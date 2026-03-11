use crate::config::{ClashConverterConfig, ClashProtocolRule};
use crate::scraper::{log_worker, AppEvent, LogLevel};
use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::Path;
use std::sync::mpsc::Sender;

#[derive(Clone, Debug)]
struct ClashNode {
    proto: String,
    name: String,
    server: String,
    port: u16,
    original: String,
}

fn parse_node(link: &str, idx: usize) -> Option<ClashNode> {
    let (proto, rest) = link.split_once("://")?;
    let proto = proto.to_lowercase();

    let host_port = if proto == "vmess" {
        "vmess.invalid:443".to_string()
    } else {
        let core = rest.split('#').next().unwrap_or(rest);
        let after_at = core.rsplit('@').next().unwrap_or(core);
        after_at
            .split('/')
            .next()
            .unwrap_or(after_at)
            .split('?')
            .next()
            .unwrap_or(after_at)
            .to_string()
    };

    let (server, port) = if let Some((h, p)) = host_port.rsplit_once(':') {
        (h.to_string(), p.parse::<u16>().unwrap_or(443))
    } else {
        (host_port, 443)
    };

    Some(ClashNode {
        name: format!("{} {}", proto, idx),
        proto,
        server,
        port,
        original: link.to_string(),
    })
}

fn protocol_key(proto: &str) -> String {
    match proto {
        "hysteria2" | "hy2" => "hysteria2".to_string(),
        "shadowsocks" => "ss".to_string(),
        v => v.to_string(),
    }
}

fn keep_node(rule: Option<&ClashProtocolRule>, current: usize) -> bool {
    let Some(r) = rule else {
        return false;
    };
    if !r.enabled {
        return false;
    }
    r.max_count == 0 || current < r.max_count
}

fn to_provider_yaml(nodes: &[ClashNode]) -> String {
    let mut out = String::from("proxies:\n");
    for n in nodes {
        out.push_str(&format!(
            "  - name: \"{}\"\n    type: {}\n    server: {}\n    port: {}\n\n",
            n.name, n.proto, n.server, n.port
        ));
    }
    out
}

fn to_full_yaml(nodes: &[ClashNode]) -> String {
    format!(
        "port: 7890\nsocks-port: 7891\nmode: rule\nallow-lan: true\n\n{}\nproxy-groups:\n  - name: AUTO\n    type: select\n    proxies:\n{}\nrules:\n  - MATCH,AUTO\n",
        to_provider_yaml(nodes),
        nodes
            .iter()
            .map(|n| format!("      - {}", n.name))
            .collect::<Vec<_>>()
            .join("\n")
    )
}

pub fn convert_tested_to_clash(
    mixed_input: &BTreeSet<String>,
    output_dir: &Path,
    cfg: &ClashConverterConfig,
    tx: &Sender<AppEvent>,
) {
    if !cfg.enabled {
        return;
    }

    log_worker(
        tx,
        LogLevel::Info,
        format!("🧩 PHASE 3 START | input_mixed={}", mixed_input.len()),
    );

    let mut nodes = Vec::new();
    let mut per_proto: BTreeMap<String, usize> = BTreeMap::new();

    for link in mixed_input {
        if let Some(node) = parse_node(link, nodes.len() + 1) {
            let key = protocol_key(&node.proto);
            let rule = cfg.protocol_rules.get(&key);
            let count = *per_proto.get(&key).unwrap_or(&0);
            if !keep_node(rule, count) {
                continue;
            }
            per_proto.insert(key, count + 1);
            nodes.push(node);
        }
    }

    nodes.sort_by_key(|n| {
        let k = protocol_key(&n.proto);
        cfg.protocol_rules
            .get(&k)
            .map(|v| v.priority)
            .unwrap_or(999)
    });

    if cfg.total_limit > 0 && nodes.len() > cfg.total_limit {
        nodes.truncate(cfg.total_limit);
    }

    let yaml = if cfg.output_full_config {
        to_full_yaml(&nodes)
    } else {
        to_provider_yaml(&nodes)
    };

    let out_folder = output_dir.join("phase3_clash");
    let _ = fs::create_dir_all(&out_folder);
    let out_file = if cfg.output_full_config {
        out_folder.join("clash_config.yaml")
    } else {
        out_folder.join("clash_provider.yaml")
    };

    if fs::write(&out_file, yaml).is_ok() {
        log_worker(
            tx,
            LogLevel::Success,
            format!(
                "✅ PHASE 3 COMPLETE | converted={} | file={}",
                nodes.len(),
                out_file.display()
            ),
        );
    } else {
        log_worker(
            tx,
            LogLevel::Error,
            "❌ PHASE 3 failed to write output file.".to_string(),
        );
    }

    let _ = fs::write(
        out_folder.join("source_mixed.txt"),
        mixed_input.iter().cloned().collect::<Vec<_>>().join("\n"),
    );

    let _ = fs::write(
        out_folder.join("source_by_protocol.json"),
        serde_json::to_string_pretty(&per_proto).unwrap_or_else(|_| "{}".to_string()),
    );

    let _ = fs::write(
        out_folder.join("source_original.txt"),
        nodes
            .iter()
            .map(|n| n.original.clone())
            .collect::<Vec<_>>()
            .join("\n"),
    );
}
