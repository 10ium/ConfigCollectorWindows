import 'package:flutter/material.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _profile = 'medium';

  @override
  Widget build(BuildContext context) {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';

    return Scaffold(
      appBar: AppBar(
        title: Text(isPersian ? 'تنظیمات عمومی' : 'General Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // Hardware Profile
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPersian ? 'پروفایل سخت‌افزاری و مصرف رم' : 'Hardware Profile & Memory Limits',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isPersian
                        ? 'تنظیم خودکار میزان همزمانی و سقف مصرف رم متناسب با توان سیستم'
                        : 'Auto-adjust worker concurrency and memory soft limits',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Divider(),
                  RadioListTile<String>(
                    title: Text(isPersian ? 'سیستم ضعیف (رم ۴ گیگ DDR3)' : 'Weak PC / Phone (4GB DDR3 RAM)'),
                    subtitle: Text(isPersian ? 'همزمانی تست: ۱۰ | مصرف رم حداکثر ۱۵۰ مگابایت' : 'Ping concurrency: 10 | Max 150MB RAM'),
                    value: 'weak',
                    groupValue: _profile,
                    onChanged: (v) => setState(() => _profile = v!),
                  ),
                  RadioListTile<String>(
                    title: Text(isPersian ? 'سیستم متوسط (پیش‌فرض پیشنهادی)' : 'Medium PC (Balanced)'),
                    subtitle: Text(isPersian ? 'همزمانی تست: ۳۰ | مصرف رم حدود ۲۵۰ مگابایت' : 'Ping concurrency: 30 | ~250MB RAM'),
                    value: 'medium',
                    groupValue: _profile,
                    onChanged: (v) => setState(() => _profile = v!),
                  ),
                  RadioListTile<String>(
                    title: Text(isPersian ? 'سیستم قوی یا سرور مجازی' : 'Strong PC / Cloud Server'),
                    subtitle: Text(isPersian ? 'همزمانی تست: ۱۰۰ | حداکثر سرعت استخراج' : 'Ping concurrency: 100 | Maximum throughput'),
                    value: 'strong',
                    groupValue: _profile,
                    onChanged: (v) => setState(() => _profile = v!),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Language & Appearance
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPersian ? 'زبان و ظاهر برنامه' : 'Language & Appearance',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: Text(isPersian ? 'تغییر زبان' : 'Language'),
                    trailing: DropdownButton<String>(
                      value: isPersian ? 'fa' : 'en',
                      items: const [
                        DropdownMenuItem(value: 'fa', child: Text('فارسی (RTL)')),
                        DropdownMenuItem(value: 'en', child: Text('English (LTR)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          FreedomConfigCollectorApp.of(context)?.setLocale(Locale(val));
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // About Card
          Card(
            child: ListTile(
              leading: const Icon(Icons.info, color: Colors.blue),
              title: const Text('Freedom Config Collector v2.0.0'),
              subtitle: Text(
                isPersian
                    ? 'طراحی‌شده با Go و Flutter | سازگار با هسته Mihomo و Xray'
                    : 'Built with Go & Flutter | Mihomo & Xray Core Ready',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
