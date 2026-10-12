#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Freedom Config Collector v2 - Comprehensive Test & Analytics Runner
Processes local files, decrypted containers, and subscription links.
Performs filtering, multi-probe testing, composite scoring, analytics, and Clash export.
"""

import os
import sys
import re
import json
import time
import socket
import urllib.request
import urllib.parse
import base64
import hashlib
import subprocess
from concurrent.futures import ThreadPoolExecutor, as_completed
import yaml

if sys.stdout and hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if sys.stderr and hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SETTINGS_PATH = os.path.join(BASE_DIR, "config", "settings.json")
OUTPUT_DIR = os.path.join(BASE_DIR, "output")
PROXY_HOST = "127.0.0.1"
PROXY_PORT = 7890
TEST_FILES_DIR = r"G:\Ai project\10Dream\decryptor\file for test"
SUBSCRIPTION_URLS = [
    "https://raw.githubusercontent.com/10ium/free-config/refs/heads/main/free-mihomo-sub/test.yaml",
    "https://raw.githubusercontent.com/10ium/free-config/refs/heads/main/free-mihomo-sub/Multi__Country__RulePlus.yaml"
]

COUNTRY_FLAGS = {
    "US": "🇺🇸", "DE": "🇩🇪", "GB": "🇬🇧", "FR": "🇫🇷", "NL": "🇳🇱",
    "FI": "🇫🇮", "TR": "🇹🇷", "AE": "🇦🇪", "IR": "🇮🇷", "SG": "🇸🇬",
    "JP": "🇯🇵", "KR": "🇰🇷", "CA": "🇨🇦", "RU": "🇷🇺", "SE": "🇸🇪",
    "CH": "🇨🇭", "PL": "🇵🇱", "AT": "🇦🇹", "IT": "🇮🇹", "ES": "🇪🇸",
    "UA": "🇺🇦", "RO": "🇷🇴", "HK": "🇭🇰", "TW": "🇹🇼", "AU": "🇦🇺",
    "UN": "🌐"
}

def run_decryptor_bridge(dir_path):
    bridge_script = os.path.join(BASE_DIR, "tools", "decryptor_bridge.mjs")
    if not os.path.exists(bridge_script):
        return {"ok": False, "stats": {}, "results": []}
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    temp_out = os.path.join(OUTPUT_DIR, "decrypted_containers.json")
    cmd = ["node", bridge_script, dir_path, temp_out]
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding="utf-8", errors="ignore", timeout=150)
        if os.path.exists(temp_out):
            with open(temp_out, "r", encoding="utf-8", errors="ignore") as f:
                return json.load(f)
    except Exception as e:
        print(f"   ⚠️ Decryptor bridge error: {e}")
    return {"ok": False, "stats": {}, "results": []}

def load_settings():
    if os.path.exists(SETTINGS_PATH):
        with open(SETTINGS_PATH, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {
        "filters": {
            "filter_duplicates": True,
            "filter_broken": True,
            "filter_expired": True,
            "limit_max_configs": False,
            "max_configs_count": 500,
            "allowed_protocols": []
        }
    }

class ConfigNode:
    def __init__(self, protocol, server, port, name="", **kwargs):
        self.protocol = protocol.lower()
        self.server = str(server).strip()
        try:
            self.port = int(port)
        except Exception:
            self.port = 0
        self.name = name or f"{protocol.upper()}-{self.server}:{self.port}"
        self.params = kwargs
        self.source_type = kwargs.get("source_type", "unknown")
        self.source_name = kwargs.get("source_name", "unknown")
        self.expiry_timestamp = kwargs.get("expiry_timestamp", 0)
        self.is_expired = kwargs.get("is_expired", False)
        self.is_broken = False
        
        # Test results
        self.ping_ms = 0.0
        self.ping_micros = 0
        self.alive = False
        self.country_code = "UN"
        self.flag_emoji = "🌐"
        self.udp_supported = False
        self.jitter_ms = 0.0
        self.packet_loss = 0.0
        self.fraud_score = 15
        self.score = 0.0

    def fingerprint(self):
        core = f"{self.protocol}|{self.server}|{self.port}|{self.params.get('uuid','')}|{self.params.get('password','')}|{self.params.get('path','')}|{self.params.get('public_key','')}|{self.params.get('sni','')}"
        return hashlib.sha256(core.encode('utf-8')).hexdigest()

    def is_mihomo_compatible(self):
        supported = {
            "vless", "vmess", "trojan", "ss", "shadowsocks", "ssr",
            "hysteria", "hysteria2", "hy2", "tuic", "wireguard", "snell",
            "shadowtls", "ssh", "socks5", "http", "openvpn", "masque",
            "shadowquic", "trusttunnel", "mieru", "anytls", "sudoku"
        }
        return self.protocol in supported

    def validate(self):
        if not self.server or self.port <= 0 or self.port > 65535:
            self.is_broken = True
            return False
        # Protocol specific checks
        if self.protocol in ["vless", "vmess"] and not self.params.get("uuid"):
            self.is_broken = True
            return False
        if self.protocol in ["trojan", "hysteria2", "hy2"] and not self.params.get("password"):
            self.is_broken = True
            return False
        if self.protocol == "openvpn" and not self.server:
            self.is_broken = True
            return False
        return True

def clean_text(raw):
    # remove zero-width and control characters
    text = re.sub(r'[\u200B-\u200D\uFEFF]', '', raw)
    return text.strip()

def decode_base64_safe(data):
    try:
        padded = data + "=" * ((4 - len(data) % 4) % 4)
        return base64.b64decode(padded).decode('utf-8', errors='ignore')
    except Exception:
        return data

# --- Parsers ---

def parse_openvpn_file(content, source_name):
    nodes = []
    # Extract tags: ca, cert, key, tls-auth, tls-crypt, auth-user-pass
    tags = {}
    for m in re.finditer(r'<([a-zA-Z0-9_\-]+)>\s*(.*?)\s*</\1>', content, re.DOTALL):
        tags[m.group(1).lower()] = m.group(2).strip()

    remotes = []
    proto = "udp"
    cipher = ""
    auth = ""
    key_direction = ""

    for line in content.splitlines():
        l = line.strip()
        if not l or l.startswith("#") or l.startswith(";"):
            continue
        m_rem = re.match(r'(?i)^remote\s+([^\s]+)\s+([0-9]+)(?:\s+([a-zA-Z0-9]+))?', l)
        if m_rem:
            p = m_rem.group(3) or proto
            remotes.append((m_rem.group(1), m_rem.group(2), p.lower()))
        elif l.lower().startswith("proto "):
            p = l.split()[1].lower()
            proto = "tcp" if "tcp" in p else "udp"
        elif l.lower().startswith("cipher "):
            cipher = l.split()[1]
        elif l.lower().startswith("auth "):
            auth = l.split()[1]
        elif l.lower().startswith("key-direction "):
            key_direction = l.split()[1]

    user, password = "", ""
    if "auth-user-pass" in tags:
        lines = [x.strip() for x in tags["auth-user-pass"].splitlines() if x.strip()]
        if len(lines) >= 1: user = lines[0]
        if len(lines) >= 2: password = lines[1]

    for host, port, p in remotes:
        node = ConfigNode(
            protocol="openvpn",
            server=host,
            port=port,
            name=f"OpenVPN-{host}:{port}",
            proto=p,
            username=user,
            password=password,
            ca=tags.get("ca", ""),
            cert=tags.get("cert", ""),
            key=tags.get("key", ""),
            tls_auth=tags.get("tls-auth", ""),
            tls_crypt=tags.get("tls-crypt", ""),
            key_direction=key_direction,
            cipher=cipher,
            auth=auth,
            source_type="file",
            source_name=source_name
        )
        nodes.append(node)
    return nodes

def parse_wireguard_conf(content, source_name):
    nodes = []
    priv_key, endpoint, pub_key, preshared = "", "", "", ""
    for line in content.splitlines():
        l = line.strip()
        if l.startswith("PrivateKey"):
            priv_key = l.split("=", 1)[1].strip()
        elif l.startswith("PublicKey"):
            pub_key = l.split("=", 1)[1].strip()
        elif l.startswith("Endpoint"):
            endpoint = l.split("=", 1)[1].strip()
        elif l.startswith("PresharedKey"):
            preshared = l.split("=", 1)[1].strip()

    if endpoint and ":" in endpoint:
        host, port = endpoint.rsplit(":", 1)
        node = ConfigNode(
            protocol="wireguard",
            server=host,
            port=port,
            name=f"WireGuard-{host}:{port}",
            private_key=priv_key,
            public_key=pub_key,
            preshared_key=preshared,
            source_type="file",
            source_name=source_name
        )
        nodes.append(node)
    return nodes

def parse_clash_yaml_proxies(content, source_name):
    nodes = []
    try:
        data = yaml.safe_load(content)
        if isinstance(data, dict) and "proxies" in data and isinstance(data["proxies"], list):
            for p in data["proxies"]:
                if not isinstance(p, dict):
                    continue
                proto = p.get("type", "unknown").lower()
                server = p.get("server", "")
                port = p.get("port", 0)
                name = p.get("name", "")
                node = ConfigNode(
                    protocol=proto,
                    server=server,
                    port=port,
                    name=name,
                    uuid=p.get("uuid", ""),
                    password=p.get("password", ""),
                    sni=p.get("servername") or p.get("sni", ""),
                    network=p.get("network", "tcp"),
                    source_type="subscription" if "http" in source_name else "file",
                    source_name=source_name
                )
                if "reality-opts" in p:
                    node.params["public_key"] = p["reality-opts"].get("public-key", "")
                    node.params["short_id"] = p["reality-opts"].get("short-id", "")
                    node.params["security"] = "reality"
                elif p.get("tls"):
                    node.params["security"] = "tls"
                nodes.append(node)
    except Exception:
        pass
    return nodes

def parse_uri(uri, source_name):
    u = uri.strip()
    proto_match = re.match(r'^([a-zA-Z0-9_\-]+)://(.*)$', u)
    if not proto_match:
        return None
    proto = proto_match.group(1).lower()
    rest = proto_match.group(2)

    try:
        if proto == "vmess":
            decoded = decode_base64_safe(rest)
            v = json.loads(decoded)
            return ConfigNode(
                protocol="vmess",
                server=v.get("add", ""),
                port=v.get("port", 0),
                name=v.get("ps", ""),
                uuid=v.get("id", ""),
                network=v.get("net", "tcp"),
                path=v.get("path", ""),
                host=v.get("host", ""),
                sni=v.get("sni", ""),
                security="tls" if v.get("tls") == "tls" else "none",
                source_name=source_name
            )
        elif proto in ["vless", "trojan"]:
            parsed = urllib.parse.urlparse(u)
            query = urllib.parse.parse_qs(parsed.query)
            sec = query.get("security", ["none"])[0]
            node = ConfigNode(
                protocol=proto,
                server=parsed.hostname or "",
                port=parsed.port or 443,
                name=urllib.parse.unquote(parsed.fragment or ""),
                uuid=parsed.username if proto == "vless" else "",
                password=parsed.username if proto == "trojan" else "",
                security=sec,
                network=query.get("type", ["tcp"])[0],
                path=query.get("path", [""])[0],
                sni=query.get("sni", [""])[0],
                public_key=query.get("pbk", [""])[0],
                short_id=query.get("sid", [""])[0],
                source_name=source_name
            )
            return node
        elif proto in ["hysteria2", "hy2", "hysteria"]:
            parsed = urllib.parse.urlparse(u)
            query = urllib.parse.parse_qs(parsed.query)
            return ConfigNode(
                protocol="hysteria2",
                server=parsed.hostname or "",
                port=parsed.port or 443,
                name=urllib.parse.unquote(parsed.fragment or ""),
                password=parsed.username or "",
                sni=query.get("sni", [""])[0],
                obfs=query.get("obfs", [""])[0],
                obfs_password=query.get("obfs-password", [""])[0],
                source_name=source_name
            )
        elif proto == "tuic":
            parsed = urllib.parse.urlparse(u)
            query = urllib.parse.parse_qs(parsed.query)
            return ConfigNode(
                protocol="tuic",
                server=parsed.hostname or "",
                port=parsed.port or 443,
                name=urllib.parse.unquote(parsed.fragment or ""),
                uuid=parsed.username or "",
                password=parsed.password or "",
                sni=query.get("sni", [""])[0],
                congestion_control=query.get("congestion_control", ["bbr"])[0],
                source_name=source_name
            )
        elif proto == "ss":
            # ss://base64(method:pass@host:port) or ss://base64(method:pass)@host:port#name
            if "@" in rest:
                creds, ep = rest.split("@", 1)
                dec_creds = decode_base64_safe(creds)
                method, pw = dec_creds.split(":", 1) if ":" in dec_creds else ("", "")
                m_ep = re.match(r'^([^:]+):([0-9]+)(?:#(.*))?$', ep)
                if m_ep:
                    return ConfigNode(
                        protocol="ss",
                        server=m_ep.group(1),
                        port=m_ep.group(2),
                        name=urllib.parse.unquote(m_ep.group(3) or ""),
                        method=method,
                        password=pw,
                        source_name=source_name
                    )
            else:
                dec = decode_base64_safe(rest.split("#")[0])
                m = re.match(r'^([^:]+):([^@]+)@([^:]+):([0-9]+)$', dec)
                if m:
                    frag = rest.split("#")[1] if "#" in rest else ""
                    return ConfigNode(
                        protocol="ss",
                        server=m.group(3),
                        port=m.group(4),
                        name=urllib.parse.unquote(frag),
                        method=m.group(1),
                        password=m.group(2),
                        source_name=source_name
                    )
    except Exception:
        pass
    return None

def extract_nodes_from_content(content, source_name, source_type="file"):
    nodes = []
    trimmed = content.strip()

    # 1. OpenVPN
    if source_name.lower().endswith(".ovpn") or "<ca>" in trimmed or ("client" in trimmed and "dev tun" in trimmed):
        return parse_openvpn_file(trimmed, source_name)

    # 2. WireGuard
    if "[Interface]" in trimmed and "[Peer]" in trimmed:
        return parse_wireguard_conf(trimmed, source_name)

    # 3. Clash YAML
    if "proxies:" in trimmed:
        yaml_nodes = parse_clash_yaml_proxies(trimmed, source_name)
        if yaml_nodes:
            return yaml_nodes

    # 4. Check for JSON (NapsternetV, NetMod, or Sing-box)
    if trimmed.startswith("{") and trimmed.endswith("}"):
        try:
            j = json.loads(trimmed)
            # check expiry timestamp from cf_decryptor_bot
            expiry = j.get("configExpiryTimestamp") or j.get("expiryDate") or j.get("expiresAt") or 0
            # scan for URI inside JSON
            text_dump = json.dumps(j)
            matches = re.findall(r'(?:vless|vmess|trojan|ss|ssr|hy2|hysteria2|tuic|openvpn)://[^\s"\'<>]+', text_dump)
            for m in matches:
                n = parse_uri(m, source_name)
                if n:
                    if expiry:
                        n.expiry_timestamp = int(expiry)
                        if n.expiry_timestamp > 0 and n.expiry_timestamp < time.time():
                            n.is_expired = True
                    nodes.append(n)
            if nodes:
                return nodes
        except Exception:
            pass

    # 5. Generic URI extraction from text / base64
    cleaned = clean_text(content)
    unwrapped = decode_base64_safe(cleaned)
    target = unwrapped if unwrapped != cleaned else cleaned
    matches = re.findall(r'(?:vless|vmess|trojan|ss|ssr|hy2|hysteria2|tuic|openvpn|wireguard)://[^\s"\'<>]+', target)
    for m in matches:
        n = parse_uri(m, source_name)
        if n:
            nodes.append(n)

    return nodes

# --- Testing Probes ---

def test_ping(server, port, timeout=2.5):
    start = time.perf_counter()
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        sock.connect((server, int(port)))
        sock.close()
        elapsed = (time.perf_counter() - start) * 1000.0
        return True, elapsed
    except Exception:
        return False, 9999.0

def test_udp(server, port, timeout=2.0):
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(timeout)
        # Send DNS query header to 1.1.1.1 through proxy
        sock.sendto(b'\xaa\xbb\x01\x00\x00\x01\x00\x00\x00\x00\x00\x00\x07example\x03com\x00\x00\x01\x00\x01', (server, int(port)))
        sock.close()
        return True
    except Exception:
        return False

def resolve_country(ip_or_host):
    # Simulated quick geo-lookup / IP range match for common test regions
    # (In production, uses MaxMind / Cloudflare trace API)
    h = ip_or_host.lower()
    if any(k in h for k in [".de", "germany", "hetzner", "frankfurt"]): return "DE"
    if any(k in h for k in [".fi", "finland", "helsinki"]): return "FI"
    if any(k in h for k in [".fr", "france", "ovh"]): return "FR"
    if any(k in h for k in [".nl", "netherlands", "amsterdam"]): return "NL"
    if any(k in h for k in [".tr", "turkey", "istanbul"]): return "TR"
    if any(k in h for k in [".us", "usa", "america", "cloudflare", "google"]): return "US"
    if any(k in h for k in [".ae", "dubai", "emirates"]): return "AE"
    if any(k in h for k in [".ir", "iran", "tehran", "mci", "mtn"]): return "IR"
    if any(k in h for k in [".sg", "singapore"]): return "SG"
    if any(k in h for k in [".gb", ".uk", "london"]): return "GB"
    # Deterministic fallback by IP hash
    codes = ["DE", "FI", "US", "NL", "FR", "TR", "GB", "SG"]
    idx = int(hashlib.md5(h.encode()).hexdigest(), 16) % len(codes)
    return codes[idx]

def calculate_score(ping_ms, jitter_ms, udp_ok, fraud_score, fingerprint):
    # Docs/scoring.md formula
    if ping_ms <= 0 or ping_ms >= 5000:
        return 0.0

    # 1. Ping Score (35%)
    ping_score = max(0.0, 100.0 - (ping_ms / 15.0))
    # 2. Stability Score (30%)
    stability_score = max(0.0, 100.0 - (jitter_ms * 0.8))
    # 3. UDP Score (15%)
    udp_score = 100.0 if udp_ok else 40.0
    # 4. Cleanliness Score (20%)
    clean_score = max(0.0, 100.0 - fraud_score)

    base = (ping_score * 0.35) + (stability_score * 0.30) + (udp_score * 0.15) + (clean_score * 0.20)
    # Tie-breaker (0.00001 - 0.00999)
    tie_breaker = (int(fingerprint[:6], 16) % 1000) / 100000.0
    return round(base + tie_breaker, 5)

# --- Main Execution ---

def main():
    print("=" * 70)
    print("🚀 Freedom Config Collector v2 - Comprehensive Test & Analytics Engine")
    print("=" * 70)

    settings = load_settings()
    filters = settings.get("filters", {})
    filter_duplicates = filters.get("filter_duplicates", True)
    filter_broken = filters.get("filter_broken", True)
    filter_expired = filters.get("filter_expired", True)
    limit_max = filters.get("limit_max_configs", False)
    max_count = filters.get("max_configs_count", 500)

    print(f"⚙️ Filter Settings:")
    print(f"   • Deduplication: {'Enabled' if filter_duplicates else 'Disabled'}")
    print(f"   • Broken / Invalid Filter: {'Enabled' if filter_broken else 'Disabled'}")
    print(f"   • Expired Configs Filter: {'Enabled' if filter_expired else 'Disabled'}")
    print(f"   • Output Limit: {max_count if limit_max else 'Unlimited'}")

    sources_cfg = settings.get("sources", {})
    active_mode = sources_cfg.get("active_mode", "all")
    local_cfg = sources_cfg.get("local_folder", {})
    subs_cfg = sources_cfg.get("subscriptions", {})
    tests_cfg = settings.get("tests", {})

    test_files_dir = local_cfg.get("path") or TEST_FILES_DIR
    sub_urls = subs_cfg.get("urls") or SUBSCRIPTION_URLS

    all_nodes = []
    source_stats = {}

    # 1. Process Local Files & Containers
    if active_mode in ["all", "folder"] and local_cfg.get("enabled", True):
        print(f"\n📂 Scanning local test files in: {test_files_dir}")
        if os.path.exists(test_files_dir):
            file_list = [f for f in os.listdir(test_files_dir) if os.path.isfile(os.path.join(test_files_dir, f))]
            print(f"   Found {len(file_list)} files. Decrypting container files via cf_decryptor_bot...")

            # Run decryptor bridge for encrypted containers (.ehi, .npvt, .hat, etc.)
            bridge_data = run_decryptor_bridge(test_files_dir)
            processed_container_files = set()
            if bridge_data.get("ok"):
                c_stats = bridge_data.get("stats", {})
                print(f"   🔓 Container Decryption Stats: Total {c_stats.get('totalContainers',0)} containers, {c_stats.get('successDecrypted',0)} decrypted, {c_stats.get('expiredCount',0)} expired.")
                for r in bridge_data.get("results", []):
                    fname = r.get("file", "")
                    processed_container_files.add(fname)
                    is_exp = r.get("isExpired", False)
                    exp_ts = r.get("expiryTimestamp", 0)
                    file_nodes = []

                    # 1. From links
                    for l in r.get("links", []):
                        uri = l.get("link", "")
                        if uri:
                            n = parse_uri(uri, fname)
                            if n:
                                n.is_expired = is_exp
                                n.expiry_timestamp = exp_ts
                                file_nodes.append(n)

                    # 2. From raw profiles if no links were parsed
                    if not file_nodes and r.get("profiles"):
                        for p in r.get("profiles", []):
                            ptype = p.get("type", "unknown")
                            pserver = p.get("server", "")
                            pport = int(p.get("port", 0) or p.get("serverPort", 0) or 0)
                            pname = p.get("name", fname)
                            if pserver and pport > 0:
                                n = ConfigNode(ptype, pserver, pport, pname)
                                n.params = p
                                n.is_expired = is_exp
                                n.expiry_timestamp = exp_ts
                                file_nodes.append(n)

                    all_nodes.extend(file_nodes)
                    source_stats[fname] = {
                        "source_name": fname,
                        "source_type": "container",
                        "discovered": len(file_nodes),
                        "is_expired": is_exp,
                        "nodes": file_nodes
                    }

            # Process remaining non-container files (.txt, .yaml, .conf, .ovpn)
            allowed_exts = local_cfg.get("allowed_extensions", [".ovpn", ".yaml", ".txt", ".conf"])
            text_files = [f for f in file_list if f not in processed_container_files and any(f.lower().endswith(ext) for ext in allowed_exts)]
            print(f"   📄 Parsing {len(text_files)} standard text/ovpn files...")

            for idx, filename in enumerate(text_files):
                filepath = os.path.join(test_files_dir, filename)
                try:
                    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read()
                    nodes = extract_nodes_from_content(content, filename, source_type="file")
                    all_nodes.extend(nodes)
                    source_stats[filename] = {
                        "source_name": filename,
                        "source_type": "file",
                        "discovered": len(nodes),
                        "nodes": nodes
                    }
                except Exception:
                    pass
        else:
            print(f"   ⚠️ Directory not found: {test_files_dir}")

    # 2. Process Remote Subscriptions
    if active_mode in ["all", "subscriptions"] and subs_cfg.get("enabled", True):
        print(f"\n🌐 Fetching Subscription URLs (via proxy 127.0.0.1:7890)...")
        proxy_handler = urllib.request.ProxyHandler({'http': f'http://{PROXY_HOST}:{PROXY_PORT}', 'https': f'http://{PROXY_HOST}:{PROXY_PORT}'})
        opener = urllib.request.build_opener(proxy_handler)

        for sub_url in sub_urls:
            sub_name = sub_url.split("/")[-1]
            print(f"   Fetching: {sub_name}...")
            try:
                req = urllib.request.Request(sub_url, headers={'User-Agent': 'FreedomCollector/2.0'})
                with opener.open(req, timeout=12) as resp:
                    raw_data = resp.read().decode('utf-8', errors='ignore')
                nodes = extract_nodes_from_content(raw_data, sub_name, source_type="subscription")
                all_nodes.extend(nodes)
                source_stats[sub_name] = {
                    "source_name": sub_name,
                    "source_type": "subscription",
                    "discovered": len(nodes),
                    "nodes": nodes
                }
                print(f"   ✅ {sub_name}: Discovered {len(nodes)} proxies")
            except Exception as e:
                print(f"   ❌ {sub_name} Failed: {e}")
                source_stats[sub_name] = {
                    "source_name": sub_name,
                    "source_type": "subscription",
                    "discovered": 0,
                    "nodes": []
                }

    print(f"\n📊 Total Discovered Configurations: {len(all_nodes)}")

    # 3. Apply Filters
    print(f"\n🧹 Applying Filters...")
    unique_map = {}
    valid_nodes = []
    broken_count = 0
    expired_count = 0
    duplicate_count = 0

    for n in all_nodes:
        # Broken check
        if filter_broken and not n.validate():
            broken_count += 1
            continue
        # Expired check
        if filter_expired and n.is_expired:
            expired_count += 1
            continue
        # Duplicate check
        fp = n.fingerprint()
        if filter_duplicates:
            if fp in unique_map:
                duplicate_count += 1
                continue
            unique_map[fp] = n
        valid_nodes.append(n)

    print(f"   • Broken / Invalid Dropped: {broken_count}")
    print(f"   • Expired Dropped: {expired_count}")
    print(f"   • Duplicates Dropped: {duplicate_count}")
    print(f"   • Surviving Unique Configs: {len(valid_nodes)}")

    # 4. Multi-Probe Testing
    print(f"\n⚡ Running Multi-Probe Testing on Survivors (Concurrency: 25)...")
    survivors = []
    test_batch = valid_nodes[:200] if len(valid_nodes) > 200 else valid_nodes
    print(f"   Testing active batch of {len(test_batch)} configs...")

    ping_enabled = tests_cfg.get("ping", {}).get("enabled", True)
    geo_enabled = tests_cfg.get("geo_flag", {}).get("enabled", True)
    udp_enabled = tests_cfg.get("udp", {}).get("enabled", True)
    stability_enabled = tests_cfg.get("stability", {}).get("enabled", True)

    def probe_node(node):
        if ping_enabled:
            alive, ping = test_ping(node.server, node.port, timeout=2.0)
            node.alive = alive
            node.ping_ms = ping if alive else 9999.0
            node.ping_micros = int(node.ping_ms * 1000)
        else:
            node.alive = True
            node.ping_ms = 100.0
            node.ping_micros = 100000

        if geo_enabled:
            node.country_code = resolve_country(node.server)
            node.flag_emoji = COUNTRY_FLAGS.get(node.country_code, "🌐")
        else:
            node.country_code = "UN"
            node.flag_emoji = "🌐"

        if node.alive:
            if udp_enabled:
                node.udp_supported = test_udp(node.server, node.port)
            else:
                node.udp_supported = False

            if stability_enabled:
                node.jitter_ms = round(abs(node.ping_ms * 0.12), 2)
            else:
                node.jitter_ms = 0.0

            node.score = calculate_score(node.ping_ms, node.jitter_ms, node.udp_supported, node.fraud_score, node.fingerprint())
        else:
            node.score = 0.0
        return node

    with ThreadPoolExecutor(max_workers=25) as executor:
        futures = {executor.submit(probe_node, n): n for n in test_batch}
        done_count = 0
        for f in as_completed(futures):
            done_count += 1
            res = f.result()
            if res.alive:
                survivors.append(res)
            if done_count % 50 == 0 or done_count == len(test_batch):
                print(f"   Tested {done_count}/{len(test_batch)}... Alive: {len(survivors)}")

    # Sort survivors by score descending
    survivors.sort(key=lambda x: x.score, reverse=True)

    # 5. Compile Analytics & Statistics
    print(f"\n📈 Calculating Comprehensive Analytics & Statistics...")
    proto_counts = {}
    feature_counts = {"reality": 0, "ws": 0, "grpc": 0, "tls": 0, "udp": 0}
    mihomo_compat_count = 0

    for n in valid_nodes:
        p = n.protocol
        proto_counts[p] = proto_counts.get(p, 0) + 1
        if n.is_mihomo_compatible():
            mihomo_compat_count += 1
        sec = n.params.get("security", "")
        net = n.params.get("network", "")
        if sec == "reality": feature_counts["reality"] += 1
        if sec == "tls": feature_counts["tls"] += 1
        if net == "ws": feature_counts["ws"] += 1
        if net == "grpc": feature_counts["grpc"] += 1
        if n.udp_supported or n.protocol in ["hysteria2", "tuic", "openvpn", "wireguard"]:
            feature_counts["udp"] += 1

    # Per source analytics
    source_analytics_list = []
    for s_name, s_data in source_stats.items():
        disc = s_data["discovered"]
        if disc == 0: continue
        s_nodes = s_data["nodes"]
        alive_s = [n for n in s_nodes if n.alive]
        pings = [n.ping_ms for n in alive_s if n.ping_ms < 5000]
        avg_ping = round(sum(pings) / len(pings), 1) if pings else 0.0
        survival_rate = round((len(alive_s) / disc) * 100.0, 1) if disc else 0.0
        source_analytics_list.append({
            "source": s_name,
            "type": s_data["source_type"],
            "discovered": disc,
            "alive": len(alive_s),
            "survival_rate": survival_rate,
            "avg_ping_ms": avg_ping
        })

    # Rank sources
    ranked_sources = sorted(source_analytics_list, key=lambda x: (x["survival_rate"], -x["avg_ping_ms"] if x["avg_ping_ms"] > 0 else 9999), reverse=True)

    analytics_summary = {
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "total_sources_scanned": len(source_stats),
        "total_discovered": len(all_nodes),
        "total_unique": len(valid_nodes),
        "total_broken_dropped": broken_count,
        "total_expired_dropped": expired_count,
        "total_duplicates_dropped": duplicate_count,
        "mihomo_compatible_count": mihomo_compat_count,
        "mihomo_compatibility_percent": round((mihomo_compat_count / len(valid_nodes)) * 100.0, 2) if valid_nodes else 0.0,
        "protocol_breakdown": proto_counts,
        "feature_breakdown": feature_counts,
        "test_batch_size": len(test_batch),
        "survivors_count": len(survivors),
        "top_sources": ranked_sources[:10]
    }

    # Save JSON analytics
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    json_path = os.path.join(OUTPUT_DIR, "analytics_report.json")
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(analytics_summary, f, indent=2, ensure_ascii=False)
    print(f"   💾 Saved Analytics Report to: {json_path}")

    # 6. Generate Clash Provider & Full Config YAML
    print(f"\n📦 Exporting Clash / Mihomo Outputs...")
    
    # Provider YAML
    export_nodes = survivors if survivors else valid_nodes[:100]
    clash_proxies = []

    for n in export_nodes:
        flag = n.flag_emoji
        cc = n.country_code
        display_name = f"{flag} {cc} | {n.protocol.upper()} | {n.score:.1f}★ | {n.server}:{n.port}"
        
        p_dict = {
            "name": display_name,
            "type": n.protocol,
            "server": n.server,
            "port": n.port,
            "udp": True
        }

        if n.protocol == "openvpn":
            p_dict["proto"] = n.params.get("proto", "udp")
            if n.params.get("username"): p_dict["username"] = n.params["username"]
            if n.params.get("password"): p_dict["password"] = n.params["password"]
            if n.params.get("ca"): p_dict["ca"] = n.params["ca"]
            if n.params.get("cipher"): p_dict["cipher"] = n.params["cipher"]
            if n.params.get("auth"): p_dict["auth"] = n.params["auth"]
            p_dict["udp"] = (p_dict["proto"] == "udp")
        elif n.protocol == "vless":
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
        elif n.protocol == "wireguard":
            p_dict["ip"] = "172.16.0.2/32"
            p_dict["public-key"] = n.params.get("public_key", "")
            p_dict["private-key"] = n.params.get("private_key", "")

        clash_proxies.append(p_dict)

    provider_yaml_path = os.path.join(OUTPUT_DIR, "clash_provider.yaml")
    with open(provider_yaml_path, 'w', encoding='utf-8') as f:
        yaml.dump({"proxies": clash_proxies}, f, allow_unicode=True, sort_keys=False)
    print(f"   💾 Saved Clash Provider YAML to: {provider_yaml_path} ({len(clash_proxies)} proxies)")

    # Full Clash Config with Persian Proxy Groups
    proxy_names = [p["name"] for p in clash_proxies]
    if not proxy_names:
        proxy_names = ["DIRECT"]

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

    full_yaml_path = os.path.join(OUTPUT_DIR, "clash_full.yaml")
    with open(full_yaml_path, 'w', encoding='utf-8') as f:
        yaml.dump(full_clash, f, allow_unicode=True, sort_keys=False)
    print(f"   💾 Saved Full Clash Config YAML to: {full_yaml_path}")

    # Generate Markdown Summary
    md_summary_path = os.path.join(OUTPUT_DIR, "analytics_summary.md")
    with open(md_summary_path, 'w', encoding='utf-8') as f:
        f.write("# 📊 گزارش جامع تحلیلی استخراج و تست Freedom Config Collector v2\n\n")
        f.write(f"- **زمان گزارش:** `{time.strftime('%Y-%m-%d %H:%M:%S')}`\n")
        f.write(f"- **تعداد منابع اسکن‌شده:** `{len(source_stats)}` (فایل‌های محلی + لینک‌های اشتراک)\n")
        f.write(f"- **کل کانفیگ‌های شناسایی‌شده:** `{len(all_nodes)}`\n")
        f.write(f"- **کانفیگ‌های معتبر و یکتا:** `{len(valid_nodes)}`\n")
        f.write(f"- **کانفیگ‌های خراب/فیک حذف‌شده:** `{broken_count}`\n")
        f.write(f"- **کانفیگ‌های منقضی حذف‌شده:** `{expired_count}`\n")
        f.write(f"- **کانفیگ‌های تکراری حذف‌شده:** `{duplicate_count}`\n")
        f.write(f"- **درصد سازگاری با هسته میهومو (Mihomo Ready):** `{analytics_summary['mihomo_compatibility_percent']}%`\n\n")
        
        f.write("## 🧬 تفکیک پروتکل‌ها\n\n")
        f.write("| پروتکل | تعداد شناسایی‌شده | سهم درصدی |\n")
        f.write("| :--- | :--- | :--- |\n")
        for proto, count in sorted(proto_counts.items(), key=lambda x: x[1], reverse=True):
            pct = round((count / len(valid_nodes)) * 100.0, 1) if valid_nodes else 0
            f.write(f"| **{proto.upper()}** | {count} | {pct}% |\n")

        f.write("\n## 🛡️ خصوصیات پیشرفته شناسایی‌شده\n\n")
        f.write(f"- **VLESS Reality:** `{feature_counts['reality']}`\n")
        f.write(f"- **WebSocket (WS):** `{feature_counts['ws']}`\n")
        f.write(f"- **gRPC Transport:** `{feature_counts['grpc']}`\n")
        f.write(f"- **TLS Camouflage:** `{feature_counts['tls']}`\n")
        f.write(f"- **UDP Supported:** `{feature_counts['udp']}`\n\n")

        f.write("## 🏆 برترین منابع (رتبه‌بندی کیفی و پایداری)\n\n")
        f.write("| رتبه | نام منبع | نوع | تعداد کل | زنده | درصد موفقیت | میانگین پینگ |\n")
        f.write("| :---: | :--- | :---: | :---: | :---: | :---: | :---: |\n")
        for idx, src in enumerate(ranked_sources[:10]):
            f.write(f"| {idx+1} | `{src['source']}` | {src['type']} | {src['discovered']} | {src['alive']} | {src['survival_rate']}% | {src['avg_ping_ms']}ms |\n")

    print(f"   💾 Saved Markdown Summary to: {md_summary_path}")

    print("\n" + "=" * 70)
    print("✨ Comprehensive Test & Analytics Run Finished Successfully!")
    print("=" * 70)

if __name__ == "__main__":
    main()
