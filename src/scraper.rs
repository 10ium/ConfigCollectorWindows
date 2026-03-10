use crate::config::{AppConfig, ChannelMemory, ProtocolRule, ProxyType, SentHistory};
use crate::storage::{write_files_standard, write_files_standard_append};
use anyhow::Result;
use chrono::{DateTime, Duration as ChronoDuration, Utc};
use regex::Regex;
use reqwest::blocking::ClientBuilder;
use std::collections::{BTreeMap, BTreeSet};
use std::path::Path;
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::mpsc::Sender;
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

#[derive(Clone, Debug, PartialEq)]
pub enum LogLevel { Debug, Info, Success, Warning, Error }

#[derive(Clone, Debug)]
pub enum AppEvent {
    Log(LogLevel, String),
    Stats { total: usize, by_protocol: BTreeMap<String, usize> },
    WorkerStopped,
}

pub fn log_worker(tx: &Sender<AppEvent>, level: LogLevel, text: String) {
    let _ = tx.send(AppEvent::Log(level, text));
}

pub fn build_client(config: &AppConfig) -> Result<reqwest::blocking::Client> {
    let mut b = ClientBuilder::new()
        .timeout(Duration::from_secs(config.timeout_secs))
        .user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36")
        .danger_accept_invalid_certs(config.ignore_ssl_errors);

    match config.proxy_type {
        ProxyType::None => { b = b.no_proxy(); }
        ProxyType::System => {}
        ProxyType::Http | ProxyType::Socks5 => {
            let scheme = if config.proxy_type == ProxyType::Socks5 && config.remote_dns { "socks5h" } 
                         else if config.proxy_type == ProxyType::Socks5 { "socks5" } 
                         else { "http" };
            let host = if config.proxy_host.trim().is_empty() { "127.0.0.1" } else { config.proxy_host.trim() };
            b = b.proxy(reqwest::Proxy::all(&format!("{}://{}:{}", scheme, host, config.proxy_port))?);
        }
    }
    b.build().map_err(|e| anyhow::anyhow!("Failed to build client: {}", e))
}

pub fn parse_channels(raw: &str) -> Vec<String> {
    raw.lines()
        .map(str::trim)
        .filter(|l| !l.is_empty() && !l.starts_with('#'))
        .filter_map(|line| {
            if let Some(rest) = line.strip_prefix('@') { return Some(rest.to_string()); }
            if line.contains("t.me/") { return line.split("t.me/").nth(1).map(|x| x.split('?').next().unwrap_or_default().trim_matches('/').to_string()); }
            Some(line.to_string())
        })
        .filter(|s| !s.is_empty())
        .collect()
}

pub fn apply_protocol_limits(store: &mut BTreeMap<String, BTreeSet<String>>, rules: &BTreeMap<String, ProtocolRule>) {
    for (proto, links) in store.iter_mut() {
        if let Some(rule) = rules.get(proto) {
            if rule.max_count > 0 && links.len() > rule.max_count {
                *links = links.iter().take(rule.max_count).cloned().collect();
            }
        }
    }
}

pub fn run_worker(
    config: AppConfig,
    channels_raw: String,
    stop: Arc<AtomicBool>,
    tx: Sender<AppEvent>,
) -> Result<()> {
    let channels = parse_channels(&channels_raw);
    let total_channels_count = channels.len();
    
    let regex_pattern = r"(?i)(vmess|vless|trojan|ss|ssr|tuic|hysteria|hysteria2|hy2|juicity|snell|anytls|ssh|wireguard|wg|warp|socks|socks4|socks5|tg|dns|nm-dns|nm-vless|slipnet-enc|slipnet|slipstream|dnstt)://[a-zA-Z0-9\-\._~:/\?#\[\]@!\$&'\(\)\*\+,%;=]+";
    let regex = Regex::new(regex_pattern).unwrap();
    let date_regex = Regex::new(r#"<time datetime="([^"]+)""#).unwrap();
    let post_id_regex = Regex::new(r#"data-post="[^/]+/(\d+)""#).unwrap();

    let mut history = SentHistory::load();
    let threshold_date = Utc::now() - ChronoDuration::days(config.lookback_days.max(0));
    
    let mut channel_memory = ChannelMemory::load();

    log_worker(&tx, LogLevel::Info, format!("🚀 Crawler Started | {} Channels | Threads: {}", total_channels_count, config.concurrent_channels));

    loop {
        if stop.load(Ordering::SeqCst) { break; }
        
        history.prune(config.lookback_days);
        let client = build_client(&config)?;
        
        let queue = Arc::new(Mutex::new(channels.clone()));
        let global_gathered: Arc<Mutex<BTreeMap<String, BTreeSet<String>>>> = Arc::new(Mutex::new(BTreeMap::new()));
        let total_run_configs = Arc::new(Mutex::new(0usize));
        let completed_count = Arc::new(AtomicUsize::new(0));
        let new_memory = Arc::new(Mutex::new(channel_memory.clone()));
        
        let mut handles = vec![];
        let threads_count = config.concurrent_channels.max(1).min(total_channels_count.max(1));

        for _ in 0..threads_count {
            let q = queue.clone();
            let client_c = client.clone();
            let config_c = config.clone();
            let stop_c = stop.clone();
            let tx_c = tx.clone();
            let gathered_c = global_gathered.clone();
            let total_c = total_run_configs.clone();
            let memory_c = new_memory.clone();
            let comp_count_c = completed_count.clone();
            
            let reg_c = regex.clone();
            let date_reg_c = date_regex.clone();
            let post_id_reg_c = post_id_regex.clone();

            handles.push(thread::spawn(move || {
                loop {
                    if stop_c.load(Ordering::SeqCst) { break; }
                    
                    let channel = {
                        let mut lock = q.lock().unwrap();
                        match lock.pop() { Some(c) => c, None => break, }
                    };

                    let clean_channel_name = channel.trim_start_matches('@').to_lowercase();
                    let stored_max_id = memory_c.lock().unwrap().last_seen_ids.get(&clean_channel_name).copied();
                    let mut highest_id_seen_now = 0;

                    let mut before: Option<String> = None;
                    let mut channel_configs = 0;
                    let mut local_gathered: BTreeMap<String, BTreeSet<String>> = BTreeMap::new();
                    let mut hit_known_post = false;

                    for page in 1..=config_c.max_pages_per_channel {
                        if stop_c.load(Ordering::SeqCst) || hit_known_post { break; }
                        
                        let mut url = format!("https://t.me/s/{}", channel);
                        if let Some(ref id) = before { url.push_str(&format!("?before={}", id)); }

                        match client_c.get(&url).send() {
                            Ok(resp) if resp.status().is_success() => {
                                if let Ok(raw_html) = resp.text() {
                                    let mut found_in_page = 0;
                                    let mut next_before = None;

                                    let decoded_html = raw_html.replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"");

                                    let next_regex = Regex::new(r#"data-post="[^/]+/(\d+)""#).unwrap();
                                    for cap in next_regex.captures_iter(&decoded_html) {
                                        next_before = Some(cap[1].to_string());
                                    }

                                    let blocks: Vec<&str> = decoded_html.split("tgme_widget_message ").collect();
                                    for block in blocks {
                                        let mut block_id = 0;
                                        if let Some(caps) = post_id_reg_c.captures(block) {
                                            if let Ok(id) = caps[1].parse::<u64>() {
                                                block_id = id;
                                                if id > highest_id_seen_now { highest_id_seen_now = id; }
                                            }
                                        }

                                        if let Some(known_id) = stored_max_id {
                                            if block_id > 0 && block_id <= known_id {
                                                hit_known_post = true;
                                                continue; 
                                            }
                                        }

                                        let mut is_valid_date = true;
                                        if let Some(caps) = date_reg_c.captures(block) {
                                            if let Ok(parsed_date) = DateTime::parse_from_rfc3339(&caps[1]) {
                                                if parsed_date.with_timezone(&Utc) < threshold_date {
                                                    is_valid_date = false;
                                                }
                                            }
                                        }

                                        if is_valid_date {
                                            for m in reg_c.find_iter(block) {
                                                let clean_link = m.as_str().trim_end_matches(&['(', ')', '[', ']', ' ', '!', '.', ',', ';', '\'', '"', '<', '>'][..]).to_string();
                                                if let Some(proto) = clean_link.split("://").next() {
                                                    found_in_page += 1;
                                                    local_gathered.entry(proto.to_lowercase()).or_default().insert(clean_link);
                                                }
                                            }
                                        }
                                    }

                                    channel_configs += found_in_page;
                                    let has_next = next_before.is_some();
                                    before = next_before;

                                    if hit_known_post {
                                        log_worker(&tx_c, LogLevel::Debug, format!("⏭️ @{} -> Reached previously scanned posts.", channel));
                                        break;
                                    }

                                    if !has_next || found_in_page == 0 { break; }
                                }
                            }
                            Err(_) => {
                                log_worker(&tx_c, LogLevel::Warning, format!("⚠️ Failed page {} of @{}", page, channel));
                                break;
                            }
                            _ => break,
                        }
                        thread::sleep(Duration::from_millis(config_c.delay_ms));
                    }

                    if highest_id_seen_now > 0 {
                        memory_c.lock().unwrap().last_seen_ids.insert(clean_channel_name, highest_id_seen_now);
                    }

                    let mut breakdown = Vec::new();
                    let mut g = gathered_c.lock().unwrap();
                    for (k, v) in local_gathered {
                        breakdown.push(format!("{}: {}", k, v.len()));
                        g.entry(k).or_default().extend(v);
                    }
                    *total_c.lock().unwrap() += channel_configs;
                    
                    let current_done = comp_count_c.fetch_add(1, Ordering::SeqCst) + 1;
                    let breakdown_str = if breakdown.is_empty() { "None".to_string() } else { breakdown.join(", ") };
                    log_worker(&tx_c, LogLevel::Success, format!("[{}/{}] ✔️ @{} -> Extracted: {} ({})", current_done, total_channels_count, channel, channel_configs, breakdown_str));
                }
            }));
        }

        for h in handles { let _ = h.join(); }
        if stop.load(Ordering::SeqCst) { break; }

        let mut final_gathered = Arc::try_unwrap(global_gathered).unwrap().into_inner().unwrap();
        let total_run = Arc::try_unwrap(total_run_configs).unwrap().into_inner().unwrap();
        channel_memory = Arc::try_unwrap(new_memory).unwrap().into_inner().unwrap();

        let _ = channel_memory.save();

        if let Some(hy2_links) = final_gathered.remove("hy2") {
            final_gathered.entry("hysteria2".to_string()).or_default().extend(hy2_links);
        }

        apply_protocol_limits(&mut final_gathered, &config.protocol_rules);

        let mut new_only: BTreeMap<String, BTreeSet<String>> = BTreeMap::new();
        let mut total_new = 0;

        for (proto, links) in &final_gathered {
            for link in links {
                if !history.sent_at.contains_key(link) {
                    history.sent_at.insert(link.clone(), Utc::now());
                    new_only.entry(proto.clone()).or_default().insert(link.clone());
                    total_new += 1;
                }
            }
        }

        let mut by_protocol = BTreeMap::new();
        for (k, v) in &new_only { by_protocol.insert(k.clone(), v.len()); }

        let out_new = Path::new(&config.output_directory).join("new_only");
        let out_append = Path::new(&config.output_directory).join("append_unique");

        if config.output_new_only_enabled && !new_only.is_empty() {
            if let Err(e) = write_files_standard(&out_new, &new_only) {
                log_worker(&tx, LogLevel::Error, format!("Write New Error: {}", e));
            }
        }
        if config.output_append_unique_enabled && !final_gathered.is_empty() {
            if let Err(e) = write_files_standard_append(&out_append, &final_gathered) {
                log_worker(&tx, LogLevel::Error, format!("Write Append Error: {}", e));
            }
        }

        let _ = history.save();
        let _ = tx.send(AppEvent::Stats { total: total_new, by_protocol });

        log_worker(&tx, LogLevel::Success, format!("====================================="));
        log_worker(&tx, LogLevel::Success, format!("🎉 CYCLE COMPLETE! Total: {} | NEW: {}", total_run, total_new));
        log_worker(&tx, LogLevel::Success, format!("====================================="));
        log_worker(&tx, LogLevel::Info, format!("💤 Sleeping for {} minutes...", config.interval_minutes));

        for _ in 0..(config.interval_minutes * 60) {
            if stop.load(Ordering::SeqCst) { break; }
            thread::sleep(Duration::from_secs(1));
        }
    }
    Ok(())
}
