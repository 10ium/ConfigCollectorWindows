import 'package:flutter/material.dart';

class SourcesScreen extends StatefulWidget {
  const SourcesScreen({super.key});

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  bool _telegramEnabled = true;
  bool _subscriptionsEnabled = true;
  bool _localFolderEnabled = false;

  final TextEditingController _channelsCtrl = TextEditingController(
    text: '@V2ray20261\n@MatinSenPaii\n@Config724\n@PewezaVPN\n@AzadNet\n@DirectVPN',
  );

  final TextEditingController _subsCtrl = TextEditingController(
    text: 'https://raw.githubusercontent.com/10Dream/VpnClashFaCollector/refs/heads/main/sub/all/mixed.txt\nhttps://raw.githubusercontent.com/mahsanet/MahsaFreeConfig/refs/heads/main/mci/sub_1.txt',
  );

  final TextEditingController _folderCtrl = TextEditingController(
    text: 'C:\\Configs',
  );

  @override
  void dispose() {
    _channelsCtrl.dispose();
    _subsCtrl.dispose();
    _folderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';

    return Scaffold(
      appBar: AppBar(
        title: Text(isPersian ? 'منابع ورودی جمع‌آوری' : 'Input Sources Management'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // Info banner
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
                          ? 'هر سه منبع ورودی کاملاً مستقل هستند. می‌توانید هر یک از آن‌ها را به تنهایی یا چند مورد را همزمان فعال کنید.'
                          : 'All three sources are fully independent. You can activate any single source or any combination simultaneously.',
                      style: const TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Source 1: Telegram Channels
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: Text(
                      isPersian ? 'کانال‌های تلگرام (صفحات عمومی وب)' : 'Telegram Channels (Public Web)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      isPersian ? 'استخراج بدون نیاز به پروکسی یا توکن ربات' : 'Scrape public t.me/s pages without token',
                    ),
                    value: _telegramEnabled,
                    onChanged: (val) => setState(() => _telegramEnabled = val),
                  ),
                  if (_telegramEnabled) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      isPersian ? 'آیدی کانال‌ها (در هر خط یک کانال):' : 'Channel Usernames (one per line):',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _channelsCtrl,
                      maxLines: 5,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '@ChannelName',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Source 2: Subscription Links
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: Text(
                      isPersian ? 'لینک‌های اشتراک (Subscription URLs)' : 'Subscription URLs',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      isPersian ? 'پشتیبانی خودکار از فرمت‌های Base64، سابسکریپشن کلش و متنی' : 'Auto Base64 unwrapping, Clash YAML & plaintext',
                    ),
                    value: _subscriptionsEnabled,
                    onChanged: (val) => setState(() => _subscriptionsEnabled = val),
                  ),
                  if (_subscriptionsEnabled) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      isPersian ? 'لینک‌های اشتراک (در هر خط یک لینک):' : 'Subscription URLs (one per line):',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _subsCtrl,
                      maxLines: 4,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'https://...',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Source 3: Local Text Folder
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: Text(
                      isPersian ? 'پوشه فایل‌های متنی روی سیستم' : 'Local Text Folder',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      isPersian ? 'اسکن و استخراج خودکار تمام فایل‌های txt. درون پوشه' : 'Scan all .txt files inside a local directory',
                    ),
                    value: _localFolderEnabled,
                    onChanged: (val) => setState(() => _localFolderEnabled = val),
                  ),
                  if (_localFolderEnabled) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _folderCtrl,
                            textDirection: TextDirection.ltr,
                            decoration: InputDecoration(
                              labelText: isPersian ? 'مسیر پوشه' : 'Folder Path',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.tonalIcon(
                          onPressed: () {},
                          icon: const Icon(Icons.folder_open),
                          label: Text(isPersian ? 'انتخاب' : 'Browse'),
                        ),
                      ],
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
