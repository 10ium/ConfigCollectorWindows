use std::collections::{BTreeMap, BTreeSet, HashMap};
use std::fs;
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::Sender;
use std::sync::Arc;
use std::time::{Instant, SystemTime, UNIX_EPOCH};

use crate::config::TesterConfig;
use crate::scraper::{log_worker, AppEvent, LogLevel};
use crate::storage::NON_MIXED_PROTOCOLS;

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

fn country_to_flag(code: &str) -> &'static str {
    match code.to_ascii_uppercase().as_str() {
        "IR" => "🇮🇷",
        "US" => "🇺🇸",
        "DE" => "🇩🇪",
        "NL" => "🇳🇱",
        "FR" => "🇫🇷",
        "GB" => "🇬🇧",
        "TR" => "🇹🇷",
        "AE" => "🇦🇪",
        _ => "🌐",
    }
}

fn format_speed(download_kb: f64) -> String {
    if download_kb >= 1024.0 {
        format!("{:.1}MB", download_kb / 1024.0)
    } else {
        format!("{:.1}KB", download_kb.max(0.1))
    }
}

fn append_labels_to_config(
    config_str: &str,
    tester_cfg: &TesterConfig,
    result: &TestResult,
) -> String {
    let mut labels = Vec::new();

    if tester_cfg.append_country_flag {
        let cc = result.country.as_deref().unwrap_or("UN");
        labels.push(country_to_flag(cc).to_string());
    }

    if tester_cfg.append_ping_flag {
        if let Some(ping) = result.delay_ms {
            labels.push(format!("Ping:{}ms", ping));
        }
    }

    if tester_cfg.append_speed_flag {
        if let Some(download) = result.download_kb {
            if download > 0.0 {
                labels.push(format!("Speed:{}", format_speed(download)));
            }
        }
    }

    if labels.is_empty() {
        return config_str.to_string();
    }

    let suffix = format!("[{}]", labels.join(" | "));
    if config_str.rfind('#').is_some() {
        format!("{}-{}", config_str, suffix)
    } else {
        format!("{}#{}", config_str, suffix)
    }
}

fn run_xray_knife(tester_cfg: &TesterConfig, args: &[String]) -> bool {
    let mut command = Command::new(&tester_cfg.xray_knife_path);
    command
        .args(args)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .stdin(Stdio::null())
        .env_remove("HTTP_PROXY")
        .env_remove("HTTPS_PROXY")
        .env_remove("ALL_PROXY")
        .env("NO_PROXY", "*");

    #[cfg(windows)]
    {
        use std::os::windows::process::CommandExt;
        command.creation_flags(CREATE_NO_WINDOW);
    }

    command.status().map(|s| s.success()).unwrap_or(false)
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

fn parse_csv_results(path: &str) -> Vec<TestResult> {
    let Ok(raw) = fs::read_to_string(path) else {
        return Vec::new();
    };

    let mut lines = raw.lines();
    let Some(header_line) = lines.next() else {
        return Vec::new();
    };

    let headers: Vec<String> = split_csv_line(header_line)
        .into_iter()
        .map(|h| h.trim().trim_matches('"').to_lowercase())
        .collect();

    let link_idx = headers
        .iter()
        .position(|h| h == "link" || h == "config")
        .unwrap_or(0);
    let delay_idx = headers
        .iter()
        .position(|h| h == "delay")
        .unwrap_or(usize::MAX);
    let download_idx = headers
        .iter()
        .position(|h| {
            h == "download"
                || h == "speed"
                || h == "dl"
                || h.contains("download")
                || h.contains("speed")
        })
        .unwrap_or(usize::MAX);
    let location_idx = headers
        .iter()
        .position(|h| h == "location" || h == "cc")
        .unwrap_or(usize::MAX);

    let mut out = Vec::new();
    for line in lines {
        let cols = split_csv_line(line);
        if link_idx >= cols.len() {
            continue;
        }

        let link = cols[link_idx].trim().trim_matches('"').to_string();
        if link.is_empty() {
            continue;
        }

        let delay_ms = if delay_idx < cols.len() {
            parse_numeric_to_kb(cols[delay_idx].trim().trim_matches('"'), false)
                .map(|v| v as u128)
                .filter(|v| *v > 0)
        } else {
            None
        };

        let download_kb = if download_idx < cols.len() {
            parse_numeric_to_kb(cols[download_idx].trim().trim_matches('"'), true)
                .filter(|v| *v > 0.0)
        } else {
            None
        };

        let country = if location_idx < cols.len() {
            let value = cols[location_idx].trim().trim_matches('"');
            if value.is_empty() {
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

fn split_csv_line(line: &str) -> Vec<String> {
    let mut cols = Vec::new();
    let mut current = String::new();
    let mut in_quotes = false;

    for ch in line.chars() {
        match ch {
            '"' => in_quotes = !in_quotes,
            ',' if !in_quotes => {
                cols.push(current.clone());
                current.clear();
            }
            _ => current.push(ch),
        }
    }
    cols.push(current);
    cols
}

fn parse_numeric_to_kb(raw: &str, is_speed: bool) -> Option<f64> {
    let lower = raw.trim().to_ascii_lowercase();
    if lower.is_empty() {
        return None;
    }

    let cleaned = lower.replace(',', "");
    let numeric: String = cleaned
        .chars()
        .filter(|c| c.is_ascii_digit() || *c == '.')
        .collect();
    let mut value = numeric.parse::<f64>().ok()?;

    if !is_speed {
        return Some(value);
    }

    if cleaned.contains("mb/s") || cleaned.ends_with("mb") {
        value *= 1024.0;
    } else if cleaned.contains("kb/s") || cleaned.ends_with("kb") {
    } else if cleaned.contains("gb/s") || cleaned.ends_with("gb") {
        value *= 1024.0 * 1024.0;
    } else if cleaned.contains("mbps") {
        value *= 125.0;
    } else if cleaned.contains("kbps") {
        value /= 8.0;
    } else if cleaned.contains("b/s") || cleaned.ends_with('b') || value > 5000.0 {
        value /= 1024.0;
    }

    Some(value)
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
            "-a".to_string(),
            timeout_ms,
        ];
        append_extra_args(&mut args, &tester_cfg.extra_xray_args);

        log_worker(
            &tx,
            LogLevel::Info,
            format!(
                "📍 Phase2/PING start -> {} | candidates={} | timeout={}s",
                tester_cfg.ping_test_url, total, tester_cfg.timeout_secs
            ),
        );
        if !run_xray_knife(tester_cfg, &args) {
            log_worker(
                &tx,
                LogLevel::Error,
                "❌ Ping test failed to execute.".to_string(),
            );
            let _ = fs::remove_file(&input_path);
            let _ = fs::remove_file(&ping_csv);
            return phase2;
        }

        ping_selected = parse_csv_results(&ping_csv);
        ping_selected.retain(|r| r.delay_ms.is_some());
        ping_selected.sort_by_key(|r| r.delay_ms.unwrap_or(u128::MAX));
        phase2.ping_passed_mixed = ping_selected.iter().map(|r| r.link.clone()).collect();
        let _ = fs::remove_file(&ping_csv);

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
    }

    let mut final_selected: Vec<TestResult> = if tester_cfg.ping_test_enabled {
        ping_selected
    } else {
        to_test
            .iter()
            .map(|link| TestResult {
                link: link.clone(),
                delay_ms: None,
                download_kb: None,
                country: None,
            })
            .collect()
    };

    if stop_flag.load(Ordering::SeqCst) {
        let _ = fs::remove_file(&input_path);
        log_worker(&tx, LogLevel::Warning, "🛑 Tester interrupted.".to_string());
        return phase2;
    }

    if final_selected.is_empty() {
        let _ = fs::remove_file(&input_path);
        log_worker(
            &tx,
            LogLevel::Warning,
            "⚠️ No configs left after ping phase.".to_string(),
        );
        for (proto, links) in configs_map.iter_mut() {
            if !NON_MIXED_PROTOCOLS.contains(&proto.as_str()) {
                links.clear();
            }
        }
        return phase2;
    }

    if tester_cfg.speed_test_enabled {
        let speed_started = Instant::now();
        let speed_input = build_temp_path("speed_candidates.txt");
        let speed_csv = build_temp_path("speed_results.csv");

        let mut speed_targets: Vec<String> =
            if tester_cfg.speed_test_from_ping_passed_only && tester_cfg.ping_test_enabled {
                final_selected.iter().map(|r| r.link.clone()).collect()
            } else {
                to_test.clone()
            };

        let top_n = tester_cfg
            .speed_test_top_count
            .max(1)
            .min(speed_targets.len());
        speed_targets.truncate(top_n);

        log_worker(
            &tx,
            LogLevel::Info,
            format!(
                "📦 Phase2/SPEED targets={} | source={} | remaining_after_speed=depends_on_results",
                speed_targets.len(),
                if tester_cfg.speed_test_from_ping_passed_only && tester_cfg.ping_test_enabled {
                    "ping-passed"
                } else {
                    "all-phase1"
                }
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
            && tester_cfg.speed_test_download_bytes > 0
        {
            if tester_cfg.speed_test_url.contains("{bytes}") {
                tester_cfg
                    .speed_test_url
                    .replace("{bytes}", &tester_cfg.speed_test_download_bytes.to_string())
            } else {
                let separator = if tester_cfg.speed_test_url.contains('?') {
                    "&"
                } else {
                    "?"
                };
                format!(
                    "{}{}bytes={}",
                    tester_cfg.speed_test_url, separator, tester_cfg.speed_test_download_bytes
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
            (tester_cfg.speed_test_timeout_secs.max(1) * 1000).to_string(),
        ];
        append_extra_args(&mut args, &tester_cfg.extra_xray_args);

        log_worker(
            &tx,
            LogLevel::Info,
            format!("🚀 Phase2/SPEED start -> {}", speed_url),
        );
        if run_xray_knife(tester_cfg, &args) {
            let mut speed_results = parse_csv_results(&speed_csv);
            speed_results.retain(|item| item.download_kb.unwrap_or(0.0) > 0.0);
            phase2.speed_passed_mixed = speed_results.iter().map(|r| r.link.clone()).collect();
            if speed_results.is_empty() {
                log_worker(
                    &tx,
                    LogLevel::Warning,
                    "⚠️ Speed test returned 0 healthy configs. No config will pass speed stage in this cycle.".to_string(),
                );
                final_selected.clear();
            } else {
                final_selected = speed_results;
            }
        } else {
            log_worker(
                &tx,
                LogLevel::Warning,
                "⚠️ Speed test failed to execute. Speed stage marked as failed; no config will pass this stage.".to_string(),
            );
            final_selected.clear();
            phase2.speed_passed_mixed.clear();
        }

        log_worker(
            &tx,
            LogLevel::Success,
            format!(
                "✅ Phase2/SPEED done | passed={} | removed={} | elapsed={}ms",
                phase2.speed_passed_mixed.len(),
                speed_targets
                    .len()
                    .saturating_sub(phase2.speed_passed_mixed.len()),
                speed_started.elapsed().as_millis()
            ),
        );

        let _ = fs::remove_file(&speed_input);
        let _ = fs::remove_file(&speed_csv);
    } else {
        phase2.speed_passed_mixed = final_selected.iter().map(|r| r.link.clone()).collect();
    }

    let _ = fs::remove_file(&input_path);

    if final_selected.is_empty() {
        log_worker(
            &tx,
            LogLevel::Warning,
            "⚠️ PHASE 2 produced 0 final configs after active tests.".to_string(),
        );
    }

    for (proto, links) in configs_map.iter_mut() {
        if !NON_MIXED_PROTOCOLS.contains(&proto.as_str()) {
            links.clear();
        }
    }

    let mut passed_count = 0usize;
    for item in final_selected {
        let Some(proto) = proto_by_link.get(&item.link) else {
            continue;
        };

        let final_config = append_labels_to_config(&item.link, tester_cfg, &item);
        configs_map
            .entry(proto.clone())
            .or_default()
            .insert(final_config);
        passed_count += 1;
    }

    log_worker(
        &tx,
        LogLevel::Success,
        format!(
            "🏁 PHASE 2 COMPLETE | final_passed={}/{}",
            passed_count, total
        ),
    );
    phase2
}
