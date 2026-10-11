import 'dart:io';

import '../../domain/models/imported_document.dart';
import '../../domain/models/print_request.dart';
import '../../domain/models/printer_capabilities.dart';

enum DocumentFormatPath {
  directPassThrough,
  rasterizationRequired,
  unsupported,
}

class FormatNegotiationResult {
  const FormatNegotiationResult({
    required this.path,
    required this.targetMimeType,
    this.explanation,
  });

  final DocumentFormatPath path;
  final String targetMimeType;
  final String? explanation;
}

class DocumentPipelineEngine {
  const DocumentPipelineEngine();

  /// Inspects magic headers to validate document authenticity without loading full file into memory.
  Future<bool> validateMagicBytes(File file, String declaredMimeType) async {
    if (!await file.exists()) return false;
    final length = await file.length();
    if (length == 0) return false;

    final reader = await file.open();
    try {
      final header = await reader.read(8);
      if (declaredMimeType == 'application/pdf') {
        // PDF magic bytes: '%PDF-' (0x25, 0x50, 0x44, 0x46, 0x2D)
        if (header.length < 5) return false;
        return header[0] == 0x25 &&
            header[1] == 0x50 &&
            header[2] == 0x44 &&
            header[3] == 0x46 &&
            header[4] == 0x2D;
      } else if (declaredMimeType == 'image/png') {
        // PNG magic bytes: 0x89, 0x50, 0x4E, 0x47
        if (header.length < 4) return false;
        return header[0] == 0x89 &&
            header[1] == 0x50 &&
            header[2] == 0x4E &&
            header[3] == 0x47;
      } else if (declaredMimeType == 'image/jpeg') {
        // JPEG magic bytes: 0xFF, 0xD8, 0xFF
        if (header.length < 3) return false;
        return header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF;
      }
      return true;
    } finally {
      await reader.close();
    }
  }

  /// Computes the exact pages to print based on selection mode and total page count.
  List<int> filterPagesByMode({
    required PageSelectionMode mode,
    required int totalPages,
    String customRange = '',
  }) {
    if (totalPages <= 0) return const [];

    return switch (mode) {
      PageSelectionMode.all => List.generate(totalPages, (i) => i + 1),
      PageSelectionMode.oddOnly => [
          for (int p = 1; p <= totalPages; p += 2) p,
        ],
      PageSelectionMode.evenOnly => [
          for (int p = 2; p <= totalPages; p += 2) p,
        ],
      PageSelectionMode.custom => parsePageRanges(customRange, totalPages),
    };
  }

  /// Parses page range string expressions (e.g., '1-3, 5, 8-10') safely.
  List<int> parsePageRanges(String input, int totalPages) {
    if (input.trim().isEmpty) {
      return List.generate(totalPages, (i) => i + 1);
    }

    final pages = <int>{};
    final segments = input.split(',');

    for (final seg in segments) {
      final clean = seg.trim();
      if (clean.contains('-')) {
        final parts = clean.split('-');
        if (parts.length == 2) {
          final start = int.tryParse(parts[0].trim());
          final end = int.tryParse(parts[1].trim());
          if (start != null && end != null && start <= end) {
            for (int p = start; p <= end; p++) {
              if (p >= 1 && p <= totalPages) {
                pages.add(p);
              }
            }
          }
        }
      } else {
        final page = int.tryParse(clean);
        if (page != null && page >= 1 && page <= totalPages) {
          pages.add(page);
        }
      }
    }

    final sorted = pages.toList()..sort();
    return sorted;
  }

  /// Determines format compatibility against target printer capabilities.
  FormatNegotiationResult negotiateFormat({
    required ImportedDocument document,
    required PrinterCapabilities capabilities,
  }) {
    if (capabilities.documentFormats.contains(document.mimeType)) {
      return FormatNegotiationResult(
        path: DocumentFormatPath.directPassThrough,
        targetMimeType: document.mimeType,
        explanation:
            'Printer supports direct ${document.mimeType} transmission.',
      );
    }

    // Check if printer supports standard PWG Raster
    if (capabilities.supportsPwgRaster) {
      return const FormatNegotiationResult(
        path: DocumentFormatPath.rasterizationRequired,
        targetMimeType: 'image/pwg-raster',
        explanation:
            'Printer does not support direct PDF; conversion to PWG Raster is required.',
      );
    }

    return FormatNegotiationResult(
      path: DocumentFormatPath.unsupported,
      targetMimeType: document.mimeType,
      explanation:
          'Printer does not support ${document.mimeType} or PWG Raster. Supported formats: ${capabilities.documentFormats.join(', ')}',
    );
  }
}
