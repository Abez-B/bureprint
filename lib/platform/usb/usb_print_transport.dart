import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

import '../../core/raster/document_rasterizer_engine.dart';
import '../../core/raster/drivers/pwg_rasterizer.dart';
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

  static final Set<int> _uploadedFirmwareDeviceIds = <int>{};

  @override
  Future<PrintJobResult> submit(
    PrintRequest request, {
    void Function(int currentSheet, int totalSheets, String stage)? onProgress,
  }) async {
    var activeDeviceId = device.deviceId;

    // 1. Verify USB permission
    final hasPerm = await bridge.hasPermission(activeDeviceId);
    if (!hasPerm) {
      final granted = await bridge.requestPermission(activeDeviceId);
      if (!granted) {
        return const PrintJobResult(
          jobId: '',
          accepted: false,
          message: 'USB permission was denied by user',
        );
      }
    }

    // 2. Hardware firmware upload for HP LaserJet host-based printers requiring firmware
    // (Note: HP LaserJet M1005 MFP [0x3B17] has onboard ROM firmware and does NOT require upload)
    final needsHpFirmware =
        (device.vendorId == 0x03F0 || device.vendorId == 1008) &&
            (device.productId == 0x3D17 || // P1005
                device.productId == 0x3E17 || // P1006
                device.productId == 0x4817 || // P1007
                device.productId == 0x4917 || // P1008
                device.productId == 0x3F17 || // P1505
                device.productId == 0x4017); // P1505n

    if (needsHpFirmware &&
        !_uploadedFirmwareDeviceIds.contains(activeDeviceId)) {
      final String fwAsset;
      if (device.productId == 0x3D17 || device.productId == 0x4817) {
        fwAsset = 'assets/firmware/sihpP1005.dl';
      } else {
        fwAsset = 'assets/firmware/sihpP1006.dl';
      }

      try {
        onProgress?.call(
            0, 1, 'Uploading printer firmware (${device.displayName})...');
        final data = await rootBundle.load(fwAsset);
        final fwBytes = data.buffer.asUint8List();
        final ok = await bridge.sendBytes(activeDeviceId, fwBytes);
        if (ok) {
          _uploadedFirmwareDeviceIds.add(activeDeviceId);
          // Wait 2.5 seconds for printer CPU reboot & motor reinitialization
          await Future.delayed(const Duration(milliseconds: 2500));
          // Refresh active device ID in case USB re-enumerated post reboot
          try {
            final fresh = await bridge.enumerateDevices();
            final match = fresh.firstWhere(
              (d) =>
                  d.vendorId == device.vendorId &&
                  d.productId == device.productId,
              orElse: () => device,
            );
            activeDeviceId = match.deviceId;
            _uploadedFirmwareDeviceIds.add(activeDeviceId);
            if (!await bridge.hasPermission(activeDeviceId)) {
              await bridge.requestPermission(activeDeviceId);
            }
          } catch (_) {}
        }
      } catch (_) {
        // Continue even if firmware load throws, as printer might already be booted
      }
    }

    final printerDevice = device.toPrinterDevice();
    final driver = PrinterDriverRegistry.resolveDriver(printerDevice) ??
        (device.isIppOverUsb ? const PwgRasterizer() : null);

    if (driver == null) {
      final name = '${device.displayName} ${device.deviceName}'.toLowerCase();
      String detail;
      if (name.contains('capt') || name.contains('carps')) {
        detail =
            'Canon CAPT/CARPS is a proprietary host-based protocol requiring closed-source firmware/drivers. Direct byte dumping is disabled for hardware safety.';
      } else if (name.contains('1020') || name.contains('1018')) {
        detail =
            'HP LaserJet 1018/1020 uses ZjStream/ARM protocol and requires firmware upload. Direct byte dumping is disabled for hardware safety.';
      } else {
        detail =
            'Printer does not support standard IPP-over-USB protocol. Direct byte dumping is disabled for hardware safety.';
      }

      return PrintJobResult(
        jobId: '',
        accepted: false,
        message: detail,
      );
    }

    try {
      final fileExists = File(request.filePath).existsSync();
      final List<int> payloadBytes;

      if (fileExists) {
        // 3. Rasterize document to the printer's specific native language stream
        payloadBytes = await _rasterEngine.rasterizeDocument(
          filePath: request.filePath,
          mimeType: request.mimeType,
          settings: request.settings,
          device: printerDevice,
          jobName: request.jobName,
          onProgress: (current, total) {
            onProgress?.call(
                current, total, 'Rasterizing page $current of $total...');
          },
        );
      } else {
        // Safe fallback for mock / virtual environments
        payloadBytes =
            driver.createJobHeader(request.settings, request.jobName);
      }

      if (payloadBytes.isEmpty) {
        return const PrintJobResult(
          jobId: '',
          accepted: false,
          message: 'Rasterization produced an empty document stream',
        );
      }

      // 4. Transmit payload over USB bulk endpoint
      onProgress?.call(1, 1, 'Transmitting data to printer...');
      final success = await bridge.sendBytes(activeDeviceId, payloadBytes);
      if (!success) {
        return const PrintJobResult(
          jobId: '',
          accepted: false,
          message: 'Failed to write bytes to USB endpoint',
        );
      }

      final jobId =
          'usb-$activeDeviceId-${DateTime.now().millisecondsSinceEpoch}';
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
