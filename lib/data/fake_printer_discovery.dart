import '../domain/interfaces/printer_discovery.dart';
import '../domain/models/printer_device.dart';

/// Temporary source used to develop the UI before real mDNS/IPP discovery exists.
class FakePrinterDiscovery implements PrinterDiscovery {
  @override
  Stream<PrinterDevice> discover() async* {
    yield const PrinterDevice(
      id: 'demo-network-printer',
      name: 'Demo Network Printer',
      connectionType: PrinterConnectionType.network,
      host: '192.168.1.50',
      isOnline: true,
      model: 'Demo only',
    );
  }
}
