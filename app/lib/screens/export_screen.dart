import 'package:flutter/material.dart';

class ExportScreen extends StatelessWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';

    return Scaffold(
      appBar: AppBar(
        title: Text(isPersian ? 'خروجی و استخراج فایل‌ها' : 'Clash Export & Output Formats'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // Option 1: Full Clash Config
          Card(
            child: ListTile(
              leading: const Icon(Icons.auto_awesome, color: Colors.blue, size: 36),
              title: Text(
                isPersian ? 'کانفیگ کامل کلش میهومو (Clash Full Config)' : 'Full Clash Mihomo Config',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                isPersian
                    ? 'شامل ۳۲ گروه پروکسی فارسی، قوانین ترافیک هوشمند، و DNS رمزنگاری‌شده'
                    : 'Includes 32 Persian proxy groups, DNS rules, and TUN network',
              ),
              trailing: FilledButton.tonal(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isPersian ? 'فایل clash_full.yaml ذخیره شد' : 'clash_full.yaml saved successfully')),
                  );
                },
                child: Text(isPersian ? 'دانلود YAML' : 'Save YAML'),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Option 2: Proxy Provider
          Card(
            child: ListTile(
              leading: const Icon(Icons.view_list, color: Colors.green, size: 36),
              title: Text(
                isPersian ? 'پرووایدر پروکسی (Clash Proxy Provider)' : 'Clash Proxy Provider',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                isPersian
                    ? 'فقط لیست پروکسی‌های سالم جهت افزودن به کلاینت‌های FlClash و Verge'
                    : 'Pure proxies: [...] list for FlClash & Clash Verge proxy-providers',
              ),
              trailing: FilledButton.tonal(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isPersian ? 'فایل proxies.yaml ذخیره شد' : 'proxies.yaml saved')),
                  );
                },
                child: Text(isPersian ? 'دانلود فایل' : 'Save File'),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Option 3: Raw Links
          Card(
            child: ListTile(
              leading: const Icon(Icons.link, color: Colors.orange, size: 36),
              title: Text(
                isPersian ? 'لینک‌های خام و سابسکریپشن Base64' : 'Raw Links & Base64 Subscription',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                isPersian
                    ? 'فایل متنی خط‌به‌خط برای وارد کردن مستقیم در v2rayN یا Hiddify'
                    : 'Plaintext links for v2rayN, Hiddify, or v2rayNG',
              ),
              trailing: FilledButton.tonal(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isPersian ? 'لینک‌ها کپی شدند' : 'Links copied')),
                  );
                },
                child: Text(isPersian ? 'کپی لینک‌ها' : 'Copy Links'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
