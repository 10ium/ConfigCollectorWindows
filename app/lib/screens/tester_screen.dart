import 'package:flutter/material.dart';
import '../services/config_service.dart';

class TesterScreen extends StatefulWidget {
  const TesterScreen({super.key});

  @override
  State<TesterScreen> createState() => _TesterScreenState();
}

class _TesterScreenState extends State<TesterScreen> {
  final ConfigService _config = ConfigService();

  // Test toggles
  bool _t1Ping = true;
  bool _t2Geo = true;
  bool _t3Gemini = true;
  bool _t4YouTube = false;
  bool _t5Telegram = false;
  bool _t6SpeedDown = false;
  bool _t7UDP = true;
  bool _t8Stability = true;
  bool _t9Fraud = true;

  // Custom Test URLs
  String _pingUrl = 'http://www.gstatic.com/generate_204';
  late TextEditingController _customPingCtrl;
  String _speedUrl = 'https://speed.cloudflare.com/__down?bytes=5000000';
  late TextEditingController _customSpeedCtrl;

  // Concurrency & Limits
  double _maxPingMs = 1500;
  int _concurrency = 30;

  // Smart Timeout
  late TextEditingController _timeoutCtrl;
  String _timeoutUnit = 'ثانیه';

  // Multi-round testing
  int _roundsCount = 1;
  int _intervalBetweenRoundsSec = 15;

  // Gemini 3-level settings
  int _geminiLevel = 2;
  late TextEditingController _geminiApiKeyCtrl;

  @override
  void initState() {
    super.initState();
    _customPingCtrl = TextEditingController(text: _pingUrl);
    _customSpeedCtrl = TextEditingController(text: _speedUrl);
    _timeoutCtrl = TextEditingController(text: '3');
    _geminiApiKeyCtrl = TextEditingController();
    _loadFromConfig();
  }

  void _loadFromConfig() {
    final tests = _config.settings['tests'] ?? {};
    final ping = tests['ping'] ?? {};
    final gemini = tests['gemini'] ?? {};
    final speed = tests['download_speed'] ?? {};
    final rounds = _config.settings['testing_rounds'] ?? {};

    _t1Ping = ping['enabled'] ?? true;
    _maxPingMs = (ping['max_latency_ms'] ?? 1500).toDouble();
    _concurrency = ping['concurrency'] ?? 30;
    _pingUrl = ping['test_url'] ?? 'http://www.gstatic.com/generate_204';
    _customPingCtrl.text = _pingUrl;
    _timeoutCtrl.text = '${ping['timeout_val'] ?? 3}';

    _t3Gemini = gemini['enabled'] ?? true;
    _geminiLevel = gemini['level'] ?? 2;
    _geminiApiKeyCtrl.text = gemini['api_key'] ?? '';

    _t6SpeedDown = speed['enabled'] ?? false;
    _speedUrl = speed['test_url'] ?? 'https://speed.cloudflare.com/__down?bytes=5000000';
    _customSpeedCtrl.text = _speedUrl;

    _roundsCount = rounds['rounds_count'] ?? 1;
    _intervalBetweenRoundsSec = rounds['interval_between_rounds_sec'] ?? 15;

    _t2Geo = (tests['geo_flag'] ?? {})['enabled'] ?? true;
    _t7UDP = (tests['udp'] ?? {})['enabled'] ?? true;
    _t8Stability = (tests['stability'] ?? {})['enabled'] ?? true;
    _t9Fraud = (tests['fraud_score'] ?? {})['enabled'] ?? true;
  }

  @override
  void dispose() {
    _customPingCtrl.dispose();
    _customSpeedCtrl.dispose();
    _timeoutCtrl.dispose();
    _geminiApiKeyCtrl.dispose();
    super.dispose();
  }

  void _saveSettings() {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';

    // Parse smart timeout
    final smartSeconds = ConfigService.parseSmartTime(_timeoutCtrl.text, _timeoutUnit);

    _config.updateNestedSetting('tests', 'ping', 'enabled', _t1Ping);
    _config.updateNestedSetting('tests', 'ping', 'test_url', _customPingCtrl.text.trim());
    _config.updateNestedSetting('tests', 'ping', 'max_latency_ms', _maxPingMs.toInt());
    _config.updateNestedSetting('tests', 'ping', 'concurrency', _concurrency);
    _config.updateNestedSetting('tests', 'ping', 'timeout_val', smartSeconds > 0 ? smartSeconds : 3);
    _config.updateNestedSetting('tests', 'ping', 'timeout_unit', 's');

    _config.updateNestedSetting('tests', 'gemini', 'enabled', _t3Gemini);
    _config.updateNestedSetting('tests', 'gemini', 'level', _geminiLevel);
    _config.updateNestedSetting('tests', 'gemini', 'api_key', _geminiApiKeyCtrl.text.trim());

    _config.updateNestedSetting('tests', 'download_speed', 'enabled', _t6SpeedDown);
    _config.updateNestedSetting('tests', 'download_speed', 'test_url', _customSpeedCtrl.text.trim());

    _config.updateNestedSetting('testing_rounds', 'rounds_count', _roundsCount);
    _config.updateNestedSetting('testing_rounds', 'interval_between_rounds_sec', _intervalBetweenRoundsSec);

    _config.updateNestedSetting('tests', 'geo_flag', 'enabled', _t2Geo);
    _config.updateNestedSetting('tests', 'udp', 'enabled', _t7UDP);
    _config.updateNestedSetting('tests', 'stability', 'enabled', _t8Stability);
    _config.updateNestedSetting('tests', 'fraud_score', 'enabled', _t9Fraud);

    _config.saveSettings();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isPersian ? 'تنظیمات شخصی‌سازی تست‌ها ذخیره شد.' : 'Test settings saved.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';

    return Scaffold(
      appBar: AppBar(
        title: Text(isPersian ? 'شخصی‌سازی پیشرفته تست‌ها' : 'Advanced Test Funnel Customization'),
        actions: [
          FilledButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save),
            label: Text(isPersian ? 'ذخیره تنظیمات' : 'Save Settings'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // Section 1: Multi-Round Testing Card
          Card(
            color: Colors.purple.shade50,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.repeat, color: Colors.purple, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPersian ? 'تست چندباره نودها (Multi-Round Testing)' : 'Multi-Round Testing',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purple),
                            ),
                            Text(
                              isPersian
                                  ? 'برای جلوگیری از حذف اشتباهی کانفیگ‌های سالم در شرایط سخت شبکه، کل لیست چند بار با وقفه تست می‌شود.'
                                  : 'Repeat the test across multiple rounds with cooldown to avoid false negatives.',
                              style: TextStyle(color: Colors.purple.shade800, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isPersian ? 'تعداد دور تست:' : 'Rounds Count:'),
                            const SizedBox(height: 8),
                            SegmentedButton<int>(
                              segments: const [
                                ButtonSegment(value: 1, label: Text('۱ دور')),
                                ButtonSegment(value: 2, label: Text('۲ دور')),
                                ButtonSegment(value: 3, label: Text('۳ دور')),
                                ButtonSegment(value: 5, label: Text('۵ دور')),
                              ],
                              selected: {_roundsCount},
                              onSelectionChanged: (set) => setState(() => _roundsCount = set.first),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isPersian ? 'وقفه بین هر دور: $_intervalBetweenRoundsSec ثانیه' : 'Cooldown: $_intervalBetweenRoundsSec s'),
                            Slider(
                              min: 5,
                              max: 60,
                              divisions: 11,
                              value: _intervalBetweenRoundsSec.toDouble(),
                              onChanged: (v) => setState(() => _intervalBetweenRoundsSec = v.toInt()),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Test 1: Real Delay / Ping Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.speed, color: Colors.blue, size: 28),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPersian ? 'تست ۱: تاخیر واقعی اتصال (Real Delay / URL Test)' : 'Test 1: Ping & Real Delay',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                isPersian ? 'سنجش زنده بودن و محاسبه تاخیر واقعی RTT بر حسب میلی‌ثانیه' : 'Measures true RTT in milliseconds',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _t1Ping,
                        onChanged: (v) => setState(() => _t1Ping = v),
                      ),
                    ],
                  ),
                  if (_t1Ping) ...[
                    const Divider(height: 24),
                    // Test URL Presets + Custom
                    Text(isPersian ? 'انتخاب آدرس تست تاخیر (پیش‌فرض‌ها یا وارد کردن دلخواه):' : 'Test URL (Presets or Custom):'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: [
                        'http://www.gstatic.com/generate_204',
                        'https://cp.cloudflare.com/generate_204',
                        'https://www.google.com/generate_204',
                        'https://www.apple.com/library/test/success.html',
                      ].contains(_pingUrl) ? _pingUrl : null,
                      hint: Text(isPersian ? 'انتخاب از لیست پیش‌فرض‌های پرسرعت' : 'Select a preset'),
                      items: const [
                        DropdownMenuItem(
                          value: 'http://www.gstatic.com/generate_204',
                          child: Text('Google GStatic (سبک‌ترین و پایدارترین)'),
                        ),
                        DropdownMenuItem(
                          value: 'https://cp.cloudflare.com/generate_204',
                          child: Text('Cloudflare 204 (جهانی)'),
                        ),
                        DropdownMenuItem(
                          value: 'https://www.google.com/generate_204',
                          child: Text('Google 204 (استاندارد)'),
                        ),
                        DropdownMenuItem(
                          value: 'https://www.apple.com/library/test/success.html',
                          child: Text('Apple Captive Portal'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _pingUrl = val;
                            _customPingCtrl.text = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customPingCtrl,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: isPersian ? 'آدرس دقیق لینک تست تاخیر' : 'Custom Ping URL',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // Smart Timeout with units
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isPersian ? 'مهلت تست (تبدیل هوشمند زمان):' : 'Test Timeout:'),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: _timeoutCtrl,
                                      decoration: InputDecoration(
                                        border: const OutlineInputBorder(),
                                        hintText: isPersian ? 'مثلاً ۳ یا ۵' : '3 or 5',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: DropdownButtonFormField<String>(
                                      value: _timeoutUnit,
                                      items: const [
                                        DropdownMenuItem(value: 'ثانیه', child: Text('ثانیه')),
                                        DropdownMenuItem(value: 'دقیقه', child: Text('دقیقه')),
                                        DropdownMenuItem(value: 'ساعت', child: Text('ساعت')),
                                      ],
                                      onChanged: (v) => setState(() => _timeoutUnit = v!),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Concurrency
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isPersian ? 'تعداد تست همزمان (Concurrency): $_concurrency' : 'Concurrency: $_concurrency'),
                              Slider(
                                min: 5,
                                max: 100,
                                divisions: 19,
                                value: _concurrency.toDouble(),
                                onChanged: (v) => setState(() => _concurrency = v.toInt()),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(isPersian ? 'سقف حداکثر تاخیر مجاز: ${_maxPingMs.toInt()} میلی‌ثانیه' : 'Max Latency: ${_maxPingMs.toInt()} ms'),
                    Slider(
                      min: 300,
                      max: 3000,
                      divisions: 27,
                      value: _maxPingMs,
                      onChanged: (v) => setState(() => _maxPingMs = v),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Test 3: Gemini AI 3-Level Checker
          Card(
            color: Colors.blue.shade50.withOpacity(0.5),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.psychology, color: Colors.blue, size: 28),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPersian ? 'تست هوش مصنوعی جمنای گوگل (Google Gemini)' : 'Google Gemini 3-Level Probe',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                isPersian
                                    ? 'سنجش دقیق عبور از تحریم منطقه گوگل جمنای با پشتیبانی از کلید API'
                                    : 'Accurate regional unblock check with Gemini API Key support',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _t3Gemini,
                        onChanged: (v) => setState(() => _t3Gemini = v),
                      ),
                    ],
                  ),
                  if (_t3Gemini) ...[
                    const Divider(height: 24),
                    Text(isPersian ? 'انتخاب سطح بررسی جمنای:' : 'Gemini Probe Level:'),
                    RadioListTile<int>(
                      title: Text(isPersian ? 'سطح ۱: بررسی دسترسی سریع به دامنه (سبک و سریع)' : 'Level 1: Domain Reachability'),
                      subtitle: Text(isPersian ? 'بررسی اتصال TCP و TLS به سرورهای جمنای' : 'Quick DNS/TLS probe'),
                      value: 1,
                      groupValue: _geminiLevel,
                      onChanged: (v) => setState(() => _geminiLevel = v!),
                    ),
                    RadioListTile<int>(
                      title: Text(isPersian ? 'سطح ۲: سنجش تحریم منطقه‌ای وب‌اپ (پیش‌فرض پیشنهادی)' : 'Level 2: Web App Regional Block Check'),
                      subtitle: Text(isPersian ? 'بررسی عدم دریافت خطای Unavailable in your country' : 'Detects "Unavailable in your country" block page'),
                      value: 2,
                      groupValue: _geminiLevel,
                      onChanged: (v) => setState(() => _geminiLevel = v!),
                    ),
                    RadioListTile<int>(
                      title: Text(isPersian ? 'سطح ۳: تست پرامپت زنده با کلید API کاربر (قطعی‌ترین تست)' : 'Level 3: Live API Prompt with User Key'),
                      subtitle: Text(isPersian ? 'ارسال پرامپت تست به Gemini Flash و دریافت پاسخ زنده' : 'Sends real prompt to Gemini Flash API'),
                      value: 3,
                      groupValue: _geminiLevel,
                      onChanged: (v) => setState(() => _geminiLevel = v!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _geminiApiKeyCtrl,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: isPersian ? 'کلید اختصاصی Gemini API Key (برای سطح ۳)' : 'Gemini API Key (For Level 3)',
                        hintText: 'AIzaSy...',
                        prefixIcon: const Icon(Icons.key),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Other Test Funnels
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPersian ? 'سایر تست‌های تخصصی' : 'Additional Specialized Tests',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Divider(height: 20),
                  SwitchListTile(
                    title: Text(isPersian ? 'تشخیص کشور و پرچم (Geo Exit IP)' : 'Country Flag & Geo IP'),
                    subtitle: Text(isPersian ? 'دریافت IP خروجی و الصاق پرچم کشور به نام پروکسی' : 'Extract exit IP and append country flag emoji'),
                    value: _t2Geo,
                    onChanged: (v) => setState(() => _t2Geo = v),
                  ),
                  SwitchListTile(
                    title: Text(isPersian ? 'پروتکل UDP (مخصوص گیمینگ و تماس صوتی)' : 'UDP Protocol (Gaming & Voice)'),
                    subtitle: Text(isPersian ? 'تست بسته‌های DNS UDP برای بازی‌های آنلاین و دیسکورد' : 'Test UDP transmission for voice and gaming'),
                    value: _t7UDP,
                    onChanged: (v) => setState(() => _t7UDP = v),
                  ),
                  SwitchListTile(
                    title: Text(isPersian ? 'سنجش پایداری و نوسان (Stability & Jitter)' : 'Stability & Jitter'),
                    subtitle: Text(isPersian ? 'اندازه‌گیری نوسان پینگ و پکت‌لاس' : 'Measure latency fluctuation and packet loss'),
                    value: _t8Stability,
                    onChanged: (v) => setState(() => _t8Stability = v),
                  ),
                  SwitchListTile(
                    title: Text(isPersian ? 'نمره تمیزی آی‌پی (Fraud Score & Clean IP)' : 'Fraud Score (Clean IP)'),
                    subtitle: Text(isPersian ? 'عدم حضور در لیست‌های مشکوک برای جلوگیری از کپچا' : 'Ensure IP is clean from captchas and blacklists'),
                    value: _t9Fraud,
                    onChanged: (v) => setState(() => _t9Fraud = v),
                  ),
                  SwitchListTile(
                    title: Text(isPersian ? 'سنجش سرعت دانلود واقعی (Download Speed)' : 'Download Speed Test'),
                    subtitle: Text(isPersian ? 'دریافت ترافیک واقعی از کلاودفلر برای محاسبه پهنای باند' : 'Real traffic download throughput measurement'),
                    value: _t6SpeedDown,
                    onChanged: (v) => setState(() => _t6SpeedDown = v),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
