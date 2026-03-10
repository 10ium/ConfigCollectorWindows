use reqwest::blocking::ClientBuilder;
use std::collections::{BTreeMap, BTreeSet};
use std::io::Read;
use std::net::TcpListener;
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::Sender;
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

use crate::config::TesterConfig;
use crate::scraper::{log_worker, AppEvent, LogLevel};
use crate::storage::NON_MIXED_PROTOCOLS;

/// پیدا کردن یک پورت آزاد برای اجرای پروکسی محلی (جلوگیری از تداخل پورت‌ها در تست همزمان)
fn get_available_port(start: u16) -> u16 {
    let mut port = start;
    loop {
        if TcpListener::bind(("127.0.0.1", port)).is_ok() {
            return port;
        }
        port += 1;
        if port > 65000 {
            return start; // Fallback
        }
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

    // جدا کردن کانفیگ‌های قابل تست (نادیده گرفتن tg, dns و ...)
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

    log_worker(&tx, LogLevel::Warning, format!("🔬 PHASE 2: Testing {} configs using xray-knife. This may take a while...", total));

    let queue = Arc::new(Mutex::new(to_test));
    let working_configs = Arc::new(Mutex::new(BTreeSet::new()));
    let mut handles = vec![];

    // تعیین تعداد پردازش‌های همزمان (مثلاً 10 تا)
    let threads_count = tester_cfg.concurrent_tests.max(1).min(total);
    let base_port = 20000;

    for i in 0..threads_count {
        let q = queue.clone();
        let w = working_configs.clone();
        let cfg = tester_cfg.clone();
        let stop = stop_flag.clone();
        let tx_c = tx.clone();
        let initial_port = base_port + (i as u16) * 5; // فاصله پورت‌ها برای اطمینان

        handles.push(thread::spawn(move || {
            loop {
                if stop.load(Ordering::SeqCst) { break; }

                let (proto, config_str) = {
                    let mut lock = q.lock().unwrap();
                    match lock.pop() {
                        Some(item) => item,
                        None => break,
                    }
                };

                // دریافت پورت خالی ایمن برای این ترد
                let p = get_available_port(initial_port);

                // 1. اجرای xray-knife در پس‌زمینه
                let mut child = match Command::new(&cfg.xray_knife_path)
                    .args(&["proxy", "--inbound", "socks", "--port", &p.to_string(), "-c", &config_str])
                    .stdout(Stdio::null())
                    .stderr(Stdio::null())
                    .spawn() {
                        Ok(c) => c,
                        Err(e) => {
                            log_worker(&tx_c, LogLevel::Error, format!("⚠️ xray-knife Missing! Path: '{}'. Error: {}", cfg.xray_knife_path, e));
                            break; // خروج ترد در صورت عدم یافتن ابزار
                        }
                    };

                // فرصت 1.5 ثانیه‌ای برای بالا آمدن هسته xray و بایند شدن روی پورت
                thread::sleep(Duration::from_millis(1500));

                if stop.load(Ordering::SeqCst) {
                    let _ = child.kill();
                    break;
                }

                let mut is_working = false;
                let loop_proxy_url = format!("socks5://127.0.0.1:{}", p);

                // 2. ساخت کلاینت دایرکت، صرفاً متصل به این پورت محلی
                if let Ok(loop_proxy) = reqwest::Proxy::all(&loop_proxy_url) {
                    if let Ok(client) = ClientBuilder::new()
                        .no_proxy() // مهم: غیرفعال کردن صد در صدی پروکسی سیستم
                        .proxy(loop_proxy) // اعمال پروکسی محلی xray-knife
                        .timeout(Duration::from_secs(cfg.timeout_secs)) // 6 ثانیه مهلت دانلود
                        .danger_accept_invalid_certs(true)
                        .build() {
                            
                            // 3. تلاش برای دانلود فایل
                            if let Ok(mut resp) = client.get(&cfg.test_url).send() {
                                if resp.status().is_success() {
                                    let mut buf = [0; 512];
                                    // تست دریافت حجم بزرگتر از 0 کیلوبایت
                                    if let Ok(read_bytes) = resp.read(&mut buf) {
                                        if read_bytes > 0 {
                                            is_working = true;
                                        }
                                    }
                                }
                            }
                    }
                }

                // 4. بستن اجباری و پاکسازی پروسه xray-knife
                let _ = child.kill();
                let _ = child.wait(); // جلوگیری از ایجاد پردازش‌های Zombie

                if is_working {
                    w.lock().unwrap().insert(config_str.clone());
                    log_worker(&tx_c, LogLevel::Success, format!("✔️ [PASS] {}", proto));
                } else {
                    log_worker(&tx_c, LogLevel::Debug, format!("❌ [TIMEOUT/0KB] {}", proto));
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

    let working_set = Arc::try_unwrap(working_configs).unwrap().into_inner().unwrap();
    let passed_count = working_set.len();

    log_worker(&tx, LogLevel::Success, format!("🏁 Testing Complete: {}/{} passed Phase 2.", passed_count, total));

    // 5. اعمال فیلتر روی نقشه‌ی اصلی کانفیگ‌ها
    for (proto, links) in configs_map.iter_mut() {
        if !NON_MIXED_PROTOCOLS.contains(&proto.as_str()) {
            links.retain(|link| working_set.contains(link));
        }
    }
}
