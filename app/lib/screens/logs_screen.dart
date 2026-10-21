import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/config_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final ConfigService _config = ConfigService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  String _filterType = 'all'; // all, info, success, warning, error
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _config.addListener(_onLogsUpdated);
  }

  @override
  void dispose() {
    _config.removeListener(_onLogsUpdated);
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onLogsUpdated() {
    if (mounted) {
      setState(() {});
      if (_autoScroll && _scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    }
  }

  void _copyAllLogs() {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';
    final allText = _config.logs
        .map((l) => '[${l.formattedTime}] [${l.source}] [${l.type.name.toUpperCase()}] ${l.message}${l.details != null ? ' - ' + l.details! : ''}')
        .join('\n');
    Clipboard.setData(ClipboardData(text: allText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isPersian ? 'تمام لاگ‌ها در حافظه کلیپ‌بورد کپی شدند.' : 'All logs copied to clipboard.'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';
    final query = _searchCtrl.text.trim().toLowerCase();

    final filteredLogs = _config.logs.where((entry) {
      if (_filterType != 'all' && entry.type.name != _filterType) {
        return false;
      }
      if (query.isNotEmpty) {
        final full = '${entry.message} ${entry.source} ${entry.details ?? ''}'.toLowerCase();
        if (!full.contains(query)) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(isPersian ? 'گزارش و لاگ لحظه‌ای فرآیندها' : 'Live Execution Logs'),
        actions: [
          IconButton(
            tooltip: isPersian ? 'کپی کل لاگ‌ها' : 'Copy All Logs',
            icon: const Icon(Icons.copy_all),
            onPressed: _config.logs.isEmpty ? null : _copyAllLogs,
          ),
          IconButton(
            tooltip: isPersian ? 'پاک کردن لاگ‌ها' : 'Clear Logs',
            icon: const Icon(Icons.delete_outline),
            onPressed: _config.logs.isEmpty ? null : () => setState(() => _config.clearLogs()),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter & Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      hintText: isPersian ? 'جستجو در لاگ‌ها (نام منبع، پیام، خطا...)' : 'Search logs...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() => _searchCtrl.clear()),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  label: Text(isPersian ? 'همه (${_config.logs.length})' : 'All'),
                  selected: _filterType == 'all',
                  onSelected: (v) => setState(() => _filterType = 'all'),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: Text(isPersian ? 'موفق' : 'Success'),
                  selected: _filterType == 'success',
                  selectedColor: Colors.green.withOpacity(0.25),
                  onSelected: (v) => setState(() => _filterType = 'success'),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: Text(isPersian ? 'هشدار/خطا' : 'Errors'),
                  selected: _filterType == 'error',
                  selectedColor: Colors.red.withOpacity(0.25),
                  onSelected: (v) => setState(() => _filterType = 'error'),
                ),
                const Spacer(),
                Row(
                  children: [
                    Text(
                      isPersian ? 'اسکرول خودکار' : 'Auto-scroll',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Switch(
                      value: _autoScroll,
                      onChanged: (v) => setState(() => _autoScroll = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Log List View
          Expanded(
            child: filteredLogs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.terminal, size: 48, color: Colors.grey.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        Text(
                          isPersian ? 'هیچ رویدادی برای نمایش وجود ندارد.' : 'No logs recorded yet.',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isPersian ? 'با شروع اسکن در داشبورد، گزارش زنده مرحله به مرحله در اینجا نمایش داده خواهد شد.' : 'Start scanning from dashboard to see live output.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : Container(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF0F1117)
                        : const Color(0xFFF7F9FC),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filteredLogs.length,
                      itemBuilder: (context, index) {
                        final entry = filteredLogs[index];
                        Color typeColor;
                        IconData iconData;

                        switch (entry.type) {
                          case LogType.success:
                            typeColor = Colors.greenAccent;
                            iconData = Icons.check_circle_outline;
                            break;
                          case LogType.warning:
                            typeColor = Colors.orangeAccent;
                            iconData = Icons.warning_amber_rounded;
                            break;
                          case LogType.error:
                            typeColor = Colors.redAccent;
                            iconData = Icons.error_outline;
                            break;
                          case LogType.info:
                          default:
                            typeColor = Colors.blueAccent;
                            iconData = Icons.info_outline;
                            break;
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.formattedTime,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(iconData, size: 14, color: typeColor),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: typeColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  entry.source,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: typeColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  entry.message + (entry.details != null ? ' (${entry.details})' : ''),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontFamily: 'monospace',
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey.shade200
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
