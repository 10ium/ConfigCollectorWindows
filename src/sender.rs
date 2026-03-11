use crate::config::Phase5TelegramConfig;
use crate::scraper::{build_client, log_worker, AppEvent, LogLevel};
use anyhow::{anyhow, Result};
use reqwest::blocking::Client;
use std::fs;
use std::path::Path;
use std::sync::mpsc::Sender;

fn escape_html(text: &str) -> String {
    text.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
}

fn chunk_lines(lines: &[String], chunk_size: usize) -> Vec<Vec<String>> {
    let size = chunk_size.max(1);
    lines
        .chunks(size)
        .map(|c| c.to_vec())
        .collect::<Vec<Vec<String>>>()
}

fn post_message(client: &Client, cfg: &Phase5TelegramConfig, text: &str) -> Result<()> {
    let api_url = format!(
        "https://api.telegram.org/bot{}/sendMessage",
        cfg.bot_token.trim()
    );
    let params = [
        ("chat_id", cfg.chat_id.trim().to_string()),
        ("text", text.to_string()),
        ("parse_mode", "HTML".to_string()),
        ("disable_web_page_preview", "true".to_string()),
    ];

    let resp = client.post(&api_url).form(&params).send()?;
    if !resp.status().is_success() {
        let status = resp.status();
        let body = resp.text().unwrap_or_default();
        return Err(anyhow!("telegram sendMessage failed: {} {}", status, body));
    }
    Ok(())
}

pub fn send_tested_new_only_to_telegram(
    output_dir: &str,
    cfg: &Phase5TelegramConfig,
    app_cfg: &crate::config::AppConfig,
    tx: &Sender<AppEvent>,
) -> Result<usize> {
    if !cfg.enabled {
        return Ok(0);
    }

    if cfg.bot_token.trim().is_empty() || cfg.chat_id.trim().is_empty() {
        return Err(anyhow!("Phase 5 enabled but bot token / chat id is empty"));
    }

    let mixed_path = Path::new(output_dir)
        .join("tested")
        .join("new_only")
        .join("mixed.txt");

    if !mixed_path.exists() {
        log_worker(
            tx,
            LogLevel::Warning,
            format!(
                "⚠️ PHASE 5 skipped: {} not found.",
                mixed_path.to_string_lossy()
            ),
        );
        return Ok(0);
    }

    let raw = fs::read_to_string(&mixed_path)?;
    let configs: Vec<String> = raw
        .lines()
        .map(str::trim)
        .filter(|l| !l.is_empty())
        .map(ToOwned::to_owned)
        .collect();

    if configs.is_empty() {
        log_worker(
            tx,
            LogLevel::Info,
            "ℹ️ PHASE 5: no new tested configs to send.".to_string(),
        );
        return Ok(0);
    }

    let client = build_client(app_cfg)?;
    let chunks = chunk_lines(&configs, cfg.post_config_count.max(1));

    log_worker(
        tx,
        LogLevel::Info,
        format!(
            "📤 PHASE 5 START | source=tested/new_only/mixed.txt | configs={} | posts={} | per_post={}",
            configs.len(),
            chunks.len(),
            cfg.post_config_count.max(1)
        ),
    );

    for (idx, group) in chunks.iter().enumerate() {
        let mut message_lines = Vec::new();
        if cfg.header_enabled && !cfg.header_text.trim().is_empty() {
            message_lines.push(escape_html(cfg.header_text.trim()));
        }

        message_lines.push("<pre>".to_string());
        for line in group {
            message_lines.push(escape_html(line));
        }
        message_lines.push("</pre>".to_string());

        if cfg.footer_enabled && !cfg.footer_text.trim().is_empty() {
            message_lines.push(escape_html(cfg.footer_text.trim()));
        }

        let body = message_lines.join("\n");
        post_message(&client, cfg, &body)?;

        log_worker(
            tx,
            LogLevel::Success,
            format!(
                "✅ PHASE 5 POST {}/{} sent | configs_in_post={} | remaining_posts={}",
                idx + 1,
                chunks.len(),
                group.len(),
                chunks.len().saturating_sub(idx + 1)
            ),
        );
    }

    log_worker(
        tx,
        LogLevel::Success,
        format!("🏁 PHASE 5 COMPLETE | sent_configs={}", configs.len()),
    );

    Ok(configs.len())
}
