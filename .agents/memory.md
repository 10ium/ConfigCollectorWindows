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


