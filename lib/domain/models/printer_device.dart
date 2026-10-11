import 'package:flutter/foundation.dart';

enum PrinterConnectionType { network, usb, operatingSystem }

enum TransportSecurityPolicy {
  ippsStrict,
  ippsAllowSelfSigned,
  plainIppExplicit,
}

@immutable
class PrinterDevice {
  const PrinterDevice({
    required this.id,
    required this.name,
    required this.connectionType,
    this.host,
    this.port = 631,
    this.resourcePath = '/ipp/print',
    this.isOnline = false,
    this.model,
    this.securityPolicy = TransportSecurityPolicy.ippsStrict,
    this.isDiscovered = true,
    this.capabilitiesQueried = false,
    this.vendorId,
    this.productId,
    this.usbDeviceId,
  });

  final String id;
  final String name;
  final PrinterConnectionType connectionType;
  final String? host;
  final int port;
  final String resourcePath;
  final bool isOnline;
  final String? model;
  final TransportSecurityPolicy securityPolicy;
  final bool isDiscovered;
  final bool capabilitiesQueried;
  final int? vendorId;
  final int? productId;
  final int? usbDeviceId;

  String get endpointUri {
    final scheme = securityPolicy == TransportSecurityPolicy.plainIppExplicit
        ? 'ipp'
        : 'ipps';
    return '$scheme://${host ?? "localhost"}:$port$resourcePath';
  }

  PrinterDevice copyWith({
    String? id,
    String? name,
    PrinterConnectionType? connectionType,
    String? host,
    int? port,
    String? resourcePath,
    bool? isOnline,
    String? model,
    TransportSecurityPolicy? securityPolicy,
    bool? isDiscovered,
    bool? capabilitiesQueried,
    int? vendorId,
    int? productId,
    int? usbDeviceId,
  }) {
    return PrinterDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      connectionType: connectionType ?? this.connectionType,
      host: host ?? this.host,
      port: port ?? this.port,
      resourcePath: resourcePath ?? this.resourcePath,
      isOnline: isOnline ?? this.isOnline,
      model: model ?? this.model,
      securityPolicy: securityPolicy ?? this.securityPolicy,
      isDiscovered: isDiscovered ?? this.isDiscovered,
      capabilitiesQueried: capabilitiesQueried ?? this.capabilitiesQueried,
      vendorId: vendorId ?? this.vendorId,
      productId: productId ?? this.productId,
      usbDeviceId: usbDeviceId ?? this.usbDeviceId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'connectionType': connectionType.name,
        if (host != null) 'host': host,
        'port': port,
        'resourcePath': resourcePath,
        'isOnline': isOnline,
        if (model != null) 'model': model,
        'securityPolicy': securityPolicy.name,
        'isDiscovered': isDiscovered,
        'capabilitiesQueried': capabilitiesQueried,
        if (vendorId != null) 'vendorId': vendorId,
        if (productId != null) 'productId': productId,
        if (usbDeviceId != null) 'usbDeviceId': usbDeviceId,
      };

  factory PrinterDevice.fromJson(Map<String, dynamic> json) {
    return PrinterDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      connectionType:
          PrinterConnectionType.values.byName(json['connectionType'] as String),
      host: json['host'] as String?,
      port: json['port'] as int? ?? 631,
      resourcePath: json['resourcePath'] as String? ?? '/ipp/print',
      isOnline: json['isOnline'] as bool? ?? false,
      model: json['model'] as String?,
      securityPolicy: json['securityPolicy'] != null
          ? TransportSecurityPolicy.values
              .byName(json['securityPolicy'] as String)
          : TransportSecurityPolicy.ippsStrict,
      isDiscovered: json['isDiscovered'] as bool? ?? false,
      capabilitiesQueried: json['capabilitiesQueried'] as bool? ?? false,
      vendorId: json['vendorId'] as int?,
      productId: json['productId'] as int?,
      usbDeviceId: json['usbDeviceId'] as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrinterDevice &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          connectionType == other.connectionType &&
          host == other.host &&
          port == other.port &&
          resourcePath == other.resourcePath &&
          isOnline == other.isOnline &&
          model == other.model &&
          securityPolicy == other.securityPolicy &&
          isDiscovered == other.isDiscovered &&
          capabilitiesQueried == other.capabilitiesQueried;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        connectionType,
        host,
        port,
        resourcePath,
        isOnline,
        model,
        securityPolicy,
        isDiscovered,
        capabilitiesQueried,
      );
}
