use crate::config::{
    AppConfig, InputSourceMode, PerformanceProfile, ProxyType, CHANNELS_PATH, SUBSCRIPTIONS_PATH,
};
use crate::scraper::{build_client, run_worker, AppEvent, LogLevel};
use chrono::Local;
use eframe::egui;
use std::collections::BTreeMap;
use std::fs;
use std::path::Path;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::{self, Receiver, Sender};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant};

#[derive(Clone, Debug)]
pub struct LogMessage {
    pub time: String,
    pub level: LogLevel,
    pub text: String,
}

pub struct AppState {
    pub config: AppConfig,
    pub channels_text: String,
    pub subscriptions_text: String,
    pub active_tab: usize,
    pub logs: Vec<LogMessage>,
    pub total_configs: usize,
    pub by_protocol: BTreeMap<String, usize>,
    pub running: bool,
    pub stop_flag: Arc<AtomicBool>,
    pub is_downloading: Arc<AtomicBool>,
    pub worker_handle: Option<thread::JoinHandle<()>>,
    pub event_tx: Sender<AppEvent>,
    pub event_rx: Receiver<AppEvent>,
}

impl AppState {
    pub fn bootstrap() -> Self {
        let (tx, rx) = mpsc::channel();
        let mut state = Self {
            config: AppConfig::load_or_create(),
            channels_text: fs::read_to_string(CHANNELS_PATH)
                .unwrap_or_else(|_| crate::config::DEFAULT_TARGETS.to_string()),
            subscriptions_text: fs::read_to_string(SUBSCRIPTIONS_PATH).unwrap_or_default(),
            active_tab: 0,
            logs: vec![LogMessage {
                time: Local::now().format("%H:%M:%S").to_string(),
                level: LogLevel::Info,
                text: "🖥️ System Boot: Smart Modular Engine Initialized (Phase 5).".to_string(),
            }],
            total_configs: 0,
            by_protocol: BTreeMap::new(),
            running: false,
            stop_flag: Arc::new(AtomicBool::new(false)),
            is_downloading: Arc::new(AtomicBool::new(false)),
            worker_handle: None,
            event_tx: tx,
            event_rx: rx,
        };

        let xray_path = &state.config.tester.xray_knife_path;
        if state.config.tester.enabled && !Path::new(xray_path).exists() {
            state.add_log(
                LogLevel::Error,
                "⚠️ xray-knife.exe not found! Please download it from the Tester tab.".to_string(),
            );
        }

        state.test_connection();
        state
    }

    pub fn test_connection(&mut self) {
        let tx = self.event_tx.clone();
        let config = self.config.clone();
        self.add_log(LogLevel::Info, "Testing proxy connection...".to_string());

        thread::spawn(move || {
            let start = Instant::now();
            if let Ok(client) = build_client(&config) {
                match client.get("https://t.me/s/telegram").send() {
                    Ok(resp) if resp.status().is_success() => {
                        let elapsed = start.elapsed().as_millis();
                        let _ = tx.send(AppEvent::Log(
                            LogLevel::Success,
                            format!("📡 Network Check Passed in {}ms", elapsed),
                        ));
                    }
                    _ => {
                        let _ = tx.send(AppEvent::Log(
                            LogLevel::Error,
                            "❌ Network Test Failed! Check your proxy settings.".to_string(),
                        ));
                    }
                }
            } else {
                let _ = tx.send(AppEvent::Log(
                    LogLevel::Error,
                    "❌ Failed to build network client!".to_string(),
                ));
            }
        });
    }

    pub fn test_direct_connection(&mut self) {
        let tx = self.event_tx.clone();
        self.add_log(
            LogLevel::Info,
            "Testing direct system connection (No Proxy) to soft98.ir...".to_string(),
        );

        thread::spawn(move || {
            let start = Instant::now();
            let direct_client = reqwest::blocking::ClientBuilder::new()
                .no_proxy()
                .timeout(Duration::from_secs(10))
                .danger_accept_invalid_certs(true)
                .build();

            if let Ok(client) = direct_client {
                match client.get("https://soft98.ir").send() {
                    Ok(resp) if resp.status().is_success() => {
                        let elapsed = start.elapsed().as_millis();
                        let _ = tx.send(AppEvent::Log(
                            LogLevel::Success,
                            format!(
                                "🌐 Direct Connection Passed! soft98.ir loaded in {}ms",
                                elapsed
                            ),
                        ));
                    }
                    _ => {
                        let _ = tx.send(AppEvent::Log(
                            LogLevel::Error,
                            "❌ Direct Connection Failed! Is your network blocked?".to_string(),
                        ));
                    }
                }
            }
        });
    }

    pub fn save_all_settings(&mut self) {
        if let Some(parent) = Path::new(CHANNELS_PATH).parent() {
            let _ = fs::create_dir_all(parent);
        }
        let _ = fs::write(CHANNELS_PATH, &self.channels_text);
        let _ = fs::write(SUBSCRIPTIONS_PATH, &self.subscriptions_text);
        if self.config.save().is_ok() {
            self.add_log(
                LogLevel::Success,
                "💾 All settings and targets saved successfully.".to_string(),
            );
        }
    }

    pub fn start(&mut self) {
        if self.running {
            return;
        }

        let xray_path = &self.config.tester.xray_knife_path;
        if self.config.tester.enabled && !Path::new(xray_path).exists() {
            self.add_log(LogLevel::Error, "⛔ Cannot start: Tester is enabled but xray-knife.exe is missing. Download it first!".to_string());
            return;
        }

        self.logs.clear();
        self.save_all_settings();

        self.stop_flag.store(false, Ordering::SeqCst);
        self.running = true;

        let tx = self.event_tx.clone();
        let cfg = self.config.clone();
        let channels_raw = self.channels_text.clone();
        let subscriptions_raw = self.subscriptions_text.clone();
        let stop_flag = self.stop_flag.clone();

        self.worker_handle = Some(thread::spawn(move || {
            if let Err(err) = run_worker(cfg, channels_raw, subscriptions_raw, stop_flag, tx.clone()) {
                let _ = tx.send(AppEvent::Log(LogLevel::Error, format!("🔥 CRASH: {}", err)));
            }
            let _ = tx.send(AppEvent::WorkerStopped);
        }));
    }

    pub fn stop(&mut self) {
        self.stop_flag.store(true, Ordering::SeqCst);
        self.add_log(
            LogLevel::Warning,
            "🛑 Stop signal sent. Interrupting all threads cleanly...".to_string(),
        );
    }

    pub fn add_log(&mut self, level: LogLevel, text: String) {
        self.logs.push(LogMessage {
            time: Local::now().format("%H:%M:%S").to_string(),
            level,
            text,
        });
    }

    pub fn poll_events(&mut self) {
        while let Ok(event) = self.event_rx.try_recv() {
            match event {
                AppEvent::Log(level, msg) => self.add_log(level, msg),
                AppEvent::Stats { total, by_protocol } => {
                    self.total_configs = total;
                    self.by_protocol = by_protocol;
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

pub fn apply_modern_theme(ctx: &egui::Context) {
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
                            egui::RichText::new("Modular Smart Engine - Phase 5")
                                .size(13.0)
                                .color(egui::Color32::from_rgb(120, 140, 160)),
                        );
                        ui.hyperlink_to("📣 Channel: @vpnclashfa", "https://t.me/vpnclashfa");
                    });

                    ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                        let btn_size = [150.0, 45.0];
                        let is_busy = self.running || self.is_downloading.load(Ordering::SeqCst);

                        if self.running {
                            if ui
                                .add_sized(
                                    btn_size,
                                    egui::Button::new(
                                        egui::RichText::new("⏹ STOP ENGINE")
                                            .size(15.0)
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
                            ui.add_enabled_ui(!is_busy, |ui| {
                                if ui
                                    .add_sized(
                                        btn_size,
                                        egui::Button::new(
                                            egui::RichText::new("▶ START ENGINE")
                                                .size(15.0)
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
                            });
                            if ui
                                .add_sized(
                                    [130.0, 45.0],
                                    egui::Button::new(
                                        egui::RichText::new("💾 Save Settings")
                                            .size(14.0)
                                            .strong()
                                            .color(egui::Color32::WHITE),
                                    )
                                    .fill(egui::Color32::from_rgb(60, 120, 200))
                                    .rounding(8.0),
                                )
                                .clicked()
                            {
                                self.save_all_settings();
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
                    ui.selectable_value(&mut self.active_tab, 3, "🔬 Tester");
                    ui.selectable_value(&mut self.active_tab, 4, "📤 Publisher");
                });
                ui.separator();
                egui::ScrollArea::vertical().show(ui, |ui| {
                    match self.active_tab {
                        0 => {
                            ui.add_space(5.0);
                            ui.heading(egui::RichText::new("💻 Performance Profile").color(egui::Color32::GOLD));

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

                            if profile_changed { self.config.apply_profile_defaults(); }

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
                            ui.heading(egui::RichText::new("🌐 Network & Proxy").color(egui::Color32::LIGHT_BLUE));

                            let mut proxy_changed = false;
                            ui.horizontal(|ui| {
                                egui::ComboBox::from_id_salt("proxy_type")
                                    .selected_text(match self.config.proxy_type {
                                        ProxyType::None => "Direct", ProxyType::System => "System Auto",
                                        ProxyType::Http => "HTTP", ProxyType::Socks5 => "SOCKS5",
                                    })
                                    .show_ui(ui, |ui| {
                                        if ui.selectable_value(&mut self.config.proxy_type, ProxyType::System, "System Auto").changed() { proxy_changed = true; }
                                        if ui.selectable_value(&mut self.config.proxy_type, ProxyType::Socks5, "SOCKS5").changed() { proxy_changed = true; }
                                        if ui.selectable_value(&mut self.config.proxy_type, ProxyType::Http, "HTTP").changed() { proxy_changed = true; }
                                        if ui.selectable_value(&mut self.config.proxy_type, ProxyType::None, "Direct").changed() { proxy_changed = true; }
                                    });

                                if ui.button("🔄 Test Proxy").clicked() { proxy_changed = true; }
                                if ui.button("🌐 Test Direct").clicked() { self.test_direct_connection(); }
                            });

                            if proxy_changed { self.test_connection(); }

                            if matches!(self.config.proxy_type, ProxyType::Http | ProxyType::Socks5) {
                                ui.horizontal(|ui| { ui.label("IP:"); ui.text_edit_singleline(&mut self.config.proxy_host); });
                                ui.horizontal(|ui| { ui.label("Port:"); ui.add(egui::DragValue::new(&mut self.config.proxy_port).range(1..=65535)); });
                            }
                            ui.checkbox(&mut self.config.ignore_ssl_errors, "Bypass SSL/TLS Filter (For VPNs)");

                            ui.add_space(15.0);
                            ui.heading(egui::RichText::new("📅 Scheduler & Dates").color(egui::Color32::LIGHT_BLUE));
                            ui.horizontal(|ui| { ui.label("Loop Interval (Min):"); ui.add(egui::DragValue::new(&mut self.config.interval_minutes).range(1..=240)); });
                            ui.horizontal(|ui| { ui.label("Max Pages/Channel:"); ui.add(egui::DragValue::new(&mut self.config.max_pages_per_channel).range(1..=100)); });
                            ui.horizontal(|ui| { ui.label("Lookback Days:"); ui.add(egui::DragValue::new(&mut self.config.lookback_days).range(0..=30)); });

                            ui.add_space(15.0);
                            ui.heading(egui::RichText::new("💾 Output Settings").color(egui::Color32::LIGHT_BLUE));
                            ui.horizontal(|ui| { ui.label("Folder:"); ui.text_edit_singleline(&mut self.config.output_directory).on_hover_text("Directory path to save results."); });
                            ui.checkbox(&mut self.config.output_new_only_enabled, "Save New Configs Only (new_only)");
                            ui.checkbox(&mut self.config.output_append_unique_enabled, "Backup Unique Configs (append_unique)");

                            ui.add_space(15.0);
                            ui.heading(egui::RichText::new("🔄 Application Update").color(egui::Color32::from_rgb(200, 150, 255)));
                            ui.horizontal(|ui| {
                                ui.label("GitHub Repo:");
                                ui.text_edit_singleline(&mut self.config.app_update_repo).on_hover_text("Format: username/repository");
                            });

                            ui.add_space(5.0);

                            if self.is_downloading.load(Ordering::SeqCst) {
                                ui.horizontal(|ui| {
                                    ui.spinner();
                                    ui.label(egui::RichText::new("Processing update... Please wait.").color(egui::Color32::YELLOW));
                                });
                            } else {
                                if ui.button(egui::RichText::new("🚀 Update Collector App").size(13.0).color(egui::Color32::WHITE)).clicked() {
                                    self.is_downloading.store(true, Ordering::SeqCst);

                                    let tx = self.event_tx.clone();
                                    let repo_name = self.config.app_update_repo.clone();
                                    let config_clone = self.config.clone();
                                    let downloading_flag = self.is_downloading.clone();

                                    thread::spawn(move || {
                                        match build_client(&config_clone) {
                                            Ok(client) => {
                                                if let Err(e) = crate::updater::update_main_app(client, repo_name, tx.clone()) {
                                                    let _ = tx.send(AppEvent::Log(
                                                        LogLevel::Error,
                                                        format!("❌ App Update Failed: {}", e)
                                                    ));
                                                }
                                            },
                                            Err(e) => {
                                                let _ = tx.send(AppEvent::Log(
                                                    LogLevel::Error,
                                                    format!("❌ Failed to build network client: {}", e)
                                                ));
                                            }
                                        }
                                        downloading_flag.store(false, Ordering::SeqCst);
                                    });
                                }
                            }
                        }
                        1 => {
                            ui.heading(egui::RichText::new("📥 Input Source").color(egui::Color32::LIGHT_BLUE));
                            ui.horizontal(|ui| {
                                ui.label("Mode:");
                                egui::ComboBox::from_id_salt("input_mode_combo")
                                    .selected_text(match self.config.input_mode {
                                        InputSourceMode::TelegramChannels => "Telegram channels",
                                        InputSourceMode::SubscriptionLinks => "Subscription links",
                                        InputSourceMode::LocalTextFolder => "Local text folder",
                                    })
                                    .show_ui(ui, |ui| {
                                        ui.selectable_value(
                                            &mut self.config.input_mode,
                                            InputSourceMode::TelegramChannels,
                                            "Telegram channels",
                                        );
                                        ui.selectable_value(
                                            &mut self.config.input_mode,
                                            InputSourceMode::SubscriptionLinks,
                                            "Subscription links",
                                        );
                                        ui.selectable_value(
                                            &mut self.config.input_mode,
                                            InputSourceMode::LocalTextFolder,
                                            "Local text folder",
                                        );
                                    });
                            });
                            ui.add_space(8.0);
                            match self.config.input_mode {
                                InputSourceMode::TelegramChannels => {
                                    ui.label(
                                        egui::RichText::new("One channel ID/Link per line:")
                                            .small()
                                            .color(egui::Color32::GRAY),
                                    );
                                    ui.add_sized(
                                        [ui.available_width(), ui.available_height() - 60.0],
                                        egui::TextEdit::multiline(&mut self.channels_text)
                                            .font(egui::TextStyle::Monospace),
                                    );
                                }
                                InputSourceMode::SubscriptionLinks => {
                                    ui.label(
                                        egui::RichText::new("One subscription URL per line:")
                                            .small()
                                            .color(egui::Color32::GRAY),
                                    );
                                    ui.add_sized(
                                        [ui.available_width(), ui.available_height() - 60.0],
                                        egui::TextEdit::multiline(&mut self.subscriptions_text)
                                            .font(egui::TextStyle::Monospace),
                                    );
                                }
                                InputSourceMode::LocalTextFolder => {
                                    ui.label(
                                        egui::RichText::new(
                                            "Select a local folder. All text files inside it will be scanned.",
                                        )
                                        .small()
                                        .color(egui::Color32::GRAY),
                                    );
                                    ui.horizontal(|ui| {
                                        ui.label("Folder path:");
                                        ui.text_edit_singleline(&mut self.config.local_text_folder);
                                    });
                                }
                            }
                        }
                        2 => {
                            ui.heading(egui::RichText::new("🎯 Phase 1 Protocols Filter").color(egui::Color32::LIGHT_BLUE));
                            ui.label(egui::RichText::new("Set Max Count to 0 for UNLIMITED").small().color(egui::Color32::GRAY));

                            for (name, rule) in &mut self.config.protocol_rules {
                                ui.horizontal(|ui| {
                                    ui.checkbox(&mut rule.enabled, name);
                                    ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                                        let response = ui.add(egui::DragValue::new(&mut rule.max_count).range(0..=500000));
                                        if rule.max_count == 0 {
                                            response.on_hover_text("0 = Unlimited");
                                            ui.label(egui::RichText::new("Unlimited").color(egui::Color32::from_rgb(60, 180, 120)).small());
                                        }
                                    });
                                });
                            }

                            ui.add_space(12.0);
                            ui.separator();
                            ui.add_space(8.0);
                            ui.heading(egui::RichText::new("🧩 Phase 4 - Clash Output Controls").color(egui::Color32::GOLD));
                            ui.checkbox(&mut self.config.clash_converter.enabled, "Enable Phase 3->4 Clash conversion output");
                            ui.checkbox(&mut self.config.clash_converter.output_full_config, "Output full Clash config (otherwise provider only)");
                            ui.horizontal(|ui| {
                                ui.label("Total convert limit (0=unlimited):");
                                ui.add(egui::DragValue::new(&mut self.config.clash_converter.total_limit).range(0..=200000));
                            });

                            for (proto, rule) in &mut self.config.clash_converter.protocol_rules {
                                ui.horizontal(|ui| {
                                    ui.checkbox(&mut rule.enabled, format!("{}", proto));
                                    ui.label("max:");
                                    ui.add(egui::DragValue::new(&mut rule.max_count).range(0..=100000));
                                    ui.label("priority:");
                                    ui.add(egui::DragValue::new(&mut rule.priority).range(1..=1000));
                                });
                            }
                        }
                        3 => {
                            ui.heading(egui::RichText::new("🔬 Phase 2 Tester Engine").color(egui::Color32::LIGHT_BLUE));
                            ui.label(egui::RichText::new("Validates scraped configs via xray-knife in DIRECT mode.\nConfigure core behavior, pings, and speedtests below.").small().color(egui::Color32::GRAY));
                            ui.add_space(10.0);

                            ui.checkbox(&mut self.config.tester.enabled, "Enable Xray-Knife Tester");

                            egui::Frame::none()
                                .fill(egui::Color32::from_rgb(25, 28, 40))
                                .rounding(6.0)
                                .inner_margin(10.0)
                                .show(ui, |ui| {
                                    ui.heading(egui::RichText::new("⚙ Engine Parameters").size(14.0).color(egui::Color32::from_rgb(200, 200, 200)));
                                    ui.add_space(4.0);
                                    
                                    ui.horizontal(|ui| {
                                        ui.label("Core Type:");
                                        egui::ComboBox::from_id_salt("core_type")
                                            .selected_text(match self.config.tester.core_type.as_str() {
                                                "xray" => "Xray-Core",
                                                "singbox" => "Sing-Box",
                                                _ => "Auto (Recommended)",
                                            })
                                            .show_ui(ui, |ui| {
                                                ui.selectable_value(&mut self.config.tester.core_type, "auto".to_string(), "Auto (Recommended)");
                                                ui.selectable_value(&mut self.config.tester.core_type, "xray".to_string(), "Xray-Core");
                                                ui.selectable_value(&mut self.config.tester.core_type, "singbox".to_string(), "Sing-Box");
                                            });
                                    });
                                    
                                    ui.horizontal(|ui| {
                                        ui.label("Concurrent Tests:");
                                        ui.add(egui::DragValue::new(&mut self.config.tester.concurrent_tests).range(1..=500));
                                        ui.label("  Retries:");
                                        ui.add(egui::DragValue::new(&mut self.config.tester.retries).range(0..=5));
                                    });
                                    
                                    ui.horizontal(|ui| {
                                        ui.label("Max Delay (ms):");
                                        ui.add(egui::DragValue::new(&mut self.config.tester.max_delay_ms).range(100..=30000))
                                            .on_hover_text("Max acceptable ping (-d flag). Configs slower than this will fail.");
                                        ui.label("  Timeout (s):");
                                        ui.add(egui::DragValue::new(&mut self.config.tester.timeout_secs).range(1..=60));
                                    });

                                    ui.add_space(8.0);
                                    ui.separator();
                                    ui.add_space(8.0);

                                    ui.heading(egui::RichText::new("📍 Ping Test").size(14.0).color(egui::Color32::from_rgb(200, 200, 200)));
                                    ui.add_space(4.0);
                                    ui.checkbox(&mut self.config.tester.ping_test_enabled, "Enable Ping Test");
                                    ui.horizontal(|ui| {
                                        ui.label("Ping URL:");
                                        ui.text_edit_singleline(&mut self.config.tester.ping_test_url);
                                    });
                                    ui.horizontal(|ui| {
                                        ui.label("Ping Preset:");
                                        egui::ComboBox::from_id_salt("ping_preset")
                                            .selected_text(match self.config.tester.ping_url_preset {
                                                1 => "Telegram favicon",
                                                2 => "Telegram homepage",
                                                3 => "Google generate_204",
                                                4 => "Cloudflare trace",
                                                _ => "Custom",
                                            })
                                            .show_ui(ui, |ui| {
                                                if ui.selectable_value(&mut self.config.tester.ping_url_preset, 1, "Telegram favicon").clicked() { self.config.tester.ping_test_url = "https://telegram.org/favicon.ico".to_string(); }
                                                if ui.selectable_value(&mut self.config.tester.ping_url_preset, 2, "Telegram homepage").clicked() { self.config.tester.ping_test_url = "https://telegram.org/".to_string(); }
                                                if ui.selectable_value(&mut self.config.tester.ping_url_preset, 3, "Google generate_204").clicked() { self.config.tester.ping_test_url = "https://www.gstatic.com/generate_204".to_string(); }
                                                if ui.selectable_value(&mut self.config.tester.ping_url_preset, 4, "Cloudflare trace").clicked() { self.config.tester.ping_test_url = "https://1.1.1.1/cdn-cgi/trace".to_string(); }
                                                ui.selectable_value(&mut self.config.tester.ping_url_preset, 0, "Custom");
                                            });
                                    });

                                    ui.add_space(8.0);
                                    ui.separator();
                                    ui.add_space(8.0);

                                    ui.heading(egui::RichText::new("🚀 Speed Test").size(14.0).color(egui::Color32::from_rgb(200, 200, 200)));
                                    ui.add_space(4.0);
                                    ui.checkbox(&mut self.config.tester.speed_test_enabled, "Enable Speed Test (-p)");
                                    ui.checkbox(&mut self.config.tester.speed_test_from_ping_passed_only, "Chain Mode: Speed test only from ping-passed configs");
                                    ui.horizontal(|ui| {
                                        ui.label("Speed URL:");
                                        ui.text_edit_singleline(&mut self.config.tester.speed_test_url);
                                    });
                                    ui.horizontal(|ui| {
                                        ui.label("Speed Preset:");
                                        egui::ComboBox::from_id_salt("speed_preset")
                                            .selected_text(match self.config.tester.speed_url_preset {
                                                1 => "Telegram web app js",
                                                2 => "Cloudflare 10MB",
                                                3 => "Hetzner 10MB",
                                                4 => "ThinkBroadband 5MB",
                                                _ => "Custom",
                                            })
                                            .show_ui(ui, |ui| {
                                                if ui.selectable_value(&mut self.config.tester.speed_url_preset, 1, "Telegram web app js").clicked() { self.config.tester.speed_test_url = "https://telegram.org/js/telegram-web-app.js".to_string(); self.config.tester.speed_url_supports_bytes_query = false; }
                                                if ui.selectable_value(&mut self.config.tester.speed_url_preset, 2, "Cloudflare 10MB").clicked() { self.config.tester.speed_test_url = "https://speed.cloudflare.com/__down".to_string(); self.config.tester.speed_url_supports_bytes_query = true; }
                                                if ui.selectable_value(&mut self.config.tester.speed_url_preset, 3, "Hetzner 10MB").clicked() { self.config.tester.speed_test_url = "https://speed.hetzner.de/10MB.bin".to_string(); self.config.tester.speed_url_supports_bytes_query = false; }
                                                if ui.selectable_value(&mut self.config.tester.speed_url_preset, 4, "ThinkBroadband 5MB").clicked() { self.config.tester.speed_test_url = "https://ipv4.download.thinkbroadband.com/5MB.zip".to_string(); self.config.tester.speed_url_supports_bytes_query = false; }
                                                ui.selectable_value(&mut self.config.tester.speed_url_preset, 0, "Custom");
                                            });
                                    });
                                    
                                    ui.checkbox(&mut self.config.tester.speed_url_supports_bytes_query, "Append bytes query to URL ({bytes})");
                                    ui.horizontal(|ui| {
                                        ui.label("DL Amount (KB):")
                                            .on_hover_text("-a flag. Sets the size of the download file in KB.");
                                        ui.add(egui::DragValue::new(&mut self.config.tester.speed_test_amount_kb).range(10..=100_000));
                                    });
                                    
                                    ui.horizontal(|ui| {
                                        ui.label("Batch Size:");
                                        ui.add(egui::DragValue::new(&mut self.config.tester.speed_test_batch_size).range(1..=100));
                                        ui.label("  Timeout (s):");
                                        ui.add(egui::DragValue::new(&mut self.config.tester.speed_test_timeout_secs).range(1..=60));
                                    });
                                    ui.horizontal(|ui| {
                                        ui.label("Top by Ping for Speed:");
                                        ui.add(egui::DragValue::new(&mut self.config.tester.speed_test_top_count).range(1..=10_000));
                                    });
                                    
                                    ui.add_space(8.0);
                                    ui.separator();
                                    ui.add_space(8.0);
                                    
                                    ui.heading(egui::RichText::new("🔧 Advanced Flags").size(14.0).color(egui::Color32::from_rgb(200, 200, 200)));
                                    ui.add_space(4.0);

                                    ui.checkbox(&mut self.config.tester.resolve_real_ip, "Resolve Real IP & Location (-r)");
                                    ui.checkbox(&mut self.config.tester.allow_insecure, "Allow Insecure TLS (--insecure)")
                                        .on_hover_text("Bypasses invalid SSL certificates. Crucial for finding free/leaked Telegram configs.");
                                        
                                    ui.horizontal(|ui| {
                                        ui.label("Extra args:");
                                        ui.text_edit_singleline(&mut self.config.tester.extra_xray_args)
                                            .on_hover_text("Any extra flags supported by xray-knife http (advanced). Example: --xfdb");
                                    });
                                    
                                    ui.add_space(4.0);
                                    ui.heading(egui::RichText::new("🏷️ Naming & Tags").size(14.0).color(egui::Color32::from_rgb(200, 200, 200)));
                                    ui.checkbox(&mut self.config.tester.append_ping_flag, "Append Ping to Config Name");
                                    ui.checkbox(&mut self.config.tester.append_speed_flag, "Append Download Speed to Config Name");
                                    ui.checkbox(&mut self.config.tester.append_country_flag, "Append Country Flag Emoji to Config Name");
                                });

                            ui.add_space(20.0);
                            ui.separator();
                            ui.add_space(10.0);

                            ui.heading(egui::RichText::new("Core Downloader").color(egui::Color32::GOLD));

                            ui.horizontal(|ui| {
                                ui.label("Binary Path:");
                                ui.text_edit_singleline(&mut self.config.tester.xray_knife_path);
                            });

                            ui.add_space(15.0);

                            if self.is_downloading.load(Ordering::SeqCst) {
                                ui.horizontal(|ui| {
                                    ui.spinner();
                                    ui.label(egui::RichText::new("Downloading & Extracting... Please wait.").color(egui::Color32::YELLOW));
                                });
                            } else {
                                if ui.button(egui::RichText::new("📥 Download / Update xray-knife").size(14.0).color(egui::Color32::WHITE)).clicked() {
                                    self.is_downloading.store(true, Ordering::SeqCst);

                                    let tx = self.event_tx.clone();
                                    let target_path = self.config.tester.xray_knife_path.clone();
                                    let config_clone = self.config.clone();
                                    let downloading_flag = self.is_downloading.clone();

                                    thread::spawn(move || {
                                        match build_client(&config_clone) {
                                            Ok(client) => {
                                                if let Err(e) = crate::updater::update_xray_knife(client, target_path, tx.clone()) {
                                                    let _ = tx.send(AppEvent::Log(
                                                        LogLevel::Error,
                                                        format!("❌ Download Failed: {}", e)
                                                    ));
                                                }
                                            },
                                            Err(e) => {
                                                let _ = tx.send(AppEvent::Log(
                                                    LogLevel::Error,
                                                    format!("❌ Failed to build network client for download: {}", e)
                                                ));
                                            }
                                        }
                                        downloading_flag.store(false, Ordering::SeqCst);
                                    });
                                }
                            }
                        }

                        4 => {
                            ui.heading(egui::RichText::new("📤 Phase 5 - Telegram Publisher").color(egui::Color32::LIGHT_BLUE));
                            ui.label(egui::RichText::new("Sends output/tested/new_only/mixed.txt to your Telegram channel/group via bot API using app proxy settings.").small().color(egui::Color32::GRAY));
                            ui.label(egui::RichText::new("If you get chat not found: add bot to channel/group, grant post permission, then use @channelusername (public) or -100... id (private).").small().color(egui::Color32::from_rgb(250, 190, 70)));
                            ui.add_space(8.0);

                            ui.checkbox(&mut self.config.phase5_telegram.enabled, "Enable Phase 5 Telegram Publish");
                            ui.horizontal(|ui| {
                                ui.label("Bot Token:");
                                ui.text_edit_singleline(&mut self.config.phase5_telegram.bot_token);
                            });
                            ui.horizontal(|ui| {
                                ui.label("Chat ID (@channel or -100...):");
                                ui.text_edit_singleline(&mut self.config.phase5_telegram.chat_id);
                            });
                            ui.horizontal(|ui| {
                                ui.label("Configs per post:");
                                ui.add(egui::DragValue::new(&mut self.config.phase5_telegram.post_config_count).range(1..=200));
                            });

                            ui.separator();
                            ui.checkbox(&mut self.config.phase5_telegram.header_enabled, "Enable custom first line");
                            ui.add_enabled_ui(self.config.phase5_telegram.header_enabled, |ui| {
                                ui.text_edit_singleline(&mut self.config.phase5_telegram.header_text);
                            });

                            ui.checkbox(&mut self.config.phase5_telegram.footer_enabled, "Enable custom last line");
                            ui.add_enabled_ui(self.config.phase5_telegram.footer_enabled, |ui| {
                                ui.text_edit_singleline(&mut self.config.phase5_telegram.footer_text);
                            });

                            ui.add_space(6.0);
                            ui.label(egui::RichText::new("Tip: Configs are posted inside <pre> block so each line is one config and easy one-tap copy.").small().color(egui::Color32::from_rgb(160, 210, 255)));
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
                });

                ui.add_space(10.0);
                egui::Frame::none()
                    .fill(egui::Color32::from_rgb(8, 10, 15))
                    .rounding(8.0)
                    .inner_margin(10.0)
                    .show(ui, |ui| {
                        ui.horizontal(|ui| {
                            ui.heading(
                                egui::RichText::new("Terminal Log").color(egui::Color32::WHITE),
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
                                    let base_color = match log.level {
                                        LogLevel::Debug => egui::Color32::from_rgb(100, 110, 130),
                                        LogLevel::Info => egui::Color32::from_rgb(120, 200, 255),
                                        LogLevel::Success => egui::Color32::from_rgb(80, 240, 150),
                                        LogLevel::Warning => egui::Color32::from_rgb(250, 190, 70),
                                        LogLevel::Error => egui::Color32::from_rgb(255, 90, 90),
                                    };
                                    let text_lower = log.text.to_ascii_lowercase();
                                    let color = if text_lower.contains("passed=")
                                        || text_lower.contains("final_passed")
                                        || text_lower.contains("sent_configs=")
                                        || text_lower.contains("post ")
                                    {
                                        egui::Color32::from_rgb(255, 220, 90)
                                    } else {
                                        base_color
                                    };
                                    ui.horizontal_wrapped(|ui| {
                                        ui.label(
                                            egui::RichText::new(format!("[{}]", log.time))
                                                .color(egui::Color32::from_rgb(80, 90, 110))
                                                .monospace()
                                                .small(),
                                        );
                                        ui.label(
                                            egui::RichText::new(&log.text).color(color).monospace(),
                                        );
                                    });
                                }
                            });
                    });
            });
        ctx.request_repaint_after(Duration::from_millis(500));
    }
}
