import 'dart:io';
import 'package:flutter/material.dart';
import '../services/config_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ConfigService _config = ConfigService();

  // Hardware Profile
  String _profile = 'medium';

  // System Proxy (named "سیستم پروکسی" as requested)
  bool _systemProxyEnabled = true;
  late TextEditingController _proxyHostCtrl;
  late TextEditingController _proxyPortCtrl;

  // Telegram Bot Auto-Dispatcher
  bool _telegramBotEnabled = false;
  late TextEditingController _botTokenCtrl;
  late TextEditingController _channelIdCtrl;
  bool _sendFiles = true;
  bool _sendSummary = true;
  String _botTestStatus = '';

  // Sent History Deduplication
  bool _dedupEnabled = true;

  // Mihomo Core Manager
  String _preferredArch = 'auto';
  String _detectedArch = 'windows-amd64';

  @override
  void initState() {
    super.initState();
    _proxyHostCtrl = TextEditingController(text: '127.0.0.1');
    _proxyPortCtrl = TextEditingController(text: '7890');
    _botTokenCtrl = TextEditingController();
    _channelIdCtrl = TextEditingController();
    _detectSystemArchitecture();
    _loadFromConfig();
  }

  void _detectSystemArchitecture() {
    // Detect Windows architecture
    if (Platform.isWindows) {
      final arch = Platform.environment['PROCESSOR_ARCHITECTURE'] ?? '';
      if (arch.contains('64')) {
        _detectedArch = 'windows-amd64 (پشتیبانی از AVX2)';
      } else {
        _detectedArch = 'windows-amd64-compatible (بدون AVX2)';
      }
    }
  }

  void _loadFromConfig() {
    final net = _config.settings['network'] ?? {};
    _systemProxyEnabled = (net['mode'] ?? 'system_proxy') == 'system_proxy';
    _proxyHostCtrl.text = net['proxy_host'] ?? '127.0.0.1';
    _proxyPortCtrl.text = '${net['proxy_port'] ?? 7890}';

    final tg = _config.settings['telegram_sender'] ?? {};
    _telegramBotEnabled = tg['enabled'] ?? false;
    _botTokenCtrl.text = tg['bot_token'] ?? '';
    _channelIdCtrl.text = tg['channel_id'] ?? '';
    _sendFiles = tg['send_files'] ?? true;
    _sendSummary = tg['send_summary'] ?? true;

    final of = _config.settings['output_filters'] ?? {};
    _dedupEnabled = of['filter_previously_sent'] ?? true;

    final cm = _config.settings['core_manager'] ?? {};
    _preferredArch = cm['preferred_arch'] ?? 'auto';
  }

  @override
  void dispose() {
    _proxyHostCtrl.dispose();
    _proxyPortCtrl.dispose();
    _botTokenCtrl.dispose();
    _channelIdCtrl.dispose();
    super.dispose();
  }

  void _saveSettings() {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';

    _config.updateNestedSetting('network', 'mode', _systemProxyEnabled ? 'system_proxy' : 'direct');
    _config.updateNestedSetting('network', 'proxy_host', _proxyHostCtrl.text.trim());
    _config.updateNestedSetting('network', 'proxy_port', int.tryParse(_proxyPortCtrl.text.trim()) ?? 7890);

    _config.updateNestedSetting('telegram_sender', 'enabled', _telegramBotEnabled);
    _config.updateNestedSetting('telegram_sender', 'bot_token', _botTokenCtrl.text.trim());
    _config.updateNestedSetting('telegram_sender', 'channel_id', _channelIdCtrl.text.trim());
    _config.updateNestedSetting('telegram_sender', 'send_files', _sendFiles);
    _config.updateNestedSetting('telegram_sender', 'send_summary', _sendSummary);

    _config.updateNestedSetting('output_filters', 'filter_previously_sent', _dedupEnabled);
    _config.updateNestedSetting('core_manager', 'preferred_arch', _preferredArch);

    _config.saveSettings();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isPersian ? 'تنظیمات عمومی با موفقیت ذخیره شد.' : 'Settings saved successfully.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _testBotConnection() async {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';
    final token = _botTokenCtrl.text.trim();
    if (token.isEmpty) {
      setState(() => _botTestStatus = isPersian ? 'لطفاً ابتدا توکن ربات را وارد کنید.' : 'Please enter Bot Token first.');
      return;
    }

    setState(() => _botTestStatus = isPersian ? 'درحال اعتبارسنجی توکن...' : 'Verifying token...');
    try {
      final client = HttpClient();
      // Use local proxy if enabled
      if (_systemProxyEnabled) {
        final port = int.tryParse(_proxyPortCtrl.text) ?? 7890;
        client.findProxy = (uri) => 'PROXY 127.0.0.1:$port';
      }
      final req = await client.getUrl(Uri.parse('https://api.telegram.org/bot$token/getMe'));
      final resp = await req.close();
      if (resp.statusCode == 200) {
        setState(() => _botTestStatus = isPersian ? '✅ اتصال ربات با موفقیت تایید شد!' : '✅ Telegram Bot Connected Successfully!');
      } else {
        setState(() => _botTestStatus = isPersian ? '❌ توکن نامعتبر است (کد خطا: ${resp.statusCode})' : '❌ Invalid Bot Token (${resp.statusCode})');
      }
    } catch (e) {
      setState(() => _botTestStatus = isPersian ? '❌ خطا در برقراری ارتباط (پروکسی را چک کنید)' : '❌ Connection Failed ($e)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';

    return Scaffold(
      appBar: AppBar(
        title: Text(isPersian ? 'تنظیمات کلی، شبکه و ربات' : 'General & Network Settings'),
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
          // Section 1: System Proxy ("سیستم پروکسی")
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
                          const Icon(Icons.lan, color: Colors.blue, size: 28),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPersian ? 'سیستم پروکسی (System Proxy)' : 'System Proxy Settings',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                isPersian
                                    ? 'استفاده از فیلترشکن فعال سیستم جهت استخراج و دانلود منابع'
                                    : 'Route extraction & updates through system proxy / VPN',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _systemProxyEnabled,
                        onChanged: (v) => setState(() => _systemProxyEnabled = v),
                      ),
                    ],
                  ),
                  if (_systemProxyEnabled) ...[
                    const Divider(height: 24),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _proxyHostCtrl,
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: isPersian ? 'آدرس IP پروکسی' : 'Proxy Host',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _proxyPortCtrl,
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: isPersian ? 'پورت (پیش‌فرض: ۷۸۹۰)' : 'Port (7890)',
                            ),
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

          // Section 2: Telegram Bot Auto-Dispatcher
          Card(
            color: Colors.blue.shade50.withOpacity(0.4),
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
                          const Icon(Icons.send_rounded, color: Colors.blue, size: 28),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPersian ? 'ارسال خودکار به کانال تلگرام (Telegram Auto-Send)' : 'Telegram Bot Auto-Dispatcher',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                isPersian
                                    ? 'ارسال اتوماتیک فایل‌های خروجی و گزارش نتایج به کانال اختصاصی شما'
                                    : 'Automatically post tested config files to your Telegram channel',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _telegramBotEnabled,
                        onChanged: (v) => setState(() => _telegramBotEnabled = v),
                      ),
                    ],
                  ),
                  if (_telegramBotEnabled) ...[
                    const Divider(height: 24),
                    TextField(
                      controller: _botTokenCtrl,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: isPersian ? 'توکن ربات تلگرام (Bot Token)' : 'Telegram Bot Token',
                        hintText: '123456789:ABCdefGhIJKlmNoPQRsTUVwxyZ',
                        prefixIcon: const Icon(Icons.token),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _channelIdCtrl,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: isPersian ? 'آیدی کانال مقصد (مثلاً @MyChannel یا -100...)' : 'Channel Username / ID',
                        hintText: '@MyConfigChannel',
                        prefixIcon: const Icon(Icons.tag),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _testBotConnection,
                          icon: const Icon(Icons.network_check),
                          label: Text(isPersian ? 'تست اتصال ربات' : 'Test Connection'),
                        ),
                        const SizedBox(width: 12),
                        if (_botTestStatus.isNotEmpty)
                          Expanded(
                            child: Text(
                              _botTestStatus,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _botTestStatus.startsWith('✅') ? Colors.green : Colors.red,
                              ),
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

          // Section 3: Sent History Deduplication
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
                          const Icon(Icons.history, color: Colors.purple, size: 28),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPersian ? 'حافظه عدم تکرار (Sent History)' : 'Sent History Deduplication',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                isPersian
                                    ? 'جلوگیری از ارسال دوباره کانفیگ‌های تکراری به کانال تلگرام'
                                    : 'Prevent re-posting already sent configs to your Telegram channel',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _dedupEnabled,
                        onChanged: (v) => setState(() => _dedupEnabled = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 4: Mihomo Core Management
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.memory, color: Colors.orange, size: 28),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPersian ? 'مدیریت هسته میهومو (Mihomo Core Manager)' : 'Mihomo Core Management',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            isPersian ? 'معماری شناسایی‌شده پردازنده سیستم شما: $_detectedArch' : 'Detected CPU: $_detectedArch',
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Text(isPersian ? 'انتخاب نسخه هسته:' : 'Core Variant:'),
                  RadioListTile<String>(
                    title: Text(isPersian ? 'تشخیص خودکار و هوشمند (Auto - پیشنهادی)' : 'Auto Detect (Recommended)'),
                    subtitle: Text(isPersian ? 'استفاده از نسخه بهینه متناسب با پشتیبانی AVX2 سی‌پی‌یو' : 'Chooses optimal version for CPU features'),
                    value: 'auto',
                    groupValue: _preferredArch,
                    onChanged: (v) => setState(() => _preferredArch = v!),
                  ),
                  RadioListTile<String>(
                    title: const Text('windows-amd64 (حداکثر سرعت با دستورات AVX2)'),
                    value: 'amd64',
                    groupValue: _preferredArch,
                    onChanged: (v) => setState(() => _preferredArch = v!),
                  ),
                  RadioListTile<String>(
                    title: const Text('windows-amd64-compatible (سازگاری عمومی با همه پردازنده‌ها)'),
                    value: 'compatible',
                    groupValue: _preferredArch,
                    onChanged: (v) => setState(() => _preferredArch = v!),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 5: Hardware Profile
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPersian ? 'پروفایل سخت‌افزاری و توان سیستم' : 'Hardware Profile',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Divider(height: 20),
                  RadioListTile<String>(
                    title: Text(isPersian ? 'سیستم متوسط (پیش‌فرض پیشنهادی)' : 'Medium PC (Balanced)'),
                    subtitle: Text(isPersian ? 'همزمانی تست: ۳۰ | مصرف رم حدود ۲۵۰ مگابایت' : 'Concurrency: 30 | ~250MB RAM'),
                    value: 'medium',
                    groupValue: _profile,
                    onChanged: (v) => setState(() => _profile = v!),
                  ),
                  RadioListTile<String>(
                    title: Text(isPersian ? 'سیستم قوی یا سرور مجازی' : 'Strong PC / Cloud Server'),
                    subtitle: Text(isPersian ? 'همزمانی تست: ۱۰۰ | حداکثر سرعت استخراج' : 'Concurrency: 100 | Maximum speed'),
                    value: 'strong',
                    groupValue: _profile,
                    onChanged: (v) => setState(() => _profile = v!),
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
