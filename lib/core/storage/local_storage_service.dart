import 'dart:convert';
import 'dart:io';

import '../../domain/models/imported_document.dart';
import '../../domain/models/printer_device.dart';

/// Service responsible for persisting saved printers and session documents
/// to the app's local data storage directory.
class LocalStorageService {
  LocalStorageService._();
  static final LocalStorageService instance = LocalStorageService._();

  Directory? _baseDir;

  void initialize(Directory directory) {
    _baseDir = directory;
  }

  Directory get _directory {
    if (_baseDir != null) return _baseDir!;
    // Fallback if not initialized explicitly
    return Directory.systemTemp;
  }

  File get _printersFile => File('${_directory.path}/saved_printers.json');
  File get _documentsFile => File('${_directory.path}/session_documents.json');
  File get _guideFile => File('${_directory.path}/guide_seen.flag');

  /// -------------------------------------------------------------
  /// ONBOARDING GUIDE PERSISTENCE
  /// -------------------------------------------------------------

  Future<bool> hasSeenGuide() async {
    try {
      return await _guideFile.exists();
    } catch (_) {
      return false;
    }
  }

  Future<void> setGuideSeen() async {
    try {
      await _guideFile.writeAsString('seen');
    } catch (_) {}
  }

  /// -------------------------------------------------------------
  /// SAVED PRINTERS PERSISTENCE (Forever until deleted by user)
  /// -------------------------------------------------------------

  Future<List<PrinterDevice>> loadSavedPrinters() async {
    try {
      if (!await _printersFile.exists()) return [];
      final content = await _printersFile.readAsString();
      if (content.trim().isEmpty) return [];
      final list = jsonDecode(content) as List<dynamic>;
      return list
          .map((item) => PrinterDevice.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> savePrinters(List<PrinterDevice> printers) async {
    try {
      final jsonList = printers.map((p) => p.toJson()).toList();
      await _printersFile.writeAsString(jsonEncode(jsonList));
    } catch (_) {
      // Ignored safely
    }
  }

  /// -------------------------------------------------------------
  /// SESSION DOCUMENTS PERSISTENCE (With 24-hour expiration check)
  /// -------------------------------------------------------------

  Future<List<ImportedDocument>> loadSessionDocuments({
    Duration ttl = const Duration(hours: 24),
  }) async {
    try {
      if (!await _documentsFile.exists()) return [];
      final content = await _documentsFile.readAsString();
      if (content.trim().isEmpty) return [];
      final list = jsonDecode(content) as List<dynamic>;
      final now = DateTime.now();

      final validDocs = <ImportedDocument>[];
      for (final item in list) {
        final doc = ImportedDocument.fromJson(item as Map<String, dynamic>);
        // Check if file still exists on disk
        final file = File(doc.filePath);
        if (!await file.exists()) continue;

        // Check if TTL expired
        final age = now.difference(doc.importedAt);
        if (age <= ttl) {
          validDocs.add(doc);
        } else {
          // Clean up expired temp file if it's within our sessions directory
          if (doc.filePath.contains('/sessions/')) {
            try {
              await file.delete();
            } catch (_) {}
          }
        }
      }

      // Re-save pruned list
      await saveSessionDocuments(validDocs);
      return validDocs;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSessionDocuments(List<ImportedDocument> documents) async {
    try {
      final jsonList = documents.map((d) => d.toJson()).toList();
      await _documentsFile.writeAsString(jsonEncode(jsonList));
    } catch (_) {
      // Ignored safely
    }
  }
}
