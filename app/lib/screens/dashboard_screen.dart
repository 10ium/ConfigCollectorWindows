import 'package:flutter/material.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isRunning = false;
  int _totalFound = 0;
  int _totalTested = 0;
  int _totalAlive = 0;
  double _avgPing = 0.0;

  void _toggleScan() {
    setState(() {
      _isRunning = !_isRunning;
      if (_isRunning) {
        _totalFound = 142;
        _totalTested = 84;
        _totalAlive = 53;
        _avgPing = 112.4;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';

    return Scaffold(
      appBar: AppBar(
        title: Text(isPersian ? 'داشبورد کنترل اصلی' : 'Main Control Dashboard'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Start / Stop Hero Card
            Card(
              color: _isRunning
                  ? Colors.red.shade50
                  : Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    Icon(
                      _isRunning ? Icons.stop_circle : Icons.play_circle_fill,
                      size: 64,
                      color: _isRunning
                          ? Colors.red
                          : Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isRunning
                                ? (isPersian ? 'موتور در حال استخراج و تست...' : 'Engine is extracting and testing...')
                                : (isPersian ? 'موتور آماده به کار است' : 'Engine is idle & ready'),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isPersian
                                ? 'منابع فعال: تلگرام و سابسکریپشن | تست‌های فعال: پینگ، کشور، UDP، پایداری، تمیزی'
                                : 'Active sources: Telegram & Subscriptions | Active tests: Ping, Geo, UDP, Stability, Fraud',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _toggleScan,
                      style: FilledButton.styleFrom(
                        backgroundColor: _isRunning ? Colors.red : null,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                      ),
                      icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
                      label: Text(
                        _isRunning
                            ? (isPersian ? 'توقف عملیات' : 'Stop')
                            : (isPersian ? 'شروع استخراج و تست' : 'Start Scan'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Metrics Grid
            Text(
              isPersian ? 'وضعیت زنده استخراج' : 'Live Metrics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildMetricCard(
                  context,
                  title: isPersian ? 'کانفیگ‌های کشف‌شده' : 'Found Configs',
                  value: '$_totalFound',
                  icon: Icons.search,
                  color: Colors.blue,
                ),
                const SizedBox(width: 16),
                _buildMetricCard(
                  context,
                  title: isPersian ? 'بررسی‌شده' : 'Tested',
                  value: '$_totalTested',
                  icon: Icons.fact_check_outlined,
                  color: Colors.orange,
                ),
                const SizedBox(width: 16),
                _buildMetricCard(
                  context,
                  title: isPersian ? 'سالم و زنده' : 'Passed Survivors',
                  value: '$_totalAlive',
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                ),
                const SizedBox(width: 16),
                _buildMetricCard(
                  context,
                  title: isPersian ? 'میانگین تاخیر' : 'Avg Latency',
                  value: '${_avgPing.toStringAsFixed(0)} ms',
                  icon: Icons.speed,
                  color: Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  Icon(icon, color: color, size: 24),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
