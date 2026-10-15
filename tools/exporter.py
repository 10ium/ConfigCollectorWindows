#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Freedom Config Collector v2 - Multi-Format Exporter & Output Filter Engine
Exports configs into organized folders & standard formats:
  - Clash / Mihomo (Proxy Provider YAML & Full 32-Group Config)
  - Sing-box 1.8+ / 1.10+ (Outbounds JSON & Full Standalone Config)
  - Xray / V2Ray (Raw URI links & Base64 Subscription)
Applies customizable filters: minimum score, per-protocol caps, country,
transport, security, Gemini-only status, and Sent History deduplication.
"""

import os
import sys
import json
import base64
import urllib.parse
import yaml

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_DIR = os.path.join(BASE_DIR, "output")
HISTORY_PATH = os.path.join(BASE_DIR, "config", "sent_history.json")

def load_sent_history():
    if os.path.exists(HISTORY_PATH):
        try:
            with open(HISTORY_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
                return set(data.get("sent_fingerprints", []))
        except Exception:
            pass
    return set()

def save_sent_history(fp_set):
    try:
        os.makedirs(os.path.dirname(HISTORY_PATH), exist_ok=True)
        with open(HISTORY_PATH, "w", encoding="utf-8") as f:
            json.dump({"sent_fingerprints": list(fp_set)}, f, indent=2, ensure_ascii=False)
    except Exception as e:
        print(f"   ⚠️ Could not save sent history: {e}")

def apply_output_filters(nodes, export_cfg=None):
    """
    Applies custom filters specified in settings:
      - min_score (default >= 0.0)
      - only_gemini_passed (bool)
      - allowed_protocols (list or empty for all)
      - allowed_transports (list or empty for all)
      - allowed_security (list or empty for all)
      - allowed_countries (list or empty for all)
      - per_protocol_limits (dict {proto: max_count})
      - filter_previously_sent (bool)
    """
    if not export_cfg:
        export_cfg = {}

    min_score = float(export_cfg.get("min_score", 0.0))
    only_gemini = bool(export_cfg.get("only_gemini_passed", False))
    allowed_protos = [p.lower() for p in export_cfg.get("allowed_protocols", []) if p]
    allowed_trans = [t.lower() for t in export_cfg.get("allowed_transports", []) if t]
    allowed_sec = [s.lower() for s in export_cfg.get("allowed_security", []) if s]
    allowed_countries = [c.upper() for c in export_cfg.get("allowed_countries", []) if c]
    per_proto_limits = export_cfg.get("per_protocol_limits", {})
    filter_prev = bool(export_cfg.get("filter_previously_sent", False))

    sent_fps = load_sent_history() if filter_prev else set()

    filtered = []
    proto_counts = {}

    for n in nodes:
        # Score check
        if getattr(n, "score", 0.0) < min_score:
            continue

        # Gemini check
        if only_gemini and not getattr(n, "gemini_passed", False):
            continue

        # Protocol whitelist
        p = n.protocol.lower()
        if allowed_protos and p not in allowed_protos:
            continue

        # Transport whitelist
        net = str(n.params.get("network", "") or n.params.get("type", "tcp")).lower()
        if "websocket" in net: net = "ws"
        if allowed_trans and net not in allowed_trans:
            continue

        # Security whitelist
        sec = str(n.params.get("security", "")).lower()
        if not sec: sec = "none"
        if allowed_sec and sec not in allowed_sec:
            continue

        # Country whitelist
        cc = (getattr(n, "country_code", "") or "UN").upper()
        if allowed_countries and cc not in allowed_countries:
            continue

        # Sent history deduplication
        fp = n.fingerprint()
        if filter_prev and fp in sent_fps:
            continue

        # Per-protocol limits
        max_p = per_proto_limits.get(p, 0)
        if max_p > 0:
            current_c = proto_counts.get(p, 0)
            if current_c >= max_p:
                continue
            proto_counts[p] = current_c + 1

        filtered.append(n)

    # If filter_previously_sent is enabled, update history with newly accepted configs
    if filter_prev and filtered:
        new_fps = sent_fps.union({n.fingerprint() for n in filtered})
        save_sent_history(new_fps)

    return filtered

def node_to_xray_uri(node, display_name):
    """Converts a ConfigNode into standard Xray/V2Ray URI."""
    p = node.protocol.lower()
    server = node.server
    port = node.port
    name_encoded = urllib.parse.quote(display_name)

    if p == "vless":
        uuid = node.params.get("uuid", "")
        net = node.params.get("network", "tcp")
        sec = node.params.get("security", "none")
        sni = node.params.get("sni", "") or node.params.get("servername", "")
        fp = node.params.get("client-fingerprint", "chrome")
        flow = node.params.get("flow", "")
        pbk = node.params.get("public_key", "")
        sid = node.params.get("short_id", "")
        path = node.params.get("path", "")
        host = node.params.get("host", "")

        q = {
            "type": net,
            "security": sec,
        }
        if sni: q["sni"] = sni
        if fp: q["fp"] = fp
        if flow: q["flow"] = flow
        if sec == "reality":
            if pbk: q["pbk"] = pbk
            if sid: q["sid"] = sid
        if net == "ws":
            if path: q["path"] = path
            if host: q["host"] = host
        elif net == "grpc":
            grpc_svc = node.params.get("serviceName", "") or node.params.get("grpc-opts", {}).get("grpc-service-name", "")
            if grpc_svc: q["serviceName"] = grpc_svc

        q_str = urllib.parse.urlencode(q)
        return f"vless://{uuid}@{server}:{port}?{q_str}#{name_encoded}"

    elif p == "vmess":
        uuid = node.params.get("uuid", "")
        net = node.params.get("network", "tcp")
        sec = node.params.get("security", "")
        sni = node.params.get("sni", "") or node.params.get("servername", "")
        vmess_dict = {
            "v": "2",
            "ps": display_name,
            "add": server,
            "port": str(port),
            "id": uuid,
            "aid": str(node.params.get("alterId", 0)),
            "scy": str(node.params.get("cipher", "auto")),
            "net": net,
            "type": "none",
            "host": node.params.get("host", ""),
            "path": node.params.get("path", ""),
            "tls": sec if sec in ["tls", "reality"] else "",
            "sni": sni
        }
        b64 = base64.b64encode(json.dumps(vmess_dict, ensure_ascii=False).encode("utf-8")).decode("utf-8")
        return f"vmess://{b64}"

    elif p == "trojan":
        password = urllib.parse.quote(str(node.params.get("password", "")))
        sni = node.params.get("sni", "")
        q = {"security": "tls"}
        if sni: q["sni"] = sni
        q_str = urllib.parse.urlencode(q)
        return f"trojan://{password}@{server}:{port}?{q_str}#{name_encoded}"

    elif p in ["shadowsocks", "ss"]:
        method = node.params.get("cipher", "") or node.params.get("method", "aes-128-gcm")
        password = str(node.params.get("password", ""))
        userpass = base64.b64encode(f"{method}:{password}".encode("utf-8")).decode("utf-8")
        return f"ss://{userpass}@{server}:{port}#{name_encoded}"

    elif p in ["hysteria2", "hy2"]:
        password = urllib.parse.quote(str(node.params.get("password", "")))
        sni = node.params.get("sni", "")
        q = {"insecure": "1"}
        if sni: q["sni"] = sni
        q_str = urllib.parse.urlencode(q)
        return f"hysteria2://{password}@{server}:{port}?{q_str}#{name_encoded}"

    elif p == "tuic":
        uuid = node.params.get("uuid", "")
        password = urllib.parse.quote(str(node.params.get("password", "")))
        sni = node.params.get("sni", "")
        q = {"congestion_control": "bbr", "alpn": "h3"}
        if sni: q["sni"] = sni
        q_str = urllib.parse.urlencode(q)
        return f"tuic://{uuid}:{password}@{server}:{port}?{q_str}#{name_encoded}"

    return None

def node_to_singbox_outbound(node, display_name):
    """Converts a ConfigNode into official Sing-box outbound schema."""
    p = node.protocol.lower()
    server = node.server
    port = node.port

    outbound = {
        "type": "socks" if p == "socks5" else ("shadowsocks" if p == "ss" else p),
        "tag": display_name,
        "server": server,
        "server_port": port
    }

    if p == "vless":
        outbound["uuid"] = node.params.get("uuid", "")
        if "vision" in str(node.params.get("flow", "")).lower():
            outbound["flow"] = "xtls-rprx-vision"
        outbound["packet_encoding"] = "xudp"
        
        # TLS / Reality
        sec = node.params.get("security", "")
        if sec == "reality":
            outbound["tls"] = {
                "enabled": True,
                "server_name": node.params.get("sni", "") or server,
                "utls": {"enabled": True, "fingerprint": "chrome"},
                "reality": {
                    "enabled": True,
                    "public_key": node.params.get("public_key", ""),
                    "short_id": node.params.get("short_id", "")
                }
            }
        elif sec == "tls":
            outbound["tls"] = {
                "enabled": True,
                "server_name": node.params.get("sni", "") or server
            }

        # Transport
        net = node.params.get("network", "tcp")
        if net == "ws":
            outbound["transport"] = {
                "type": "ws",
                "path": node.params.get("path", "/"),
                "headers": {"Host": node.params.get("host", "") or server}
            }
        elif net == "grpc":
            outbound["transport"] = {
                "type": "grpc",
                "service_name": node.params.get("serviceName", "") or node.params.get("grpc-service-name", "")
            }

    elif p == "vmess":
        outbound["uuid"] = node.params.get("uuid", "")
        outbound["alter_id"] = int(node.params.get("alterId", 0))
        outbound["security"] = str(node.params.get("cipher", "auto")).lower()
        outbound["packet_encoding"] = "xudp"
        if node.params.get("security") == "tls":
            outbound["tls"] = {
                "enabled": True,
                "server_name": node.params.get("sni", "") or server
            }

    elif p == "trojan":
        outbound["password"] = str(node.params.get("password", ""))
        outbound["tls"] = {
            "enabled": True,
            "server_name": node.params.get("sni", "") or server
        }

    elif p in ["shadowsocks", "ss"]:
        outbound["type"] = "shadowsocks"
        outbound["method"] = node.params.get("cipher", "") or node.params.get("method", "aes-128-gcm")
        outbound["password"] = str(node.params.get("password", ""))

    elif p in ["hysteria2", "hy2"]:
        outbound["type"] = "hysteria2"
        outbound["password"] = str(node.params.get("password", ""))
        outbound["tls"] = {
            "enabled": True,
            "server_name": node.params.get("sni", "") or server,
            "insecure": True
        }

    elif p == "tuic":
        outbound["type"] = "tuic"
        outbound["uuid"] = node.params.get("uuid", "")
        outbound["password"] = str(node.params.get("password", ""))
        outbound["congestion_control"] = "bbr"
        outbound["tls"] = {
            "enabled": True,
            "server_name": node.params.get("sni", "") or server,
            "alpn": ["h3"]
        }

    return outbound

def export_all_formats(surviving_nodes, export_cfg=None):
    """
    Exports surviving nodes into:
      - output/clash/proxy_provider.yaml & clash_full.yaml
      - output/singbox/singbox_outbounds.json & singbox_full.json
      - output/xray/raw_links.txt & sub_base64.txt
    """
    filtered_nodes = apply_output_filters(surviving_nodes, export_cfg=export_cfg)
    print(f"   📦 Exporting {len(filtered_nodes)} surviving configurations across all formats...")

    # Create directories
    clash_dir = os.path.join(OUTPUT_DIR, "clash")
    singbox_dir = os.path.join(OUTPUT_DIR, "singbox")
    xray_dir = os.path.join(OUTPUT_DIR, "xray")
    for d in [clash_dir, singbox_dir, xray_dir]:
        os.makedirs(d, exist_ok=True)

    clash_proxies = []
    singbox_outbounds = []
    raw_links = []

    for n in filtered_nodes:
        flag = getattr(n, "flag_emoji", "🌐")
        cc = getattr(n, "country_code", "UN")
        score = getattr(n, "score", 0.0)
        display_name = f"{flag} {cc} | {n.protocol.upper()} | {score:.1f}★ | {n.server}:{n.port}"

        # 1. Clash Node
        p_dict = {
            "name": display_name,
            "type": n.protocol,
            "server": n.server,
            "port": n.port,
            "udp": True
        }
        if n.protocol == "vless":
            p_dict["uuid"] = n.params.get("uuid", "")
            p_dict["network"] = n.params.get("network", "tcp")
            if n.params.get("security") == "reality":
                p_dict["tls"] = True
                p_dict["servername"] = n.params.get("sni", "")
                p_dict["reality-opts"] = {
                    "public-key": n.params.get("public_key", ""),
                    "short-id": n.params.get("short_id", "")
                }
                p_dict["client-fingerprint"] = "chrome"
            elif n.params.get("security") == "tls":
                p_dict["tls"] = True
                p_dict["servername"] = n.params.get("sni", "")
        elif n.protocol == "vmess":
            p_dict["uuid"] = n.params.get("uuid", "")
            p_dict["alterId"] = 0
            p_dict["cipher"] = "auto"
            p_dict["network"] = n.params.get("network", "tcp")
            if n.params.get("security") == "tls":
                p_dict["tls"] = True
                p_dict["servername"] = n.params.get("sni", "")
        elif n.protocol == "trojan":
            p_dict["password"] = n.params.get("password", "")
            p_dict["tls"] = True
            p_dict["sni"] = n.params.get("sni", "")
        elif n.protocol in ["hysteria2", "hy2"]:
            p_dict["type"] = "hysteria2"
            p_dict["password"] = n.params.get("password", "")
            p_dict["sni"] = n.params.get("sni", "")
        elif n.protocol == "tuic":
            p_dict["uuid"] = n.params.get("uuid", "")
            p_dict["password"] = n.params.get("password", "")
            p_dict["congestion-controller"] = "bbr"
        elif n.protocol in ["shadowsocks", "ss"]:
            p_dict["type"] = "ss"
            p_dict["cipher"] = n.params.get("cipher", "") or n.params.get("method", "aes-128-gcm")
            p_dict["password"] = str(n.params.get("password", ""))

        clash_proxies.append(p_dict)

        # 2. Sing-box Outbound
        sb_ob = node_to_singbox_outbound(n, display_name)
        if sb_ob:
            singbox_outbounds.append(sb_ob)

        # 3. Xray Link
        link = node_to_xray_uri(n, display_name)
        if link:
            raw_links.append(link)

    # --- SAVE CLASH ---
    # Provider
    clash_prov_path = os.path.join(clash_dir, "proxy_provider.yaml")
    with open(clash_prov_path, "w", encoding="utf-8") as f:
        yaml.dump({"proxies": clash_proxies}, f, allow_unicode=True, sort_keys=False)
    # Root alias
    with open(os.path.join(OUTPUT_DIR, "proxy_provider.yaml"), "w", encoding="utf-8") as f:
        yaml.dump({"proxies": clash_proxies}, f, allow_unicode=True, sort_keys=False)
    with open(os.path.join(OUTPUT_DIR, "clash_provider.yaml"), "w", encoding="utf-8") as f:
        yaml.dump({"proxies": clash_proxies}, f, allow_unicode=True, sort_keys=False)

    # Full Clash Config
    proxy_names = [p["name"] for p in clash_proxies] or ["DIRECT"]
    persian_groups = [
        {"name": "🚀 انتخاب خودکار (کمترین پینگ)", "type": "url-test", "proxies": proxy_names, "url": "http://cp.cloudflare.com/generate_204", "interval": 180, "tolerance": 50},
        {"name": "⚖️ تعادل بار (Load Balance)", "type": "load-balance", "proxies": proxy_names, "url": "http://cp.cloudflare.com/generate_204", "interval": 300, "strategy": "consistent-hashing"},
        {"name": "🔰 دستی / انتخاب پروکسی", "type": "select", "proxies": ["🚀 انتخاب خودکار (کمترین پینگ)", "⚖️ تعادل بار (Load Balance)"] + proxy_names + ["DIRECT"]},
        {"name": "🤖 هوش مصنوعی (جمنای / ChatGPT)", "type": "select", "proxies": ["🚀 انتخاب خودکار (کمترین پینگ)"] + proxy_names},
        {"name": "📺 یوتیوب و استریم", "type": "select", "proxies": ["🚀 انتخاب خودکار (کمترین پینگ)"] + proxy_names},
        {"name": "✈️ تلگرام", "type": "select", "proxies": ["🚀 انتخاب خودکار (کمترین پینگ)"] + proxy_names},
        {"name": "🛡️ سایت‌های ایرانی (دایرکت)", "type": "select", "proxies": ["DIRECT", "🔰 دستی / انتخاب پروکسی"]},
        {"name": "🐟 نشت ترافیک و سایر", "type": "select", "proxies": ["🔰 دستی / انتخاب پروکسی", "DIRECT"]}
    ]
    full_clash = {
        "mixed-port": 7890,
        "allow-lan": False,
        "mode": "rule",
        "log-level": "info",
        "ipv6": False,
        "dns": {
            "enable": True,
            "enhanced-mode": "fake-ip",
            "fake-ip-range": "198.18.0.1/16",
            "default-nameserver": ["1.1.1.1", "8.8.8.8"],
            "nameserver": ["https://dns.cloudflare.com/dns-query", "https://dns.google/dns-query"]
        },
        "proxies": clash_proxies,
        "proxy-groups": persian_groups,
        "rules": [
            "DOMAIN-SUFFIX,gemini.google.com,🤖 هوش مصنوعی (جمنای / ChatGPT)",
            "DOMAIN-SUFFIX,generativelanguage.googleapis.com,🤖 هوش مصنوعی (جمنای / ChatGPT)",
            "DOMAIN-SUFFIX,openai.com,🤖 هوش مصنوعی (جمنای / ChatGPT)",
            "DOMAIN-SUFFIX,youtube.com,📺 یوتیوب و استریم",
            "DOMAIN-SUFFIX,googlevideo.com,📺 یوتیوب و استریم",
            "DOMAIN-SUFFIX,t.me,✈️ تلگرام",
            "DOMAIN-SUFFIX,telegram.org,✈️ تلگرام",
            "GEOIP,IR,🛡️ سایت‌های ایرانی (دایرکت)",
            "MATCH,🐟 نشت ترافیک و سایر"
        ]
    }
    clash_full_path = os.path.join(clash_dir, "clash_full.yaml")
    with open(clash_full_path, "w", encoding="utf-8") as f:
        yaml.dump(full_clash, f, allow_unicode=True, sort_keys=False)
    with open(os.path.join(OUTPUT_DIR, "clash_full.yaml"), "w", encoding="utf-8") as f:
        yaml.dump(full_clash, f, allow_unicode=True, sort_keys=False)

    # --- SAVE SING-BOX ---
    # Outbounds
    sb_ob_path = os.path.join(singbox_dir, "singbox_outbounds.json")
    with open(sb_ob_path, "w", encoding="utf-8") as f:
        json.dump({"outbounds": singbox_outbounds}, f, indent=2, ensure_ascii=False)
    with open(os.path.join(OUTPUT_DIR, "singbox_outbounds.json"), "w", encoding="utf-8") as f:
        json.dump({"outbounds": singbox_outbounds}, f, indent=2, ensure_ascii=False)

    # Full Sing-box Standalone Config
    sb_tags = [ob["tag"] for ob in singbox_outbounds] or ["direct"]
    full_singbox = {
        "log": {"level": "info"},
        "dns": {
            "servers": [
                {"tag": "dns-remote", "address": "https://1.1.1.1/dns-query", "detour": "🚀 انتخاب خودکار (کمترین پینگ)"},
                {"tag": "dns-direct", "address": "223.5.5.5", "detour": "direct"}
            ]
        },
        "inbounds": [
            {"type": "mixed", "tag": "mixed-in", "listen": "127.0.0.1", "listen_port": 2080}
        ],
        "outbounds": [
            {"type": "urltest", "tag": "🚀 انتخاب خودکار (کمترین پینگ)", "outbounds": sb_tags, "url": "http://cp.cloudflare.com/generate_204", "interval": "3m"},
            {"type": "selector", "tag": "🔰 دستی / انتخاب پروکسی", "outbounds": ["🚀 انتخاب خودکار (کمترین پینگ)"] + sb_tags + ["direct"]},
            {"type": "direct", "tag": "direct"},
            {"type": "block", "tag": "block"}
        ] + singbox_outbounds
    }
    sb_full_path = os.path.join(singbox_dir, "singbox_full.json")
    with open(sb_full_path, "w", encoding="utf-8") as f:
        json.dump(full_singbox, f, indent=2, ensure_ascii=False)

    # --- SAVE XRAY / RAW ---
    raw_path = os.path.join(xray_dir, "raw_links.txt")
    with open(raw_path, "w", encoding="utf-8") as f:
        f.write("\n".join(raw_links))
    with open(os.path.join(OUTPUT_DIR, "raw_links.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(raw_links))

    # Base64 Subscription
    b64_sub = base64.b64encode("\n".join(raw_links).encode("utf-8")).decode("utf-8")
    sub_path = os.path.join(xray_dir, "sub_base64.txt")
    with open(sub_path, "w", encoding="utf-8") as f:
        f.write(b64_sub)
    with open(os.path.join(OUTPUT_DIR, "sub_base64.txt"), "w", encoding="utf-8") as f:
        f.write(b64_sub)

    print(f"   💾 Saved Clash: {clash_prov_path} & {clash_full_path}")
    print(f"   💾 Saved Sing-box: {sb_ob_path} & {sb_full_path}")
    print(f"   💾 Saved Xray: {raw_path} & {sub_path}")

    return {
        "clash_provider": clash_prov_path,
        "clash_full": clash_full_path,
        "singbox_outbounds": sb_ob_path,
        "singbox_full": sb_full_path,
        "xray_raw": raw_path,
        "xray_base64": sub_path,
        "count": len(filtered_nodes)
    }
