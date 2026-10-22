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
    _autoSaveQuietly();
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isPersian ? 'منابع با موفقیت ذخیره شدند (لینک‌های گیت‌هاب به Raw تبدیل شدند).' : 'Sources saved with GitHub Raw conversion.'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _autoSaveQuietly() {
    final channelsList = _channelsCtrl.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final urlsList = _providersCtrl.text
        .split('\n')
        .map((e) => ConfigService.normalizeGithubUrl(e))
        .where((e) => e.isNotEmpty)
        .toList();

    _config.updateNestedSetting('sources', 'telegram', 'enabled', _telegramEnabled);
    _config.updateNestedSetting('sources', 'telegram', 'channels', channelsList);
    _config.updateNestedSetting('sources', 'telegram', 'fetch_delay_ms', _telegramDelayMs);

    _config.updateNestedSetting('sources', 'subscriptions', 'enabled', _providersEnabled);
    _config.updateNestedSetting('sources', 'subscriptions', 'urls', urlsList);
    _config.updateNestedSetting('sources', 'subscriptions', 'timeout_val', _subTimeoutSec);

    _config.updateNestedSetting('sources', 'local_folder', 'enabled', _localFolderEnabled);
    _config.updateNestedSetting('sources', 'local_folder', 'path', _folderCtrl.text.trim());

    _config.saveSettings();
  }

  void _resetToDefaults() {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';
    setState(() {
      _telegramEnabled = true;
      _providersEnabled = true;
      _localFolderEnabled = false;
      _telegramDelayMs = 600;
      _subTimeoutSec = 12;
      _channelsCtrl.text = '@vless_collector\n@v2ray_free_conf';
      _providersCtrl.text = 'https://raw.githubusercontent.com/yebekhe/TVC/main/subscriptions/xray/normal/mix';
      _folderCtrl.text = 'G:\\Ai project\\10Dream\\decryptor\\file for test';
    });
    _autoSaveQuietly();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isPersian ? 'تنظیمات منابع به مقادیر پیش‌فرض بازگردانی شدند.' : 'Sources reset to defaults.'),
        backgroundColor: Colors.blueAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildSteppedSlider({
    required String label,
    required String valueDisplay,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required double step,
    required ValueChanged<double> onChanged,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
              ),
              child: Text(
                valueDisplay,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 22),
              onPressed: value > min
                  ? () {
                      final newVal = (value - step).clamp(min, max);
                      onChanged(newVal);
                    }
                  : null,
              tooltip: '-$step',
            ),
            Expanded(
              child: Slider(
                min: min,
                max: max,
                divisions: divisions,
                value: value.clamp(min, max),
                onChanged: onChanged,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 22),
              onPressed: value < max
                  ? () {
                      final newVal = (value + step).clamp(min, max);
                      onChanged(newVal);
                    }
                  : null,
              tooltip: '+$step',
            ),
          ],
        ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Text(hint, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';

    return Scaffold(
      appBar: AppBar(
        title: Text(isPersian ? 'مدیریت منابع استخراج' : 'Input Sources Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: isPersian ? 'بازگردانی به مقادیر پیش‌فرض' : 'Reset to Defaults',
            onPressed: _resetToDefaults,
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _saveSources,
            icon: const Icon(Icons.save),
            label: Text(isPersian ? 'ذخیره دستی' : 'Save'),
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
                        onSelected: (val) {
                          setState(() => _telegramEnabled = val);
                          _autoSaveQuietly();
                        },
                      ),
                      FilterChip(
                        avatar: Icon(Icons.hub, size: 18, color: _providersEnabled ? Colors.white : Colors.indigoAccent),
                        label: Text(isPersian ? 'پروکسی پروایدرها (لینک‌های اشتراک)' : 'Proxy Providers'),
                        selected: _providersEnabled,
                        onSelected: (val) {
                          setState(() => _providersEnabled = val);
                          _autoSaveQuietly();
                        },
                      ),
                      FilterChip(
                        avatar: Icon(Icons.folder, size: 18, color: _localFolderEnabled ? Colors.white : Colors.amber),
                        label: Text(isPersian ? 'پوشه فایل‌های محلی' : 'Local Folder'),
                        selected: _localFolderEnabled,
                        onSelected: (val) {
                          setState(() => _localFolderEnabled = val);
                          _autoSaveQuietly();
                        },
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
                        onChanged: (v) {
                          setState(() => _providersEnabled = v);
                          _autoSaveQuietly();
                        },
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
                      onChanged: (_) => _autoSaveQuietly(),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: 'https://example.com/sub/all.yaml\nhttps://example.com/sub2.txt',
                        labelText: isPersian ? 'آدرس لینک‌های پروکسی پروایدر (هر خط یک آدرس)' : 'Proxy Provider URLs (One per line)',
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildSteppedSlider(
                      label: isPersian ? 'مهلت دریافت پاسخ از سرور پروایدر:' : 'Subscription Request Timeout:',
                      valueDisplay: isPersian ? '$_subTimeoutSec ثانیه' : '$_subTimeoutSec s',
                      value: _subTimeoutSec.toDouble(),
                      min: 5,
                      max: 60,
                      divisions: 55, // exactly 1.0s per step: (60 - 5) / 55 = 1!
                      step: 1.0,
                      onChanged: (v) {
                        setState(() => _subTimeoutSec = v.toInt());
                        _autoSaveQuietly();
                      },
                      hint: isPersian
                          ? 'تنظیم دقیق ۱ ثانیه به ۱ ثانیه (با دکمه‌های + و - یا لغزنده).'
                          : 'Fine-tune 1 second at a time with +/- buttons or slider.',
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
                        onChanged: (v) {
                          setState(() => _telegramEnabled = v);
                          _autoSaveQuietly();
                        },
                      ),
                    ],
                  ),
                  if (_telegramEnabled) ...[
                    const Divider(height: 24),
                    TextField(
                      controller: _channelsCtrl,
                      maxLines: 5,
                      onChanged: (_) => _autoSaveQuietly(),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: '@Channel1\n@Channel2\nhttps://t.me/s/Channel3',
                        labelText: isPersian ? 'آیدی یا لینک کانال‌ها (هر خط یک کانال)' : 'Channel IDs or Links (One per line)',
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildSteppedSlider(
                      label: isPersian ? 'وقفه بین واکشی پست‌های کانال‌های تلگرام:' : 'Telegram Fetch Delay:',
                      valueDisplay: isPersian ? '$_telegramDelayMs میلی‌ثانیه' : '$_telegramDelayMs ms',
                      value: _telegramDelayMs.toDouble(),
                      min: 100,
                      max: 2000,
                      divisions: 38, // 50 ms per step: (2000 - 100) / 38 = 50.0!
                      step: 50.0,
                      onChanged: (v) {
                        setState(() => _telegramDelayMs = v.toInt());
                        _autoSaveQuietly();
                      },
                      hint: isPersian
                          ? 'نکته: وقفه بین کانال‌های تلگرام برای پیشگیری از بلاک شدن آی‌پی توسط وب تلگرام است.'
                          : 'Note: This delay prevents Telegram Web from rate-limiting or blocking IP requests.',
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
                        onChanged: (v) {
                          setState(() => _localFolderEnabled = v);
                          _autoSaveQuietly();
                        },
                      ),
                    ],
                  ),
                  if (_localFolderEnabled) ...[
                    const Divider(height: 24),
                    TextField(
                      controller: _folderCtrl,
                      onChanged: (_) => _autoSaveQuietly(),
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
