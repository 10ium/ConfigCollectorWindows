import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/sources_screen.dart';
import 'screens/tester_screen.dart';
import 'screens/results_screen.dart';
import 'screens/export_screen.dart';
import 'screens/scheduler_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FreedomConfigCollectorApp());
}

class FreedomConfigCollectorApp extends StatefulWidget {
  const FreedomConfigCollectorApp({super.key});

  static _FreedomConfigCollectorAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_FreedomConfigCollectorAppState>();

  @override
  State<FreedomConfigCollectorApp> createState() =>
      _FreedomConfigCollectorAppState();
}

class _FreedomConfigCollectorAppState extends State<FreedomConfigCollectorApp> {
  Locale _locale = const Locale('fa');
  ThemeMode _themeMode = ThemeMode.system;

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  void setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Freedom Config Collector',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: _themeMode,
      locale: _locale,
      supportedLocales: const [
        Locale('fa'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    SourcesScreen(),
    TesterScreen(),
    ResultsScreen(),
    ExportScreen(),
    SchedulerScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 720;
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';

    final navDestinations = [
      NavigationDestination(
        icon: const Icon(Icons.dashboard_outlined),
        selectedIcon: const Icon(Icons.dashboard),
        label: isPersian ? 'داشبورد' : 'Dashboard',
      ),
      NavigationDestination(
        icon: const Icon(Icons.hub_outlined),
        selectedIcon: const Icon(Icons.hub),
        label: isPersian ? 'منابع' : 'Sources',
      ),
      NavigationDestination(
        icon: const Icon(Icons.tune_outlined),
        selectedIcon: const Icon(Icons.tune),
        label: isPersian ? 'تستر' : 'Tester',
      ),
      NavigationDestination(
        icon: const Icon(Icons.list_alt_outlined),
        selectedIcon: const Icon(Icons.list_alt),
        label: isPersian ? 'نتایج' : 'Results',
      ),
      NavigationDestination(
        icon: const Icon(Icons.file_download_outlined),
        selectedIcon: const Icon(Icons.file_download),
        label: isPersian ? 'خروجی' : 'Export',
      ),
      NavigationDestination(
        icon: const Icon(Icons.alarm_outlined),
        selectedIcon: const Icon(Icons.alarm),
        label: isPersian ? 'زمان‌بندی' : 'Scheduler',
      ),
      NavigationDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings),
        label: isPersian ? 'تنظیمات' : 'Settings',
      ),
    ];

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (idx) =>
                  setState(() => _selectedIndex = idx),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.bolt, color: Colors.white),
                ),
              ),
              destinations: navDestinations
                  .map(
                    (d) => NavigationRailDestination(
                      icon: d.icon,
                      selectedIcon: d.selectedIcon,
                      label: Text(d.label),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: _screens[_selectedIndex]),
          ],
        ),
      );
    }

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: navDestinations,
      ),
    );
  }
}
