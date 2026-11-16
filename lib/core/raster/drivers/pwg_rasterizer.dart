import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../../domain/models/print_request.dart';
import '../../../domain/models/printer_device.dart';
import '../printer_rasterizer.dart';

/// Universal PWG Raster (PWG 5102.4) driver for modern IPP-over-USB, AirPrint, Mopria,
/// and IPP Everywhere network/USB printers.
class PwgRasterizer implements PrinterRasterizer {
  const PwgRasterizer();

  @override
  String get id => 'driver.pwg_raster';

  @override
  String get displayName => 'Universal PWG Raster (IPP-over-USB / AirPrint)';

  @override
  bool canHandle(PrinterDevice device) {
    // Modern IPP-over-USB printers advertise USB class 7, subclass 1, protocol 4
    if (device.isIppOverUsb) return true;

    final name = '${device.name} ${device.model ?? ''}'.toLowerCase();
    return name.contains('ipp') ||
        name.contains('mopria') ||
        name.contains('airprint') ||
        name.contains('everywhere');
  }

  @override
  List<int> createJobHeader(PrintSettings settings, String jobName) {
    // PWG Raster synchronization header: "RaS2"
    return const [0x52, 0x61, 0x53, 0x32];
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

    // 1. PWG Raster Page Header (exact 1796 bytes defined in PWG 5102.4)
    final header = Uint8List(1796);
    final headerByteData = ByteData.view(header.buffer);

    // MediaColor (64 bytes string)
    _writeString(header, 0, 'white', 64);
    // MediaType (64 bytes string)
    _writeString(header, 64, 'stationery', 64);
    // PrintContentOptimize (64 bytes)
    _writeString(header, 128, 'auto', 64);

    // Offsets at 288:
    // HWResolutionX (uint32 big-endian at byte 288)
    // HWResolutionY (uint32 big-endian at byte 292)
    const dpi = 600;
    headerByteData.setUint32(288, dpi, Endian.big);
    headerByteData.setUint32(292, dpi, Endian.big);

    // PageSizeX (uint32 at 304 in points: widthPixels * 72 / 600)
    final sizeXPoints = (widthPixels * 72 / dpi).round();
    final sizeYPoints = (heightPixels * 72 / dpi).round();
    headerByteData.setUint32(304, sizeXPoints, Endian.big);
    headerByteData.setUint32(308, sizeYPoints, Endian.big);

    // Duplex (uint32 at 324: 0 = None, 1 = Long edge, 2 = Short edge)
    final duplexVal = settings.duplex
        ? (settings.duplexMode == DuplexMode.shortEdge ? 2 : 1)
        : 0;
    headerByteData.setUint32(324, duplexVal, Endian.big);

    // Width (uint32 at 344 in pixels)
    // Height (uint32 at 348 in pixels)
    headerByteData.setUint32(344, widthPixels, Endian.big);
    headerByteData.setUint32(348, heightPixels, Endian.big);

    // BitsPerColor (uint32 at 352: 1 for bi-level monochrome)
    headerByteData.setUint32(352, 1, Endian.big);
    // BitsPerPixel (uint32 at 356: 1)
    headerByteData.setUint32(356, 1, Endian.big);
    // BytesPerLine (uint32 at 360)
    headerByteData.setUint32(360, linesize, Endian.big);
    // ColorOrder (uint32 at 364: 0 = Chunky)
    headerByteData.setUint32(364, 0, Endian.big);
    // ColorSpace (uint32 at 368: 18 = Sgray, 3 = Black / Device1)
    headerByteData.setUint32(368, 3, Endian.big);
    // TotalPageCount (uint32 at 376)
    headerByteData.setUint32(376, totalPages, Endian.big);
    // CrossFeedTransform (int32 at 380: 1)
    headerByteData.setInt32(380, 1, Endian.big);
    // FeedTransform (int32 at 384: 1)
    headerByteData.setInt32(384, 1, Endian.big);

    buffer.add(header);

    // 2. Scanline raster packets
    // In PWG Raster, each line starts with a 1-byte repeat count (0 = print 1 line, N = repeat N+1 lines)
    // Followed by the raw scanline bitmap bytes.
    int y = 0;
    while (y < heightPixels) {
      final lineOffset = y * linesize;
      if (lineOffset >= pixelBytes.length) break;

      final copyLen = math.min(linesize, pixelBytes.length - lineOffset);
      final line =
          Uint8List.sublistView(pixelBytes, lineOffset, lineOffset + copyLen);

      // Check if subsequent lines are identical for repeat compression
      int repeatCount = 0;
      while (y + repeatCount + 1 < heightPixels && repeatCount < 255) {
        final nextOffset = (y + repeatCount + 1) * linesize;
        if (nextOffset + copyLen > pixelBytes.length) break;

        bool identical = true;
        for (int b = 0; b < copyLen; b++) {
          if (pixelBytes[nextOffset + b] != line[b]) {
            identical = false;
            break;
          }
        }
        if (!identical) break;
        repeatCount++;
      }

      // Add repeat byte (0..255)
      buffer.addByte(repeatCount);
      buffer.add(line);

      y += repeatCount + 1;
    }

    return buffer.toBytes();
  }

  @override
  List<int> createJobFooter(String jobName) {
    // PWG Raster has no mandatory trailer beyond page streams
    return const [];
  }

  static void _writeString(
      Uint8List dest, int offset, String text, int maxLen) {
    final bytes = utf8.encode(text);
    final len = math.min(bytes.length, maxLen - 1);
    dest.setRange(offset, offset + len, bytes);
  }
}
