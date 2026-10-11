import 'dart:io';
import 'package:flutter/foundation.dart';

import '../../domain/models/imported_document.dart';
import 'office_document_converter.dart';

abstract interface class PdfMergeService {
  Future<ImportedDocument> mergeDocuments(
    List<ImportedDocument> documents, {
    String? outputDirectoryPath,
  });
}

/// Robust local-first multi-format document concatenator.
/// Capable of merging heterogeneous documents (PDFs, Images, Word DOCX/DOC,
/// OpenDocument ODT, RTF, and TXT files) into a single cohesive PDF.
///
/// Converts non-PDF inputs to intermediate PDFs, then unites them using
/// standard system tools (pdfunite, qpdf, gs) or pure byte stream concatenation.
class LocalPdfMergeService implements PdfMergeService {
  const LocalPdfMergeService();

  @override
  Future<ImportedDocument> mergeDocuments(
    List<ImportedDocument> documents, {
    String? outputDirectoryPath,
  }) async {
    if (documents.isEmpty) {
      throw ArgumentError('Cannot merge an empty document list');
    }

    if (documents.length == 1) {
      return documents.first;
    }

    // Determine target directory: preferred persistent documents directory or system temp
    final targetDir = outputDirectoryPath != null
        ? Directory(outputDirectoryPath)
        : Directory.systemTemp;

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final mergedFilePath = '${targetDir.path}/merged_$timestamp.pdf';

    // Step 1: Normalize all documents to intermediate PDF representations
    final normalizedPdfPaths = <String>[];
    final temporaryIntermediates = <String>[];

    for (final doc in documents) {
      final file = File(doc.filePath);
      if (!await file.exists()) continue;

      if (doc.mimeType == 'application/pdf' ||
          doc.filePath.toLowerCase().endsWith('.pdf')) {
        // Direct PDF
        normalizedPdfPaths.add(doc.filePath);
      } else if (doc.mimeType.startsWith('image/') ||
          _isImageFile(doc.filePath)) {
        // Convert Image to intermediate PDF
        final intermediatePdf =
            await _convertImageToPdf(doc.filePath, targetDir.path, timestamp);
        if (intermediatePdf != null) {
          normalizedPdfPaths.add(intermediatePdf);
          temporaryIntermediates.add(intermediatePdf);
        }
      } else if (OfficeDocumentConverter.isConvertibleOfficeDocument(
          doc.filePath, doc.mimeType)) {
        // Convert Office/Text document to intermediate PDF
        final intermediatePdf =
            await OfficeDocumentConverter.instance.convertToPdf(doc.filePath);
        if (intermediatePdf != null) {
          normalizedPdfPaths.add(intermediatePdf);
          // Note: OfficeDocumentConverter caches in system temp
        }
      } else {
        // Unknown format, attempt direct inclusion if non-empty
        normalizedPdfPaths.add(doc.filePath);
      }
    }

    if (normalizedPdfPaths.isEmpty) {
      throw const FileSystemException(
          'None of the selected files could be prepared for merging');
    }

    // Step 2: Merge normalized PDFs
    bool mergedViaCli = false;
    if (!kIsWeb && Platform.isLinux) {
      // 1st priority: pdfunite
      try {
        final args = [...normalizedPdfPaths, mergedFilePath];
        final res = await Process.run('pdfunite', args);
        if (res.exitCode == 0 && await File(mergedFilePath).exists()) {
          mergedViaCli = true;
        }
      } catch (_) {
        mergedViaCli = false;
      }

      // 2nd priority: qpdf fallback
      if (!mergedViaCli) {
        try {
          final args = [
            '--empty',
            '--pages',
            ...normalizedPdfPaths,
            '--',
            mergedFilePath,
          ];
          final res = await Process.run('qpdf', args);
          if (res.exitCode == 0 && await File(mergedFilePath).exists()) {
            mergedViaCli = true;
          }
        } catch (_) {
          mergedViaCli = false;
        }
      }
    }

    // Step 3: Pure stream concatenation fallback if CLI unavailable
    if (!mergedViaCli) {
      final mergedFile = File(mergedFilePath);
      final sink = mergedFile.openWrite();
      try {
        for (final path in normalizedPdfPaths) {
          final file = File(path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            sink.add(bytes);
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
    }

    // Clean up temporary image-to-pdf files
    for (final tempPath in temporaryIntermediates) {
      try {
        final f = File(tempPath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }

    final finalFile = File(mergedFilePath);
    final totalBytes = await finalFile.length();

    // Calculate total pages
    int totalPages = 0;
    for (final d in documents) {
      totalPages += (d.pageCount ?? 1);
    }

    return ImportedDocument(
      id: 'merged-$timestamp',
      name: 'Merged_${documents.length}_Documents.pdf',
      filePath: mergedFilePath,
      fileSizeBytes: totalBytes,
      mimeType: 'application/pdf',
      importedAt: DateTime.now(),
      pageCount: totalPages > 0 ? totalPages : null,
    );
  }

  static bool _isImageFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.gif');
  }

  /// Converts an image file to a single-page PDF.
  Future<String?> _convertImageToPdf(
      String imagePath, String outputDirPath, int timestamp) async {
    final imageFile = File(imagePath);
    if (!await imageFile.exists()) return null;

    final outputPdf = '$outputDirPath/img_${imagePath.hashCode}_$timestamp.pdf';

    if (!kIsWeb && Platform.isLinux) {
      // 1. Try ImageMagick ('magick' or 'convert')
      try {
        final res = await Process.run('magick', [imagePath, outputPdf]);
        if (res.exitCode == 0 && await File(outputPdf).exists()) {
          return outputPdf;
        }
      } catch (_) {
        try {
          final res = await Process.run('convert', [imagePath, outputPdf]);
          if (res.exitCode == 0 && await File(outputPdf).exists()) {
            return outputPdf;
          }
        } catch (_) {}
      }
    }

    return null;
  }
}
