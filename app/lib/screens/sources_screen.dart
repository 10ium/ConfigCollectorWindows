import 'package:flutter/material.dart';
import '../services/config_service.dart';

class SourcesScreen extends StatefulWidget {
  const SourcesScreen({super.key});

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  final ConfigService _config = ConfigService();

  late TextEditingController _channelsCtrl;
  late TextEditingController _providersCtrl;
  late TextEditingController _folderCtrl;

  bool _telegramEnabled = true;
  bool _providersEnabled = true;
  bool _localFolderEnabled = false;

  int _telegramDelayMs = 600;
  int _subTimeoutSec = 12;

  @override
  void initState() {
    super.initState();
    _channelsCtrl = TextEditingController();
    _providersCtrl = TextEditingController();
    _folderCtrl = TextEditingController();
    _loadFromConfig();
  }

  void _loadFromConfig() {
    final s = _config.settings['sources'] ?? {};
    final tg = s['telegram'] ?? {};
    final sub = s['subscriptions'] ?? {};
    final loc = s['local_folder'] ?? {};

    _telegramEnabled = tg['enabled'] ?? true;
    _providersEnabled = sub['enabled'] ?? true;
    _localFolderEnabled = loc['enabled'] ?? false;

    _telegramDelayMs = tg['fetch_delay_ms'] ?? tg['delay_ms'] ?? 600;
    _subTimeoutSec = sub['timeout_val'] ?? 12;

    final channels = (tg['channels'] as List?)?.join('\n') ?? '';
    final urls = (sub['urls'] as List?)?.join('\n') ?? '';
    final path = loc['path'] ?? 'G:\\Ai project\\10Dream\\decryptor\\file for test';

    _channelsCtrl.text = channels;
    _providersCtrl.text = urls;
    _folderCtrl.text = path;
  }

  @override
  void dispose() {
    _channelsCtrl.dispose();
    _providersCtrl.dispose();
    _folderCtrl.dispose();
    super.dispose();
  }

  void _saveSources() {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';

    final channelsList = _channelsCtrl.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // Auto-convert GitHub web URLs to raw URLs on the fly
    final urlsList = _providersCtrl.text
        .split('\n')
        .map((e) => ConfigService.normalizeGithubUrl(e))
        .where((e) => e.isNotEmpty)
        .toList();

    // Update text field to show converted raw links
    _providersCtrl.text = urlsList.join('\n');

    _config.updateNestedSetting('sources', 'telegram', 'enabled', _telegramEnabled);
    _config.updateNestedSetting('sources', 'telegram', 'channels', channelsList);
    _config.updateNestedSetting('sources', 'telegram', 'fetch_delay_ms', _telegramDelayMs);

    _config.updateNestedSetting('sources', 'subscriptions', 'enabled', _providersEnabled);
    _config.updateNestedSetting('sources', 'subscriptions', 'urls', urlsList);
    _config.updateNestedSetting('sources', 'subscriptions', 'timeout_val', _subTimeoutSec);

    _config.updateNestedSetting('sources', 'local_folder', 'enabled', _localFolderEnabled);
    _config.updateNestedSetting('sources', 'local_folder', 'path', _folderCtrl.text.trim());

    _config.saveSettings();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isPersian ? 'منابع با موفقیت ذخیره شدند (لینک‌های گیت‌هاب به Raw تبدیل شدند).' : 'Sources saved with GitHub Raw conversion.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';

    return Scaffold(
      appBar: AppBar(
        title: Text(isPersian ? 'مدیریت منابع استخراج' : 'Input Sources Management'),
        actions: [
          FilledButton.icon(
            onPressed: _saveSources,
            icon: const Icon(Icons.save),
            label: Text(isPersian ? 'ذخیره تغییرات' : 'Save Changes'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // Multi-Source Quick Selection Row
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.blue.withOpacity(0.3)),
            ),
            color: Theme.of(context).cardColor,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune, color: Colors.blueAccent),
                      const SizedBox(width: 10),
                      Text(
                        isPersian ? 'انتخاب و شخصی‌سازی منابع فعال (چند انتخابی):' : 'Active Sources Selection (Multi-Select):',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        avatar: Icon(Icons.telegram, size: 18, color: _telegramEnabled ? Colors.white : Colors.blue),
                        label: Text(isPersian ? 'کانال‌های تلگرام' : 'Telegram Channels'),
                        selected: _telegramEnabled,
                        onSelected: (val) => setState(() => _telegramEnabled = val),
                      ),
                      FilterChip(
                        avatar: Icon(Icons.hub, size: 18, color: _providersEnabled ? Colors.white : Colors.indigoAccent),
                        label: Text(isPersian ? 'پروکسی پروایدرها (لینک‌های اشتراک)' : 'Proxy Providers'),
                        selected: _providersEnabled,
                        onSelected: (val) => setState(() => _providersEnabled = val),
                      ),
                      FilterChip(
                        avatar: Icon(Icons.folder, size: 18, color: _localFolderEnabled ? Colors.white : Colors.amber),
                        label: Text(isPersian ? 'پوشه فایل‌های محلی' : 'Local Folder'),
                        selected: _localFolderEnabled,
                        onSelected: (val) => setState(() => _localFolderEnabled = val),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Source 1: Proxy Providers (formerly Subscriptions)
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
                          const Icon(Icons.hub, color: Colors.indigo, size: 28),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPersian ? 'پروکسی پروایدرها (Proxy Providers)' : 'Proxy Providers (Subscriptions)',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                isPersian
                                    ? 'لینک‌های سابسکریپشن کلش و فایل‌های آنلاین متنی یا YAML'
                                    : 'Clash subscription URLs & online text/yaml files',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _providersEnabled,
                        onChanged: (v) => setState(() => _providersEnabled = v),
                      ),
                    ],
                  ),
                  if (_providersEnabled) ...[
                    const Divider(height: 24),
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.indigo.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_fix_high, size: 18, color: Colors.indigoAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isPersian
                                  ? 'تبدیل خودکار لینک‌های گیت‌هاب فعال است: لینک‌های حاوی github.com/blob خودکار به فرمت فایل خام (Raw) تبدیل می‌شوند.'
                                  : 'GitHub raw auto-conversion active: blob URLs automatically convert to raw.githubusercontent.com.',
                              style: const TextStyle(fontSize: 11, color: Colors.indigoAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextField(
                      controller: _providersCtrl,
                      maxLines: 5,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: 'https://example.com/sub/all.yaml\nhttps://example.com/sub2.txt',
                        labelText: isPersian ? 'آدرس لینک‌های پروکسی پروایدر (هر خط یک آدرس)' : 'Proxy Provider URLs (One per line)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isPersian
                          ? 'مهلت دریافت پاسخ از سرور پروایدر: $_subTimeoutSec ثانیه'
                          : 'Subscription Request Timeout: $_subTimeoutSec s',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Slider(
                      min: 5,
                      max: 60,
                      divisions: 11,
                      value: _subTimeoutSec.toDouble(),
                      onChanged: (v) => setState(() => _subTimeoutSec = v.toInt()),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Source 2: Telegram Channels
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
                          const Icon(Icons.telegram, color: Colors.blue, size: 28),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPersian ? 'کانال‌های تلگرام (Telegram Channels)' : 'Telegram Channels',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                isPersian
                                    ? 'استخراج خودکار آخرین کانفیگ‌های منتشرشده در پیام‌های کانال‌ها'
                                    : 'Auto-scrape proxy configs from public channel posts',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _telegramEnabled,
                        onChanged: (v) => setState(() => _telegramEnabled = v),
                      ),
                    ],
                  ),
                  if (_telegramEnabled) ...[
                    const Divider(height: 24),
                    TextField(
                      controller: _channelsCtrl,
                      maxLines: 5,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: '@Channel1\n@Channel2\nhttps://t.me/s/Channel3',
                        labelText: isPersian ? 'آیدی یا لینک کانال‌ها (هر خط یک کانال)' : 'Channel IDs or Links (One per line)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isPersian
                          ? 'وقفه بین واکشی پست‌های کانال‌های تلگرام: $_telegramDelayMs میلی‌ثانیه'
                          : 'Telegram Fetch Delay: $_telegramDelayMs ms',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Slider(
                      min: 100,
                      max: 2000,
                      divisions: 19,
                      value: _telegramDelayMs.toDouble(),
                      onChanged: (v) => setState(() => _telegramDelayMs = v.toInt()),
                    ),
                    Text(
                      isPersian
                          ? 'نکته: وقفه بین کانال‌های تلگرام برای پیشگیری از بلاک شدن آی‌پی توسط وب تلگرام است.'
                          : 'Note: This delay prevents Telegram Web from rate-limiting or blocking IP requests.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Source 3: Local Folder
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
                          const Icon(Icons.folder_open, color: Colors.amber, size: 28),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPersian ? 'پوشه فایل‌های محلی (Local Folder)' : 'Local File Directory',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                isPersian
                                    ? 'اسکن خودکار انواع فرمت‌ها (.ovpn, .ehi, .nm, .hat, .dark, .ssc, .txt, .yaml)'
                                    : 'Auto-scan files (.ovpn, .ehi, .nm, .hat, .dark, .ssc, .txt, .yaml)',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _localFolderEnabled,
                        onChanged: (v) => setState(() => _localFolderEnabled = v),
                      ),
                    ],
                  ),
                  if (_localFolderEnabled) ...[
                    const Divider(height: 24),
                    TextField(
                      controller: _folderCtrl,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: isPersian ? 'مسیر پوشه روی سیستم' : 'Directory Path',
                        suffixIcon: const Icon(Icons.drive_file_move_outline),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
