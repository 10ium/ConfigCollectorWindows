# Protocol & Format Parsing Specification (from cf_decryptor_bot)

<div dir="rtl">

## راهنمای جامع پارس، رمزگشایی و تبدیل پروتکل‌ها (برگرفته از cf_decryptor_bot)

این مستند تمام قوانین، پارامترهای فنی و نحوه تبدیل پروتکل‌های مختلف به فرمت استاندارد Clash/Mihomo را مشخص می‌کند.

---

### ۱. پاکسازی متن و نویسه‌های مخفی
پیش از هرگونه پردازش، کاراکترهای نامرئی، کنترلی و مخرب که باعث Mojibake یا خطای فرمت می‌شوند، با عبارات باقاعده زیر حذف می‌شوند:
- Regex: `[\x00-\x1F\x7F-\x9F\u200B-\u200D\uFEFF\uFFFD]`
- کدهای HTML با انکودینگ کاراکتر (مانند `&amp;` به `&`، `&#35;` به `#`) دیکد می‌شوند.

---

### ۲. پروتکل‌های پشتیبانی‌شده و پارامترهای هرکدام

#### ۱. پروتکل VLESS (`vless://`)
- **ساختار لینک**: `vless://{uuid}@{server}:{port}?{params}#{name}`
- **پارامترهای کلیدی**:
  - `type` یا `network`: `tcp`، `ws`، `grpc`، `xhttp`، `splithttp`، `http`
  - `security`: `none`، `tls`، `reality`
  - `flow`: `xtls-rprx-vision`
  - `sni` یا `peer`: نام دامنه سرور برای TLS
  - `fp`: فینگرپرینت uTLS (`chrome`، `firefox`، `safari`، `randomized`، `unsafe`)
  - **پارامترهای اختصاصی Reality**:
    - `pbk`: کلید عمومی (Public Key)
    - `sid`: شناسه کوتاه (Short ID)
    - `spx`: مسیر SpiderX
  - **پارامترهای انتقال (Transport)**:
    - WebSocket: `path`، `host`
    - gRPC: `serviceName`
    - xHTTP / SplitHTTP: `path`، `host`، `mode`
    - TCP HTTP: `headerType=http`، `path`، `host`

#### ۲. پروتکل VMess (`vmess://`)
- **ساختار لینک**: `vmess://{base64(JSON)}`
- **فیلدهای جیسون**:
  - `v`: نسخه پروتکل
  - `ps`: نام کانفیگ
  - `add`: آدرس سرور
  - `port`: پورت اتصال
  - `id`: شناسه کاربر (UUID)
  - `aid`: آلتر آی‌دی (AlterID - پیش‌فرض 0)
  - `scy`: متد رمزنگاری (`auto`، `aes-128-gcm`، `chacha20-poly1305`، `none`)
  - `net`: نوع شبکه (`tcp`، `ws`، `grpc`، `h2`)
  - `type`: نوع هدر (مثلاً `none` یا `http`)
  - `host` و `path`: برای انتقال وب‌سوکت و HTTP
  - `tls`: فعال یا غیرفعال بودن TLS
  - `sni` و `alpn`: نام سرور و پروتکل‌های لایه کاربرد
  - `fp`: فینگرپرینت TLS

#### ۳. پروتکل Trojan (`trojan://`)
- **ساختار لینک**: `trojan://{password}@{server}:{port}?{params}#{name}`
- **پارامترها**:
  - `sni` یا `peer`: دامنه SNI
  - `type`: نوع انتقال (`tcp`، `ws`، `grpc`)
  - `security`: `tls` یا `reality`
  - `alpn`، `fp`، `path`، `host`، `serviceName`

#### ۴. پروتکل Hysteria 2 / hy2 (`hysteria2://` یا `hy2://`)
- **ساختار لینک**: `hysteria2://{password}@{server}:{port}?{params}#{name}`
- **پارامترها**:
  - `sni`: دامنه سرور
  - `insecure`: نادیده گرفتن اعتبار گواهی (`1` یا `true`)
  - `obfs`: نوع مبهم‌سازی (`salamander` یا `none`)
  - `obfs-password`: رمز مبهم‌سازی
  - `alpn`: پیش‌فرض `["h3"]`

#### ۵. پروتکل TUIC (`tuic://`)
- **ساختار لینک**: `tuic://{uuid}:{password}@{server}:{port}?{params}#{name}`
- **پارامترها**:
  - `congestion_control`: کنترل ازدحام (`bbr`، `cubic`، `new_reno`)
  - `udp_relay_mode`: حالت ارسال UDP (`native` یا `quic`)
  - `sni`، `alpn`، `disable_sni`

#### ۶. پروتکل Shadowsocks (`ss://`)
- **فرمت‌های مختلف**:
  - استاندارد SIP002: `ss://{base64(method:password)}@{server}:{port}#{name}`
  - فرمت قدیمی: `ss://{base64(method:password@server:port)}#{name}`
  - پلاگین‌ها: `plugin=v2ray-plugin;mode=websocket;host=...;path=...` یا `obfs-local`

#### ۷. پروتکل WireGuard / AmneziaWG (`wireguard://` یا `wg://`)
- **پارامترها**:
  - `privateKey`، `publicKey`، `presharedKey`
  - `reserved`: بایت‌های رزرو شده (برای دور زدن محدودیت‌های همراه اول/ایرانسل)
  - `mtu`، `localAddress`
  - پارامترهای نویز آمینزیا: `jc`، `jmin`، `jmax`، `s1`، `s2`، `h1`، `h2`، `wnoise`

#### ۸. پروتکل پروکسی تلگرام (`tg://proxy`، `tg://socks`، `https://t.me/proxy`)
- استخراج مستقیم سرور، پورت، یوزرنیم و پسورد به عنوان پروکسی استاندارد SOCKS5.

---

### ۳. امضای فنی یکتا برای حذف تکراری‌ها (Deduplication Fingerprint)

برای اینکه کانفیگ‌های یکسان که فقط اسمشان در کانال‌های مختلف عوض شده دوباره تست نشوند، یک شناسه یکتا ساخته می‌شود:

$$\text{Fingerprint} = \text{MD5}(\text{Protocol} + \text{ServerIP} + \text{Port} + \text{UUID/Password} + \text{Network} + \text{SNI} + \text{Path})$$

اگر فینگرپرینت قبلاً در این دوره دیده شده باشد، کانفیگ فوراً بدون ارسال درخواست به شبکه نادیده گرفته می‌شود.

</div>
