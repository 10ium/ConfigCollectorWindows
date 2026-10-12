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
