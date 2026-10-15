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

  // Multi-dimensional filters
  String _selectedPort = 'ALL';
  String _selectedProto = 'ALL';
  String _selectedCountry = 'ALL';
  String _selectedTransport = 'ALL';
  String _selectedSecurity = 'ALL';
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

    // Extract dynamic options from current survivors
    final allCountries = {'ALL', ..._config.survivors.map((e) => (e['country'] ?? 'OTHER').toString()).where((e) => e.isNotEmpty)}.toList();
    final allPorts = {'ALL', ..._config.survivors.map((e) => (e['port'] ?? 443).toString())}.toList();
    final allProtos = {'ALL', ..._config.survivors.map((e) => (e['proto'] ?? 'VLESS').toString())}.toList();
    final allTransports = {'ALL', 'TCP', 'WS (WebSocket)', 'gRPC', 'XHTTP', 'SplitHTTP', 'H2', 'QUIC'};
    final allSecurities = {'ALL', 'Reality', 'TLS', 'ShadowTLS', 'None'};

    final filtered = _config.survivors.where((item) {
      if (_onlyGemini && item['gemini'] != true) return false;
      if (_selectedPort != 'ALL' && (item['port']?.toString() ?? '443') != _selectedPort) return false;
      if (_selectedProto != 'ALL' && item['proto'] != _selectedProto) return false;
      if (_selectedCountry != 'ALL' && (item['country'] ?? '') != _selectedCountry) return false;
      if (_selectedTransport != 'ALL' && (item['transport'] ?? '') != _selectedTransport) return false;
      if (_selectedSecurity != 'ALL' && (item['security'] ?? '') != _selectedSecurity) return false;
      if (_searchQuery.isNotEmpty && !item['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(isPersian ? 'پروکسی‌های سالم و فیلترهای چندبعدی' : 'Survivor Results & Multi-Filter'),
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
          // Filter Bar Container
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Theme.of(context).cardColor,
            child: Column(
              children: [
                // Search row + Gemini chip
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: isPersian ? 'جستجو در نام پروکسی...' : 'Search proxy name...',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilterChip(
                      label: Text(isPersian ? 'فقط جمنای 🤖' : 'Gemini Only 🤖'),
                      selected: _onlyGemini,
                      onSelected: (val) => setState(() => _onlyGemini = val),
                      selectedColor: Colors.blue.withOpacity(0.2),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Dropdown Filters Row: Port, Protocol, Country, Transport, Security
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Port Filter
                      _buildDropdownFilter(
                        label: isPersian ? 'پورت' : 'Port',
                        value: _selectedPort,
                        items: allPorts,
                        onChanged: (v) => setState(() => _selectedPort = v!),
                      ),
                      const SizedBox(width: 8),
                      // Protocol Filter
                      _buildDropdownFilter(
                        label: isPersian ? 'پروتکل' : 'Protocol',
                        value: _selectedProto,
                        items: allProtos,
                        onChanged: (v) => setState(() => _selectedProto = v!),
                      ),
                      const SizedBox(width: 8),
                      // Country Filter
                      _buildDropdownFilter(
                        label: isPersian ? 'کشور' : 'Country',
                        value: _selectedCountry,
                        items: allCountries,
                        onChanged: (v) => setState(() => _selectedCountry = v!),
                      ),
                      const SizedBox(width: 8),
                      // Transport Filter
                      _buildDropdownFilter(
                        label: isPersian ? 'بستر' : 'Transport',
                        value: _selectedTransport,
                        items: allTransports.toList(),
                        onChanged: (v) => setState(() => _selectedTransport = v!),
                      ),
                      const SizedBox(width: 8),
                      // Security Filter
                      _buildDropdownFilter(
                        label: isPersian ? 'امنیت' : 'Security',
                        value: _selectedSecurity,
                        items: allSecurities.toList(),
                        onChanged: (v) => setState(() => _selectedSecurity = v!),
                      ),
                      const SizedBox(width: 8),
                      if (_selectedPort != 'ALL' || _selectedProto != 'ALL' || _selectedCountry != 'ALL' || _selectedTransport != 'ALL' || _selectedSecurity != 'ALL')
                        IconButton(
                          icon: const Icon(Icons.clear, color: Colors.redAccent),
                          tooltip: isPersian ? 'پاک‌سازی همه فیلترها' : 'Clear all filters',
                          onPressed: () => setState(() {
                            _selectedPort = 'ALL';
                            _selectedProto = 'ALL';
                            _selectedCountry = 'ALL';
                            _selectedTransport = 'ALL';
                            _selectedSecurity = 'ALL';
                            _onlyGemini = false;
                            _searchQuery = '';
                          }),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Results Count Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            color: Theme.of(context).cardColor.withOpacity(0.5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isPersian ? 'نمایش ${filtered.length} از ${_config.survivors.length} پروکسی' : 'Showing ${filtered.length} of ${_config.survivors.length} proxies',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.bold),
                ),
                Text(
                  isPersian ? 'مرتب‌شده بر اساس امتیاز ترکیبی' : 'Sorted by Composite Score',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
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
                        Icon(Icons.filter_list_off, size: 64, color: Colors.grey.shade600),
                        const SizedBox(height: 12),
                        Text(
                          isPersian ? 'هیچ پروکسی با این ترکیب فیلترها مطابقت ندارد.' : 'No proxies match selected filters.',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final ping = (item['ping'] as num).toDouble();
                      final isLowPing = ping < 100;

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    item['flag'] ?? '🌐',
                                    style: const TextStyle(fontSize: 26),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['name'],
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              '${ping.toStringAsFixed(0)} ms',
                                              style: TextStyle(
                                                color: isLowPing ? Colors.greenAccent : Colors.orangeAccent,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text('• پورت: ${item['port'] ?? 443}', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                                            const SizedBox(width: 8),
                                            Text('• نوسان: ${item['jitter']}ms', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, size: 20),
                                    onSelected: (format) {
                                      final rawLink = 'vless://example@1.1.1.1:443?security=reality#${item['name']}';
                                      _copyToClipboard(rawLink, format);
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(value: 'لینک خام (Raw)', child: Text('کپی لینک مستقیم (URI)')),
                                      const PopupMenuItem(value: 'Clash YAML', child: Text('کپی قطعه کد کلش')),
                                      const PopupMenuItem(value: 'Sing-box JSON', child: Text('کپی JSON سینگ‌باکس')),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Badges row: Protocol, Transport, Security, UDP, Gemini
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  _buildTag(item['proto'], Colors.blueAccent),
                                  _buildTag(item['transport'] ?? 'TCP', Colors.tealAccent),
                                  _buildTag(item['security'] ?? 'None', Colors.amberAccent),
                                  if (item['udp'] == true) _buildTag('UDP', Colors.greenAccent),
                                  if (item['gemini'] == true) _buildTag('Gemini AI 🤖', Colors.cyanAccent),
                                ],
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

  Widget _buildDropdownFilter({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : 'ALL',
          isDense: true,
          items: items.map((opt) {
            return DropdownMenuItem<String>(
              value: opt,
              child: Text(
                opt == 'ALL' ? '$label: همه' : '$label: $opt',
                style: const TextStyle(fontSize: 12),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
