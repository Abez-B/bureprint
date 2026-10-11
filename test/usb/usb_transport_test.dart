import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

import 'package:bureprint/domain/models/print_request.dart';
import 'package:bureprint/platform/usb/usb_host_bridge.dart';
import 'package:bureprint/platform/usb/usb_print_transport.dart';
import 'package:bureprint/platform/usb/usb_printer_device.dart';

class FakeUsbHostBridge implements UsbHostBridge {
  FakeUsbHostBridge({
    this.permissionGranted = true,
    this.sendSuccess = true,
  });

  bool permissionGranted;
  bool sendSuccess;

  final _attachedController = StreamController<UsbPrinterDevice>.broadcast();
  final _detachedController = StreamController<int>.broadcast();

  @override
  Stream<UsbPrinterDevice> get onDeviceAttached => _attachedController.stream;

  @override
  Stream<int> get onDeviceDetached => _detachedController.stream;

  @override
  Future<List<UsbPrinterDevice>> enumerateDevices() async {
    return const [];
  }

  @override
  Future<bool> hasPermission(int deviceId) async => permissionGranted;

  @override
  Future<bool> requestPermission(int deviceId) async => permissionGranted;

  @override
  Future<bool> sendBytes(int deviceId, List<int> bytes) async => sendSuccess;
}

void main() {
  group('UsbPrintTransport Hardware Safety & Permissions', () {
    const ippUsbDevice = UsbPrinterDevice(
      deviceId: 1,
      vendorId: 0x03F0, // HP
      productId: 0x1234,
      deviceName: '/dev/bus/usb/001/002',
      isIppOverUsb: true,
      hasPermission: true,
    );

    const rawUsbDevice = UsbPrinterDevice(
      deviceId: 2,
      vendorId: 0x04B8, // Epson
      productId: 0x5678,
      deviceName: '/dev/bus/usb/001/003',
      isIppOverUsb: false, // Unknown / Raw protocol
      hasPermission: true,
    );

    const testRequest = PrintRequest(
      jobName: 'Test.pdf',
      filePath: '/tmp/test.pdf',
      mimeType: 'application/pdf',
      printerId: 'usb-1',
    );

    test(
        'accepts job when printer supports IPP-over-USB and permission is granted',
        () async {
      final fakeBridge =
          FakeUsbHostBridge(permissionGranted: true, sendSuccess: true);
      final transport =
          UsbPrintTransport(device: ippUsbDevice, bridge: fakeBridge);

      final result = await transport.submit(testRequest);
      expect(result.accepted, isTrue);
      expect(result.jobId, startsWith('usb-1-'));
    });

    test(
        'safely rejects transmission when printer does not support IPP-over-USB to protect hardware',
        () async {
      final fakeBridge = FakeUsbHostBridge(permissionGranted: true);
      final transport =
          UsbPrintTransport(device: rawUsbDevice, bridge: fakeBridge);

      final result = await transport.submit(testRequest);
      expect(result.accepted, isFalse);
      expect(result.message,
          contains('Direct byte dumping is disabled for hardware safety'));
    });

    test('rejects job when USB permission is denied by user', () async {
      final fakeBridge = FakeUsbHostBridge(permissionGranted: false);
      final transport =
          UsbPrintTransport(device: ippUsbDevice, bridge: fakeBridge);

      final result = await transport.submit(testRequest);
      expect(result.accepted, isFalse);
      expect(result.message, contains('USB permission was denied'));
    });
  });
}
