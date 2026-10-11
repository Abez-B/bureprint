import 'dart:io';
import 'package:file_picker/file_picker.dart';

import '../../domain/models/imported_document.dart';

enum DocumentPickMode {
  images,
  documents,
  allFiles,
}

abstract interface class FilePickerService {
  Future<List<ImportedDocument>> pickFiles({
    DocumentPickMode mode = DocumentPickMode.allFiles,
    bool allowMultiple = true,
  });
}

class SystemFilePickerService implements FilePickerService {
  const SystemFilePickerService();

  @override
  Future<List<ImportedDocument>> pickFiles({
    DocumentPickMode mode = DocumentPickMode.allFiles,
    bool allowMultiple = true,
  }) async {
    FileType fileType;
    List<String>? allowedExtensions;

    switch (mode) {
      case DocumentPickMode.images:
        fileType = FileType.image;
        break;
      case DocumentPickMode.documents:
        fileType = FileType.custom;
        allowedExtensions = ['pdf', 'doc', 'docx', 'odt', 'rtf', 'txt'];
        break;
      case DocumentPickMode.allFiles:
        fileType = FileType.any;
        break;
    }

    final result = await FilePicker.platform.pickFiles(
      type: fileType,
      allowedExtensions: allowedExtensions,
      allowMultiple: allowMultiple,
      withData: false, // Stream/path based to avoid memory spikes
    );

    if (result == null || result.files.isEmpty) {
      return const [];
    }

    final imported = <ImportedDocument>[];
    for (final file in result.files) {
      final path = file.path;
      if (path == null) continue;

      final ioFile = File(path);
      final size = file.size > 0 ? file.size : (await ioFile.length());
      final extension = (file.extension ?? '').toLowerCase();

      String mimeType = 'application/octet-stream';
      if (extension == 'pdf') {
        mimeType = 'application/pdf';
      } else if (extension == 'jpg' || extension == 'jpeg') {
        mimeType = 'image/jpeg';
      } else if (extension == 'png') {
        mimeType = 'image/png';
      } else if (extension == 'webp') {
        mimeType = 'image/webp';
      } else if (extension == 'gif') {
        mimeType = 'image/gif';
      } else if (extension == 'bmp') {
        mimeType = 'image/bmp';
      } else if (extension == 'docx') {
        mimeType =
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      } else if (extension == 'doc') {
        mimeType = 'application/msword';
      } else if (extension == 'odt') {
        mimeType = 'application/vnd.oasis.opendocument.text';
      } else if (extension == 'rtf') {
        mimeType = 'application/rtf';
      } else if (extension == 'txt') {
        mimeType = 'text/plain';
      }

      imported.add(
        ImportedDocument(
          id: 'doc-${DateTime.now().millisecondsSinceEpoch}-${file.name.hashCode}',
          name: file.name,
          filePath: path,
          fileSizeBytes: size,
          mimeType: mimeType,
          importedAt: DateTime.now(),
        ),
      );
    }

    return imported;
  }
}
