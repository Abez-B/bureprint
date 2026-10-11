import 'package:flutter/foundation.dart';

@immutable
class ImportedDocument {
  const ImportedDocument({
    required this.id,
    required this.name,
    required this.filePath,
    required this.fileSizeBytes,
    required this.mimeType,
    required this.importedAt,
    this.pageCount,
    this.isRasterized = false,
  });

  final String id;
  final String name;
  final String filePath;
  final int fileSizeBytes;
  final String mimeType;
  final DateTime importedAt;
  final int? pageCount;
  final bool isRasterized;

  String get formattedFileSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  ImportedDocument copyWith({
    String? id,
    String? name,
    String? filePath,
    int? fileSizeBytes,
    String? mimeType,
    DateTime? importedAt,
    int? pageCount,
    bool? isRasterized,
  }) {
    return ImportedDocument(
      id: id ?? this.id,
      name: name ?? this.name,
      filePath: filePath ?? this.filePath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      mimeType: mimeType ?? this.mimeType,
      importedAt: importedAt ?? this.importedAt,
      pageCount: pageCount ?? this.pageCount,
      isRasterized: isRasterized ?? this.isRasterized,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'filePath': filePath,
        'fileSizeBytes': fileSizeBytes,
        'mimeType': mimeType,
        'importedAt': importedAt.toIso8601String(),
        if (pageCount != null) 'pageCount': pageCount,
        'isRasterized': isRasterized,
      };

  factory ImportedDocument.fromJson(Map<String, dynamic> json) {
    return ImportedDocument(
      id: json['id'] as String,
      name: json['name'] as String,
      filePath: json['filePath'] as String,
      fileSizeBytes: json['fileSizeBytes'] as int,
      mimeType: json['mimeType'] as String,
      importedAt: DateTime.parse(json['importedAt'] as String),
      pageCount: json['pageCount'] as int?,
      isRasterized: json['isRasterized'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImportedDocument &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          filePath == other.filePath &&
          fileSizeBytes == other.fileSizeBytes &&
          mimeType == other.mimeType &&
          importedAt == other.importedAt &&
          pageCount == other.pageCount &&
          isRasterized == other.isRasterized;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        filePath,
        fileSizeBytes,
        mimeType,
        importedAt,
        pageCount,
        isRasterized,
      );
}
