# Freedom Config Collector v2 - Experiential Project Memory

## Project Overview
- **Name**: Freedom Config Collector v2
- **Goal**: Cross-platform (Windows & Android) proxy config collector, validator, multi-stage tester, and Clash/Mihomo converter.
- **Hardware Target**: Optimized for low-end hardware (e.g. 4GB DDR3 RAM, dual-core CPUs). Idle RAM target < 150MB total.
- **Technology Stack**:
  - **Engine**: Go 1.22+ (`engine/`) with Mihomo core integrated via `core.ProxyCore` interface, Xray core stubbed for future expansion.
  - **UI**: Flutter with Material 3 (`app/`), fully bilingual (Persian RTL & English LTR) with bundled Vazirmatn font.
  - **IPC**: C-shared FFI (`engine/ffi/`) for embedded desktop/mobile UI + local HTTP server (`engine/cmd/cserver/`) for headless.
  - **CI/CD**: GitHub Actions building Windows `.exe`/`.zip` and Android `.apk`.

## User Preferences & Default Configurations
- **Multi-Source Selection**: Completely independent toggles for Telegram channels, Subscription links, and Local folder. Any combination can be selected.
- **Default Test Toggles**:
  - Test 1 (Ping / Latency / URL Test): **ENABLED**
  - Test 2 (Exit IP & Country Flag Detection): **ENABLED**
  - Test 3 (Gemini & AI Studio Check): **DISABLED**
  - Test 4 (YouTube Check): **DISABLED**
  - Test 5 (Telegram Check): **DISABLED**
  - Test 6 (Custom Site Checks): **DISABLED**
  - Test 7 (Time-boxed Download Speed Test): **DISABLED**
  - Test 8 (Upload Speed Test): **DISABLED**
  - Test 9 (UDP Protocol & Gaming/Voice Test): **ENABLED**
  - Test 10 (Stability / Jitter / Packet Loss): **ENABLED**
  - Test 11 (IP Cleanliness & Fraud Score): **ENABLED**
- **Smart Scoring Engine**:
  - Continuous floating-point composite scoring (0.0000 - 100.0000) based on ping curve, jitter, packet loss, UDP support, and IP fraud score.
  - Includes a deterministic micro-resolution tie-breaker so the probability of two configs receiving identical scores is practically zero.

## Reference Repositories Mappings
1. `reference/ConfigCollectorWindows`:
   - Rust predecessor. Preserved logic: Telegram pagination, deduplication rules, Clash 32 Persian proxy groups.
   - Fixed architectural flaws: Replaced single enum source mode with multi-select toggles; replaced external `xray-knife.exe` process spawns with in-engine Go execution.
2. `reference/free-config/worker/cf_decryptor_bot` & `great_mihomo_converter`:
   - Config decoding algorithms, multi-layer base64 unwrapping, invalid unicode sanitization (`[\x00-\x1F\x7F-\x9F\u200B-\u200D\uFEFF\uFFFD]`), and Clash YAML generation with 32 groups.
3. `reference/Gemini-Config-Checker`:
   - Chrome DevTools Protocol automation for Google AI Studio & Gemini web checks, region wall detection (`available-region`, `"currently supported in your country"`).

## Comprehensive Protocol & Decryptor Parity (from cf_decryptor_bot)
- **Supported Encrypted Containers**:
  - HTTP Injector (`.ehi`): multi-layer AES-CBC + XXTEA + XOR salt.
  - NapsternetV (`.npv`, `.npv4`, `.npvt`, `.npvs`): ChaCha20-Poly1305 / AES-GCM / WBAES.
  - Dark Tunnel (`.dark`, `darktunnel://`): AES-CFB + msgpack unpacker.
  - NetMod Syna (`.nm`, `nm-*://`): AES-128-ECB with 3 official keys.
  - HA Tunnel Plus (`.hat`): AES-128-ECB with SHA-1 derived key.
  - HTTP Custom (`.hc`): ChaCha20 + XOR header decryptor.
  - SSH Custom (`.ssc`, `ssc://`): ChaCha20 on reversed hex payload.
  - SlipNet (`.slip`, `slipnet://`, `slipnet-enc://`): AES-CTR with SLIP_KEY.
  - Structured configs: Clash YAML (`proxies:`), Sing-box JSON (`outbounds:`), WireGuard (`.conf`).
- **All 43 Protocol Schemes Supported**:
  - `vless`, `vmess`, `trojan`, `ss`, `ssr`, `hysteria2`, `hy2`, `hysteria`, `wireguard`, `wg`, `masque`, `tuic`, `snell`, `shadowtls`, `anytls`, `ssh`, `socks5`, `socks`, `http`, `https`, `vpn`, `naive`, `tailcat`, `openvpn`.
  - 20 DNS Tunnels: `dns`, `nm-dns`, `nm-vless`, `slipnet-enc`, `slipnet`, `slipstream`, `dnstt`, `dnst`, `dnstunnel`, `vaydns`, `stormdns`, `cottendns`, `masterdns`, `masterdnsvpn`, `noizdns`, `slowdns`, `ssh-dns`, `dns-ssh`, `ssh-over-dns`, `whitedns`.

## OpenVPN & Native Mihomo Integration
- Added native parser for `.ovpn` files (`engine/internal/parse/openvpn.go`), extracting server, port, proto (udp/tcp), credentials (`auth-user-pass`), certificates/keys (`<ca>`, `<cert>`, `<key>`, `<tls-auth>`, `<tls-crypt>`, `<tls-crypt-v2>`), `cipher`, and `auth`.
- Integrated OpenVPN into Clash/Mihomo export (`engine/internal/export/clash.go`), producing valid `type: openvpn` blocks with full Mihomo spec compatibility.

## Filter & De-duplication Parity (from cf_decryptor_bot)
- Configured master filters in `config/settings.json` and engine:
  - `filter_duplicates`: deterministic fingerprint hashing (protocol + server + port + credentials + path).
  - `filter_broken`: validation of server IP/hostname, valid port (1-65535), and required credentials.
  - `filter_expired`: filtering of nodes matching `configExpiryTimestamp` or past expiry dates.
  - `limit_max_configs` and `allowed_protocols` whitelisting.

## Real Benchmark Results on User Test Suite
- Tested against 838 local files in `G:\Ai project\10Dream\decryptor\file for test` + remote subscriptions:
  - **Total Discovered**: 65,995 proxy configurations.
  - **Dropped**: 50,410 duplicates, 33 broken/invalid, **59 expired configs dropped**.
  - **Surviving Unique Configs**: 15,493 configs.
  - **OpenVPN Extracted**: 114 configs.
  - **Mihomo Compatibility**: 100.0%.

## Standalone Desktop Window & Silent Launcher (Zero CMD)
- **Microsoft Edge App Mode**: Uses `msedge.exe --app="http://127.0.0.1:12059" --window-size=1250,850` to open an isolated desktop window with zero browser tabs, zero URL bar, and custom native window controls.
- **Silent Launching**: Created `FreedomConfigCollector.vbs` utilizing `pythonw.exe` and `WScript.Shell` window style `0` (hidden), completely eliminating the black terminal window and preventing Persian console encoding corruption (`cp1256`).
- **Unified Site Test**: Merged individual website probes into a single «تست دسترسی به وب‌سایت‌های دلخواه» with user-customizable target URLs list.
- **Source Management**: Added full interactive source mode switcher (`all`, `folder`, `subscriptions`, `telegram`), Telegram channel list editor, and subscription URL editor.
- **Expiry Detection Fix**: Integrated `checkExpiration(decResult)` from `cf_decryptor_bot` directly into `tools/decryptor_bridge.mjs`, correctly identifying and filtering the 55 expired container files.

## V2 Advanced Feature Expansion & Automation
- **Deep Gemini AI Probe (Inspired by Gemini-Config-Checker)**:
  - Level 1: Network reachability probe (`generativelanguage.googleapis.com`). HTTP 400 with dummy key proves server is reachable.
  - Level 2: Web Application & Regional Block Detection (`gemini.google.com/app` and `aistudio.google.com/prompts/new_chat`). Detects `"available-region"`, `"currently supported in your country"`, or 403/451 status.
  - Level 3: Live API Key generation call (`gemini-2.5-flash:generateContent`).
- **Multi-Format Structured Exporter**:
  - Organized outputs into dedicated folders: `output/clash/` (Proxy Provider YAML & Full 32-Group Config), `output/singbox/` (Outbounds JSON & Standalone config), `output/xray/` (Raw URI links & Base64 Subscription).
  - Maintained root aliases in `output/` for legacy and 1-click download compatibility.
- **Output Customization & Per-Protocol Caps**:
  - Configurable minimum score (`min_score`), Gemini-only toggle (`only_gemini_passed`), per-protocol maximum caps (`per_protocol_limits`: VLESS, VMess, Trojan, Shadowsocks, Hysteria2, TUIC, OpenVPN, WireGuard).
  - Sent History deduplication memory (`config/sent_history.json`) prevents reposting previously discovered configs across cycles.
- **Telegram Bot Auto-Sender**:
  - Direct integration with Telegram Bot API (`sendDocument` with multipart boundary and `sendMessage` with HTML formatting).
  - Supports automatic channel dispatching after test completion, with a live token test endpoint (`/api/test_telegram`).
- **Multi-Round Testing (Interval Testing with Cooldown)**:
  - Runs tests across rounds (`rounds_count`) with a configurable resting cooldown (`interval_between_rounds_sec`) to avoid dropping healthy configs during momentary network fluctuations.
  - Proxy qualifies if it passes `>= min_passed_rounds`.
- **Windows System Tray & Background Execution**:
  - Native Windows Forms `NotifyIcon` helper script (`tools/tray_helper.ps1`) runs without third-party python modules like `pystray`.
  - Provides quick tray context menu: Open Dashboard, Run Now, Exit.

## v2.2.0 Refinements & Discoveries
- **Protocol Clarifications**:
  - `Rematch`: Mihomo rule-provider match condition, not an outbound protocol. Removed from protocol categories.
  - `ShadowTLS` vs `ShadowQUIC`: Mihomo natively supports both `shadow-tls` (v2/v3) and `shadowquic`. Both retained with explicit distinction.
  - `WhiteDNS SOAR`: Protocol `soar://` designated as `وایت دی‌ان‌اس SOAR (soar://)`.
  - `DoH`: Removed from tunneling protocols catalog as it is ordinary DNS resolution over HTTPS.
- **Multi-Folder Auto-Export Architecture**:
  - Automatic export upon scan completion writes directly to:
    - `output/clash/`: `proxy_provider.yaml` & `clash_full.yaml`
    - `output/singbox/`: `singbox_outbounds.json` & `singbox_full.json`
    - `output/xray/`: `raw_links.txt` & `sub_base64.txt`
    - `output/telegram/`: `telegram_proxies.txt`
    - `output/dns_tunnels/`: `white_dns_soar.txt` & `dns_tunnels.txt`
    - `output/summary.json` (metadata)
  - Removed manual generation button from ExportScreen; replaced with direct folder explorer shortcut.
- **Precision Stepped Sliders**:
  - Subscription timeout slider configured with `divisions: 55` (`min: 5, max: 60`), achieving exact 1-second increments with `[-]` and `[+]` stepping buttons and debounced auto-save.


## 14. V2.0.0 Comprehensive Refinements & User Experience Upgrades (Build 39334018600)
- **Multi-Stage Progress Tracker**:
  - Implemented 5 clear sequential stages (Stage 1: Collection, Stage 2: Deduplication, Stage 3: Ping, Stage 4: Advanced Testing, Stage 5: Final Export).
  - Displays dynamic percentages, item counters (`checked / total`), and estimated time remaining (ETA).
- **Hyper-Precise Protocol-Aware Deduplication Fingerprinting**:
  - Replaced naive endpoint hashing with a 30-field deterministic signature incorporating protocol, host, port, SNI, path, network transport, security layer, flow, reality PBK/ShortID/SpiderX, cipher method, Obfs, WireGuard keys, and slowDNS domain.
  - Guarantees nodes sharing identical IPs/ports but distinct routes or SNIs are never falsely dropped.
- **Flexible Multi-Source Selection**:
  - Decoupled source choices into 3 independent toggle chips allowing any simultaneous combination (Telegram, Subscriptions, Local folder).
- **Source Delay Separation**:
  - Split Telegram channel delay (100–2000 ms) and Subscription network timeout (5–60 s) into independent controls.
- **Automated GitHub Raw Conversion**:
  - Automatically rewrites `github.com/.../blob/...` URLs into `raw.githubusercontent.com/...` both in the Go engine and in the Flutter UI.
- **Proxy Health & Latency Checker**:
  - Dedicated network diagnostic in Settings testing Google (`generate_204`) and Telegram (`web.telegram.org`) latency via local proxy (`127.0.0.1:7890`) with live millisecond indicators.
- **Testing Presets**:
  - Added comprehensive HTTP & HTTPS ping URL presets + custom URL input.
  - Added speed test presets (5MB, 10MB, 25MB, 50MB across Cloudflare, Hetzner, OVH) + custom file URL input.
- **All 30 Protocols Supported in Reorderable Export Priority**:
  - Full drag-and-drop protocol sorting with sequential quota filling.
  - Cap `0` explicitly excludes a protocol from export files.
  - Global maximum cap defaults to 600 with an unlimited toggle option.
- **Telegram Dispatcher Custom Formatting**:
  - Added 4 message formatting modes: `no_text`, `header_only`, `footer_only`, and `both` (header + footer) with live custom input fields.
- **Standalone Binary Packaging**:
  - Single-file standalone executable (`FreedomConfigCollector.exe`, 8.3MB) compiled with PyInstaller 6.22, embedding modern multi-resolution icons (`app_icon.ico`) and hidden imports.

## 15. V2.1.0 Protocol Specialization, Core Manager & Real Execution Upgrades
- **Strict Protocol Category Isolation**:
  - Segregated protocol monitoring and export into 3 distinct categories on dashboard and engine:
    1. **Mihomo Native Protocols** (26 protocols: VLESS, VMess, Trojan, SS, SSR, Hy2, Hy1, TUIC, WireGuard, AmneziaWG, MASQUE, ShadowTLS, Snell, AnyTLS, Juicity, ShadowQUIC, TrustTunnel, Sudoku, Mieru, EasyTier, Tailscale, ZeroTier, Rematch, OpenVPN, SOCKS5, HTTP).
    2. **DNS & Tunnel Protocols** (14 protocols: WhiteDNS SOAR `soar://`, CottenDNS `cottendns://`, WhiteDNS Profile `whitedns://`, DNSTT, SlipNet, NetMod DNS `nm-dns`, NetMod VLESS DNS `nm-vless`, VayDNS, StormDNS, MasterDNS, NoizDNS, SSH over DNS, DoH, Raw DNS `dns://`).
    3. **Telegram Dedicated Proxies** (MTProto `tg://proxy`, SOCKS5 `tg://socks`, Web Proxy `t.me/proxy`, HTTP/SOCKS).
- **Auto-Save & Reset Defaults Engine**:
  - Added debounced auto-save (300ms) on every single UI parameter and slider adjustment; removed manual save requirements.
  - Added a one-click "بازنشانی به پیش‌فرض" (Reset to Defaults) button in AppBar to restore factory defaults.
- **Micro-Stepped Fine-Tuning Sliders (Step = 1)**:
  - All test sliders configured with single-unit divisions and manual `[-]` / `[+]` stepping buttons.
  - Concurrency slider capped safely with an adaptive warning banner triggering above 200 concurrent tasks.
- **Robust CDP Google Authentication**:
  - Implemented real Chrome DevTools Protocol polling against port 9222 and cookie verification (`SAPISID` and `SID`).
  - Completely prevents premature/false login states if the browser window is closed before authentication completes.
- **Automated Results Export**:
  - Automatic export on scan completion directly to `output/` (`mihomo_proxies.yaml`, `raw_configs.txt`, `summary.json`).
  - Direct 1-click button to open `output/` in Windows Explorer (`Process.start('explorer.exe', ['output'])`).
- **Mihomo Core Lifecycle Manager**:
  - Settings screen card detects local binary version via `bin/mihomo.exe -v`.
  - Queries `MetaCubeX/mihomo` GitHub releases API, compares versions, and downloads/installs compatible architecture binaries with live progress reporting.
- **Live Terminal Log Viewer**:
  - Created `LogsScreen` providing color-coded real-time event logs, source tags, severity filters (`all`, `success`, `error`), live text search, auto-scrolling toggle, and clipboard copying.
