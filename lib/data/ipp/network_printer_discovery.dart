import 'dart:async';

import '../../domain/interfaces/printer_discovery.dart';
import '../../domain/models/printer_device.dart';

class NetworkPrinterDiscovery implements PrinterDiscovery {
  NetworkPrinterDiscovery();

  final _controller = StreamController<PrinterDevice>.broadcast();

  @override
  Stream<PrinterDevice> discover() {
    return _controller.stream;
  }

  /// Adds a manually configured printer device (static IP / hostname).
  void addManualPrinter({
    required String name,
    required String host,
    int port = 631,
    String resourcePath = '/ipp/print',
    TransportSecurityPolicy securityPolicy = TransportSecurityPolicy.ippsStrict,
  }) {
    final printer = PrinterDevice(
      id: 'manual-${host.replaceAll(".", "-")}-$port',
      name: name,
      connectionType: PrinterConnectionType.network,
      host: host,
      port: port,
      resourcePath: resourcePath,
      securityPolicy: securityPolicy,
      isOnline: true,
      isDiscovered: false,
    );
    _controller.add(printer);
  }

  void dispose() {
    _controller.close();
  }
}
