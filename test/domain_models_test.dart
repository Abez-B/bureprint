import 'package:flutter_test/flutter_test.dart';

import 'package:bureprint/domain/models/print_job.dart';
import 'package:bureprint/domain/models/print_request.dart';
import 'package:bureprint/domain/models/printer_capabilities.dart';
import 'package:bureprint/domain/models/printer_device.dart';

void main() {
  group('PrintJob domain model', () {
    test(
        'supports full lifecycle state transitions, copyWith and serialization',
        () {
      final now = DateTime.now();
      final job = PrintJob(
        id: 'job-101',
        name: 'Report.pdf',
        status: PrintJobStatus.queuedLocally,
        printerId: 'printer-hp-1',
        printerName: 'HP LaserJet Pro',
        createdAt: now,
        copies: 2,
      );

      expect(job.status.isActive, isTrue);
      expect(job.status.isTerminal, isFalse);

      final updatedJob = job.copyWith(
        status: PrintJobStatus.completed,
        sheetsCompleted: 2,
      );

      expect(updatedJob.status, equals(PrintJobStatus.completed));
      expect(updatedJob.status.isTerminal, isTrue);
      expect(updatedJob.sheetsCompleted, equals(2));

      // Test JSON round-trip
      final json = updatedJob.toJson();
      final restored = PrintJob.fromJson(json);
      expect(restored, equals(updatedJob));
    });
  });

  group('PrinterDevice domain model', () {
    test('builds correct endpoint URI based on transport security policy', () {
      const printerTls = PrinterDevice(
        id: 'printer-1',
        name: 'Office Printer',
        connectionType: PrinterConnectionType.network,
        host: '192.168.1.100',
        port: 631,
        resourcePath: '/ipp/print',
        securityPolicy: TransportSecurityPolicy.ippsStrict,
      );

      expect(
          printerTls.endpointUri, equals('ipps://192.168.1.100:631/ipp/print'));

      final printerHttp = printerTls.copyWith(
        securityPolicy: TransportSecurityPolicy.plainIppExplicit,
      );
      expect(
          printerHttp.endpointUri, equals('ipp://192.168.1.100:631/ipp/print'));

      // Test JSON round-trip
      final json = printerTls.toJson();
      final restored = PrinterDevice.fromJson(json);
      expect(restored, equals(printerTls));
    });
  });

  group('PrinterCapabilities domain model', () {
    test('correctly evaluates operation and format support predicates', () {
      const capabilities = PrinterCapabilities(
        printerName: 'Canon Maxify',
        operationsSupported: [
          0x0002,
          0x0005,
          0x0006
        ], // Print-Job, Create-Job, Send-Document
        documentFormats: ['application/pdf', 'image/pwg-raster'],
      );

      expect(capabilities.supportsTwoStepJob, isTrue);
      expect(capabilities.supportsPrintJob, isTrue);
      expect(capabilities.supportsPdf, isTrue);
      expect(capabilities.supportsPwgRaster, isTrue);

      const legacyCapabilities = PrinterCapabilities(
        operationsSupported: [0x0002], // Print-Job only
        documentFormats: ['image/pwg-raster'],
      );

      expect(legacyCapabilities.supportsTwoStepJob, isFalse);
      expect(legacyCapabilities.supportsPrintJob, isTrue);
      expect(legacyCapabilities.supportsPdf, isFalse);
      expect(legacyCapabilities.supportsPwgRaster, isTrue);

      // Test JSON round-trip
      final json = capabilities.toJson();
      final restored = PrinterCapabilities.fromJson(json);
      expect(restored, equals(capabilities));
    });

    test('supports marker supplies parsing, serialization and equality', () {
      const supplyBlack = PrinterSupplyLevel(
        name: 'black toner cartridge',
        colorHex: '#000000',
        levelPercent: 78,
        type: 'toner',
      );
      const supplyCyan = PrinterSupplyLevel(
        name: 'cyan toner cartridge',
        colorHex: '#00FFFF',
        levelPercent: 42,
        type: 'toner',
      );

      const capsWithSupplies = PrinterCapabilities(
        printerName: 'LaserJet Color',
        markerSupplies: [supplyBlack, supplyCyan],
      );

      expect(capsWithSupplies.markerSupplies.length, equals(2));
      expect(capsWithSupplies.markerSupplies.first.name,
          equals('black toner cartridge'));
      expect(capsWithSupplies.markerSupplies.first.levelPercent, equals(78));

      final json = capsWithSupplies.toJson();
      final restored = PrinterCapabilities.fromJson(json);
      expect(restored, equals(capsWithSupplies));
      expect(restored.markerSupplies.first, equals(supplyBlack));
      expect(restored.markerSupplies.last, equals(supplyCyan));
    });
  });

  group('PrintSettings & PrintRequest domain models', () {
    test('supports immutability, copyWith and JSON serialization', () {
      const settings = PrintSettings(
        copies: 3,
        duplex: true,
        landscape: true,
        firstPage: 1,
        lastPage: 5,
        scalingFitToPage: true,
        pagesPerSheet: PagesPerSheet.two,
      );

      const request = PrintRequest(
        jobName: 'Financials.pdf',
        filePath: '/cache/docs/financials.pdf',
        mimeType: 'application/pdf',
        printerId: 'printer-1',
        settings: settings,
      );

      expect(request.settings.copies, equals(3));
      expect(request.settings.duplex, isTrue);
      expect(request.settings.pagesPerSheet, equals(PagesPerSheet.two));

      final json = request.toJson();
      final restored = PrintRequest.fromJson(json);
      expect(restored, equals(request));
    });

    test('PagesPerSheet enum provides correct counts and names', () {
      expect(PagesPerSheet.one.count, equals(1));
      expect(PagesPerSheet.two.count, equals(2));
      expect(PagesPerSheet.four.count, equals(4));
      expect(PagesPerSheet.two.displayName, contains('2-Up'));
    });

    test('PaperDimensions resolves correct aspect ratios and standard sizes',
        () {
      final a4 = PaperDimensions.fromPaperSize('iso_a4_210x297mm');
      expect(a4.widthMm, equals(210));
      expect(a4.heightMm, equals(297));
      expect(a4.portraitAspectRatio, closeTo(210 / 297, 0.001));
      expect(a4.landscapeAspectRatio, closeTo(297 / 210, 0.001));

      final letter = PaperDimensions.fromPaperSize('na_letter_8.5x11in');
      expect(letter.widthMm, equals(215.9));
      expect(letter.heightMm, equals(279.4));
      expect(letter.portraitAspectRatio, closeTo(215.9 / 279.4, 0.001));

      final photo4x6 = PaperDimensions.fromPaperSize('na_index-4x6_4x6in');
      expect(photo4x6.widthMm, equals(101.6));
      expect(photo4x6.heightMm, equals(152.4));
      expect(photo4x6.portraitAspectRatio, closeTo(101.6 / 152.4, 0.001));

      final legal = PaperDimensions.fromPaperSize('na_legal_8.5x14in');
      expect(legal.widthMm, equals(215.9));
      expect(legal.heightMm, equals(355.6));
    });
  });
}
