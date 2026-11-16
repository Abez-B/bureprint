import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../../domain/models/print_request.dart';
import '../../../domain/models/printer_device.dart';
import '../printer_rasterizer.dart';

/// Driver for ESC/POS receipt printers (e.g. 58mm / 80mm POS thermal printers).
class EscPosRasterizer implements PrinterRasterizer {
  const EscPosRasterizer();

  @override
  String get id => 'driver.escpos';

  @override
  String get displayName => 'ESC/POS Thermal Receipt';

  @override
  bool canHandle(PrinterDevice device) {
    final name = '${device.name} ${device.model ?? ''}'.toLowerCase();
    return name.contains('pos') ||
        name.contains('receipt') ||
        name.contains('thermal') ||
        name.contains('58mm') ||
        name.contains('80mm');
  }

  @override
  List<int> createJobHeader(PrintSettings settings, String jobName) {
    // ESC @: Initialize printer
    return [0x1B, 0x40];
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

    // GS v 0: Print raster bit image in 256-dot bands to avoid thermal printer FIFO buffer overflow
    // Format: 0x1D, 0x76, 0x30, mode (0), xL, xH, yL, yH, data...
    final xL = linesize % 256;
    final xH = linesize ~/ 256;
    const bandHeight = 256;

    for (int y = 0; y < heightPixels; y += bandHeight) {
      final h = math.min(bandHeight, heightPixels - y);
      final offset = y * linesize;
      final byteCount = h * linesize;
      final copyLen = math.min(byteCount, pixelBytes.length - offset);

      if (copyLen <= 0) break;

      final bandBytes = Uint8List.sublistView(
        pixelBytes,
        offset,
        offset + copyLen,
      );

      final yL = h % 256;
      final yH = h ~/ 256;

      buffer.add([0x1D, 0x76, 0x30, 0x00, xL, xH, yL, yH]);
      buffer.add(bandBytes);
    }

    // Feed lines & Cut paper
    buffer.add([0x1B, 0x64, 0x04]); // feed 4 lines
    buffer.add([0x1D, 0x56, 0x42, 0x00]); // GS V B 0 (cut)

    return buffer.toBytes();
  }

  @override
  List<int> createJobFooter(String jobName) {
    return [0x1B, 0x40]; // Reset
  }
}

/// Universal standard PCL3 / PCL5 / PCL6 GUI rasterizer for HP, Canon, Xerox, etc.
class StandardPclRasterizer implements PrinterRasterizer {
  const StandardPclRasterizer();

  @override
  String get id => 'driver.pcl';

  @override
  String get displayName => 'Standard PCL / HP PCL3/5';

  @override
  bool canHandle(PrinterDevice device) {
    final name = '${device.name} ${device.model ?? ''}'.toLowerCase();

    // Explicitly reject proprietary host-based printers that do not speak PCL:
    // 1. HP LaserJet P1000 / P1500 / 1018 / 1020 series (require proprietary ZjStream / Foo2xqx / firmware dl)
    if (name.contains('p1005') ||
        name.contains('p1006') ||
        name.contains('p1007') ||
        name.contains('p1008') ||
        name.contains('p1505') ||
        name.contains('1018') ||
        name.contains('1020')) {
      return false;
    }
    // 2. Canon CAPT / CARPS host-based laser printers (e.g. LBP2900, LBP3000, CAPT USB)
    if (name.contains('capt') || name.contains('carps')) {
      return false;
    }

    return name.contains('hp') ||
        name.contains('deskjet') ||
        name.contains('laserjet') ||
        name.contains('canon') ||
        name.contains('pcl');
  }

  @override
  List<int> createJobHeader(PrintSettings settings, String jobName) {
    final pjl = StringBuffer();
    pjl.write('\x1B%-12345X@PJL\n');
    pjl.write('@PJL JOB NAME="$jobName"\n');
    pjl.write('@PJL ENTER LANGUAGE = PCL\n');
    pjl.write('\x1BE'); // Reset
    pjl.write('\x1B&l${math.max(1, settings.copies)}X'); // Copies
    if (settings.duplex) {
      final duplexCode = settings.duplexMode == DuplexMode.shortEdge ? 1 : 2;
      pjl.write('\x1B&l${duplexCode}S');
    }
    pjl.write(
        '\x1B&l${settings.landscape ? 1 : 0}O'); // 0=Portrait, 1=Landscape
    pjl.write('\x1B&l${_mapPaperCode(settings.paperSize)}A'); // Paper Size
    return utf8.encode(pjl.toString());
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
    // Synchronize raster resolution to match the rendered canvas DPI
    final dpi = (widthPixels > 3500 || heightPixels > 5000)
        ? 600
        : ((widthPixels > 2000) ? 300 : 150);
    buffer.add(ascii.encode('\x1B*t${dpi}R'));
    // Select raster compression mode 2 (TIFF PackBits / Run-length): ESC * b 2 M
    buffer.add(ascii.encode('\x1B*b2M'));
    // Start raster graphics: ESC * r 1 A
    buffer.add(ascii.encode('\x1B*r1A'));

    for (int y = 0; y < heightPixels; y++) {
      final offset = y * linesize;
      if (offset >= pixelBytes.length) break;
      final line = Uint8List.sublistView(
        pixelBytes,
        offset,
        (offset + linesize).clamp(0, pixelBytes.length),
      );

      // Encode line with PCL Mode 2 (PackBits / Run-Length Compression).
      // PackBits naturally compresses blank (all 0) lines into minimal bytes
      // without triggering PCL syntax errors from non-standard 0-byte line transfers.
      final compressed = _encodePackBits(line);
      buffer.add(ascii.encode('\x1B*b${compressed.length}W'));
      buffer.add(compressed);
    }

    // End raster graphics: ESC * r B and Form Feed
    buffer.add(ascii.encode('\x1B*rB\x0C'));
    return buffer.toBytes();
  }

  static int _mapPaperCode(String paperSize) {
    final lower = paperSize.toLowerCase();
    if (lower.contains('letter')) return 2;
    if (lower.contains('legal')) return 3;
    if (lower.contains('executive')) return 1;
    if (lower.contains('a5')) return 25;
    if (lower.contains('b5')) return 45;
    if (lower.contains('a3')) return 27;
    if (lower.contains('4x6')) return 71;
    if (lower.contains('5x7')) return 72;
    return 26; // Default ISO A4
  }

  /// PCL Mode 2 (TIFF PackBits) byte run-length encoder.
  static Uint8List _encodePackBits(Uint8List src) {
    final out = BytesBuilder();
    int i = 0;
    while (i < src.length) {
      // Check for run of identical bytes
      int runLen = 1;
      while (i + runLen < src.length &&
          src[i + runLen] == src[i] &&
          runLen < 128) {
        runLen++;
      }

      if (runLen > 1) {
        // Repeated bytes: -(runLen - 1) followed by the byte
        out.addByte((1 - runLen) & 0xFF);
        out.addByte(src[i]);
        i += runLen;
      } else {
        // Literal sequence
        int litLen = 1;
        while (i + litLen < src.length && litLen < 128) {
          if (i + litLen + 1 < src.length &&
              src[i + litLen] == src[i + litLen + 1] &&
              (i + litLen + 2 >= src.length ||
                  src[i + litLen] == src[i + litLen + 2])) {
            break;
          }
          litLen++;
        }
        out.addByte(litLen - 1);
        out.add(Uint8List.sublistView(src, i, i + litLen));
        i += litLen;
      }
    }
    return out.toBytes();
  }

  @override
  List<int> createJobFooter(String jobName) {
    return utf8.encode('\x1B%-12345X@PJL EOJ\n\x1B%-12345X');
  }
}
