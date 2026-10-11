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

  String get displayName =>
      productName ?? manufacturerName ?? 'USB Printer ($vendorId:$productId)';

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
    return PrinterDevice(
      id: 'usb-$deviceId',
      name: displayName,
      connectionType: PrinterConnectionType.usb,
      host: 'usb-$deviceId',
      port: 0,
      resourcePath: '/usb/print',
      isOnline: true,
      isDiscovered: true,
      model: productName ?? manufacturerName,
      vendorId: vendorId,
      productId: productId,
      usbDeviceId: deviceId,
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
