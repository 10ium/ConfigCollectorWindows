#![windows_subsystem = "windows"]

use anyhow::Result;
use chrono::{DateTime, Duration as ChronoDuration, Local, Utc};
use eframe::egui;
use regex::Regex;
use reqwest::blocking::ClientBuilder;
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::Path;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::{self, Receiver, Sender};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

const APP_CONFIG_PATH: &str = "config/app_config.toml";
const CHANNELS_PATH: &str = "config/channels.txt";
const HISTORY_PATH: &str = "config/sent_history.json";

const DEFAULT_PROTOCOLS: [&str; 27] = [
    "vmess", "vless", "trojan", "ss", "ssr", "tuic", "hysteria", "hysteria2", "hy2", "juicity",
    "snell", "anytls", "ssh", "wireguard", "wg", "warp", "socks", "socks4", "socks5", "tg", "dns",
    "nm-dns", "nm-vless", "slipnet-enc", "slipnet", "slipstream", "dnstt",
];

fn generate_icon() -> egui::IconData {
    let width = 32;
    let height = 32;
    let mut rgba = Vec::with_capacity((width * height * 4) as usize);
    for _y in 0..height {
        for _x in 0..width {
            rgba.push(30);
            rgba.push(160);
            rgba.push(100);
            rgba.push(255);
        }
    }
    egui::IconData { rgba, width, height }
}

fn main() {
    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([1100.0, 750.0])
            .with_min_inner_size([900.0, 600.0])
            .with_icon(generate_icon()),
        ..Default::default()
    };
    let _ = eframe::run_native(
        "⚡ Config Collector Pro (Ultra Fast API)",
        options,
        Box::new(|_| Ok(Box::new(AppState::bootstrap()))),
    );
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
enum ProxyType {
    None,
    System,
    Http,
    Socks5,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
enum PerformanceProfile {
    WeakPC,
    MediumPC,
    StrongPC,
    Custom,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
struct ProtocolRule {
    enabled: bool,
    max_count: usize,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(default)]
struct AppConfig {
    interval_minutes: u64,
    max_pages_per_channel: usize,
    lookback_days: i64,
    proxy_type: ProxyType,
    proxy_host: String,
    proxy_port: u16,
    performance: PerformanceProfile,
    
    // متغیرهای عملکردی
    delay_ms: u64,
    timeout_secs: u64,
    concurrent_channels: usize,

    ignore_ssl_errors: bool,
    remote_dns: bool,
    output_directory: String,
    output_new_only_enabled: bool,
    output_append_unique_enabled: bool,
    protocol_rules: BTreeMap<String, ProtocolRule>,
}

impl Default for AppConfig {
    fn default() -> Self {
        let mut protocol_rules = BTreeMap::new();
        for p in DEFAULT_PROTOCOLS {
            protocol_rules.insert(
                p.to_string(),
                ProtocolRule {
                    enabled: true,
                    max_count: 500,
                },
            );
        }
        Self {
            interval_minutes: 5,
            max_pages_per_channel: 15,
            lookback_days: 2,
            proxy_type: ProxyType::System,
            proxy_host: "127.0.0.1".to_string(),
            proxy_port: 10808,
            performance: PerformanceProfile::MediumPC,
            delay_ms: 2000,
            timeout_secs: 15,
            concurrent_channels: 3,
            ignore_ssl_errors: true,
            remote_dns: true,
            output_directory: "output".to_string(),
            output_new_only_enabled: true,
            output_append_unique_enabled: true,
            protocol_rules,
        }
    }
}

impl AppConfig {
    fn load_or_create() -> Self {
        if let Ok(raw) = fs::read_to_string(APP_CONFIG_PATH) {
            if let Ok(mut cfg) = toml::from_str::<Self>(&raw) {
                for p in DEFAULT_PROTOCOLS {
                    cfg.protocol_rules
                        .entry(p.to_string())
                        .or_insert(ProtocolRule {
                            enabled: true,
                            max_count: 500,
                        });
                }
                return cfg;
            }
        }
        let cfg = Self::default();
        let _ = cfg.save();
        cfg
    }

    fn save(&self) -> Result<()> {
        if let Some(parent) = Path::new(APP_CONFIG_PATH).parent() {
            fs::create_dir_all(parent)?;
        }
        fs::write(APP_CONFIG_PATH, toml::to_string_pretty(self)?)?;
        Ok(())
    }

    fn apply_profile_defaults(&mut self) {
        match self.performance {
            PerformanceProfile::WeakPC => {
                self.delay_ms = 5000;
                self.timeout_secs = 30;
                self.concurrent_channels = 1;
            }
            PerformanceProfile::MediumPC => {
                self.delay_ms = 2000;
                self.timeout_secs = 15;
                self.concurrent_channels = 3;
            }
            PerformanceProfile::StrongPC => {
                self.delay_ms = 500;
                self.timeout_secs = 10;
                self.concurrent_channels = 8;
            }
            PerformanceProfile::Custom => {}
        }
    }
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
struct SentHistory {
    sent_at: BTreeMap<String, DateTime<Utc>>,
}

impl SentHistory {
    fn load() -> Self {
        if let Ok(raw) = fs::read_to_string(HISTORY_PATH) {
            if let Ok(v) = serde_json::from_str::<Self>(&raw) {
                return v;
            }
        }
        Self::default()
    }

    fn prune(&mut self, lookback_days: i64) {
        let threshold = Utc::now() - ChronoDuration::days(lookback_days.max(1));
        self.sent_at.retain(|_, ts| *ts >= threshold);
    }

    fn save(&self) -> Result<()> {
        if let Some(parent) = Path::new(HISTORY_PATH).parent() {
            fs::create_dir_all(parent)?;
        }
        fs::write(HISTORY_PATH, serde_json::to_string_pretty(self)?)?;
        Ok(())
    }
}

#[derive(Clone, Debug, PartialEq)]
enum LogLevel {
    Debug,
    Info,
    Success,
    Warning,
    Error,
}

#[derive(Clone, Debug)]
struct LogMessage {
    time: String,
    level: LogLevel,
    text: String,
}

#[derive(Clone, Debug)]
enum AppEvent {
    Log(LogLevel, String),
    Stats {
        total: usize,
        by_protocol: BTreeMap<String, usize>,
    },
    PingResult {
        ok: bool,
        detail: String,
    },
    WorkerStopped,
}

struct AppState {
    config: AppConfig,
    channels_text: String,
    active_tab: usize,
    proxy_access_status: String,
    proxy_access_ok: Option<bool>,
    logs: Vec<LogMessage>,
    total_configs: usize,
    by_protocol: BTreeMap<String, usize>,
    running: bool,
    stop_flag: Arc<AtomicBool>,
    worker_handle: Option<thread::JoinHandle<()>>,
    event_tx: Sender<AppEvent>,
    event_rx: Receiver<AppEvent>,
}

impl AppState {
    fn bootstrap() -> Self {
        let (tx, rx) = mpsc::channel();
        let mut state = Self {
            config: AppConfig::load_or_create(),
            channels_text: fs::read_to_string(CHANNELS_PATH)
                .unwrap_or_else(|_| "IranProxyPlus\nfilembad".to_string()),
            active_tab: 0,
            proxy_access_status: "Awaiting test...".to_string(),
            proxy_access_ok: None,
            logs: vec![LogMessage {
                time: Local::now().format("%H:%M:%S").to_string(),
                level: LogLevel::Info,
                text: "🖥️ System Boot: Ultra Fast Concurrent Engine Initialized.".to_string(),
            }],
            total_configs: 0,
            by_protocol: BTreeMap::new(),
            running: false,
            stop_flag: Arc::new(AtomicBool::new(false)),
            worker_handle: None,
            event_tx: tx,
            event_rx: rx,
        };
        state.test_connection();
        state
    }

    fn test_connection(&mut self) {
        self.proxy_access_status = "Testing connection...".to_string();
        self.proxy_access_ok = None;
        let tx = self.event_tx.clone();
        let config = self.config.clone();

        thread::spawn(move || {
            let start = Instant::now();
            if let Ok(client) = build_client(&config) {
                match client.get("https://t.me/s/telegram").send() {
                    Ok(resp) if resp.status().is_success() => {
                        let elapsed = start.elapsed().as_millis();
                        let _ = tx.send(AppEvent::PingResult {
                            ok: true,
                            detail: format!("Online ({}ms)", elapsed),
                        });
                        let _ = tx.send(AppEvent::Log(
                            LogLevel::Success,
                            format!("📡 Network Check Passed in {}ms", elapsed),
                        ));
                    }
                    _ => {
                        let _ = tx.send(AppEvent::PingResult {
                            ok: false,
                            detail: "Failed".to_string(),
                        });
                    }
                }
            }
        });
    }

    fn start(&mut self) {
        if self.running {
            return;
        }
        self.logs.clear();
        if let Some(parent) = Path::new(CHANNELS_PATH).parent() {
            let _ = fs::create_dir_all(parent);
        }
        let _ = fs::write(CHANNELS_PATH, &self.channels_text);
        let _ = self.config.save();
        
        self.stop_flag.store(false, Ordering::SeqCst);
        self.running = true;

        let tx = self.event_tx.clone();
        let cfg = self.config.clone();
        let channels_raw = self.channels_text.clone();
        let stop_flag = self.stop_flag.clone();

        self.worker_handle = Some(thread::spawn(move || {
            if let Err(err) = run_worker(cfg, channels_raw, stop_flag, tx.clone()) {
                let _ = tx.send(AppEvent::Log(
                    LogLevel::Error,
                    format!("🔥 CRASH: {}", err),
                ));
            }
            let _ = tx.send(AppEvent::WorkerStopped);
        }));
    }

    fn stop(&mut self) {
        self.stop_flag.store(true, Ordering::SeqCst);
        self.add_log(
            LogLevel::Warning,
            "🛑 Stop signal sent. Interrupting all threads cleanly...".to_string(),
        );
    }

    fn add_log(&mut self, level: LogLevel, text: String) {
        self.logs.push(LogMessage {
            time: Local::now().format("%H:%M:%S").to_string(),
            level,
            text,
        });
    }

    fn poll_events(&mut self) {
        while let Ok(event) = self.event_rx.try_recv() {
            match event {
                AppEvent::Log(level, msg) => self.add_log(level, msg),
                AppEvent::Stats { total, by_protocol } => {
                    self.total_configs = total;
                    self.by_protocol = by_protocol;
                }
                AppEvent::PingResult { ok, detail } => {
                    self.proxy_access_ok = Some(ok);
                    self.proxy_access_status = detail;
                }
                AppEvent::WorkerStopped => {
                    self.running = false;
                    self.add_log(
                        LogLevel::Warning,
                        "💤 Engine safely terminated.".to_string(),
                    );
                }
            }
        }
    }
}

impl Drop for AppState {
    fn drop(&mut self) {
        self.stop_flag.store(true, Ordering::SeqCst);
    }
}

fn apply_modern_theme(ctx: &egui::Context) {
    let mut visuals = egui::Visuals::dark();
    visuals.panel_fill = egui::Color32::from_rgb(13, 15, 23);
    visuals.window_fill = egui::Color32::from_rgb(18, 20, 30);
    visuals.widgets.noninteractive.bg_fill = egui::Color32::from_rgb(25, 28, 40);
    visuals.widgets.inactive.bg_fill = egui::Color32::from_rgb(32, 36, 50);
    visuals.widgets.hovered.bg_fill = egui::Color32::from_rgb(45, 52, 70);
    visuals.widgets.active.bg_fill = egui::Color32::from_rgb(60, 100, 220);
    visuals.selection.bg_fill = egui::Color32::from_rgb(60, 100, 220);
    ctx.set_visuals(visuals);
}

impl eframe::App for AppState {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        self.poll_events();
        apply_modern_theme(ctx);

        egui::TopBottomPanel::top("header")
            .exact_height(85.0)
            .frame(
                egui::Frame::default()
                    .fill(egui::Color32::from_rgb(18, 20, 30))
                    .inner_margin(15.0),
            )
            .show(ctx, |ui| {
                ui.horizontal(|ui| {
                    ui.vertical(|ui| {
                        ui.label(
                            egui::RichText::new("⚡ Telegram Config Collector")
                                .size(28.0)
                                .strong()
                                .color(egui::Color32::from_rgb(240, 248, 255)),
                        );
                        ui.label(
                            egui::RichText::new("Ultra Fast Concurrent Edition")
                                .size(13.0)
                                .color(egui::Color32::from_rgb(120, 140, 160)),
                        );
                    });

                    ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                        let btn_size = [160.0, 45.0];
                        if self.running {
                            if ui
                                .add_sized(
                                    btn_size,
                                    egui::Button::new(
                                        egui::RichText::new("🛑 STOP ENGINE")
                                            .size(16.0)
                                            .strong()
                                            .color(egui::Color32::WHITE),
                                    )
                                    .fill(egui::Color32::from_rgb(220, 60, 60))
                                    .rounding(8.0),
                                )
                                .clicked()
                            {
                                self.stop();
                            }
                            ui.spinner();
                        } else {
                            if ui
                                .add_sized(
                                    btn_size,
                                    egui::Button::new(
                                        egui::RichText::new("▶ START ENGINE")
                                            .size(16.0)
                                            .strong()
                                            .color(egui::Color32::WHITE),
                                    )
                                    .fill(egui::Color32::from_rgb(40, 180, 100))
                                    .rounding(8.0),
                                )
                                .clicked()
                            {
                                self.start();
                            }
                        }
                    });
                });
            });

        egui::SidePanel::left("sidebar")
            .default_width(360.0)
            .frame(
                egui::Frame::default()
                    .fill(egui::Color32::from_rgb(18, 20, 30))
                    .inner_margin(15.0),
            )
            .show(ctx, |ui| {
                ui.horizontal(|ui| {
                    ui.selectable_value(&mut self.active_tab, 0, "⚙ Main");
                    ui.selectable_value(&mut self.active_tab, 1, "📡 Targets");
                    ui.selectable_value(&mut self.active_tab, 2, "🎯 Filters");
                });
                ui.separator();
                egui::ScrollArea::vertical().show(ui, |ui| {
                    match self.active_tab {
                        0 => {
                            ui.add_space(5.0);
                            ui.heading(
                                egui::RichText::new("💻 Performance Profile")
                                    .color(egui::Color32::GOLD),
                            );
                            
                            let mut profile_changed = false;
                            egui::ComboBox::from_label("Hardware Profile")
                                .selected_text(match self.config.performance {
                                    PerformanceProfile::WeakPC => "Weak PC (Safe)",
                                    PerformanceProfile::MediumPC => "Medium PC (Balanced)",
                                    PerformanceProfile::StrongPC => "Strong PC (Aggressive)",
                                    PerformanceProfile::Custom => "Custom Profile",
                                })
                                .show_ui(ui, |ui| {
                                    if ui.selectable_value(&mut self.config.performance, PerformanceProfile::WeakPC, "Weak PC (Safe)").changed() { profile_changed = true; }
                                    if ui.selectable_value(&mut self.config.performance, PerformanceProfile::MediumPC, "Medium PC (Balanced)").changed() { profile_changed = true; }
                                    if ui.selectable_value(&mut self.config.performance, PerformanceProfile::StrongPC, "Strong PC (Aggressive)").changed() { profile_changed = true; }
                                    if ui.selectable_value(&mut self.config.performance, PerformanceProfile::Custom, "Custom Profile").changed() { profile_changed = true; }
                                });

                            if profile_changed {
                                self.config.apply_profile_defaults();
                            }

                            let is_custom = self.config.performance == PerformanceProfile::Custom;

                            egui::Frame::none()
                                .fill(egui::Color32::from_rgb(25, 28, 40))
                                .rounding(6.0)
                                .inner_margin(10.0)
                                .show(ui, |ui| {
                                    ui.horizontal(|ui| {
                                        ui.label("Delay (ms):").on_hover_text("Pause between requests to avoid ban.");
                                        ui.add_enabled(is_custom, egui::DragValue::new(&mut self.config.delay_ms).range(100..=10000));
                                    });
                                    ui.horizontal(|ui| {
                                        ui.label("Timeout (s):").on_hover_text("Max wait time for a page response.");
                                        ui.add_enabled(is_custom, egui::DragValue::new(&mut self.config.timeout_secs).range(5..=60));
                                    });
                                    ui.horizontal(|ui| {
                                        ui.label("Concurrent Channels:").on_hover_text("How many channels to scan simultaneously.");
                                        ui.add_enabled(is_custom, egui::DragValue::new(&mut self.config.concurrent_channels).range(1..=50));
                                    });
                                });

                            ui.add_space(15.0);
                            ui.heading(
                                egui::RichText::new("🌐 Network & Proxy")
                                    .color(egui::Color32::LIGHT_BLUE),
                            );
                            ui.horizontal(|ui| {
                                egui::ComboBox::from_id_salt("proxy_type")
                                    .selected_text(match self.config.proxy_type {
                                        ProxyType::None => "Direct",
                                        ProxyType::System => "System Auto",
                                        ProxyType::Http => "HTTP",
                                        ProxyType::Socks5 => "SOCKS5",
                                    })
                                    .show_ui(ui, |ui| {
                                        ui.selectable_value(&mut self.config.proxy_type, ProxyType::System, "System Auto");
                                        ui.selectable_value(&mut self.config.proxy_type, ProxyType::Socks5, "SOCKS5");
                                        ui.selectable_value(&mut self.config.proxy_type, ProxyType::Http, "HTTP");
                                        ui.selectable_value(&mut self.config.proxy_type, ProxyType::None, "Direct");
                                    });
                                
                                if ui.button("🔄 Test").clicked() {
                                    self.test_connection();
                                }
                            });

                            if matches!(self.config.proxy_type, ProxyType::Http | ProxyType::Socks5)
                            {
                                ui.horizontal(|ui| {
                                    ui.label("IP:");
                                    ui.text_edit_singleline(&mut self.config.proxy_host);
                                });
                                ui.horizontal(|ui| {
                                    ui.label("Port:");
                                    ui.add(
                                        egui::DragValue::new(&mut self.config.proxy_port)
                                            .range(1..=65535),
                                    );
                                });
                            }
                            ui.checkbox(
                                &mut self.config.ignore_ssl_errors,
                                "Bypass SSL/TLS Filter (For VPNs)",
                            );

                            ui.add_space(15.0);
                            ui.heading(
                                egui::RichText::new("⏱️ Scheduler & Dates")
                                    .color(egui::Color32::LIGHT_BLUE),
                            );
                            ui.horizontal(|ui| {
                                ui.label("Loop Interval (Min):");
                                ui.add(
                                    egui::DragValue::new(&mut self.config.interval_minutes)
                                        .range(1..=240),
                                );
                            });
                            ui.horizontal(|ui| {
                                ui.label("Pages Per Channel:");
                                ui.add(
                                    egui::DragValue::new(&mut self.config.max_pages_per_channel)
                                        .range(1..=100),
                                );
                            });
                            ui.horizontal(|ui| {
                                ui.label("Lookback Days:");
                                ui.add(
                                    egui::DragValue::new(&mut self.config.lookback_days)
                                        .range(1..=30),
                                );
                            });

                            ui.add_space(15.0);
                            ui.heading(
                                egui::RichText::new("💾 Output Settings")
                                    .color(egui::Color32::LIGHT_BLUE),
                            );
                            ui.horizontal(|ui| {
                                ui.label("Folder:");
                                ui.text_edit_singleline(&mut self.config.output_directory)
                                    .on_hover_text("Directory path to save results.");
                            });
                            ui.checkbox(
                                &mut self.config.output_new_only_enabled,
                                "Save New Configs Only (new_only)",
                            );
                            ui.checkbox(
                                &mut self.config.output_append_unique_enabled,
                                "Backup Unique Configs (append_unique)",
                            );
                        }
                        1 => {
                            ui.heading(
                                egui::RichText::new("📡 Target Channels")
                                    .color(egui::Color32::LIGHT_BLUE),
                            );
                            ui.label(egui::RichText::new("One ID/Link per line:").small().color(egui::Color32::GRAY));
                            ui.add_sized(
                                [ui.available_width(), ui.available_height() - 20.0],
                                egui::TextEdit::multiline(&mut self.channels_text)
                                    .font(egui::TextStyle::Monospace),
                            );
                        }
                        2 => {
                            ui.heading(
                                egui::RichText::new("🎯 Protocols Filter")
                                    .color(egui::Color32::LIGHT_BLUE),
                            );
                            for (name, rule) in &mut self.config.protocol_rules {
                                ui.horizontal(|ui| {
                                    ui.checkbox(&mut rule.enabled, name);
                                    ui.with_layout(
                                        egui::Layout::right_to_left(egui::Align::Center),
                                        |ui| {
                                            ui.add(
                                                egui::DragValue::new(&mut rule.max_count)
                                                    .range(1..=50000),
                                            );
                                        },
                                    );
                                });
                            }
                        }
                        _ => {}
                    }
                });
            });

        egui::CentralPanel::default()
            .frame(
                egui::Frame::default()
                    .fill(egui::Color32::from_rgb(13, 15, 23))
                    .inner_margin(15.0),
            )
            .show(ctx, |ui| {
                ui.horizontal(|ui| {
                    ui.group(|ui| {
                        ui.label(
                            egui::RichText::new("Extracted Total:").color(egui::Color32::GRAY),
                        );
                        ui.label(
                            egui::RichText::new(self.total_configs.to_string())
                                .size(22.0)
                                .strong()
                                .color(egui::Color32::from_rgb(30, 180, 120)),
                        );
                    });
                    let proxy_color = match self.proxy_access_ok {
                        Some(true) => egui::Color32::from_rgb(30, 180, 120),
                        Some(false) => egui::Color32::from_rgb(220, 60, 60),
                        None => egui::Color32::from_rgb(200, 150, 40),
                    };
                    ui.group(|ui| {
                        ui.label(
                            egui::RichText::new("Connection Status:").color(egui::Color32::GRAY),
                        );
                        ui.label(
                            egui::RichText::new(&self.proxy_access_status)
                                .size(15.0)
                                .strong()
                                .color(proxy_color),
                        );
                    });
                });

                ui.add_space(10.0);
                egui::Frame::none()
                    .fill(egui::Color32::from_rgb(8, 10, 15))
                    .rounding(8.0)
                    .inner_margin(10.0)
                    .show(ui, |ui| {
                        ui.horizontal(|ui| {
                            ui.heading(
                                egui::RichText::new("Terminal Log")
                                    .color(egui::Color32::WHITE),
                            );
                            ui.with_layout(
                                egui::Layout::right_to_left(egui::Align::Center),
                                |ui| {
                                    if ui.button("Clear").clicked() {
                                        self.logs.clear();
                                    }
                                    if ui.button("Copy").clicked() {
                                        let text = self
                                            .logs
                                            .iter()
                                            .map(|l| format!("[{}] {}", l.time, l.text))
                                            .collect::<Vec<_>>()
                                            .join("\n");
                                        ctx.output_mut(|o| o.copied_text = text);
                                    }
                                },
                            );
                        });
                        ui.separator();
                        egui::ScrollArea::vertical()
                            .stick_to_bottom(true)
                            .auto_shrink([false; 2])
                            .show(ui, |ui| {
                                ui.spacing_mut().item_spacing.y = 5.0;
                                for log in self.logs.iter().rev().take(500).rev() {
                                    let color = match log.level {
                                        LogLevel::Debug => egui::Color32::from_rgb(100, 110, 130),
                                        LogLevel::Info => egui::Color32::from_rgb(160, 180, 200),
                                        LogLevel::Success => egui::Color32::from_rgb(60, 210, 130),
                                        LogLevel::Warning => egui::Color32::from_rgb(240, 180, 50),
                                        LogLevel::Error => egui::Color32::from_rgb(255, 90, 90),
                                    };
                                    ui.horizontal_wrapped(|ui| {
                                        ui.label(
                                            egui::RichText::new(format!("[{}]", log.time))
                                                .color(egui::Color32::from_rgb(80, 90, 110))
                                                .monospace()
                                                .small(),
                                        );
                                        ui.label(
                                            egui::RichText::new(&log.text)
                                                .color(color)
                                                .monospace(),
                                        );
                                    });
                                }
                            });
                    });
            });
        ctx.request_repaint_after(Duration::from_millis(500));
    }
}

// =============================================================
// 🛡️ هسته شبکه (استفاده از Connection Pool یکتا)
// =============================================================

fn build_client(config: &AppConfig) -> Result<reqwest::blocking::Client> {
    let mut b = ClientBuilder::new()
        .timeout(Duration::from_secs(config.timeout_secs))
        .user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36")
        .danger_accept_invalid_certs(config.ignore_ssl_errors);

    match config.proxy_type {
        ProxyType::None => {
            b = b.no_proxy();
        }
        ProxyType::System => {}
        ProxyType::Http | ProxyType::Socks5 => {
            let scheme = if config.proxy_type == ProxyType::Socks5 && config.remote_dns {
                "socks5h"
            } else if config.proxy_type == ProxyType::Socks5 {
                "socks5"
            } else {
                "http"
            };
            let host = if config.proxy_host.trim().is_empty() {
                "127.0.0.1"
            } else {
                config.proxy_host.trim()
            };
            b = b.proxy(reqwest::Proxy::all(&format!(
                "{}://{}:{}",
                scheme, host, config.proxy_port
            ))?);
        }
    }
    b.build().map_err(|e| anyhow::anyhow!("Failed to build client: {}", e))
}

// =============================================================
// 🧠 استخراج همزمان (Concurrent Smart Scraping)
// =============================================================

fn run_worker(
    config: AppConfig,
    channels_raw: String,
    stop: Arc<AtomicBool>,
    tx: Sender<AppEvent>,
) -> Result<()> {
    let channels = parse_channels(&channels_raw);
    let regex_pattern = r"(?i)(vmess|vless|trojan|ss|ssr|tuic|hysteria|hysteria2|hy2|juicity|snell|anytls|ssh|wireguard|wg|warp|socks|socks4|socks5|tg|dns|nm-dns|nm-vless|slipnet-enc|slipnet|slipstream|dnstt)://[a-zA-Z0-9\-\._~:/\?#\[\]@!\$&'\(\)\*\+,%;=]+";
    let regex = Regex::new(regex_pattern).unwrap();
    let date_regex = Regex::new(r#"<time datetime="([^"]+)""#).unwrap();

    let mut history = SentHistory::load();
    let threshold_date = Utc::now() - ChronoDuration::days(config.lookback_days.max(1));

    log_worker(
        &tx,
        LogLevel::Info,
        format!(
            "🚀 Crawler Started | Mode: {:?} | Concurrency: {} threads",
            config.performance, config.concurrent_channels
        ),
    );

    loop {
        if stop.load(Ordering::SeqCst) { break; }
        
        history.prune(config.lookback_days);
        let client = build_client(&config)?;
        
        // متغیرهای مشترک (Thread-Safe)
        let queue = Arc::new(Mutex::new(channels.clone()));
        let global_gathered: Arc<Mutex<BTreeMap<String, BTreeSet<String>>>> = Arc::new(Mutex::new(BTreeMap::new()));
        let total_run_configs = Arc::new(Mutex::new(0usize));
        
        let mut handles = vec![];
        let threads_count = config.concurrent_channels.max(1).min(channels.len().max(1));

        for _ in 0..threads_count {
            let q = queue.clone();
            let client_c = client.clone();
            let config_c = config.clone();
            let stop_c = stop.clone();
            let tx_c = tx.clone();
            let gathered_c = global_gathered.clone();
            let total_c = total_run_configs.clone();
            let reg_c = regex.clone();
            let date_reg_c = date_regex.clone();

            handles.push(thread::spawn(move || {
                loop {
                    if stop_c.load(Ordering::SeqCst) { break; }
                    
                    let channel = {
                        let mut lock = q.lock().unwrap();
                        match lock.pop() {
                            Some(c) => c,
                            None => break,
                        }
                    };

                    log_worker(&tx_c, LogLevel::Info, format!("📡 Thread started scanning: @{}", channel));
                    
                    let mut before: Option<String> = None;
                    let mut channel_configs = 0;
                    let mut local_gathered: BTreeMap<String, BTreeSet<String>> = BTreeMap::new();

                    for page in 1..=config_c.max_pages_per_channel {
                        if stop_c.load(Ordering::SeqCst) { break; }
                        
                        let mut url = format!("https://t.me/s/{}", channel);
                        if let Some(ref id) = before {
                            url.push_str(&format!("?before={}", id));
                        }

                        match client_c.get(&url).send() {
                            Ok(resp) if resp.status().is_success() => {
                                if let Ok(raw_html) = resp.text() {
                                    let mut found_in_page = 0;
                                    let mut next_before = None;

                                    let decoded_html = raw_html
                                        .replace("&amp;", "&")
                                        .replace("&lt;", "<")
                                        .replace("&gt;", ">")
                                        .replace("&quot;", "\"");

                                    let next_regex = Regex::new(r#"data-post="[^/]+/(\d+)""#).unwrap();
                                    for cap in next_regex.captures_iter(&decoded_html) {
                                        next_before = Some(cap[1].to_string());
                                    }

                                    let blocks: Vec<&str> = decoded_html.split("tgme_widget_message ").collect();
                                    for block in blocks {
                                        let mut is_valid_date = true;
                                        if let Some(caps) = date_reg_c.captures(block) {
                                            if let Ok(parsed_date) = DateTime::parse_from_rfc3339(&caps[1]) {
                                                if parsed_date.with_timezone(&Utc) < threshold_date {
                                                    is_valid_date = false;
                                                }
                                            }
                                        }

                                        if is_valid_date {
                                            for m in reg_c.find_iter(block) {
                                                let clean_link = m.as_str()
                                                    .trim_end_matches(&['(', ')', '[', ']', ' ', '!', '.', ',', ';', '\'', '"', '<', '>'][..])
                                                    .to_string();

                                                if let Some(proto) = clean_link.split("://").next() {
                                                    found_in_page += 1;
                                                    local_gathered.entry(proto.to_lowercase()).or_default().insert(clean_link);
                                                }
                                            }
                                        }
                                    }

                                    channel_configs += found_in_page;
                                    
                                    // بررسی و ذخیره وضعیت حلقه قبل از انتقال مالکیت
                                    let has_next = next_before.is_some();
                                    before = next_before;

                                    if !has_next || found_in_page == 0 {
                                        break; // پایان یا عدم وجود لینک
                                    }
                                }
                            }
                            Err(_) => {
                                log_worker(&tx_c, LogLevel::Warning, format!("⚠️ Failed fetching page {} of @{}", page, channel));
                                break;
                            }
                            _ => break,
                        }
                        thread::sleep(Duration::from_millis(config_c.delay_ms));
                    }

                    if channel_configs > 0 {
                        let mut g = gathered_c.lock().unwrap();
                        for (k, v) in local_gathered {
                            g.entry(k).or_default().extend(v);
                        }
                        *total_c.lock().unwrap() += channel_configs;
                        log_worker(&tx_c, LogLevel::Success, format!("✔️ @{} finished: {} configs.", channel, channel_configs));
                    }
                }
            }));
        }

        // صبر کردن تا تمام Threadها کارشان روی کانال‌ها تمام شود
        for h in handles {
            let _ = h.join();
        }

        if stop.load(Ordering::SeqCst) { break; }

        let mut final_gathered = Arc::try_unwrap(global_gathered).unwrap().into_inner().unwrap();
        let total_run = Arc::try_unwrap(total_run_configs).unwrap().into_inner().unwrap();

        // اعمال لیمیت‌های فیلتر
        apply_protocol_limits(&mut final_gathered, &config.protocol_rules);

        let mut new_only: BTreeMap<String, BTreeSet<String>> = BTreeMap::new();
        let mut total_new = 0;

        for (proto, links) in &final_gathered {
            for link in links {
                if !history.sent_at.contains_key(link) {
                    history.sent_at.insert(link.clone(), Utc::now());
                    new_only.entry(proto.clone()).or_default().insert(link.clone());
                    total_new += 1;
                }
            }
        }

        let mut by_protocol = BTreeMap::new();
        for (k, v) in &new_only {
            by_protocol.insert(k.clone(), v.len());
        }

        let out_new = Path::new(&config.output_directory).join("new_only");
        let out_append = Path::new(&config.output_directory).join("append_unique");

        if config.output_new_only_enabled && !new_only.is_empty() {
            let _ = write_outputs_replace(&out_new, &new_only);
        }
        if config.output_append_unique_enabled && !final_gathered.is_empty() {
            let _ = write_outputs_append_unique(&out_append, &final_gathered);
        }

        let _ = history.save();
        let _ = tx.send(AppEvent::Stats { total: total_new, by_protocol });

        log_worker(
            &tx,
            LogLevel::Success,
            format!("🎉 All Channels Processed! Found: {} ({} NEW).", total_run, total_new),
        );
        log_worker(
            &tx,
            LogLevel::Info,
            format!("💤 Sleeping for {} minutes before next cycle...", config.interval_minutes),
        );

        for _ in 0..(config.interval_minutes * 60) {
            if stop.load(Ordering::SeqCst) { break; }
            thread::sleep(Duration::from_secs(1));
        }
    }
    Ok(())
}

fn log_worker(tx: &Sender<AppEvent>, level: LogLevel, text: String) {
    let _ = tx.send(AppEvent::Log(level, text));
}

fn apply_protocol_limits(
    store: &mut BTreeMap<String, BTreeSet<String>>,
    rules: &BTreeMap<String, ProtocolRule>,
) {
    for (proto, links) in store.iter_mut() {
        if let Some(rule) = rules.get(proto) {
            if links.len() > rule.max_count {
                *links = links.iter().take(rule.max_count).cloned().collect();
            }
        }
    }
}

fn write_outputs_replace(base_dir: &Path, store: &BTreeMap<String, BTreeSet<String>>) -> Result<()> {
    if store.is_empty() { return Ok(()); }
    fs::create_dir_all(base_dir)?;
    let mut mixed = BTreeSet::new();
    for (p, links) in store {
        if links.is_empty() { continue; }
        let lines: Vec<String> = links.iter().cloned().collect();
        fs::write(base_dir.join(format!("{p}.txt")), lines.join("\n"))?;
        mixed.extend(links.iter().cloned());
    }
    if !mixed.is_empty() {
        let mixed_lines: Vec<String> = mixed.into_iter().collect();
        fs::write(base_dir.join("mixed.txt"), mixed_lines.join("\n"))?;
    }
    Ok(())
}

fn write_outputs_append_unique(
    base_dir: &Path,
    store: &BTreeMap<String, BTreeSet<String>>,
) -> Result<()> {
    if store.is_empty() { return Ok(()); }
    fs::create_dir_all(base_dir)?;
    for (p, links) in store {
        if links.is_empty() { continue; }
        let path = base_dir.join(format!("{p}.txt"));
        let mut combined = read_existing_set(&path)?;
        combined.extend(links.iter().cloned());
        let lines: Vec<String> = combined.into_iter().collect();
        fs::write(&path, lines.join("\n"))?;
    }
    
    let path_mixed = base_dir.join("mixed.txt");
    let mut mixed = read_existing_set(&path_mixed)?;
    for links in store.values() {
        mixed.extend(links.iter().cloned());
    }
    if !mixed.is_empty() {
        let mixed_lines: Vec<String> = mixed.into_iter().collect();
        fs::write(path_mixed, mixed_lines.join("\n"))?;
    }
    Ok(())
}

fn read_existing_set(path: &Path) -> Result<BTreeSet<String>> {
    if !path.exists() { return Ok(BTreeSet::new()); }
    let raw = fs::read_to_string(path)?;
    let lines = raw.lines().map(str::trim).filter(|l| !l.is_empty()).map(ToOwned::to_owned).collect();
    Ok(lines)
}

fn parse_channels(raw: &str) -> Vec<String> {
    raw.lines()
        .map(str::trim)
        .filter(|l| !l.is_empty() && !l.starts_with('#'))
        .filter_map(|line| {
            if let Some(rest) = line.strip_prefix('@') { return Some(rest.to_string()); }
            if line.contains("t.me/") {
                return line.split("t.me/").nth(1).map(|x| x.split('?').next().unwrap_or_default().trim_matches('/').to_string());
            }
            Some(line.to_string())
        })
        .filter(|s| !s.is_empty())
        .collect()
}
