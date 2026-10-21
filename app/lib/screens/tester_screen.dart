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
  bool _t4SpeedDown = false;
  bool _t5SpeedUp = false;
  bool _t6UDP = true;
  bool _t7Stability = true;
  bool _t8PacketLoss = true;
  bool _t9Fraud = true;

  // Real Delay (Ping) settings
  String _pingUrl = 'http://www.gstatic.com/generate_204';
  late TextEditingController _customPingCtrl;
  double _maxPingMs = 1500;
  int _concurrency = 50;
  late TextEditingController _timeoutCtrl;
  String _timeoutUnit = 'ثانیه';

  // Multi-round testing
  bool _roundsEnabled = false;
  int _roundsCount = 1;
  int _intervalBetweenRoundsSec = 15;

  // Jitter & Packet Loss settings
  double _maxJitterMs = 120.0;
  double _maxPacketLossPercent = 0.0;

  // Download Speed Test settings
  String _speedDownUrl = 'https://speed.cloudflare.com/__down?bytes=10000000';
  late TextEditingController _customSpeedDownCtrl;
  int _downloadFileSizeMb = 10;
  int _minDownloadSpeedKbps = 500;
  int _downloadTimeoutSec = 10;

  // Upload Speed Test settings
  String _speedUpUrl = 'https://speed.cloudflare.com/__up';
  late TextEditingController _customSpeedUpCtrl;
  int _uploadFileSizeMb = 2;
  int _minUploadSpeedKbps = 200;
  int _uploadTimeoutSec = 8;

  // Gemini AI settings
  int _geminiLevel = 2;
  String _geminiTarget = 'both'; // 'gemini_web', 'ai_studio', 'both'
  int _geminiConcurrency = 3;
  late TextEditingController _geminiApiKeyCtrl;
  bool _isGoogleLoggedIn = false;
  String _googleAccountEmail = '';

  @override
  void initState() {
    super.initState();
    _customPingCtrl = TextEditingController(text: _pingUrl);
    _customSpeedDownCtrl = TextEditingController(text: _speedDownUrl);
    _customSpeedUpCtrl = TextEditingController(text: _speedUpUrl);
    _timeoutCtrl = TextEditingController(text: '3');
    _geminiApiKeyCtrl = TextEditingController();
    _loadFromConfig();
  }

  void _loadFromConfig() {
    final tests = _config.settings['tests'] ?? {};
    final ping = tests['ping'] ?? {};
    final gemini = tests['gemini'] ?? {};
    final speedDown = tests['download_speed'] ?? {};
    final speedUp = tests['upload_speed'] ?? {};
    final rounds = _config.settings['testing_rounds'] ?? {};
    final stability = tests['stability'] ?? {};
    final pLoss = tests['packet_loss'] ?? {};

    _t1Ping = ping['enabled'] ?? true;
    _maxPingMs = (ping['max_latency_ms'] ?? 1500).toDouble();
    _concurrency = ping['concurrency'] ?? 50;
    _pingUrl = ping['test_url'] ?? 'http://www.gstatic.com/generate_204';
    _customPingCtrl.text = _pingUrl;
    _timeoutCtrl.text = '${ping['timeout_val'] ?? 3}';

    _t8PacketLoss = pLoss['enabled'] ?? true;
    _maxPacketLossPercent = (pLoss['max_loss_percent'] ?? 0).toDouble();

    _t7Stability = stability['enabled'] ?? true;
    _maxJitterMs = (stability['max_jitter_ms'] ?? 120.0).toDouble();

    // Gemini
    _t3Gemini = gemini['enabled'] ?? true;
    _geminiLevel = gemini['level'] ?? 2;
    _geminiTarget = gemini['target'] ?? 'both';
    _geminiConcurrency = gemini['concurrency'] ?? 3;
    _geminiApiKeyCtrl.text = gemini['api_key'] ?? '';
    _isGoogleLoggedIn = gemini['logged_in'] ?? false;
    _googleAccountEmail = gemini['account_email'] ?? '';

    // Download Speed
    _t4SpeedDown = speedDown['enabled'] ?? false;
    _speedDownUrl = speedDown['test_url'] ?? 'https://speed.cloudflare.com/__down?bytes=10000000';
    _customSpeedDownCtrl.text = _speedDownUrl;
    _downloadFileSizeMb = speedDown['file_size_mb'] ?? 10;
    _minDownloadSpeedKbps = speedDown['min_speed_kbps'] ?? 500;
    _downloadTimeoutSec = speedDown['timeout_val'] ?? 10;

    // Upload Speed
    _t5SpeedUp = speedUp['enabled'] ?? false;
    _speedUpUrl = speedUp['test_url'] ?? 'https://speed.cloudflare.com/__up';
    _customSpeedUpCtrl.text = _speedUpUrl;
    _uploadFileSizeMb = speedUp['payload_bytes'] != null ? (speedUp['payload_bytes'] ~/ 1048576) : 2;
    if (_uploadFileSizeMb < 1) _uploadFileSizeMb = 1;
    _minUploadSpeedKbps = speedUp['min_speed_kbps'] ?? 200;
    _uploadTimeoutSec = speedUp['timeout_val'] ?? 8;

    // Rounds
    _roundsEnabled = rounds['enabled'] ?? false;
    _roundsCount = rounds['rounds_count'] ?? 1;
    _intervalBetweenRoundsSec = rounds['interval_between_rounds_sec'] ?? 15;

    _t2Geo = (tests['geo_flag'] ?? {})['enabled'] ?? true;
    _t6UDP = (tests['udp'] ?? {})['enabled'] ?? true;
    _t9Fraud = (tests['fraud_score'] ?? {})['enabled'] ?? true;
  }

  @override
  void dispose() {
    _customPingCtrl.dispose();
    _customSpeedDownCtrl.dispose();
    _customSpeedUpCtrl.dispose();
    _timeoutCtrl.dispose();
    _geminiApiKeyCtrl.dispose();
    super.dispose();
  }

  void _autoSaveQuietly() {
    final smartSeconds = ConfigService.parseSmartTime(_timeoutCtrl.text, _timeoutUnit);

    _config.updateNestedSetting('tests', 'ping', 'enabled', _t1Ping);
    _config.updateNestedSetting('tests', 'ping', 'test_url', _customPingCtrl.text.trim());
    _config.updateNestedSetting('tests', 'ping', 'max_latency_ms', _maxPingMs.toInt());
    _config.updateNestedSetting('tests', 'ping', 'concurrency', _concurrency);
    _config.updateNestedSetting('tests', 'ping', 'timeout_val', smartSeconds > 0 ? smartSeconds : 3);
    _config.updateNestedSetting('tests', 'ping', 'timeout_unit', 's');

    _config.updateNestedSetting('tests', 'packet_loss', 'enabled', _t8PacketLoss);
    _config.updateNestedSetting('tests', 'packet_loss', 'max_loss_percent', _maxPacketLossPercent.toInt());

    _config.updateNestedSetting('tests', 'stability', 'enabled', _t7Stability);
    _config.updateNestedSetting('tests', 'stability', 'max_jitter_ms', _maxJitterMs);

    // Gemini
    _config.updateNestedSetting('tests', 'gemini', 'enabled', _t3Gemini);
    _config.updateNestedSetting('tests', 'gemini', 'level', _geminiLevel);
    _config.updateNestedSetting('tests', 'gemini', 'target', _geminiTarget);
    _config.updateNestedSetting('tests', 'gemini', 'concurrency', _geminiConcurrency);
    _config.updateNestedSetting('tests', 'gemini', 'api_key', _geminiApiKeyCtrl.text.trim());
    _config.updateNestedSetting('tests', 'gemini', 'logged_in', _isGoogleLoggedIn);
    _config.updateNestedSetting('tests', 'gemini', 'account_email', _googleAccountEmail);

    // Download Speed
    _config.updateNestedSetting('tests', 'download_speed', 'enabled', _t4SpeedDown);
    _config.updateNestedSetting('tests', 'download_speed', 'test_url', _customSpeedDownCtrl.text.trim());
    _config.updateNestedSetting('tests', 'download_speed', 'file_size_mb', _downloadFileSizeMb);
    _config.updateNestedSetting('tests', 'download_speed', 'min_speed_kbps', _minDownloadSpeedKbps);
    _config.updateNestedSetting('tests', 'download_speed', 'timeout_val', _downloadTimeoutSec);

    // Upload Speed
    _config.updateNestedSetting('tests', 'upload_speed', 'enabled', _t5SpeedUp);
    _config.updateNestedSetting('tests', 'upload_speed', 'test_url', _customSpeedUpCtrl.text.trim());
    _config.updateNestedSetting('tests', 'upload_speed', 'payload_bytes', _uploadFileSizeMb * 1048576);
    _config.updateNestedSetting('tests', 'upload_speed', 'min_speed_kbps', _minUploadSpeedKbps);
    _config.updateNestedSetting('tests', 'upload_speed', 'timeout_val', _uploadTimeoutSec);

    // Rounds
    _config.updateSetting('testing_rounds', 'enabled', _roundsEnabled);
    _config.updateSetting('testing_rounds', 'rounds_count', _roundsCount);
    _config.updateSetting('testing_rounds', 'interval_between_rounds_sec', _intervalBetweenRoundsSec);

    _config.updateNestedSetting('tests', 'geo_flag', 'enabled', _t2Geo);
    _config.updateNestedSetting('tests', 'udp', 'enabled', _t6UDP);
    _config.updateNestedSetting('tests', 'fraud_score', 'enabled', _t9Fraud);
  }

  void _saveSettingsExplicit() {
    _autoSaveQuietly();
    _config.saveSettings();
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isPersian ? 'تنظیمات تست‌ها ذخیره شد.' : 'Test settings saved.'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  void _handleGoogleLogin() {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';
    if (_isGoogleLoggedIn) {
      setState(() {
        _isGoogleLoggedIn = false;
        _googleAccountEmail = '';
      });
      _config.setGoogleLoggedIn(false, '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isPersian ? 'از حساب گوگل خارج شدید.' : 'Signed out from Google.'),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isPersian ? 'ورود به حساب گوگل' : 'Sign in to Google Account'),
          content: Text(
            isPersian
                ? 'پنجره مرورگر کروم/ایج در یک پروفایل امن و ایزوله اختصاصی باز خواهد شد تا لاگین رسمی را انجام دهید. هیچ رمز عبوری در برنامه ذخیره نمی‌شود و صرفاً کوکی‌های نشست جهت بررسی تحریم جمنای استفاده می‌گردد.'
                : 'A dedicated browser profile will launch to capture the session for Gemini region checking.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isPersian ? 'انصراف' : 'Cancel'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await _config.launchGoogleSignIn();
                setState(() {
                  _isGoogleLoggedIn = _config.isGoogleLoggedIn;
                  _googleAccountEmail = _config.googleAccountEmail;
                });
                if (mounted) {
                  if (_config.isGoogleLoggedIn) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isPersian ? 'ورود با موفقیت تایید شد ($_googleAccountEmail)!' : 'Logged in successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isPersian ? 'پنجره مرورگر قبل از احراز هویت بسته شد یا لاگین تایید نگردید.' : 'Browser closed before sign-in completed.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.login),
              label: Text(isPersian ? 'باز کردن پنجره مرورگر' : 'Open Browser'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSteppedSlider({
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required ValueChanged<double> onChanged,
    double step = 1.0,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              tooltip: '-$step',
              onPressed: value > min
                  ? () {
                      final next = (value - step).clamp(min, max);
                      onChanged(next);
                      _autoSaveQuietly();
                    }
                  : null,
            ),
            Expanded(
              child: Slider(
                min: min,
                max: max,
                divisions: divisions,
                value: value.clamp(min, max),
                onChanged: (v) {
                  onChanged(v);
                  _autoSaveQuietly();
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              tooltip: '+$step',
              onPressed: value < max
                  ? () {
                      final next = (value + step).clamp(min, max);
                      onChanged(next);
                      _autoSaveQuietly();
                    }
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';

    return Scaffold(
      appBar: AppBar(
        title: Text(isPersian ? 'شخصی‌سازی پیشرفته تست‌ها' : 'Advanced Test Funnel Customization'),
        actions: [
          IconButton(
            tooltip: isPersian ? 'ذخیره تنظیمات' : 'Save Settings',
            onPressed: _saveSettingsExplicit,
            icon: const Icon(Icons.save),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // Section 1: Multi-Round Testing Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.purple.withOpacity(0.25)),
            ),
            color: Theme.of(context).cardColor,
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
                          const Icon(Icons.repeat, color: Colors.purpleAccent, size: 28),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPersian ? 'تست چندباره نودها با وقفه (Multi-Round Testing)' : 'Multi-Round Testing',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isPersian
                                    ? 'برای جلوگیری از حذف اشتباهی کانفیگ‌ها در نوسانات شبکه، کل لیست چند بار با وقفه تست می‌شود.'
                                    : 'Repeat the test across multiple rounds with cooldown to avoid false negatives.',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _roundsEnabled,
                        onChanged: (v) {
                          setState(() => _roundsEnabled = v);
                          _autoSaveQuietly();
                        },
                      ),
                    ],
                  ),
                  if (_roundsEnabled) ...[
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
                                onSelectionChanged: (set) {
                                  setState(() => _roundsCount = set.first);
                                  _autoSaveQuietly();
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildSteppedSlider(
                            value: _intervalBetweenRoundsSec.toDouble(),
                            min: 5,
                            max: 60,
                            divisions: 55,
                            label: isPersian ? 'وقفه بین هر دور: $_intervalBetweenRoundsSec ثانیه' : 'Cooldown: $_intervalBetweenRoundsSec s',
                            onChanged: (v) => setState(() => _intervalBetweenRoundsSec = v.toInt()),
                            step: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    Text(
                      isPersian
                          ? 'تست چند مرحله‌ای خاموش است؛ نودها در ۱ دور ارزیابی می‌شوند.'
                          : 'Multi-round testing disabled: nodes are tested in a single fast round.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Test 1: Real Delay / Ping Settings
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.blue.withOpacity(0.25)),
            ),
            color: Theme.of(context).cardColor,
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
                          const Icon(Icons.speed, color: Colors.blueAccent, size: 28),
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
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _t1Ping,
                        onChanged: (v) {
                          setState(() => _t1Ping = v);
                          _autoSaveQuietly();
                        },
                      ),
                    ],
                  ),
                  if (_t1Ping) ...[
                    const Divider(height: 24),
                    Text(isPersian ? 'انتخاب آدرس تست تاخیر (HTTP و HTTPS):' : 'Test URL Presets:'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: [
                        'http://www.gstatic.com/generate_204',
                        'https://www.gstatic.com/generate_204',
                        'http://cp.cloudflare.com/generate_204',
                        'https://cp.cloudflare.com/generate_204',
                        'http://connectivitycheck.gstatic.com/generate_204',
                        'https://connectivitycheck.gstatic.com/generate_204',
                        'http://www.apple.com/library/test/success.html',
                        'https://www.apple.com/library/test/success.html',
                      ].contains(_pingUrl) ? _pingUrl : null,
                      hint: Text(isPersian ? 'انتخاب از لیست پیش‌فرض‌های پرسرعت' : 'Select a preset'),
                      items: const [
                        DropdownMenuItem(
                          value: 'http://www.gstatic.com/generate_204',
                          child: Text('Google GStatic [HTTP] (بسیار سریع و سبک)'),
                        ),
                        DropdownMenuItem(
                          value: 'https://www.gstatic.com/generate_204',
                          child: Text('Google GStatic [HTTPS] (استاندارد و امن)'),
                        ),
                        DropdownMenuItem(
                          value: 'http://cp.cloudflare.com/generate_204',
                          child: Text('Cloudflare 204 [HTTP] (سرورهای جهانی)'),
                        ),
                        DropdownMenuItem(
                          value: 'https://cp.cloudflare.com/generate_204',
                          child: Text('Cloudflare 204 [HTTPS] (رمزنگاری‌شده)'),
                        ),
                        DropdownMenuItem(
                          value: 'http://connectivitycheck.gstatic.com/generate_204',
                          child: Text('Android Check [HTTP] (گوگل اندروید)'),
                        ),
                        DropdownMenuItem(
                          value: 'https://connectivitycheck.gstatic.com/generate_204',
                          child: Text('Android Check [HTTPS]'),
                        ),
                        DropdownMenuItem(
                          value: 'http://www.apple.com/library/test/success.html',
                          child: Text('Apple Portal [HTTP]'),
                        ),
                        DropdownMenuItem(
                          value: 'https://www.apple.com/library/test/success.html',
                          child: Text('Apple Portal [HTTPS]'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _pingUrl = val;
                            _customPingCtrl.text = val;
                          });
                          _autoSaveQuietly();
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customPingCtrl,
                      onChanged: (_) => _autoSaveQuietly(),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: isPersian ? 'یا وارد کردن آدرس سفارشی تست تاخیر (Custom Ping URL)' : 'Custom Ping URL',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // Timeout
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isPersian ? 'مهلت تست:' : 'Test Timeout:'),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: _timeoutCtrl,
                                      onChanged: (_) => _autoSaveQuietly(),
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
                                      onChanged: (v) {
                                        setState(() => _timeoutUnit = v!);
                                        _autoSaveQuietly();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Concurrency slider
                        Expanded(
                          child: _buildSteppedSlider(
                            value: _concurrency.toDouble(),
                            min: 1,
                            max: 1000,
                            divisions: 999,
                            label: isPersian ? 'تعداد تست همزمان (Concurrency): $_concurrency' : 'Concurrency: $_concurrency',
                            onChanged: (v) => setState(() => _concurrency = v.toInt()),
                            step: 1.0,
                          ),
                        ),
                      ],
                    ),
                    if (_concurrency > 200) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isPersian
                                    ? '⚠️ هشدار همزمانی بالا: همزمانی بالای ۲۰۰ نود نیازمند پردازنده قوی و اینترنت پرسرعت پایدار (مانند فیبر نوری) است. در سیستم‌های معمولی ممکن است باعث اشباع سوکت‌ها یا کندی شود.'
                                    : 'Warning: Concurrency over 200 requires high-end hardware and high-bandwidth fiber connection.',
                                style: const TextStyle(fontSize: 12, color: Colors.amber),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildSteppedSlider(
                      value: _maxPingMs,
                      min: 100,
                      max: 3000,
                      divisions: 2900,
                      label: isPersian ? 'سقف حداکثر تاخیر مجاز: ${_maxPingMs.toInt()} میلی‌ثانیه' : 'Max Latency: ${_maxPingMs.toInt()} ms',
                      onChanged: (v) => setState(() => _maxPingMs = v),
                      step: 5.0,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Jitter and Packet Loss Settings
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.teal.withOpacity(0.25)),
            ),
            color: Theme.of(context).cardColor,
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
                          const Icon(Icons.network_check, color: Colors.tealAccent, size: 28),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPersian ? 'سنجش نوسان پینگ (Jitter) و پکت‌لاست (Packet Loss)' : 'Packet Loss & Jitter',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                isPersian ? 'حذف اتصالات دارای پرش یا قطعی متناوب جهت تضمین ثبات' : 'Filters unstable connections',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(isPersian ? 'پکت‌لاست:' : 'Loss:'),
                          Switch(
                            value: _t8PacketLoss,
                            onChanged: (v) {
                              setState(() => _t8PacketLoss = v);
                              _autoSaveQuietly();
                            },
                          ),
                          const SizedBox(width: 8),
                          Text(isPersian ? 'جیتر:' : 'Jitter:'),
                          Switch(
                            value: _t7Stability,
                            onChanged: (v) {
                              setState(() => _t7Stability = v);
                              _autoSaveQuietly();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_t8PacketLoss || _t7Stability) ...[
                    const Divider(height: 24),
                    Row(
                      children: [
                        if (_t8PacketLoss)
                          Expanded(
                            child: _buildSteppedSlider(
                              value: _maxPacketLossPercent,
                              min: 0,
                              max: 50,
                              divisions: 50,
                              label: isPersian ? 'سقف پکت‌لاست مجاز: ${_maxPacketLossPercent.toInt()}%' : 'Max Packet Loss: ${_maxPacketLossPercent.toInt()}%',
                              onChanged: (v) => setState(() => _maxPacketLossPercent = v),
                              step: 1.0,
                            ),
                          ),
                        if (_t8PacketLoss && _t7Stability) const SizedBox(width: 24),
                        if (_t7Stability)
                          Expanded(
                            child: _buildSteppedSlider(
                              value: _maxJitterMs,
                              min: 10,
                              max: 500,
                              divisions: 490,
                              label: isPersian ? 'سقف نوسان مجاز (Jitter): ${_maxJitterMs.toInt()} ms' : 'Max Jitter: ${_maxJitterMs.toInt()} ms',
                              onChanged: (v) => setState(() => _maxJitterMs = v),
                              step: 1.0,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Test 3: Gemini AI Probe with Google Login and Targets
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.blueAccent.withOpacity(0.25)),
            ),
            color: Theme.of(context).cardColor,
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
                          const Icon(Icons.psychology, color: Colors.blueAccent, size: 28),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPersian ? 'تست هوش مصنوعی جمنای گوگل (Google Gemini)' : 'Google Gemini AI Probe',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                isPersian
                                    ? 'سنجش دقیق عبور از تحریم منطقه گوگل جمنای و استودیوی AI'
                                    : 'Regional unblock check with Google sign-in and API key support',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _t3Gemini,
                        onChanged: (v) {
                          setState(() => _t3Gemini = v);
                          _autoSaveQuietly();
                        },
                      ),
                    ],
                  ),
                  if (_t3Gemini) ...[
                    const Divider(height: 24),
                    // Google Sign-In Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _isGoogleLoggedIn ? Colors.green.withOpacity(0.08) : Colors.blue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _isGoogleLoggedIn ? Colors.green.withOpacity(0.3) : Colors.blue.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isGoogleLoggedIn ? Icons.check_circle : Icons.account_circle,
                            color: _isGoogleLoggedIn ? Colors.greenAccent : Colors.blueAccent,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isGoogleLoggedIn
                                      ? (isPersian ? 'وارد شده با حساب گوگل: $_googleAccountEmail' : 'Google Signed-In: $_googleAccountEmail')
                                      : (isPersian ? 'ورود به حساب گوگل (برای تست دقیق‌تر منطقه)' : 'Google Sign-In (for high-accuracy region probe)'),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  isPersian
                                      ? 'گوگل منطقه واقعی کاربر را برای حساب‌های لاگین‌شده سخت‌گیرانه‌تر بررسی می‌کند.'
                                      : 'Google checks regional access more thoroughly on authenticated accounts.',
                                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _handleGoogleLogin,
                            icon: Icon(_isGoogleLoggedIn ? Icons.logout : Icons.login, size: 16),
                            label: Text(
                              _isGoogleLoggedIn
                                  ? (isPersian ? 'خروج از حساب' : 'Logout')
                                  : (isPersian ? 'ورود به اکانت' : 'Sign In'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Target Selection & Concurrency
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isPersian ? 'سایت هدف بررسی جمنای:' : 'Target Service:'),
                              const SizedBox(height: 8),
                              SegmentedButton<String>(
                                segments: [
                                  ButtonSegment(
                                    value: 'gemini_web',
                                    label: Text(isPersian ? 'فقط جمنای وب' : 'Gemini Web'),
                                  ),
                                  ButtonSegment(
                                    value: 'ai_studio',
                                    label: Text(isPersian ? 'فقط AI Studio' : 'AI Studio'),
                                  ),
                                  ButtonSegment(
                                    value: 'both',
                                    label: Text(isPersian ? 'هر دو (کامل)' : 'Both Services'),
                                  ),
                                ],
                                selected: {_geminiTarget},
                                onSelectionChanged: (set) {
                                  setState(() => _geminiTarget = set.first);
                                  _autoSaveQuietly();
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 2,
                          child: _buildSteppedSlider(
                            value: _geminiConcurrency.toDouble(),
                            min: 1,
                            max: 10,
                            divisions: 9,
                            label: isPersian ? 'همزمانی تست جمنای: $_geminiConcurrency' : 'Gemini Concurrency: $_geminiConcurrency',
                            onChanged: (v) => setState(() => _geminiConcurrency = v.toInt()),
                            step: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(isPersian ? 'سطح بررسی:' : 'Probe Level:'),
                    RadioListTile<int>(
                      title: Text(isPersian ? 'سطح ۱: بررسی دسترسی سریع به دامنه' : 'Level 1: Domain Reachability'),
                      subtitle: Text(isPersian ? 'بررسی اتصال TCP و TLS به سرورهای جمنای' : 'Quick DNS/TLS probe'),
                      value: 1,
                      groupValue: _geminiLevel,
                      onChanged: (v) {
                        setState(() => _geminiLevel = v!);
                        _autoSaveQuietly();
                      },
                    ),
                    RadioListTile<int>(
                      title: Text(isPersian ? 'سطح ۲: سنجش تحریم منطقه‌ای وب‌اپ (پیشنهادی)' : 'Level 2: Web App Regional Block Check'),
                      subtitle: Text(isPersian ? 'بررسی عدم دریافت خطای Unavailable in your country' : 'Detects "Unavailable in your country" block page'),
                      value: 2,
                      groupValue: _geminiLevel,
                      onChanged: (v) {
                        setState(() => _geminiLevel = v!);
                        _autoSaveQuietly();
                      },
                    ),
                    RadioListTile<int>(
                      title: Text(isPersian ? 'سطح ۳: تست پرامپت زنده با کلید API کاربر' : 'Level 3: Live API Prompt with User Key'),
                      subtitle: Text(isPersian ? 'ارسال پرامپت تست به Gemini Flash و دریافت پاسخ زنده' : 'Sends real prompt to Gemini Flash API'),
                      value: 3,
                      groupValue: _geminiLevel,
                      onChanged: (v) {
                        setState(() => _geminiLevel = v!);
                        _autoSaveQuietly();
                      },
                    ),
                    if (_geminiLevel == 3) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _geminiApiKeyCtrl,
                        obscureText: true,
                        onChanged: (_) => _autoSaveQuietly(),
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: isPersian ? 'کلید API جمنای (Google Gemini API Key)' : 'Gemini API Key',
                          hintText: 'AIzaSy...',
                          prefixIcon: const Icon(Icons.key),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Download Speed Test Settings
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.green.withOpacity(0.25)),
            ),
            color: Theme.of(context).cardColor,
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
                          const Icon(Icons.download, color: Colors.greenAccent, size: 28),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPersian ? 'سنجش سرعت دانلود واقعی (Download Speed)' : 'Download Speed Test',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                isPersian ? 'دریافت ترافیک واقعی از سرور و محاسبه پهنای باند دانلود' : 'Measures actual download bandwidth',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _t4SpeedDown,
                        onChanged: (v) {
                          setState(() => _t4SpeedDown = v);
                          _autoSaveQuietly();
                        },
                      ),
                    ],
                  ),
                  if (_t4SpeedDown) ...[
                    const Divider(height: 24),
                    Text(isPersian ? 'انتخاب سرور و اندازه فایل دانلودی:' : 'Download Test Server & Size:'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: [
                        'https://speed.cloudflare.com/__down?bytes=5000000',
                        'https://speed.cloudflare.com/__down?bytes=10000000',
                        'https://speed.cloudflare.com/__down?bytes=25000000',
                        'https://speed.cloudflare.com/__down?bytes=50000000',
                        'https://proof.ovh.net/files/10Mb.dat',
                        'https://speed.hetzner.de/10MB.bin',
                      ].contains(_speedDownUrl) ? _speedDownUrl : null,
                      hint: Text(isPersian ? 'انتخاب از لیست سرورهای پرسرعت جهانی' : 'Select a preset'),
                      items: const [
                        DropdownMenuItem(
                          value: 'https://speed.cloudflare.com/__down?bytes=5000000',
                          child: Text('Cloudflare Speed 5MB (سریع و استاندارد)'),
                        ),
                        DropdownMenuItem(
                          value: 'https://speed.cloudflare.com/__down?bytes=10000000',
                          child: Text('Cloudflare Speed 10MB (دقیق و پیشنهادی)'),
                        ),
                        DropdownMenuItem(
                          value: 'https://speed.cloudflare.com/__down?bytes=25000000',
                          child: Text('Cloudflare Speed 25MB (پهنای باند بالا)'),
                        ),
                        DropdownMenuItem(
                          value: 'https://speed.cloudflare.com/__down?bytes=50000000',
                          child: Text('Cloudflare Speed 50MB (سنگین / فیبر نوری)'),
                        ),
                        DropdownMenuItem(
                          value: 'https://proof.ovh.net/files/10Mb.dat',
                          child: Text('OVH Telecom 10MB (دیتاسنتر اروپا)'),
                        ),
                        DropdownMenuItem(
                          value: 'https://speed.hetzner.de/10MB.bin',
                          child: Text('Hetzner Speedtest 10MB (آلمان)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _speedDownUrl = val;
                            _customSpeedDownCtrl.text = val;
                          });
                          _autoSaveQuietly();
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customSpeedDownCtrl,
                      onChanged: (_) => _autoSaveQuietly(),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: isPersian ? 'یا وارد کردن آدرس سفارشی فایل آزمایشی' : 'Custom Download Test URL',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isPersian ? 'اندازه بسته دانلودی:' : 'File Size:'),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<int>(
                                value: _downloadFileSizeMb,
                                items: const [
                                  DropdownMenuItem(value: 1, child: Text('۱ مگابایت (سریع)')),
                                  DropdownMenuItem(value: 5, child: Text('۵ مگابایت (متعادل)')),
                                  DropdownMenuItem(value: 10, child: Text('۱۰ مگابایت (دقیق)')),
                                  DropdownMenuItem(value: 20, child: Text('۲۰ مگابایت (سنگین)')),
                                ],
                                onChanged: (v) {
                                  setState(() => _downloadFileSizeMb = v!);
                                  _autoSaveQuietly();
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSteppedSlider(
                            value: _minDownloadSpeedKbps.toDouble(),
                            min: 50,
                            max: 10000,
                            divisions: 995,
                            label: isPersian ? 'حداقل سرعت قبولی: $_minDownloadSpeedKbps KB/s' : 'Min Speed: $_minDownloadSpeedKbps KB/s',
                            onChanged: (v) => setState(() => _minDownloadSpeedKbps = v.toInt()),
                            step: 50.0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Upload Speed Test Settings
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.orange.withOpacity(0.25)),
            ),
            color: Theme.of(context).cardColor,
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
                          const Icon(Icons.upload, color: Colors.orangeAccent, size: 28),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPersian ? 'سنجش سرعت آپلود واقعی (Upload Speed)' : 'Upload Speed Test',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                isPersian ? 'ارسال بسته به سرور و محاسبه نرخ بارگذاری داده‌ها' : 'Measures actual upload bandwidth',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _t5SpeedUp,
                        onChanged: (v) {
                          setState(() => _t5SpeedUp = v);
                          _autoSaveQuietly();
                        },
                      ),
                    ],
                  ),
                  if (_t5SpeedUp) ...[
                    const Divider(height: 24),
                    TextField(
                      controller: _customSpeedUpCtrl,
                      onChanged: (_) => _autoSaveQuietly(),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: isPersian ? 'آدرس مقصد تست آپلود' : 'Upload Target URL',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isPersian ? 'حجم بسته ارسالی:' : 'Upload Payload:'),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<int>(
                                value: _uploadFileSizeMb,
                                items: const [
                                  DropdownMenuItem(value: 1, child: Text('۱ مگابایت')),
                                  DropdownMenuItem(value: 2, child: Text('۲ مگابایت')),
                                  DropdownMenuItem(value: 5, child: Text('۵ مگابایت')),
                                ],
                                onChanged: (v) {
                                  setState(() => _uploadFileSizeMb = v!);
                                  _autoSaveQuietly();
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSteppedSlider(
                            value: _minUploadSpeedKbps.toDouble(),
                            min: 20,
                            max: 5000,
                            divisions: 498,
                            label: isPersian ? 'حداقل سرعت قبولی: $_minUploadSpeedKbps KB/s' : 'Min Speed: $_minUploadSpeedKbps KB/s',
                            onChanged: (v) => setState(() => _minUploadSpeedKbps = v.toInt()),
                            step: 20.0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Other Tests
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
            color: Theme.of(context).cardColor,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPersian ? 'سایر تست‌های تخصصی' : 'Additional Probes',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Divider(height: 20),
                  SwitchListTile(
                    title: Text(isPersian ? 'تشخیص کشور و پرچم (Geo Exit IP)' : 'Country & Flag Detection'),
                    subtitle: Text(isPersian ? 'دریافت IP خروجی و الصاق پرچم کشور به نام پروکسی' : 'Attaches country flag emoji to proxy name'),
                    value: _t2Geo,
                    onChanged: (v) {
                      setState(() => _t2Geo = v);
                      _autoSaveQuietly();
                    },
                  ),
                  SwitchListTile(
                    title: Text(isPersian ? 'پروتکل UDP (مخصوص گیمینگ و تماس صوتی)' : 'UDP Support Check'),
                    subtitle: Text(isPersian ? 'تست بسته‌های UDP برای بازی‌های آنلاین و دیسکورد' : 'Ensures UDP traffic is supported for gaming/calls'),
                    value: _t6UDP,
                    onChanged: (v) {
                      setState(() => _t6UDP = v);
                      _autoSaveQuietly();
                    },
                  ),
                  SwitchListTile(
                    title: Text(isPersian ? 'نمره تمیزی آی‌پی (Fraud Score)' : 'IP Fraud Score'),
                    subtitle: Text(isPersian ? 'اطمینان از تمیز بودن IP جهت جلوگیری از کپچاهای متعدد' : 'Filters datacenter/abused IPs causing captchas'),
                    value: _t9Fraud,
                    onChanged: (v) {
                      setState(() => _t9Fraud = v);
                      _autoSaveQuietly();
                    },
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
