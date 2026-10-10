import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/documents/documents_screen.dart';
import '../features/home/home_screen.dart';
import '../features/printers/printers_screen.dart';
import '../features/queue/queue_screen.dart';
import '../features/settings/settings_screen.dart';

class BurePrintApp extends StatelessWidget {
  const BurePrintApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(
            location: state.uri.path,
            child: child,
          ),
          routes: [
            GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
            GoRoute(
              path: '/documents',
              builder: (_, __) => const DocumentsScreen(),
            ),
            GoRoute(
              path: '/printers',
              builder: (_, __) => const PrintersScreen(),
            ),
            GoRoute(path: '/queue', builder: (_, __) => const QueueScreen()),
            GoRoute(
              path: '/settings',
              builder: (_, __) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      title: 'BurePrint',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF246B57),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8F6),
        appBarTheme: const AppBarTheme(centerTitle: false),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF65C7A5),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  static const _destinations = [
    _Destination('Home', '/', Icons.home_outlined),
    _Destination('Documents', '/documents', Icons.description_outlined),
    _Destination('Printers', '/printers', Icons.print_outlined),
    _Destination('Queue', '/queue', Icons.list_alt_outlined),
    _Destination('Settings', '/settings', Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = _destinations.indexWhere((d) => d.path == location);
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.print_rounded),
            SizedBox(width: 10),
            Text('BurePrint', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected < 0 ? 0 : selected,
        onDestinationSelected: (index) =>
            context.go(_destinations[index].path),
        destinations: [
          for (final destination in _destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.path, this.icon);
  final String label;
  final String path;
  final IconData icon;
}
