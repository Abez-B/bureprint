import 'dart:convert';
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

    // GS v 0: Print raster bit image
    // Format: 0x1D, 0x76, 0x30, mode (0), xL, xH, yL, yH, data...
    final xL = linesize % 256;
    final xH = linesize ~/ 256;
    final yL = heightPixels % 256;
    final yH = heightPixels ~/ 256;

    buffer.add([0x1D, 0x76, 0x30, 0x00, xL, xH, yL, yH]);
    buffer.add(pixelBytes);

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
    pjl.write('\x1B&l${settings.copies}X'); // Copies
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
    // Start raster graphics: ESC * r 1 A
    buffer.add(ascii.encode('\x1B*r1A'));

    for (int y = 0; y < heightPixels; y++) {
      final offset = y * linesize;
      if (offset >= pixelBytes.length) break;
      final line = pixelBytes.sublist(
        offset,
        (offset + linesize).clamp(0, pixelBytes.length),
      );

      // ESC * b [count] W [data]
      buffer.add(ascii.encode('\x1B*b${line.length}W'));
      buffer.add(line);
    }

    // End raster graphics: ESC * r B
    buffer.add(ascii.encode('\x1B*rB\x0C'));
    return buffer.toBytes();
  }

  @override
  List<int> createJobFooter(String jobName) {
    return utf8.encode('\x1B%-12345X@PJL EOJ\n\x1B%-12345X');
  }
}
