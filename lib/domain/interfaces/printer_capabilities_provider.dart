import '../models/printer_capabilities.dart';
import '../models/printer_device.dart';

abstract interface class PrinterCapabilitiesProvider {
  Future<PrinterCapabilities> getCapabilities(PrinterDevice printer);
}
