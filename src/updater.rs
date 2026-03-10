use anyhow::{anyhow, Result};
use reqwest::blocking::Client;
use serde_json::Value;
use std::fs::File;
use std::io::{self, Cursor, Read};
use std::sync::mpsc::Sender;

use crate::scraper::{AppEvent, LogLevel};

/// ارسال لاگ به رابط کاربری
pub fn log_updater(tx: &Sender<AppEvent>, level: LogLevel, text: String) {
    let _ = tx.send(AppEvent::Log(level, text));
}

/// دانلود و استخراج مستقیم xray-knife (نسخه ویندوز) روی دیسک
pub fn update_xray_knife(client: Client, target_path: String, tx: Sender<AppEvent>) -> Result<()> {
    log_updater(&tx, LogLevel::Info, "🔄 Checking GitHub for the latest Windows release of xray-knife...".to_string());

    let api_url = "https://api.github.com/repos/lilendian0x00/xray-knife/releases/latest";
    
    // دریافت اطلاعات آخرین نسخه (پروکسی روی client از قبل تنظیم شده است)
    let resp: Value = client.get(api_url).send()?.json()?;

    let assets = resp["assets"]
        .as_array()
        .ok_or_else(|| anyhow!("No assets found in the latest release!"))?;
        
    let mut download_url = None;
    for asset in assets {
        if let Some(name) = asset["name"].as_str() {
            let name_lower = name.to_lowercase();
            // جستجوی فایل مربوط به ویندوز 64 بیت
            if name_lower.contains("windows-64") && name_lower.ends_with(".zip") {
                download_url = asset["browser_download_url"].as_str().map(|s| s.to_string());
                break;
            }
        }
    }

    let url = download_url.ok_or_else(|| anyhow!("Could not find a suitable Windows .zip file!"))?;

    log_updater(&tx, LogLevel::Info, format!("📥 Downloading package: {}", url));
    
    // دانلود فایل فشرده
    let mut response = client.get(&url).send()?;
    if !response.status().is_success() {
        return Err(anyhow!("Failed to download file. HTTP Status: {}", response.status()));
    }

    let mut buf = Vec::new();
    response.read_to_end(&mut buf)?;

    log_updater(&tx, LogLevel::Info, "📦 Extracting 'xray-knife.exe' directly to disk...".to_string());
    
    // باز کردن فایل فشرده در حافظه RAM
    let cursor = Cursor::new(buf);
    let mut archive = zip::ZipArchive::new(cursor)?;

    let target_file_name = "xray-knife.exe";
    let mut found = false;

    // جستجو در فایل زیپ برای پیدا کردن فایل اجرایی و ذخیره دائم آن روی دیسک
    for i in 0..archive.len() {
        let mut file = archive.by_index(i)?;
        if file.name().ends_with(target_file_name) {
            // ساخت/جایگزینی فایل نهایی روی دیسک کاربر
            let mut out_file = File::create(&target_path)?;
            io::copy(&mut file, &mut out_file)?;
            found = true;
            break;
        }
    }

    if !found {
        return Err(anyhow!("Could not find 'xray-knife.exe' inside the downloaded archive."));
    }

    log_updater(&tx, LogLevel::Success, "✅ xray-knife.exe updated/downloaded and saved to disk successfully!".to_string());
    Ok(())
}
