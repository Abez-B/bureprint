import 'package:flutter/foundation.dart';

enum DuplexMode {
  oneSided,
  longEdge,
  shortEdge;

  String get displayName => switch (this) {
        DuplexMode.oneSided => 'One-Sided',
        DuplexMode.longEdge => 'Two-Sided (Long Edge)',
        DuplexMode.shortEdge => 'Two-Sided (Short Edge)',
      };
}

enum ScalingMode {
  fitPrintableArea,
  fillPage,
  originalSize,
  fitWidth,
  fitHeight;

  String get displayName => switch (this) {
        ScalingMode.fitPrintableArea => 'Fit to Printable Area (Best Fit)',
        ScalingMode.fillPage => 'Fill Entire Page (Crop Edge Margins)',
        ScalingMode.originalSize => '100% Original Size (No Scaling)',
        ScalingMode.fitWidth => 'Fit to Page Width',
        ScalingMode.fitHeight => 'Fit to Page Height',
      };
}

enum PrintQuality {
  draft,
  normal,
  high;

  String get displayName => switch (this) {
        PrintQuality.draft => 'Draft (Fast / Low Ink)',
        PrintQuality.normal => 'Normal (Standard)',
        PrintQuality.high => 'High Quality (Photo / Best)',
      };
}

enum PageSelectionMode {
  all,
  oddOnly,
  evenOnly,
  custom;

  String get displayName => switch (this) {
        PageSelectionMode.all => 'All Pages',
        PageSelectionMode.oddOnly => 'Odd Pages Only',
        PageSelectionMode.evenOnly => 'Even Pages Only',
        PageSelectionMode.custom => 'Custom Range',
      };
}

enum PagesPerSheet {
  one,
  two,
  four;

  int get count => switch (this) {
        PagesPerSheet.one => 1,
        PagesPerSheet.two => 2,
        PagesPerSheet.four => 4,
      };

  String get displayName => switch (this) {
        PagesPerSheet.one => '1 page per sheet',
        PagesPerSheet.two => '2 pages per sheet (2-Up)',
        PagesPerSheet.four => '4 pages per sheet (4-Up)',
      };
}

/// Physical dimensions and aspect ratio for standard paper sizes.
@immutable
class PaperDimensions {
  const PaperDimensions({
    required this.widthMm,
    required this.heightMm,
  });

  final double widthMm;
  final double heightMm;

  /// Aspect ratio (width / height) in portrait orientation.
  double get portraitAspectRatio => widthMm / heightMm;

  /// Aspect ratio in landscape orientation.
  double get landscapeAspectRatio => heightMm / widthMm;

  /// Resolves standard PaperDimensions for an IPP paper size string.
  static PaperDimensions fromPaperSize(String paperSize) {
    final lower = paperSize.toLowerCase();
    if (lower.contains('a3')) {
      return const PaperDimensions(widthMm: 297, heightMm: 420);
    }
    if (lower.contains('a5')) {
      return const PaperDimensions(widthMm: 148, heightMm: 210);
    }
    if (lower.contains('letter')) {
      return const PaperDimensions(widthMm: 215.9, heightMm: 279.4);
    }
    if (lower.contains('legal')) {
      return const PaperDimensions(widthMm: 215.9, heightMm: 355.6);
    }
    if (lower.contains('tabloid')) {
      return const PaperDimensions(widthMm: 279.4, heightMm: 431.8);
    }
    if (lower.contains('4x6')) {
      return const PaperDimensions(widthMm: 101.6, heightMm: 152.4);
    }
    if (lower.contains('5x7')) {
      return const PaperDimensions(widthMm: 127.0, heightMm: 177.8);
    }
    // Default: ISO A4 (210 x 297 mm)
    return const PaperDimensions(widthMm: 210, heightMm: 297);
  }
}

@immutable
class PrintSettings {
  const PrintSettings({
    this.copies = 1,
    this.paperSize = 'iso_a4_210x297mm',
    this.landscape = false,
    this.color = true,
    this.duplex = false,
    this.duplexMode = DuplexMode.oneSided,
    this.quality = PrintQuality.normal,
    this.pageSelectionMode = PageSelectionMode.all,
    this.customPageRange = '',
    this.firstPage = 1,
    this.lastPage,
    this.scalingFitToPage = true,
    this.scalingMode = ScalingMode.fitPrintableArea,
    this.pagesPerSheet = PagesPerSheet.one,
  });

  final int copies;
  final String paperSize;
  final bool landscape;
  final bool color;
  final bool duplex;
  final DuplexMode duplexMode;
  final PrintQuality quality;
  final PageSelectionMode pageSelectionMode;
  final String customPageRange;
  final int firstPage;
  final int? lastPage;
  final bool scalingFitToPage;
  final ScalingMode scalingMode;
  final PagesPerSheet pagesPerSheet;

  PrintSettings copyWith({
    int? copies,
    String? paperSize,
    bool? landscape,
    bool? color,
    bool? duplex,
    DuplexMode? duplexMode,
    PrintQuality? quality,
    PageSelectionMode? pageSelectionMode,
    String? customPageRange,
    int? firstPage,
    int? lastPage,
    bool? scalingFitToPage,
    ScalingMode? scalingMode,
    PagesPerSheet? pagesPerSheet,
  }) {
    return PrintSettings(
      copies: copies ?? this.copies,
      paperSize: paperSize ?? this.paperSize,
      landscape: landscape ?? this.landscape,
      color: color ?? this.color,
      duplex: duplex ?? this.duplex,
      duplexMode: duplexMode ?? this.duplexMode,
      quality: quality ?? this.quality,
      pageSelectionMode: pageSelectionMode ?? this.pageSelectionMode,
      customPageRange: customPageRange ?? this.customPageRange,
      firstPage: firstPage ?? this.firstPage,
      lastPage: lastPage ?? this.lastPage,
      scalingFitToPage: scalingFitToPage ?? this.scalingFitToPage,
      scalingMode: scalingMode ?? this.scalingMode,
      pagesPerSheet: pagesPerSheet ?? this.pagesPerSheet,
    );
  }

  Map<String, dynamic> toJson() => {
        'copies': copies,
        'paperSize': paperSize,
        'landscape': landscape,
        'color': color,
        'duplex': duplex,
        'duplexMode': duplexMode.name,
        'quality': quality.name,
        'pageSelectionMode': pageSelectionMode.name,
        'customPageRange': customPageRange,
        'firstPage': firstPage,
        if (lastPage != null) 'lastPage': lastPage,
        'scalingFitToPage': scalingFitToPage,
        'scalingMode': scalingMode.name,
        'pagesPerSheet': pagesPerSheet.name,
      };

  factory PrintSettings.fromJson(Map<String, dynamic> json) {
    return PrintSettings(
      copies: json['copies'] as int? ?? 1,
      paperSize: json['paperSize'] as String? ?? 'iso_a4_210x297mm',
      landscape: json['landscape'] as bool? ?? false,
      color: json['color'] as bool? ?? true,
      duplex: json['duplex'] as bool? ?? false,
      duplexMode: json['duplexMode'] != null
          ? DuplexMode.values.byName(json['duplexMode'] as String)
          : DuplexMode.oneSided,
      quality: json['quality'] != null
          ? PrintQuality.values.byName(json['quality'] as String)
          : PrintQuality.normal,
      pageSelectionMode: json['pageSelectionMode'] != null
          ? PageSelectionMode.values.byName(json['pageSelectionMode'] as String)
          : PageSelectionMode.all,
      customPageRange: json['customPageRange'] as String? ?? '',
      firstPage: json['firstPage'] as int? ?? 1,
      lastPage: json['lastPage'] as int?,
      scalingFitToPage: json['scalingFitToPage'] as bool? ?? true,
      scalingMode: json['scalingMode'] != null
          ? ScalingMode.values.byName(json['scalingMode'] as String)
          : ScalingMode.fitPrintableArea,
      pagesPerSheet: json['pagesPerSheet'] != null
          ? PagesPerSheet.values.byName(json['pagesPerSheet'] as String)
          : PagesPerSheet.one,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrintSettings &&
          runtimeType == other.runtimeType &&
          copies == other.copies &&
          paperSize == other.paperSize &&
          landscape == other.landscape &&
          color == other.color &&
          duplex == other.duplex &&
          duplexMode == other.duplexMode &&
          quality == other.quality &&
          pageSelectionMode == other.pageSelectionMode &&
          customPageRange == other.customPageRange &&
          firstPage == other.firstPage &&
          lastPage == other.lastPage &&
          scalingFitToPage == other.scalingFitToPage &&
          scalingMode == other.scalingMode &&
          pagesPerSheet == other.pagesPerSheet;

  @override
  int get hashCode => Object.hash(
        copies,
        paperSize,
        landscape,
        color,
        duplex,
        duplexMode,
        quality,
        pageSelectionMode,
        customPageRange,
        firstPage,
        lastPage,
        scalingFitToPage,
        scalingMode,
        pagesPerSheet,
      );
}

@immutable
class PrintRequest {
  const PrintRequest({
    required this.jobName,
    required this.filePath,
    required this.mimeType,
    required this.printerId,
    this.settings = const PrintSettings(),
  });

  final String jobName;
  final String filePath;
  final String mimeType;
  final String printerId;
  final PrintSettings settings;

  PrintRequest copyWith({
    String? jobName,
    String? filePath,
    String? mimeType,
    String? printerId,
    PrintSettings? settings,
  }) {
    return PrintRequest(
      jobName: jobName ?? this.jobName,
      filePath: filePath ?? this.filePath,
      mimeType: mimeType ?? this.mimeType,
      printerId: printerId ?? this.printerId,
      settings: settings ?? this.settings,
    );
  }

  Map<String, dynamic> toJson() => {
        'jobName': jobName,
        'filePath': filePath,
        'mimeType': mimeType,
        'printerId': printerId,
        'settings': settings.toJson(),
      };

  factory PrintRequest.fromJson(Map<String, dynamic> json) {
    return PrintRequest(
      jobName: json['jobName'] as String,
      filePath: json['filePath'] as String,
      mimeType: json['mimeType'] as String,
      printerId: json['printerId'] as String,
      settings:
          PrintSettings.fromJson(json['settings'] as Map<String, dynamic>),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrintRequest &&
          runtimeType == other.runtimeType &&
          jobName == other.jobName &&
          filePath == other.filePath &&
          mimeType == other.mimeType &&
          printerId == other.printerId &&
          settings == other.settings;

  @override
  int get hashCode =>
      Object.hash(jobName, filePath, mimeType, printerId, settings);
}
