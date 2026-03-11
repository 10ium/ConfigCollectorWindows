use anyhow::Result;
use base64::{engine::general_purpose::STANDARD as B64, Engine};
use regex::Regex;
use serde_json::Value;
use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::Path;

pub const NON_MIXED_PROTOCOLS: [&str; 8] = [
    "tg",
    "dns",
    "nm-dns",
    "nm-vless",
    "slipnet-enc",
    "slipnet",
    "slipstream",
    "dnstt",
];

pub const CLOUDFLARE_DOMAINS: [&str; 4] = [
    ".workers.dev",
    ".pages.dev",
    ".trycloudflare.com",
    "chatgpt.com",
];

pub fn is_windows_compatible(link: &str) -> bool {
    let re = Regex::new(r"secret=([a-zA-Z0-9%_\-]+)").unwrap();
    if let Some(caps) = re.captures(link) {
        let secret = caps[1].to_lowercase();
        if secret.contains('%') || secret.contains('_') || secret.contains('-') {
            return false;
        }
        if secret.starts_with("ee") {
            return false;
        }
        let actual_secret = if secret.starts_with("dd") {
            &secret[2..]
        } else {
            &secret
        };
        if actual_secret.len() != 32 {
            return false;
        }
        return actual_secret.chars().all(|c| c.is_ascii_hexdigit());
    }
    false
}

pub fn is_behind_cloudflare(link: &str) -> bool {
    let check_domain = |d: &str| -> bool {
        let lower = d.to_lowercase();
        if lower == "chatgpt.com" {
            return true;
        }
        CLOUDFLARE_DOMAINS.iter().any(|&cf| lower.ends_with(cf))
    };

    let lower_link = link.to_lowercase();
    if lower_link.starts_with("vmess://") {
        let b64_str = &link[8..];
        if let Ok(decoded) = B64.decode(b64_str) {
            if let Ok(json_str) = String::from_utf8(decoded) {
                if let Ok(parsed) = serde_json::from_str::<Value>(&json_str) {
                    if let Some(obj) = parsed.as_object() {
                        for field in ["add", "host", "sni"] {
                            if let Some(val) = obj.get(field).and_then(|v| v.as_str()) {
                                if check_domain(val) {
                                    return true;
                                }
                            }
                        }
                    }
                }
            }
        }
    } else {
        for cf in CLOUDFLARE_DOMAINS {
            if lower_link.contains(cf) {
                return true;
            }
        }
    }
    false
}

pub fn save_content(
    base_dir: &Path,
    filename: &str,
    content_list: &BTreeSet<String>,
) -> Result<()> {
    if content_list.is_empty() {
        return Ok(());
    }

    // ساخت زیرپوشه‌های مجزا
    let normal_dir = base_dir.join("normal");
    let base64_dir = base_dir.join("base64");
    fs::create_dir_all(&normal_dir)?;
    fs::create_dir_all(&base64_dir)?;

    let lines: Vec<String> = content_list.iter().cloned().collect();
    let content_str = lines.join("\n");

    fs::write(normal_dir.join(format!("{filename}.txt")), &content_str)?;

    let b64_str = B64.encode(content_str.as_bytes());
    fs::write(base64_dir.join(format!("{filename}_base64.txt")), b64_str)?;

    Ok(())
}

pub fn save_content_append(
    base_dir: &Path,
    filename: &str,
    new_content: &BTreeSet<String>,
) -> Result<()> {
    if new_content.is_empty() {
        return Ok(());
    }

    let normal_dir = base_dir.join("normal");
    let base64_dir = base_dir.join("base64");
    fs::create_dir_all(&normal_dir)?;
    fs::create_dir_all(&base64_dir)?;

    let txt_path = normal_dir.join(format!("{filename}.txt"));
    let mut combined = read_existing_set(&txt_path)?;
    combined.extend(new_content.iter().cloned());

    let lines: Vec<String> = combined.into_iter().collect();
    let content_str = lines.join("\n");

    fs::write(&txt_path, &content_str)?;

    let b64_str = B64.encode(content_str.as_bytes());
    fs::write(base64_dir.join(format!("{filename}_base64.txt")), b64_str)?;

    Ok(())
}

pub fn write_files_standard(
    base_dir: &Path,
    data_map: &BTreeMap<String, BTreeSet<String>>,
) -> Result<()> {
    let mut mixed_content = BTreeSet::new();
    let mut cloudflare_content = BTreeSet::new();
    let mut slipnet_mixed_content = BTreeSet::new();

    for (proto, lines) in data_map {
        if lines.is_empty() {
            continue;
        }

        if !NON_MIXED_PROTOCOLS.contains(&proto.as_str()) {
            mixed_content.extend(lines.iter().cloned());
            for link in lines {
                if is_behind_cloudflare(link) {
                    cloudflare_content.insert(link.clone());
                }
            }
            save_content(base_dir, proto, lines)?;
        } else if proto == "tg" {
            let mut windows_tg = BTreeSet::new();
            let mut android_tg = BTreeSet::new();
            for link in lines {
                if is_windows_compatible(link) {
                    windows_tg.insert(link.clone());
                } else {
                    android_tg.insert(link.clone());
                }
            }
            save_content(base_dir, "tg_windows", &windows_tg)?;
            save_content(base_dir, "tg_android", &android_tg)?;
            save_content(base_dir, "tg", lines)?;
        } else {
            if proto == "slipnet" || proto == "slipnet-enc" {
                slipnet_mixed_content.extend(lines.iter().cloned());
            }
            save_content(base_dir, proto, lines)?;
        }
    }

    save_content(base_dir, "mixed", &mixed_content)?;
    save_content(base_dir, "cloudflare", &cloudflare_content)?;
    save_content(base_dir, "slipnet_mixed", &slipnet_mixed_content)?;

    Ok(())
}

pub fn write_files_standard_append(
    base_dir: &Path,
    data_map: &BTreeMap<String, BTreeSet<String>>,
) -> Result<()> {
    let mut mixed_content = BTreeSet::new();
    let mut cloudflare_content = BTreeSet::new();
    let mut slipnet_mixed_content = BTreeSet::new();

    for (proto, lines) in data_map {
        if lines.is_empty() {
            continue;
        }

        if !NON_MIXED_PROTOCOLS.contains(&proto.as_str()) {
            mixed_content.extend(lines.iter().cloned());
            for link in lines {
                if is_behind_cloudflare(link) {
                    cloudflare_content.insert(link.clone());
                }
            }
            save_content_append(base_dir, proto, lines)?;
        } else if proto == "tg" {
            let mut windows_tg = BTreeSet::new();
            let mut android_tg = BTreeSet::new();
            for link in lines {
                if is_windows_compatible(link) {
                    windows_tg.insert(link.clone());
                } else {
                    android_tg.insert(link.clone());
                }
            }
            save_content_append(base_dir, "tg_windows", &windows_tg)?;
            save_content_append(base_dir, "tg_android", &android_tg)?;
            save_content_append(base_dir, "tg", lines)?;
        } else {
            if proto == "slipnet" || proto == "slipnet-enc" {
                slipnet_mixed_content.extend(lines.iter().cloned());
            }
            save_content_append(base_dir, proto, lines)?;
        }
    }

    save_content_append(base_dir, "mixed", &mixed_content)?;
    save_content_append(base_dir, "cloudflare", &cloudflare_content)?;
    save_content_append(base_dir, "slipnet_mixed", &slipnet_mixed_content)?;

    Ok(())
}

pub fn read_existing_set(path: &Path) -> Result<BTreeSet<String>> {
    if !path.exists() {
        return Ok(BTreeSet::new());
    }
    let raw = fs::read_to_string(path)?;
    let lines = raw
        .lines()
        .map(str::trim)
        .filter(|l| !l.is_empty())
        .map(ToOwned::to_owned)
        .collect();
    Ok(lines)
}

pub fn write_mixed_only(base_dir: &Path, mixed_links: &BTreeSet<String>) -> Result<()> {
    save_content(base_dir, "mixed", mixed_links)
}

pub fn write_mixed_only_append(base_dir: &Path, mixed_links: &BTreeSet<String>) -> Result<()> {
    save_content_append(base_dir, "mixed", mixed_links)
}
