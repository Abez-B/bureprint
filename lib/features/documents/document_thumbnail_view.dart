import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/document/office_document_converter.dart';
import '../../core/document/universal_pdf_renderer.dart';
import '../../domain/models/imported_document.dart';

/// Fast asynchronous thumbnail component for grid/list tiles.
/// Automatically handles PDF rasterization with cache and image loading.
class DocumentThumbnailView extends StatefulWidget {
  const DocumentThumbnailView({
    required this.document,
    this.width = double.infinity,
    this.height = 110,
    super.key,
  });

  final ImportedDocument document;
  final double width;
  final double height;

  @override
  State<DocumentThumbnailView> createState() => _DocumentThumbnailViewState();
}

class _DocumentThumbnailViewState extends State<DocumentThumbnailView> {
  Uint8List? _thumbnailBytes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(covariant DocumentThumbnailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.id != widget.document.id ||
        oldWidget.document.filePath != widget.document.filePath) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    if (widget.document.mimeType.startsWith('image/')) {
      // Local image file loads directly via Image.file
      return;
    }

    final isPdfOrConvertible = widget.document.mimeType == 'application/pdf' ||
        OfficeDocumentConverter.isConvertibleOfficeDocument(
            widget.document.filePath, widget.document.mimeType);

    if (isPdfOrConvertible) {
      final file = File(widget.document.filePath);
      if (!file.existsSync()) {
        return;
      }

      setState(() => _isLoading = true);
      try {
        final bytes = await UniversalPdfRenderer.instance.renderPageImage(
          filePath: widget.document.filePath,
          pageNumber: 1,
          dpi: 80, // Lightweight thumbnail dpi
        );

        if (mounted) {
          setState(() {
            _thumbnailBytes = bytes;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isImage = widget.document.mimeType.startsWith('image/');
    final file = File(widget.document.filePath);

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181818) : const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0),
          width: 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(
        child: isImage && file.existsSync()
            ? Padding(
                padding: const EdgeInsets.all(4.0),
                child: Image.file(
                  file,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => _buildFallbackIcon(isDark),
                ),
              )
            : _thumbnailBytes != null
                ? Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Image.memory(
                        _thumbnailBytes!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            _buildFallbackIcon(isDark),
                      ),
                    ),
                  )
                : _isLoading
                    ? Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      )
                    : _buildFallbackIcon(isDark),
      ),
    );
  }

  Widget _buildFallbackIcon(bool isDark) {
    return Center(
      child: Icon(
        widget.document.mimeType == 'application/pdf'
            ? Icons.picture_as_pdf_outlined
            : Icons.insert_drive_file_outlined,
        size: 32,
        color: isDark ? const Color(0xFF666666) : const Color(0xFF999999),
      ),
    );
  }
}
