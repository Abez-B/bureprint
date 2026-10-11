import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../core/document/document_pipeline_engine.dart';
import '../../core/document/office_document_converter.dart';
import '../../core/document/universal_pdf_renderer.dart';
import '../../domain/models/imported_document.dart';
import '../../domain/models/print_request.dart';
import 'enlarge_preview_dialog.dart';

class DocumentPreviewCarousel extends StatefulWidget {
  const DocumentPreviewCarousel({
    required this.document,
    required this.landscape,
    required this.scalingMode,
    this.paperSize = 'iso_a4_210x297mm',
    this.pagesPerSheet = PagesPerSheet.one,
    this.pageSelectionMode = PageSelectionMode.all,
    this.customPageRange = '',
    this.compact = false,
    this.onPageCountResolved,
    super.key,
  });

  final ImportedDocument document;
  final bool landscape;
  final ScalingMode scalingMode;
  final String paperSize;
  final PagesPerSheet pagesPerSheet;
  final PageSelectionMode pageSelectionMode;
  final String customPageRange;
  final bool compact;
  final ValueChanged<int>? onPageCountResolved;

  @override
  State<DocumentPreviewCarousel> createState() =>
      _DocumentPreviewCarouselState();
}

class _DocumentPreviewCarouselState extends State<DocumentPreviewCarousel> {
  int _currentSheet = 1;
  int _rawTotalPages = 1;
  List<int> _printablePages = [1];
  // Map of physical page number -> rendered bytes
  final Map<int, Uint8List> _pageCache = {};
  bool _isLoading = false;
  String? _renderError;

  @override
  void initState() {
    super.initState();
    _loadPdfIfNeeded();
  }

  @override
  void didUpdateWidget(covariant DocumentPreviewCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final docChanged = oldWidget.document.id != widget.document.id ||
        oldWidget.document.filePath != widget.document.filePath;
    final selectionChanged =
        oldWidget.pageSelectionMode != widget.pageSelectionMode ||
            oldWidget.customPageRange != widget.customPageRange ||
            oldWidget.pagesPerSheet != widget.pagesPerSheet;

    if (docChanged) {
      _currentSheet = 1;
      _pageCache.clear();
      _loadPdfIfNeeded();
    } else if (selectionChanged) {
      _computePrintablePages();
      _currentSheet = 1;
      _renderCurrentSheetPages();
    }
  }

  void _computePrintablePages() {
    const engine = DocumentPipelineEngine();
    final filtered = engine.filterPagesByMode(
      mode: widget.pageSelectionMode,
      totalPages: _rawTotalPages,
      customRange: widget.customPageRange,
    );
    _printablePages = filtered.isEmpty ? [1] : filtered;
    final totalSheets = _calculateTotalSheets();
    if (_currentSheet > totalSheets) {
      _currentSheet = totalSheets.clamp(1, 999999);
    }
  }

  int _calculateTotalSheets() {
    final n = widget.pagesPerSheet.count;
    return (_printablePages.length / n).ceil().clamp(1, 999999);
  }

  List<int> _pagesForCurrentSheet() {
    final n = widget.pagesPerSheet.count;
    final startIndex = (_currentSheet - 1) * n;
    final pages = <int>[];
    for (int i = 0; i < n; i++) {
      final index = startIndex + i;
      if (index < _printablePages.length) {
        pages.add(_printablePages[index]);
      }
    }
    return pages;
  }

  Future<void> _loadPdfIfNeeded() async {
    final isPdfOrConvertible = widget.document.mimeType == 'application/pdf' ||
        OfficeDocumentConverter.isConvertibleOfficeDocument(
            widget.document.filePath, widget.document.mimeType);

    if (!isPdfOrConvertible) {
      _rawTotalPages = 1;
      _computePrintablePages();
      return;
    }

    final file = File(widget.document.filePath);
    if (!await file.exists()) {
      if (mounted) {
        setState(() {
          _renderError = 'File not found';
        });
      }
      return;
    }

    try {
      final total = await UniversalPdfRenderer.instance
          .getPageCount(widget.document.filePath);
      if (mounted) {
        final count = total > 0 ? total : 1;
        setState(() {
          _rawTotalPages = count;
          _computePrintablePages();
        });
        widget.onPageCountResolved?.call(count);
        await _renderCurrentSheetPages();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _renderError = 'Cannot open PDF';
        });
      }
    }
  }

  Future<void> _renderCurrentSheetPages() async {
    final isImage = widget.document.mimeType.startsWith('image/');
    if (isImage) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final pagesToRender = _pagesForCurrentSheet();
    final missing =
        pagesToRender.where((p) => !_pageCache.containsKey(p)).toList();

    if (missing.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _renderError = null;
        });
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      for (final p in missing) {
        final bytes = await UniversalPdfRenderer.instance.renderPageImage(
          filePath: widget.document.filePath,
          pageNumber: p,
          dpi: 150,
        );
        if (bytes != null) {
          _pageCache[p] = bytes;
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _renderError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _renderError = 'Render error';
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  BoxFit _resolveBoxFit(ScalingMode mode) {
    return switch (mode) {
      ScalingMode.fitPrintableArea => BoxFit.contain,
      ScalingMode.fillPage => BoxFit.cover,
      ScalingMode.originalSize => BoxFit.contain,
      ScalingMode.fitWidth => BoxFit.fitWidth,
      ScalingMode.fitHeight => BoxFit.fitHeight,
    };
  }

  String _formatPaperBadge(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('a4')) return 'A4';
    if (lower.contains('a3')) return 'A3';
    if (lower.contains('a5')) return 'A5';
    if (lower.contains('letter')) return 'Letter';
    if (lower.contains('legal')) return 'Legal';
    if (lower.contains('tabloid')) return 'Tabloid';
    if (lower.contains('4x6')) return '4×6"';
    if (lower.contains('5x7')) return '5×7"';
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalSheets = _calculateTotalSheets();
    final isImage = widget.document.mimeType.startsWith('image/');
    final file = File(widget.document.filePath);
    final fileExists = file.existsSync();

    final paperDims = PaperDimensions.fromPaperSize(widget.paperSize);
    final maxDimension = widget.compact ? 175.0 : 250.0;
    final portraitRatio = paperDims.portraitAspectRatio;

    // Calculate sheetWidth and sheetHeight preserving paper aspect ratio within fixed bounds
    final double sheetWidth;
    final double sheetHeight;
    if (widget.landscape) {
      sheetWidth = maxDimension;
      sheetHeight = (maxDimension * portraitRatio).clamp(60.0, maxDimension);
    } else {
      sheetHeight = maxDimension;
      sheetWidth = (maxDimension * portraitRatio).clamp(60.0, maxDimension);
    }

    final paperLabel = _formatPaperBadge(widget.paperSize);
    final currentPagesOnSheet = _pagesForCurrentSheet();
    final initialPageForDialog =
        currentPagesOnSheet.isNotEmpty ? currentPagesOnSheet.first : 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Clickable paper sheet preview within fixed-height stage to guarantee zero layout shift
        SizedBox(
          height: maxDimension,
          child: Center(
            child: GestureDetector(
              onTap: () {
                EnlargePreviewDialog.show(
                  context,
                  document: widget.document,
                  initialPage: initialPageForDialog,
                  paperSize: widget.paperSize,
                  landscape: widget.landscape,
                  pagesPerSheet: widget.pagesPerSheet,
                  pageSelectionMode: widget.pageSelectionMode,
                  customPageRange: widget.customPageRange,
                );
              },
              child: Tooltip(
                message: 'Tap to enlarge preview ($paperLabel)',
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  width: sheetWidth,
                  height: sheetHeight,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF666666)
                          : const Color(0xFF000000),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.white10 : Colors.black12,
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        // Rendered Sheet Content (Single or N-Up)
                        Positioned.fill(
                          child: Padding(
                            padding: EdgeInsets.all(
                              widget.scalingMode == ScalingMode.fillPage
                                  ? 0
                                  : 6.0,
                            ),
                            child: _buildSheetContent(
                                isImage, fileExists, file, isDark),
                          ),
                        ),

                        // Top-left Paper Size and N-Up Badge
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.black.withValues(alpha: 0.85)
                                      : Colors.white.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF555555)
                                        : const Color(0xFFCCCCCC),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  paperLabel,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              if (widget.pagesPerSheet !=
                                  PagesPerSheet.one) ...[
                                const SizedBox(width: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white24
                                        : Colors.black87,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    '${widget.pagesPerSheet.count}-Up',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Top-right Enlarge Icon Button
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.87)
                                  : Colors.white.withValues(alpha: 0.87),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF444444)
                                    : const Color(0xFFCCCCCC),
                              ),
                            ),
                            child: InkWell(
                              onTap: () {
                                EnlargePreviewDialog.show(
                                  context,
                                  document: widget.document,
                                  initialPage: initialPageForDialog,
                                  paperSize: widget.paperSize,
                                  landscape: widget.landscape,
                                  pagesPerSheet: widget.pagesPerSheet,
                                  pageSelectionMode: widget.pageSelectionMode,
                                  customPageRange: widget.customPageRange,
                                );
                              },
                              child: Icon(
                                Icons.fullscreen,
                                size: widget.compact ? 14 : 16,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 6),

        // Multi-sheet navigation stepper with fixed height to prevent vertical jitter
        SizedBox(
          height: 36,
          child: Center(
            child: totalSheets > 1
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.chevron_left, size: 20),
                        onPressed: _currentSheet > 1
                            ? () {
                                setState(() => _currentSheet--);
                                _renderCurrentSheetPages();
                              }
                            : null,
                      ),
                      Text(
                        widget.pagesPerSheet == PagesPerSheet.one
                            ? (_printablePages.length == _rawTotalPages
                                ? 'Page $_currentSheet of $_rawTotalPages'
                                : 'Page ${currentPagesOnSheet.isNotEmpty ? currentPagesOnSheet.first : _currentSheet} of $_rawTotalPages ($_currentSheet/${_printablePages.length})')
                            : 'Sheet $_currentSheet/$totalSheets (p.${currentPagesOnSheet.join(", ")})',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.chevron_right, size: 20),
                        onPressed: _currentSheet < totalSheets
                            ? () {
                                setState(() => _currentSheet++);
                                _renderCurrentSheetPages();
                              }
                            : null,
                      ),
                    ],
                  )
                : Text(
                    widget.pagesPerSheet != PagesPerSheet.one
                        ? 'Sheet 1/1 (p.${currentPagesOnSheet.join(", ")}) of $_rawTotalPages pages'
                        : (_printablePages.length == _rawTotalPages
                            ? 'Page 1/$_rawTotalPages'
                            : 'Page ${currentPagesOnSheet.isNotEmpty ? currentPagesOnSheet.first : 1} of $_rawTotalPages (1/${_printablePages.length} to print)'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF888888)
                          : const Color(0xFF777777),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSheetContent(
      bool isImage, bool fileExists, File file, bool isDark) {
    if (_isLoading) {
      return Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      );
    }

    if (_renderError != null) {
      return Center(
        child: Text(
          _renderError!,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 9),
        ),
      );
    }

    if (isImage && fileExists) {
      return _wrapScalingMode(
        Image.file(
          file,
          fit: _resolveBoxFit(widget.scalingMode),
        ),
        isDark,
      );
    }

    final pages = _pagesForCurrentSheet();
    if (pages.isEmpty) {
      return Center(
        child: Icon(
          Icons.description_outlined,
          size: widget.compact ? 32 : 48,
          color: isDark ? Colors.white38 : Colors.black38,
        ),
      );
    }

    if (widget.pagesPerSheet == PagesPerSheet.one) {
      final pageNum = pages.first;
      final bytes = _pageCache[pageNum];
      if (bytes != null) {
        return _wrapScalingMode(
          Image.memory(
            bytes,
            fit: _resolveBoxFit(widget.scalingMode),
          ),
          isDark,
        );
      }
      return Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      );
    }

    // N-Up Sheet Rendering (2-Up or 4-Up)
    if (widget.pagesPerSheet == PagesPerSheet.two) {
      return widget.landscape
          ? Row(
              children: [
                Expanded(child: _buildNUpSlot(pages, 0, isDark)),
                Container(
                    width: 1,
                    color: isDark ? Colors.white12 : Colors.black12,
                    margin: const EdgeInsets.symmetric(horizontal: 2)),
                Expanded(child: _buildNUpSlot(pages, 1, isDark)),
              ],
            )
          : Column(
              children: [
                Expanded(child: _buildNUpSlot(pages, 0, isDark)),
                Container(
                    height: 1,
                    color: isDark ? Colors.white12 : Colors.black12,
                    margin: const EdgeInsets.symmetric(vertical: 2)),
                Expanded(child: _buildNUpSlot(pages, 1, isDark)),
              ],
            );
    }

    // 4-Up (2x2 grid)
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildNUpSlot(pages, 0, isDark)),
              Container(
                  width: 1,
                  color: isDark ? Colors.white12 : Colors.black12,
                  margin: const EdgeInsets.symmetric(horizontal: 2)),
              Expanded(child: _buildNUpSlot(pages, 1, isDark)),
            ],
          ),
        ),
        Container(
            height: 1,
            color: isDark ? Colors.white12 : Colors.black12,
            margin: const EdgeInsets.symmetric(vertical: 2)),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildNUpSlot(pages, 2, isDark)),
              Container(
                  width: 1,
                  color: isDark ? Colors.white12 : Colors.black12,
                  margin: const EdgeInsets.symmetric(horizontal: 2)),
              Expanded(child: _buildNUpSlot(pages, 3, isDark)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNUpSlot(List<int> pages, int slotIndex, bool isDark) {
    if (slotIndex >= pages.length) {
      // Empty slot on final sheet
      return Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(8),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFEEEEEE),
            style: BorderStyle.solid,
            width: 0.5,
          ),
        ),
      );
    }

    final pageNum = pages[slotIndex];
    final bytes = _pageCache[pageNum];

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFBFBFB),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: isDark ? const Color(0xFF444444) : const Color(0xFFDDDDDD),
          width: 0.8,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: bytes != null
                ? Image.memory(
                    bytes,
                    fit: _resolveBoxFit(widget.scalingMode),
                  )
                : Center(
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
          ),
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.75)
                    : Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                '$pageNum',
                style: TextStyle(
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wrapScalingMode(Widget child, bool isDark) {
    if (widget.scalingMode == ScalingMode.originalSize) {
      // 100% Original Size: Display centered with clean document margins and subtle outline
      return Center(
        child: FractionallySizedBox(
          widthFactor: 0.88,
          heightFactor: 0.88,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color:
                    isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.white.withAlpha(12) : Colors.black12,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: child,
          ),
        ),
      );
    }
    return child;
  }
}
