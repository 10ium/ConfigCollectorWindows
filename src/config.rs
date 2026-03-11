use anyhow::Result;
use chrono::{DateTime, Duration as ChronoDuration, Utc};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::fs;
use std::path::Path;

pub const APP_CONFIG_PATH: &str = "config/app_config.toml";
pub const CHANNELS_PATH: &str = "config/channels.txt";
pub const HISTORY_PATH: &str = "config/sent_history.json";
pub const MEMORY_PATH: &str = "config/channel_memory.json";

pub const DEFAULT_TARGETS: &str = "@IranProxyPlus\nhttps://t.me/filembad\nhttps://t.me/persianvpnhub\nhttps://t.me/Speeds_vpn1\n@SOSkeyNET\nhttps://t.me/vasl_bashim\n@configraygan\nhttps://t.me/AR14N24B";

pub const DEFAULT_PROTOCOLS: [&str; 27] = [
    "vmess",
    "vless",
    "trojan",
    "ss",
    "ssr",
    "tuic",
    "hysteria",
    "hysteria2",
    "hy2",
    "juicity",
    "snell",
    "anytls",
    "ssh",
    "wireguard",
    "wg",
    "warp",
    "socks",
    "socks4",
    "socks5",
    "tg",
    "dns",
    "nm-dns",
    "nm-vless",
    "slipnet-enc",
    "slipnet",
    "slipstream",
    "dnstt",
];

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum ProxyType {
    None,
    System,
    Http,
    Socks5,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum PerformanceProfile {
    WeakPC,
    MediumPC,
    StrongPC,
    Custom,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ProtocolRule {
    pub enabled: bool,
    pub max_count: usize, // 0 یعنی نامحدود
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(default)]
pub struct TesterConfig {
    pub enabled: bool,
    pub concurrent_tests: usize,
    pub timeout_secs: u64,
    pub test_url: String,
    pub ping_test_enabled: bool,
    pub ping_test_url: String,
    pub ping_url_preset: u8,
    pub speed_test_enabled: bool,
    pub speed_test_url: String,
    pub speed_url_preset: u8,
    pub speed_url_supports_bytes_query: bool,
    pub speed_test_download_bytes: u64,
    pub speed_test_top_count: usize,
    pub speed_test_batch_size: usize,
    pub speed_test_timeout_secs: u64,
    pub append_ping_flag: bool,
    pub append_speed_flag: bool,
    pub append_country_flag: bool,
    pub extra_xray_args: String,
    pub xray_knife_path: String,
}

impl Default for TesterConfig {
    fn default() -> Self {
        Self {
            enabled: true,
            concurrent_tests: 10,
            timeout_secs: 6,
            test_url: "https://telegram.org/".to_string(),
            ping_test_enabled: false,
            ping_test_url: "https://telegram.org/favicon.ico".to_string(),
            ping_url_preset: 1,
            speed_test_enabled: true,
            speed_test_url: "https://telegram.org/js/telegram-web-app.js".to_string(),
            speed_url_preset: 1,
            speed_url_supports_bytes_query: false,
            speed_test_download_bytes: 5_000_000,
            speed_test_top_count: 300,
            speed_test_batch_size: 10,
            speed_test_timeout_secs: 6,
            append_ping_flag: false,
            append_speed_flag: false,
            append_country_flag: false,
            extra_xray_args: "".to_string(),
            xray_knife_path: if cfg!(windows) {
                "xray-knife.exe".to_string()
            } else {
                "xray-knife".to_string()
            },
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(default)]
pub struct AppConfig {
    pub interval_minutes: u64,
    pub max_pages_per_channel: usize,
    pub lookback_days: i64,
    pub proxy_type: ProxyType,
    pub proxy_host: String,
    pub proxy_port: u16,
    pub performance: PerformanceProfile,
    pub delay_ms: u64,
    pub timeout_secs: u64,
    pub concurrent_channels: usize,
    pub ignore_ssl_errors: bool,
    pub remote_dns: bool,
    pub output_directory: String,
    pub output_new_only_enabled: bool,
    pub output_append_unique_enabled: bool,
    pub app_update_repo: String, // جایگزین شدن لینک مستقیم با نام مخزن گیت‌هاب
    pub protocol_rules: BTreeMap<String, ProtocolRule>,
    pub tester: TesterConfig,
}

impl Default for AppConfig {
    fn default() -> Self {
        let mut protocol_rules = BTreeMap::new();
        for p in DEFAULT_PROTOCOLS {
            protocol_rules.insert(
                p.to_string(),
                ProtocolRule {
                    enabled: true,
                    max_count: 0,
                },
            );
        }
        Self {
            interval_minutes: 5,
            max_pages_per_channel: 10,
            lookback_days: 1,
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
            app_update_repo: "10ium/ConfigCollectorWindows".to_string(),
            protocol_rules,
            tester: TesterConfig::default(),
        }
    }
}

impl AppConfig {
    pub fn load_or_create() -> Self {
        if let Ok(raw) = fs::read_to_string(APP_CONFIG_PATH) {
            if let Ok(mut cfg) = toml::from_str::<Self>(&raw) {
                for p in DEFAULT_PROTOCOLS {
                    cfg.protocol_rules
                        .entry(p.to_string())
                        .or_insert(ProtocolRule {
                            enabled: true,
                            max_count: 0,
                        });
                }
                return cfg;
            }
        }
        let cfg = Self::default();
        let _ = cfg.save();
        cfg
    }

    pub fn save(&self) -> Result<()> {
        if let Some(parent) = Path::new(APP_CONFIG_PATH).parent() {
            fs::create_dir_all(parent)?;
        }
        fs::write(APP_CONFIG_PATH, toml::to_string_pretty(self)?)?;
        Ok(())
    }

    pub fn apply_profile_defaults(&mut self) {
        match self.performance {
            PerformanceProfile::WeakPC => {
                self.delay_ms = 5000;
                self.timeout_secs = 30;
                self.concurrent_channels = 1;
                self.tester.concurrent_tests = 3;
            }
            PerformanceProfile::MediumPC => {
                self.delay_ms = 2000;
                self.timeout_secs = 15;
                self.concurrent_channels = 3;
                self.tester.concurrent_tests = 10;
            }
            PerformanceProfile::StrongPC => {
                self.delay_ms = 500;
                self.timeout_secs = 10;
                self.concurrent_channels = 8;
                self.tester.concurrent_tests = 25;
            }
            PerformanceProfile::Custom => {}
        }
    }
}

// -------------------------------------------------------------
// ساختار حافظه هوشمند (Smart Memory)
// -------------------------------------------------------------
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct ChannelMemory {
    pub last_seen_ids: BTreeMap<String, u64>,
}

impl ChannelMemory {
    pub fn load() -> Self {
        if let Ok(raw) = fs::read_to_string(MEMORY_PATH) {
            if let Ok(v) = serde_json::from_str::<Self>(&raw) {
                return v;
            }
        }
        Self::default()
    }

    pub fn save(&self) -> Result<()> {
        if let Some(parent) = Path::new(MEMORY_PATH).parent() {
            fs::create_dir_all(parent)?;
        }
        fs::write(MEMORY_PATH, serde_json::to_string_pretty(self)?)?;
        Ok(())
    }
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct SentHistory {
    pub sent_at: BTreeMap<String, DateTime<Utc>>,
}

impl SentHistory {
    pub fn load() -> Self {
        if let Ok(raw) = fs::read_to_string(HISTORY_PATH) {
            if let Ok(v) = serde_json::from_str::<Self>(&raw) {
                return v;
            }
        }
        Self::default()
    }

    pub fn prune(&mut self, lookback_days: i64) {
        let threshold = Utc::now() - ChronoDuration::days(lookback_days.max(0));
        self.sent_at.retain(|_, ts| *ts >= threshold);
    }

    pub fn save(&self) -> Result<()> {
        if let Some(parent) = Path::new(HISTORY_PATH).parent() {
            fs::create_dir_all(parent)?;
        }
        fs::write(HISTORY_PATH, serde_json::to_string_pretty(self)?)?;
        Ok(())
    }
}
