import 'dart:math' as math;
import 'dart:typed_data';

import '../../../domain/models/print_request.dart';
import '../../../domain/models/printer_device.dart';
import '../printer_rasterizer.dart';

/// Driver for Epson inkjet and laser printers using Epson ESC/P-R (Raster) command language.
/// Compatible with Epson EcoTank (L-series, ET-series), WorkForce (WF-series), Stylus, Expression, and Artisan.
class EpsonEscprRasterizer implements PrinterRasterizer {
  const EpsonEscprRasterizer();

  @override
  String get id => 'driver.epson.escpr';

  @override
  String get displayName => 'Epson ESC/P-R (EcoTank / WorkForce)';

  @override
  bool canHandle(PrinterDevice device) {
    // Epson USB Vendor ID is 0x04B8 (1208 in decimal)
    if (device.vendorId == 0x04B8 || device.vendorId == 1208) {
      return true;
    }
    final name = '${device.name} ${device.model ?? ''}'.toLowerCase();
    return name.contains('epson') ||
        name.contains('ecotank') ||
        name.contains('workforce') ||
        name.contains('stylus') ||
        name.contains('artisan') ||
        name.contains('xp-') ||
        name.contains('et-') ||
        name.contains('wf-') ||
        name.contains('l3110') ||
        name.contains('l3150') ||
        name.contains('l3210') ||
        name.contains('l3250');
  }

  @override
  List<int> createJobHeader(PrintSettings settings, String jobName) {
    final buffer = BytesBuilder();

    // 1. Initial Reset (ESC @)
    buffer.add([0x1B, 0x40]);

    // 2. Enter Graphics Mode: ESC ( G [len_low] [len_high] [mode]
    buffer.add([0x1B, 0x28, 0x47, 0x01, 0x00, 0x01]);

    // 3. Set Unit: ESC ( U [len_l] [len_h] [unit]
    // 0x0A (10) specifies 360 DPI base grid (3600 / 10 = 360)
    final unit = settings.quality == PrintQuality.high ? 0x05 : 0x0A;
    buffer.add([0x1B, 0x28, 0x55, 0x01, 0x00, unit]);

    // 4. Page length and orientation setup
    final geom = _resolvePageGeometry(settings.paperSize);
    final pageLengthDots = geom.lengthDots;
    final pLLow = pageLengthDots & 0xFF;
    final pLHigh = (pageLengthDots >> 8) & 0xFF;

    // ESC ( C [len_l] [len_h] [length_l] [length_h]
    buffer.add([0x1B, 0x28, 0x43, 0x02, 0x00, pLLow, pLHigh]);

    // Page margins: ESC ( c [len_l] [len_h] [top_l] [top_h] [bottom_l] [bottom_h]
    buffer.add([0x1B, 0x28, 0x63, 0x04, 0x00, 0x00, 0x00, pLLow, pLHigh]);

    return buffer.toBytes();
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

    // Raster transfer unit (360 DPI or 720 DPI)
    final vUnit = settings.quality == PrintQuality.high ? 0x05 : 0x0A;
    final hUnit = vUnit;

    for (int y = 0; y < heightPixels; y++) {
      final offset = y * linesize;
      if (offset >= pixelBytes.length) break;

      final copyLen = math.min(linesize, pixelBytes.length - offset);
      final line = Uint8List.sublistView(pixelBytes, offset, offset + copyLen);

      // Check if line is completely blank (white paper)
      bool isBlank = true;
      for (int i = 0; i < line.length; i++) {
        if (line[i] != 0) {
          isBlank = false;
          break;
        }
      }

      if (isBlank) {
        // Line feed to advance raster scanline without byte transfer
        buffer.add([0x0A]);
        continue;
      }

      // Encode raster scanline using ESC . (ESC/P-R 8-bit / 1-bit raster graphics)
      // Format: ESC . [mode] [v_unit] [h_unit] [m] [nL] [nH] [data...]
      final nL = line.length & 0xFF;
      final nH = (line.length >> 8) & 0xFF;

      buffer.add([0x1B, 0x2E, 0x00, vUnit, hUnit, 0x01, nL, nH]);
      buffer.add(line);
      // Advance to next row
      buffer.add([0x0D, 0x0A]);
    }

    // Form Feed: Eject sheet
    buffer.add([0x0C]);

    return buffer.toBytes();
  }

  @override
  List<int> createJobFooter(String jobName) {
    // Reset printer to clear graphics state
    return [0x1B, 0x40];
  }

  ({int lengthDots, int widthDots}) _resolvePageGeometry(String paperSize) {
    final lower = paperSize.toLowerCase();
    if (lower.contains('letter')) {
      return (lengthDots: 3960, widthDots: 3060);
    }
    if (lower.contains('legal')) {
      return (lengthDots: 5040, widthDots: 3060);
    }
    if (lower.contains('a5')) {
      return (lengthDots: 2976, widthDots: 2097);
    }
    if (lower.contains('4x6')) {
      return (lengthDots: 2160, widthDots: 1440);
    }
    // Default ISO A4 at 360 DPI: 297mm x 360 / 25.4 = ~4209 dots, 210mm = ~2976 dots
    return (lengthDots: 4209, widthDots: 2976);
  }
}
