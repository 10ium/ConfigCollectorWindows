use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::Sender;
use std::sync::Arc;
#[cfg(windows)]
use std::os::windows::process::CommandExt;

use crate::config::TesterConfig;
use crate::scraper::{log_worker, AppEvent, LogLevel};

/// اجرای فاز دوم: تست دسته‌ای (Batch Test) کانفیگ‌ها با xray-knife
pub fn filter_working_configs(
    configs_map: &mut BTreeMap<String, BTreeSet<String>>,
    tester_cfg: &TesterConfig,
    stop_flag: Arc<AtomicBool>,
    tx: Sender<AppEvent>,
) {
    if !tester_cfg.enabled {
        return;
    }

    // ۱. استخراج تمامی کانفیگ‌ها برای تست
    let mut all_configs = Vec::new();
    for links in configs_map.values() {
        all_configs.extend(links.iter().cloned());
    }

    if all_configs.is_empty() { return; }
    
    let input_file = "temp_configs.txt";
    let output_csv = "results.csv";
    let _ = fs::write(input_file, all_configs.join("\n"));

    log_worker(&tx, LogLevel::Info, format!("🔬 Starting Batch Test ({} configs)...", all_configs.len()));

    // ۲. ساخت دستور اجرایی
    let mut cmd = Command::new(&tester_cfg.xray_knife_path);
    let mut args = vec![
        "http", 
        "-f", input_file, 
        "-o", output_csv, 
        "-x", "csv",
        "-t", &tester_cfg.concurrent_tests.to_string(),
        "--timeout", &tester_cfg.timeout_secs.to_string()
    ];

    if tester_cfg.ping_enabled {
        args.extend(["--url", &tester_cfg.ping_url]);
    }

    if tester_cfg.speed_test_enabled {
        args.extend(["--speedtest", "--speedtest-url", &tester_cfg.speed_test_url]);
    }

    cmd.args(&args);

    // مخفی‌سازی پنجره کنسول در ویندوز
    #[cfg(windows)]
    cmd.creation_flags(0x08000000); // CREATE_NO_WINDOW

    let status = cmd.stdout(Stdio::null()).stderr(Stdio::null()).spawn().and_then(|mut c| c.wait());

    // ۳. پردازش نتایج CSV
    if let Ok(_) = status {
        if let Ok(content) = fs::read_to_string(output_csv) {
            let mut passed_configs: BTreeMap<String, BTreeSet<String>> = BTreeMap::new();
            
            // پردازش خطوط CSV (ستون‌ها: Link, Delay, Speed)
            for line in content.lines().skip(1) {
                let cols: Vec<&str> = line.split(',').collect();
                if cols.len() < 2 { continue; }
                
                let link = cols[0].to_string();
                let delay = cols[1].to_string();
                
                // اضافه کردن پینگ به نام اگر فعال باشد
                let final_link = if tester_cfg.append_ping_flag {
                    if let Some(pos) = link.rfind('#') {
                        format!("{}-[Ping:{}ms]", link, delay)
                    } else {
                        format!("{}#[Ping:{}ms]", link, delay)
                    }
                } else {
                    link
                };

                let proto = final_link.split("://").next().unwrap_or("unknown").to_string();
                passed_configs.entry(proto).or_default().insert(final_link);
            }
            *configs_map = passed_configs;
        }
    }

    // ۴. پاکسازی فایل‌های موقت
    let _ = fs::remove_file(input_file);
    let _ = fs::remove_file(output_csv);
    
    log_worker(&tx, LogLevel::Success, "🏁 Batch Testing Complete.".to_string());
}
