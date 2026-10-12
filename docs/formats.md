# Protocol & Format Parsing Specification (Comprehensive cf_decryptor_bot parity)

<div dir="rtl">

## راهنمای جامع تمام قالب‌ها، فایل‌های رمزنگاری‌شده و پروتکل‌ها

این سند مشخصات فنی کامل تمام قالب‌های فایل، کانتینرهای رمزنگاری‌شده، و ۴۳ پروتکل استخراج‌شده از پروژه مرجع `cf_decryptor_bot` را توضیح می‌دهد.

---

### ۱. کانتینرها و فایل‌های رمزنگاری‌شده (Encrypted File Formats)

نرم‌افزار تمامی فایل‌های تولید شده توسط اپلیکیشن‌های معروف عبور از فیلترینگ را شناسایی و رمزگشایی می‌کند:

| پسوند فایل | نام نرم‌افزار | روش رمزگشایی | خروجی استخراج‌شده |
| :--- | :--- | :--- | :--- |
| **`.ehi`** | **HTTP Injector** | الگوریتم دولایه AES-CBC + XXTEA + XOR با کلید Salt | کانفیگ‌های VLESS، VMess، Trojan و SSH |
| **`.npv` / `.npv4` / `.npvt`** | **NapsternetV** | رمزگشایی ChaCha20-Poly1305 / AES-GCM / WBAES | پروفایل‌های V2Ray، Xray، Trojan و پروکسی |
| **`.dark` / `darktunnel://`** | **Dark Tunnel** | رمزگشایی AES-CFB (کلیدهای DT 192/256) + MessagePack | لینک‌های V2Ray، مشخصات سرور SSH و پروکسی |
| **`.nm` / `nm-*://`** | **NetMod Syna** | رمزگشایی AES-128-ECB با کلیدهای سه‌گانه رسمی | کانفیگ‌های چندگانه VLESS، VMess، SSH و Proxy |
| **`.hat`** | **HA Tunnel Plus** | رمزگشایی AES-128-ECB با کلید مشتق‌شده از SHA-1 | سرورهای HTTP Proxy، SNI و هدرهای Realm Host |
| **`.hc`** | **HTTP Custom** | رمزگشایی ChaCha20 چندبخشی + هدرهای XOR | کانفیگ‌های متصل به سرور و Payload |
| **`.ssc` / `ssc://`** | **SSH Custom** | رمزگشایی چندلایه ChaCha20 بر روی رشته‌های معکوس | یوزرنیم، پسورد، پورت و کلید سرور SSH |
| **`.slip` / `slipnet://`** | **SlipNet** | رمزگشایی AES-CTR با کلیدهای اختصاصی SLIP_KEY | کانفیگ‌های تونل DNS و رمزنگاری‌شده |
| **`.yaml` / `.yml`** | **Clash / Mihomo** | پارس مستقیم ساختار درختی `proxies` | تمام انواع پروتکل‌های کلش با تنظیمات پیشرفته |
| **`.json`** | **Sing-box** | پارس مستقیم آرایه `outbounds` | تمام پروتکل‌های مدرن سینگ‌باکس |
| **`.conf`** | **WireGuard** | استخراج سکشن‌های `[Interface]` و `[Peer]` | کلید خصوصی، آدرس، پورت و بایت‌های Reserved |

---

### ۲. فهرست کامل ۴۳ پروتکل تحت پوشش (Supported Protocols & Schemes)

#### الف) پروتکل‌های اصلی پروکسی (۲۳ پروتکل)
1. `vless://`: پروتکل نسل جدید VLESS با جریان Vision و امنیت Reality.
2. `vmess://`: فرمت رمزنگاری استاندارد V2Ray (Base64 JSON).
3. `trojan://`: پروتکل تروجان شبیه‌ساز ترافیک وب TLS.
4. `ss://`: شادوساکس استاندارد SIP002 و فرمت قدیمی با پلاگین‌های v2ray-plugin و obfs.
5. `ssr://`: شادوساکس آر (ShadowsocksR) با پروتکل‌ها و مبهم‌سازی‌های متنوع.
6. `hysteria2://` / `hy2://`: پروتکل نسل جدید بر بستر UDP QUIC با پورتهای منعطف و obfs سالاماندر.
7. `hysteria://`: نسخه ۱ هیستریا با پهنای باند آپلود و دانلود اختصاصی.
8. `wireguard://` / `wg://`: وایرگارد استاندارد به همراه پارامترهای ضد فیلتر آمینزیا (AmneziaWG).
9. `masque://`: پروتکل مدرن ماسک بر بستر HTTP/3.
10. `tuic://`: پروتکل تویک بر بستر QUIC با کنترل ازدحام BBR.
11. `snell://`: پروتکل اسنل با مبهم‌سازی HTTP و نسخه‌های مختلف (v1 تا v4).
12. `shadowtls://`: پروتکل شادوتلس با شبیه‌سازی موازات TLS.
13. `anytls://`: پروتکل انی‌تلس.
14. `ssh://`: اتصال امن ترمینال و تونل SSH.
15. `socks5://`: پروکسی ساکس ۵ با یا بدون احراز هویت.
16. `socks://`: نام مستعار ساکس.
17. `http://` / `https://`: پروکسی وب استاندارد با پشتیبانی از احراز هویت.
18. `vpn://`: لینک‌های اتصال عمومی VPN.
19. `naive://`: نیو پروکسی (NaiveProxy).
20. `tailcat://`: تونل‌های شبکه خصوصی تیل‌کت.
21. `tg://proxy` / `tg://socks`: پروکسی‌های اختصاصی تلگرام.
22. `ssc://`: لینک‌های اس‌اس‌اچ کاستوم.
23. `darktunnel://`: لینک‌های اختصاصی دارک تونل.

#### ب) پروتکل‌های تونل DNS (۲۰ پروتکل ضد فیلترینگ)
پروتکل‌های عبور از فیلترینگ از طریق بسته‌های DNS که در شرایط اختلال شدید اینترنت کاربرد دارند:
`dns://`، `nm-dns://`، `nm-vless://`، `slipnet-enc://`، `slipnet://`، `slipstream://`، `dnstt://`، `dnst://`، `dnstunnel://`، `vaydns://`، `stormdns://`، `cottendns://`، `masterdns://`، `masterdnsvpn://`، `noizdns://`، `slowdns://`، `ssh-dns://`، `dns-ssh://`، `ssh-over-dns://`، `whitedns://`.

---

### ۳. متغیرها و پارامترهای هر پروتکل

- **VLESS / Trojan:**
  - `uuid`, `password`, `security` (none, tls, reality), `flow` (xtls-rprx-vision)
  - `type` / `network` (tcp, ws, grpc, xhttp, splithttp, h2)
  - `sni`, `fp` (uTLS fingerprint: chrome, firefox, safari, randomized, unsafe), `alpn`
  - پارامترهای Reality: `pbk` (کلید عمومی), `sid` (شناسه کوتاه), `spx` (مسیر SpiderX)
  - هدرها: `path`, `host`, `serviceName`, `headerType`, `seed`
- **Hysteria 2:**
  - `password`, `sni`, `insecure`, `obfs` (salamander), `obfs-password`, `alpn`, `mport`
- **TUIC:**
  - `uuid`, `password`, `congestion_control` (bbr, cubic), `udp_relay_mode` (native, quic), `alpn`
- **WireGuard / AmneziaWG:**
  - `private_key`, `public_key`, `preshared_key`, `address`, `reserved`
  - نویز آمینزیا: `jc`, `jmin`, `jmax`, `s1`, `s2`, `h1`, `h2`, `wnoise`
- **Snell / ShadowTLS / AnyTLS:**
  - `psk`, `obfs`, `version`, `password`, `sni`

</div>
