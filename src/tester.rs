use std::collections::{BTreeMap, BTreeSet, HashMap};
use std::fs;
use std::io::{BufReader, Read};
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::Sender;
use std::sync::Arc;
use std::thread;
use std::time::{Instant, SystemTime, UNIX_EPOCH, Duration};

use base64::{engine::general_purpose::STANDARD as B64, Engine};
use regex::Regex;
use serde_json::Value;

use crate::config::TesterConfig;
use crate::scraper::{log_worker, AppEvent, LogLevel};
use crate::storage::NON_MIXED_PROTOCOLS;

#[cfg(windows)]
const CREATE_NEW_CONSOLE: u32 = 0x00000010;
#[cfg(windows)]
const CREATE_NO_WINDOW: u32 = 0x0800_0000;

#[derive(Clone, Debug)]
struct TestResult {
    link: String,
    delay_ms: Option<u128>,
    download_kb: Option<f64>,
    country: Option<String>,
}

#[derive(Clone, Debug, Default)]
pub struct Phase2Result {
    pub ping_passed_mixed: BTreeSet<String>,
    pub speed_passed_mixed: BTreeSet<String>,
}

fn get_flag(cc: &str) -> String {
    let cc = cc.trim().to_uppercase();
    if cc.len() == 2 && cc.chars().all(|c| c.is_ascii_alphabetic()) {
        cc.chars()
            .map(|c| std::char::from_u32(127397 + c as u32).unwrap_or('🌐'))
            .collect()
    } else {
        "🌐".to_string()
    }
}

fn format_speed(download_kb: f64) -> String {
    if download_kb >= 1024.0 {
        format!("{:.1}MB", download_kb / 1024.0)
    } else {
        format!("{:.0}KB", download_kb.max(0.1))
    }
}

fn percent_encode(s: &str) -> String {
    let mut out = String::with_capacity(s.len() * 3);
    for byte in s.bytes() {
        match byte {
            b'a'..=b'z' | b'A'..=b'Z' | b'0'..=b'9' | b'-' | b'.' | b'_' | b'~' => {
                out.push(byte as char);
            }
            _ => {
                out.push_str(&format!("%{:02X}", byte));
            }
        }
    }
    out
}

fn percent_decode(s: &str) -> String {
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
    out
}

fn rename_config(
    link: &str,
    tester_cfg: &TesterConfig,
    result: &TestResult,
    rank: Option<usize>,
) -> String {
    let mut parts = Vec::new();

    let cc = result.country.as_deref().unwrap_or("UN");
    if tester_cfg.append_country_flag {
        parts.push(get_flag(cc));
        parts.push(cc.to_string());
    }

    if tester_cfg.append_ping_flag {
        if let Some(ping) = result.delay_ms {
            parts.push(format!("{}ms", ping));
        } else {
            parts.push("?ms".to_string());
        }
    }

    if tester_cfg.append_speed_flag {
        if let Some(dl) = result.download_kb {
            if dl > 0.0 {
                parts.push(format_speed(dl));
            } else {
                parts.push("Low".to_string());
            }
        }
    }

    if parts.is_empty() && rank.is_none() {
        return link.to_string();
    }

    let prefix = rank.map(|r| format!("[{}] ", r)).unwrap_or_default();
    let tag = format!("{}{}", prefix, parts.join(" | "));
    let tag_with_sep = if tag.is_empty() {
        String::new()
    } else {
        format!("{} | ", tag)
    };

    if link.starts_with("vmess://") {
        if let Some(base64_part) = link.strip_prefix("vmess://") {
            if let Ok(decoded) = B64.decode(base64_part) {
                if let Ok(mut json) = serde_json::from_slice::<Value>(&decoded) {
                    if let Some(obj) = json.as_object_mut() {
                        let old_ps = obj.get("ps").and_then(|v| v.as_str()).unwrap_or("Server");
                        obj.insert(
                            "ps".to_string(),
                            Value::String(format!("{}{}", tag_with_sep, old_ps)),
                        );
                        let new_json = serde_json::to_string(&obj).unwrap_or_default();
                        return format!("vmess://{}", B64.encode(new_json.as_bytes()));
                    }
                }
            }
        }
        return link.to_string();
    }

    let mut parts_iter = link.splitn(2, '#');
    let base = parts_iter.next().unwrap_or(link);
    let old_remark = parts_iter.next().unwrap_or("Server");

    let decoded_old = percent_decode(old_remark);
    let new_remark = format!("{}{}", tag_with_sep, decoded_old);

    format!("{}#{}", base, percent_encode(&new_remark))
}

fn strip_ansi(s: &str) -> String {
    let mut cleaned = String::with_capacity(s.len());
    let mut in_escape = false;
    for c in s.chars() {
        if c == '\x1B' {
            in_escape = true;
        } else if in_escape {
            if c.is_ascii_alphabetic() {
                in_escape = false;
            }
        } else if c != '\r' && c != '\u{FEFF}' {
            cleaned.push(c);
        }
    }
    cleaned.trim().to_string()
}

// تولید صدا و نوتیفیکیشن بدون نیاز به پکیج‌های خارجی و از طریق Powershell پنهان
fn trigger_alert(beep: bool, notify: bool) {
    if beep {
        thread::spawn(|| {
            #[cfg(windows)]
            let _ = Command::new("powershell")
                .args(&["-NoProfile", "-c", "[console]::beep(800,300)"])
                .creation_flags(CREATE_NO_WINDOW)
                .output();
        });
    }
    if notify {
        thread::spawn(|| {
            let script = r#"
            [reflection.assembly]::loadwithpartialname("System.Windows.Forms") | Out-Null
            $n = new-object system.windows.forms.notifyicon
            $n.icon = [system.drawing.systemicons]::information
            $n.visible = $true
            $n.showballoontip(3000, "Freedom Config Collector", "✅ Valid Config Found!", [system.windows.forms.tooltipicon]::info)
            Start-Sleep -Seconds 4
            $n.dispose()
            "#;
            #[cfg(windows)]
            let _ = Command::new("powershell")
                .args(&["-NoProfile", "-WindowStyle", "Hidden", "-Command", script])
                .creation_flags(CREATE_NO_WINDOW)
                .output();
        });
    }
}

fn run_xray_knife(
    tester_cfg: &TesterConfig,
    args: &[String],
    csv_path: &str,
    tx: &Sender<AppEvent>,
) -> bool {
    let mut command = Command::new(&tester_cfg.xray_knife_path);
    command
        .args(args)
        .stdin(Stdio::null())
        .env_remove("HTTP_PROXY")
        .env_remove("http_proxy")
        .env_remove("HTTPS_PROXY")
        .env_remove("https_proxy")
        .env_remove("ALL_PROXY")
        .env_remove("all_proxy")
        .env("NO_PROXY", "*")
        .env("no_proxy", "*");

    let show_window = tester_cfg.show_xray_window_on_windows;

    if show_window {
        // ایجاد کنسول واقعی و مستقل برای رفع مشکل صفحه سیاه
        #[cfg(windows)]
        command.creation_flags(CREATE_NEW_CONSOLE);
    } else {
        // استفاده از پایپ برای خواندن لاگ و پنهان کردن خط فرمان
        command.stdout(Stdio::piped());
        command.stderr(Stdio::piped());
        #[cfg(windows)]
        command.creation_flags(CREATE_NO_WINDOW);
    }

    match command.spawn() {
        Ok(mut child) => {
            let is_running = Arc::new(AtomicBool::new(true));
            
            // ترد ناظر هوشمند روی فایل CSV جهت تشخیص کانفیگ سالم
            let is_running_csv = is_running.clone();
            let csv_path_str = csv_path.to_string();
            let tx_clone_csv = tx.clone();
            let beep = tester_cfg.beep_on_found;
            let notify = tester_cfg.notify_on_found;

            thread::spawn(move || {
                let mut last_count = 0;
                let mut last_alert = Instant::now() - Duration::from_secs(10);

                while is_running_csv.load(Ordering::SeqCst) {
                    if let Ok(content) = fs::read_to_string(&csv_path_str) {
                        let lines = content.lines().count();
                        let passed = lines.saturating_sub(1); 
                        if passed > last_count {
                            let diff = passed - last_count;
                            last_count = passed;
                            
                            let _ = tx_clone_csv.send(AppEvent::Log(
                                LogLevel::Success, 
                                format!("🎉 Found {} new working config(s)! (Total: {})", diff, passed)
                            ));

                            // جلوگیری از هنگ کردن سیستم با محدود کردن تولید صدا (Rate Limit)
                            if (beep || notify) && last_alert.elapsed().as_secs() >= 3 {
                                trigger_alert(beep, notify);
                                last_alert = Instant::now();
                            }
                        }
                    }
                    thread::sleep(Duration::from_millis(1000));
                }
            });

            if show_window {
                let _ = tx.send(AppEvent::Log(
                    LogLevel::Info,
                    "🖥️ Xray-Knife is running in a separate console window. Please check it for progress...".to_string(),
                ));
            } else {
                let progress_step = tester_cfg.progress_log_step_percent.max(1) as i32;
                if let Some(stdout) = child.stdout.take() {
                    let tx_clone = tx.clone();
                    thread::spawn(move || {
                        let mut reader = BufReader::new(stdout);
                        let mut buf = Vec::new();
                        let mut last_pct = -1;
                        let mut last_done_count = 0usize;
                        let pct_re = Regex::new(r"(\d{1,3})\s*%").ok();
                        let count_re = Regex::new(r"(\d+)\s*/\s*(\d+)").ok();

                        loop {
                            let mut byte =[0u8; 1];
                            if reader.read_exact(&mut byte).is_err() {
                                break;
                            }

                            let b = byte[0];
                            if b == b'\n' || b == b'\r' {
                                if buf.is_empty() {
                                    continue;
                                }
                                let line = String::from_utf8_lossy(&buf).to_string();
                                buf.clear();

                                let clean_str = strip_ansi(&line);
                                if clean_str.is_empty() {
                                    continue;
                                }

                                if clean_str.contains("Testing configs") && clean_str.contains('%') {
                                    let mut should_emit = false;
                                    if let Some(re) = &pct_re {
                                        if let Some(cap) = re.captures(&clean_str) {
                                            if let Ok(pct) = cap[1].parse::<i32>() {
                                                if pct >= last_pct + progress_step || pct == 100 {
                                                    last_pct = pct;
                                                    should_emit = true;
                                                }
                                            }
                                        }
                                    }
                                    if let Some(re) = &count_re {
                                        if let Some(cap) = re.captures(&clean_str) {
                                            if let (Ok(d), Ok(t)) = (cap[1].parse::<usize>(), cap[2].parse::<usize>()) {
                                                let min_step = (t / 20).max(1);
                                                if d >= last_done_count.saturating_add(min_step) || d == t {
                                                    last_done_count = d;
                                                    should_emit = true;
                                                }
                                            }
                                        }
                                    }

                                    if should_emit {
                                        // نمایش دقیق رشته لاگ ابزار
                                        let _ = tx_clone.send(AppEvent::Log(LogLevel::Debug, clean_str));
                                    }
                                } else {
                                    // نمایش هدرها و متن‌های پیش‌فرض لاگ
                                    let _ = tx_clone.send(AppEvent::Log(LogLevel::Debug, clean_str));
                                }
                            } else {
                                buf.push(b);
                            }
                        }
                    });
                }

                if let Some(stderr) = child.stderr.take() {
                    let tx_clone = tx.clone();
                    thread::spawn(move || {
                        let mut reader = BufReader::new(stderr);
                        let mut buf = Vec::new();
                        loop {
                            let mut byte = [0u8; 1];
                            if reader.read_exact(&mut byte).is_err() {
                                break;
                            }
                            let b = byte[0];
                            if b == b'\n' || b == b'\r' {
                                if buf.is_empty() {
                                    continue;
                                }
                                let line = String::from_utf8_lossy(&buf).to_string();
                                buf.clear();
                                let clean_str = strip_ansi(&line);
                                if !clean_str.is_empty() && !clean_str.contains("Testing configs") {
                                    let _ = tx_clone.send(AppEvent::Log(
                                        LogLevel::Warning,
                                        clean_str,
                                    ));
                                }
                            } else {
                                buf.push(b);
                            }
                        }
                    });
                }
            }

            let success = child.wait().map(|s| s.success()).unwrap_or(false);
            is_running.store(false, Ordering::SeqCst);
            success
        }
        Err(e) => {
            let _ = tx.send(AppEvent::Log(
                LogLevel::Error,
                format!("❌ Failed to start xray-knife process: {}", e),
            ));
            false
        }
    }
}

fn append_extra_args(args: &mut Vec<String>, extra: &str) {
    args.extend(
        extra
            .split_whitespace()
            .filter(|s| !s.trim().is_empty())
            .map(|s| s.to_string()),
    );
}

fn build_temp_path(file_name: &str) -> String {
    let ts = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or(0);
    std::env::temp_dir()
        .join(format!("{}_{}", ts, file_name))
        .to_string_lossy()
        .to_string()
}

fn parse_delay(raw: &str) -> Option<u128> {
    let s = raw.trim().to_lowercase();
    if s.is_empty()
        || s == "0"
        || s == "-1"
        || s.contains("err")
        || s.contains("time")
        || s.contains("fail")
        || s.contains("exceed")
        || s.contains("deadline")
    {
        return None;
    }

    let just_numbers: String = s.chars().filter(|c| c.is_ascii_digit()).collect();
    if just_numbers.is_empty() || s.len() > just_numbers.len() + 5 {
        return None;
    }

    let val = just_numbers.parse::<u128>().ok()?;
    if val > 0 && val < 30000 {
        Some(val)
    } else {
        None
    }
}

fn parse_speed(raw: &str) -> Option<f64> {
    let s = raw.trim().to_lowercase();
    if s.is_empty()
        || s == "0"
        || s == "-1"
        || s.contains("err")
        || s.contains("time")
        || s.contains("fail")
        || s.contains("exceed")
        || s.contains("deadline")
    {
        return None;
    }

    let cleaned = s.replace(',', "");
    let numeric: String = cleaned
        .chars()
        .filter(|c| c.is_ascii_digit() || *c == '.')
        .collect();
    if numeric.is_empty() || cleaned.len() > numeric.len() + 10 {
        return None;
    }

    let mut value = numeric.parse::<f64>().ok()?;

    if cleaned.contains("gib") || cleaned.contains("gb") {
        value *= 1024.0 * 1024.0;
    } else if cleaned.contains("mib") || cleaned.contains("mb") {
        value *= 1024.0;
    } else if cleaned.contains("kib") || cleaned.contains("kb") {
        value *= 1.0;
    } else if cleaned.contains("bps") || cleaned.contains("b/s") || cleaned.ends_with('b') {
        value /= 1024.0;
    } else if value > 5000.0 {
        value /= 1024.0;
    }

    if value > 0.0 {
        Some(value)
    } else {
        None
    }
}

fn parse_csv_results(path: &str) -> Vec<TestResult> {
    let raw_content = fs::read_to_string(path).unwrap_or_default();
    let raw = raw_content.strip_prefix('\u{FEFF}').unwrap_or(&raw_content);

    let mut lines = raw.lines();
    let Some(header_line) = lines.next() else {
        return Vec::new();
    };

    let headers: Vec<String> = split_csv_line_auto(header_line)
        .into_iter()
        .map(|h| h.trim().trim_matches('"').to_lowercase())
        .collect();

    let link_idx = headers
        .iter()
        .position(|h| h == "link" || h == "config" || h.contains("url"))
        .unwrap_or(0);
    let status_idx = headers.iter().position(|h| h == "status" || h == "state");
    let delay_idx = headers
        .iter()
        .position(|h| h == "delay" || h.contains("ping"))
        .unwrap_or(usize::MAX);
    let location_idx = headers
        .iter()
        .position(|h| h == "location" || h == "cc")
        .unwrap_or(usize::MAX);

    let mut download_indices: Vec<usize> = headers
        .iter()
        .enumerate()
        .filter_map(|(idx, h)| {
            if h == "download"
                || h.contains("bandwidth")
                || (h.contains("speed") && !h.contains("speedtest"))
            {
                Some(idx)
            } else {
                None
            }
        })
        .collect();
    if download_indices.is_empty() {
        if let Some(idx) = headers.iter().position(|h| h == "speed") {
            download_indices.push(idx);
        }
    }

    let mut out = Vec::new();
    for line in lines {
        let cols = split_csv_line_with_delimiter(line, detect_csv_delimiter(header_line));
        if link_idx >= cols.len() {
            continue;
        }

        let link = cols[link_idx].trim().trim_matches('"').to_string();
        if link.is_empty() {
            continue;
        }

        if let Some(idx) = status_idx {
            if idx < cols.len() {
                let status_val = cols[idx].trim().trim_matches('"').to_lowercase();
                if status_val == "failed" || status_val == "error" || status_val == "timeout" {
                    continue;
                }
            }
        }

        let delay_ms = if delay_idx < cols.len() {
            parse_delay(cols[delay_idx].trim().trim_matches('"'))
        } else {
            None
        };

        let download_kb = download_indices
            .iter()
            .filter_map(|idx| cols.get(*idx))
            .filter_map(|v| parse_speed(v.trim().trim_matches('"')))
            .max_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));

        let country = if location_idx < cols.len() {
            let value = cols[location_idx].trim().trim_matches('"');
            if value.is_empty() || value == "null" {
                None
            } else {
                Some(value.to_string())
            }
        } else {
            None
        };

        out.push(TestResult {
            link,
            delay_ms,
            download_kb,
            country,
        });
    }

    out
}

fn detect_csv_delimiter(line: &str) -> char {
    let commas = line.matches(',').count();
    let semis = line.matches(';').count();
    if semis > commas {
        ';'
    } else {
        ','
    }
}

fn split_csv_line_auto(line: &str) -> Vec<String> {
    split_csv_line_with_delimiter(line, detect_csv_delimiter(line))
}

fn split_csv_line_with_delimiter(line: &str, delimiter: char) -> Vec<String> {
    let mut cols = Vec::new();
    let mut current = String::new();
    let mut in_quotes = false;
    let mut chars = line.chars().peekable();

    while let Some(ch) = chars.next() {
        match ch {
            '"' => {
                if in_quotes && chars.peek() == Some(&'"') {
                    current.push('"');
                    let _ = chars.next();
                } else {
                    in_quotes = !in_quotes;
                }
            }
            _ if ch == delimiter && !in_quotes => {
                cols.push(current.clone());
                current.clear();
            }
            _ => current.push(ch),
        }
    }
    cols.push(current);
    cols
}

pub fn filter_working_configs(
    configs_map: &mut BTreeMap<String, BTreeSet<String>>,
    tester_cfg: &TesterConfig,
    stop_flag: Arc<AtomicBool>,
    tx: Sender<AppEvent>,
) -> Phase2Result {
    let mut phase2 = Phase2Result::default();

    if !tester_cfg.enabled {
        return phase2;
    }

    let mut to_test = Vec::new();
    let mut proto_by_link = HashMap::new();
    for (proto, links) in configs_map.iter() {
        if !NON_MIXED_PROTOCOLS.contains(&proto.as_str()) {
            for link in links {
                to_test.push(link.clone());
                proto_by_link
                    .entry(link.clone())
                    .or_insert_with(|| proto.clone());
            }
        }
    }

    let total = to_test.len();
    if total == 0 {
        return phase2;
    }

    if !tester_cfg.ping_test_enabled && !tester_cfg.speed_test_enabled {
        log_worker(
            &tx,
            LogLevel::Warning,
            "⚠️ Tester enabled but Ping/Speed are disabled.".to_string(),
        );
        return phase2;
    }

    let debug_dir = "Debug_Raw_CSVs";
    let _ = fs::create_dir_all(debug_dir);

    log_worker(
        &tx,
        LogLevel::Info,
        format!(
            "🔬 PHASE 2 START | total={} | ping={} | speed={} | chain_ping_to_speed={}",
            total,
            tester_cfg.ping_test_enabled,
            tester_cfg.speed_test_enabled,
            tester_cfg.speed_test_from_ping_passed_only
        ),
    );

    let input_path = build_temp_path("configs_for_test.txt");
    if fs::write(&input_path, to_test.join("\n")).is_err() {
        log_worker(
            &tx,
            LogLevel::Error,
            "❌ Failed to create test input file.".to_string(),
        );
        return phase2;
    }

    if stop_flag.load(Ordering::SeqCst) {
        let _ = fs::remove_file(&input_path);
        return phase2;
    }

    let mut ping_selected: Vec<TestResult> = Vec::new();
    if tester_cfg.ping_test_enabled {
        let ping_started = Instant::now();
        let ping_csv = build_temp_path("ping_test_results.csv");
        let timeout_ms = (tester_cfg.timeout_secs.max(1) * 1000).to_string();

        let mut args = vec![
            "http".to_string(),
            "-f".to_string(),
            input_path.clone(),
            "-t".to_string(),
            tester_cfg.concurrent_tests.max(1).to_string(),
            "-o".to_string(),
            ping_csv.clone(),
            "-x".to_string(),
            "csv".to_string(),
            "-u".to_string(),
            tester_cfg.ping_test_url.clone(),
            "-d".to_string(),
            tester_cfg.max_delay_ms.to_string(),
            "--retries".to_string(),
            tester_cfg.retries.to_string(),
            "--timeout".to_string(),
            timeout_ms,
        ];
        if tester_cfg.xray_verbose_logs {
            args.push("-v".to_string());
        }

        if tester_cfg.core_type != "auto" && !tester_cfg.core_type.is_empty() {
            args.push("-z".to_string());
            args.push(tester_cfg.core_type.clone());
        }
        if tester_cfg.resolve_real_ip {
            args.push("-r".to_string());
        } else {
            args.push("--rip=false".to_string());
        }
        if tester_cfg.allow_insecure {
            args.push("--insecure".to_string());
        }

        append_extra_args(&mut args, &tester_cfg.extra_xray_args);

        log_worker(
            &tx,
            LogLevel::Info,
            format!("📍 Phase2/PING start -> {}", tester_cfg.ping_test_url),
        );

        if run_xray_knife(tester_cfg, &args, &ping_csv, &tx) {
            let _ = fs::copy(&ping_csv, format!("{}/ping_raw.csv", debug_dir));

            let mut all_ping_results = parse_csv_results(&ping_csv);
            all_ping_results.retain(|r| r.delay_ms.is_some());
            all_ping_results.sort_by_key(|r| r.delay_ms.unwrap_or(u128::MAX));

            ping_selected = all_ping_results;

            phase2.ping_passed_mixed = ping_selected
                .iter()
                .map(|r| rename_config(&r.link, tester_cfg, r, None))
                .collect();

            log_worker(
                &tx,
                LogLevel::Success,
                format!(
                    "✅ Phase2/PING done | passed={} | removed={} | elapsed={}ms",
                    phase2.ping_passed_mixed.len(),
                    total.saturating_sub(phase2.ping_passed_mixed.len()),
                    ping_started.elapsed().as_millis()
                ),
            );
        } else {
            log_worker(
                &tx,
                LogLevel::Error,
                "❌ Ping test failed to execute.".to_string(),
            );
        }
        let _ = fs::remove_file(&ping_csv);
    }

    if stop_flag.load(Ordering::SeqCst) {
        let _ = fs::remove_file(&input_path);
        log_worker(&tx, LogLevel::Warning, "🛑 Tester interrupted.".to_string());
        return phase2;
    }

    let mut speed_selected: Vec<TestResult> = Vec::new();
    let mut use_rank = false;

    if tester_cfg.speed_test_enabled {
        let speed_started = Instant::now();
        let speed_input = build_temp_path("speed_candidates.txt");
        let speed_csv = build_temp_path("speed_results.csv");

        let mut speed_targets: Vec<String> = Vec::new();

        if tester_cfg.speed_test_from_ping_passed_only && tester_cfg.ping_test_enabled {
            if ping_selected.is_empty() {
                log_worker(
                    &tx,
                    LogLevel::Warning,
                    "⚠️ Chain Mode is ON but Ping found 0 configs. Skipping Speed test."
                        .to_string(),
                );
            } else {
                speed_targets = ping_selected.iter().map(|r| r.link.clone()).collect();
            }
        } else {
            speed_targets = to_test.clone();
        }

        let top_n = tester_cfg
            .speed_test_top_count
            .max(1)
            .min(speed_targets.len());
        speed_targets.truncate(top_n);

        if !speed_targets.is_empty() {
            log_worker(
                &tx,
                LogLevel::Info,
                format!(
                    "📦 Phase2/SPEED targets={} | source={} | remaining_after_speed=depends_on_results",
                    speed_targets.len(),
                    if tester_cfg.speed_test_from_ping_passed_only && tester_cfg.ping_test_enabled { "ping-passed" } else { "all-phase1" }
                ),
            );

            if fs::write(&speed_input, speed_targets.join("\n")).is_err() {
                let _ = fs::remove_file(&input_path);
                log_worker(
                    &tx,
                    LogLevel::Error,
                    "❌ Failed to create speed candidates file.".to_string(),
                );
                return phase2;
            }

            let speed_url = if tester_cfg.speed_url_supports_bytes_query
                && tester_cfg.speed_test_amount_kb > 0
            {
                let bytes = tester_cfg.speed_test_amount_kb * 1024;
                if tester_cfg.speed_test_url.contains("{bytes}") {
                    tester_cfg
                        .speed_test_url
                        .replace("{bytes}", &bytes.to_string())
                } else {
                    let separator = if tester_cfg.speed_test_url.contains('?') {
                        "&"
                    } else {
                        "?"
                    };
                    format!(
                        "{}{}{}bytes={}",
                        tester_cfg.speed_test_url, separator, bytes, ""
                    )
                }
            } else {
                tester_cfg.speed_test_url.clone()
            };

            let mut args = vec![
                "http".to_string(),
                "-f".to_string(),
                speed_input.clone(),
                "-t".to_string(),
                tester_cfg.speed_test_batch_size.max(1).to_string(),
                "-o".to_string(),
                speed_csv.clone(),
                "-x".to_string(),
                "csv".to_string(),
                "-p".to_string(),
                "-u".to_string(),
                speed_url.clone(),
                "-a".to_string(),
                tester_cfg.speed_test_amount_kb.to_string(),
                "-d".to_string(),
                tester_cfg.max_delay_ms.to_string(),
                "--retries".to_string(),
                tester_cfg.retries.to_string(),
                "--timeout".to_string(),
                (tester_cfg.speed_test_timeout_secs.max(1) * 1000).to_string(),
            ];
            if tester_cfg.xray_verbose_logs {
                args.push("-v".to_string());
            }

            if tester_cfg.core_type != "auto" && !tester_cfg.core_type.is_empty() {
                args.push("-z".to_string());
                args.push(tester_cfg.core_type.clone());
            }
            if tester_cfg.resolve_real_ip {
                args.push("-r".to_string());
            } else {
                args.push("--rip=false".to_string());
            }
            if tester_cfg.allow_insecure {
                args.push("--insecure".to_string());
            }

            append_extra_args(&mut args, &tester_cfg.extra_xray_args);

            log_worker(
                &tx,
                LogLevel::Info,
                format!("🚀 Phase2/SPEED start -> {}", speed_url),
            );

            if run_xray_knife(tester_cfg, &args, &speed_csv, &tx) {
                let _ = fs::copy(&speed_csv, format!("{}/speed_raw.csv", debug_dir));

                let mut parsed_speed = parse_csv_results(&speed_csv);
                parsed_speed.retain(|item| item.download_kb.unwrap_or(0.0) > 0.0);
                parsed_speed.sort_by(|a, b| {
                    b.download_kb
                        .unwrap_or(0.0)
                        .partial_cmp(&a.download_kb.unwrap_or(0.0))
                        .unwrap_or(std::cmp::Ordering::Equal)
                });

                phase2.speed_passed_mixed = parsed_speed
                    .iter()
                    .enumerate()
                    .map(|(i, r)| rename_config(&r.link, tester_cfg, r, Some(i + 1)))
                    .collect();

                speed_selected = parsed_speed;
                use_rank = true;
            } else {
                log_worker(
                    &tx,
                    LogLevel::Warning,
                    "⚠️ Speed test failed to execute.".to_string(),
                );
            }

            log_worker(
                &tx,
                LogLevel::Success,
                format!(
                    "✅ Phase2/SPEED done | passed={} | removed={} | elapsed={}ms",
                    speed_selected.len(),
                    speed_targets.len().saturating_sub(speed_selected.len()),
                    speed_started.elapsed().as_millis()
                ),
            );

            let _ = fs::remove_file(&speed_input);
            let _ = fs::remove_file(&speed_csv);
        }
    }

    let _ = fs::remove_file(&input_path);

    for (proto, links) in configs_map.iter_mut() {
        if !NON_MIXED_PROTOCOLS.contains(&proto.as_str()) {
            links.clear();
        }
    }

    let mut final_output_map: HashMap<String, String> = HashMap::new();

    if tester_cfg.ping_test_enabled {
        for r in &ping_selected {
            final_output_map.insert(r.link.clone(), rename_config(&r.link, tester_cfg, r, None));
        }
    }

    if tester_cfg.speed_test_enabled {
        if tester_cfg.speed_test_from_ping_passed_only {
            final_output_map.clear();
        }
        for (i, r) in speed_selected.iter().enumerate() {
            let rank = if use_rank { Some(i + 1) } else { None };
            final_output_map.insert(r.link.clone(), rename_config(&r.link, tester_cfg, r, rank));
        }
    }

    let mut passed_count = 0usize;
    for (orig_link, renamed_link) in final_output_map {
        if let Some(proto) = proto_by_link.get(&orig_link) {
            configs_map
                .entry(proto.clone())
                .or_default()
                .insert(renamed_link);
            passed_count += 1;
        }
    }

    log_worker(
        &tx,
        LogLevel::Success,
        format!(
            "🏁 PHASE 2 COMPLETE | final_passed_unique={}/{}",
            passed_count, total
        ),
    );

    phase2
}
