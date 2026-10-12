# Freedom Config Collector v2 - Agent Rules & Architecture Guidelines

## Product Definition
Cross-platform proxy config collector, validator, multi-stage tester, and Clash/Mihomo converter for Windows 10+ (x64) and Android 7+ (arm64-v8a, armeabi-v7a). Designed for ultra-lightweight execution on low-spec hardware (4 GB DDR3 RAM target, idle RAM < 150 MB).

## Core Architecture
- **Monorepo Layout**:
  - `engine/` (Go 1.22+): Contains 100% of the collection, parsing, deduplication, testing, scoring, and Clash YAML generation logic.
  - `app/` (Flutter): Pure UI presentation layer consuming engine events and sending user commands.
  - `docs/`: Technical specifications, format decoders, and scoring rules.
- **IPC Protocol**:
  - `engine/ffi/`: C-shared library for embedded in-app communication on Windows and Android.
  - `engine/cmd/cserver/`: Embedded localhost HTTP daemon for headless and automated verification.
- **Proxy Core Interface**:
  - All test probes interact exclusively with `core.ProxyCore` (`Name`, `Supports`, `Dial`).
  - Mihomo is the primary engine (`engine/internal/core/mihomo`).
  - Xray core is prepared as a pluggable adapter (`engine/internal/core/xray`).

## Config Sources (Fully Independent Toggles)
- `source_telegram_enabled`: Public telegram web scraper (`t.me/s/<channel>`), pagination, lookback days.
- `source_subscriptions_enabled`: Multi-layer Base64, plain text, Clash YAML, Sing-box JSON subscription fetcher.
- `source_local_folder_enabled`: Streaming scanner for `.txt` files in a local directory.
- The user can enable any individual source or any combination of sources.

## Default Test Configuration
- **Test 1 (Ping / URL Test)**: `true`
- **Test 2 (Country Flag & Exit Geo IP)**: `true`
- **Test 3 (Google Gemini & AI Studio)**: `false`
- **Test 4 (YouTube Check)**: `false`
- **Test 5 (Telegram Check)**: `false`
- **Test 6 (Custom Target Sites)**: `false`
- **Test 7 (Time-Boxed Download Speed)**: `false`
- **Test 8 (Upload Speed)**: `false`
- **Test 9 (UDP Protocol & Gaming/Voice)**: `true`
- **Test 10 (Stability / Jitter / Packet Loss)**: `true`
- **Test 11 (IP Cleanliness & Fraud Score)**: `true`

## Smart Scoring Specification
- Continuous floating-point score (0.0000 - 100.0000).
- Ping non-linear sigmoid weight (35%), Stability/Jitter/Loss weight (30%), UDP weight (15%), Cleanliness weight (20%).
- High-precision tie-breaker formula based on micro-RTT delta and fingerprint CRC32 ensures virtually zero identical rank collisions.

## Persian (RTL) & UI Rules
- Always use `EdgeInsetsDirectional`, `AlignmentDirectional`, `TextAlign.start`.
- Embed Vazirmatn font (Regular, Medium, Bold).
- IPs, ports, URLs, and protocol codes are always wrapped as LTR islands.
- Material 3 theme with light/dark dynamic palette.
