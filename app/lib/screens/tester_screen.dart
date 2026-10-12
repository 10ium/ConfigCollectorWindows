import 'package:flutter/material.dart';

class TesterScreen extends StatefulWidget {
  const TesterScreen({super.key});

  @override
  State<TesterScreen> createState() => _TesterScreenState();
}

class _TesterScreenState extends State<TesterScreen> {
  // Exact user-specified default states:
  bool _t1Ping = true;
  bool _t2Geo = true;
  bool _t3Gemini = false;
  bool _t4YouTube = false;
  bool _t5Telegram = false;
  bool _t6Custom = false;
  bool _t7SpeedDown = false;
  bool _t8SpeedUp = false;
  bool _t9UDP = true;
  bool _t10Stability = true;
  bool _t11Fraud = true;

  double _maxPing = 1200;
  int _geminiLevel = 1;

  @override
  Widget build(BuildContext context) {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';

    return Scaffold(
      appBar: AppBar(
        title: Text(isPersian ? 'تنظیمات تست‌های ۱۱ گانه' : '11-Stage Test Funnel Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // Banner
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.tune, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isPersian
                          ? 'تمام ۱۱ تست کاملاً اختیاری هستند. می‌توانید هر تست را روشن یا خاموش کنید و پارامترهایش را تغییر دهید.'
                          : 'All 11 tests are fully modular. Toggle each test on or off and customize its parameters.',
                      style: const TextStyle(color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Test 1: Ping
          _buildTestCard(
            title: isPersian ? 'تست ۱: پینگ و تاخیر اولیه (URL Test)' : 'Test 1: Ping & Latency (URL Test)',
            subtitle: isPersian ? 'سنجش زنده بودن و محاسبه تاخیر RTT (میلی‌ثانیه)' : 'Basic connectivity and RTT measurement',
            value: _t1Ping,
            onChanged: (v) => setState(() => _t1Ping = v),
            extra: _t1Ping
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      Text(isPersian ? 'حداکثر تاخیر مجاز: ${_maxPing.toInt()} ms' : 'Max Latency Limit: ${_maxPing.toInt()} ms'),
                      Slider(
                        min: 300,
                        max: 3000,
                        divisions: 27,
                        value: _maxPing,
                        onChanged: (v) => setState(() => _maxPing = v),
                      ),
                    ],
                  )
                : null,
          ),
          const SizedBox(height: 12),

          // Test 2: Geo Exit IP
          _buildTestCard(
            title: isPersian ? 'تست ۲: تشخیص کشور و پرچم (Geo Exit IP)' : 'Test 2: Country Flag & Exit IP',
            subtitle: isPersian ? 'دریافت IP واقعی خروجی سرور و چسباندن پرچم به نام' : 'Query real exit IP and attach ISO flag emoji',
            value: _t2Geo,
            onChanged: (v) => setState(() => _t2Geo = v),
          ),
          const SizedBox(height: 12),

          // Test 3: Gemini Check
          _buildTestCard(
            title: isPersian ? 'تست ۳: تست تحریم جمنای (Google Gemini)' : 'Test 3: Gemini & AI Studio Check',
            subtitle: isPersian ? 'سنجش عبور از سد تحریم منطقه هوش مصنوعی گوگل' : 'Detect Google regional restrictions on AI services',
            value: _t3Gemini,
            onChanged: (v) => setState(() => _t3Gemini = v),
            extra: _t3Gemini
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      Text(isPersian ? 'سطح تست جمنای:' : 'Gemini Test Level:'),
                      RadioListTile<int>(
                        title: Text(isPersian ? 'سطح ۱: اتصال مستقیم به دامنه (سریع و سبک)' : 'Level 1: Domain connect (Fast)'),
                        value: 1,
                        groupValue: _geminiLevel,
                        onChanged: (v) => setState(() => _geminiLevel = v!),
                      ),
                      RadioListTile<int>(
                        title: Text(isPersian ? 'سطح ۲: مرورگر لاگین‌شده (فوق دقیق - ویندوز)' : 'Level 2: Logged-in Browser (Windows)'),
                        value: 2,
                        groupValue: _geminiLevel,
                        onChanged: (v) => setState(() => _geminiLevel = v!),
                      ),
                      RadioListTile<int>(
                        title: Text(isPersian ? 'سطح ۳: تست با کلید API کاربر' : 'Level 3: User API Key prompt'),
                        value: 3,
                        groupValue: _geminiLevel,
                        onChanged: (v) => setState(() => _geminiLevel = v!),
                      ),
                    ],
                  )
                : null,
          ),
          const SizedBox(height: 12),

          // Tests 4, 5, 6: Websites
          _buildTestCard(
            title: isPersian ? 'تست ۴: باز شدن یوتیوب (YouTube)' : 'Test 4: YouTube Accessibility',
            subtitle: isPersian ? 'بررسی عدم مسدودی استریم ویدیو' : 'Check video playback endpoints',
            value: _t4YouTube,
            onChanged: (v) => setState(() => _t4YouTube = v),
          ),
          const SizedBox(height: 12),
          _buildTestCard(
            title: isPersian ? 'تست ۵: باز شدن تلگرام (Telegram)' : 'Test 5: Telegram Accessibility',
            subtitle: isPersian ? 'بررسی اتصال به سرورهای تلگرام' : 'Check Telegram API & MTProto endpoints',
            value: _t5Telegram,
            onChanged: (v) => setState(() => _t5Telegram = v),
          ),
          const SizedBox(height: 12),
          _buildTestCard(
            title: isPersian ? 'تست ۶: سایت‌های دلخواه (Custom Targets)' : 'Test 6: Custom Target Websites',
            subtitle: isPersian ? 'امکان وارد کردن هر سایت دلخواه توسط کاربر' : 'Custom URLs with response code criteria',
            value: _t6Custom,
            onChanged: (v) => setState(() => _t6Custom = v),
          ),
          const SizedBox(height: 12),

          // Tests 7, 8: Speeds
          _buildTestCard(
            title: isPersian ? 'تست ۷: سرعت دانلود واقعی (Time-Boxed Speed)' : 'Test 7: Download Speed (5s)',
            subtitle: isPersian ? 'دانلود ۵ ثانیه‌ای جهت محاسبه دقیق سرعت بدون مصرف زیاد اینترنت' : '5-second download test without heavy data usage',
            value: _t7SpeedDown,
            onChanged: (v) => setState(() => _t7SpeedDown = v),
          ),
          const SizedBox(height: 12),
          _buildTestCard(
            title: isPersian ? 'تست ۸: سرعت آپلود (Upload Speed)' : 'Test 8: Upload Speed',
            subtitle: isPersian ? 'ارسال بسته تستی جهت سنجش پهنای باند آپلود' : 'Small payload upload test',
            value: _t8SpeedUp,
            onChanged: (v) => setState(() => _t8SpeedUp = v),
          ),
          const SizedBox(height: 12),

          // Test 9: UDP
          _buildTestCard(
            title: isPersian ? 'تست ۹: پشتیبانی از UDP و گیمینگ (UDP Test)' : 'Test 9: UDP Protocol (Gaming/Voice)',
            subtitle: isPersian ? 'بررسی پکت‌های UDP (ضروری برای تماس صوتی و Hysteria 2)' : 'Verify UDP packet forwarding',
            value: _t9UDP,
            onChanged: (v) => setState(() => _t9UDP = v),
          ),
          const SizedBox(height: 12),

          // Test 10: Stability
          _buildTestCard(
            title: isPersian ? 'تست ۱۰: پایداری و پکت‌لاس (Stability & Jitter)' : 'Test 10: Stability & Packet Loss',
            subtitle: isPersian ? 'ارسال ۴ پینگ متوالی جهت محاسبه نوسان و قطعی' : 'Send 4 consecutive pings to compute packet loss & jitter',
            value: _t10Stability,
            onChanged: (v) => setState(() => _t10Stability = v),
          ),
          const SizedBox(height: 12),

          // Test 11: Fraud
          _buildTestCard(
            title: isPersian ? 'تست ۱۱: تمیزی آی‌پی (Fraud Score)' : 'Test 11: IP Cleanliness & Fraud Score',
            subtitle: isPersian ? 'استعلام رایگان ریسک آی‌پی سرور (دیتاسنتری یا خانگی)' : 'Detect datacenter abuse score and ISP trust',
            value: _t11Fraud,
            onChanged: (v) => setState(() => _t11Fraud = v),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Widget? extra,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          children: [
            SwitchListTile(
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(subtitle),
              value: value,
              onChanged: onChanged,
            ),
            if (extra != null) extra,
          ],
        ),
      ),
    );
  }
}
