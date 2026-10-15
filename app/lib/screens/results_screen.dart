import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/config_service.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final ConfigService _config = ConfigService();
  String _selectedProtoFilter = 'ALL';
  bool _onlyGemini = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _config.addListener(_onConfigUpdate);
  }

  @override
  void dispose() {
    _config.removeListener(_onConfigUpdate);
    super.dispose();
  }

  void _onConfigUpdate() {
    if (mounted) setState(() {});
  }

  void _copyToClipboard(String text, String format) {
    Clipboard.setData(ClipboardData(text: text));
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isPersian ? 'کانفیگ با فرمت $format در کلیپ‌بورد کپی شد.' : 'Config copied as $format.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';

    final filtered = _config.survivors.where((item) {
      if (_onlyGemini && item['gemini'] != true) return false;
      if (_selectedProtoFilter != 'ALL' && item['proto'] != _selectedProtoFilter) return false;
      if (_searchQuery.isNotEmpty && !item['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(isPersian ? 'پروکسی‌های سالم و نتایج زنده' : 'Live Survivor Results'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _config.startScan(),
            tooltip: isPersian ? 'شروع مجدد تست' : 'Retest',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: isPersian ? 'جستجو بر اساس کشور، پروتکل یا نام...' : 'Search by country, name...',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  label: Text(isPersian ? 'فقط جمنای 🤖' : 'Gemini Only 🤖'),
                  selected: _onlyGemini,
                  onSelected: (val) => setState(() => _onlyGemini = val),
                  selectedColor: Colors.blue.shade100,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Results List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          isPersian ? 'هیچ پروکسی با این فیلترها یافت نشد.' : 'No proxies match current filter.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(24.0),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final ping = item['ping'] as double;
                      final isLowPing = ping < 100;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Text(
                            item['flag'] ?? '🌐',
                            style: const TextStyle(fontSize: 32),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item['name'],
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Protocol Chip
                              Chip(
                                label: Text(item['proto'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                              const SizedBox(width: 6),
                              // Transport Chip
                              Chip(
                                label: Text(item['transport'], style: const TextStyle(fontSize: 10)),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                backgroundColor: Colors.teal.shade50,
                              ),
                              const SizedBox(width: 6),
                              // UDP Badge
                              if (item['udp'] == true)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    border: Border.all(color: Colors.green),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('UDP', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                                ),
                              // Gemini Badge
                              if (item['gemini'] == true) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    border: Border.all(color: Colors.blue),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Gemini OK', style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              isPersian
                                  ? 'تاخیر: ${ping.toStringAsFixed(0)}ms | پکت‌لاس: ${(item['packetLoss'] as double).toInt()}% | جیتر: ${(item['jitter'] as double).toStringAsFixed(1)}ms | امنیت: ${item['security']}'
                                  : 'Ping: ${ping.toStringAsFixed(0)}ms | Loss: ${(item['packetLoss'] as double).toInt()}% | Jitter: ${(item['jitter'] as double).toStringAsFixed(1)}ms | Security: ${item['security']}',
                              style: TextStyle(
                                color: isLowPing ? Colors.green.shade700 : Colors.grey.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            tooltip: isPersian ? 'کپی کانفیگ' : 'Copy Config',
                            icon: const Icon(Icons.copy),
                            onSelected: (format) {
                              if (format == 'raw') {
                                _copyToClipboard('vless://sample-uuid@1.1.1.1:443?security=reality&sni=example.com#${item['name']}', 'Xray Raw');
                              } else if (format == 'yaml') {
                                _copyToClipboard('- name: "${item['name']}"\n  type: ${item['proto'].toString().toLowerCase()}\n  server: 1.1.1.1\n  port: 443', 'Clash YAML');
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'raw',
                                child: Text(isPersian ? 'کپی لینک خام (Xray Raw)' : 'Copy Raw Link'),
                              ),
                              PopupMenuItem(
                                value: 'yaml',
                                child: Text(isPersian ? 'کپی فرمت کلش (Clash YAML)' : 'Copy Clash YAML'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
