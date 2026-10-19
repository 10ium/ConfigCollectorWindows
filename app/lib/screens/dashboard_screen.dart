import 'package:flutter/material.dart';
import '../services/config_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ConfigService _config = ConfigService();

  // Stats view mode: 'both' (سالم / کل), 'alive' (فقط سالم), 'found' (فقط پیداشده)
  String _statsMode = 'both';
  bool _showAllProtocols = true;

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
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Start / Stop Hero Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: _config.isRunning
                      ? Colors.red.withOpacity(0.5)
                      : Theme.of(context).colorScheme.primary.withOpacity(0.3),
                ),
              ),
              color: Theme.of(context).cardColor,
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
                                      color: Colors.grey.shade400,
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
                    if (_config.isRunning || _config.currentStage > 0) ...[
                      const SizedBox(height: 20),
                      // 5-Stage Stepper Bar
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        ),
                        child: Column(
                          children: [
                            // Stages Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(ConfigService.stageTitles.length, (idx) {
                                final stageNum = idx + 1;
                                final isDone = _config.currentStage > stageNum;
                                final isActive = _config.currentStage == stageNum;

                                Color iconColor = Colors.grey.shade600;
                                if (isDone) iconColor = Colors.greenAccent;
                                if (isActive) iconColor = Theme.of(context).colorScheme.primary;

                                return Expanded(
                                  child: Column(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: iconColor.withOpacity(0.2),
                                        child: isDone
                                            ? const Icon(Icons.check, size: 14, color: Colors.greenAccent)
                                            : Text(
                                                '$stageNum',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: iconColor,
                                                ),
                                              ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        ConfigService.stageTitles[idx],
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                          color: isActive ? Colors.white : Colors.grey.shade400,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 14),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: _config.progress,
                                minHeight: 8,
                                backgroundColor: Colors.grey.withOpacity(0.2),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Counters and ETA Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.pie_chart_outline, size: 16, color: Colors.grey.shade400),
                                    const SizedBox(width: 6),
                                    Text(
                                      isPersian
                                          ? 'پیشرفت: ${(_config.progress * 100).toInt()}%'
                                          : 'Progress: ${(_config.progress * 100).toInt()}%',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey.shade400),
                                    const SizedBox(width: 6),
                                    Text(
                                      isPersian
                                          ? 'بررسی‌شده: ${_config.completedItems} از ${_config.totalEstimatedItems}'
                                          : 'Checked: ${_config.completedItems} / ${_config.totalEstimatedItems}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade300),
                                    ),
                                  ],
                                ),
                                if (_config.etaString.isNotEmpty)
                                  Row(
                                    children: [
                                      Icon(Icons.timer_outlined, size: 16, color: Colors.grey.shade400),
                                      const SizedBox(width: 6),
                                      Text(
                                        isPersian ? 'زمان باقی‌مانده: ${_config.etaString}' : 'ETA: ${_config.etaString}',
                                        style: const TextStyle(fontSize: 12, color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Source Selector & Stats Mode Controls
            Row(
              children: [
                // Specific Source Filter Dropdown
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _config.availableSourceItems.any((e) => e['id'] == _config.selectedSourceFilter)
                            ? _config.selectedSourceFilter
                            : 'all',
                        items: _config.availableSourceItems.map((item) {
                          return DropdownMenuItem<String>(
                            value: item['id'],
                            child: Text(
                              item['title']!,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) _config.setSourceFilter(val);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Mode Toggle: Both vs Alive vs Found
                Expanded(
                  flex: 2,
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'both',
                        label: Text(isPersian ? 'سالم / کل' : 'Alive/All'),
                      ),
                      ButtonSegment(
                        value: 'alive',
                        label: Text(isPersian ? 'فقط سالم' : 'Alive Only'),
                      ),
                      ButtonSegment(
                        value: 'found',
                        label: Text(isPersian ? 'فقط پیداشده' : 'Found Only'),
                      ),
                    ],
                    selected: {_statsMode},
                    onSelectionChanged: (set) => setState(() => _statsMode = set.first),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Top Summary Cards
            Row(
              children: [
                _buildMetricCard(
                  context,
                  title: isPersian ? 'کل کشف‌شده' : 'Total Found',
                  value: '${_config.foundCount}',
                  icon: Icons.search,
                  color: Colors.blueAccent,
                ),
                const SizedBox(width: 12),
                _buildMetricCard(
                  context,
                  title: isPersian ? 'بررسی‌شده' : 'Tested',
                  value: '${_config.testedCount}',
                  icon: Icons.checklist_rtl,
                  color: Colors.orangeAccent,
                ),
                const SizedBox(width: 12),
                _buildMetricCard(
                  context,
                  title: isPersian ? 'سالم و تاییدشده' : 'Survivors',
                  value: '${_config.aliveCount}',
                  icon: Icons.verified,
                  color: Colors.greenAccent.shade400,
                ),
                const SizedBox(width: 12),
                _buildMetricCard(
                  context,
                  title: isPersian ? 'میانگین تاخیر' : 'Avg Latency',
                  value: _config.avgPing > 0 ? '${_config.avgPing.toStringAsFixed(0)} ms' : '-',
                  icon: Icons.speed,
                  color: Colors.purpleAccent,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Group 1: Mihomo Core Native Protocols
            _buildProtocolCategoryCard(
              context,
              title: isPersian ? 'پروتکل‌های رسمی میهومو (Mihomo Core)' : 'Mihomo Core Protocols',
              icon: Icons.dns,
              color: Colors.cyanAccent.shade700,
              protocols: ConfigService.mihomoProtocols,
              showToggle: true,
            ),
            const SizedBox(height: 16),

            // Group 2: DNS & Tunnel Protocols (From Decryptor)
            _buildProtocolCategoryCard(
              context,
              title: isPersian ? 'پروتکل‌های دی‌ان‌اس و تونلینگ (DNS & Tunnels)' : 'DNS & Tunnel Protocols',
              icon: Icons.vpn_lock,
              color: Colors.amberAccent.shade700,
              protocols: ConfigService.dnsTunnelProtocols,
            ),
            const SizedBox(height: 16),

            // Group 3: Telegram Dedicated Proxies
            _buildProtocolCategoryCard(
              context,
              title: isPersian ? 'پروکسی‌های اختصاصی تلگرام (Telegram Proxies)' : 'Telegram Dedicated Proxies',
              icon: Icons.send_rounded,
              color: Colors.lightBlueAccent,
              protocols: ConfigService.telegramProtocols,
            ),
            const SizedBox(height: 20),

            // Row with Transport & Security Cards
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildBreakdownCard(
                    context,
                    title: isPersian ? 'بستر انتقال (Transport)' : 'Transport Breakdown',
                    icon: Icons.alt_route,
                    color: Colors.tealAccent.shade400,
                    items: _config.transportStats,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildBreakdownCard(
                    context,
                    title: isPersian ? 'امنیت و رمزنگاری (Security)' : 'Security & Encryption',
                    icon: Icons.security,
                    color: Colors.orangeAccent,
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
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
        color: Theme.of(context).cardColor,
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
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
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

  Widget _buildProtocolCategoryCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<String> protocols,
    bool showToggle = false,
  }) {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';

    final displayed = protocols.where((p) {
      if (!_showAllProtocols && showToggle) {
        final found = _config.foundStats[p] ?? 0;
        final alive = _config.aliveStats[p] ?? 0;
        return (found > 0 || alive > 0);
      }
      return true;
    }).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.withOpacity(0.25)),
      ),
      color: Theme.of(context).cardColor,
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
                if (showToggle)
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () => setState(() => _showAllProtocols = !_showAllProtocols),
                    icon: Icon(_showAllProtocols ? Icons.filter_alt : Icons.list_alt, size: 16),
                    label: Text(
                      _showAllProtocols
                          ? (isPersian ? 'فقط موارد فعال' : 'Active Only')
                          : (isPersian ? 'نمایش همه ۲۴ پروتکل' : 'Show All 24'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            const Divider(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: displayed.map((p) {
                final found = _config.foundStats[p] ?? 0;
                final alive = _config.aliveStats[p] ?? 0;
                final hasAny = (found > 0 || alive > 0);

                String countLabel;
                if (_statsMode == 'alive') {
                  countLabel = '$alive';
                } else if (_statsMode == 'found') {
                  countLabel = '$found';
                } else {
                  countLabel = '$alive / $found';
                }

                return Chip(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  avatar: CircleAvatar(
                    backgroundColor: hasAny ? color.withOpacity(0.25) : Colors.grey.shade800,
                    child: Text(
                      countLabel,
                      style: TextStyle(
                        fontSize: 9,
                        color: hasAny ? color : Colors.grey.shade400,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  label: Text(
                    p,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: hasAny ? FontWeight.bold : FontWeight.normal,
                      color: hasAny ? Colors.white : Colors.grey.shade500,
                    ),
                  ),
                  backgroundColor: hasAny
                      ? color.withOpacity(0.12)
                      : Colors.transparent,
                  side: BorderSide(
                    color: hasAny ? color.withOpacity(0.4) : Colors.grey.withOpacity(0.2),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required Map<String, int> items,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.withOpacity(0.25)),
      ),
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const Divider(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.entries.map((e) {
                final hasCount = e.value > 0;
                return Chip(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  avatar: CircleAvatar(
                    backgroundColor: hasCount ? color.withOpacity(0.25) : Colors.grey.shade800,
                    child: Text(
                      '${e.value}',
                      style: TextStyle(
                        fontSize: 10,
                        color: hasCount ? color : Colors.grey.shade400,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  label: Text(
                    e.key,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: hasCount ? FontWeight.bold : FontWeight.normal,
                      color: hasCount ? Colors.white : Colors.grey.shade500,
                    ),
                  ),
                  backgroundColor: hasCount ? color.withOpacity(0.12) : Colors.transparent,
                  side: BorderSide(
                    color: hasCount ? color.withOpacity(0.4) : Colors.grey.withOpacity(0.2),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
