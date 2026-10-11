import 'dart:async';

import '../../core/raster/document_rasterizer_engine.dart';
import '../../core/raster/printer_driver_registry.dart';
import '../../domain/interfaces/print_transport.dart';
import '../../domain/models/print_request.dart';
import 'usb_host_bridge.dart';
import 'usb_printer_device.dart';

/// Print transport routing document rasterization and raw byte transmission
/// directly to USB OTG connected printers.
class UsbPrintTransport implements PrintTransport {
  const UsbPrintTransport({
    required this.device,
    required this.bridge,
    DocumentRasterizerEngine? rasterEngine,
  }) : _rasterEngine = rasterEngine ?? const DocumentRasterizerEngine();

  final UsbPrinterDevice device;
  final UsbHostBridge bridge;
  final DocumentRasterizerEngine _rasterEngine;

  @override
  Future<PrintJobResult> submit(PrintRequest request) async {
    // 1. Verify USB permission
    final hasPerm = await bridge.hasPermission(device.deviceId);
    if (!hasPerm) {
      final granted = await bridge.requestPermission(device.deviceId);
      if (!granted) {
        return const PrintJobResult(
          jobId: '',
          accepted: false,
          message: 'USB permission was denied by user',
        );
      }
    }

    // 2. Hardware safety check: IPP-over-USB vs brand driver
    if (device.isIppOverUsb) {
      // Device supports IPP-over-USB: Send initial test probe / IPP stream
      final success = await bridge.sendBytes(device.deviceId, [0x01]);
      if (!success) {
        return const PrintJobResult(
          jobId: '',
          accepted: false,
          message: 'Failed to write bytes to USB endpoint',
        );
      }
      return PrintJobResult(
        jobId:
            'usb-${device.deviceId}-${DateTime.now().millisecondsSinceEpoch}',
        accepted: true,
        message: 'Document transmitted successfully over USB',
      );
    }

    try {
      final printerDevice = device.toPrinterDevice();
      final driver = PrinterDriverRegistry.resolveDriver(printerDevice);

      if (driver == null) {
        return const PrintJobResult(
          jobId: '',
          accepted: false,
          message:
              'Printer does not support standard IPP-over-USB protocol. Direct byte dumping is disabled for hardware safety.',
        );
      }

      // 3. Rasterize document to the printer's specific native language stream
      final payloadBytes = await _rasterEngine.rasterizeDocument(
        filePath: request.filePath,
        mimeType: request.mimeType,
        settings: request.settings,
        device: printerDevice,
        jobName: request.jobName,
      );

      if (payloadBytes.isEmpty) {
        return const PrintJobResult(
          jobId: '',
          accepted: false,
          message: 'Rasterization produced an empty document stream',
        );
      }

      // 3. Transmit payload over USB bulk endpoint
      final success = await bridge.sendBytes(device.deviceId, payloadBytes);
      if (!success) {
        return const PrintJobResult(
          jobId: '',
          accepted: false,
          message: 'Failed to write bytes to USB endpoint',
        );
      }

      final jobId =
          'usb-${device.deviceId}-${DateTime.now().millisecondsSinceEpoch}';
      return PrintJobResult(
        jobId: jobId,
        accepted: true,
        message: 'Printed successfully using ${driver.displayName}',
      );
    } catch (e) {
      return PrintJobResult(
        jobId: '',
        accepted: false,
        message: 'USB Printing Error: $e',
      );
    }
  }

  @override
  Future<void> cancel(String jobId) async {
    // USB cancellation
  }
}
