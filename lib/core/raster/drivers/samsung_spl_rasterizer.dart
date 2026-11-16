import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../../domain/models/print_request.dart';
import '../../../domain/models/printer_device.dart';
import '../printer_rasterizer.dart';

/// Driver for Samsung monochrome and color laser printers using Samsung Printer Language (SPL / QPDL).
/// Compatible with Samsung ML series (ML-1610, ML-1640, ML-2160, ML-2165), SCX series (SCX-3200, SCX-3400,
/// SCX-4300), SL-M series (SL-M2020, SL-M2070), and CLP series.
class SamsungSplRasterizer implements PrinterRasterizer {
  const SamsungSplRasterizer();

  @override
  String get id => 'driver.samsung.spl';

  @override
  String get displayName => 'Samsung Laser (SPL / QPDL)';

  @override
  bool canHandle(PrinterDevice device) {
    // Samsung USB Vendor ID is 0x04E8 (1256 in decimal)
    if (device.vendorId == 0x04E8 || device.vendorId == 1256) {
      return true;
    }
    final name = '${device.name} ${device.model ?? ''}'.toLowerCase();
    return name.contains('samsung') ||
        name.contains('ml-') ||
        name.contains('scx-') ||
        name.contains('sl-m') ||
        name.contains('clp-');
  }

  @override
  List<int> createJobHeader(PrintSettings settings, String jobName) {
    final buffer = BytesBuilder();
    final safeJob = jobName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\. ]'), '_');

    final pjl = StringBuffer()
      ..write('\x1B%-12345X@PJL\n')
      ..write('@PJL JOB NAME="$safeJob"\n')
      ..write('@PJL SET PAGEPROTECT = AUTO\n')
      ..write('@PJL SET RESOLUTION = 600\n')
      ..write('@PJL SET COPIES = ${math.max(1, settings.copies)}\n')
      ..write(
          '@PJL SET ECONOMODE = ${settings.quality == PrintQuality.draft ? "ON" : "OFF"}\n');

    if (settings.duplex) {
      final duplexMode = settings.duplexMode == DuplexMode.shortEdge
          ? 'SHORTEDGE'
          : 'LONGEDGE';
      pjl.write('@PJL SET DUPLEX = ON\n');
      pjl.write('@PJL SET BINDING = $duplexMode\n');
    }

    final paper = _mapPaperName(settings.paperSize);
    pjl.write('@PJL SET PAPER = $paper\n');
    pjl.write('@PJL ENTER LANGUAGE = QPDL\n');

    buffer.add(utf8.encode(pjl.toString()));
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

    // 1. QPDL Start Page Record
    // Magic: 0x1B, 0x7E, 0x13, 0x00, followed by page attributes
    final paperCode = _mapPaperCode(settings.paperSize);
    buffer.add([
      0x1B, 0x7E, 0x13, 0x00,
      paperCode,
      settings.duplex
          ? (settings.duplexMode == DuplexMode.shortEdge ? 2 : 1)
          : 0,
      math.max(1, settings.copies) & 0xFF,
      0x00, // Monochrome plane 0 (Black)
    ]);

    // 2. Stream raster scanlines with PackBits run-length compression
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
        // Advance raster line with 0-byte header
        buffer.add([0x1B, 0x7E, 0x01, 0x00, 0x00, 0x00]);
        continue;
      }

      final compressed = _encodePackBits(line);
      final lenL = compressed.length & 0xFF;
      final lenH = (compressed.length >> 8) & 0xFF;

      // QPDL raster packet: 0x1B 0x7E 0x02 [lenL] [lenH] [compressed data...]
      buffer.add([0x1B, 0x7E, 0x02, lenL, lenH]);
      buffer.add(compressed);
    }

    // 3. QPDL End Page Record: 0x1B, 0x7E, 0x14, 0x00 + Form Feed
    buffer.add([0x1B, 0x7E, 0x14, 0x00, 0x0C]);

    return buffer.toBytes();
  }

  @override
  List<int> createJobFooter(String jobName) {
    return utf8.encode('\x1B%-12345X@PJL EOJ\n\x1B%-12345X');
  }

  static Uint8List _encodePackBits(Uint8List src) {
    final out = BytesBuilder();
    int i = 0;
    while (i < src.length) {
      int runLen = 1;
      while (i + runLen < src.length &&
          src[i + runLen] == src[i] &&
          runLen < 128) {
        runLen++;
      }

      if (runLen > 1) {
        out.addByte((1 - runLen) & 0xFF);
        out.addByte(src[i]);
        i += runLen;
      } else {
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

  String _mapPaperName(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('letter')) return 'LETTER';
    if (lower.contains('legal')) return 'LEGAL';
    if (lower.contains('a5')) return 'A5';
    if (lower.contains('b5')) return 'B5';
    return 'A4';
  }

  int _mapPaperCode(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('letter')) return 0x01;
    if (lower.contains('legal')) return 0x02;
    if (lower.contains('a5')) return 0x04;
    return 0x00; // A4
  }
}
