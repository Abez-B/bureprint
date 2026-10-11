import '../../domain/models/printer_device.dart';
import 'drivers/brother_pjl_rasterizer.dart';
import 'drivers/standard_rasterizers.dart';
import 'printer_rasterizer.dart';

/// Central registry managing all brand-specific and standard printer drivers.
class PrinterDriverRegistry {
  static final List<PrinterRasterizer> _drivers = [
    const BrotherPjlRasterizer(),
    const EscPosRasterizer(),
    const StandardPclRasterizer(),
  ];

  /// Resolves the optimal driver for a connected printer device, or null if unsupported.
  static PrinterRasterizer? resolveDriver(PrinterDevice device) {
    for (final driver in _drivers) {
      if (driver.canHandle(device)) {
        return driver;
      }
    }
    return null;
  }

  /// Registers a custom driver into the registry (enables plugins/extensions).
  static void registerDriver(PrinterRasterizer driver) {
    _drivers.insert(0, driver);
  }

  /// All supported driver descriptors.
  static List<PrinterRasterizer> get availableDrivers =>
      List.unmodifiable(_drivers);
}
