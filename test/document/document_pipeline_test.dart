import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:bureprint/core/document/document_pipeline_engine.dart';
import 'package:bureprint/core/document/temporary_document_manager.dart';
import 'package:bureprint/domain/models/imported_document.dart';
import 'package:bureprint/domain/models/print_request.dart';
import 'package:bureprint/domain/models/printer_capabilities.dart';

void main() {
  const engine = DocumentPipelineEngine();
  const tempManager = TemporaryDocumentManager();

  group('DocumentPipelineEngine Page Range Parsing & Filtering', () {
    test('expands empty string to all pages', () {
      final pages = engine.parsePageRanges('', 5);
      expect(pages, equals([1, 2, 3, 4, 5]));
    });

    test('parses comma-separated pages and ranges safely', () {
      final pages = engine.parsePageRanges('1-3, 5, 7-8', 10);
      expect(pages, equals([1, 2, 3, 5, 7, 8]));
    });

    test('ignores out-of-bounds or malformed range numbers', () {
      final pages = engine.parsePageRanges('0, 2-15, abc, 4', 5);
      // Valid pages within 1..5: 2, 3, 4, 5
      expect(pages, equals([2, 3, 4, 5]));
    });

    test('filters all pages correctly with PageSelectionMode.all', () {
      final pages = engine.filterPagesByMode(
        mode: PageSelectionMode.all,
        totalPages: 6,
      );
      expect(pages, equals([1, 2, 3, 4, 5, 6]));
    });

    test('filters odd pages only with PageSelectionMode.oddOnly', () {
      final pages = engine.filterPagesByMode(
        mode: PageSelectionMode.oddOnly,
        totalPages: 6,
      );
      expect(pages, equals([1, 3, 5]));
    });

    test('filters even pages only with PageSelectionMode.evenOnly', () {
      final pages = engine.filterPagesByMode(
        mode: PageSelectionMode.evenOnly,
        totalPages: 6,
      );
      expect(pages, equals([2, 4, 6]));
    });

    test('filters custom range correctly with PageSelectionMode.custom', () {
      final pages = engine.filterPagesByMode(
        mode: PageSelectionMode.custom,
        totalPages: 10,
        customRange: '1-3, 7, 9-10',
      );
      expect(pages, equals([1, 2, 3, 7, 9, 10]));
    });
  });

  group('DocumentPipelineEngine Format Negotiation', () {
    final pdfDoc = ImportedDocument(
      id: 'doc-1',
      name: 'Test.pdf',
      filePath: '/tmp/test.pdf',
      fileSizeBytes: 1024,
      mimeType: 'application/pdf',
      importedAt: DateTime.now(),
    );

    test('returns directPassThrough when printer advertises application/pdf',
        () {
      const capabilities = PrinterCapabilities(
        documentFormats: ['application/pdf', 'image/pwg-raster'],
      );
      final result = engine.negotiateFormat(
        document: pdfDoc,
        capabilities: capabilities,
      );
      expect(result.path, equals(DocumentFormatPath.directPassThrough));
      expect(result.targetMimeType, equals('application/pdf'));
    });

    test('returns rasterizationRequired when printer only supports PWG Raster',
        () {
      const capabilities = PrinterCapabilities(
        documentFormats: ['image/pwg-raster'],
      );
      final result = engine.negotiateFormat(
        document: pdfDoc,
        capabilities: capabilities,
      );
      expect(result.path, equals(DocumentFormatPath.rasterizationRequired));
      expect(result.targetMimeType, equals('image/pwg-raster'));
    });

    test('returns unsupported when printer neither supports PDF nor PWG Raster',
        () {
      const capabilities = PrinterCapabilities(
        documentFormats: ['text/plain'],
      );
      final result = engine.negotiateFormat(
        document: pdfDoc,
        capabilities: capabilities,
      );
      expect(result.path, equals(DocumentFormatPath.unsupported));
    });
  });

  group('TemporaryDocumentManager', () {
    test(
        'safely deletes existing temporary file and handles non-existent file gracefully',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('bureprint_test');
      final testFile = File('${tempDir.path}/scratch.tmp');
      await testFile.writeAsString('scratch bytes');

      expect(await testFile.exists(), isTrue);
      final deleted = await tempManager.deleteTemporaryFile(testFile.path);
      expect(deleted, isTrue);
      expect(await testFile.exists(), isFalse);

      final nonExistentDeleted =
          await tempManager.deleteTemporaryFile('${tempDir.path}/missing.tmp');
      expect(nonExistentDeleted, isFalse);

      await tempDir.delete(recursive: true);
    });
  });
}
