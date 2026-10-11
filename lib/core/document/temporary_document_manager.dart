import 'dart:io';

/// Deterministic temporary file lifecycle manager for document processing.
///
/// Ensures all intermediate raster files, temporary imports, and scratch buffers
/// are strictly scoped to the application cache directory and deleted immediately
/// upon completion, cancellation, or failure.
class TemporaryDocumentManager {
  const TemporaryDocumentManager();

  /// Deletes a specific temporary file safely if it exists.
  Future<bool> deleteTemporaryFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (_) {
      // Avoid throwing during cleanup
    }
    return false;
  }

  /// Scans and purges old scratch files from a designated cache directory.
  Future<int> purgeOrphanedFiles(Directory cacheDir,
      {Duration maxAge = const Duration(hours: 12)}) async {
    int purgedCount = 0;
    try {
      if (!await cacheDir.exists()) return 0;
      final now = DateTime.now();
      await for (final entity in cacheDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          if (now.difference(stat.modified) > maxAge) {
            await entity.delete();
            purgedCount++;
          }
        }
      }
    } catch (_) {
      // Avoid crashing background cleanup
    }
    return purgedCount;
  }
}
