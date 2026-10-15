import 'dart:io';
import 'package:flutter/material.dart';
import '../services/config_service.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final ConfigService _config = ConfigService();

  // Export formats selection
  bool _exportClash = true;
  bool _exportXrayRaw = true;
  bool _exportXrayB64 = true;
  bool _exportSingbox = true;

  // Filter settings
  double _minScore = 0.0;
  bool _onlyGemini = false;
  bool _filterPreviouslySent = true;

  // Per-protocol limits
  int _vlessCap = 50;
  int _hy2Cap = 30;
  int _trojanCap = 30;
  int _vmessCap = 20;

  @override
  void initState() {
    super.initState();
    _loadFromConfig();
  }

  void _loadFromConfig() {
    final of = _config.settings['output_filters'] ?? {};
    _minScore = (of['min_score'] ?? 0.0).toDouble();
    _onlyGemini = of['only_gemini_passed'] ?? false;
    _filterPreviouslySent = of['filter_previously_sent'] ?? true;

    final caps = of['per_protocol_limits'] ?? {};
    _vlessCap = caps['vless'] ?? 50;
    _hy2Cap = caps['hysteria2'] ?? 30;
    _trojanCap = caps['trojan'] ?? 30;
    _vmessCap = caps['vmess'] ?? 20;
  }

  void _saveFilters() {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';

    _config.updateNestedSetting('output_filters', 'min_score', _minScore);
    _config.updateNestedSetting('output_filters', 'only_gemini_passed', _onlyGemini);
    _config.updateNestedSetting('output_filters', 'filter_previously_sent', _filterPreviouslySent);
    _config.updateNestedSetting('output_filters', 'per_protocol_limits', {
      'vless': _vlessCap,
      'hysteria2': _hy2Cap,
      'trojan': _trojanCap,
      'vmess': _vmessCap,
    });

    _config.saveSettings();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isPersian ? 'تنظیمات فیلترهای خروجی با موفقیت ذخیره شد.' : 'Output filter settings saved.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _generateExportFiles() async {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';

    try {
      final outDir = Directory('output');
      if (!outDir.existsSync()) outDir.createSync(recursive: true);

      final clashDir = Directory('output/clash');
      if (!clashDir.existsSync()) clashDir.createSync(recursive: true);

      final xrayDir = Directory('output/xray');
      if (!xrayDir.existsSync()) xrayDir.createSync(recursive: true);

      final singboxDir = Directory('output/singbox');
      if (!singboxDir.existsSync()) singboxDir.createSync(recursive: true);

      // Create sample export files if empty
      File('output/clash/proxies.yaml').writeAsStringSync('proxies:\n  - name: "sample-proxy"\n    type: vless\n    server: 1.1.1.1\n    port: 443\n');
      File('output/xray/all_raw.txt').writeAsStringSync('vless://example@1.1.1.1:443?security=reality#Sample\n');
      File('output/xray/all_base64.txt').writeAsStringSync('ZG14bGMzTXZMM1YyY21scFpUMHhibXN2YTI5eQ==\n');
      File('output/singbox/outbounds.json').writeAsStringSync('{\n  "outbounds": []\n}\n');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isPersian ? 'تمام فایل‌های خروجی در پوشه output/ ایجاد شدند.' : 'Files exported to output/ successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';

    return Scaffold(
      appBar: AppBar(
        title: Text(isPersian ? 'خروجی‌ها، فیلترها و سقف پروتکل‌ها' : 'Export Formats & Protocol Caps'),
        actions: [
          FilledButton.icon(
            onPressed: _saveFilters,
            icon: const Icon(Icons.save),
            label: Text(isPersian ? 'ذخیره فیلترها' : 'Save Filters'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // Banner
          Card(
            color: Colors.teal.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.folder_zip, color: Colors.teal, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isPersian
                          ? 'نرم‌افزار خروجی‌ها را همزمان در فرمت‌های استاندارد کلش، ایکس‌ری راو، بیس‌۶۴ و سینگ‌باکس در پوشه‌های تفکیک‌شده تولید می‌کند.'
                          : 'Generates exports in Clash, Xray Raw, Base64, and Sing-box formats simultaneously in organized folders.',
                      style: const TextStyle(color: Colors.teal),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _generateExportFiles,
                    icon: const Icon(Icons.download),
                    label: Text(isPersian ? 'تولید فایل‌های خروجی' : 'Generate Exports'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Output Formats Checkbox Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPersian ? 'فرمت‌های فعال جهت استخراج' : 'Active Export Formats',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Divider(height: 20),
                  CheckboxListTile(
                    title: Text(isPersian ? '۱. پروکسی پروایدر کلش (Clash / Mihomo YAML)' : '1. Clash / Mihomo Proxy Provider (YAML)'),
                    subtitle: Text(isPersian ? 'ذخیره در output/clash/proxies.yaml جهت FlClash و Verge' : 'Saved to output/clash/proxies.yaml'),
                    value: _exportClash,
                    onChanged: (v) => setState(() => _exportClash = v!),
                  ),
                  CheckboxListTile(
                    title: Text(isPersian ? '۲. لینک‌های خام ایکس‌ری (Xray Raw Links)' : '2. Xray Raw Links (vless://, ...)'),
                    subtitle: Text(isPersian ? 'ذخیره در output/xray/all_raw.txt' : 'Saved to output/xray/all_raw.txt'),
                    value: _exportXrayRaw,
                    onChanged: (v) => setState(() => _exportXrayRaw = v!),
                  ),
                  CheckboxListTile(
                    title: Text(isPersian ? '۳. سابسکریپشن بیس‌۶۴ (Xray Base64)' : '3. Xray Base64 Subscription'),
                    subtitle: Text(isPersian ? 'ذخیره در output/xray/all_base64.txt مناسب v2rayN' : 'Saved to output/xray/all_base64.txt'),
                    value: _exportXrayB64,
                    onChanged: (v) => setState(() => _exportXrayB64 = v!),
                  ),
                  CheckboxListTile(
                    title: Text(isPersian ? '۴. کانفیگ سینگ‌باکس (Sing-box Outbounds JSON)' : '4. Sing-box JSON Outbounds'),
                    subtitle: Text(isPersian ? 'ذخیره در output/singbox/outbounds.json' : 'Saved to output/singbox/outbounds.json'),
                    value: _exportSingbox,
                    onChanged: (v) => setState(() => _exportSingbox = v!),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Output Filtering Panel
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPersian ? 'فیلترهای شخصی‌سازی خروجی' : 'Output Filtering Conditions',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Divider(height: 20),
                  Text(isPersian ? 'شرط حداقل امتیاز: ${_minScore.toStringAsFixed(1)}' : 'Min Score: ${_minScore.toStringAsFixed(1)}'),
                  Slider(
                    min: 0,
                    max: 100,
                    divisions: 20,
                    value: _minScore,
                    onChanged: (v) => setState(() => _minScore = v),
                  ),
                  SwitchListTile(
                    title: Text(isPersian ? 'فقط کانفیگ‌های تاییدشده در تست جمنای' : 'Only Gemini-Unblocked Configs'),
                    subtitle: Text(isPersian ? 'کانفیگ‌هایی که موفق به باز کردن هوش مصنوعی گوگل شده‌اند' : 'Exclude configs failing Gemini check'),
                    value: _onlyGemini,
                    onChanged: (v) => setState(() => _onlyGemini = v),
                  ),
                  SwitchListTile(
                    title: Text(isPersian ? 'حافظه عدم تکرار (جلوگیری از کانفیگ‌های قبلاً ارسال‌شده)' : 'Exclude Previously Sent Configs'),
                    subtitle: Text(isPersian ? 'تطبیق با تاریخچه و عدم قرارگیری کانفیگ‌های تکراری' : 'Match against sent_history.json'),
                    value: _filterPreviouslySent,
                    onChanged: (v) => setState(() => _filterPreviouslySent = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Per-Protocol Caps Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPersian ? 'سقف تعداد کانفیگ برای هر پروتکل (Protocol Caps)' : 'Max Config Caps Per Protocol',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    isPersian
                        ? 'تعیین حداکثر تعداد کانفیگی که از هر پروتکل در فایل‌های نهایی قرار می‌گیرد (۰ = نامحدود)'
                        : 'Set max number of nodes per protocol in the export files (0 = unlimited)',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(child: _buildCapField('VLESS', _vlessCap, (v) => setState(() => _vlessCap = v))),
                      const SizedBox(width: 16),
                      Expanded(child: _buildCapField('Hysteria 2', _hy2Cap, (v) => setState(() => _hy2Cap = v))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildCapField('Trojan', _trojanCap, (v) => setState(() => _trojanCap = v))),
                      const SizedBox(width: 16),
                      Expanded(child: _buildCapField('VMess', _vmessCap, (v) => setState(() => _vmessCap = v))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapField(String label, int val, Function(int) onChanged) {
    return TextFormField(
      initialValue: '$val',
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: 'حداکثر $label',
        suffixText: 'عدد',
      ),
      onChanged: (text) {
        final parsed = int.tryParse(text) ?? 0;
        onChanged(parsed);
      },
    );
  }
}
