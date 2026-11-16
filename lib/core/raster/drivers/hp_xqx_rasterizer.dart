import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../../domain/models/print_request.dart';
import '../../../domain/models/printer_device.dart';
import '../printer_rasterizer.dart';

/// Driver for HP LaserJet P1000 and M1005 series printers using the XQX (ZjStream) protocol.
///
/// Supported hardware models:
/// - HP LaserJet P1005 (USB ID 0x03F0:0x3B17)
/// - HP LaserJet P1006 (USB ID 0x03F0:0x3E17)
/// - HP LaserJet P1007 (USB ID 0x03F0:0x4817)
/// - HP LaserJet P1008 (USB ID 0x03F0:0x4917)
/// - HP LaserJet P1505 / P1505n (USB ID 0x03F0:0x3F17 / 0x4017)
/// - HP LaserJet M1005 MFP
class HpLaserJetP1000Rasterizer implements PrinterRasterizer {
  const HpLaserJetP1000Rasterizer();

  @override
  String get id => 'driver.hp.laserjet.p1000';

  @override
  String get displayName => 'HP LaserJet P1000 / M1005 Series (XQX)';

  @override
  bool canHandle(PrinterDevice device) {
    if (device.vendorId == 0x03F0 || device.vendorId == 1008) {
      final pid = device.productId;
      if (pid == 0x3B17 ||
          pid == 0x3D17 ||
          pid == 0x3E17 ||
          pid == 0x4817 ||
          pid == 0x4917 ||
          pid == 0x3F17 ||
          pid == 0x4017) {
        return true;
      }
    }
    final name = '${device.name} ${device.model ?? ''}'.toLowerCase();
    return name.contains('p1005') ||
        name.contains('p1006') ||
        name.contains('p1007') ||
        name.contains('p1008') ||
        name.contains('p1505') ||
        name.contains('m1005') ||
        name.contains('m1120');
  }

  @override
  List<int> createJobHeader(PrintSettings settings, String jobName) {
    final buffer = BytesBuilder();

    // 1. PJL Preamble
    final now = DateTime.now();
    final timeStr = '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';

    final econo = settings.quality == PrintQuality.draft ? 'ON' : 'OFF';
    final density = settings.quality == PrintQuality.draft ? 1 : 5;
    final ret = settings.quality == PrintQuality.draft ? 'OFF' : 'DARK';
    final copies = math.max(1, settings.copies);

    final pjl = StringBuffer()
      ..write('\x1B%-12345X@PJL JOB\n')
      ..write('@PJL SET JAMRECOVERY=OFF\n')
      ..write('@PJL SET DENSITY=$density\n')
      ..write('@PJL SET ECONOMODE=$econo\n')
      ..write('@PJL SET RET=$ret\n')
      ..write('@PJL SET COPIES=$copies\n')
      ..write('@PJL INFO STATUS\n')
      ..write('@PJL USTATUS DEVICE = ON\n')
      ..write('@PJL USTATUS JOB = ON\n')
      ..write('@PJL USTATUS PAGE = ON\n')
      ..write('@PJL USTATUS TIMED = 30\n')
      ..write('@PJL SET JOBATTR="JobAttr4=$timeStr"')
      ..write('\x00')
      ..write('\x1B%-12345X');

    buffer.add(utf8.encode(pjl.toString()));

    // 2. Magic bytes: ,XQX
    buffer.add(const [0x2C, 0x58, 0x51, 0x58]);

    // 3. START_DOC Record (Type 1, 7 items)
    final dmDuplex = settings.duplex
        ? (settings.duplexMode == DuplexMode.shortEdge ? 3 : 2)
        : 0;

    final startDoc = _buildRecord(1, [
      _RecordItem(0x80000000, _u32Bytes(84)),
      _RecordItem(0x10000005, _u32Bytes(1)),
      _RecordItem(0x10000001, _u32Bytes(0)),
      _RecordItem(0x10000002,
          _u32Bytes(dmDuplex)), // DMDUPLEX (0=none, 2=long edge, 3=short edge)
      _RecordItem(0x10000000, _u32Bytes(0)),
      _RecordItem(0x10000003, _u32Bytes(1)),
      _RecordItem(0x80000001, _u32Bytes(0xDEADBEEF)), // END
    ]);
    buffer.add(startDoc);

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

    final paperCode = _mapPaperCode(settings.paperSize);
    final geom = _getPaperGeometry(paperCode);

    // Target hardware printable canvas dimensions matching foo2xqx reference
    final targetPrintableWidth = geom.printableWidth;
    final targetPrintableHeight = geom.printableHeight;
    final rasterWidth = geom.rasterWidth;
    final rasterBpl = (rasterWidth + 7) >> 3;

    // Allocate raster buffer sized to exact hardware page dimensions
    final rasterBytes = Uint8List(rasterBpl * targetPrintableHeight);

    // Calculate offsets to center the content on the printable canvas
    final copyH = math.min(heightPixels, targetPrintableHeight);
    final copyW = math.min(widthPixels, targetPrintableWidth);
    final copyBpl = (copyW + 7) >> 3;

    final offsetX = (targetPrintableWidth - copyW) ~/ 2;
    final offsetY = (targetPrintableHeight - copyH) ~/ 2;
    final offsetByteX = offsetX >> 3;

    for (int y = 0; y < copyH; y++) {
      final srcOffset = y * linesize;
      final dstOffset = (y + offsetY) * rasterBpl + offsetByteX;
      final copyLen = math.min(copyBpl, pixelBytes.length - srcOffset);
      if (copyLen > 0 && (dstOffset + copyLen) <= rasterBytes.length) {
        rasterBytes.setRange(
            dstOffset, dstOffset + copyLen, pixelBytes, srcOffset);
      }
    }

    // Apply draft toner-saving pattern if requested
    if (settings.quality == PrintQuality.draft) {
      for (int y = 0; y < targetPrintableHeight; y++) {
        final rowOffset = y * rasterBpl;
        final mask = (y % 2 == 0) ? 0x55 : 0xAA;
        for (int x = 0; x < rasterBpl; x++) {
          rasterBytes[rowOffset + x] &= mask;
        }
      }
    }

    // Encode bitmap into ITU-T T.82 JBIG bi-level stream
    final jbig = JbigBilevelEncoder.encode(
      width: rasterWidth,
      height: targetPrintableHeight,
      bitmap: rasterBytes,
    );

    final copies = math.max(1, settings.copies);
    final isDraft = settings.quality == PrintQuality.draft ? 1 : 0;

    // START_PAGE Record (Type 3)
    final pageItems = <_RecordItem>[
      _RecordItem(0x80000000, _u32Bytes(settings.duplex ? 192 : 180)),
      _RecordItem(0x20000005, _u32Bytes(copies)),
      _RecordItem(0x20000006, _u32Bytes(7)), // DMBIN_AUTO
      _RecordItem(0x20000000, _u32Bytes(1)), // DMMEDIA_PLAIN
      _RecordItem(0x20000007, _u32Bytes(1)),
      _RecordItem(0x20000008, _u32Bytes(600)), // Res X
      _RecordItem(0x20000009, _u32Bytes(600)), // Res Y
      _RecordItem(
          0x2000000D, _u32Bytes(rasterWidth)), // Raster X (Padded to 128)
      _RecordItem(0x2000000E, _u32Bytes(targetPrintableHeight)), // Raster Y
      _RecordItem(0x2000000A, _u32Bytes(1)), // Video BPP
      _RecordItem(0x2000000F, _u32Bytes(targetPrintableWidth)), // Video X
      _RecordItem(0x20000010, _u32Bytes(targetPrintableHeight)), // Video Y
      _RecordItem(0x20000011, _u32Bytes(isDraft)), // EconoMode
    ];

    if (settings.duplex) {
      final pause = (pageIndex % 2 == 0) ? 0 : 1;
      pageItems.add(_RecordItem(0x20000012, _u32Bytes(pause)));
    }

    pageItems.add(_RecordItem(0x20000001, _u32Bytes(paperCode))); // DMPAPER
    pageItems.add(_RecordItem(0x80000001, _u32Bytes(0xDEADBEEF))); // END

    buffer.add(_buildRecord(3, pageItems));

    // START_PLANE + JBIG chunks (65536 bytes max per chunk)
    final jbigPayload = jbig.payload;
    const chunkSize = 65536;
    var offset = 0;
    var isFirstChunk = true;

    while (offset < jbigPayload.length || isFirstChunk) {
      final currentChunkLen = math.min(chunkSize, jbigPayload.length - offset);
      final chunkData = currentChunkLen > 0
          ? jbigPayload.sublist(offset, offset + currentChunkLen)
          : Uint8List(0);

      // START_PLANE Record (Type 5)
      final planeItems = <_RecordItem>[
        _RecordItem(0x80000000, _u32Bytes(isFirstChunk ? 64 : 48)),
        _RecordItem(0x40000000, _u32Bytes(0)),
      ];

      if (isFirstChunk) {
        planeItems.add(_RecordItem(0x40000002, jbig.bih)); // BIH 20 bytes
      } else {
        planeItems.add(_RecordItem(0x40000003, _u32Bytes(1)));
      }
      planeItems.add(_RecordItem(0x80000001, _u32Bytes(0xDEADBEEF)));

      buffer.add(_buildRecord(5, planeItems));

      // JBIG Payload Record (Type 7)
      buffer.add(_buildRawRecord(7, chunkData));

      // END_PLANE Record (Type 6)
      buffer.add(_buildRecord(6, []));

      offset += currentChunkLen;
      isFirstChunk = false;
      if (offset >= jbigPayload.length) break;
    }

    // END_PAGE Record (Type 4)
    buffer.add(_buildRecord(4, []));

    return buffer.toBytes();
  }

  @override
  List<int> createJobFooter(String jobName) {
    final buffer = BytesBuilder();

    // END_DOC Record (Type 2)
    buffer.add(_buildRecord(2, []));

    // PJL Trailer
    buffer.add(utf8.encode('\x1B%-12345X@PJL EOJ\n\x1B%-12345X'));

    return buffer.toBytes();
  }

  int _mapPaperCode(String paperSize) {
    final lower = paperSize.toLowerCase();
    if (lower.contains('letter')) return 1; // DMPAPER_LETTER
    if (lower.contains('legal')) return 5; // DMPAPER_LEGAL
    if (lower.contains('executive')) return 7; // DMPAPER_EXECUTIVE
    if (lower.contains('a5')) return 11; // DMPAPER_A5
    if (lower.contains('b5')) return 13; // DMPAPER_B5
    return 9; // DMPAPER_A4 (default)
  }

  static ({int printableWidth, int printableHeight, int rasterWidth})
      _getPaperGeometry(int paperCode) {
    switch (paperCode) {
      case 1: // DMPAPER_LETTER
        return (printableWidth: 4924, printableHeight: 6432, rasterWidth: 4992);
      case 5: // DMPAPER_LEGAL
        return (printableWidth: 4924, printableHeight: 8208, rasterWidth: 4992);
      case 7: // DMPAPER_EXECUTIVE
        return (printableWidth: 4158, printableHeight: 6108, rasterWidth: 4224);
      case 11: // DMPAPER_A5
        return (printableWidth: 3304, printableHeight: 4768, rasterWidth: 3328);
      case 13: // DMPAPER_B5
        return (printableWidth: 4107, printableHeight: 5878, rasterWidth: 4224);
      case 9: // DMPAPER_A4
      default:
        return (printableWidth: 4784, printableHeight: 6848, rasterWidth: 4864);
    }
  }

  static Uint8List _u32Bytes(int value) {
    final bd = ByteData(4);
    bd.setUint32(0, value, Endian.big);
    return bd.buffer.asUint8List();
  }

  static Uint8List _buildRecord(int recType, List<_RecordItem> items) {
    final totalBodySize =
        items.fold<int>(0, (acc, item) => acc + 8 + item.bytes.length);
    final bd = ByteData(8 + totalBodySize);
    bd.setUint32(0, recType, Endian.big);
    bd.setUint32(4, items.length, Endian.big);

    var offset = 8;
    for (final item in items) {
      bd.setUint32(offset, item.tag, Endian.big);
      bd.setUint32(offset + 4, item.bytes.length, Endian.big);
      offset += 8;
      for (int i = 0; i < item.bytes.length; i++) {
        bd.setUint8(offset + i, item.bytes[i]);
      }
      offset += item.bytes.length;
    }

    return bd.buffer.asUint8List();
  }

  static Uint8List _buildRawRecord(int recType, Uint8List rawData) {
    final bd = ByteData(8 + rawData.length);
    bd.setUint32(0, recType, Endian.big);
    bd.setUint32(4, rawData.length, Endian.big);
    for (int i = 0; i < rawData.length; i++) {
      bd.setUint8(8 + i, rawData[i]);
    }
    return bd.buffer.asUint8List();
  }
}

class _RecordItem {
  const _RecordItem(this.tag, this.bytes);
  final int tag;
  final Uint8List bytes;
}

class JbigEncodedResult {
  const JbigEncodedResult({required this.bih, required this.payload});
  final Uint8List bih;
  final Uint8List payload;
}

/// Lossless bi-level image encoder conforming to ITU-T Recommendation T.82 / T.85.
class JbigBilevelEncoder {
  static const int _linesPerStripe = 128;

  static JbigEncodedResult encode({
    required int width,
    required int height,
    required Uint8List bitmap,
  }) {
    final bpl = (width + 7) >> 3;

    // 1. Construct 20-byte BIH (Bitmap Information Header)
    final bih = Uint8List(20);
    bih[0] = 0; // DL
    bih[1] = 0; // D
    bih[2] = 1; // P (1 plane)
    bih[3] = 0;
    final bihBd = ByteData.sublistView(bih);
    bihBd.setUint32(4, width, Endian.big);
    bihBd.setUint32(8, height, Endian.big);
    bihBd.setUint32(12, _linesPerStripe, Endian.big);
    bih[16] = 0; // MX = 0 (Adaptive template movement disabled)
    bih[17] = 0; // MY = 0
    bih[18] = 3; // Order = ILEAVE | SMID
    bih[19] = 0x40; // Options = JBG_LRLTWO (Two-line template)

    final numStripes = (height + _linesPerStripe - 1) ~/ _linesPerStripe;
    final se = JbigArEncoder();
    final outBytes = BytesBuilder();

    for (int s = 0; s < numStripes; s++) {
      final stripeYStart = s * _linesPerStripe;
      final stripeLines = math.min(_linesPerStripe, height - stripeYStart);

      for (int i = 0; i < stripeLines; i++) {
        final y = stripeYStart + i;
        final rowOffset = y * bpl;

        var lineH1 = 0;
        var lineH2 = 0;
        if (i > 0 || s > 0) {
          lineH2 = bitmap[rowOffset - bpl] << 8;
        }

        var col = 0;
        for (int byteIdx = 0; byteIdx < bpl; byteIdx++) {
          lineH1 |= bitmap[rowOffset + byteIdx];
          if ((col < bpl * 8 - 8) && (i > 0 || s > 0)) {
            lineH2 |= bitmap[rowOffset - bpl + byteIdx + 1];
          }

          while (true) {
            lineH1 = (lineH1 << 1) & 0xFFFFFFFF;
            lineH2 = (lineH2 << 1) & 0xFFFFFFFF;
            final cx = (((lineH2 >> 10) & 0x3F0) | ((lineH1 >> 9) & 0x00F));
            final pix = (lineH1 >> 8) & 1;
            se.encode(cx, pix);
            col++;
            if ((col & 7 == 0) || (col >= width)) {
              break;
            }
          }
        }
      }

      se.flush();
      outBytes.add(se.takeOutput());
      se.resetInterval();
    }

    return JbigEncodedResult(
      bih: bih,
      payload: outBytes.toBytes(),
    );
  }
}

/// Binary arithmetic encoder conforming to ITU-T Recommendation T.82 Section 6.3.
class JbigArEncoder {
  JbigArEncoder() {
    _init();
  }

  static const List<int> _lszTab = [
    0x5a1d,
    0x2586,
    0x1114,
    0x080b,
    0x03d8,
    0x01da,
    0x00e5,
    0x006f,
    0x0036,
    0x001a,
    0x000d,
    0x0006,
    0x0003,
    0x0001,
    0x5a7f,
    0x3f25,
    0x2cf2,
    0x207c,
    0x17b9,
    0x1182,
    0x0cef,
    0x09a1,
    0x072f,
    0x055c,
    0x0406,
    0x0303,
    0x0240,
    0x01b1,
    0x0144,
    0x00f5,
    0x00b7,
    0x008a,
    0x0068,
    0x004e,
    0x003b,
    0x002c,
    0x5ae1,
    0x484c,
    0x3a0d,
    0x2ef1,
    0x261f,
    0x1f33,
    0x19a8,
    0x1518,
    0x1177,
    0x0e74,
    0x0bfb,
    0x09f8,
    0x0861,
    0x0706,
    0x05cd,
    0x04de,
    0x040f,
    0x0363,
    0x02d4,
    0x025c,
    0x01f8,
    0x01a4,
    0x0160,
    0x0125,
    0x00f6,
    0x00cb,
    0x00ab,
    0x008f,
    0x5b12,
    0x4d04,
    0x412c,
    0x37d8,
    0x2fe8,
    0x293c,
    0x2379,
    0x1edf,
    0x1aa9,
    0x174e,
    0x1424,
    0x119c,
    0x0f6b,
    0x0d51,
    0x0bb6,
    0x0a40,
    0x5832,
    0x4d1c,
    0x438e,
    0x3bdd,
    0x34ee,
    0x2eae,
    0x299a,
    0x2516,
    0x5570,
    0x4ca9,
    0x44d9,
    0x3e22,
    0x3824,
    0x32b4,
    0x2e17,
    0x56a8,
    0x4f46,
    0x47e5,
    0x41cf,
    0x3c3d,
    0x375e,
    0x5231,
    0x4c0f,
    0x4639,
    0x415e,
    0x5627,
    0x50e7,
    0x4b85,
    0x5597,
    0x504f,
    0x5a10,
    0x5522,
    0x59eb,
  ];

  static const List<int> _nmpsTab = [
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    13,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
    24,
    25,
    26,
    27,
    28,
    29,
    30,
    31,
    32,
    33,
    34,
    35,
    9,
    37,
    38,
    39,
    40,
    41,
    42,
    43,
    44,
    45,
    46,
    47,
    48,
    49,
    50,
    51,
    52,
    53,
    54,
    55,
    56,
    57,
    58,
    59,
    60,
    61,
    62,
    63,
    32,
    65,
    66,
    67,
    68,
    69,
    70,
    71,
    72,
    73,
    74,
    75,
    76,
    77,
    78,
    79,
    48,
    81,
    82,
    83,
    84,
    85,
    86,
    87,
    71,
    89,
    90,
    91,
    92,
    93,
    94,
    86,
    96,
    97,
    98,
    99,
    100,
    93,
    102,
    103,
    104,
    99,
    106,
    107,
    103,
    109,
    107,
    111,
    109,
    111,
  ];

  static const List<int> _nlpsTab = [
    129,
    14,
    16,
    18,
    20,
    23,
    25,
    28,
    30,
    33,
    35,
    9,
    10,
    12,
    143,
    36,
    38,
    39,
    40,
    42,
    43,
    45,
    46,
    48,
    49,
    51,
    52,
    54,
    56,
    57,
    59,
    60,
    62,
    63,
    32,
    33,
    165,
    64,
    65,
    67,
    68,
    69,
    70,
    72,
    73,
    74,
    75,
    77,
    78,
    79,
    48,
    50,
    50,
    51,
    52,
    53,
    54,
    55,
    56,
    57,
    58,
    59,
    61,
    61,
    193,
    80,
    81,
    82,
    83,
    84,
    86,
    87,
    87,
    72,
    72,
    74,
    74,
    75,
    77,
    77,
    208,
    88,
    89,
    90,
    91,
    92,
    93,
    86,
    216,
    95,
    96,
    97,
    99,
    99,
    93,
    223,
    101,
    102,
    103,
    104,
    99,
    105,
    106,
    107,
    103,
    233,
    108,
    109,
    110,
    111,
    238,
    112,
    240,
  ];

  static const int _markerStuff = 0x00;
  static const int _markerEsc = 0xFF;
  static const int _markerSdnorm = 0x02;

  final Uint8List _st = Uint8List(4096);
  final List<int> _out = <int>[];
  int _c = 0;
  int _a = 0x10000;
  int _sc = 0;
  int _ct = 11;
  int _buffer = -1;

  void _init() {
    _c = 0;
    _a = 0x10000;
    _sc = 0;
    _ct = 11;
    _buffer = -1;
  }

  void resetInterval() {
    _c = 0;
    _a = 0x10000;
    _sc = 0;
    _ct = 11;
    _buffer = -1;
  }

  Uint8List takeOutput() {
    final res = Uint8List.fromList(_out);
    _out.clear();
    return res;
  }

  void encode(int cx, int pix) {
    final sVal = _st[cx];
    final ss = sVal & 0x7F;
    final lsz = _lszTab[ss];
    final mps = (sVal >> 7) & 1;

    if (pix != mps) {
      _a -= lsz;
      if (_a >= lsz) {
        _c += _a;
        _a = lsz;
      }
      _st[cx] = (sVal & 0x80) ^ _nlpsTab[ss];
    } else {
      _a -= lsz;
      if ((_a & 0xFFFF8000) != 0) {
        return;
      }
      if (_a < lsz) {
        _c += _a;
        _a = lsz;
      }
      _st[cx] = (sVal & 0x80) | _nmpsTab[ss];
    }

    while (true) {
      _a = (_a << 1) & 0xFFFF;
      _c = (_c << 1) & 0xFFFFFFFF;
      _ct--;
      if (_ct == 0) {
        final temp = _c >> 19;
        if ((temp & 0xFFFFFF00) != 0) {
          if (_buffer >= 0) {
            _buffer++;
            _out.add(_buffer & 0xFF);
            if (_buffer == _markerEsc) {
              _out.add(_markerStuff);
            }
          }
          while (_sc > 0) {
            _out.add(0x00);
            _sc--;
          }
          _buffer = temp & 0xFF;
        } else if (temp == 0xFF) {
          _sc++;
        } else {
          if (_buffer >= 0) {
            _out.add(_buffer);
          }
          while (_sc > 0) {
            _out.add(0xFF);
            _out.add(_markerStuff);
            _sc--;
          }
          _buffer = temp;
        }
        _c &= 0x7FFFF;
        _ct = 8;
      }
      if (_a >= 0x8000) {
        break;
      }
    }
  }

  void flush() {
    final temp = (_a - 1 + _c) & 0xFFFF0000;
    if (temp < _c) {
      _c = temp + 0x8000;
    } else {
      _c = temp;
    }
    _c = (_c << _ct) & 0xFFFFFFFF;
    if ((_c & 0xF8000000) != 0) {
      if (_buffer >= 0) {
        _out.add((_buffer + 1) & 0xFF);
        if ((_buffer + 1) == _markerEsc) {
          _out.add(_markerStuff);
        }
      }
      if ((_c & 0x7FFF800) != 0) {
        while (_sc > 0) {
          _out.add(0x00);
          _sc--;
        }
      }
    } else {
      if (_buffer >= 0) {
        _out.add(_buffer);
      }
      while (_sc > 0) {
        _out.add(0xFF);
        _out.add(_markerStuff);
        _sc--;
      }
    }
    if ((_c & 0x7FFF800) != 0) {
      final b1 = (_c >> 19) & 0xFF;
      _out.add(b1);
      if (b1 == _markerEsc) {
        _out.add(_markerStuff);
      }
      if ((_c & 0x7F800) != 0) {
        final b2 = (_c >> 11) & 0xFF;
        _out.add(b2);
        if (b2 == _markerEsc) {
          _out.add(_markerStuff);
        }
      }
    }

    // Strip trailing zeros
    while (_out.isNotEmpty && _out.last == 0) {
      _out.removeLast();
    }
    if (_out.isNotEmpty && _out.last == _markerEsc) {
      _out.add(_markerStuff);
    }
    _out.add(_markerEsc);
    _out.add(_markerSdnorm);
  }
}
