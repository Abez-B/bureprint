import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdfx/pdfx.dart';

import 'office_document_converter.dart';

/// Cross-platform PDF page rendering service.
/// Automatically uses native platform renderers (Android/macOS/iOS/Windows/Web via pdfx)
/// and seamlessly falls back to local tools (`pdftoppm` / `pdfinfo`) on Linux Desktop.
class UniversalPdfRenderer {
  UniversalPdfRenderer._();

  static final UniversalPdfRenderer instance = UniversalPdfRenderer._();

  /// Gets the total number of pages in the PDF file.
  /// Gets the total number of pages in the PDF/DOCX file.
  Future<int> getPageCount(String filePath) async {
    String resolvedPath = filePath;
    if (OfficeDocumentConverter.isConvertibleOfficeDocument(filePath)) {
      final converted =
          await OfficeDocumentConverter.instance.convertToPdf(filePath);
      if (converted != null) resolvedPath = converted;
    }

    final file = File(resolvedPath);
    if (!await file.exists()) {
      throw FileSystemException('Document file not found', resolvedPath);
    }

    if (!kIsWeb && Platform.isLinux) {
      return _getLinuxPageCount(resolvedPath);
    }

    // Android, macOS, iOS, Windows, Web
    PdfDocument? doc;
    try {
      doc = await PdfDocument.openFile(resolvedPath);
      return doc.pagesCount;
    } finally {
      await doc?.close();
    }
  }

  /// Renders a specific page (1-based index) as PNG image bytes.
  Future<Uint8List?> renderPageImage({
    required String filePath,
    required int pageNumber,
    int dpi = 150,
  }) async {
    String resolvedPath = filePath;
    if (OfficeDocumentConverter.isConvertibleOfficeDocument(filePath)) {
      final converted =
          await OfficeDocumentConverter.instance.convertToPdf(filePath);
      if (converted != null) resolvedPath = converted;
    }

    final file = File(resolvedPath);
    if (!await file.exists()) {
      throw FileSystemException('Document file not found', resolvedPath);
    }

    if (!kIsWeb && Platform.isLinux) {
      return _renderLinuxPage(resolvedPath, pageNumber, dpi);
    }

    // Android, macOS, iOS, Windows, Web
    PdfDocument? doc;
    try {
      doc = await PdfDocument.openFile(resolvedPath);
      final page = await doc.getPage(pageNumber);
      final pageImage = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: PdfPageImageFormat.png,
      );
      await page.close();
      return pageImage?.bytes;
    } finally {
      await doc?.close();
    }
  }

  Future<int> _getLinuxPageCount(String filePath) async {
    try {
      final result = await Process.run('pdfinfo', [filePath]);
      if (result.exitCode == 0) {
        final lines = (result.stdout as String).split('\n');
        for (final line in lines) {
          if (line.startsWith('Pages:')) {
            final countStr = line.replaceFirst('Pages:', '').trim();
            final count = int.tryParse(countStr);
            if (count != null && count > 0) return count;
          }
        }
      }
    } catch (_) {
      // Ignore and fallback
    }
    return 1;
  }

  Future<Uint8List?> _renderLinuxPage(
      String filePath, int pageNumber, int dpi) async {
    final tempDir = Directory.systemTemp;
    final prefix =
        '${tempDir.path}/bureprint_preview_${DateTime.now().microsecondsSinceEpoch}';

    try {
      final result = await Process.run('pdftoppm', [
        '-png',
        '-r',
        '$dpi',
        '-f',
        '$pageNumber',
        '-l',
        '$pageNumber',
        filePath,
        prefix,
      ]);

      if (result.exitCode == 0) {
        // Output file naming: pdftoppm appends -<pageNumber>.png (or -01.png etc.)
        final dir = Directory(tempDir.path);
        final generatedFiles = dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.startsWith(prefix) && f.path.endsWith('.png'))
            .toList();

        if (generatedFiles.isNotEmpty) {
          final targetFile = generatedFiles.first;
          final bytes = await targetFile.readAsBytes();
          // Clean up generated preview file immediately
          try {
            await targetFile.delete();
          } catch (_) {}
          return bytes;
        }
      }
    } catch (e) {
      debugPrint('Linux PDF render fallback error: $e');
    }
    return null;
  }
}
