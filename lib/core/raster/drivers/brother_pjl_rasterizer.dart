import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../../domain/models/print_request.dart';
import '../../../domain/models/printer_device.dart';
import '../printer_rasterizer.dart';

/// Driver for Brother monochrome laser printers using Brother PJL & GDI delta rasterization.
/// Compatible with: Brother HL-L2320D, HL-L2300D, HL-2240, HL-2270DW, DCP-L2520D, etc.
class BrotherPjlRasterizer implements PrinterRasterizer {
  const BrotherPjlRasterizer();

  @override
  String get id => 'driver.brother.pjl';

  @override
  String get displayName => 'Brother Monochrome Laser (PJL / GDI)';

  @override
  bool canHandle(PrinterDevice device) {
    // Brother Vendor ID is 0x04F9 (1273 in decimal)
    if (device.vendorId == 0x04F9 || device.vendorId == 1273) {
      return true;
    }
    final name = '${device.name} ${device.model ?? ''}'.toLowerCase();
    return name.contains('brother') ||
        name.contains('hl-l23') ||
        name.contains('hl-22');
  }

  @override
  List<int> createJobHeader(PrintSettings settings, String jobName) {
    final buffer = BytesBuilder();

    // 1. Initial 128 null sync bytes
    buffer.add(Uint8List(128));

    // Clean job name
    final safeJobName = jobName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\. ]'), '_');

    // 2. PJL Universal Exit Language & Job Header
    final pjl = StringBuffer();
    pjl.write('\x1B%-12345X@PJL\n');
    pjl.write('@PJL JOB NAME="$safeJobName"\n');

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
    final output = BytesBuilder();

    // 1. Page Header for each page
    final pagePjl = StringBuffer();
    pagePjl.write('\x1B%-12345X@PJL\n');
    pagePjl.write('@PJL SET RAS1200MODE = FALSE\n');
    pagePjl.write('@PJL SET RESOLUTION = 600\n');
    pagePjl.write(
        '@PJL SET ECONOMODE = ${settings.quality == PrintQuality.draft ? "ON" : "OFF"}\n');
    pagePjl.write('@PJL SET SOURCETRAY = AUTO\n');
    pagePjl.write('@PJL SET MEDIATYPE = REGULAR\n');
    final paperName = _mapPaperSize(settings.paperSize);
    pagePjl.write('@PJL SET PAPER = $paperName\n');
    pagePjl.write('@PJL SET PAGEPROTECT = AUTO\n');
    pagePjl.write(
        '@PJL SET ORIENTATION = ${settings.landscape ? "LANDSCAPE" : "PORTRAIT"}\n');
    pagePjl.write('@PJL ENTER LANGUAGE = PCL\n');
    pagePjl.write('\x1BE');
    pagePjl.write('\x1B&l${math.max(1, settings.copies)}X');
    if (settings.duplex) {
      pagePjl.write('\x1B&l2S');
    }
    output.add(utf8.encode(pagePjl.toString()));

    // Line buffers
    final currentLine = Uint8List(linesize);
    final referenceLine = Uint8List(linesize);
    final block = _BrotherBlock();
    const linesPerBand = 64;

    // Line 0: encode without reference
    final len0 = math.min(linesize, pixelBytes.length);
    currentLine.setRange(0, len0, pixelBytes, 0);
    if (len0 < linesize) {
      currentLine.fillRange(len0, linesize, 0);
    }
    block.addLine(_encodeLineWithoutReference(currentLine));
    referenceLine.setRange(0, linesize, currentLine);

    // 2. Start Brother raster stream command
    output.add(ascii.encode('\x1B*b1030m'));

    for (int y = 1; y < heightPixels; y++) {
      final lineOffset = y * linesize;
      final remaining = pixelBytes.length - lineOffset;
      if (remaining <= 0) break;

      final copyLen = math.min(linesize, remaining);
      currentLine.setRange(0, copyLen, pixelBytes, lineOffset);
      if (copyLen < linesize) {
        currentLine.fillRange(copyLen, linesize, 0);
      }

      Uint8List encoded;
      if (y % linesPerBand == 0) {
        block.flush(output);
        encoded = _encodeLineWithoutReference(currentLine);
      } else {
        encoded = _encodeLineWithReference(currentLine, referenceLine);
        if (!block.lineFits(encoded.length)) {
          block.flush(output);
          encoded = _encodeLineWithoutReference(currentLine);
        }
      }

      block.addLine(encoded);
      referenceLine.setRange(0, linesize, currentLine);
    }

    block.flush(output);

    // End raster stream & form feed (eject sheet)
    output.add(ascii.encode('1030M\x0C'));
    return output.toBytes();
  }

  @override
  List<int> createJobFooter(String jobName) {
    final safeJobName = jobName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\. ]'), '_');
    final footer =
        '\x1B%-12345X@PJL\n@PJL EOJ NAME="$safeJobName"\n\x1B%-12345X';
    return utf8.encode(footer);
  }

  String _mapPaperSize(String paperSize) {
    if (paperSize.contains('a4')) return 'A4';
    if (paperSize.contains('a3')) return 'A3';
    if (paperSize.contains('a5')) return 'A5';
    if (paperSize.contains('legal')) return 'LEGAL';
    if (paperSize.contains('tabloid')) return 'TABLOID';
    return 'LETTER';
  }

  static bool _allZeros(Uint8List line) {
    for (int i = 0; i < line.length; i++) {
      if (line[i] != 0) return false;
    }
    return true;
  }

  static Uint8List _encodeLineWithoutReference(Uint8List line) {
    if (_allZeros(line)) {
      return Uint8List.fromList([0xFF]);
    }
    final buf = BytesBuilder();
    buf.addByte(1); // 1 edit
    _writeSubstitute(0, line, 0, line.length, buf);
    return buf.toBytes();
  }

  static Uint8List _encodeLineWithReference(
      Uint8List line, Uint8List reference) {
    if (_allZeros(line)) {
      return Uint8List.fromList([0xFF]);
    }

    final output = BytesBuilder();
    output.addByte(0); // placeholder for edit count

    const maxEdits = 254;
    int numEdits = 0;
    int i = 0;
    int refI = 0;

    int lastMismatch = line.length;
    while (lastMismatch > 0 &&
        line[lastMismatch - 1] == reference[lastMismatch - 1]) {
      lastMismatch--;
    }

    while (i < lastMismatch) {
      // Skip matching bytes
      int offset = 0;
      while (i < lastMismatch && line[i] == reference[refI]) {
        offset++;
        i++;
        refI++;
      }
      if (i >= lastMismatch) break;

      numEdits++;
      if (numEdits == maxEdits) {
        _writeSubstitute(offset, line, i, lastMismatch, output);
        break;
      }

      int repeatCount = 1;
      final byteVal = line[i];
      while (
          i + repeatCount < lastMismatch && line[i + repeatCount] == byteVal) {
        repeatCount++;
      }

      if (repeatCount >= 3) {
        _writeRepeat(offset, repeatCount, byteVal, output);
        i += repeatCount;
        refI += repeatCount;
      } else {
        int subLen = 1;
        while (i + subLen < lastMismatch) {
          if (line[i + subLen] == reference[refI + subLen] &&
              i + subLen + 1 < lastMismatch &&
              line[i + subLen + 1] == reference[refI + subLen + 1]) {
            break;
          }
          subLen++;
        }
        _writeSubstitute(offset, line, i, i + subLen, output);
        i += subLen;
        refI += subLen;
      }
    }

    final bytes = output.toBytes();
    bytes[0] = numEdits.clamp(0, 255);
    return bytes;
  }

  static void _writeOverflow(int value, BytesBuilder out) {
    if (value >= 0) {
      if (value < 255) {
        out.addByte(value);
      } else {
        int count255 = value ~/ 255;
        for (int i = 0; i < count255; i++) {
          out.addByte(255);
        }
        out.addByte(value % 255);
      }
    }
  }

  static void _writeSubstitute(
      int offset, Uint8List line, int start, int end, BytesBuilder out) {
    const offsetMax = 15;
    const countMax = 7;
    final count = (end - start) - 1;

    final offsetLow = math.min(offset, offsetMax);
    final countLow = math.min(count, countMax);

    out.addByte((offsetLow << 3) | countLow);
    _writeOverflow(offset - offsetMax, out);
    _writeOverflow(count - countMax, out);
    out.add(line.sublist(start, end));
  }

  static void _writeRepeat(int offset, int count, int value, BytesBuilder out) {
    const offsetMax = 3;
    const countMax = 31;
    final adjustedCount = count - 2;

    final offsetLow = math.min(offset, offsetMax);
    final countLow = math.min(adjustedCount, countMax);

    out.addByte(128 | (offsetLow << 5) | countLow);
    _writeOverflow(offset - offsetMax, out);
    _writeOverflow(adjustedCount - countMax, out);
    out.addByte(value);
  }
}

class _BrotherBlock {
  static const maxBlockSize = 16350;
  final List<Uint8List> _lines = [];
  int _lineBytes = 0;

  bool get isEmpty => _lineBytes == 0;

  bool lineFits(int size) => _lineBytes + size < maxBlockSize;

  void addLine(Uint8List line) {
    _lineBytes += line.length;
    _lines.add(line);
  }

  void flush(BytesBuilder target) {
    if (isEmpty) return;
    final headerStr =
        '${_lineBytes + 2}w\x00${String.fromCharCode(_lines.length)}';
    target.add(latin1.encode(headerStr));
    for (final line in _lines) {
      target.add(line);
    }
    _lineBytes = 0;
    _lines.clear();
  }
}
