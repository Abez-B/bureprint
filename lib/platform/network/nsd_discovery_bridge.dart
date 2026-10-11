import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/interfaces/printer_discovery.dart';
import '../../domain/models/printer_device.dart';

/// Dart abstract interface for Network Service Discovery (mDNS IPP/IPPS).
abstract interface class NsdDiscoveryBridge implements PrinterDiscovery {
  Future<bool> startDiscovery();
  Future<bool> stopDiscovery();
  Stream<PrinterDevice> get onPrinterDiscovered;
  Stream<String> get onPrinterLost;
}

/// Production implementation of NsdDiscoveryBridge communicating with Android NsdManager.
class AndroidNsdDiscoveryBridge implements NsdDiscoveryBridge {
  AndroidNsdDiscoveryBridge({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methodChannel =
            methodChannel ?? const MethodChannel('org.bureprint/nsd_discovery'),
        _eventChannel =
            eventChannel ?? const EventChannel('org.bureprint/nsd_events') {
    _initEventListener();
  }

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  final _discoveredController = StreamController<PrinterDevice>.broadcast();
  final _lostController = StreamController<String>.broadcast();
  StreamSubscription<dynamic>? _eventSubscription;

  bool get _isSupportedPlatform =>
      Platform.isAndroid || Platform.environment.containsKey('FLUTTER_TEST');

  void _initEventListener() {
    if (!_isSupportedPlatform) return;
    try {
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is Map) {
            final eventType = event['event'] as String?;
            if (eventType == 'serviceResolved') {
              final printer = _parseResolvedService(event);
              if (printer != null) {
                _discoveredController.add(printer);
              }
            } else if (eventType == 'serviceLost') {
              final name = event['name'] as String?;
              if (name != null) {
                _lostController.add(name);
              }
            }
          }
        },
        onError: (_) {
          // Gracefully ignore event channel errors in headless test environments
        },
      );
    } catch (_) {
      // Platform channel may be unavailable in pure Dart tests
    }
  }

  PrinterDevice? _parseResolvedService(Map<dynamic, dynamic> event) {
    try {
      final host = event['host'] as String?;
      final port = event['port'] as int? ?? 631;
      final serviceName = event['name'] as String? ?? 'Network Printer';
      final serviceType = event['serviceType'] as String? ?? '_ipp._tcp.';

      if (host == null || host.isEmpty) return null;

      final rawAttributes = event['attributes'];
      final attributes = rawAttributes is Map
          ? rawAttributes.map((k, v) => MapEntry(k.toString(), v.toString()))
          : <String, String>{};

      // 1. Resolve queue path from TXT record 'rp' (Resource Path)
      var resourcePath = attributes['rp'] ?? '/ipp/print';
      if (!resourcePath.startsWith('/')) {
        resourcePath = '/$resourcePath';
      }

      // 2. Resolve display name: prefer 'ty' (Printer Make & Model) over raw mDNS serviceName
      var displayName = attributes['ty']?.trim() ?? '';
      if (displayName.isEmpty) {
        displayName = serviceName;
      }

      // 3. Resolve transport security
      final isSecure = serviceType.contains('_ipps') || port == 443;
      final securityPolicy = isSecure
          ? TransportSecurityPolicy.ippsStrict
          : TransportSecurityPolicy.plainIppExplicit;

      final printerId = 'net-${host.replaceAll('.', '-')}-$port';

      return PrinterDevice(
        id: printerId,
        name: displayName,
        connectionType: PrinterConnectionType.network,
        host: host,
        port: port,
        resourcePath: resourcePath,
        securityPolicy: securityPolicy,
        isOnline: true,
        isDiscovered: true,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<PrinterDevice> discover() => _discoveredController.stream;

  @override
  Stream<PrinterDevice> get onPrinterDiscovered => _discoveredController.stream;

  @override
  Stream<String> get onPrinterLost => _lostController.stream;

  @override
  Future<bool> startDiscovery() async {
    if (!_isSupportedPlatform) return false;
    try {
      final result = await _methodChannel.invokeMethod<bool>('startDiscovery');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> stopDiscovery() async {
    if (!_isSupportedPlatform) return false;
    try {
      final result = await _methodChannel.invokeMethod<bool>('stopDiscovery');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _eventSubscription?.cancel();
    _discoveredController.close();
    _lostController.close();
  }
}

final nsdDiscoveryBridgeProvider = Provider<NsdDiscoveryBridge>((ref) {
  final bridge = AndroidNsdDiscoveryBridge();
  ref.onDispose(bridge.dispose);
  return bridge;
});
