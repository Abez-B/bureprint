import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/documents/document_provider.dart';
import '../features/documents/documents_screen.dart';
import '../features/home/home_screen.dart';
import '../features/printers/printers_provider.dart';
import '../features/printers/printers_screen.dart';
import '../features/queue/queue_screen.dart';
import '../features/settings/settings_screen.dart';
import '../platform/share/share_sheet_bridge.dart';
import '../platform/usb/usb_host_bridge.dart';
import 'theme.dart';
import 'theme_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    errorBuilder: (context, state) {
      // Gracefully handle external content:// URIs passed by Android OS intent
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/documents');
        }
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    },
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

class BurePrintApp extends ConsumerStatefulWidget {
  const BurePrintApp({super.key});

  @override
  ConsumerState<BurePrintApp> createState() => _BurePrintAppState();
}

class _BurePrintAppState extends ConsumerState<BurePrintApp> {
  StreamSubscription<dynamic>? _usbAttachSub;
  StreamSubscription<dynamic>? _usbDetachSub;
  StreamSubscription<dynamic>? _shareSub;

  @override
  void initState() {
    super.initState();
    _initPlatformListeners();
  }

  Future<void> _initPlatformListeners() async {
    final usbBridge = ref.read(usbHostBridgeProvider);
    final shareBridge = ref.read(shareSheetBridgeProvider);

    // 1. Initial USB device check
    try {
      final devices = await usbBridge.enumerateDevices();
      if (devices.isNotEmpty) {
        ref.read(printerRegistryProvider.notifier).setUsbPrinters(devices);
        for (final d in devices) {
          ref.read(printerRegistryProvider.notifier).addOrUpdateUsbDevice(d);
        }
      }
    } catch (_) {}

    // 2. Stream USB attach & detach events
    _usbAttachSub = usbBridge.onDeviceAttached.listen((device) {
      ref.read(printerRegistryProvider.notifier).addOrUpdateUsbDevice(device);
    });

    _usbDetachSub = usbBridge.onDeviceDetached.listen((deviceId) {
      ref.read(printerRegistryProvider.notifier).removeUsbDevice(deviceId);
    });

    // 3. Initial shared files (e.g. WhatsApp, Telegram, Drive "Open With")
    try {
      final initialFiles = await shareBridge.getInitialSharedFiles();
      if (initialFiles.isNotEmpty) {
        for (final shared in initialFiles) {
          final doc = shared.toImportedDocument();
          ref.read(documentManagerProvider.notifier).addDocument(doc);
        }
        ref.read(routerProvider).go('/documents');
      }
    } catch (_) {}

    // 4. Stream shared files while running
    _shareSub = shareBridge.onFilesShared.listen((files) {
      if (files.isNotEmpty) {
        for (final shared in files) {
          final doc = shared.toImportedDocument();
          ref.read(documentManagerProvider.notifier).addDocument(doc);
        }
        ref.read(routerProvider).go('/documents');
      }
    });
  }

  @override
  void dispose() {
    _usbAttachSub?.cancel();
    _usbDetachSub?.cancel();
    _shareSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                'assets/brand/icon-512.png',
                width: 24,
                height: 24,
                filterQuality: FilterQuality.medium,
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
