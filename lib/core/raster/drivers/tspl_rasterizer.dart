import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../../domain/models/print_request.dart';
import '../../../domain/models/printer_device.dart';
import '../printer_rasterizer.dart';

/// Driver for thermal shipping label and barcode printers using TSPL / TSPL2 (TSC, Munbyn,
/// Xprinter, Zebra-compatible label printers).
class TsplRasterizer implements PrinterRasterizer {
  const TsplRasterizer();

  @override
  String get id => 'driver.thermal.tspl';

  @override
  String get displayName => 'TSPL / Thermal Label (Munbyn / TSC / Xprinter)';

  @override
  bool canHandle(PrinterDevice device) {
    final name = '${device.name} ${device.model ?? ''}'.toLowerCase();
    return name.contains('tspl') ||
        name.contains('tsc') ||
        name.contains('munbyn') ||
        name.contains('label') ||
        name.contains('4bar') ||
        name.contains('barcode') ||
        name.contains('xp-4') ||
        name.contains('shipping');
  }

  @override
  List<int> createJobHeader(PrintSettings settings, String jobName) {
    final buffer = StringBuffer();

    // Map paper size to label dimensions in inches (default 4x6 shipping label)
    final (widthIn, heightIn) = _mapLabelDimensions(settings.paperSize);

    buffer.write('SIZE $widthIn,$heightIn\n');
    buffer.write('GAP 0.12,0\n');
    buffer.write('DIRECTION 1\n');
    buffer.write('CLS\n');

    return ascii.encode(buffer.toString());
  }

  @override
  List<int> encodePage({
    required Uint8List pixelBytes,
    required int widthPixels,
    required int heightPixels,
    required int linesize,
    required PrintSettings settings,
    required int pageIndex,
    required int totalPages,
  }) {
    final buffer = BytesBuilder();

    // TSPL BITMAP command:
    // BITMAP X, Y, width_in_bytes, height_in_dots, mode, bitmap_data...
    final cmd = 'BITMAP 0,0,$linesize,$heightPixels,0,';
    buffer.add(ascii.encode(cmd));
    buffer.add(pixelBytes);
    buffer.add(ascii.encode('\n'));

    // Print command: PRINT [copies], [sets]
    final copies = math.max(1, settings.copies);
    buffer.add(ascii.encode('PRINT $copies,1\n'));

    return buffer.toBytes();
  }

  @override
  List<int> createJobFooter(String jobName) {
    return ascii.encode('\n');
  }

  (double, double) _mapLabelDimensions(String paperSize) {
    final lower = paperSize.toLowerCase();
    if (lower.contains('4x6') || lower.contains('shipping')) {
      return (4.0, 6.0);
    }
    if (lower.contains('5x7')) {
      return (5.0, 7.0);
    }
    if (lower.contains('58mm')) {
      return (2.28, 4.0);
    }
    if (lower.contains('80mm')) {
      return (3.15, 6.0);
    }
    // Default 4x6 inches
    return (4.0, 6.0);
  }
}
