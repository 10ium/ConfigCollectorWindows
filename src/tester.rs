use std::collections::{BTreeMap, BTreeSet, HashMap};
use std::fs;
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::Sender;
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

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
        format!("{}KB", download_kb.max(0.0).round() as u64)
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
        .stdin(Stdio::null());

    #[cfg(windows)]
    {
        use std::os::windows::process::CommandExt;
        command.creation_flags(CREATE_NO_WINDOW);
    }

    command.status().map(|s| s.success()).unwrap_or(false)
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

    let headers: Vec<String> = header_line
        .split(',')
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
        .position(|h| h == "download")
        .unwrap_or(usize::MAX);
    let location_idx = headers
        .iter()
        .position(|h| h == "location" || h == "cc")
        .unwrap_or(usize::MAX);

    let mut out = Vec::new();
    for line in lines {
        let cols: Vec<&str> = line.split(',').collect();
        if link_idx >= cols.len() {
            continue;
        }

        let link = cols[link_idx].trim().trim_matches('"').to_string();
        if link.is_empty() {
            continue;
        }

        let delay_ms = if delay_idx < cols.len() {
            cols[delay_idx]
                .trim()
                .trim_matches('"')
                .parse::<u128>()
                .ok()
                .filter(|v| *v > 0)
        } else {
            None
        };

        let download_kb = if download_idx < cols.len() {
            cols[download_idx]
                .trim()
                .trim_matches('"')
                .parse::<f64>()
                .ok()
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

pub fn filter_working_configs(
    configs_map: &mut BTreeMap<String, BTreeSet<String>>,
    tester_cfg: &TesterConfig,
    stop_flag: Arc<AtomicBool>,
    tx: Sender<AppEvent>,
) {
    if !tester_cfg.enabled {
        return;
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
        return;
    }

    if !tester_cfg.ping_test_enabled && !tester_cfg.speed_test_enabled {
        log_worker(
            &tx,
            LogLevel::Warning,
            "⚠️ Tester is enabled but both Ping and Speed tests are disabled. Keeping original configs."
                .to_string(),
        );
        return;
    }

    log_worker(
        &tx,
        LogLevel::Warning,
        format!(
            "🔬 PHASE 2: Batch testing {} configs with xray-knife (Ping: {}, Speed: {}).",
            total, tester_cfg.ping_test_enabled, tester_cfg.speed_test_enabled
        ),
    );

    let input_path = build_temp_path("configs_for_test.txt");
    if fs::write(&input_path, to_test.join("\n")).is_err() {
        log_worker(
            &tx,
            LogLevel::Error,
            "❌ Failed to create temporary input file for tester.".to_string(),
        );
        return;
    }

    if stop_flag.load(Ordering::SeqCst) {
        let _ = fs::remove_file(&input_path);
        return;
    }

    let mut selected = if tester_cfg.ping_test_enabled {
        let ping_csv = build_temp_path("ping_test_results.csv");
        let timeout_ms = (tester_cfg.timeout_secs.max(1) * 1000).to_string();
        let ping_url = if tester_cfg.ping_test_url.trim().is_empty() {
            tester_cfg.test_url.clone()
        } else {
            tester_cfg.ping_test_url.clone()
        };

        let args = vec![
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
            ping_url,
            "-a".to_string(),
            timeout_ms,
        ];

        if !run_xray_knife(tester_cfg, &args) {
            log_worker(
                &tx,
                LogLevel::Error,
                "❌ Ping test failed to execute via xray-knife.".to_string(),
            );
            let _ = fs::remove_file(&input_path);
            let _ = fs::remove_file(&ping_csv);
            return;
        }

        let mut ping_selected = parse_csv_results(&ping_csv);
        ping_selected.retain(|r| r.delay_ms.is_some());
        ping_selected.sort_by_key(|r| r.delay_ms.unwrap_or(u128::MAX));

        let _ = fs::remove_file(&ping_csv);
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
        return;
    }

    if selected.is_empty() {
        let _ = fs::remove_file(&input_path);
        log_worker(
            &tx,
            LogLevel::Warning,
            "⚠️ No config passed ping phase.".to_string(),
        );
        for (proto, links) in configs_map.iter_mut() {
            if !NON_MIXED_PROTOCOLS.contains(&proto.as_str()) {
                links.clear();
            }
        }
        return;
    }

    if tester_cfg.speed_test_enabled {
        let speed_input = build_temp_path("speed_candidates.txt");
        let speed_csv = build_temp_path("speed_results.csv");
        let top_n = tester_cfg.speed_test_top_count.max(1).min(selected.len());
        let speed_targets: Vec<String> = selected
            .iter()
            .take(top_n)
            .map(|r| r.link.clone())
            .collect();

        if fs::write(&speed_input, speed_targets.join("\n")).is_err() {
            let _ = fs::remove_file(&input_path);
            log_worker(
                &tx,
                LogLevel::Error,
                "❌ Failed to create speed candidates file.".to_string(),
            );
            return;
        }

        let speed_url = if tester_cfg.speed_test_download_bytes > 0 {
            let separator = if tester_cfg.speed_test_url.contains('?') {
                "&"
            } else {
                "?"
            };
            format!(
                "{}{}bytes={}",
                tester_cfg.speed_test_url, separator, tester_cfg.speed_test_download_bytes
            )
        } else {
            tester_cfg.speed_test_url.clone()
        };

        let args = vec![
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
            speed_url,
            "-a".to_string(),
            (tester_cfg.speed_test_timeout_secs.max(1) * 1000).to_string(),
        ];

        if run_xray_knife(tester_cfg, &args) {
            let mut speed_results = parse_csv_results(&speed_csv);
            speed_results.retain(|item| item.download_kb.unwrap_or(0.0) > 0.0);
            if !speed_results.is_empty() {
                selected = speed_results;
            } else {
                selected.clear();
            }
        } else {
            log_worker(
                &tx,
                LogLevel::Warning,
                "⚠️ Speed test failed to execute. Keeping ping-only results.".to_string(),
            );
        }

        let _ = fs::remove_file(&speed_input);
        let _ = fs::remove_file(&speed_csv);
    }

    let _ = fs::remove_file(&input_path);

    for (proto, links) in configs_map.iter_mut() {
        if !NON_MIXED_PROTOCOLS.contains(&proto.as_str()) {
            links.clear();
        }
    }

    let mut passed_count = 0usize;
    for item in selected {
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
            "🏁 Testing Complete: {}/{} passed Phase 2.",
            passed_count, total
        ),
    );
}
