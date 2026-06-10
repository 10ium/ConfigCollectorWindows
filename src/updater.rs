use anyhow::{anyhow, Result};
use reqwest::blocking::Client;
use serde_json::Value;
use std::fs::{self, File};
use std::io::{self, Cursor, Read};
use std::path::Path;
use std::sync::mpsc::Sender;

use crate::scraper::{AppEvent, LogLevel};

/// ارسال لاگ به رابط کاربری
pub fn log_updater(tx: &Sender<AppEvent>, level: LogLevel, text: String) {
    let _ = tx.send(AppEvent::Log(level, text));
}

fn parse_version_parts(version: &str) -> (u64, u64, u64) {
    let cleaned = version.trim().trim_start_matches('v');
    let mut parts = cleaned.split('.').filter_map(|p| p.parse::<u64>().ok());
    (
        parts.next().unwrap_or(0),
        parts.next().unwrap_or(0),
        parts.next().unwrap_or(0),
    )
}

/// دانلود و جایگزینی خودکار فایل اجرایی نرم‌افزار (Self Update Auto-Detect)
pub fn update_main_app(client: Client, repo_name: String, tx: Sender<AppEvent>) -> Result<()> {
    log_updater(
        &tx,
        LogLevel::Info,
        format!(
            "🔄 Checking GitHub for the latest App release in '{}'...",
            repo_name
        ),
    );

    let api_url = format!("https://api.github.com/repos/{}/releases/latest", repo_name);

    // دریافت اطلاعات آخرین نسخه از API گیت‌هاب (با استفاده از پروکسی کلاینت)
    let resp: Value = client.get(&api_url).send()?.json()?;

    let assets = resp["assets"]
        .as_array()
        .ok_or_else(|| anyhow!("No assets found in the latest release!"))?;

    let mut download_url = None;
    let version_tag = resp["tag_name"].as_str().unwrap_or("Unknown").to_string();

    let current_version = env!("CARGO_PKG_VERSION");
    let latest = parse_version_parts(&version_tag);
    let current = parse_version_parts(current_version);

    if latest <= current {
        log_updater(
            &tx,
            LogLevel::Success,
            format!(
                "✅ You are already on the latest version (current: {}, latest: {}).",
                current_version, version_tag
            ),
        );
        return Ok(());
    }

    for asset in assets {
        if let Some(name) = asset["name"].as_str() {
            let name_lower = name.to_lowercase();
            // جستجوی فایل نصبی/اجرایی ویندوز (پسوند .exe)
            if name_lower.ends_with(".exe") {
                download_url = asset["browser_download_url"]
                    .as_str()
                    .map(|s| s.to_string());
                break;
            }
        }
    }

    let url = download_url
        .ok_or_else(|| anyhow!("Could not find a suitable .exe file in the latest release!"))?;

    log_updater(
        &tx,
        LogLevel::Info,
        format!(
            "📥 Found Version [{}]. Downloading core update from: {}",
            version_tag, url
        ),
    );

    let mut response = client.get(&url).send()?;
    if !response.status().is_success() {
        return Err(anyhow!(
            "Failed to download update. HTTP Status: {}",
            response.status()
        ));
    }

    // ایجاد یک فایل موقت برای ذخیره نسخه جدید
    let temp_file_path = "ConfigCollector_update_temp.exe";
    let mut out_file = File::create(temp_file_path)?;
    response.copy_to(&mut out_file)?;

    log_updater(
        &tx,
        LogLevel::Warning,
        "🔄 Applying update to the running executable...".to_string(),
    );

    // استفاده از کتابخانه self_replace برای دور زدن خطای File-in-use ویندوز
    self_replace::self_replace(temp_file_path)?;

    // پاکسازی فایل موقت
    let _ = fs::remove_file(temp_file_path);

    log_updater(
        &tx,
        LogLevel::Success,
        "✅ App updated successfully! Please CLOSE and RESTART the application to apply changes."
            .to_string(),
    );
    Ok(())
}

/// دانلود، اعتبارسنجی آفلاین نسخه و استخراج مستقیم xray-knife (نسخه ویندوز) روی دیسک
pub fn update_xray_knife(client: Client, target_path: String, tx: Sender<AppEvent>) -> Result<()> {
    log_updater(
        &tx,
        LogLevel::Info,
        "🔄 Checking GitHub for the latest Windows release of xray-knife...".to_string(),
    );

    let api_url = "https://api.github.com/repos/lilendian0x00/xray-knife/releases/latest";
    let resp: Value = client.get(api_url).send()?.json()?;

    let version_tag = resp["tag_name"].as_str().unwrap_or("Unknown").to_string();

    // ردیاب آفلاین و محلی فایل نسخه هسته
    let version_file_path = "config/xray_knife_version.txt";
    if Path::new(&target_path).exists() && Path::new(version_file_path).exists() {
        if let Ok(local_version) = fs::read_to_string(version_file_path) {
            if local_version.trim() == version_tag.trim() {
                log_updater(
                    &tx,
                    LogLevel::Success,
                    format!(
                        "✅ xray-knife.exe is already up-to-date (Version: {}). No download required.",
                        version_tag
                    ),
                );
                return Ok(());
            }
        }
    }

    let assets = resp["assets"]
        .as_array()
        .ok_or_else(|| anyhow!("No assets found in the latest release!"))?;

    let mut download_url = None;
    for asset in assets {
        if let Some(name) = asset["name"].as_str() {
            let name_lower = name.to_lowercase();
            if name_lower.contains("windows-64") && name_lower.ends_with(".zip") {
                download_url = asset["browser_download_url"]
                    .as_str()
                    .map(|s| s.to_string());
                break;
            }
        }
    }

    let url =
        download_url.ok_or_else(|| anyhow!("Could not find a suitable Windows .zip file!"))?;

    log_updater(
        &tx,
        LogLevel::Info,
        format!("📥 Downloading package: {} (Tag: {})", url, version_tag),
    );

    let mut response = client.get(&url).send()?;
    if !response.status().is_success() {
        return Err(anyhow!(
            "Failed to download file. HTTP Status: {}",
            response.status()
        ));
    }

    let mut buf = Vec::new();
    response.read_to_end(&mut buf)?;

    log_updater(
        &tx,
        LogLevel::Info,
        "📦 Extracting 'xray-knife.exe' directly to disk...".to_string(),
    );

    let cursor = Cursor::new(buf);
    let mut archive = zip::ZipArchive::new(cursor)?;

    let target_file_name = "xray-knife.exe";
    let mut found = false;

    for i in 0..archive.len() {
        let mut file = archive.by_index(i)?;
        if file.name().ends_with(target_file_name) {
            let mut out_file = File::create(&target_path)?;
            io::copy(&mut file, &mut out_file)?;
            found = true;
            break;
        }
    }

    if !found {
        return Err(anyhow!(
            "Could not find 'xray-knife.exe' inside the downloaded archive."
        ));
    }

    // نوشتن موفق فایل نسخه روی سیستم کاربر جهت ردیابی آفلاین در اجراهای بعدی
    if let Some(parent) = Path::new(version_file_path).parent() {
        let _ = fs::create_dir_all(parent);
    }
    let _ = fs::write(version_file_path, &version_tag);

    log_updater(
        &tx,
        LogLevel::Success,
        format!(
            "✅ xray-knife.exe updated/downloaded and saved to disk successfully! (Version: {})",
            version_tag
        ),
    );
    Ok(())
}
