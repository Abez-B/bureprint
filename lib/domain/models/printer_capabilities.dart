import 'package:flutter/foundation.dart';

@immutable
class PrinterSupplyLevel {
  const PrinterSupplyLevel({
    required this.name,
    required this.colorHex,
    required this.levelPercent,
    this.type = 'toner', // toner, ink, waste, drum
  });

  final String name;
  final String colorHex;
  final int levelPercent; // 0 - 100, -1 for unknown
  final String type;

  Map<String, dynamic> toJson() => {
        'name': name,
        'colorHex': colorHex,
        'levelPercent': levelPercent,
        'type': type,
      };

  factory PrinterSupplyLevel.fromJson(Map<String, dynamic> json) {
    return PrinterSupplyLevel(
      name: json['name'] as String? ?? 'Supply',
      colorHex: json['colorHex'] as String? ?? '#000000',
      levelPercent: json['levelPercent'] as int? ?? -1,
      type: json['type'] as String? ?? 'toner',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrinterSupplyLevel &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          colorHex == other.colorHex &&
          levelPercent == other.levelPercent &&
          type == other.type;

  @override
  int get hashCode => Object.hash(name, colorHex, levelPercent, type);
}

@immutable
class PrinterCapabilities {
  const PrinterCapabilities({
    this.printerName,
    this.printerMakeAndModel,
    this.printerState = 'idle',
    this.printerStateReasons = const [],
    this.operationsSupported = const [],
    this.documentFormats = const [],
    this.paperSizes = const [],
    this.supportsColor = false,
    this.supportsDuplex = false,
    this.resolutionsDpi = const [],
    this.copiesSupportedMax = 1,
    this.markerSupplies = const [],
  });

  final String? printerName;
  final String? printerMakeAndModel;
  final String printerState;
  final List<String> printerStateReasons;
  final List<int> operationsSupported;
  final List<String> documentFormats;
  final List<String> paperSizes;
  final bool supportsColor;
  final bool supportsDuplex;
  final List<int> resolutionsDpi;
  final int copiesSupportedMax;
  final List<PrinterSupplyLevel> markerSupplies;

  /// RFC 8011 operation check: Create-Job (0x0005) & Send-Document (0x0006)
  bool get supportsTwoStepJob =>
      operationsSupported.contains(0x0005) &&
      operationsSupported.contains(0x0006);

  /// RFC 8011 operation check: Print-Job (0x0002)
  bool get supportsPrintJob => operationsSupported.contains(0x0002);

  /// RFC 8011 format check: Direct PDF support
  bool get supportsPdf => documentFormats.contains('application/pdf');

  /// RFC 8011 format check: PWG Raster support
  bool get supportsPwgRaster => documentFormats.contains('image/pwg-raster');

  PrinterCapabilities copyWith({
    String? printerName,
    String? printerMakeAndModel,
    String? printerState,
    List<String>? printerStateReasons,
    List<int>? operationsSupported,
    List<String>? documentFormats,
    List<String>? paperSizes,
    bool? supportsColor,
    bool? supportsDuplex,
    List<int>? resolutionsDpi,
    int? copiesSupportedMax,
    List<PrinterSupplyLevel>? markerSupplies,
  }) {
    return PrinterCapabilities(
      printerName: printerName ?? this.printerName,
      printerMakeAndModel: printerMakeAndModel ?? this.printerMakeAndModel,
      printerState: printerState ?? this.printerState,
      printerStateReasons: printerStateReasons ?? this.printerStateReasons,
      operationsSupported: operationsSupported ?? this.operationsSupported,
      documentFormats: documentFormats ?? this.documentFormats,
      paperSizes: paperSizes ?? this.paperSizes,
      supportsColor: supportsColor ?? this.supportsColor,
      supportsDuplex: supportsDuplex ?? this.supportsDuplex,
      resolutionsDpi: resolutionsDpi ?? this.resolutionsDpi,
      copiesSupportedMax: copiesSupportedMax ?? this.copiesSupportedMax,
      markerSupplies: markerSupplies ?? this.markerSupplies,
    );
  }

  Map<String, dynamic> toJson() => {
        if (printerName != null) 'printerName': printerName,
        if (printerMakeAndModel != null)
          'printerMakeAndModel': printerMakeAndModel,
        'printerState': printerState,
        'printerStateReasons': printerStateReasons,
        'operationsSupported': operationsSupported,
        'documentFormats': documentFormats,
        'paperSizes': paperSizes,
        'supportsColor': supportsColor,
        'supportsDuplex': supportsDuplex,
        'resolutionsDpi': resolutionsDpi,
        'copiesSupportedMax': copiesSupportedMax,
        'markerSupplies': markerSupplies.map((s) => s.toJson()).toList(),
      };

  factory PrinterCapabilities.fromJson(Map<String, dynamic> json) {
    return PrinterCapabilities(
      printerName: json['printerName'] as String?,
      printerMakeAndModel: json['printerMakeAndModel'] as String?,
      printerState: json['printerState'] as String? ?? 'idle',
      printerStateReasons:
          (json['printerStateReasons'] as List<dynamic>?)?.cast<String>() ??
              const [],
      operationsSupported:
          (json['operationsSupported'] as List<dynamic>?)?.cast<int>() ??
              const [],
      documentFormats:
          (json['documentFormats'] as List<dynamic>?)?.cast<String>() ??
              const [],
      paperSizes:
          (json['paperSizes'] as List<dynamic>?)?.cast<String>() ?? const [],
      supportsColor: json['supportsColor'] as bool? ?? false,
      supportsDuplex: json['supportsDuplex'] as bool? ?? false,
      resolutionsDpi:
          (json['resolutionsDpi'] as List<dynamic>?)?.cast<int>() ?? const [],
      copiesSupportedMax: json['copiesSupportedMax'] as int? ?? 1,
      markerSupplies: (json['markerSupplies'] as List<dynamic>?)
              ?.map(
                  (s) => PrinterSupplyLevel.fromJson(s as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrinterCapabilities &&
          runtimeType == other.runtimeType &&
          printerName == other.printerName &&
          printerMakeAndModel == other.printerMakeAndModel &&
          printerState == other.printerState &&
          listEquals(printerStateReasons, other.printerStateReasons) &&
          listEquals(operationsSupported, other.operationsSupported) &&
          listEquals(documentFormats, other.documentFormats) &&
          listEquals(paperSizes, other.paperSizes) &&
          supportsColor == other.supportsColor &&
          supportsDuplex == other.supportsDuplex &&
          listEquals(resolutionsDpi, other.resolutionsDpi) &&
          copiesSupportedMax == other.copiesSupportedMax &&
          listEquals(markerSupplies, other.markerSupplies);

  @override
  int get hashCode => Object.hash(
        printerName,
        printerMakeAndModel,
        printerState,
        Object.hashAll(printerStateReasons),
        Object.hashAll(operationsSupported),
        Object.hashAll(documentFormats),
        Object.hashAll(paperSizes),
        supportsColor,
        supportsDuplex,
        Object.hashAll(resolutionsDpi),
        copiesSupportedMax,
        Object.hashAll(markerSupplies),
      );
}
