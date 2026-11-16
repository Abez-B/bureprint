import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:bureprint/core/raster/document_rasterizer_engine.dart';
import 'package:bureprint/core/raster/drivers/brother_pjl_rasterizer.dart';
import 'package:bureprint/core/raster/drivers/epson_escpr_rasterizer.dart';
import 'package:bureprint/core/raster/drivers/hp_xqx_rasterizer.dart';
import 'package:bureprint/core/raster/drivers/pwg_rasterizer.dart';
import 'package:bureprint/core/raster/drivers/samsung_spl_rasterizer.dart';
import 'package:bureprint/core/raster/drivers/standard_rasterizers.dart';
import 'package:bureprint/core/raster/drivers/tspl_rasterizer.dart';
import 'package:bureprint/core/raster/printer_driver_registry.dart';
import 'package:bureprint/domain/models/print_request.dart';
import 'package:bureprint/domain/models/printer_device.dart';

void main() {
  group('Printer Driver Registry & Resolution Tests', () {
    test('resolves BrotherPjlRasterizer for Brother USB vendorId 0x04F9', () {
      const brotherDevice = PrinterDevice(
        id: 'usb-1',
        name: 'Brother HL-L2320D series',
        connectionType: PrinterConnectionType.usb,
        host: 'usb-1',
        port: 0,
        resourcePath: '/usb/print',
        vendorId: 0x04F9,
        productId: 0x0062,
      );

      final driver = PrinterDriverRegistry.resolveDriver(brotherDevice);
      expect(driver, isNotNull);
      expect(driver, isA<BrotherPjlRasterizer>());
      expect(driver!.id, equals('driver.brother.pjl'));
    });

    test('resolves EscPosRasterizer for thermal receipt printers', () {
      const posDevice = PrinterDevice(
        id: 'usb-2',
        name: 'POS-80 Thermal Printer',
        connectionType: PrinterConnectionType.usb,
        host: 'usb-2',
        port: 0,
        resourcePath: '/usb/print',
      );

      final driver = PrinterDriverRegistry.resolveDriver(posDevice);
      expect(driver, isNotNull);
      expect(driver, isA<EscPosRasterizer>());
      expect(driver!.id, equals('driver.escpos'));
    });

    test('resolves StandardPclRasterizer for HP / Canon PCL printers', () {
      const pclDevice = PrinterDevice(
        id: 'usb-3',
        name: 'HP LaserJet Professional',
        connectionType: PrinterConnectionType.usb,
        host: 'usb-3',
        port: 0,
        resourcePath: '/usb/print',
      );

      final driver = PrinterDriverRegistry.resolveDriver(pclDevice);
      expect(driver, isNotNull);
      expect(driver, isA<StandardPclRasterizer>());
      expect(driver!.id, equals('driver.pcl'));
    });

    test('resolves EpsonEscprRasterizer for Epson EcoTank USB printer (0x04B8)',
        () {
      const epsonDevice = PrinterDevice(
        id: 'usb-epson',
        name: 'Epson EcoTank L3250',
        connectionType: PrinterConnectionType.usb,
        host: 'usb-epson',
        port: 0,
        resourcePath: '/usb/print',
        vendorId: 0x04B8,
        productId: 0x1177,
      );

      final driver = PrinterDriverRegistry.resolveDriver(epsonDevice);
      expect(driver, isNotNull);
      expect(driver, isA<EpsonEscprRasterizer>());
      expect(driver!.id, equals('driver.epson.escpr'));
    });

    test(
        'resolves SamsungSplRasterizer for Samsung ML / SCX laser printer (0x04E8)',
        () {
      const samsungDevice = PrinterDevice(
        id: 'usb-samsung',
        name: 'Samsung ML-2160 Series',
        connectionType: PrinterConnectionType.usb,
        host: 'usb-samsung',
        port: 0,
        resourcePath: '/usb/print',
        vendorId: 0x04E8,
        productId: 0x330F,
      );

      final driver = PrinterDriverRegistry.resolveDriver(samsungDevice);
      expect(driver, isNotNull);
      expect(driver, isA<SamsungSplRasterizer>());
      expect(driver!.id, equals('driver.samsung.spl'));
    });

    test('resolves TsplRasterizer for Munbyn / TSC thermal label printer', () {
      const labelDevice = PrinterDevice(
        id: 'usb-label',
        name: 'Munbyn 4BarLabel Printer',
        connectionType: PrinterConnectionType.usb,
        host: 'usb-label',
        port: 0,
        resourcePath: '/usb/print',
      );

      final driver = PrinterDriverRegistry.resolveDriver(labelDevice);
      expect(driver, isNotNull);
      expect(driver, isA<TsplRasterizer>());
      expect(driver!.id, equals('driver.thermal.tspl'));
    });

    test('resolves PwgRasterizer for IPP-over-USB printer', () {
      const pwgDevice = PrinterDevice(
        id: 'usb-pwg',
        name: 'Mopria AirPrint Device',
        connectionType: PrinterConnectionType.usb,
        host: 'usb-pwg',
        port: 0,
        resourcePath: '/usb/print',
        isIppOverUsb: true,
      );

      final driver = PrinterDriverRegistry.resolveDriver(pwgDevice);
      expect(driver, isNotNull);
      expect(driver, isA<PwgRasterizer>());
      expect(driver!.id, equals('driver.pwg_raster'));
    });

    test(
        'resolves HpLaserJetP1000Rasterizer for HP LaserJet P1008 (0x03F0:0x4917)',
        () {
      const hpDevice = PrinterDevice(
        id: 'usb-1008',
        name: 'HP LaserJet P1008',
        connectionType: PrinterConnectionType.usb,
        host: 'usb-1008',
        port: 0,
        resourcePath: '/usb/print',
        vendorId: 0x03F0,
        productId: 0x4917,
      );

      final driver = PrinterDriverRegistry.resolveDriver(hpDevice);
      expect(driver, isNotNull);
      expect(driver, isA<HpLaserJetP1000Rasterizer>());
      expect(driver!.id, equals('driver.hp.laserjet.p1000'));
    });

    test(
        'resolves HpLaserJetP1000Rasterizer for HP LaserJet P1006 (0x03F0:0x3E17)',
        () {
      const hpDevice = PrinterDevice(
        id: 'usb-1006',
        name: 'HP LaserJet P1006',
        connectionType: PrinterConnectionType.usb,
        host: 'usb-1006',
        port: 0,
        resourcePath: '/usb/print',
        vendorId: 0x03F0,
        productId: 0x3E17,
      );

      final driver = PrinterDriverRegistry.resolveDriver(hpDevice);
      expect(driver, isNotNull);
      expect(driver, isA<HpLaserJetP1000Rasterizer>());
    });

    test(
        'resolves HpLaserJetP1000Rasterizer for HP LaserJet M1005 MFP (0x03F0:0x3B17)',
        () {
      const hpDevice = PrinterDevice(
        id: 'usb-m1005',
        name: 'HP LaserJet M1005 MFP',
        connectionType: PrinterConnectionType.usb,
        host: 'usb-m1005',
        port: 0,
        resourcePath: '/usb/print',
        vendorId: 0x03F0,
        productId: 0x3B17,
      );

      final driver = PrinterDriverRegistry.resolveDriver(hpDevice);
      expect(driver, isNotNull);
      expect(driver, isA<HpLaserJetP1000Rasterizer>());
      expect(driver!.displayName, contains('M1005'));
    });

    test(
        'resolves HpLaserJetP1000Rasterizer for HP LaserJet P1005 (0x03F0:0x3D17)',
        () {
      const hpDevice = PrinterDevice(
        id: 'usb-p1005',
        name: 'HP LaserJet P1005',
        connectionType: PrinterConnectionType.usb,
        host: 'usb-p1005',
        port: 0,
        resourcePath: '/usb/print',
        vendorId: 0x03F0,
        productId: 0x3D17,
      );

      final driver = PrinterDriverRegistry.resolveDriver(hpDevice);
      expect(driver, isNotNull);
      expect(driver, isA<HpLaserJetP1000Rasterizer>());
    });

    test(
        'returns null when printer is unknown raw protocol to ensure hardware safety',
        () {
      const unknownDevice = PrinterDevice(
        id: 'usb-4',
        name: 'Generic Unknown Hardware',
        connectionType: PrinterConnectionType.usb,
        host: 'usb-4',
        port: 0,
        resourcePath: '/usb/print',
      );

      final driver = PrinterDriverRegistry.resolveDriver(unknownDevice);
      expect(driver, isNull);
    });
  });

  group('Brother PJL Stream Generation Tests', () {
    const rasterizer = BrotherPjlRasterizer();
    const settings = PrintSettings(
      paperSize: 'iso_a4_210x297mm',
      copies: 1,
      duplexMode: DuplexMode.oneSided,
      color: false,
    );

    test('generates valid PJL sync and enter language header', () {
      final headerBytes = rasterizer.createJobHeader(settings, 'TestDocument');
      final headerString = String.fromCharCodes(headerBytes);

      expect(headerString, contains('@PJL JOB NAME="TestDocument"\n'));
      expect(headerString, contains('\x1B%-12345X@PJL\n'));
    });

    test('encodes monochrome page into brlaser delta compression bands', () {
      const width = 2480;
      const height = 64; // Exactly one 64-line band
      const linesize = (width + 7) ~/ 8;
      final dummyPixels =
          Uint8List(linesize * height); // Blank / all-white page

      final pageBytes = rasterizer.encodePage(
        pixelBytes: dummyPixels,
        widthPixels: width,
        heightPixels: height,
        linesize: linesize,
        settings: settings,
        pageIndex: 0,
        totalPages: 1,
      );

      expect(pageBytes, isNotEmpty);
      final pageString = String.fromCharCodes(pageBytes);
      expect(pageString, contains('@PJL SET RESOLUTION = 600\n'));
      expect(pageString, contains('@PJL ENTER LANGUAGE = PCL\n'));
      expect(pageString, contains('\x1B*b1030m'));
      expect(pageBytes.last, equals(0x0C)); // Form Feed \f
    });

    test('generates PJL termination footer', () {
      final footerBytes = rasterizer.createJobFooter('TestDocument');
      final footerString = String.fromCharCodes(footerBytes);

      expect(footerString, contains('@PJL EOJ NAME="TestDocument"'));
      expect(footerString, contains('\x1B%-12345X'));
    });
  });

  group('HP LaserJet P1000 XQX Stream & JBIG Tests', () {
    const rasterizer = HpLaserJetP1000Rasterizer();
    const settings = PrintSettings(
      paperSize: 'iso_a4_210x297mm',
      copies: 1,
      duplexMode: DuplexMode.oneSided,
      color: false,
    );

    test('generates valid XQX PJL header, ,XQX magic and START_DOC record', () {
      final headerBytes = rasterizer.createJobHeader(settings, 'HpTestDoc');
      final headerString = String.fromCharCodes(headerBytes);

      expect(headerString, contains('@PJL JOB\n'));
      expect(headerString, contains('@PJL SET JAMRECOVERY=OFF\n'));
      expect(headerString, contains('@PJL SET DENSITY=5\n'));
      expect(headerString, contains('@PJL SET ECONOMODE=OFF\n'));
      expect(headerString, contains('@PJL SET RET=DARK\n'));
      expect(headerString, contains(',XQX'));

      // Check START_DOC record type (1) Big Endian: [0, 0, 0, 1]
      final magicPos = headerBytes.indexOf(0x2C); // ',' in ',XQX'
      expect(magicPos, isNonNegative);
      final startDocOffset = magicPos + 4;
      expect(headerBytes.sublist(startDocOffset, startDocOffset + 4),
          equals([0, 0, 0, 1])); // Record Type 1 (START_DOC)
      expect(headerBytes.sublist(startDocOffset + 4, startDocOffset + 8),
          equals([0, 0, 0, 7])); // 7 items
    });

    test('encodes monochrome page into valid XQX records with JBIG payload',
        () {
      const width = 640;
      const height = 128; // 1 stripe
      const linesize = width ~/ 8;
      final testPixels = Uint8List(linesize * height);
      // Alternate rows with pattern
      for (int y = 0; y < height; y++) {
        final val = (y % 2 == 0) ? 0xAA : 0x55;
        for (int x = 0; x < linesize; x++) {
          testPixels[y * linesize + x] = val;
        }
      }

      final pageBytes = rasterizer.encodePage(
        pixelBytes: testPixels,
        widthPixels: width,
        heightPixels: height,
        linesize: linesize,
        settings: settings,
        pageIndex: 0,
        totalPages: 1,
      );

      expect(pageBytes, isNotEmpty);
      // First record in page must be START_PAGE (Type 3)
      final bd = ByteData.sublistView(Uint8List.fromList(pageBytes));
      expect(bd.getUint32(0, Endian.big), equals(3)); // Type 3 (START_PAGE)

      // Ensure JBIG record (Type 7) is present
      var foundJbig = false;
      var offset = 0;
      while (offset + 8 <= pageBytes.length) {
        final recType = bd.getUint32(offset, Endian.big);
        final count = bd.getUint32(offset + 4, Endian.big);
        offset += 8;
        if (recType == 7) {
          foundJbig = true;
          expect(count, isPositive);
          break;
        } else if (recType == 1 || recType == 3 || recType == 5) {
          for (int i = 0; i < count; i++) {
            final sz = bd.getUint32(offset + 4, Endian.big);
            offset += 8 + sz;
          }
        }
      }
      expect(foundJbig, isTrue);
    });

    test('generates valid XQX END_DOC and PJL EOJ trailer', () {
      final footerBytes = rasterizer.createJobFooter('HpTestDoc');
      final footerString = String.fromCharCodes(footerBytes);

      // Record type 2 (END_DOC)
      expect(footerBytes.sublist(0, 4), equals([0, 0, 0, 2]));
      expect(footerBytes.sublist(4, 8), equals([0, 0, 0, 0]));
      expect(footerString, contains('\x1B%-12345X@PJL EOJ\n\x1B%-12345X'));
    });

    test('JbigBilevelEncoder generates valid 20-byte BIH and compressed stream',
        () {
      const width = 128;
      const height = 16;
      final testBitmap = Uint8List((width ~/ 8) * height);
      for (int i = 0; i < testBitmap.length; i++) {
        testBitmap[i] = (i % 2 == 0) ? 0xAA : 0x55;
      }

      final encoded = JbigBilevelEncoder.encode(
        width: width,
        height: height,
        bitmap: testBitmap,
      );

      expect(encoded.bih.length, equals(20));
      expect(encoded.bih[0], equals(0)); // DL
      expect(encoded.bih[1], equals(0)); // D
      expect(encoded.bih[2], equals(1)); // P
      expect(encoded.bih[18], equals(3)); // Order
      expect(encoded.bih[19], equals(0x40)); // Options: JBG_LRLTWO
      expect(encoded.payload, isNotEmpty);
      // Last two bytes of JBIG payload must be SDNORM marker [0xFF, 0x02]
      expect(encoded.payload[encoded.payload.length - 2], equals(0xFF));
      expect(encoded.payload[encoded.payload.length - 1], equals(0x02));
    });
  });

  group('Comprehensive Print Settings Tests across Drivers & Rasterizer Engine',
      () {
    const rasterEngine = DocumentRasterizerEngine();
    const hpRasterizer = HpLaserJetP1000Rasterizer();
    const brotherRasterizer = BrotherPjlRasterizer();
    const pclRasterizer = StandardPclRasterizer();

    test('Print Settings: copies', () {
      const settings1 = PrintSettings(copies: 1);
      const settings3 = PrintSettings(copies: 3);

      final hpPjl1 =
          String.fromCharCodes(hpRasterizer.createJobHeader(settings1, 'doc'));
      final hpPjl3 =
          String.fromCharCodes(hpRasterizer.createJobHeader(settings3, 'doc'));
      expect(hpPjl1, contains('@PJL SET COPIES=1'));
      expect(hpPjl3, contains('@PJL SET COPIES=3'));

      final pcl1 =
          String.fromCharCodes(pclRasterizer.createJobHeader(settings1, 'doc'));
      final pcl3 =
          String.fromCharCodes(pclRasterizer.createJobHeader(settings3, 'doc'));
      expect(pcl1, contains('\x1B&l1X'));
      expect(pcl3, contains('\x1B&l3X'));
    });

    test('Print Settings: quality (draft, normal, high)', () {
      const draftSettings = PrintSettings(quality: PrintQuality.draft);
      const normalSettings = PrintSettings(quality: PrintQuality.normal);
      const highSettings = PrintSettings(quality: PrintQuality.high);

      final draftPjl = String.fromCharCodes(
          hpRasterizer.createJobHeader(draftSettings, 'doc'));
      expect(draftPjl, contains('@PJL SET ECONOMODE=ON'));
      expect(draftPjl, contains('@PJL SET DENSITY=1'));
      expect(draftPjl, contains('@PJL SET RET=OFF'));

      final normalPjl = String.fromCharCodes(
          hpRasterizer.createJobHeader(normalSettings, 'doc'));
      expect(normalPjl, contains('@PJL SET ECONOMODE=OFF'));
      expect(normalPjl, contains('@PJL SET DENSITY=5'));

      final highPjl = String.fromCharCodes(
          hpRasterizer.createJobHeader(highSettings, 'doc'));
      expect(highPjl, contains('@PJL SET ECONOMODE=OFF'));
      expect(highPjl, contains('@PJL SET DENSITY=5'));
      expect(highPjl, contains('@PJL SET RET=DARK'));
    });

    test(
        'Print Settings: duplex and duplexMode (one-sided, long edge, short edge)',
        () {
      const oneSided =
          PrintSettings(duplex: false, duplexMode: DuplexMode.oneSided);
      const longEdge =
          PrintSettings(duplex: true, duplexMode: DuplexMode.longEdge);
      const shortEdge =
          PrintSettings(duplex: true, duplexMode: DuplexMode.shortEdge);

      // Brother PCL escape: 0S = Simplex, 2S = Long Edge, 1S = Short Edge
      final brotherPageOne = String.fromCharCodes(brotherRasterizer.encodePage(
        pixelBytes: Uint8List(100),
        widthPixels: 100,
        heightPixels: 1,
        linesize: 13,
        settings: oneSided,
        pageIndex: 0,
        totalPages: 1,
      ));
      expect(brotherPageOne, isNot(contains('\x1B&l2S')));
      expect(brotherPageOne, isNot(contains('\x1B&l1S')));

      final brotherPageLong = String.fromCharCodes(brotherRasterizer.encodePage(
        pixelBytes: Uint8List(100),
        widthPixels: 100,
        heightPixels: 1,
        linesize: 13,
        settings: longEdge,
        pageIndex: 0,
        totalPages: 1,
      ));
      expect(brotherPageLong, contains('\x1B&l2S'));

      final brotherPageShort =
          String.fromCharCodes(brotherRasterizer.encodePage(
        pixelBytes: Uint8List(100),
        widthPixels: 100,
        heightPixels: 1,
        linesize: 13,
        settings: shortEdge,
        pageIndex: 0,
        totalPages: 1,
      ));
      expect(brotherPageShort, contains('\x1B&l1S'));

      // Standard PCL
      final pclLong =
          String.fromCharCodes(pclRasterizer.createJobHeader(longEdge, 'doc'));
      final pclShort =
          String.fromCharCodes(pclRasterizer.createJobHeader(shortEdge, 'doc'));
      expect(pclLong, contains('\x1B&l2S'));
      expect(pclShort, contains('\x1B&l1S'));
    });

    test('Print Settings: paperSize and paperGeometry mapping', () {
      final a4 = DocumentRasterizerEngine.getPaperGeometry('iso_a4_210x297mm');
      expect(a4.printableWidth, equals(4784));
      expect(a4.printableHeight, equals(6848));

      final letter =
          DocumentRasterizerEngine.getPaperGeometry('na_letter_8.5x11in');
      expect(letter.printableWidth, equals(4924));
      expect(letter.printableHeight, equals(6432));

      final legal =
          DocumentRasterizerEngine.getPaperGeometry('na_legal_8.5x14in');
      expect(legal.printableWidth, equals(4924));
      expect(legal.printableHeight, equals(8208));

      final a5 = DocumentRasterizerEngine.getPaperGeometry('iso_a5_148x210mm');
      expect(a5.printableWidth, equals(3304));
      expect(a5.printableHeight, equals(4768));

      final b5 = DocumentRasterizerEngine.getPaperGeometry('b5');
      expect(b5.printableWidth, equals(4107));
      expect(b5.printableHeight, equals(5878));

      final exec = DocumentRasterizerEngine.getPaperGeometry('executive');
      expect(exec.printableWidth, equals(4158));
      expect(exec.printableHeight, equals(6108));
    });

    test('Print Settings: pageSelectionMode and custom range parsing', () {
      const allMode = PrintSettings(pageSelectionMode: PageSelectionMode.all);
      const oddMode =
          PrintSettings(pageSelectionMode: PageSelectionMode.oddOnly);
      const evenMode =
          PrintSettings(pageSelectionMode: PageSelectionMode.evenOnly);
      const customMode = PrintSettings(
        pageSelectionMode: PageSelectionMode.custom,
        customPageRange: '1-3, 5, 8-10',
      );

      expect(DocumentRasterizerEngine.resolvePageList(allMode, 10),
          equals([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]));
      expect(DocumentRasterizerEngine.resolvePageList(oddMode, 10),
          equals([1, 3, 5, 7, 9]));
      expect(DocumentRasterizerEngine.resolvePageList(evenMode, 10),
          equals([2, 4, 6, 8, 10]));
      expect(DocumentRasterizerEngine.resolvePageList(customMode, 10),
          equals([1, 2, 3, 5, 8, 9, 10]));
    });

    test('Print Settings: pagesPerSheet (1-Up, 2-Up, 4-Up partition logic)',
        () {
      expect(PagesPerSheet.one.count, equals(1));
      expect(PagesPerSheet.two.count, equals(2));
      expect(PagesPerSheet.four.count, equals(4));

      // With 5 total pages:
      // 1-Up -> 5 sheets
      expect((5 + 1 - 1) ~/ 1, equals(5));
      // 2-Up -> 3 sheets
      expect((5 + 2 - 1) ~/ 2, equals(3));
      // 4-Up -> 2 sheets
      expect((5 + 4 - 1) ~/ 4, equals(2));
    });

    test('End-to-End Rasterization with test image and HP LaserJet P1008',
        () async {
      // Create a temporary 100x100 test PNG image
      final imgObj = img.Image(width: 100, height: 100);
      img.fill(imgObj,
          color: img.ColorRgba8(0, 0, 0, 255)); // solid black square
      final pngBytes = img.encodePng(imgObj);

      final tempDir = Directory.systemTemp;
      final tempFile = File(
          '${tempDir.path}/test_print_square_${DateTime.now().microsecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(pngBytes);

      try {
        const hpDevice = PrinterDevice(
          id: 'usb-p1008',
          name: 'HP LaserJet P1008',
          connectionType: PrinterConnectionType.usb,
          host: 'usb-p1008',
          port: 0,
          resourcePath: '/usb/print',
          vendorId: 0x03F0,
          productId: 0x4917,
        );

        // Test 1: Portrait Normal Quality
        final portraitBytes = await rasterEngine.rasterizeDocument(
          filePath: tempFile.path,
          mimeType: 'image/png',
          settings: const PrintSettings(
            paperSize: 'iso_a4_210x297mm',
            landscape: false,
            quality: PrintQuality.normal,
            copies: 1,
          ),
          device: hpDevice,
          jobName: 'PortraitJob',
        );

        expect(portraitBytes, isNotEmpty);
        expect(portraitBytes.sublist(0, 4), equals(utf8.encode('\x1B%-1')));
        expect(String.fromCharCodes(portraitBytes),
            contains('@PJL SET DENSITY=5'));
        expect(String.fromCharCodes(portraitBytes),
            contains('@PJL SET ECONOMODE=OFF'));
        expect(String.fromCharCodes(portraitBytes), contains('@PJL EOJ'));

        // Test 2: Landscape High Quality
        final landscapeBytes = await rasterEngine.rasterizeDocument(
          filePath: tempFile.path,
          mimeType: 'image/png',
          settings: const PrintSettings(
            paperSize: 'iso_a4_210x297mm',
            landscape: true,
            quality: PrintQuality.high,
            copies: 2,
          ),
          device: hpDevice,
          jobName: 'LandscapeJob',
        );

        expect(landscapeBytes, isNotEmpty);
        expect(String.fromCharCodes(landscapeBytes),
            contains('@PJL SET COPIES=2'));
        expect(String.fromCharCodes(landscapeBytes),
            contains('@PJL SET RET=DARK'));

        // Test 3: Draft Mode with EconoMode
        final draftBytes = await rasterEngine.rasterizeDocument(
          filePath: tempFile.path,
          mimeType: 'image/png',
          settings: const PrintSettings(
            paperSize: 'iso_a4_210x297mm',
            quality: PrintQuality.draft,
          ),
          device: hpDevice,
          jobName: 'DraftJob',
        );

        expect(draftBytes, isNotEmpty);
        expect(String.fromCharCodes(draftBytes),
            contains('@PJL SET ECONOMODE=ON'));
        expect(
            String.fromCharCodes(draftBytes), contains('@PJL SET DENSITY=1'));

        // Test 4: 2-Up Pages Per Sheet
        final twoUpBytes = await rasterEngine.rasterizeDocument(
          filePath: tempFile.path,
          mimeType: 'image/png',
          settings: const PrintSettings(
            paperSize: 'iso_a4_210x297mm',
            pagesPerSheet: PagesPerSheet.two,
          ),
          device: hpDevice,
          jobName: 'TwoUpJob',
        );

        expect(twoUpBytes, isNotEmpty);
      } finally {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    });

    test('Epson ESC/P-R rasterization produces valid ESC commands and graphics',
        () async {
      final imgObj = img.Image(width: 200, height: 200);
      img.fill(imgObj, color: img.ColorRgba8(255, 255, 255, 255));
      img.fillRect(imgObj,
          x1: 40,
          y1: 40,
          x2: 160,
          y2: 160,
          color: img.ColorRgba8(0, 0, 0, 255));
      final pngData = img.encodePng(imgObj);

      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/test_epson_raster.png');
      await tempFile.writeAsBytes(pngData);

      try {
        const epsonDevice = PrinterDevice(
          id: 'usb-epson-test',
          name: 'Epson EcoTank L3250',
          connectionType: PrinterConnectionType.usb,
          host: 'usb',
          port: 0,
          resourcePath: '/usb/print',
          vendorId: 0x04B8,
        );

        const rasterEngine = DocumentRasterizerEngine();
        final bytes = await rasterEngine.rasterizeDocument(
          filePath: tempFile.path,
          mimeType: 'image/png',
          settings: const PrintSettings(
            paperSize: 'iso_a4_210x297mm',
            copies: 1,
          ),
          device: epsonDevice,
          jobName: 'EpsonTest',
        );

        expect(bytes, isNotEmpty);
        // ESC @ reset (0x1B, 0x40)
        expect(bytes.sublist(0, 2), equals([0x1B, 0x40]));
        // Form feed at end (0x0C)
        expect(bytes.contains(0x0C), isTrue);
      } finally {
        if (await tempFile.exists()) await tempFile.delete();
      }
    });

    test('Samsung SPL rasterization produces valid PJL & QPDL records',
        () async {
      final imgObj = img.Image(width: 200, height: 200);
      img.fill(imgObj, color: img.ColorRgba8(255, 255, 255, 255));
      img.fillRect(imgObj,
          x1: 20,
          y1: 20,
          x2: 180,
          y2: 180,
          color: img.ColorRgba8(0, 0, 0, 255));
      final pngData = img.encodePng(imgObj);

      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/test_samsung_raster.png');
      await tempFile.writeAsBytes(pngData);

      try {
        const samsungDevice = PrinterDevice(
          id: 'usb-samsung-test',
          name: 'Samsung ML-2165',
          connectionType: PrinterConnectionType.usb,
          host: 'usb',
          port: 0,
          resourcePath: '/usb/print',
          vendorId: 0x04E8,
        );

        const rasterEngine = DocumentRasterizerEngine();
        final bytes = await rasterEngine.rasterizeDocument(
          filePath: tempFile.path,
          mimeType: 'image/png',
          settings: const PrintSettings(
            paperSize: 'iso_a4_210x297mm',
            copies: 2,
          ),
          device: samsungDevice,
          jobName: 'SamsungTest',
        );

        expect(bytes, isNotEmpty);
        final text = String.fromCharCodes(bytes);
        expect(text, contains('@PJL ENTER LANGUAGE = QPDL'));
        expect(text, contains('@PJL SET COPIES = 2'));
        expect(text, contains('@PJL EOJ'));
      } finally {
        if (await tempFile.exists()) await tempFile.delete();
      }
    });

    test('PWG Raster generates valid RaS2 magic header for IPP-over-USB',
        () async {
      final imgObj = img.Image(width: 100, height: 100);
      img.fill(imgObj, color: img.ColorRgba8(255, 255, 255, 255));
      final pngData = img.encodePng(imgObj);

      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/test_pwg_raster.png');
      await tempFile.writeAsBytes(pngData);

      try {
        const pwgDevice = PrinterDevice(
          id: 'usb-pwg-test',
          name: 'Mopria Printer',
          connectionType: PrinterConnectionType.usb,
          host: 'usb',
          port: 0,
          resourcePath: '/usb/print',
          isIppOverUsb: true,
        );

        const rasterEngine = DocumentRasterizerEngine();
        final bytes = await rasterEngine.rasterizeDocument(
          filePath: tempFile.path,
          mimeType: 'image/png',
          settings: const PrintSettings(
            paperSize: 'iso_a4_210x297mm',
          ),
          device: pwgDevice,
          jobName: 'PwgTest',
        );

        expect(bytes, isNotEmpty);
        // "RaS2" magic
        expect(bytes.sublist(0, 4), equals([0x52, 0x61, 0x53, 0x32]));
      } finally {
        if (await tempFile.exists()) await tempFile.delete();
      }
    });

    test('TSPL rasterization produces valid SIZE and BITMAP commands',
        () async {
      final imgObj = img.Image(width: 100, height: 100);
      img.fill(imgObj, color: img.ColorRgba8(255, 255, 255, 255));
      final pngData = img.encodePng(imgObj);

      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/test_tspl_raster.png');
      await tempFile.writeAsBytes(pngData);

      try {
        const tsplDevice = PrinterDevice(
          id: 'usb-tspl-test',
          name: 'Munbyn Thermal Label Printer',
          connectionType: PrinterConnectionType.usb,
          host: 'usb',
          port: 0,
          resourcePath: '/usb/print',
        );

        const rasterEngine = DocumentRasterizerEngine();
        final bytes = await rasterEngine.rasterizeDocument(
          filePath: tempFile.path,
          mimeType: 'image/png',
          settings: const PrintSettings(
            paperSize: 'na_index-4x6_4x6in',
            copies: 1,
          ),
          device: tsplDevice,
          jobName: 'TsplTest',
        );

        expect(bytes, isNotEmpty);
        final text = String.fromCharCodes(bytes);
        expect(text, contains('SIZE 4.0,6.0'));
        expect(text, contains('BITMAP'));
        expect(text, contains('PRINT 1,1'));
      } finally {
        if (await tempFile.exists()) await tempFile.delete();
      }
    });
  });
}
