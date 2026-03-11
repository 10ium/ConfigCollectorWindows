use reqwest::blocking::ClientBuilder;
use std::collections::{BTreeMap, BTreeSet};
use std::io::Read;
use std::net::TcpListener;
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::Sender;
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use crate::config::TesterConfig;
use crate::scraper::{log_worker, AppEvent, LogLevel};
use crate::storage::NON_MIXED_PROTOCOLS;

/// پیدا کردن یک پورت آزاد برای اجرای پروکسی محلی (جلوگیری از تداخل در تست همزمان)
fn get_available_port(start: u16) -> u16 {
    let mut port = start;
    loop {
        if TcpListener::bind(("127.0.0.1", port)).is_ok() {
            return port;
        }
        port += 1;
        if port > 65000 {
            return start;
        }
    }
}

/// تابع کمکی برای اضافه کردن زمان پینگ به انتهای نام کانفیگ
fn append_ping_to_config(config_str: &str, ping_ms: u128) -> String {
    let flag = format!("[Ping:{}ms]", ping_ms);
    if let Some(pos) = config_str.rfind('#') {
        // اگر از قبل نام (Remark) دارد، پرچم را به آن اضافه می‌کنیم
        format!("{}-{}", config_str, flag)
    } else {
        // اگر نام ندارد، یک هش‌تگ جدید ایجاد می‌کنیم
        format!("{}#{}", config_str, flag)
    }
}

/// اجرای فاز دوم: تست کانفیگ‌های جدید از طریق xray-knife
pub fn filter_working_configs(
    configs_map: &mut BTreeMap<String, BTreeSet<String>>,
    tester_cfg: &TesterConfig,
    stop_flag: Arc<AtomicBool>,
    tx: Sender<AppEvent>,
) {
    if !tester_cfg.enabled {
        return;
    }

    // جدا کردن کانفیگ‌های قابل تست
    let mut to_test = Vec::new();
    for (proto, links) in configs_map.iter() {
        if !NON_MIXED_PROTOCOLS.contains(&proto.as_str()) {
            for link in links {
                to_test.push((proto.clone(), link.clone()));
            }
        }
    }

    let total = to_test.len();
    if total == 0 {
        return;
    }

    log_worker(
        &tx,
        LogLevel::Warning,
        format!(
            "🔬 PHASE 2: Testing {} configs... (SpeedTest: {}, AddPing: {})",
            total, tester_cfg.speed_test_enabled, tester_cfg.append_ping_flag
        ),
    );

    let queue = Arc::new(Mutex::new(to_test));
    // ذخیره نتیجه به صورت (پروتکل، کانفیگ_نهایی)
    let working_configs = Arc::new(Mutex::new(Vec::new()));
    let mut handles = vec![];

    let threads_count = tester_cfg.concurrent_tests.max(1).min(total);
    let base_port = 20000;

    for i in 0..threads_count {
        let q = queue.clone();
        let w = working_configs.clone();
        let cfg = tester_cfg.clone();
        let stop = stop_flag.clone();
        let tx_c = tx.clone();
        let initial_port = base_port + (i as u16) * 10;

        handles.push(thread::spawn(move || {
            loop {
                if stop.load(Ordering::SeqCst) {
                    break;
                }

                let (proto, original_config_str) = {
                    let mut lock = q.lock().unwrap();
                    match lock.pop() {
                        Some(item) => item,
                        None => break,
                    }
                };

                let p = get_available_port(initial_port);

                // ۱. اجرای xray-knife
                let mut child = match Command::new(&cfg.xray_knife_path)
                    .args(&[
                        "proxy",
                        "--inbound",
                        "socks",
                        "--port",
                        &p.to_string(),
                        "-c",
                        &original_config_str,
                    ])
                    .stdout(Stdio::null())
                    .stderr(Stdio::null())
                    .stdin(Stdio::null())
                    .spawn()
                {
                    Ok(c) => c,
                    Err(e) => {
                        log_worker(
                            &tx_c,
                            LogLevel::Error,
                            format!("⚠️ xray-knife Missing! Path: '{}'. Error: {}", cfg.xray_knife_path, e),
                        );
                        break;
                    }
                };

                // مهلت برای بالا آمدن هسته و بایند شدن روی پورت
                thread::sleep(Duration::from_millis(1500));

                if stop.load(Ordering::SeqCst) {
                    let _ = child.kill();
                    let _ = child.wait();
                    break;
                }

                let mut is_working = false;
                let mut ping_time = 0;
                let loop_proxy_url = format!("socks5://127.0.0.1:{}", p);

                // ۲. ساخت کلاینت دایرکت، صرفاً متصل به این پورت محلی
                if let Ok(loop_proxy) = reqwest::Proxy::all(&loop_proxy_url) {
                    if let Ok(client) = ClientBuilder::new()
                        .no_proxy() // مهم: غیرفعال کردن صد در صدی پروکسی سیستم تا تست واقعی باشد
                        .proxy(loop_proxy)
                        .timeout(Duration::from_secs(cfg.timeout_secs))
                        .danger_accept_invalid_certs(true)
                        .build()
                    {
                        let start_time = Instant::now();
                        
                        // ۳. تلاش برای ارتباط و دانلود
                        if let Ok(mut resp) = client.get(&cfg.test_url).send() {
                            if resp.status().is_success() {
                                if cfg.speed_test_enabled {
                                    let mut buf = [0; 1024]; // تست دریافت حداقل ۱ کیلوبایت
                                    if let Ok(read_bytes) = resp.read(&mut buf) {
                                        if read_bytes > 0 {
                                            is_working = true;
                                            ping_time = start_time.elapsed().as_millis();
                                        }
                                    }
                                } else {
                                    // اگر تست سرعت خاموش باشد، فقط هدرهای موفقیت‌آمیز کافیست
                                    is_working = true;
                                    ping_time = start_time.elapsed().as_millis();
                                }
                            }
                        }
                    }
                }

                // ۴. بستن اجباری و پاکسازی پروسه
                let _ = child.kill();
                let _ = child.wait();

                if is_working {
                    let final_config = if cfg.append_ping_flag {
                        append_ping_to_config(&original_config_str, ping_time)
                    } else {
                        original_config_str.clone()
                    };

                    w.lock().unwrap().push((proto.clone(), final_config));
                    log_worker(
                        &tx_c,
                        LogLevel::Success,
                        format!("✔️ [PASS] {} (Ping: {}ms)", proto, ping_time),
                    );
                } else {
                    log_worker(
                        &tx_c,
                        LogLevel::Debug,
                        format!("❌ [FAILED/TIMEOUT] {}", proto),
                    );
                }
            }
        }));
    }

    for h in handles {
        let _ = h.join();
    }

    if stop_flag.load(Ordering::SeqCst) {
        log_worker(&tx, LogLevel::Warning, "🛑 Tester interrupted.".to_string());
        return;
    }

    let working_list = Arc::try_unwrap(working_configs).unwrap().into_inner().unwrap();
    let passed_count = working_list.len();

    log_worker(
        &tx,
        LogLevel::Success,
        format!("🏁 Testing Complete: {}/{} passed Phase 2.", passed_count, total),
    );

    // ۵. جایگزینی کامل نقشه کانفیگ‌ها با کانفیگ‌های تایید شده (و احتمالاً تغییر نام یافته)
    for (proto, links) in configs_map.iter_mut() {
        if !NON_MIXED_PROTOCOLS.contains(&proto.as_str()) {
            links.clear(); // پاک کردن کانفیگ‌های تست نشده
        }
    }

    // اضافه کردن مجدد کانفیگ‌های سالم به نقشه
    for (proto, config) in working_list {
        configs_map.entry(proto).or_default().insert(config);
    }
}
