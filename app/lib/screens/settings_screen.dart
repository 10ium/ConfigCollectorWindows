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

  // Network Proxy Mode: 'system_proxy', 'socks5', 'http', 'direct'
  String _networkMode = 'system_proxy';
  late TextEditingController _proxyHostCtrl;
  late TextEditingController _proxyPortCtrl;

  // Proxy & Internet Health Check
  bool _isCheckingProxy = false;
  Map<String, dynamic>? _proxyHealthResult;

  // Telegram Bot Dispatcher
  bool _telegramBotEnabled = false;
  late TextEditingController _botTokenCtrl;
  late TextEditingController _channelIdCtrl;
  late TextEditingController _captionCtrl;
  late TextEditingController _headerTextCtrl;
  late TextEditingController _footerTextCtrl;
  String _messageMode = 'both';
  bool _sendFiles = true;
  bool _sendSummary = true;
  String _botTestStatus = '';

  // Mihomo Core Architecture & Manager
  String _preferredArch = 'windows-amd64';
  String _detectedArch = 'windows-amd64';
  bool _isCheckingCore = false;
  Map<String, dynamic>? _coreStatus;
  bool _isDownloadingCore = false;
  double _coreDownloadProgress = 0.0;
  String _coreDownloadMsg = '';

  // In-App Update State
  bool _isCheckingUpdate = false;
  String _updateStatus = '';
  String? _updateReleaseUrl;

  @override
  void initState() {
    super.initState();
    _proxyHostCtrl = TextEditingController(text: '127.0.0.1');
    _proxyPortCtrl = TextEditingController(text: '7890');
    _botTokenCtrl = TextEditingController();
    _channelIdCtrl = TextEditingController();
    _captionCtrl = TextEditingController(text: '⚡ کانفیگ‌های تازه استخراج‌شده توسط Freedom Config Collector v2');
    _headerTextCtrl = TextEditingController(text: '⚡ مجموعه کانفیگ‌های تاییدشده Freedom Config Collector v2');
    _footerTextCtrl = TextEditingController(text: '🌐 ساخته‌شده با عشق برای دسترسی آزاد به اینترنت');
    _detectSystemArchitecture();
    _loadFromConfig();
    _checkCoreStatusQuietly();
  }

  void _detectSystemArchitecture() {
    if (Platform.isWindows) {
      final arch = Platform.environment['PROCESSOR_ARCHITECTURE'] ?? '';
      if (arch.contains('ARM') || arch.contains('64') && Platform.environment['PROCESSOR_ARCHITEW6432']?.contains('ARM') == true) {
        _detectedArch = 'windows-arm64';
      } else if (arch.contains('64')) {
        _detectedArch = 'windows-amd64';
      } else {
        _detectedArch = 'windows-386';
      }
    }
  }

  void _loadFromConfig() {
    final net = _config.settings['network'] ?? {};
    _networkMode = net['mode'] ?? 'system_proxy';
    _proxyHostCtrl.text = net['proxy_host'] ?? '127.0.0.1';
    _proxyPortCtrl.text = '${net['proxy_port'] ?? 7890}';

    final tg = _config.settings['telegram_sender'] ?? {};
    _telegramBotEnabled = tg['enabled'] ?? false;
    _botTokenCtrl.text = tg['bot_token'] ?? '';
    _channelIdCtrl.text = tg['channel_id'] ?? '';
    _captionCtrl.text = tg['custom_caption'] ?? tg['caption'] ?? '⚡ کانفیگ‌های تازه استخراج‌شده توسط Freedom Config Collector v2';
    _messageMode = tg['message_mode'] ?? 'both';
    _headerTextCtrl.text = tg['header_text'] ?? '⚡ مجموعه کانفیگ‌های تاییدشده Freedom Config Collector v2';
    _footerTextCtrl.text = tg['footer_text'] ?? '🌐 ساخته‌شده با عشق برای دسترسی آزاد به اینترنت';
    _sendFiles = tg['send_files'] ?? true;
    _sendSummary = tg['send_summary'] ?? true;

    final cm = _config.settings['core_manager'] ?? {};
    _preferredArch = cm['preferred_arch'] ?? _detectedArch;
  }

  @override
  void dispose() {
    _proxyHostCtrl.dispose();
    _proxyPortCtrl.dispose();
    _botTokenCtrl.dispose();
    _channelIdCtrl.dispose();
    _captionCtrl.dispose();
    _headerTextCtrl.dispose();
    _footerTextCtrl.dispose();
    super.dispose();
  }

  void _autoSaveQuietly() {
    _config.updateSetting('network', 'mode', _networkMode);
    _config.updateSetting('network', 'proxy_host', _proxyHostCtrl.text.trim());
    _config.updateSetting('network', 'proxy_port', int.tryParse(_proxyPortCtrl.text.trim()) ?? 7890);

    _config.updateSetting('telegram_sender', 'enabled', _telegramBotEnabled);
    _config.updateSetting('telegram_sender', 'bot_token', _botTokenCtrl.text.trim());
    _config.updateSetting('telegram_sender', 'channel_id', _channelIdCtrl.text.trim());
    _config.updateSetting('telegram_sender', 'custom_caption', _captionCtrl.text.trim());
    _config.updateSetting('telegram_sender', 'message_mode', _messageMode);
    _config.updateSetting('telegram_sender', 'header_text', _headerTextCtrl.text.trim());
    _config.updateSetting('telegram_sender', 'footer_text', _footerTextCtrl.text.trim());
    _config.updateSetting('telegram_sender', 'send_files', _sendFiles);
    _config.updateSetting('telegram_sender', 'send_summary', _sendSummary);

    _config.updateSetting('core_manager', 'preferred_arch', _preferredArch);
  }

  void _saveSettingsExplicit() {
    _autoSaveQuietly();
    _config.saveSettings();
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isPersian ? 'تنظیمات با موفقیت ذخیره شد.' : 'Settings saved successfully.'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  void _resetToDefaults() {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isPersian ? 'بازنشانی تنظیمات به پیش‌فرض' : 'Reset to Default Settings'),
        content: Text(
          isPersian
              ? 'آیا مطمئن هستید که می‌خواهید تمام تنظیمات برنامه را به مقادیر پیش‌فرض اولیه بازگردانید؟'
              : 'Are you sure you want to restore all settings to default values?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isPersian ? 'انصراف' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _config.resetToDefaults();
              _loadFromConfig();
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isPersian ? 'کلیه تنظیمات به حالت پیش‌فرض اولیه بازگردانده شدند.' : 'Settings restored to defaults.'),
                  backgroundColor: Colors.teal,
                ),
              );
            },
            child: Text(isPersian ? 'بازنشانی' : 'Reset'),
          ),
        ],
      ),
    );
  }

  void _checkCoreStatusQuietly() async {
    final status = await _config.checkMihomoCoreStatus();
    if (mounted) {
      setState(() => _coreStatus = status);
    }
  }

  void _checkCoreStatusExplicit() async {
    setState(() => _isCheckingCore = true);
    final status = await _config.checkMihomoCoreStatus();
    if (mounted) {
      setState(() {
        _isCheckingCore = false;
        _coreStatus = status;
      });
    }
  }

  void _downloadCore() async {
    setState(() {
      _isDownloadingCore = true;
      _coreDownloadProgress = 0.05;
      _coreDownloadMsg = 'در حال آماده‌سازی دانلود...';
    });

    final success = await _config.downloadMihomoCore(
      onProgress: (prog, msg) {
        if (mounted) {
          setState(() {
            _coreDownloadProgress = prog;
            _coreDownloadMsg = msg;
          });
        }
      },
    );

    if (mounted) {
      setState(() => _isDownloadingCore = false);
      _checkCoreStatusExplicit();
      final isPersian = Localizations.localeOf(context).languageCode == 'fa';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? (isPersian ? 'هسته Mihomo با موفقیت دریافت و آماده شد!' : 'Mihomo Core installed successfully!')
                : (isPersian ? 'خطا در دریافت هسته Mihomo.' : 'Failed to download core.'),
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _testProxyConnection() async {
    setState(() {
      _isCheckingProxy = true;
      _proxyHealthResult = null;
    });

    final res = await _config.checkProxyHealth();
    if (mounted) {
      setState(() {
        _isCheckingProxy = false;
        _proxyHealthResult = res;
      });
    }
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
      if (_networkMode == 'system_proxy' || _networkMode == 'http' || _networkMode == 'socks5') {
        final port = int.tryParse(_proxyPortCtrl.text) ?? 7890;
        client.findProxy = (uri) => 'PROXY 127.0.0.1:$port';
      }
      final req = await client.getUrl(Uri.parse('https://api.telegram.org/bot$token/getMe'));
      final resp = await req.close();
      if (resp.statusCode == 200) {
        setState(() => _botTestStatus = isPersian ? '✅ اتصال برقرار شد! ربات تلگرام تایید شد.' : '✅ Connected successfully!');
      } else {
        setState(() => _botTestStatus = isPersian ? '❌ خطا در احراز هویت توکن (${resp.statusCode}).' : '❌ Error: Status ${resp.statusCode}');
      }
    } catch (e) {
      setState(() => _botTestStatus = isPersian ? '⚠️ خطا در اتصال به تلگرام: $e' : '⚠️ Connection failed: $e');
    }
  }

  void _checkSoftwareUpdate() async {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';
    setState(() {
      _isCheckingUpdate = true;
      _updateStatus = isPersian ? 'درحال ارتباط با سرورهای گیت‌هاب...' : 'Checking GitHub releases...';
      _updateReleaseUrl = null;
    });

    final res = await _config.checkUpdate();
    if (mounted) {
      setState(() {
        _isCheckingUpdate = false;
        if (res['hasUpdate'] == true) {
          _updateStatus = isPersian
              ? '🚀 نسخه جدید ${res['latestVersion']} منتشر شده است!'
              : '🚀 New update ${res['latestVersion']} available!';
          _updateReleaseUrl = res['releaseUrl'];
        } else {
          _updateStatus = isPersian
              ? '✅ شما از آخرین نسخه (v2.0.0) استفاده می‌کنید.'
              : '✅ You are running the latest version (v2.0.0).';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';

    return Scaffold(
      appBar: AppBar(
        title: Text(isPersian ? 'تنظیمات عمومی، پروکسی و هسته' : 'General, Network & Core Settings'),
        actions: [
          IconButton(
            tooltip: isPersian ? 'بازنشانی به پیش‌فرض' : 'Reset to Defaults',
            icon: const Icon(Icons.restart_alt),
            onPressed: _resetToDefaults,
          ),
          IconButton(
            tooltip: isPersian ? 'ذخیره تنظیمات' : 'Save Settings',
            icon: const Icon(Icons.save),
            onPressed: _saveSettingsExplicit,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // Section 1: In-App Update Checker
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
                    children: [
                      const Icon(Icons.system_update, color: Colors.blueAccent, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPersian ? 'بروزرسانی نرم‌افزار (Freedom Config Collector v2.0.0)' : 'Software Update (v2.0.0)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              isPersian ? 'بررسی آخرین انتشارهای رسمی مخزن گیت‌هاب' : 'Check latest official GitHub repository releases',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _isCheckingUpdate ? null : _checkSoftwareUpdate,
                        icon: _isCheckingUpdate
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.sync),
                        label: Text(isPersian ? 'بررسی نسخه جدید' : 'Check Now'),
                      ),
                    ],
                  ),
                  if (_updateStatus.isNotEmpty) ...[
                    const Divider(height: 20),
                    Row(
                      children: [
                        Text(_updateStatus, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const Spacer(),
                        if (_updateReleaseUrl != null)
                          TextButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: Text(isPersian ? 'مشاهده در گیت‌هاب' : 'View on GitHub'),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 2: Network & Proxy Mode (System Proxy, SOCKS5, HTTP, Direct)
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
                    children: [
                      const Icon(Icons.alt_route, color: Colors.tealAccent, size: 28),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPersian ? 'پروکسی شبکه جهت اتصال به منابع (Proxy for Sources)' : 'Network Proxy Mode',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            isPersian
                                ? 'جهت دور زدن فیلترینگ هنگام دانلود سابسکریپشن‌ها و اتصال به تلگرام (تست نودها مستقیم انجام می‌شود)'
                                : 'For bypassing blocking during source fetching and Telegram dispatch',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'system_proxy',
                        label: Text(isPersian ? 'سیستم پروکسی' : 'System Proxy'),
                      ),
                      ButtonSegment(
                        value: 'socks5',
                        label: Text('SOCKS5'),
                      ),
                      ButtonSegment(
                        value: 'http',
                        label: Text('HTTP'),
                      ),
                      ButtonSegment(
                        value: 'direct',
                        label: Text(isPersian ? 'مستقیم (Direct)' : 'Direct'),
                      ),
                    ],
                    selected: {_networkMode},
                    onSelectionChanged: (set) {
                      setState(() => _networkMode = set.first);
                      _autoSaveQuietly();
                    },
                  ),
                  if (_networkMode != 'direct') ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _proxyHostCtrl,
                            onChanged: (_) => _autoSaveQuietly(),
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: isPersian ? 'آدرس هاست پروکسی' : 'Proxy Host',
                              hintText: '127.0.0.1',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _proxyPortCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _autoSaveQuietly(),
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: isPersian ? 'پورت' : 'Port',
                              hintText: '7890',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _isCheckingProxy ? null : _testProxyConnection,
                        icon: _isCheckingProxy
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.network_check),
                        label: Text(isPersian ? 'تست اتصال پروکسی به اینترنت (گوگل و تلگرام)' : 'Test Proxy Health'),
                      ),
                    ],
                  ),
                  if (_proxyHealthResult != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  _proxyHealthResult!['telegramOk'] == true ? Icons.check_circle : Icons.cancel,
                                  color: _proxyHealthResult!['telegramOk'] == true ? Colors.greenAccent : Colors.redAccent,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _proxyHealthResult!['telegramOk'] == true
                                        ? (isPersian ? 'تلگرام: متصل (${_proxyHealthResult!['telegramPing']}ms)' : 'Telegram: OK')
                                        : (isPersian ? 'تلگرام: قطع یا مسدود' : 'Telegram: Blocked'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: _proxyHealthResult!['telegramOk'] == true ? Colors.greenAccent : Colors.redAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  _proxyHealthResult!['googleOk'] == true ? Icons.check_circle : Icons.cancel,
                                  color: _proxyHealthResult!['googleOk'] == true ? Colors.greenAccent : Colors.redAccent,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _proxyHealthResult!['googleOk'] == true
                                        ? (isPersian ? 'گوگل: متصل (${_proxyHealthResult!['googlePing']}ms)' : 'Google: OK')
                                        : (isPersian ? 'گوگل: قطع یا مسدود' : 'Google: Blocked'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: _proxyHealthResult!['googleOk'] == true ? Colors.greenAccent : Colors.redAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 3: Telegram Sender
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.lightBlueAccent.withOpacity(0.25)),
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
                          const Icon(Icons.send_rounded, color: Colors.lightBlueAccent, size: 28),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPersian ? 'ارسال خودکار به کانال تلگرام (Telegram Dispatcher)' : 'Telegram Channel Auto-Dispatcher',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                isPersian ? 'انتشار خودکار فایل‌های خروجی و گزارش نتایج در کانال' : 'Automatically pushes tested configs to your channel',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _telegramBotEnabled,
                        onChanged: (v) {
                          setState(() => _telegramBotEnabled = v);
                          _autoSaveQuietly();
                        },
                      ),
                    ],
                  ),
                  if (_telegramBotEnabled) ...[
                    const Divider(height: 24),
                    TextField(
                      controller: _botTokenCtrl,
                      obscureText: true,
                      onChanged: (_) => _autoSaveQuietly(),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: isPersian ? 'توکن ربات تلگرام (Bot Token)' : 'Bot Token',
                        hintText: '123456789:ABCdefGHIjklMNO...',
                        prefixIcon: const Icon(Icons.token),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _channelIdCtrl,
                      onChanged: (_) => _autoSaveQuietly(),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: isPersian ? 'آیدی کانال مقصد (Channel ID / Username)' : 'Channel Username / ID',
                        hintText: '@MyConfigChannel or -1001234567890',
                        prefixIcon: const Icon(Icons.campaign),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isPersian ? 'نحوه و محل درج متن سفارشی در پیام ارسالی کانال:' : 'Custom Message Placement:',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'no_text',
                          label: Text(isPersian ? 'بدون متن' : 'No Text'),
                        ),
                        ButtonSegment(
                          value: 'header_only',
                          label: Text(isPersian ? 'فقط خط اول' : 'Header Only'),
                        ),
                        ButtonSegment(
                          value: 'footer_only',
                          label: Text(isPersian ? 'فقط خط آخر' : 'Footer Only'),
                        ),
                        ButtonSegment(
                          value: 'both',
                          label: Text(isPersian ? 'هردو (ابتدا و انتها)' : 'Both'),
                        ),
                      ],
                      selected: {_messageMode},
                      onSelectionChanged: (set) {
                        setState(() => _messageMode = set.first);
                        _autoSaveQuietly();
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_messageMode == 'header_only' || _messageMode == 'both') ...[
                      TextField(
                        controller: _headerTextCtrl,
                        maxLines: 2,
                        onChanged: (_) => _autoSaveQuietly(),
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: isPersian ? 'متن خط اول پیام (Header / هدر سفارشی)' : 'Header Text (First Line)',
                          hintText: isPersian ? '⚡ مجموعه کانفیگ‌های تاییدشده...' : 'Custom header...',
                          prefixIcon: const Icon(Icons.vertical_align_top),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_messageMode == 'footer_only' || _messageMode == 'both') ...[
                      TextField(
                        controller: _footerTextCtrl,
                        maxLines: 2,
                        onChanged: (_) => _autoSaveQuietly(),
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: isPersian ? 'متن آخرین خط پیام (Footer / فوتر و امضا)' : 'Footer Text (Last Line)',
                          hintText: isPersian ? '🌐 ساخته‌شده با عشق برای دسترسی آزاد...' : 'Custom footer...',
                          prefixIcon: const Icon(Icons.vertical_align_bottom),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    CheckboxListTile(
                      title: Text(isPersian ? 'ارسال فایل‌های خروجی (کلش، ایکس‌ری و سینگ‌باکس)' : 'Send Export Files'),
                      value: _sendFiles,
                      onChanged: (v) {
                        setState(() => _sendFiles = v ?? true);
                        _autoSaveQuietly();
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      title: Text(isPersian ? 'ارسال گزارش آماری خلاصه نتایج' : 'Send Summary Stats Report'),
                      value: _sendSummary,
                      onChanged: (v) {
                        setState(() => _sendSummary = v ?? true);
                        _autoSaveQuietly();
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _testBotConnection,
                          icon: const Icon(Icons.wifi_find),
                          label: Text(isPersian ? 'تست اتصال ربات' : 'Test Bot Connection'),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _botTestStatus,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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

          // Section 4: Mihomo Core Manager & CPU Architecture
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.orangeAccent.withOpacity(0.25)),
            ),
            color: Theme.of(context).cardColor,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.memory, color: Colors.orangeAccent, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPersian ? 'مدیریت و بروزرسانی هسته Mihomo' : 'Mihomo Core Manager',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              isPersian
                                  ? 'تشخیص نسخه هسته، بررسی انتشارهای MetaCubeX و دانلود مستقیم'
                                  : 'Inspect local binary, compare with upstream MetaCubeX and download',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _isCheckingCore ? null : _checkCoreStatusExplicit,
                        icon: _isCheckingCore
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh),
                        label: Text(isPersian ? 'بررسی هسته' : 'Check Core'),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  if (_coreStatus != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                _coreStatus!['installed'] == true ? Icons.check_circle : Icons.warning_amber_rounded,
                                color: _coreStatus!['installed'] == true ? Colors.greenAccent : Colors.orangeAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isPersian ? 'نسخه نصب‌شده در سیستم: ' : 'Installed version: ',
                                style: const TextStyle(fontSize: 13),
                              ),
                              Text(
                                '${_coreStatus!['installedVersion']}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const Spacer(),
                              Text(
                                isPersian ? 'آخرین انتشار مخزن: ' : 'Upstream: ',
                                style: const TextStyle(fontSize: 13),
                              ),
                              Text(
                                '${_coreStatus!['latestVersion']}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueAccent),
                              ),
                            ],
                          ),
                          if (_coreStatus!['downloadUrl'] != null && (_coreStatus!['downloadUrl'] as String).isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                FilledButton.icon(
                                  onPressed: _isDownloadingCore ? null : _downloadCore,
                                  icon: _isDownloadingCore
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.download),
                                  label: Text(
                                    _coreStatus!['installed'] == true
                                        ? (isPersian ? 'بروزرسانی هسته به آخرین نسخه' : 'Update Core')
                                        : (isPersian ? 'دانلود و نصب هسته Mihomo' : 'Download Mihomo Core'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (_isDownloadingCore)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        LinearProgressIndicator(value: _coreDownloadProgress),
                                        const SizedBox(height: 4),
                                        Text(_coreDownloadMsg, style: const TextStyle(fontSize: 11)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    isPersian ? 'انتخاب معماری پردازنده جهت دریافت هسته (سیستم شما: $_detectedArch):' : 'Processor Architecture Profile:',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<String>(
                    title: Text(isPersian ? '۱. windows-amd64 (مدرن با AVX/AVX2 - حداکثر بازدهی)' : '1. windows-amd64 (Modern AVX/AVX2)'),
                    subtitle: Text(
                      isPersian ? 'مناسب برای اکثر سیستم‌های جدید ۶۴ بیتی اینتل و AMD' : 'Recommended for modern 64-bit Intel & AMD processors',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
                    value: 'windows-amd64',
                    groupValue: _preferredArch,
                    onChanged: (v) {
                      setState(() => _preferredArch = v!);
                      _autoSaveQuietly();
                    },
                  ),
                  RadioListTile<String>(
                    title: Text(isPersian ? '۲. windows-amd64-compatible (سازگاری عمومی بدون کرش)' : '2. windows-amd64-compatible'),
                    subtitle: Text(
                      isPersian ? 'مناسب برای پردازنده‌های قدیمی‌تر فاقد AVX2 جهت جلوگیری از بسته شدن برنامه' : 'Universal compatibility for older 64-bit CPUs',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
                    value: 'windows-amd64-compatible',
                    groupValue: _preferredArch,
                    onChanged: (v) {
                      setState(() => _preferredArch = v!);
                      _autoSaveQuietly();
                    },
                  ),
                  RadioListTile<String>(
                    title: Text(isPersian ? '۳. windows-arm64 (سرفیس پرو و پردازنده‌های اسنپ‌دراگون)' : '3. windows-arm64 (Surface / Snapdragon)'),
                    subtitle: Text(
                      isPersian ? 'مناسب برای ویندوزهای مبتنی بر معماری ARM64' : 'Native binary for ARM64 Windows PCs',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
                    value: 'windows-arm64',
                    groupValue: _preferredArch,
                    onChanged: (v) {
                      setState(() => _preferredArch = v!);
                      _autoSaveQuietly();
                    },
                  ),
                  RadioListTile<String>(
                    title: Text(isPersian ? '۴. windows-386 (سیستم‌های ۳۲ بیتی)' : '4. windows-386 (32-bit Legacy)'),
                    subtitle: Text(
                      isPersian ? 'سازگار با ویندوزهای قدیمی ۳۲ بیتی' : 'Legacy 32-bit Windows systems',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
                    value: 'windows-386',
                    groupValue: _preferredArch,
                    onChanged: (v) {
                      setState(() => _preferredArch = v!);
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
