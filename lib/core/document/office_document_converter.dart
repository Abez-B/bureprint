import 'dart:io';
import 'package:flutter/foundation.dart';

/// Universal service to convert office documents (.docx, .doc, .odt, .rtf, .txt)
/// into standard PDF files for local rendering, previewing, and printing.
class OfficeDocumentConverter {
  const OfficeDocumentConverter._();

  static const OfficeDocumentConverter instance = OfficeDocumentConverter._();

  /// Identifies whether a file is an office or text document that can be converted to PDF.
  static bool isConvertibleOfficeDocument(String path, [String? mimeType]) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.docx') ||
        lower.endsWith('.doc') ||
        lower.endsWith('.odt') ||
        lower.endsWith('.rtf') ||
        lower.endsWith('.txt')) {
      return true;
    }

    if (mimeType != null) {
      if (mimeType ==
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document' ||
          mimeType == 'application/msword' ||
          mimeType == 'application/vnd.oasis.opendocument.text' ||
          mimeType == 'application/rtf' ||
          mimeType == 'text/plain') {
        return true;
      }
    }

    return false;
  }

  /// Converts an office/text document to a temporary PDF file.
  /// Returns the path to the converted PDF file, or null if conversion failed.
  Future<String?> convertToPdf(String inputPath) async {
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) return null;

    final tempDir = Directory.systemTemp;
    final baseName = inputFile.uri.pathSegments.last.replaceAll(
      RegExp(r'\.(docx|doc|odt|rtf|txt)$', caseSensitive: false),
      '',
    );
    final outputPdfPath = '${tempDir.path}/${baseName}_converted.pdf';
    final outputPdfFile = File(outputPdfPath);

    // Reuse previously converted PDF if newer than the input file
    if (await outputPdfFile.exists()) {
      final inputMod = await inputFile.lastModified();
      final outputMod = await outputPdfFile.lastModified();
      if (outputMod.isAfter(inputMod)) {
        return outputPdfPath;
      }
    }

    // On Linux desktop, convert via headless LibreOffice
    if (!kIsWeb && Platform.isLinux) {
      try {
        final result = await Process.run('libreoffice', [
          '--headless',
          '--convert-to',
          'pdf',
          inputPath,
          '--outdir',
          tempDir.path,
        ]);

        if (result.exitCode == 0 && await outputPdfFile.exists()) {
          return outputPdfPath;
        }

        // Check if libreoffice created a file with a slightly different name pattern
        final expectedFile = File('${tempDir.path}/$baseName.pdf');
        if (await expectedFile.exists()) {
          if (expectedFile.path != outputPdfPath) {
            await expectedFile.copy(outputPdfPath);
          }
          return outputPdfPath;
        }
      } catch (e) {
        debugPrint('OfficeDocumentConverter Linux error: $e');
      }
    }

    return null;
  }
}
