import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/documents/documents_screen.dart';
import '../features/home/home_screen.dart';
import '../features/printers/printers_screen.dart';
import '../features/queue/queue_screen.dart';
import '../features/settings/settings_screen.dart';
import 'theme.dart';
import 'theme_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
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
});

class BurePrintApp extends ConsumerWidget {
  const BurePrintApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'BurePrint',
      debugShowCheckedModeBanner: false,
      theme: BurePrintTheme.lightTheme,
      darkTheme: BurePrintTheme.darkTheme,
      themeMode: themeMode,
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.asset(
                'assets/brand/icon-48.png',
                width: 24,
                height: 24,
                errorBuilder: (_, __, ___) => const Icon(Icons.print, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'BurePrint',
              style:
                  TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
            ),
          ],
        ),
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected < 0 ? 0 : selected,
        onDestinationSelected: (index) => context.go(_destinations[index].path),
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
