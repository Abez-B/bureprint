import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

import '../document/universal_pdf_renderer.dart';
import '../../domain/models/print_request.dart';
import '../../domain/models/printer_device.dart';
import 'drivers/standard_rasterizers.dart';
import 'printer_driver_registry.dart';

/// Service that coordinates rendering document pages into raw bitmaps
/// and encoding them into the target printer's native command language.
class DocumentRasterizerEngine {
  const DocumentRasterizerEngine();

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

    final pagesToPrint = _resolvePageList(settings, totalDocPages);

    // 3. Render and encode each sheet
    for (int i = 0; i < pagesToPrint.length; i++) {
      final pageNum = pagesToPrint[i];
      onProgress?.call(i + 1, pagesToPrint.length);

      final bitmapData = await _renderPageToMonochromeBitmap(
        filePath: filePath,
        mimeType: mimeType,
        pageNumber: pageNum,
        settings: settings,
      );

      final pageBytes = driver.encodePage(
        pixelBytes: bitmapData.bytes,
        widthPixels: bitmapData.width,
        heightPixels: bitmapData.height,
        linesize: bitmapData.linesize,
        settings: settings,
        pageIndex: i,
        totalPages: pagesToPrint.length,
      );

      output.add(pageBytes);
    }

    // 4. Session / Job Footer
    output.add(driver.createJobFooter(jobName));

    return output.toBytes();
  }

  List<int> _resolvePageList(PrintSettings settings, int totalPages) {
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

  Future<_MonochromeBitmap> _renderPageToMonochromeBitmap({
    required String filePath,
    required String mimeType,
    required int pageNumber,
    required PrintSettings settings,
  }) async {
    Uint8List? pngBytes;

    if (mimeType.startsWith('image/')) {
      pngBytes = await File(filePath).readAsBytes();
    } else {
      pngBytes = await UniversalPdfRenderer.instance.renderPageImage(
        filePath: filePath,
        pageNumber: pageNumber,
        dpi: 600, // Matches 600 DPI Brother PJL resolution
      );
    }

    if (pngBytes == null) {
      throw StateError('Failed to rasterize document page $pageNumber');
    }

    // Decode image to extract pixels
    final rawDecoded = img.decodeImage(pngBytes);
    if (rawDecoded == null) {
      throw StateError('Failed to decode rendered page image');
    }

    // Composite transparent backgrounds over solid white
    final decoded = img.Image(
      width: rawDecoded.width,
      height: rawDecoded.height,
    )..clear(img.ColorRgb8(255, 255, 255));
    img.compositeImage(decoded, rawDecoded);

    // Rotate if landscape requested
    final oriented = settings.landscape && decoded.width < decoded.height
        ? img.copyRotate(decoded, angle: 90)
        : decoded;

    final width = oriented.width;
    final height = oriented.height;
    final linesize = (width + 7) ~/ 8; // 1-bit per pixel (8 pixels per byte)
    final packed = Uint8List(linesize * height);

    // Convert pixels to 1-bit monochrome (Black dot = 1, White paper = 0)
    for (int y = 0; y < height; y++) {
      final rowOffset = y * linesize;
      for (int x = 0; x < width; x++) {
        final pixel = oriented.getPixel(x, y);
        final lum = pixel.luminance;
        // Standard threshold: dark pixels (toner) get bit 1, paper white gets bit 0
        if (lum < 128) {
          final byteIndex = rowOffset + (x >> 3);
          final bitIndex = 7 - (x & 7);
          packed[byteIndex] |= (1 << bitIndex);
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
