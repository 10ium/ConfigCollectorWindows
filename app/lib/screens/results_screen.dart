import 'package:flutter/material.dart';

class ConfigItem {
  final String flag;
  final String country;
  final String protocol;
  final double ping;
  final bool udp;
  final double packetLoss;
  final double jitter;
  final int fraud;
  final double score;
  final String uri;

  ConfigItem({
    required this.flag,
    required this.country,
    required this.protocol,
    required this.ping,
    required this.udp,
    required this.packetLoss,
    required this.jitter,
    required this.fraud,
    required this.score,
    required this.uri,
  });
}

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';

    final sampleResults = [
      ConfigItem(
        flag: '🇩🇪',
        country: 'DE',
        protocol: 'VLESS',
        ping: 68.2,
        udp: true,
        packetLoss: 0.0,
        jitter: 2.1,
        fraud: 5,
        score: 96.48214,
        uri: 'vless://uuid@server1:443?security=reality',
      ),
      ConfigItem(
        flag: '🇫🇮',
        country: 'FI',
        protocol: 'HY2',
        ping: 89.5,
        udp: true,
        packetLoss: 0.0,
        jitter: 3.4,
        fraud: 8,
        score: 92.15832,
        uri: 'hy2://pass@server2:8443?insecure=1',
      ),
      ConfigItem(
        flag: '🇳🇱',
        country: 'NL',
        protocol: 'VLESS',
        ping: 115.0,
        udp: true,
        packetLoss: 0.0,
        jitter: 4.8,
        fraud: 12,
        score: 87.34125,
        uri: 'vless://uuid@server3:443',
      ),
      ConfigItem(
        flag: '🇹🇷',
        country: 'TR',
        protocol: 'VMESS',
        ping: 142.0,
        udp: false,
        packetLoss: 0.0,
        jitter: 7.2,
        fraud: 15,
        score: 74.89201,
        uri: 'vmess://base64json',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(isPersian ? 'نتایج زنده و رتبه‌بندی کیفی' : 'Live Results & Quality Ranking'),
        actions: [
          IconButton(
            tooltip: isPersian ? 'کپی تمام کانفیگ‌های سالم' : 'Copy All Survivors',
            icon: const Icon(Icons.copy_all),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(isPersian ? 'تمام کانفیگ‌ها در کلیپ‌بورد کپی شدند' : 'All configs copied to clipboard')),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: sampleResults.length,
        itemBuilder: (context, index) {
          final item = sampleResults[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12.0),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: index == 0
                    ? Colors.amber.shade100
                    : Theme.of(context).colorScheme.surfaceVariant,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: index == 0 ? Colors.amber.shade900 : null,
                  ),
                ),
              ),
              title: Row(
                children: [
                  Text(item.flag, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    '${item.country} | ${item.protocol}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  if (item.udp)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('UDP', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              subtitle: Text(
                isPersian
                    ? 'تاخیر: ${item.ping.toStringAsFixed(0)}ms | پکت‌لاس: ${item.packetLoss.toInt()}% | جیتر: ${item.jitter.toStringAsFixed(1)}ms'
                    : 'Latency: ${item.ping.toStringAsFixed(0)}ms | Loss: ${item.packetLoss.toInt()}% | Jitter: ${item.jitter.toStringAsFixed(1)}ms',
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${item.score.toStringAsFixed(2)} ★',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  Text(
                    '#${item.score.toStringAsFixed(5)}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
