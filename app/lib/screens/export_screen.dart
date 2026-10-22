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

  // Export mode for Mihomo: 'full_config' (Default) vs 'proxy_provider'
  String _mihomoExportType = 'full_config';

  // Overall limit for Mihomo config
  int _totalMaxProxies = 600;
  bool _totalMaxUnlimited = false;

  // Filter settings
  double _minScore = 0.0;
  bool _onlyGemini = false;
  bool _filterPreviouslySent = true;

  // Protocol priority order (Reorderable / Drag & Drop)
  List<String> _protocolPriority = [];

  // Per-protocol limits
  Map<String, int> _protocolLimits = {};

  // System Tray & Quiet Hours
  bool _minimizeToTray = true;
  bool _quietHoursEnabled = false;
  late TextEditingController _quietStartCtrl;
  late TextEditingController _quietEndCtrl;

  @override
  void initState() {
    super.initState();
    _quietStartCtrl = TextEditingController(text: '23:00');
    _quietEndCtrl = TextEditingController(text: '07:00');
    _loadFromConfig();
  }

  void _loadFromConfig() {
    final of = _config.settings['output_filters'] ?? {};
    _mihomoExportType = of['export_type'] ?? 'full_config';
    _totalMaxProxies = of['total_max_proxies'] ?? 600;
    _totalMaxUnlimited = of['total_max_unlimited'] ?? false;
    _minScore = (of['min_score'] ?? 0.0).toDouble();
    _onlyGemini = of['only_gemini_passed'] ?? false;
    _filterPreviouslySent = of['filter_previously_sent'] ?? true;

    final rawPriority = of['protocol_priority'] as List?;
    if (rawPriority != null && rawPriority.isNotEmpty) {
      _protocolPriority = rawPriority.map((e) => e.toString()).toList();
      for (final p in ConfigService.allCategorizedProtocols) {
        if (!_protocolPriority.contains(p)) {
          _protocolPriority.add(p);
        }
      }
    } else {
      _protocolPriority = List.from(ConfigService.allCategorizedProtocols);
    }

    final rawLimits = of['per_protocol_limits'] as Map<String, dynamic>? ?? {};
    _protocolLimits = {};
    for (final p in _protocolPriority) {
      if (rawLimits.containsKey(p)) {
        _protocolLimits[p] = (rawLimits[p] ?? 0) as int;
      } else {
        _protocolLimits[p] = (p == 'VLESS' || p == 'Hysteria 2') ? 100 : 50;
      }
    }

    final tray = _config.settings['system_tray'] ?? {};
    _minimizeToTray = tray['minimize_to_tray_on_close'] ?? true;

    final qh = _config.settings['quiet_hours'] ?? {};
    _quietHoursEnabled = qh['enabled'] ?? false;
    _quietStartCtrl.text = qh['start_time'] ?? '23:00';
    _quietEndCtrl.text = qh['end_time'] ?? '07:00';
  }

  @override
  void dispose() {
    _quietStartCtrl.dispose();
    _quietEndCtrl.dispose();
    super.dispose();
  }

  void _saveFilters() {
    _autoSaveQuietly();
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isPersian ? 'تنظیمات فیلترهای خروجی با موفقیت ذخیره شد.' : 'Output settings saved successfully.'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _autoSaveQuietly() {
    _config.updateSetting('output_filters', 'export_type', _mihomoExportType);
    _config.updateSetting('output_filters', 'total_max_proxies', _totalMaxProxies);
    _config.updateSetting('output_filters', 'total_max_unlimited', _totalMaxUnlimited);
    _config.updateSetting('output_filters', 'min_score', _minScore);
    _config.updateSetting('output_filters', 'only_gemini_passed', _onlyGemini);
    _config.updateSetting('output_filters', 'filter_previously_sent', _filterPreviouslySent);
    _config.updateSetting('output_filters', 'protocol_priority', _protocolPriority);
    _config.updateSetting('output_filters', 'per_protocol_limits', _protocolLimits);

    _config.updateSetting('system_tray', 'minimize_to_tray_on_close', _minimizeToTray);
    _config.updateSetting('quiet_hours', 'enabled', _quietHoursEnabled);
    _config.updateSetting('quiet_hours', 'start_time', _quietStartCtrl.text.trim());
    _config.updateSetting('quiet_hours', 'end_time', _quietEndCtrl.text.trim());

    _config.saveSettings();
  }

  void _resetToDefaults() {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';
    setState(() {
      _mihomoExportType = 'full_config';
      _totalMaxProxies = 600;
      _totalMaxUnlimited = false;
      _minScore = 0.0;
      _onlyGemini = false;
      _filterPreviouslySent = false;
      _protocolPriority = List.from(ConfigService.allCategorizedProtocols);
      _protocolLimits = {};
      for (final p in _protocolPriority) {
        _protocolLimits[p] = (p == 'VLESS' || p == 'Hysteria 2') ? 100 : ((p == 'Trojan') ? 80 : ((p == 'VMess') ? 60 : 0));
      }
      _minimizeToTray = true;
      _quietHoursEnabled = false;
      _quietStartCtrl.text = '23:00';
      _quietEndCtrl.text = '07:00';
    });
    _autoSaveQuietly();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isPersian ? 'تنظیمات فیلترها و اولویت‌ها به حالت پیش‌فرض بازگشت.' : 'Filters & priorities reset to defaults.'),
        backgroundColor: Colors.blueAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';

    return Scaffold(
      appBar: AppBar(
        title: Text(isPersian ? 'خروجی‌ها، اولویت‌بندی و سقف پروتکل‌ها' : 'Exports, Priority & Protocol Caps'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: isPersian ? 'بازگردانی به مقادیر پیش‌فرض' : 'Reset to Defaults',
            onPressed: _resetToDefaults,
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _saveFilters,
            icon: const Icon(Icons.save),
            label: Text(isPersian ? 'ذخیره دستی' : 'Save'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // Banner Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.tealAccent.withOpacity(0.35)),
            ),
            color: Theme.of(context).cardColor,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.folder_zip, color: Colors.tealAccent, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isPersian
                          ? 'تولید خروجی‌ها ۱۰۰٪ خودکار است: پس از پایان هر چرخه آزمون، فایل‌های خروجی در پوشه‌های تفکیک‌شده (output/clash/, output/singbox/, output/xray/, output/telegram/, output/dns_tunnels/) ساخته و ذخیره می‌شوند.'
                          : 'Automatic exports: Output files are saved into dedicated folders (output/clash/, output/singbox/, output/xray/, output/telegram/, output/dns_tunnels/) automatically when tests complete.',
                      style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _config.openOutputFolder(),
                    icon: const Icon(Icons.folder_open),
                    label: Text(isPersian ? 'باز کردن پوشه خروجی‌ها' : 'Open Output Folder'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 1: Mihomo Export Type (Full Config vs Proxy Provider)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.cyanAccent.withOpacity(0.35)),
            ),
            color: Theme.of(context).cardColor,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune, color: Colors.cyanAccent, size: 26),
                      const SizedBox(width: 10),
                      Text(
                        isPersian ? 'نوع کانفیگ خروجی میهومو (Mihomo Configuration Type)' : 'Mihomo Export Format',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  RadioListTile<String>(
                    title: Text(isPersian ? '۱. کانفیگ کامل میهومو (Full Config - پیشنهادی)' : '1. Full Mihomo Config (Recommended)'),
                    subtitle: Text(
                      isPersian
                          ? 'شامل پورت‌های ترکیبی، DNS محلی، رول‌های تفکیک ترافیک ایران و گروه‌های پروکسی (Auto-Select، Fallback، انتخاب دستی)'
                          : 'Complete importable config with mixed-port, DNS, smart rules, and auto-select proxy groups.',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
                    value: 'full_config',
                    groupValue: _mihomoExportType,
                    onChanged: (v) {
                      setState(() => _mihomoExportType = v!);
                      _autoSaveQuietly();
                    },
                  ),
                  RadioListTile<String>(
                    title: Text(isPersian ? '۲. پروکسی پروایدر (Proxy Provider YAML)' : '2. Proxy Provider YAML'),
                    subtitle: Text(
                      isPersian
                          ? 'فقط لیست نودهای سالم در قالب استاندارد کلش برای استفاده به عنوان سابسکریپشن/پروایدر در کلاینت‌ها'
                          : 'Pure proxies array for use as a remote provider inside existing configs.',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
                    value: 'proxy_provider',
                    groupValue: _mihomoExportType,
                    onChanged: (v) {
                      setState(() => _mihomoExportType = v!);
                      _autoSaveQuietly();
                    },
                  ),
                  const SizedBox(height: 12),
                  // Total Maximum Cap for Mihomo Config
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPersian
                                  ? 'سقف کل تعداد نودها در خروجی میهومو: ${_totalMaxUnlimited ? "نامحدود" : "$_totalMaxProxies نود"}'
                                  : 'Total Proxy Cap: ${_totalMaxUnlimited ? "Unlimited" : "$_totalMaxProxies proxies"}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (!_totalMaxUnlimited)
                              Slider(
                                min: 50,
                                max: 2000,
                                divisions: 39,
                                value: _totalMaxProxies.toDouble(),
                                onChanged: (v) {
                                  setState(() => _totalMaxProxies = v.toInt());
                                  _autoSaveQuietly();
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      FilterChip(
                        label: Text(isPersian ? 'تعداد نامحدود' : 'Unlimited'),
                        selected: _totalMaxUnlimited,
                        onSelected: (val) {
                          setState(() => _totalMaxUnlimited = val);
                          _autoSaveQuietly();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 2: Drag & Drop Protocol Priority & Per-Protocol Caps
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.indigoAccent.withOpacity(0.35)),
            ),
            color: Theme.of(context).cardColor,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.drag_indicator, color: Colors.indigoAccent, size: 26),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPersian ? 'اولویت‌بندی ۳۰ پروتکل (چینش ترتیبی با Drag & Drop)' : 'Protocol Priority (Drag & Drop) & Limits',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                isPersian
                                    ? 'خروجی به ترتیب از بالا به پایین پر می‌شود؛ سقف ۰ به معنای حذف کامل آن پروتکل از خروجی است.'
                                    : 'Fills from top to bottom based on caps. Setting 0 completely excludes that protocol.',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.indigo.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 18, color: Colors.indigoAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isPersian
                                ? 'نحوه تخصیص: ابتدا پروتکل ردیف ۱ تا سقف تعیین‌شده پر می‌شود، سپس ردیف ۲ و بعدی‌ها تا زمانی که مجموع به سقف کل خروجی برسد.'
                                : 'Sequential filling: Highest priority protocols are filled first up to their cap until total limit is reached.',
                            style: const TextStyle(fontSize: 11, color: Colors.indigoAccent),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 420,
                    child: ReorderableListView.builder(
                      shrinkWrap: true,
                      itemCount: _protocolPriority.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = _protocolPriority.removeAt(oldIndex);
                          _protocolPriority.insert(newIndex, item);
                        });
                        _autoSaveQuietly();
                      },
                      itemBuilder: (context, index) {
                        final proto = _protocolPriority[index];
                        final cap = _protocolLimits[proto] ?? 0;
                        final isExcluded = (cap == 0);

                        return Container(
                          key: ValueKey(proto),
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isExcluded
                                ? Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5)
                                : Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isExcluded
                                  ? Colors.red.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                '#${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isExcluded ? Colors.grey : Colors.blueAccent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Row(
                                  children: [
                                    Text(
                                      proto,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isExcluded ? Colors.grey.shade500 : Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (isExcluded)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isPersian ? 'حذف از خروجی' : 'Excluded',
                                          style: const TextStyle(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                isPersian ? 'سقف:' : 'Cap:',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 75,
                                height: 36,
                                child: TextFormField(
                                  initialValue: '$cap',
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isExcluded ? Colors.redAccent : Colors.white,
                                  ),
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                    hintText: '۰ = حذف',
                                  ),
                                  onChanged: (v) {
                                    final parsed = int.tryParse(v.trim()) ?? 0;
                                    setState(() {
                                      _protocolLimits[proto] = parsed;
                                    });
                                    _autoSaveQuietly();
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 3: General Output Filters (Score, Gemini, Deduplication)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.amberAccent.withOpacity(0.35)),
            ),
            color: Theme.of(context).cardColor,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPersian ? 'فیلترهای کیفی خروجی' : 'Quality Filters',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Divider(height: 20),
                  Text(isPersian ? 'حداقل امتیاز نود: ${_minScore.toInt()} از ۱۰۰' : 'Min Composite Score: ${_minScore.toInt()} / 100'),
                  Slider(
                    min: 0,
                    max: 100,
                    divisions: 20,
                    value: _minScore,
                    onChanged: (v) {
                      setState(() => _minScore = v);
                      _autoSaveQuietly();
                    },
                  ),
                  SwitchListTile(
                    title: Text(isPersian ? 'فقط کانفیگ‌های تاییدشده توسط هوش مصنوعی جمنای' : 'Only Gemini Passed Configs'),
                    subtitle: Text(isPersian ? 'صرفاً پروکسی‌هایی که توانسته‌اند با موفقیت سایت یا API جمنای را باز کنند' : 'Only include proxies passing Google Gemini test'),
                    value: _onlyGemini,
                    onChanged: (v) {
                      setState(() => _onlyGemini = v);
                      _autoSaveQuietly();
                    },
                  ),
                  SwitchListTile(
                    title: Text(isPersian ? 'حافظه عدم تکرار (عدم ارسال مجدد کانفیگ‌های تکراری)' : 'Deduplication Memory'),
                    subtitle: Text(isPersian ? 'کانفیگ‌هایی که در دوره‌های قبلی ارسال شده‌اند را نادیده بگیرد' : 'Skip proxies sent in previous sessions'),
                    value: _filterPreviouslySent,
                    onChanged: (v) {
                      setState(() => _filterPreviouslySent = v);
                      _autoSaveQuietly();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 4: System Tray & Quiet Hours
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.withOpacity(0.25)),
            ),
            color: Theme.of(context).cardColor,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPersian ? 'رفتار بستن پنجره و ساعت سکوت' : 'Window Close Behavior & Quiet Hours',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Divider(height: 20),
                  SwitchListTile(
                    title: Text(isPersian ? 'کوچک شدن به کنار ساعت با زدن ضربدر (Minimize to Tray)' : 'Minimize to System Tray on Close'),
                    subtitle: Text(
                      isPersian
                          ? 'در صورت فعال بودن، با زدن ضربدر پنجره برنامه باز می‌ماند و به سینی کنار ساعت می‌رود. در غیر این صورت کاملاً بسته می‌شود.'
                          : 'When enabled, clicking window close (X) minimizes to tray instead of quitting.',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
                    value: _minimizeToTray,
                    onChanged: (v) {
                      setState(() => _minimizeToTray = v);
                      _autoSaveQuietly();
                    },
                  ),
                  SwitchListTile(
                    title: Text(isPersian ? 'فعال‌سازی ساعت سکوت (Quiet Hours)' : 'Enable Quiet Hours'),
                    subtitle: Text(
                      isPersian ? 'در این بازه زمانی هیچ پیامی به تلگرام ارسال نخواهد شد.' : 'Suppresses all notifications and Telegram dispatches during this interval.',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
                    value: _quietHoursEnabled,
                    onChanged: (v) {
                      setState(() => _quietHoursEnabled = v);
                      _autoSaveQuietly();
                    },
                  ),
                  if (_quietHoursEnabled) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _quietStartCtrl,
                            onChanged: (_) => _autoSaveQuietly(),
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: isPersian ? 'شروع سکوت (مثلاً ۲۳:۰۰)' : 'Start Time (e.g. 23:00)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _quietEndCtrl,
                            onChanged: (_) => _autoSaveQuietly(),
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: isPersian ? 'پایان سکوت (مثلاً ۰۷:۰۰)' : 'End Time (e.g. 07:00)',
                            ),
                          ),
                        ),
                      ],
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
