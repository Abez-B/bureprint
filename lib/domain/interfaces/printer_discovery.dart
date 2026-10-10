import '../models/printer_device.dart';

abstract interface class PrinterDiscovery {
  Stream<PrinterDevice> discover();
}
