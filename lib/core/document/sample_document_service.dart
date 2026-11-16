import 'dart:io';
import 'package:flutter/services.dart';

import '../../domain/models/imported_document.dart';
import 'universal_pdf_renderer.dart';

/// Service responsible for loading and provisioning pre-configured
/// printer diagnostic and test documents without external dependencies.
class SampleDocumentService {
  const SampleDocumentService();

  static const String sampleAssetPath =
      'assets/samples/bureprint_test_page.pdf';

  /// Loads the bundled diagnostic test sheet PDF, extracts it to the local cache,
  /// and returns an [ImportedDocument] ready for immediate rendering and printing.
  Future<ImportedDocument> loadSampleTestPage() async {
    final byteData = await rootBundle.load(sampleAssetPath);
    final buffer = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );

    final tempDir = Directory.systemTemp;
    final targetPath = '${tempDir.path}/bureprint_diagnostic_test_page.pdf';
    final targetFile = File(targetPath);
    await targetFile.writeAsBytes(buffer, flush: true);

    int pageCount = 1;
    try {
      pageCount =
          await UniversalPdfRenderer.instance.getPageCount(targetFile.path);
    } catch (_) {
      pageCount = 1;
    }

    final fileSize = await targetFile.length();

    return ImportedDocument(
      id: 'bureprint-sample-test-page',
      name: 'BurePrint_Diagnostic_Test_Sheet.pdf',
      filePath: targetFile.path,
      fileSizeBytes: fileSize,
      mimeType: 'application/pdf',
      importedAt: DateTime.now(),
      pageCount: pageCount,
    );
  }
}
