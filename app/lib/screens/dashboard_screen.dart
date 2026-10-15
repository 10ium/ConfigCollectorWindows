import 'package:flutter/material.dart';
import '../services/config_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ConfigService _config = ConfigService();

  @override
  void initState() {
    super.initState();
    _config.addListener(_onConfigUpdate);
    _config.loadSettings();
  }

  @override
  void dispose() {
    _config.removeListener(_onConfigUpdate);
    super.dispose();
  }

  void _onConfigUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';

    return Scaffold(
      appBar: AppBar(
        title: Text(isPersian ? 'داشبورد کنترل و تحلیل زنده' : 'Live Dashboard & Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: isPersian ? 'بارگذاری مجدد تنظیمات' : 'Reload Settings',
            onPressed: () => _config.loadSettings(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Start / Stop Hero Card
            Card(
              color: _config.isRunning
                  ? Colors.red.shade50
                  : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          _config.isRunning ? Icons.stop_circle : Icons.play_circle_fill,
                          size: 56,
                          color: _config.isRunning
                              ? Colors.red
                              : Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _config.isRunning
                                    ? (isPersian ? 'موتور در حال استخراج و تست...' : 'Engine is running...')
                                    : (isPersian ? 'موتور آماده به کار است' : 'Engine is ready'),
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _config.statusMessage,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey.shade700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () {
                            if (_config.isRunning) {
                              _config.stopScan();
                            } else {
                              _config.startScan();
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: _config.isRunning ? Colors.red : null,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          ),
                          icon: Icon(_config.isRunning ? Icons.stop : Icons.play_arrow),
                          label: Text(
                            _config.isRunning
                                ? (isPersian ? 'توقف عملیات' : 'Stop')
                                : (isPersian ? 'شروع استخراج و تست' : 'Start Process'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    if (_config.isRunning) ...[
                      const SizedBox(height: 16),
                      LinearProgressIndicator(value: _config.progress),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Source Filter Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isPersian ? 'آمار زنده بر اساس منبع:' : 'Live Metrics by Source:',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _config.selectedSourceFilter,
                      items: [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text(isPersian ? '📊 همه منابع (کامل)' : 'All Sources'),
                        ),
                        DropdownMenuItem(
                          value: 'telegram',
                          child: Text(isPersian ? '📢 کانال‌های تلگرام' : 'Telegram Channels'),
                        ),
                        DropdownMenuItem(
                          value: 'subscription',
                          child: Text(isPersian ? '🌐 پروکسی پروایدرها' : 'Proxy Providers'),
                        ),
                        DropdownMenuItem(
                          value: 'local_folder',
                          child: Text(isPersian ? '📁 پوشه محلی' : 'Local Folder'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) _config.setSourceFilter(val);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Top Metrics Grid
            Row(
              children: [
                _buildMetricCard(
                  context,
                  title: isPersian ? 'کشف‌شده' : 'Found',
                  value: '${_config.foundCount}',
                  icon: Icons.search,
                  color: Colors.blue,
                ),
                const SizedBox(width: 12),
                _buildMetricCard(
                  context,
                  title: isPersian ? 'بررسی‌شده' : 'Tested',
                  value: '${_config.testedCount}',
                  icon: Icons.checklist_rtl,
                  color: Colors.orange,
                ),
                const SizedBox(width: 12),
                _buildMetricCard(
                  context,
                  title: isPersian ? 'سالم و تاییدشده' : 'Survivors',
                  value: '${_config.aliveCount}',
                  icon: Icons.verified,
                  color: Colors.green,
                ),
                const SizedBox(width: 12),
                _buildMetricCard(
                  context,
                  title: isPersian ? 'میانگین تاخیر' : 'Avg Latency',
                  value: _config.avgPing > 0 ? '${_config.avgPing.toStringAsFixed(0)} ms' : '-',
                  icon: Icons.speed,
                  color: Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Card 1: Protocols Breakdown
            _buildBreakdownCard(
              context,
              title: isPersian ? 'آمار تفکیک پروتکل‌ها' : 'Protocols Breakdown',
              icon: Icons.share,
              color: Colors.indigo,
              items: _config.protocolStats,
              isProtocol: true,
            ),
            const SizedBox(height: 16),

            // Row with Transport & Security Cards
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildBreakdownCard(
                    context,
                    title: isPersian ? 'بستر انتقال (Transport)' : 'Transport Breakdown',
                    icon: Icons.alt_route,
                    color: Colors.teal,
                    items: _config.transportStats,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildBreakdownCard(
                    context,
                    title: isPersian ? 'امنیت و رمزنگاری (Security)' : 'Security & Encryption',
                    icon: Icons.security,
                    color: Colors.amber.shade800,
                    items: _config.securityStats,
                  ),
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  Icon(icon, color: color, size: 22),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
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

  bool _showAllProtocols = true;

  Widget _buildBreakdownCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required Map<String, int> items,
    bool isProtocol = false,
  }) {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';
    final entries = isProtocol && !_showAllProtocols
        ? items.entries.where((e) => e.value > 0).toList()
        : items.entries.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                if (isProtocol)
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () => setState(() => _showAllProtocols = !_showAllProtocols),
                    icon: Icon(_showAllProtocols ? Icons.filter_alt : Icons.list_alt, size: 16),
                    label: Text(
                      _showAllProtocols
                          ? (isPersian ? 'نمایش فقط موارد شناسایی‌شده' : 'Show Active Only')
                          : (isPersian ? 'نمایش تمام ۲۷ پروتکل میهومو' : 'Show All 27 Protocols'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            const Divider(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: entries.map((e) {
                final hasCount = e.value > 0;
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: hasCount ? color : Colors.grey.shade300,
                    child: Text(
                      '${e.value}',
                      style: TextStyle(
                        fontSize: 10,
                        color: hasCount ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  label: Text(
                    e.key,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: hasCount ? FontWeight.bold : FontWeight.normal,
                      color: hasCount ? Colors.black87 : Colors.grey.shade600,
                    ),
                  ),
                  backgroundColor: hasCount
                      ? color.withOpacity(0.12)
                      : Colors.grey.shade100,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
