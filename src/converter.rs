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

/// رمزگشایی استاندارد کاراکترهای درصد گذاری شده (Percent-Decoding) برای نمایش صحیح اموجی‌ها و متون یونیکد
fn safe_decode(s: &str) -> String {
    let mut out = String::new();
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
                out.push(byte as char);
            } else {
                out.push('%');
                out.push_str(&hex);
            }
        } else if c == '+' {
            out.push(' ');
        } else {
            out.push(c);
        }
    }
    // پاکسازی فاصله‌های اضافی احتمالی در ابتدا و انتها
    out.trim().to_string()
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

            // حذف پسوند لوله‌های اضافی خالی که ممکن است در انتهای رشته بعد از دکد شدن تگ ایجاد شود
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

fn build_full_config(proxies: &[Value]) -> String {
    if proxies.is_empty() {
        return "proxies: []\n".to_string();
    }
    let list = proxies
        .iter()
        .map(|p| {
            format!(
                "  - {}",
                serde_json::to_string(p).unwrap_or_else(|_| "{}".to_string())
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let names = proxies
        .iter()
        .filter_map(|p| p.get("name").and_then(|v| v.as_str()))
        .map(|n| format!("      - \"{}\"", n))
        .collect::<Vec<_>>()
        .join("\n");
    format!(
        "global-client-fingerprint: chrome\nport: 7890\nsocks-port: 7891\nallow-lan: true\nmode: rule\n\nproxies:\n{}\n\nproxy-groups:\n  - name: AUTO\n    type: select\n    proxies:\n{}\n\nrules:\n  - MATCH,AUTO\n",
        list, names
    )
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
