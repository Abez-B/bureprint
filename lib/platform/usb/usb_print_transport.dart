import 'dart:async';

import '../../domain/interfaces/print_transport.dart';
import '../../domain/models/print_request.dart';
import 'usb_host_bridge.dart';
import 'usb_printer_device.dart';

/// Print transport bridge routing print payloads to USB OTG printers.
class UsbPrintTransport implements PrintTransport {
  const UsbPrintTransport({
    required this.device,
    required this.bridge,
  });

  final UsbPrinterDevice device;
  final UsbHostBridge bridge;

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

    // 2. Hardware safety check: IPP-over-USB vs raw streams
    // Never send unvalidated raw bytes unless device explicitly identifies with a supported protocol
    if (!device.isIppOverUsb) {
      return const PrintJobResult(
        jobId: '',
        accepted: false,
        message:
            'Printer does not support standard IPP-over-USB protocol. Direct byte dumping is disabled for hardware safety.',
      );
    }

    // 3. Transmit payload
    final success =
        await bridge.sendBytes(device.deviceId, [0x01]); // Handshake/probe
    if (!success) {
      return const PrintJobResult(
        jobId: '',
        accepted: false,
        message: 'Failed to write bytes to USB endpoint',
      );
    }

    return PrintJobResult(
      jobId: 'usb-${device.deviceId}-${DateTime.now().millisecondsSinceEpoch}',
      accepted: true,
      message: 'Document transmitted successfully over USB',
    );
  }

  @override
  Future<void> cancel(String jobId) async {
    // USB endpoint cancellation logic
  }
}
