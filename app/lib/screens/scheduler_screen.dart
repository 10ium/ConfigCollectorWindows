import 'package:flutter/material.dart';

class SchedulerScreen extends StatefulWidget {
  const SchedulerScreen({super.key});

  @override
  State<SchedulerScreen> createState() => _SchedulerScreenState();
}

class _SchedulerScreenState extends State<SchedulerScreen> {
  bool _loopEnabled = false;
  int _intervalMinutes = 60;
  bool _minimizeToTray = true;
  bool _quietHours = false;

  @override
  Widget build(BuildContext context) {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';

    return Scaffold(
      appBar: AppBar(
        title: Text(isPersian ? 'زمان‌بندی و اجرای خودکار' : 'Automated Scheduler Loop'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: Text(
                      isPersian ? 'فعال‌سازی چرخه خودکار (Loop Mode)' : 'Enable Automated Loop',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      isPersian
                          ? 'اجرای خودکار استخراج و تست در بازه‌های زمانی مشخص'
                          : 'Automatically collect and test configs at recurring intervals',
                    ),
                    value: _loopEnabled,
                    onChanged: (v) => setState(() => _loopEnabled = v),
                  ),
                  if (_loopEnabled) ...[
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      isPersian
                          ? 'فاصله زمانی بین هر اجرا: $_intervalMinutes دقیقه'
                          : 'Interval between runs: $_intervalMinutes minutes',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Slider(
                      min: 15,
                      max: 360,
                      divisions: 23,
                      value: _intervalMinutes.toDouble(),
                      onChanged: (v) => setState(() => _intervalMinutes = v.toInt()),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: Text(isPersian ? 'کوچک‌شدن به کنار ساعت (System Tray)' : 'Minimize to System Tray on close'),
                      value: _minimizeToTray,
                      onChanged: (v) => setState(() => _minimizeToTray = v),
                    ),
                    SwitchListTile(
                      title: Text(isPersian ? 'ساعات سکوت (عدم اجرا بین ۱ تا ۶ صبح)' : 'Quiet Hours (pause 01:00 - 06:00)'),
                      value: _quietHours,
                      onChanged: (v) => setState(() => _quietHours = v),
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
