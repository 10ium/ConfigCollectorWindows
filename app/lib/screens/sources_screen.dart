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

    final urlsList = _providersCtrl.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    _config.updateNestedSetting('sources', 'telegram', 'enabled', _telegramEnabled);
    _config.updateNestedSetting('sources', 'telegram', 'channels', channelsList);

    _config.updateNestedSetting('sources', 'subscriptions', 'enabled', _providersEnabled);
    _config.updateNestedSetting('sources', 'subscriptions', 'urls', urlsList);

    _config.updateNestedSetting('sources', 'local_folder', 'enabled', _localFolderEnabled);
    _config.updateNestedSetting('sources', 'local_folder', 'path', _folderCtrl.text.trim());

    _config.saveSettings();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isPersian ? 'منابع با موفقیت ذخیره شدند.' : 'Sources saved successfully.'),
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
          // Banner
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isPersian
                          ? 'نام این بخش طبق استاندارد به «پروکسی پروایدر» (Proxy Provider) به‌روزرسانی شد. می‌توانید لینک‌های اشتراک و کانال‌های تلگرام را در هر سطر جداگانه وارد کنید.'
                          : 'Sources updated to "Proxy Provider". Enter subscription links and Telegram channels one per line.',
                      style: const TextStyle(color: Colors.blue),
                    ),
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
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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
                    TextField(
                      controller: _providersCtrl,
                      maxLines: 5,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: 'https://example.com/sub/all.yaml\nhttps://example.com/sub2.txt',
                        labelText: isPersian ? 'آدرس لینک‌های پروکسی پروایدر (هر خط یک آدرس)' : 'Proxy Provider URLs (One per line)',
                      ),
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
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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
