//! Linux bridge between the AndroidMic core and the Quickshell GUI.
//!
//! In `--quickshell` mode the cosmic windows are not opened. Instead we expose
//! the app state over a Unix socket (`$XDG_RUNTIME_DIR/android-mic.qsock`) using
//! newline-delimited JSON, the wire protocol documented in `quickshell/README.md`.
//! The Quickshell bar-widget connects to this socket to render the info +
//! settings dialogs and controls the app. There is no system-tray icon: the bar
//! widget is the GUI.

use std::sync::OnceLock;
use tokio::{
    io::{AsyncBufReadExt, AsyncWriteExt, BufReader},
    net::{UnixListener, UnixStream},
    sync::{broadcast, mpsc},
};

/// Command from the GUI (or tray) into the app's update loop.
#[derive(Debug, Clone)]
pub enum QuickCmd {
    Connect,
    Stop,
    Exit,
    UseRecommendedFormat,
    ResetDenoise,
    SetConfig(String, serde_json::Value),
    SetDevice(String),
    SetAdapter(String),
    /// A new client connected -> re-broadcast a full snapshot.
    SnapshotRequested,
}

static OUT_TX: OnceLock<broadcast::Sender<String>> = OnceLock::new();

/// Broadcast a JSON message to every connected Quickshell client.
pub fn broadcast(json: serde_json::Value) {
    if let Some(tx) = OUT_TX.get() {
        let _ = tx.send(json.to_string());
    }
}

fn runtime_dir() -> String {
    if let Ok(d) = std::env::var("XDG_RUNTIME_DIR")
        && !d.is_empty()
    {
        return d;
    }
    // Fallback: `id -u`, then a common default.
    let uid = std::process::Command::new("id")
        .arg("-u")
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| s.trim().to_string())
        .unwrap_or_else(|| "1000".to_string());
    format!("/run/user/{uid}")
}

fn socket_path() -> String {
    format!("{}/android-mic.qsock", runtime_dir())
}

/// Returns a stream of commands coming in from the Quickshell GUI & tray.
/// Must be registered as a single iced subscription.
pub fn subscribe() -> impl futures::Stream<Item = QuickCmd> {
    async_stream::stream! {
        let (cmd_tx, mut cmd_rx) = mpsc::channel::<QuickCmd>(64);
        let (out_tx, _out_rx) = broadcast::channel::<String>(64);

        // Publish the senders the rest of the app uses.
        let _ = OUT_TX.set(out_tx.clone());

        // Start the Unix socket server (the bar widget is the GUI; no tray).
        tokio::spawn(run_server(out_tx.clone(), cmd_tx.clone()));

        while let Some(cmd) = cmd_rx.recv().await {
            yield cmd;
        }
    }
}

async fn run_server(out_tx: broadcast::Sender<String>, cmd_tx: mpsc::Sender<QuickCmd>) {
    let path = socket_path();
    let _ = std::fs::remove_file(&path);
    let listener = match UnixListener::bind(&path) {
        Ok(l) => l,
        Err(e) => {
            error!("quickshell: can't bind {}: {e}", path);
            return;
        }
    };
    info!("quickshell: listening on {path}");

    loop {
        match listener.accept().await {
            Ok((stream, _)) => {
                tokio::spawn(handle_client(stream, out_tx.clone(), cmd_tx.clone()));
            }
            Err(e) => {
                error!("quickshell: accept failed: {e}");
                tokio::time::sleep(std::time::Duration::from_millis(100)).await;
            }
        }
    }
}

async fn handle_client(
    stream: UnixStream,
    out_tx: broadcast::Sender<String>,
    cmd_tx: mpsc::Sender<QuickCmd>,
) {
    let (rd, wr) = stream.into_split();
    let mut reader = BufReader::new(rd);

    // Subscribe before requesting a snapshot so this client receives it.
    let mut rx = out_tx.subscribe();
    let _ = cmd_tx.send(QuickCmd::SnapshotRequested).await;

    // Writer task: drain the broadcast channel into the client socket.
    let mut writer = wr;
    tokio::spawn(async move {
        loop {
            match rx.recv().await {
                Ok(line) => {
                    if writer.write_all(line.as_bytes()).await.is_err()
                        || writer.write_all(b"\n").await.is_err()
                    {
                        break;
                    }
                }
                Err(broadcast::error::RecvError::Lagged(n)) => {
                    // Too slow to keep up (e.g. wave spam): skip the dropped
                    // messages but keep the client alive.
                    warn!("quickshell: client too slow, skipped {n} messages");
                    continue;
                }
                Err(_) => break, // channel closed
            }
        }
    });

    let mut buf = Vec::new();
    loop {
        buf.clear();
        match reader.read_until(b'\n', &mut buf).await {
            Ok(0) => break, // peer closed
            Ok(_) => {
                if let Some(cmd) = parse_command(&String::from_utf8_lossy(&buf)) {
                    if cmd_tx.send(cmd).await.is_err() {
                        break;
                    }
                }
            }
            Err(_) => break,
        }
    }
}

/// Parse a single client command line into a `QuickCmd`.
fn parse_command(line: &str) -> Option<QuickCmd> {
    let v: serde_json::Value = serde_json::from_str(line.trim()).ok()?;
    let cmd = v.get("cmd")?.as_str()?;
    let s = |k: &str| -> String {
        v.get(k)
            .and_then(|x| x.as_str())
            .unwrap_or("")
            .to_string()
    };

    Some(match cmd {
        "connect" => QuickCmd::Connect,
        "stop" => QuickCmd::Stop,
        "exit" => QuickCmd::Exit,
        "use_recommended_format" => QuickCmd::UseRecommendedFormat,
        "reset_denoise" => QuickCmd::ResetDenoise,
        "device" => QuickCmd::SetDevice(s("value")),
        "adapter" => QuickCmd::SetAdapter(s("value")),
        "config" => QuickCmd::SetConfig(
            s("key"),
            v.get("value").cloned().unwrap_or(serde_json::Value::Null),
        ),
        _ => return None,
    })
}

// ------------------------------------------------------- wire format helpers
// Canonical string forms shared by the daemon, snapshot and command parsing.

pub fn quick_mode(m: &crate::config::ConnectionMode) -> &'static str {
    match m {
        crate::config::ConnectionMode::Tcp => "tcp",
        crate::config::ConnectionMode::Udp => "udp",
        #[cfg(feature = "adb")]
        crate::config::ConnectionMode::Adb => "adb",
        #[cfg(feature = "usb")]
        crate::config::ConnectionMode::Usb => "usb",
    }
}

pub fn quick_format(f: &crate::config::AudioFormat) -> &'static str {
    match f {
        crate::config::AudioFormat::U8 => "u8",
        crate::config::AudioFormat::I16 => "i16",
        crate::config::AudioFormat::I24 => "i24",
        crate::config::AudioFormat::I32 => "i32",
        crate::config::AudioFormat::F32 => "f32",
    }
}

pub fn quick_denoise(k: &crate::config::DenoiseKind) -> &'static str {
    match k {
        crate::config::DenoiseKind::Rnnoise => "rnnoise",
        crate::config::DenoiseKind::Speexdsp => "speexdsp",
    }
}

pub fn denoise_from_str(s: &str) -> Option<crate::config::DenoiseKind> {
    match s {
        "rnnoise" | "Rnnoise" | "RNNoise" => Some(crate::config::DenoiseKind::Rnnoise),
        "speexdsp" | "Speexdsp" => Some(crate::config::DenoiseKind::Speexdsp),
        _ => None,
    }
}

pub fn quick_theme(t: &crate::config::AppTheme) -> &'static str {
    match t {
        crate::config::AppTheme::System => "System",
        crate::config::AppTheme::Dark => "Dark",
        crate::config::AppTheme::Light => "Light",
        crate::config::AppTheme::HighContrastDark => "HighContrastDark",
        crate::config::AppTheme::HighContrastLight => "HighContrastLight",
    }
}

pub fn theme_from_str(s: &str) -> Option<crate::config::AppTheme> {
    match s {
        "System" => Some(crate::config::AppTheme::System),
        "Dark" => Some(crate::config::AppTheme::Dark),
        "Light" => Some(crate::config::AppTheme::Light),
        "HighContrastDark" => Some(crate::config::AppTheme::HighContrastDark),
        "HighContrastLight" => Some(crate::config::AppTheme::HighContrastLight),
        _ => None,
    }
}

pub fn quick_effect(e: &crate::config::AudioEffect) -> &'static str {
    use crate::config::AudioEffect::*;
    match e {
        NoEffect => "none",
        Echo => "echo",
        ReverbIntimate => "reverb_intimate",
        ReverbSpatious => "reverb_spacious",
        Spaceship => "spaceship",
        Underwater => "underwater",
        PitchUp => "pitch_up",
        PitchDown => "pitch_down",
        Demon => "demon",
        Walkie => "walkie",
        Popstar => "popstar",
        Robot => "robot",
    }
}

pub fn effect_from_str(s: &str) -> Option<crate::config::AudioEffect> {
    use crate::config::AudioEffect::*;
    Some(match s {
        "none" | "No Effect" => NoEffect,
        "echo" => Echo,
        "reverb_intimate" | "Empty Room" => ReverbIntimate,
        "reverb_spacious" | "Concert Hall" => ReverbSpatious,
        "spaceship" => Spaceship,
        "underwater" => Underwater,
        "pitch_up" | "Chipmunk" => PitchUp,
        "pitch_down" | "Giant" => PitchDown,
        "demon" => Demon,
        "walkie" | "Walkie-Talkie" => Walkie,
        "popstar" | "Pop Star" => Popstar,
        "robot" => Robot,
        _ => return None,
    })
}
