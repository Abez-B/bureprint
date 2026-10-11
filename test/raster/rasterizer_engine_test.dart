import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:bureprint/core/raster/drivers/brother_pjl_rasterizer.dart';
import 'package:bureprint/core/raster/drivers/standard_rasterizers.dart';
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
}
