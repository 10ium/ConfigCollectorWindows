use anyhow::Result;
use chrono::{DateTime, Duration as ChronoDuration, Utc};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::fs;
use std::path::Path;

pub const APP_CONFIG_PATH: &str = "config/app_config.toml";
pub const CHANNELS_PATH: &str = "config/channels.txt";
pub const SUBSCRIPTIONS_PATH: &str = "config/subscriptions.txt";
pub const HISTORY_PATH: &str = "config/sent_history.json";
pub const MEMORY_PATH: &str = "config/channel_memory.json";

pub const DEFAULT_TARGETS: &str = "@AHWAZIConnect\n@AKLISvpn\n@AR14N24B\n@AzadNet\n@BahamestanAzadi\n@BugFreeNet\n@Capoit\n@Config724\n@DarcProxy\n@DirectVPN\n@Express_freevpn\n@Filter_breaker\n@Go_vpns\n@Gozarnetir\n@HOKM_AKHAR\n@Hiddify_Nexttt\n@IranProxyPlus\n@KIA_NET\n@KW1VPN\n@Khosrow_vpn\n@LagVPN\n@LetIranBreath\n@Lx3vpn\n@MARAMBASHI\n@Masyakata\n@MatinSenPaii\n@Maznet\n@MerlinVpn\n@NetAccount\n@PathToArrive\n@PewezaVPN\n@PrivateVPNs\n@ProfxPsiphon\n@ProxyFa10\n@SOSkeyNET\n@SamnetInternet\n@ShadowProxy66\n@ShadowSocks_s\n@SorushVpn\n@Speeds_vpn1\n@V2ray20261\n@V2rayEnglish\n@V2raybazi\n@VPN_KING_V2RAY\n@Varkana0\n@Vpn_Sky\n@Vpn_m2s\n@Wpnfa\n@XV2RAY\n@acccrd\n@airdrop2033\n@allworldcfg\n@amir_webstudio\n@anty_filter\n@asrnovin_ir\n@chillguy_vpn\n@club_profsor\n@configfa\n@configraygan\n@filembad\n@free_fastvpn\n@free_netplus\n@freedom_soldiers1\n@freev2config\n@habsiop\n@hacknashidd\n@hamedvpns\n@i10VPN\n@iVPN26\n@irFreeProxy\n@irazadd\n@irdnstt\n@isprox\n@llFreak\n@meliproxyy\n@mindism\n@mypremium98\n@net_cir\n@our_time_is_now\n@persianvpnhub\n@proxy_kafee\n@proxy_online_net\n@prrofile_purple\n@saministamm\n@sinavm\n@tel_melli\n@v2FreeHub\n@v2nodes\n@vasl_bashim\n@vaslbashi\n@vmessorg\n@wiki_tajrobe\n@xsfilternet\n@yebekhe\n@zede_filteri";

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
pub enum InputSourceMode {
    TelegramChannels,
    SubscriptionLinks,
    LocalTextFolder,
}

impl Default for InputSourceMode {
    fn default() -> Self {
        Self::TelegramChannels
    }
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

    pub core_type: String,     
    pub max_delay_ms: u32,     
    pub retries: u16,          
    pub resolve_real_ip: bool, 

    pub timeout_secs: u64, 
    pub test_url: String,

    pub ping_test_enabled: bool,
    pub ping_test_url: String,
    pub ping_url_preset: u8,

    pub speed_test_enabled: bool,
    pub speed_test_url: String,
    pub speed_url_preset: u8,
    pub speed_url_supports_bytes_query: bool,

    pub speed_test_amount_kb: u32, 
    pub speed_test_top_count: usize,
    pub speed_test_batch_size: usize,
    pub speed_test_timeout_secs: u64, 

    pub append_ping_flag: bool,
    pub append_speed_flag: bool,
    pub append_country_flag: bool,
    pub speed_test_from_ping_passed_only: bool,

    pub extra_xray_args: String,
    pub xray_knife_path: String,
    pub allow_insecure: bool, 
    pub xray_verbose_logs: bool,
    pub show_xray_window_on_windows: bool,
    pub progress_log_step_percent: u8,
    
    pub notify_on_found: bool,
    pub beep_on_found: bool,
}

impl Default for TesterConfig {
    /// پیش‌فرض بهینه شرایط عادی (Normal Conditions) الهام‌گرفته از لاگ خروجی موفق شما
    fn default() -> Self {
        Self {
            enabled: true,
            concurrent_tests: 50, // بر اساس لاگ شما

            core_type: "auto".to_string(),
            max_delay_ms: 5000,   // بر اساس لاگ شما (۵ ثانیه)
            retries: 1,           // بر اساس لاگ شما
            resolve_real_ip: true,// بر اساس لاگ شما (IP Info: true)

            timeout_secs: 10,
            test_url: "https://cloudflare.com/cdn-cgi/trace".to_string(), // بر اساس لاگ شما

            ping_test_enabled: true,
            ping_test_url: "https://cloudflare.com/cdn-cgi/trace".to_string(), // بر اساس لاگ شما
            ping_url_preset: 4,

            speed_test_enabled: false,
            speed_test_url: "https://speed.cloudflare.com/__down".to_string(),
            speed_url_preset: 0,
            speed_url_supports_bytes_query: true,

            speed_test_amount_kb: 5000, 
            speed_test_top_count: 300,
            speed_test_batch_size: 10,
            speed_test_timeout_secs: 10,

            append_ping_flag: true,
            append_speed_flag: true,
            append_country_flag: true,
            speed_test_from_ping_passed_only: false,

            extra_xray_args: "".to_string(),
            xray_knife_path: if cfg!(windows) {
                "xray-knife.exe".to_string()
            } else {
                "xray-knife".to_string()
            },
            allow_insecure: false, // بر اساس لاگ شما (Insecure TLS: false)
            xray_verbose_logs: false,
            show_xray_window_on_windows: true,
            progress_log_step_percent: 2,
            
            notify_on_found: false,
            beep_on_found: false,
        }
    }
}

impl TesterConfig {
    /// اعمال دستی تنظیمات شرایط عادی (منطبق با لاگ موفق)
    pub fn apply_normal_preset(&mut self) {
        self.concurrent_tests = 50;
        self.max_delay_ms = 5000;
        self.retries = 1;
        self.resolve_real_ip = true;
        self.timeout_secs = 10;
        self.test_url = "https://cloudflare.com/cdn-cgi/trace".to_string();
        self.ping_test_url = "https://cloudflare.com/cdn-cgi/trace".to_string();
        self.ping_url_preset = 4;
        self.allow_insecure = false;
    }

    /// اعمال دستی تنظیمات شرایط حاد (پروفایل سنگین قدیمی)
    pub fn apply_extreme_preset(&mut self) {
        self.concurrent_tests = 100;
        self.max_delay_ms = 30000; // ۳۰ ثانیه تاخیر مجاز
        self.retries = 2;
        self.resolve_real_ip = true;
        self.timeout_secs = 60;
        self.test_url = "https://telegram.org/".to_string();
        self.ping_test_url = "https://telegram.org/favicon.ico".to_string();
        self.ping_url_preset = 1;
        self.allow_insecure = true;
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(default)]
pub struct ClashProtocolRule {
    pub enabled: bool,
    pub max_count: usize,
    pub priority: usize,
}

impl Default for ClashProtocolRule {
    fn default() -> Self {
        Self {
            enabled: true,
            max_count: 0,
            priority: 99,
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(default)]
pub struct ClashConverterConfig {
    pub enabled: bool,
    pub output_full_config: bool,
    pub total_limit: usize,
    pub protocol_rules: BTreeMap<String, ClashProtocolRule>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(default)]
pub struct Phase5TelegramConfig {
    pub enabled: bool,
    pub bot_token: String,
    pub chat_id: String,
    pub post_config_count: usize,
    pub header_enabled: bool,
    pub header_text: String,
    pub footer_enabled: bool,
    pub footer_text: String,
}

impl Default for Phase5TelegramConfig {
    fn default() -> Self {
        Self {
            enabled: false,
            bot_token: "".to_string(),
            chat_id: "".to_string(),
            post_config_count: 10,
            header_enabled: false,
            header_text: "".to_string(),
            footer_enabled: false,
            footer_text: "".to_string(),
        }
    }
}

impl Default for ClashConverterConfig {
    fn default() -> Self {
        let mut protocol_rules = BTreeMap::new();
        let defaults = [
            ("vless", 1usize),
            ("ss", 2),
            ("trojan", 3),
            ("vmess", 4),
            ("hysteria2", 5),
        ];

        for (name, prio) in defaults {
            protocol_rules.insert(
                name.to_string(),
                ClashProtocolRule {
                    enabled: true,
                    max_count: 0,
                    priority: prio,
                },
            );
        }

        Self {
            enabled: true,
            output_full_config: true,
            total_limit: 0,
            protocol_rules,
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(default)]
pub struct AppConfig {
    pub input_mode: InputSourceMode,
    pub local_text_folder: String,
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
    pub app_update_repo: String,
    pub protocol_rules: BTreeMap<String, ProtocolRule>,
    pub tester: TesterConfig,
    pub clash_converter: ClashConverterConfig,
    pub phase5_telegram: Phase5TelegramConfig,
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
            input_mode: InputSourceMode::LocalTextFolder,
            local_text_folder: "d:\\ConfigCollectorWindowsnew\\list config".to_string(),
            interval_minutes: 15,
            max_pages_per_channel: 10,
            lookback_days: 1,
            proxy_type: ProxyType::None,
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
            clash_converter: ClashConverterConfig::default(),
            phase5_telegram: Phase5TelegramConfig::default(),
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
                for (name, prio) in [
                    ("vless", 1usize),
                    ("ss", 2),
                    ("trojan", 3),
                    ("vmess", 4),
                    ("hysteria2", 5),
                ] {
                    cfg.clash_converter
                        .protocol_rules
                        .entry(name.to_string())
                        .or_insert(ClashProtocolRule {
                            enabled: true,
                            max_count: 0,
                            priority: prio,
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
                self.tester.concurrent_tests = 20;
            }
            PerformanceProfile::MediumPC => {
                self.delay_ms = 2000;
                self.timeout_secs = 15;
                self.concurrent_channels = 3;
                self.tester.concurrent_tests = 50;
            }
            PerformanceProfile::StrongPC => {
                self.delay_ms = 500;
                self.timeout_secs = 10;
                self.concurrent_channels = 8;
                self.tester.concurrent_tests = 100;
            }
            PerformanceProfile::Custom => {}
        }
    }
}

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
