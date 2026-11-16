import 'package:flutter/foundation.dart';
import '../../domain/models/printer_device.dart';

@immutable
class UsbPrinterDevice {
  const UsbPrinterDevice({
    required this.deviceId,
    required this.vendorId,
    required this.productId,
    required this.deviceName,
    this.manufacturerName,
    this.productName,
    this.hasPermission = false,
    this.isIppOverUsb = false,
  });

  final int deviceId;
  final int vendorId;
  final int productId;
  final String deviceName;
  final String? manufacturerName;
  final String? productName;
  final bool hasPermission;
  final bool isIppOverUsb;

  String get displayName {
    if (productName != null && productName!.isNotEmpty) {
      return productName!;
    }
    if (manufacturerName != null && manufacturerName!.isNotEmpty) {
      return manufacturerName!;
    }
    // Map known USB printer IDs to their real hardware names
    if (vendorId == 0x03F0) {
      // HP (1008 in decimal)
      return switch (productId) {
        0x3B17 => 'HP LaserJet M1005 MFP',
        0x3D17 => 'HP LaserJet P1005',
        0x3E17 => 'HP LaserJet P1006',
        0x4817 => 'HP LaserJet P1007',
        0x4917 => 'HP LaserJet P1008',
        0x3F17 => 'HP LaserJet P1505',
        0x4017 => 'HP LaserJet P1505n',
        0x4117 => 'HP LaserJet 1018',
        0x2B17 => 'HP LaserJet 1020',
        _ => 'HP Printer ($vendorId:$productId)',
      };
    }
    if (vendorId == 0x04A9) {
      // Canon (1193 in decimal)
      return switch (productId) {
        0x2676 => 'Canon LBP2900 (CAPT)',
        0x266A => 'Canon LBP3000 (CAPT)',
        0x26DA => 'Canon LBP3010/LBP3018 (CAPT)',
        0x26E0 => 'Canon LBP3100/LBP3108 (CAPT)',
        0x26ED => 'Canon LBP6000/LBP6018 (CAPT)',
        _ => 'Canon USB Device ($vendorId:$productId)',
      };
    }
    if (vendorId == 0x04B8) {
      // Epson (1208 in decimal)
      return 'Epson USB Printer ($vendorId:$productId)';
    }
    if (vendorId == 0x04E8) {
      // Samsung (1256 in decimal)
      return 'Samsung Laser Printer ($vendorId:$productId)';
    }
    if (vendorId == 0x04F9) {
      // Brother (1273 in decimal)
      return 'Brother USB Printer ($vendorId:$productId)';
    }
    if (vendorId == 0x0A5F) {
      // Zebra (2655 in decimal)
      return 'Zebra Thermal Label Printer ($vendorId:$productId)';
    }
    return 'USB Printer ($vendorId:$productId)';
  }

  UsbPrinterDevice copyWith({
    int? deviceId,
    int? vendorId,
    int? productId,
    String? deviceName,
    String? manufacturerName,
    String? productName,
    bool? hasPermission,
    bool? isIppOverUsb,
  }) {
    return UsbPrinterDevice(
      deviceId: deviceId ?? this.deviceId,
      vendorId: vendorId ?? this.vendorId,
      productId: productId ?? this.productId,
      deviceName: deviceName ?? this.deviceName,
      manufacturerName: manufacturerName ?? this.manufacturerName,
      productName: productName ?? this.productName,
      hasPermission: hasPermission ?? this.hasPermission,
      isIppOverUsb: isIppOverUsb ?? this.isIppOverUsb,
    );
  }

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'vendorId': vendorId,
        'productId': productId,
        'deviceName': deviceName,
        if (manufacturerName != null) 'manufacturerName': manufacturerName,
        if (productName != null) 'productName': productName,
        'hasPermission': hasPermission,
        'isIppOverUsb': isIppOverUsb,
      };

  PrinterDevice toPrinterDevice() {
    final persistentId =
        'usb-${vendorId.toRadixString(16).padLeft(4, '0')}-${productId.toRadixString(16).padLeft(4, '0')}';
    return PrinterDevice(
      id: persistentId,
      name: displayName,
      connectionType: PrinterConnectionType.usb,
      host: persistentId,
      port: 0,
      resourcePath: '/usb/print',
      isOnline: true,
      isDiscovered: true,
      model: productName ?? manufacturerName ?? displayName,
      vendorId: vendorId,
      productId: productId,
      usbDeviceId: deviceId,
      isIppOverUsb: isIppOverUsb,
    );
  }

  factory UsbPrinterDevice.fromJson(Map<String, dynamic> json) {
    return UsbPrinterDevice(
      deviceId: json['deviceId'] as int,
      vendorId: json['vendorId'] as int,
      productId: json['productId'] as int,
      deviceName: json['deviceName'] as String,
      manufacturerName: json['manufacturerName'] as String?,
      productName: json['productName'] as String?,
      hasPermission: json['hasPermission'] as bool? ?? false,
      isIppOverUsb: json['isIppOverUsb'] as bool? ?? false,
    );
  }

  factory UsbPrinterDevice.fromPrinterDevice(PrinterDevice printer) {
    int devId = printer.usbDeviceId ?? 0;
    if (devId == 0 && printer.id.startsWith('usb-')) {
      final part = printer.id.replaceFirst('usb-', '');
      devId = int.tryParse(part) ?? 0;
    }
    final dev = UsbPrinterDevice(
      deviceId: devId,
      vendorId: printer.vendorId ?? 0,
      productId: printer.productId ?? 0,
      deviceName: printer.name,
      manufacturerName: printer.model,
      productName: printer.name.contains(':') ? null : printer.name,
      hasPermission: true,
      isIppOverUsb: false,
    );
    return dev;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UsbPrinterDevice &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId &&
          vendorId == other.vendorId &&
          productId == other.productId &&
          deviceName == other.deviceName &&
          manufacturerName == other.manufacturerName &&
          productName == other.productName &&
          hasPermission == other.hasPermission &&
          isIppOverUsb == other.isIppOverUsb;

  @override
  int get hashCode => Object.hash(
        deviceId,
        vendorId,
        productId,
        deviceName,
        manufacturerName,
        productName,
        hasPermission,
        isIppOverUsb,
      );
}
