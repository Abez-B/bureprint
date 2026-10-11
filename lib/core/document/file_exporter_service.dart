import 'dart:io';
import 'package:file_picker/file_picker.dart';

import '../../domain/models/imported_document.dart';
import '../../platform/share/share_sheet_bridge.dart';
import 'office_document_converter.dart';

/// Service to export / download documents (or converted PDFs) to user device storage.
/// - Uses system file picker save dialog (`FilePicker.platform.saveFile`) when available.
/// - Gracefully falls back to copying directly to the system `~/Downloads` directory.
class FileExporterService {
  const FileExporterService();

  /// Exports the given document to a destination file chosen by user or standard Downloads.
  /// Returns the absolute path of the exported file if successful, or null if cancelled / failed.
  Future<String?> exportDocument(ImportedDocument document) async {
    final sourcePath = document.filePath;
    String actualPathToExport = sourcePath;

    // If source document is an office or text file, ensure we export a printable PDF
    if (OfficeDocumentConverter.isConvertibleOfficeDocument(
        sourcePath, document.mimeType)) {
      final convertedPdf =
          await OfficeDocumentConverter.instance.convertToPdf(sourcePath);
      if (convertedPdf != null && await File(convertedPdf).exists()) {
        actualPathToExport = convertedPdf;
      }
    }

    final sourceFile = File(actualPathToExport);
    if (!await sourceFile.exists()) {
      throw FileSystemException(
          'Source document file does not exist', sourcePath);
    }

    final sanitizedName =
        _resolveExportFilename(document.name, actualPathToExport);

    // 1. Attempt system saveFile dialog
    String? selectedPath;
    try {
      selectedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save / Download Document',
        fileName: sanitizedName,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg'],
      );
    } catch (_) {
      selectedPath = null;
    }

    // 2. If system dialog wasn't used or not supported, fallback to ~/Downloads
    if (selectedPath == null || selectedPath.isEmpty) {
      selectedPath = await _resolveFallbackDownloadPath(sanitizedName);
    }

    if (selectedPath == null) {
      return null;
    }

    final targetFile = File(selectedPath);
    final targetDir = targetFile.parent;
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    await sourceFile.copy(selectedPath);

    if (Platform.isAndroid) {
      try {
        await AndroidShareSheetBridge().notifyMediaScanner(selectedPath);
      } catch (_) {}
    }

    return selectedPath;
  }

  String _resolveExportFilename(String originalName, String actualPath) {
    if (actualPath.endsWith('.pdf') &&
        !originalName.toLowerCase().endsWith('.pdf')) {
      final base = originalName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      return '$base.pdf';
    }
    return originalName;
  }

  /// Resolves the fallback download destination.
  /// On Android, saves to the dedicated `BurePrint` folder in user storage (e.g. `/storage/emulated/0/Download/BurePrint`).
  Future<String?> _resolveFallbackDownloadPath(String filename) async {
    if (Platform.isAndroid) {
      final androidCandidates = [
        '/storage/emulated/0/Download/BurePrint',
        '/storage/emulated/0/Documents/BurePrint',
        '/sdcard/Download/BurePrint',
        '/storage/emulated/0/BurePrint',
      ];

      for (final candidate in androidCandidates) {
        try {
          final dir = Directory(candidate);
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          return '${dir.path}/$filename';
        } catch (_) {
          continue;
        }
      }
    }

    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null && home.isNotEmpty) {
      final burePrintDownloads = Directory('$home/Downloads/BurePrint');
      try {
        if (!await burePrintDownloads.exists()) {
          await burePrintDownloads.create(recursive: true);
        }
        return '${burePrintDownloads.path}/$filename';
      } catch (_) {}

      final downloadsDir = Directory('$home/Downloads');
      if (await downloadsDir.exists()) {
        return '${downloadsDir.path}/$filename';
      }
      final documentsDir = Directory('$home/Documents');
      if (await documentsDir.exists()) {
        return '${documentsDir.path}/$filename';
      }
    }

    // Fallback to system temp if no home path (e.g. unit test runner)
    return '${Directory.systemTemp.path}/$filename';
  }
}
