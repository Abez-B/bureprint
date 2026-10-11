import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:bureprint/core/document/file_exporter_service.dart';
import 'package:bureprint/domain/models/imported_document.dart';

void main() {
  group('FileExporterService', () {
    const exporter = FileExporterService();

    test('exports existing document file to destination directory', () async {
      final tempDir =
          await Directory.systemTemp.createTemp('bureprint_export_test');
      final sourceFile = File('${tempDir.path}/sample_document.pdf');
      await sourceFile.writeAsString('%PDF-1.4 Mock document content');

      final doc = ImportedDocument(
        id: 'doc-export-1',
        name: 'sample_document.pdf',
        filePath: sourceFile.path,
        fileSizeBytes: await sourceFile.length(),
        mimeType: 'application/pdf',
        importedAt: DateTime.now(),
      );

      final exportedPath = await exporter.exportDocument(doc);
      expect(exportedPath, isNotNull);
      expect(await File(exportedPath!).exists(), isTrue);

      final exportedContent = await File(exportedPath).readAsString();
      expect(exportedContent, equals('%PDF-1.4 Mock document content'));

      // Cleanup
      await tempDir.delete(recursive: true);
      final exportedFile = File(exportedPath);
      if (await exportedFile.exists() && exportedPath.contains('bureprint')) {
        await exportedFile.delete();
      }
    });

    test('throws FileSystemException when source file is missing', () async {
      final doc = ImportedDocument(
        id: 'doc-missing',
        name: 'missing.pdf',
        filePath:
            '/tmp/non_existent_file_${DateTime.now().millisecondsSinceEpoch}.pdf',
        fileSizeBytes: 0,
        mimeType: 'application/pdf',
        importedAt: DateTime.now(),
      );

      expect(() => exporter.exportDocument(doc),
          throwsA(isA<FileSystemException>()));
    });
  });
}
