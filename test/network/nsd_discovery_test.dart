import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bureprint/domain/models/printer_device.dart';
import 'package:bureprint/platform/network/nsd_discovery_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AndroidNsdDiscoveryBridge Tests', () {
    late AndroidNsdDiscoveryBridge bridge;
    late List<MethodCall> methodCalls;
    late StreamController<dynamic> fakeEventStream;

    setUp(() {
      methodCalls = [];
      fakeEventStream = StreamController<dynamic>.broadcast();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('org.bureprint/nsd_discovery'),
        (MethodCall call) async {
          methodCalls.add(call);
          if (call.method == 'startDiscovery') return true;
          if (call.method == 'stopDiscovery') return true;
          return null;
        },
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
        const EventChannel('org.bureprint/nsd_events'),
        MockStreamHandler.inline(
          onListen: (args, sink) {
            fakeEventStream.stream.listen(
              (event) => sink.success(event),
              onError: (err) =>
                  sink.error(code: 'ERROR', message: err.toString()),
            );
          },
        ),
      );

      bridge = AndroidNsdDiscoveryBridge();
    });

    tearDown(() {
      bridge.dispose();
      fakeEventStream.close();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('org.bureprint/nsd_discovery'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
        const EventChannel('org.bureprint/nsd_events'),
        null,
      );
    });

    test('startDiscovery invokes platform method', () async {
      final success = await bridge.startDiscovery();
      expect(success, isTrue);
      expect(methodCalls.map((c) => c.method), contains('startDiscovery'));
    });

    test('stopDiscovery invokes platform method', () async {
      final success = await bridge.stopDiscovery();
      expect(success, isTrue);
      expect(methodCalls.map((c) => c.method), contains('stopDiscovery'));
    });

    test('parses resolved IPP printer with TXT attributes', () async {
      final discoveredPrinters = <PrinterDevice>[];
      final sub = bridge.onPrinterDiscovered.listen(discoveredPrinters.add);

      // Emit simulated mDNS resolve event
      fakeEventStream.add({
        'event': 'serviceResolved',
        'name': 'Office-Printer',
        'host': '192.168.1.120',
        'port': 631,
        'serviceType': '_ipp._tcp.',
        'attributes': {
          'rp': 'printers/OfficeLaser',
          'ty': 'HP LaserJet Pro M404n',
          'pdl': 'application/pdf,image/pwg-raster',
        },
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(discoveredPrinters, hasLength(1));
      final printer = discoveredPrinters.first;
      expect(printer.id, equals('net-192-168-1-120-631'));
      expect(printer.name, equals('HP LaserJet Pro M404n'));
      expect(printer.host, equals('192.168.1.120'));
      expect(printer.port, equals(631));
      expect(printer.resourcePath, equals('/printers/OfficeLaser'));
      expect(printer.securityPolicy,
          equals(TransportSecurityPolicy.plainIppExplicit));
      expect(printer.connectionType, equals(PrinterConnectionType.network));
      expect(printer.isOnline, isTrue);
      expect(printer.isDiscovered, isTrue);
    });

    test('parses secure IPPS printer with default queue path', () async {
      final discoveredPrinters = <PrinterDevice>[];
      final sub = bridge.onPrinterDiscovered.listen(discoveredPrinters.add);

      fakeEventStream.add({
        'event': 'serviceResolved',
        'name': 'Epson WorkForce Secure',
        'host': '192.168.1.188',
        'port': 443,
        'serviceType': '_ipps._tcp.',
        'attributes': <String, String>{},
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(discoveredPrinters, hasLength(1));
      final printer = discoveredPrinters.first;
      expect(printer.id, equals('net-192-168-1-188-443'));
      expect(printer.name, equals('Epson WorkForce Secure'));
      expect(printer.resourcePath, equals('/ipp/print'));
      expect(
          printer.securityPolicy, equals(TransportSecurityPolicy.ippsStrict));
    });

    test('ignores invalid or empty host events safely', () async {
      final discoveredPrinters = <PrinterDevice>[];
      final sub = bridge.onPrinterDiscovered.listen(discoveredPrinters.add);

      fakeEventStream.add({
        'event': 'serviceResolved',
        'name': 'Faulty Printer',
        'host': '',
        'port': 631,
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(discoveredPrinters, isEmpty);
    });
  });
}
