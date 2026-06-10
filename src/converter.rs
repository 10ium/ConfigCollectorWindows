use base64::{engine::general_purpose::STANDARD as B64, Engine};
use serde_json::{json, Map, Value};
use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::Path;
use std::sync::mpsc::Sender;

use crate::config::ClashConverterConfig;
use crate::scraper::{log_worker, AppEvent, LogLevel};

fn normalize_base64(v: &str) -> Option<String> {
    let mut s = v
        .trim()
        .replace('-', "+")
        .replace('_', "/")
        .replace(' ', "");
    if s.is_empty() {
        return None;
    }
    let pad = s.len() % 4;
    if pad == 2 {
        s.push_str("==");
    } else if pad == 3 {
        s.push('=');
    } else if pad == 1 {
        return None;
    }
    let decoded = B64.decode(s).ok()?;
    String::from_utf8(decoded).ok()
}

/// دکدر درصد فوق هوشمند و چندبایتی (Multi-byte UTF-8) برای نمایش بی‌نقص اموجی‌ها و متون خاص در تبدیل کلش
fn safe_decode(s: &str) -> String {
    let mut bytes = Vec::new();
    let mut chars = s.chars().peekable();
    while let Some(c) = chars.next() {
        if c == '%' {
            let mut hex = String::new();
            if let Some(h1) = chars.next() {
                hex.push(h1);
            }
            if let Some(h2) = chars.next() {
                hex.push(h2);
            }
            if let Ok(byte) = u8::from_str_radix(&hex, 16) {
                bytes.push(byte);
            } else {
                bytes.extend_from_slice(b"%");
                bytes.extend_from_slice(hex.as_bytes());
            }
        } else if c == '+' {
            bytes.push(b' ');
        } else {
            let mut buf = [0; 4];
            bytes.extend_from_slice(c.encode_utf8(&mut buf).as_bytes());
        }
    }
    String::from_utf8_lossy(&bytes).trim().to_string()
}

fn parse_vless(link: &str) -> Option<Value> {
    let url = reqwest::Url::parse(&link.replacen("vless://", "http://", 1)).ok()?;
    let security = url
        .query_pairs()
        .find(|(k, _)| k == "security")
        .map(|(_, v)| v.to_string())
        .unwrap_or_default();
    let network = url
        .query_pairs()
        .find(|(k, _)| k == "type")
        .map(|(_, v)| v.to_string())
        .unwrap_or_else(|| "tcp".to_string());
    let mut obj = Map::new();
    obj.insert(
        "name".into(),
        json!(safe_decode(
            url.fragment().unwrap_or(url.host_str().unwrap_or("vless"))
        )),
    );
    obj.insert("type".into(), json!("vless"));
    obj.insert("server".into(), json!(url.host_str()?));
    obj.insert("port".into(), json!(url.port().unwrap_or(443)));
    obj.insert("uuid".into(), json!(url.username()));
    obj.insert("udp".into(), json!(true));
    obj.insert(
        "tls".into(),
        json!(security == "tls" || security == "reality"),
    );
    obj.insert("network".into(), json!(network.clone()));
    if let Some((_, sni)) = url.query_pairs().find(|(k, _)| k == "sni") {
        obj.insert("servername".into(), json!(sni.to_string()));
    }
    if let Some((_, fp)) = url.query_pairs().find(|(k, _)| k == "fp") {
        obj.insert("client-fingerprint".into(), json!(fp.to_string()));
    }
    if security == "reality" {
        let pbk = url
            .query_pairs()
            .find(|(k, _)| k == "pbk")
            .map(|(_, v)| v.to_string())
            .unwrap_or_default();
        let mut reality = Map::new();
        reality.insert("public-key".into(), json!(pbk));
        if let Some((_, sid)) = url.query_pairs().find(|(k, _)| k == "sid") {
            reality.insert("short-id".into(), json!(sid.to_string()));
        }
        obj.insert("reality-opts".into(), Value::Object(reality));
    }
    Some(Value::Object(obj))
}

fn parse_vmess(link: &str) -> Option<Value> {
    let raw = link.trim_start_matches("vmess://");
    let decoded = normalize_base64(raw)?;
    let j: Value = serde_json::from_str(&decoded).ok()?;
    Some(json!({
        "name": j.get("ps").and_then(|v| v.as_str()).map(|s| safe_decode(s)).unwrap_or(j.get("add").and_then(|v| v.as_str()).unwrap_or("vmess").to_string()),
        "type": "vmess",
        "server": j.get("add").and_then(|v| v.as_str()).unwrap_or(""),
        "port": j.get("port").and_then(|v| v.as_str()).and_then(|p| p.parse::<u16>().ok()).unwrap_or(443),
        "uuid": j.get("id").and_then(|v| v.as_str()).unwrap_or(""),
        "alterId": j.get("aid").and_then(|v| v.as_str()).and_then(|p| p.parse::<u16>().ok()).unwrap_or(0),
        "cipher": j.get("scy").and_then(|v| v.as_str()).unwrap_or("auto"),
        "udp": true
    }))
}

fn parse_trojan(link: &str) -> Option<Value> {
    let url = reqwest::Url::parse(&link.replacen("trojan://", "http://", 1)).ok()?;
    let network = url
        .query_pairs()
        .find(|(k, _)| k == "type")
        .map(|(_, v)| v.to_string())
        .unwrap_or_else(|| "tcp".to_string());
    let mut obj = Map::new();
    obj.insert(
        "name".into(),
        json!(safe_decode(
            url.fragment().unwrap_or(url.host_str().unwrap_or("trojan"))
        )),
    );
    obj.insert("type".into(), json!("trojan"));
    obj.insert("server".into(), json!(url.host_str()?));
    obj.insert("port".into(), json!(url.port().unwrap_or(443)));
    obj.insert("password".into(), json!(safe_decode(url.username())));
    obj.insert("udp".into(), json!(true));
    obj.insert("tls".into(), json!(true));
    obj.insert("network".into(), json!(network));
    if let Some((_, sni)) = url.query_pairs().find(|(k, _)| k == "sni") {
        obj.insert("servername".into(), json!(sni.to_string()));
    }
    Some(Value::Object(obj))
}

fn parse_ss(link: &str) -> Option<Value> {
    let raw = link.trim_start_matches("ss://");
    let mut base = raw;
    let mut tag = String::new();
    if let Some((b, t)) = raw.split_once('#') {
        base = b;
        tag = safe_decode(t);
    }
    let (method, password, server, port) = if base.contains('@') {
        let (auth, host) = base.split_once('@')?;
        let decoded = normalize_base64(auth).unwrap_or_else(|| auth.to_string());
        let (m, p) = decoded.split_once(':')?;
        let (s, po) = host.split_once(':')?;
        (
            m.to_string(),
            p.to_string(),
            s.to_string(),
            po.parse::<u16>().ok()?,
        )
    } else {
        let decoded = normalize_base64(base)?;
        let (auth, host) = decoded.split_once('@')?;
        let (m, p) = auth.split_once(':')?;
        let (s, po) = host.split_once(':')?;
        (
            m.to_string(),
            p.to_string(),
            s.to_string(),
            po.parse::<u16>().ok()?,
        )
    };
    let display_name = if tag.is_empty() { server.clone() } else { tag };
    Some(
        json!({"name": display_name, "type": "ss", "server": server, "port": port, "cipher": method, "password": password, "udp": true}),
    )
}

fn parse_hysteria2(link: &str) -> Option<Value> {
    let normalized = if link.starts_with("hy2://") {
        link.replacen("hy2://", "hysteria2://", 1)
    } else {
        link.to_string()
    };
    let url = reqwest::Url::parse(&normalized.replacen("hysteria2://", "http://", 1)).ok()?;
    let mut obj = Map::new();
    obj.insert(
        "name".into(),
        json!(safe_decode(
            url.fragment().unwrap_or(url.host_str().unwrap_or("hy2"))
        )),
    );
    obj.insert("type".into(), json!("hysteria2"));
    obj.insert("server".into(), json!(url.host_str()?));
    obj.insert("port".into(), json!(url.port().unwrap_or(443)));
    obj.insert("password".into(), json!(safe_decode(url.username())));
    obj.insert("udp".into(), json!(true));
    if let Some((_, sni)) = url.query_pairs().find(|(k, _)| k == "sni") {
        obj.insert("sni".into(), json!(sni.to_string()));
    }
    Some(Value::Object(obj))
}

fn parse_proxy(line: &str) -> Option<Value> {
    let lower = line.to_lowercase();
    if lower.starts_with("vless://") {
        return parse_vless(line);
    }
    if lower.starts_with("vmess://") {
        return parse_vmess(line);
    }
    if lower.starts_with("trojan://") {
        return parse_trojan(line);
    }
    if lower.starts_with("ss://") {
        return parse_ss(line);
    }
    if lower.starts_with("hy2://") || lower.starts_with("hysteria2://") {
        return parse_hysteria2(line);
    }
    None
}

fn valid(p: &Value) -> bool {
    let t = p.get("type").and_then(|v| v.as_str()).unwrap_or("");
    let server_ok = p
        .get("server")
        .and_then(|v| v.as_str())
        .map(|v| !v.is_empty())
        .unwrap_or(false);
    let port_ok = p
        .get("port")
        .and_then(|v| v.as_u64())
        .map(|v| v > 0)
        .unwrap_or(false);
    if !server_ok || !port_ok {
        return false;
    }
    match t {
        "vless" | "vmess" => p
            .get("uuid")
            .and_then(|v| v.as_str())
            .map(|v| !v.is_empty())
            .unwrap_or(false),
        "trojan" | "hysteria2" => p
            .get("password")
            .and_then(|v| v.as_str())
            .map(|v| !v.is_empty())
            .unwrap_or(false),
        "ss" => p.get("cipher").is_some() && p.get("password").is_some(),
        _ => false,
    }
}

fn apply_phase4_rules(mut proxies: Vec<Value>, cfg: &ClashConverterConfig) -> Vec<Value> {
    let mut type_count: BTreeMap<String, usize> = BTreeMap::new();
    proxies.sort_by_key(|p| {
        let t = p.get("type").and_then(|v| v.as_str()).unwrap_or("");
        cfg.protocol_rules.get(t).map(|r| r.priority).unwrap_or(999)
    });

    let mut out = Vec::new();
    for p in proxies {
        let t = p
            .get("type")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();
        let Some(rule) = cfg.protocol_rules.get(&t) else {
            continue;
        };
        if !rule.enabled {
            continue;
        }
        let c = *type_count.get(&t).unwrap_or(&0);
        if rule.max_count > 0 && c >= rule.max_count {
            continue;
        }
        type_count.insert(t, c + 1);
        out.push(p);
        if cfg.total_limit > 0 && out.len() >= cfg.total_limit {
            break;
        }
    }

    let mut seen_names: BTreeMap<String, usize> = BTreeMap::new();
    for p in &mut out {
        if let Some(obj) = p.as_object_mut() {
            let original_name = obj
                .get("name")
                .and_then(|v| v.as_str())
                .map(|s| s.trim().to_string())
                .filter(|s| !s.is_empty())
                .unwrap_or_else(|| {
                    obj.get("type")
                        .and_then(|v| v.as_str())
                        .unwrap_or("PROXY")
                        .to_uppercase()
                });

            let mut clean_original_name = original_name;
            while clean_original_name.ends_with('|') || clean_original_name.ends_with(' ') {
                let len = clean_original_name.len();
                if len == 0 { break; }
                clean_original_name.truncate(len - 1);
            }
            let clean_original_name = clean_original_name.trim().to_string();

            let final_name = if let Some(count) = seen_names.get_mut(&clean_original_name) {
                *count += 1;
                format!("{}-{}", clean_original_name, count)
            } else {
                seen_names.insert(clean_original_name.clone(), 0);
                clean_original_name
            };

            obj.insert("name".into(), json!(final_name));
        }
    }

    out
}

fn build_provider(proxies: &[Value]) -> String {
    if proxies.is_empty() {
        return "proxies: []\n".to_string();
    }
    let lines = proxies
        .iter()
        .map(|p| {
            format!(
                "  - {}",
                serde_json::to_string(p).unwrap_or_else(|_| "{}".to_string())
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    format!("proxies:\n{}\n", lines)
}

/// تولید ساختار کامل قالب ضد فیلترینگ و هوشمند کلش میهومو (Mihomo/Clash-Meta) منطبق با فایل قالب ارسالی شما
fn build_full_config(proxies: &[Value]) -> String {
    if proxies.is_empty() {
        return "proxies: []\n".to_string();
    }

    // ۱. استخراج نام تمامی پروکسی‌های تایید شده
    let proxy_names: Vec<String> = proxies
        .iter()
        .filter_map(|p| p.get("name").and_then(|v| v.as_str()))
        .map(|s| s.to_string())
        .collect();

    // ۲. تولید بخش سرورهای پروکسی به صورت رشته خطی معتبر کلش
    let mut proxies_yaml = String::new();
    for p in proxies {
        proxies_yaml.push_str(&format!(
            "  - {}\n",
            serde_json::to_string(p).unwrap_or_default()
        ));
    }

    // ۳. فرمت‌بندی لیست نام‌ها برای گروه‌های گلوبال کلش
    let mut names_list_yaml = String::new();
    for name in &proxy_names {
        names_list_yaml.push_str(&format!("      - \"{}\"\n", name));
    }

    // ۴. ساختار تنظیمات سیستمی، DNS ضد فوت، اسنیفر پورت‌ها و رول پرووایدرهای بومی ایران
    let static_head = r#"global-client-fingerprint: "chrome"
keep-alive-interval: 5
keep-alive-idle: 10
disable-keep-alive: false
port: 7890
socks-port: 7891
redir-port: 7892
mixed-port: 7893
tproxy-port: 7894
allow-lan: true
tcp-concurrent: true
enable-process: true
find-process-mode: "always"
ipv6: false
log-level: "info"
geo-auto-update: true
geo-update-interval: 168
secret: ""
bind-address: "*"
unified-delay: false

profile:
  store-selected: true
  store-fake-ip: true

dns:
  enable: true
  ipv6: false
  prefer-h3: false
  cache-algorithm: "arc"
  use-system-hosts: true
  use-host: true
  listen: "0.0.0.0:53"
  enhanced-mode: "fake-ip"
  fake-ip-filter-mode: "blacklist"
  fake-ip-range: "198.18.0.1/16"
  fake-ip-filter:
    - "*.lan"
    - "*.localdomain"
    - "*.invalid"
    - "*.localhost"
    - "*.test"
    - "*.local"
    - "*.home.arpa"
    - "time.*.com"
    - "ntp.*.com"
    - "*.ir"
  default-nameserver:
    - "1.1.1.1"
    - "8.8.8.8"
    - "9.9.9.9"
  nameserver:
    - "tcp://1.1.1.1"
    - "tcp://1.0.0.1"
    - "tcp://8.8.8.8"
    - "tcp://8.8.4.4"
    - "tcp://9.9.9.9"
    - "tcp://149.112.112.112"
    - "tcp://208.67.222.222"
    - "tcp://208.67.220.222"
  fallback:
    - "tcp://76.76.19.19"
    - "tcp://76.223.122.150"
    - "tcp://185.228.168.9"
    - "tcp://185.228.169.9"
    - "tcp://8.26.56.26"
    - "tcp://8.20.247.20"
    - "tcp://76.76.2.11"
    - "tcp://76.76.10.11"
    - "tcp://84.200.69.80"
    - "tcp://84.200.70.40"
    - "tcp://45.33.97.5"
    - "tcp://37.235.1.177"
    - "tcp://209.244.0.3"
    - "tcp://209.244.0.4"
    - "tcp://156.154.70.5"
    - "tcp://156.154.71.5"
    - "tcp://103.86.96.100"
    - "tcp://103.86.99.100"
    - "tcp://199.85.126.10"
    - "tcp://199.85.127.10"
    - "tcp://129.250.35.250"
    - "tcp://129.250.35.251"
    - "tcp://94.16.114.254"
    - "tcp://94.247.43.254"
    - "tcp://208.67.222.20"
    - "tcp://195.46.39.39"
    - "tcp://195.46.39.40"
    - "tcp://204.117.214.10"
    - "tcp://199.2.252.10"
    - "tcp://194.169.169.169"
    - "tcp://156.154.70.1"
    - "tcp://156.154.71.1"
    - "tcp://91.239.100.100"
    - "tcp://89.233.43.71"
    - "tcp://64.6.64.6"
    - "tcp://64.6.65.6"
    - "tcp://77.88.8.8"
    - "tcp://77.88.8.1"
  fallback-filter:
    geoip: true
    geoip-code: "IR"
    geosite:
      - "gfw"
    ipcidr:
      - "240.0.0.0/4"
    domain:
      - "+.google.com"
      - "+.facebook.com"
      - "+.youtube.com"
  proxy-server-nameserver:
    - "tcp://1.1.1.1"
    - "tcp://8.8.8.8"
  direct-nameserver:
    - "78.157.42.100"
    - "78.157.42.101"

sniffer:
  enable: true
  force-dns-mapping: true
  parse-pure-ip: true
  override-destination: false
  sniff:
    HTTP:
      ports: [80, 8080, 8880, 2052, 2082, 2086, 2095]
    TLS:
      ports: [443, 8443, 2053, 2083, 2087, 2096]

tun:
  enable: true
  stack: "mixed"
  auto-route: true
  auto-detect-interface: true
  auto-redir: true
  dns-hijack:
    - "any:53"
    - "tcp://any:53"

rule-providers:
  category_public_tracker:
    type: http
    behavior: domain
    url: "https://raw.githubusercontent.com/10ium/V2rayDomains2Clash/generated/category-public-tracker.yaml"
    interval: 86400
    path: "./ruleset/category_public_tracker.yaml"
  iran_ads:
    type: http
    behavior: domain
    url: "https://github.com/bootmortis/iran-hosted-domains/releases/latest/download/clash_rules_ads.yaml"
    interval: 86400
    path: "./ruleset/iran_ads.yaml"
  PersianBlocker:
    type: http
    behavior: domain
    url: "https://github.com/MasterKia/iran-hosted-domains/releases/latest/download/clash_rules_ads.yaml"
    interval: 86400
    path: "./ruleset/PersianBlocker.yaml"
  youtube:
    type: http
    behavior: domain
    url: "https://raw.githubusercontent.com/10ium/V2rayDomains2Clash/generated/youtube.yaml"
    interval: 86400
    path: "./ruleset/youtube.yaml"
  telegram:
    type: http
    behavior: domain
    url: "https://raw.githubusercontent.com/10ium/V2rayDomains2Clash/generated/telegram.yaml"
    interval: 86400
    path: "./ruleset/telegram.yaml"
  twitch:
    type: http
    behavior: domain
    url: "https://raw.githubusercontent.com/10ium/V2rayDomains2Clash/generated/twitch.yaml"
    interval: 86400
    path: "./ruleset/twitch.yaml"
  censor:
    type: http
    behavior: classical
    url: "https://raw.githubusercontent.com/10ium/clash_rules/main/censor.yaml"
    interval: 86400
    path: "./ruleset/censor.yaml"
  local_ips:
    type: http
    behavior: ipcidr
    url: "https://raw.githubusercontent.com/10ium/V2rayDomains2Clash/generated/local-ips.yaml"
    interval: 86400
    path: "./ruleset/local_ips.yaml"
  private:
    type: http
    behavior: domain
    url: "https://raw.githubusercontent.com/10ium/V2rayDomains2Clash/generated/private.yaml"
    interval: 86400
    path: "./ruleset/private.yaml"
  category_ir:
    type: http
    behavior: domain
    url: "https://raw.githubusercontent.com/10ium/V2rayDomains2Clash/generated/category-ir.yaml"
    interval: 86400
    path: "./ruleset/category_ir.yaml"
  iran:
    type: http
    behavior: classical
    url: "https://raw.githubusercontent.com/10ium/clash_rules/main/iran.yaml"
    interval: 86400
    path: "./ruleset/iran.yaml"
  steam:
    type: http
    behavior: classical
    url: "https://raw.githubusercontent.com/10ium/clash_rules/main/steam.yaml"
    interval: 86400
    path: "./ruleset/steam.yaml"
  game:
    type: http
    behavior: classical
    url: "https://raw.githubusercontent.com/10ium/clash_rules/refs/heads/main/game.yaml"
    interval: 86400
    path: "./ruleset/game.yaml"
  category-games:
    type: http
    behavior: domain
    url: "https://raw.githubusercontent.com/10ium/V2rayDomains2Clash/refs/heads/generated/category-games.yaml"
    interval: 86400
    path: "./ruleset/category-games.yaml"
  ir:
    type: http
    format: yaml
    behavior: domain
    url: "https://github.com/chocolate4u/Iran-clash-rules/releases/latest/download/ir.yaml"
    interval: 86400
    path: "./ruleset/ir.yaml"
  apps:
    type: http
    format: yaml
    behavior: classical
    url: "https://github.com/chocolate4u/Iran-clash-rules/releases/latest/download/apps.yaml"
    interval: 86400
    path: "./ruleset/apps.yaml"
  ircidr:
    type: http
    format: yaml
    behavior: ipcidr
    url: "https://github.com/chocolate4u/Iran-clash-rules/releases/latest/download/ircidr.yaml"
    interval: 86400
    path: "./ruleset/ircidr.yaml"
  irasn:
    type: http
    format: yaml
    behavior: classical
    url: "https://raw.githubusercontent.com/Chocolate4U/Iran-clash-rules/release/irasn.yaml"
    interval: 86400
    path: "./ruleset/irasn.yaml"
  arvancloud:
    type: http
    format: yaml
    behavior: ipcidr
    url: "https://raw.githubusercontent.com/Chocolate4U/Iran-clash-rules/release/arvancloud.yaml"
    interval: 86400
    path: "./ruleset/arvancloud.yaml"
  derakcloud:
    type: http
    format: yaml
    behavior: ipcidr
    url: "https://raw.githubusercontent.com/Chocolate4U/Iran-clash-rules/release/derakcloud.yaml"
    interval: 86400
    path: "./ruleset/derakcloud.yaml"
  iranserver:
    type: http
    format: yaml
    behavior: ipcidr
    url: "https://raw.githubusercontent.com/Chocolate4U/Iran-clash-rules/release/iranserver.yaml"
    interval: 86400
    path: "./ruleset/iranserver.yaml"
  parspack:
    type: http
    format: yaml
    behavior: ipcidr
    url: "https://raw.githubusercontent.com/Chocolate4U/Iran-clash-rules/release/parspack.yaml"
    interval: 86400
    path: "./ruleset/parspack.yaml"
  malware:
    type: http
    format: yaml
    behavior: domain
    url: "https://raw.githubusercontent.com/Chocolate4U/Iran-clash-rules/release/malware.yaml"
    interval: 86400
    path: "./ruleset/malware.yaml"
  phishing:
    type: http
    format: yaml
    behavior: domain
    url: "https://raw.githubusercontent.com/Chocolate4U/Iran-clash-rules/release/phishing.yaml"
    interval: 86400
    path: "./ruleset/phishing.yaml"
  cryptominers:
    type: http
    format: yaml
    behavior: domain
    url: "https://raw.githubusercontent.com/Chocolate4U/Iran-clash-rules/release/cryptominers.yaml"
    interval: 86400
    path: "./ruleset/cryptominers.yaml"
  ads:
    type: http
    format: yaml
    behavior: domain
    url: "https://github.com/Chocolate4U/Iran-clash-rules/releases/download/202606060815/category-ads-all.yaml"
    interval: 86400
    path: "./ruleset/ads.yaml"
  DownloadManagers:
    type: http
    behavior: classical
    url: "https://raw.githubusercontent.com/10ium/clash_rules/refs/heads/main/DownloadManagers.yaml"
    interval: 86400
    path: "./ruleset/DownloadManagers.yaml"
  BanProgramAD:
    type: http
    behavior: classical
    url: "https://raw.githubusercontent.com/10ium/mihomo_rule/refs/heads/main/list/BanProgramAD.yaml"
    interval: 86400
    path: "./ruleset/BanProgramAD.yaml"
  BanAD:
    type: http
    behavior: classical
    url: "https://raw.githubusercontent.com/10ium/mihomo_rule/refs/heads/main/list/BanAD.yaml"
    interval: 86400
    path: "./ruleset/BanAD.yaml"
  PrivateTracker:
    type: http
    behavior: classical
    url: "https://raw.githubusercontent.com/10ium/mihomo_rule/refs/heads/main/list/PrivateTracker.yaml"
    interval: 86400
    path: "./ruleset/PrivateTracker.yaml"
  BanEasyList:
    type: http
    behavior: classical
    url: "https://raw.githubusercontent.com/10ium/mihomo_rule/refs/heads/main/list/BanEasyList.yaml"
    interval: 86400
    path: "./ruleset/BanEasyList.yaml"
  Download:
    type: http
    behavior: classical
    url: "https://raw.githubusercontent.com/10ium/mihomo_rule/refs/heads/main/list/Download.yaml"
    interval: 86400
    path: "./ruleset/Download.yaml"
  GameDownload:
    type: http
    behavior: classical
    url: "https://raw.githubusercontent.com/10ium/mihomo_rule/refs/heads/main/list/GameDownload.yaml"
    interval: 86400
    path: "./ruleset/GameDownload.yaml"
  SteamRegionCheck:
    type: http
    behavior: classical
    url: "https://raw.githubusercontent.com/10ium/mihomo_rule/refs/heads/main/list/SteamRegionCheck.yaml"
    interval: 86400
    path: "./ruleset/SteamRegionCheck.yaml"
  Xbox:
    type: http
    behavior: classical
    url: "https://raw.githubusercontent.com/10ium/mihomo_rule/refs/heads/main/list/Xbox.yaml"
    interval: 86400
    path: "./ruleset/Xbox.yaml"
  YouTubeMusic:
    type: http
    behavior: classical
    url: "https://raw.githubusercontent.com/10ium/mihomo_rule/refs/heads/main/list/YouTubeMusic.yaml"
    interval: 86400
    path: "./ruleset/YouTubeMusic.yaml"
  YouTube:
    type: http
    behavior: classical
    url: "https://raw.githubusercontent.com/10ium/mihomo_rule/refs/heads/main/list/YouTube.yaml"
    interval: 86400
    path: "./ruleset/YouTube.yaml"
  Ponzi:
    type: http
    behavior: classical
    url: "https://raw.githubusercontent.com/10ium/mihomo_rule/refs/heads/main/Ponzi.yaml"
    interval: 86400
    path: "./ruleset/Ponzi.yaml"
  warninglist:
    type: http
    behavior: classical
    url: "https://raw.githubusercontent.com/10ium/mihomo_rule/refs/heads/main/warning-list.yaml"
    interval: 86400
    path: "./ruleset/warninglist.yaml"
  google:
    type: http
    behavior: domain
    url: "https://raw.githubusercontent.com/10ium/V2rayDomains2Clash/refs/heads/generated/google.yaml"
    interval: 86400
    path: "./ruleset/google.yaml"
  google-play:
    type: http
    behavior: domain
    url: "https://raw.githubusercontent.com/10ium/V2rayDomains2Clash/refs/heads/generated/google-play.yaml"
    interval: 86400
    path: "./ruleset/google-play.yaml"
  xiaomi_block_list:
    type: http
    format: yaml
    behavior: domain
    url: "https://raw.githubusercontent.com/10ium/clash_rules/refs/heads/main/xiaomi_block_list.yaml"
    interval: 86400
    path: "./ruleset/xiaomi_block_list.yaml"
  xiaomi_white_list:
    type: http
    behavior: classical
    url: "https://raw.githubusercontent.com/10ium/clash_rules/refs/heads/main/xiaomi_white_list.yaml"
    interval: 86400
    path: "./ruleset/xiaomi_white_list.yaml"
  cloudflare:
    type: http
    behavior: domain
    url: "https://raw.githubusercontent.com/10ium/V2rayDomains2Clash/refs/heads/generated/cloudflare.yaml"
    interval: 86400
    path: "./ruleset/cloudflare.yaml"
  github:
    type: http
    behavior: domain
    url: "https://raw.githubusercontent.com/10ium/V2rayDomains2Clash/refs/heads/generated/github.yaml"
    interval: 86400
    path: "./ruleset/xgithub.yaml"
  whatsapp:
    type: http
    behavior: domain
    url: "https://raw.githubusercontent.com/10ium/V2rayDomains2Clash/generated/whatsapp.yaml"
    interval: 86400
    path: "./ruleset/whatsapp.yaml"
  LiteAds:
    type: http
    behavior: classical
    url: "https://raw.githubusercontent.com/10ium/clash_rules/refs/heads/main/LiteAds.yaml"
    interval: 86400
    path: "./ruleset/LiteAds.yaml"
  discord:
    type: http
    behavior: classical
    url: "https://raw.githubusercontent.com/10ium/clash_rules/refs/heads/main/discord.yaml"
    interval: 86400
    path: "./ruleset/discord.yaml"
  instagram:
    type: http
    behavior: domain
    url: "https://raw.githubusercontent.com/10ium/V2rayDomains2Clash/refs/heads/generated/instagram.yaml"
    interval: 86400
    path: "./ruleset/instagram.yaml"
  category-ai:
    type: http
    behavior: domain
    url: "https://raw.githubusercontent.com/10ium/V2rayDomains2Clash/refs/heads/generated/category-ai-!cn.yaml"
    interval: 86400
    path: "./ruleset/category-ai.yaml"
  stremio:
    type: http
    behavior: classical
    url: "https://raw.githubusercontent.com/10ium/clash_rules/refs/heads/main/stremio.yaml"
    interval: 86400
    path: "./ruleset/stremio.yaml"
  windows:
    type: http
    behavior: classical
    url: "https://raw.githubusercontent.com/10ium/clash_rules/refs/heads/main/windows.yaml"
    interval: 86400
    path: "./ruleset/windows.yaml"
  Chotwitter:
    type: http
    format: yaml
    behavior: ipcidr
    url: "https://raw.githubusercontent.com/Chocolate4U/Iran-clash-rules/release/twitter.yaml"
    interval: 86400
    path: "./ruleset/Chotwitter.yaml"
  mihTwitter:
    type: http
    behavior: classical
    url: "https://raw.githubusercontent.com/10ium/mihomo_rule/refs/heads/main/list/Twitter.yaml"
    interval: 86400
    path: "./ruleset/mihTwitter.yaml"
  Domtwitter:
    type: http
    behavior: domain
    url: "https://raw.githubusercontent.com/10ium/V2rayDomains2Clash/refs/heads/generated/twitter.yaml"
    interval: 86400
    path: "./ruleset/Domtwitter.yaml"
  DomainSpotify:
    type: http
    behavior: domain
    url: "https://raw.githubusercontent.com/10ium/V2rayDomains2Clash/refs/heads/generated/spotify.yaml"
    interval: 86400
    path: "./ruleset/DomainSpotify.yaml"
  mihspotify:
    type: http
    behavior: domain
    url: "https://raw.githubusercontent.com/10ium/mihomo_rule/refs/heads/main/list/Spotify.yaml"
    interval: 86400
    path: "./ruleset/mihSpotify.yaml"

rules:
  - RULE-SET,DownloadManagers,دانلود منیجر 📥
  - RULE-SET,Download,دانلود منیجر 📥
  - RULE-SET,stremio,استریمیو 🎬
  - PROCESS-NAME,im.vector.app,المنت 💬
  - PROCESS-NAME,io.element.android.x,المنت 💬
  - PROCESS-NAME,Element.exe,المنت 💬
  - DOMAIN-SUFFIX,aklispro.sbs,المنت 💬
  - DOMAIN-SUFFIX,chat.aklispro.sbs,المنت 💬
  - DOMAIN-SUFFIX,site.aklispro.sbs,المنت 💬
  - DOMAIN-SUFFIX,electonet.xyz,المنت 💬
  - DOMAIN-SUFFIX,chat.electonet.xyz,المنت 💬
  - DOMAIN-SUFFIX,rainbuwu.ir,المنت 💬
  - DOMAIN-SUFFIX,cinny.rainbuwu.ir,المنت 💬
  - PROCESS-NAME,chat.delta,دلتاچت ✉️
  - PROCESS-NAME,DeltaChat.exe,دلتاچت ✉️
  - DOMAIN-SUFFIX,arsalandalvand.ir,دلتاچت ✉️
  - DST-PORT,993,دلتاچت ✉️
  - DST-PORT,465,دلتاچت ✉️
  - DST-PORT,587,دلتاچت ✉️
  - PROCESS-NAME,com.teamspeak.ts3client,تیم‌اسپیک 🎧
  - PROCESS-NAME,ts3client_win64.exe,تیم‌اسپیک 🎧
  - PROCESS-NAME,ts3client_win32.exe,تیم‌اسپیک 🎧
  - DOMAIN-SUFFIX,ag.tssq.ir,تیم‌اسپیک 🎧
  - DST-PORT,9987,تیم‌اسپیک 🎧
  - RULE-SET,BanProgramAD,تبلیغات اپ ها 🍃
  - RULE-SET,BanAD,رهگیری جهانی 🛑
  - RULE-SET,PrivateTracker,رهگیری جهانی 🛑
  - RULE-SET,category_public_tracker,رهگیری جهانی 🛑
  - RULE-SET,malware,سایتای مخرب ⚠️
  - RULE-SET,phishing,سایتای مخرب ⚠️
  - RULE-SET,cryptominers,سایتای مخرب ⚠️
  - RULE-SET,warninglist,سایتای مخرب ⚠️
  - RULE-SET,Ponzi,سایتای مخرب ⚠️
  - RULE-SET,LiteAds,تبلیغات 🆎
  - RULE-SET,iran_ads,تبلیغات 🆎
  - RULE-SET,PersianBlocker,تبلیغات 🆎
  - RULE-SET,ads,تبلیغات 🆎
  - RULE-SET,BanEasyList,تبلیغات 🆎
  - RULE-SET,twitch,توییچ 📡
  - PROCESS-NAME,Telegram.exe,تلگرام 💬
  - PROCESS-NAME,org.telegram.messenger,تلگرام 💬
  - PROCESS-NAME,org.telegram.messenger.web,تلگرام 💬
  - RULE-SET,telegram,تلگرام 💬
  - RULE-SET,YouTube,یوتیوب ▶️
  - RULE-SET,youtube,یوتیوب ▶️
  - RULE-SET,YouTubeMusic,یوتیوب ▶️
  - PROCESS-NAME,com.anydesk.anydeskandroid,انی‌دسک 🔴
  - PROCESS-NAME,AnyDesk.exe,انی‌دسک 🔴
  - DOMAIN-SUFFIX,anydesk.com,انی‌دسک 🔴
  - PROCESS-NAME,Twitter.exe,توییتر 🐦
  - PROCESS-NAME,com.twitter.android,توییتر 🐦
  - RULE-SET,Chotwitter,توییتر 🐦
  - RULE-SET,mihTwitter,توییتر 🐦
  - RULE-SET,Domtwitter,توییتر 🐦
  - PROCESS-NAME,com.spotify.music,اسپاتیفای 🎵
  - PROCESS-NAME,Spotify.exe,اسپاتیفای 🎵
  - RULE-SET,DomainSpotify,اسپاتیفای 🎵
  - RULE-SET,mihspotify,اسپاتیفای 🎵
  - PROCESS-NAME,com.instagram.android,اینستاگرام 📸
  - RULE-SET,instagram,اینستاگرام 📸
  - DOMAIN-SUFFIX,deepseek.com,هوش مصنوعی 🤖
  - DOMAIN-SUFFIX,qwen.ai,هوش مصنوعی 🤖
  - RULE-SET,category-ai,هوش مصنوعی 🤖
  - RULE-SET,censor,سایتای سانسوری 🤬
  - RULE-SET,apps,سایتای ایرانی 🇮🇷
  - RULE-SET,iran,سایتای ایرانی 🇮🇷
  - RULE-SET,arvancloud,سایتای ایرانی 🇮🇷
  - RULE-SET,derakcloud,سایتای ایرانی 🇮🇷
  - RULE-SET,iranserver,سایتای ایرانی 🇮🇷
  - RULE-SET,parspack,سایتای ایرانی 🇮🇷
  - RULE-SET,irasn,سایتای ایرانی 🇮🇷
  - RULE-SET,ircidr,سایتای ایرانی 🇮🇷
  - RULE-SET,ir,سایتای ایرانی 🇮🇷
  - RULE-SET,category_ir,سایتای ایرانی 🇮🇷
  - DOMAIN-SUFFIX,unimics.com,سایتای ایرانی 🇮🇷
  - RULE-SET,whatsapp,واتس آپ 🟢
  - RULE-SET,steam,استیم 🖥️
  - RULE-SET,SteamRegionCheck,استیم 🖥️
  - RULE-SET,game,گیم 🎮
  - RULE-SET,GameDownload,گیم 🎮
  - RULE-SET,category-games,گیم 🎮
  - RULE-SET,Xbox,گیم 🎮
  - RULE-SET,discord,دیسکورد 🗣️
  - RULE-SET,xiaomi_white_list,نوع انتخاب پروکسی 🔀
  - RULE-SET,xiaomi_block_list,تبلیغات اپ ها 🍃
  - RULE-SET,windows,ویندوز 🧊
  - RULE-SET,cloudflare,کلودفلر ☁️
  - RULE-SET,github,گیتهاب 🐙
  - PROCESS-NAME,com.android.vending,نوع انتخاب پروکسی 🔀
  - PROCESS-NAME,com.google.android.gms,نوع انتخاب پروکسی 🔀
  - RULE-SET,google-play,نوع انتخاب پروکسی 🔀
  - RULE-SET,google,گوگل 🌍
  - IP-CIDR,10.10.34.0/24,نوع انتخاب پروکسی 🔀
  - RULE-SET,local_ips,بدون فیلترشکن 🛡️
  - RULE-SET,private,بدون فیلترشکن 🛡️
  - MATCH,نوع انتخاب پروکسی 🔀

ntp:
  enable: true
  server: "time.apple.com"
  port: 123
  interval: 30
"#;

    // ۵. ساختار پویای گروه‌های پروکسی با درج لیست نام پروکسی‌ها به صورت آرایه کدهای YAML
    let static_groups_head = r#"proxy-groups:
  - name: "نوع انتخاب پروکسی 🔀"
    type: select
    icon: "https://www.svgrepo.com/show/412721/choose.svg"
    proxies:
      - "خودکار (بهترین پینگ) 🤖"
      - "دستی 🤏"
      - "توزیع بار چرخشی ⚖️"
      - "قطع اینترنت ⛔"
      - "بدون فیلترشکن 🛡️"

  - name: "دستی 🤏"
    type: select
    icon: "https://www.svgrepo.com/show/372331/cursor-hand-click.svg"
    proxies:
"#;

    let static_groups_test = r#"  - name: "خودکار (بهترین پینگ) 🤖"
    type: url-test
    icon: "https://www.svgrepo.com/show/7876/speedometer.svg"
    url: "https://www.gstatic.com/generate_204"
    interval: 600
    tolerance: 50
    timeout: 3200
    lazy: false
    max-failed-times: 2
    proxies:
"#;

    let static_groups_balance = r#"  - name: "توزیع بار چرخشی ⚖️"
    type: load-balance
    icon: "https://www.svgrepo.com/show/388466/rotating-forward.svg"
    strategy: round-robin
    url: "https://www.gstatic.com/generate_204"
    interval: 30
    timeout: 1500
    lazy: false
    proxies:
"#;

    let static_groups_foot = r#"  - name: "المنت 💬"
    type: select
    icon: "https://www.svgrepo.com/show/353655/matrix-icon.svg"
    proxies:
      - "بدون فیلترشکن 🛡️"
      - "نوع انتخاب پروکسی 🔀"
      - "خودکار (بهترین پینگ) 🤖"
      - "دستی 🤏"
      - "اجازه ندادن 🚫"

  - name: "تیم‌اسپیک 🎧"
    type: select
    icon: "https://www.svgrepo.com/show/331567/teamspeak.svg"
    proxies:
      - "بدون فیلترشکن 🛡️"
      - "نوع انتخاب پروکسی 🔀"
      - "خودکار (بهترین پینگ) 🤖"
      - "دستی 🤏"
      - "اجازه ندادن 🚫"

  - name: "دلتاچت ✉️"
    type: select
    icon: "https://www.svgrepo.com/show/373771/mail.svg"
    proxies:
      - "بدون فیلترشکن 🛡️"
      - "نوع انتخاب پروکسی 🔀"
      - "خودکار (بهترین پینگ) 🤖"
      - "دستی 🤏"
      - "اجازه ندادن 🚫"

  - name: "دانلود منیجر 📥"
    type: select
    icon: "https://www.sadeemrdp.com/fonts/apps/IDM-Logo.svg"
    proxies:
      - "بدون فیلترشکن 🛡️"
      - "نوع انتخاب پروکسی 🔀"
      - "خودکار (بهترین پینگ) 🤖"
      - "دستی 🤏"
      - "اجازه ندادن 🚫"

  - name: "تلگرام 💬"
    type: select
    icon: "https://www.svgrepo.com/show/354443/telegram.svg"
    proxies:
      - "نوع انتخاب پروکسی 🔀"
      - "بدون فیلترشکن 🛡️"
      - "خودکار (بهترین پینگ) 🤖"
      - "دستی 🤏"
      - "اجازه ندادن 🚫"

  - name: "یوتیوب ▶️"
    type: select
    icon: "https://www.svgrepo.com/show/475700/youtube-color.svg"
    proxies:
      - "نوع انتخاب پروکسی 🔀"
      - "خودکار (بهترین پینگ) 🤖"
      - "دستی 🤏"
      - "اجازه ندادن 🚫"
      - "بدون فیلترشکن 🛡️"

  - name: "گوگل 🌍"
    type: select
    icon: "https://www.svgrepo.com/show/475656/google-color.svg"
    proxies:
      - "نوع انتخاب پروکسی 🔀"
      - "بدون فیلترشکن 🛡️"
      - "خودکار (بهترین پینگ) 🤖"
      - "دستی 🤏"
      - "اجازه ندادن 🚫"

  - name: "واتس آپ 🟢"
    type: select
    icon: "https://upload.wikimedia.org/wikipedia/commons/4/4c/WhatsApp_Logo_green.svg"
    proxies:
      - "نوع انتخاب پروکسی 🔀"
      - "خودکار (بهترین پینگ) 🤖"
      - "دستی 🤏"
      - "اجازه ندادن 🚫"
      - "بدون فیلترشکن 🛡️"

  - name: "هوش مصنوعی 🤖"
    type: select
    icon: "https://www.svgrepo.com/show/306500/openai.svg"
    proxies:
      - "نوع انتخاب پروکسی 🔀"
      - "بدون فیلترشکن 🛡️"
      - "خودکار (بهترین پینگ) 🤖"
      - "دستی 🤏"
      - "اجازه ندادن 🚫"

  - name: "توییتر 🐦"
    type: select
    icon: "https://www.svgrepo.com/show/475689/twitter-color.svg"
    proxies:
      - "نوع انتخاب پروکسی 🔀"
      - "بدون فیلترشکن 🛡️"
      - "خودکار (بهترین پینگ) 🤖"
      - "دستی 🤏"
      - "اجازه ندادن 🚫"

  - name: "اسپاتیفای 🎵"
    type: select
    icon: "https://www.svgrepo.com/show/475684/spotify-color.svg"
    proxies:
      - "نوع انتخاب پروکسی 🔀"
      - "بدون فیلترشکن 🛡️"
      - "خودکار (بهترین پینگ) 🤖"
      - "دستی 🤏"
      - "اجازه ندادن 🚫"

  - name: "اینستاگرام 📸"
    type: select
    icon: "https://www.svgrepo.com/show/452229/instagram-1.svg"
    proxies:
      - "نوع انتخاب پروکسی 🔀"
      - "خودکار (بهترین پینگ) 🤖"
      - "دستی 🤏"
      - "اجازه ندادن 🚫"
      - "بدون فیلترشکن 🛡️"

  - name: "تبلیغات 🆎"
    type: select
    icon: "https://www.svgrepo.com/show/336358/ad.svg"
    proxies:
      - "اجازه ندادن 🚫"
      - "نوع انتخاب پروکسی 🔀"
      - "خودکار (بهترین پینگ) 🤖"
      - "دستی 🤏"
      - "بدون فیلترشکن 🛡️"

  - name: "تبلیغات اپ ها 🍃"
    type: select
    icon: "https://www.svgrepo.com/show/12172/smartphone-ad.svg"
    proxies:
      - "اجازه ندادن 🚫"
      - "نوع انتخاب پروکسی 🔀"
      - "خودکار (بهترین پینگ) 🤖"
      - "دستی 🤏"
      - "بدون فیلترشکن 🛡️"

  - name: "رهگیری جهانی 🛑"
    type: select
    icon: "https://www.svgrepo.com/show/298725/tracking-track.svg"
    proxies:
      - "اجازه ندادن 🚫"
      - "نوع انتخاب پروکسی 🔀"
      - "خودکار (بهترین پینگ) 🤖"
      - "دستی 🤏"
      - "بدون فیلترشکن 🛡️"

  - name: "سایتای مخرب ⚠️"
    type: select
    icon: "https://www.svgrepo.com/show/381135/cyber-crime-cyber-phishing-fraud-hack-money.svg"
    proxies:
      - "اجازه ندادن 🚫"
      - "نوع انتخاب پروکسی 🔀"
      - "خودکار (بهترین پینگ) 🤖"
      - "دستی 🤏"
      - "بدون فیلترشکن 🛡️"

  - name: "استیم 🖥️"
    type: select
    icon: "https://www.svgrepo.com/show/452107/steam.svg"
    proxies:
      - "نوع انتخاب پروکسی 🔀"
      - "بدون فیلترشکن 🛡️"
      - "خودکار (بهترین پینگ) 🤖"
      - "دستی 🤏"
      - "اجازه ندادن 🚫"

  - name: "گیم 🎮"
    type: select
    icon: "https://www.svgrepo.com/show/167729/game-controller.svg"
    proxies:
      - "نوع انتخاب پروکسی 🔀"
      - "بدون فیلترشکن 🛡️"
      - "خودکار (بهترین پینگ) 🤖"
      - "دستی 🤏"
      - "اجازه ندادن 🚫"

  - name: "توییچ 📡"
    type: select
    icon: "https://www.svgrepo.com/show/343527/twitch-network-communication-interaction-connection.svg"
    proxies:
      - "نوع انتخاب پروکسی 🔀"
      - "بدون فیلترشکن 🛡️"
      - "خودکار (بهترین پینگ) 🤖"
      - "دستی 🤏"
      - "اجازه ندادن 🚫"

  - name: "سایتای ایرانی 🇮🇷"
    type: select
    icon: "https://upload.wikimedia.org/wikipedia/commons/3/36/Flag_of_Iran_%28civil%29.svg"
    proxies:
      - "بدون فیلترشکن 🛡️"
      - "نوع انتخاب پروکسی 🔀"
      - "خودکار (بهترین پینگ) 🤖"
      - "دستی 🤏"
      - "اجازه ندادن 🚫"

  - name: "ویندوز 🧊"
    type: select
    icon: "https://icon.icepanel.io/Technology/svg/Windows-11.svg"
    proxies:
      - "نوع انتخاب پروکسی 🔀"
      - "بدون فیلترشکن 🛡️"
      - "اجازه ندادن 🚫"
      - "خودکار (بهترین پینگ) 🤖"
      - "دستی 🤏"

  - name: "کلودفلر ☁️"
    type: select
    icon: "https://icon.icepanel.io/Technology/svg/Cloudflare.svg"
    proxies:
      - "نوع انتخاب پروکسی 🔀"
      - "بدون فیلترشکن 🛡️"
      - "خودکار (بهترین پینگ) 🤖"
      - "دستی 🤏"
      - "اجازه ندادن 🚫"

  - name: "گیتهاب 🐙"
    type: select
    icon: "https://www.svgrepo.com/show/355033/github.svg"
    proxies:
      - "نوع انتخاب پروکسی 🔀"
      - "بدون فیلترشکن 🛡️"
      - "خودکار (بهترین پینگ) 🤖"
      - "دستی 🤏"
      - "اجازه ندادن 🚫"

  - name: "دیسکورد 🗣️"
    type: select
    icon: "https://automatorplugin.com/wp-content/uploads/2024/10/discord-icon.svg"
    proxies:
      - "نوع انتخاب پروکسی 🔀"
      - "بدون فیلترشکن 🛡️"
      - "خودکار (بهترین پینگ) 🤖"
      - "دستی 🤏"
      - "اجازه ندادن 🚫"

  - name: "استریمیو 🎬"
    type: select
    icon: "https://stremio.github.io/stremio-addon-guide/img/stremio.svg"
    proxies:
      - "نوع انتخاب پروکسی 🔀"
      - "بدون فیلترشکن 🛡️"
      - "خودکار (بهترین پینگ) 🤖"
      - "دستی 🤏"
      - "اجازه ندادن 🚫"

  - name: "انی‌دسک 🔴"
    type: select
    icon: "https://www.svgrepo.com/show/331289/anydesk.svg"
    proxies:
      - "بدون فیلترشکن 🛡️"
      - "نوع انتخاب پروکسی 🔀"
      - "خودکار (بهترین پینگ) 🤖"
      - "دستی 🤏"
      - "اجازه ندادن 🚫"

  - name: "سایتای سانسوری 🤬"
    type: select
    icon: "https://upload.wikimedia.org/wikipedia/commons/thumb/6/67/Censorship.svg/300px-Censorship.svg.png"
    proxies:
      - "اجازه ندادن 🚫"
      - "نوع انتخاب پروکسی 🔀"
      - "خودکار (بهترین پینگ) 🤖"
      - "دستی 🤏"
      - "بدون فیلترشکن 🛡️"

  - name: "بدون فیلترشکن 🛡️"
    type: select
    icon: "https://www.svgrepo.com/show/6318/connection.svg"
    proxies:
      - "DIRECT"
    hidden: true

  - name: "قطع اینترنت ⛔"
    type: select
    icon: "https://www.svgrepo.com/show/305372/wifi-off.svg"
    proxies:
      - "REJECT"
    hidden: true

  - name: "اجازه ندادن 🚫"
    type: select
    icon: "https://www.svgrepo.com/show/444307/gui-ban.svg"
    proxies:
      - "REJECT"
    hidden: true
"#;

    let mut full_yaml = String::new();
    full_yaml.push_str(static_head);
    full_yaml.push_str("\nproxies:\n");
    full_yaml.push_str(&proxies_yaml);
    full_yaml.push_str("\n");
    full_yaml.push_str(static_groups_head);
    full_yaml.push_str(&names_list_yaml);
    full_yaml.push_str("\n");
    full_yaml.push_str(static_groups_test);
    full_yaml.push_str(&names_list_yaml);
    full_yaml.push_str("\n");
    full_yaml.push_str(static_groups_balance);
    full_yaml.push_str(&names_list_yaml);
    full_yaml.push_str("\n");
    full_yaml.push_str(static_groups_foot);

    full_yaml
}

fn convert_set(
    name: &str,
    input: &BTreeSet<String>,
    out_dir: &Path,
    cfg: &ClashConverterConfig,
    tx: &Sender<AppEvent>,
) {
    let mut unique: BTreeMap<String, Value> = BTreeMap::new();
    for line in input {
        if let Some(p) = parse_proxy(line) {
            if !valid(&p) {
                continue;
            }
            let fp = format!(
                "{}|{}|{}|{}",
                p.get("type").and_then(|v| v.as_str()).unwrap_or(""),
                p.get("server").and_then(|v| v.as_str()).unwrap_or(""),
                p.get("port").and_then(|v| v.as_u64()).unwrap_or(0),
                p.get("uuid")
                    .or_else(|| p.get("password"))
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
            );
            unique.entry(fp).or_insert(p);
        }
    }

    let filtered = apply_phase4_rules(unique.into_values().collect(), cfg);
    let yaml = if cfg.output_full_config {
        build_full_config(&filtered)
    } else {
        build_provider(&filtered)
    };
    let file = if cfg.output_full_config {
        out_dir.join(format!("{}_config.yaml", name))
    } else {
        out_dir.join(format!("{}_provider.yaml", name))
    };
    let _ = fs::write(&file, yaml);
    log_worker(
        tx,
        LogLevel::Success,
        format!("✅ PHASE 3 {} -> {}", name, file.display()),
    );
}

pub fn convert_tested_to_clash(
    mixed: &BTreeSet<String>,
    ping: &BTreeSet<String>,
    speed: &BTreeSet<String>,
    output_dir: &Path,
    cfg: &ClashConverterConfig,
    tx: &Sender<AppEvent>,
) {
    if !cfg.enabled {
        return;
    }
    let out = output_dir.join("clash");
    let _ = fs::create_dir_all(&out);
    log_worker(
        tx,
        LogLevel::Info,
        format!(
            "🧩 PHASE 3 START | ping={} speed={} mixed={}",
            ping.len(),
            speed.len(),
            mixed.len()
        ),
    );
    convert_set("ping", ping, &out, cfg, tx);
    convert_set("speed", speed, &out, cfg, tx);
    convert_set("mixed", mixed, &out, cfg, tx);
    log_worker(tx, LogLevel::Success, "✅ PHASE 3 COMPLETE".to_string());
}
