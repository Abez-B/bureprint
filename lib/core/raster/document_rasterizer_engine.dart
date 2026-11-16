import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;

import '../document/universal_pdf_renderer.dart';
import '../../domain/models/print_request.dart';
import '../../domain/models/printer_device.dart';
import 'drivers/brother_pjl_rasterizer.dart';
import 'drivers/epson_escpr_rasterizer.dart';
import 'drivers/hp_xqx_rasterizer.dart';
import 'drivers/pwg_rasterizer.dart';
import 'drivers/samsung_spl_rasterizer.dart';
import 'drivers/standard_rasterizers.dart';
import 'drivers/tspl_rasterizer.dart';
import 'printer_driver_registry.dart';

/// Service that coordinates rendering document pages into raw bitmaps
/// and encoding them into the target printer's native command language.
class DocumentRasterizerEngine {
  const DocumentRasterizerEngine();

  // Standard 8x8 Bayer dithering matrix normalized to 0..255
  static final Uint8List _bayer8x8 = Uint8List.fromList([
    0,
    128,
    32,
    160,
    8,
    136,
    40,
    168,
    192,
    64,
    224,
    96,
    200,
    72,
    232,
    104,
    48,
    176,
    16,
    144,
    56,
    184,
    24,
    152,
    240,
    112,
    208,
    80,
    248,
    120,
    216,
    88,
    12,
    140,
    44,
    172,
    4,
    132,
    36,
    164,
    204,
    76,
    236,
    108,
    196,
    68,
    228,
    100,
    60,
    188,
    28,
    156,
    52,
    180,
    20,
    148,
    252,
    124,
    220,
    92,
    244,
    116,
    212,
    84,
  ]);

  /// Converts a document file ([filePath]) according to [settings] and [device]
  /// into the target printer's native byte payload.
  Future<List<int>> rasterizeDocument({
    required String filePath,
    required String mimeType,
    required PrintSettings settings,
    required PrinterDevice device,
    required String jobName,
    void Function(int currentSheet, int totalSheets)? onProgress,
  }) async {
    final driver = PrinterDriverRegistry.resolveDriver(device) ??
        const StandardPclRasterizer();
    final output = BytesBuilder();

    // 1. Session / Job Header
    output.add(driver.createJobHeader(settings, jobName));

    // 2. Determine pages to print
    final renderer = UniversalPdfRenderer.instance;
    final totalDocPages = mimeType.startsWith('image/')
        ? 1
        : await renderer.getPageCount(filePath);

    final pagesToPrint = resolvePageList(settings, totalDocPages);

    final isLaserPrinter = driver is HpLaserJetP1000Rasterizer ||
        driver is BrotherPjlRasterizer ||
        driver is SamsungSplRasterizer ||
        driver is PwgRasterizer ||
        driver is StandardPclRasterizer;

    final int targetDpi;
    if (driver is EpsonEscprRasterizer) {
      targetDpi = settings.quality == PrintQuality.high ? 720 : 360;
    } else if (driver is EscPosRasterizer || driver is TsplRasterizer) {
      targetDpi = 203; // Standard thermal DPI
    } else if (isLaserPrinter) {
      targetDpi = 600;
    } else {
      targetDpi = switch (settings.quality) {
        PrintQuality.draft => 150,
        PrintQuality.normal => 300,
        PrintQuality.high => 600,
      };
    }

    // Paper canvas geometry at target DPI
    final geom = getPaperGeometry(settings.paperSize);

    // 3. Partition pages into sheets based on PagesPerSheet (N-Up)
    final int nUp = settings.pagesPerSheet.count;
    final int totalSheets = (pagesToPrint.length + nUp - 1) ~/ nUp;

    for (int s = 0; s < totalSheets; s++) {
      onProgress?.call(s + 1, totalSheets);

      final sheetPages = pagesToPrint.sublist(
        s * nUp,
        math.min((s + 1) * nUp, pagesToPrint.length),
      );

      final bitmapData = await _renderSheetToMonochromeBitmap(
        filePath: filePath,
        mimeType: mimeType,
        sheetPages: sheetPages,
        settings: settings,
        targetDpi: targetDpi,
        geom: geom,
      );

      final pageBytes = driver.encodePage(
        pixelBytes: bitmapData.bytes,
        widthPixels: bitmapData.width,
        heightPixels: bitmapData.height,
        linesize: bitmapData.linesize,
        settings: settings,
        pageIndex: s,
        totalPages: totalSheets,
      );

      output.add(pageBytes);
    }

    // 4. Session / Job Footer
    output.add(driver.createJobFooter(jobName));

    return output.toBytes();
  }

  /// Resolves the printable area at 600 DPI for standard paper sizes.
  static ({int printableWidth, int printableHeight}) getPaperGeometry(
      String paperSize) {
    final lower = paperSize.toLowerCase();
    if (lower.contains('letter')) {
      return (printableWidth: 4924, printableHeight: 6432);
    }
    if (lower.contains('legal')) {
      return (printableWidth: 4924, printableHeight: 8208);
    }
    if (lower.contains('executive')) {
      return (printableWidth: 4158, printableHeight: 6108);
    }
    if (lower.contains('a5')) {
      return (printableWidth: 3304, printableHeight: 4768);
    }
    if (lower.contains('b5')) {
      return (printableWidth: 4107, printableHeight: 5878);
    }
    if (lower.contains('a3')) {
      return (printableWidth: 6848, printableHeight: 9792);
    }
    if (lower.contains('4x6')) {
      return (printableWidth: 2320, printableHeight: 3520);
    }
    if (lower.contains('5x7')) {
      return (printableWidth: 2920, printableHeight: 4120);
    }
    if (lower.contains('58mm') || lower.contains('pos58')) {
      return (printableWidth: 1180, printableHeight: 2400);
    }
    if (lower.contains('80mm') || lower.contains('pos80')) {
      return (printableWidth: 1728, printableHeight: 3600);
    }
    // Default ISO A4 (210 x 297 mm, 600 DPI with 3.3mm unprintable margins)
    return (printableWidth: 4784, printableHeight: 6848);
  }

  static List<int> resolvePageList(PrintSettings settings, int totalPages) {
    switch (settings.pageSelectionMode) {
      case PageSelectionMode.all:
        return List.generate(totalPages, (i) => i + 1);
      case PageSelectionMode.oddOnly:
        return [for (int i = 1; i <= totalPages; i += 2) i];
      case PageSelectionMode.evenOnly:
        return [for (int i = 2; i <= totalPages; i += 2) i];
      case PageSelectionMode.custom:
        final parsed = <int>[];
        final parts = settings.customPageRange.split(',');
        for (final p in parts) {
          final trimmed = p.trim();
          if (trimmed.contains('-')) {
            final range = trimmed.split('-');
            final start = int.tryParse(range[0].trim());
            final end = int.tryParse(range[1].trim());
            if (start != null && end != null && start <= end) {
              for (int r = start; r <= end; r++) {
                if (r >= 1 && r <= totalPages && !parsed.contains(r)) {
                  parsed.add(r);
                }
              }
            }
          } else {
            final single = int.tryParse(trimmed);
            if (single != null &&
                single >= 1 &&
                single <= totalPages &&
                !parsed.contains(single)) {
              parsed.add(single);
            }
          }
        }
        return parsed.isNotEmpty
            ? parsed
            : List.generate(totalPages, (i) => i + 1);
    }
  }

  Future<_MonochromeBitmap> _renderSheetToMonochromeBitmap({
    required String filePath,
    required String mimeType,
    required List<int> sheetPages,
    required PrintSettings settings,
    required int targetDpi,
    required ({int printableWidth, int printableHeight}) geom,
  }) async {
    // 1. Determine logical sheet dimensions:
    // When landscape is requested, the page is viewed horizontally:
    // logical width = printableHeight (long edge, e.g. 6848), logical height = printableWidth (short edge, e.g. 4784).
    final int logicalW;
    final int logicalH;
    if (settings.landscape) {
      logicalW = geom.printableHeight;
      logicalH = geom.printableWidth;
    } else {
      logicalW = geom.printableWidth;
      logicalH = geom.printableHeight;
    }

    final nUp = settings.pagesPerSheet.count;

    // Fast path for standard 1-Up prints: avoids extra full-sheet compositing allocation
    if (nUp == 1 && sheetPages.isNotEmpty) {
      final pageNum = sheetPages.first;
      final rawPageImg = await _renderSinglePageImage(
        filePath: filePath,
        mimeType: mimeType,
        pageNumber: pageNum,
        targetDpi: targetDpi,
      );

      var transformed = rawPageImg;

      // Calculate scale factor according to ScalingMode
      final double scale;
      switch (settings.scalingMode) {
        case ScalingMode.fitPrintableArea:
          scale = math.min(
            logicalW / transformed.width,
            logicalH / transformed.height,
          );
          break;
        case ScalingMode.fillPage:
          scale = math.max(
            logicalW / transformed.width,
            logicalH / transformed.height,
          );
          break;
        case ScalingMode.originalSize:
          scale = 1.0;
          break;
        case ScalingMode.fitWidth:
          scale = logicalW / transformed.width;
          break;
        case ScalingMode.fitHeight:
          scale = logicalH / transformed.height;
          break;
      }

      final drawW = math.max(1, (transformed.width * scale).round());
      final drawH = math.max(1, (transformed.height * scale).round());

      if (drawW != transformed.width || drawH != transformed.height) {
        transformed = img.copyResize(transformed, width: drawW, height: drawH);
      }

      // Always composite onto a complete white paper sheet canvas of logicalW x logicalH.
      // This guarantees the printed page always matches the exact hardware paper boundary,
      // eliminating partial heights, truncated lines, or paper size mismatch engine faults.
      final sheetCanvas = img.Image(width: logicalW, height: logicalH);
      img.fill(sheetCanvas, color: img.ColorRgba8(255, 255, 255, 255));

      final drawX = ((logicalW - drawW) ~/ 2)
          .clamp(0, math.max(0, logicalW - drawW))
          .toInt();
      final drawY = ((logicalH - drawH) ~/ 2)
          .clamp(0, math.max(0, logicalH - drawH))
          .toInt();

      img.compositeImage(sheetCanvas, transformed, dstX: drawX, dstY: drawY);

      var finalSheet = sheetCanvas;
      if (settings.landscape) {
        finalSheet = img.copyRotate(finalSheet, angle: 90);
      }

      return _binarizeToMonochrome(finalSheet);
    }

    // Multi-page N-Up compositing path (2-Up or 4-Up)
    final sheetCanvas = img.Image(width: logicalW, height: logicalH);
    img.fill(sheetCanvas, color: img.ColorRgba8(255, 255, 255, 255));

    final slots = _partitionSlots(logicalW, logicalH, settings.pagesPerSheet);

    for (int i = 0; i < sheetPages.length && i < slots.length; i++) {
      final pageNum = sheetPages[i];
      final slot = slots[i];

      var pageImg = await _renderSinglePageImage(
        filePath: filePath,
        mimeType: mimeType,
        pageNumber: pageNum,
        targetDpi: targetDpi,
      );

      // Auto-orient sub-page to maximize printable slot area
      if ((pageImg.width > pageImg.height) != (slot.w > slot.h)) {
        pageImg = img.copyRotate(pageImg, angle: 90);
      }

      final double scale;
      switch (settings.scalingMode) {
        case ScalingMode.fitPrintableArea:
          scale = math.min(slot.w / pageImg.width, slot.h / pageImg.height);
          break;
        case ScalingMode.fillPage:
          scale = math.max(slot.w / pageImg.width, slot.h / pageImg.height);
          break;
        case ScalingMode.originalSize:
          scale = 1.0;
          break;
        case ScalingMode.fitWidth:
          scale = slot.w / pageImg.width;
          break;
        case ScalingMode.fitHeight:
          scale = slot.h / pageImg.height;
          break;
      }

      final drawW = math.max(1, (pageImg.width * scale).round());
      final drawH = math.max(1, (pageImg.height * scale).round());

      if (drawW != pageImg.width || drawH != pageImg.height) {
        pageImg = img.copyResize(pageImg, width: drawW, height: drawH);
      }

      final drawX = slot.x + (slot.w - drawW) ~/ 2;
      final drawY = slot.y + (slot.h - drawH) ~/ 2;

      img.compositeImage(sheetCanvas, pageImg, dstX: drawX, dstY: drawY);
    }

    var finalSheet = sheetCanvas;
    if (settings.landscape) {
      finalSheet = img.copyRotate(finalSheet, angle: 90);
    }

    return _binarizeToMonochrome(finalSheet);
  }

  Future<img.Image> _renderSinglePageImage({
    required String filePath,
    required String mimeType,
    required int pageNumber,
    required int targetDpi,
  }) async {
    final Uint8List? pngBytes;

    if (mimeType.startsWith('image/')) {
      pngBytes = await File(filePath).readAsBytes();
    } else {
      pngBytes = await UniversalPdfRenderer.instance.renderPageImage(
        filePath: filePath,
        pageNumber: pageNumber,
        dpi: targetDpi,
      );
    }

    if (pngBytes == null) {
      throw StateError('Failed to rasterize document page $pageNumber');
    }

    final decoded = img.decodeImage(pngBytes);
    if (decoded == null) {
      throw StateError('Failed to decode rendered page image');
    }
    return decoded;
  }

  List<({int x, int y, int w, int h})> _partitionSlots(
    int sheetW,
    int sheetH,
    PagesPerSheet pagesPerSheet,
  ) {
    switch (pagesPerSheet) {
      case PagesPerSheet.one:
        return [(x: 0, y: 0, w: sheetW, h: sheetH)];
      case PagesPerSheet.two:
        if (sheetW >= sheetH) {
          // Landscape sheet: two vertical columns side by side
          final halfW = sheetW ~/ 2;
          return [
            (x: 0, y: 0, w: halfW, h: sheetH),
            (x: halfW, y: 0, w: halfW, h: sheetH),
          ];
        } else {
          // Portrait sheet: two horizontal rows stacked
          final halfH = sheetH ~/ 2;
          return [
            (x: 0, y: 0, w: sheetW, h: halfH),
            (x: 0, y: halfH, w: sheetW, h: halfH),
          ];
        }
      case PagesPerSheet.four:
        final halfW = sheetW ~/ 2;
        final halfH = sheetH ~/ 2;
        return [
          (x: 0, y: 0, w: halfW, h: halfH),
          (x: halfW, y: 0, w: halfW, h: halfH),
          (x: 0, y: halfH, w: halfW, h: halfH),
          (x: halfW, y: halfH, w: halfW, h: halfH),
        ];
    }
  }

  /// Converts an image into high-contrast 1-bit packed bi-level bitmap with Bayer halftoning.
  /// - Solid dark pixels (luminance < 160) receive 100% solid black dots.
  /// - Anti-aliasing edges and midtones (160 <= lum < 252) are dithered against Bayer 8x8 matrix.
  /// - Paper white (lum >= 252 or transparent) stays clean white.
  _MonochromeBitmap _binarizeToMonochrome(img.Image image) {
    final width = image.width;
    final height = image.height;
    final linesize = (width + 7) >> 3;
    final packed = Uint8List(linesize * height);

    for (int y = 0; y < height; y++) {
      final rowOffset = y * linesize;
      final bayerY = (y & 7) << 3;

      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        if (pixel.a < 32) continue; // Transparent: white paper

        final lum = pixel.luminance;
        if (lum < 252) {
          // Solid text & vector lines (< 160) get solid black dot.
          // Midtones/anti-aliased edges (160..251) dither with Bayer 8x8 matrix.
          final threshold = lum < 160 ? 255 : _bayer8x8[bayerY | (x & 7)];
          if (lum < threshold) {
            final byteIndex = rowOffset + (x >> 3);
            final bitIndex = 7 - (x & 7);
            packed[byteIndex] |= (1 << bitIndex);
          }
        }
      }
    }

    return _MonochromeBitmap(
      bytes: packed,
      width: width,
      height: height,
      linesize: linesize,
    );
  }
}

class _MonochromeBitmap {
  const _MonochromeBitmap({
    required this.bytes,
    required this.width,
    required this.height,
    required this.linesize,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final int linesize;
}
