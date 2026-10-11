import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../core/document/document_pipeline_engine.dart';
import '../../core/document/office_document_converter.dart';
import '../../core/document/universal_pdf_renderer.dart';
import '../../domain/models/imported_document.dart';
import '../../domain/models/print_request.dart';

class EnlargePreviewDialog extends StatefulWidget {
  const EnlargePreviewDialog({
    required this.document,
    this.initialPage = 1,
    this.paperSize = 'iso_a4_210x297mm',
    this.landscape = false,
    this.pagesPerSheet = PagesPerSheet.one,
    this.pageSelectionMode = PageSelectionMode.all,
    this.customPageRange = '',
    super.key,
  });

  final ImportedDocument document;
  final int initialPage;
  final String paperSize;
  final bool landscape;
  final PagesPerSheet pagesPerSheet;
  final PageSelectionMode pageSelectionMode;
  final String customPageRange;

  static Future<void> show(
    BuildContext context, {
    required ImportedDocument document,
    int initialPage = 1,
    String paperSize = 'iso_a4_210x297mm',
    bool landscape = false,
    PagesPerSheet pagesPerSheet = PagesPerSheet.one,
    PageSelectionMode pageSelectionMode = PageSelectionMode.all,
    String customPageRange = '',
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => EnlargePreviewDialog(
        document: document,
        initialPage: initialPage,
        paperSize: paperSize,
        landscape: landscape,
        pagesPerSheet: pagesPerSheet,
        pageSelectionMode: pageSelectionMode,
        customPageRange: customPageRange,
      ),
    );
  }

  @override
  State<EnlargePreviewDialog> createState() => _EnlargePreviewDialogState();
}

class _EnlargePreviewDialogState extends State<EnlargePreviewDialog> {
  final Map<int, Uint8List> _pageCache = {};
  bool _isLoading = true;
  String? _errorMessage;
  int _currentSheet = 1;
  int _rawTotalPages = 1;
  List<int> _printablePages = [1];

  @override
  void initState() {
    super.initState();
    _initDocument();
  }

  Future<void> _initDocument() async {
    final file = File(widget.document.filePath);
    if (!await file.exists()) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'File not found on device';
      });
      return;
    }

    final isPdfOrConvertible = widget.document.mimeType == 'application/pdf' ||
        OfficeDocumentConverter.isConvertibleOfficeDocument(
            widget.document.filePath, widget.document.mimeType);

    if (isPdfOrConvertible) {
      try {
        final count = await UniversalPdfRenderer.instance
            .getPageCount(widget.document.filePath);
        _rawTotalPages = count > 0 ? count : 1;
        _computePrintablePages();

        // Calculate initial sheet based on widget.initialPage
        final initialIdx = _printablePages.indexOf(widget.initialPage);
        final n = widget.pagesPerSheet.count;
        if (initialIdx >= 0) {
          _currentSheet = (initialIdx ~/ n) + 1;
        } else {
          _currentSheet = 1;
        }

        await _renderCurrentSheetPages();
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to open document: $e';
        });
      }
    } else {
      // Image document
      _rawTotalPages = 1;
      _computePrintablePages();
      setState(() {
        _isLoading = false;
      });
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
          _errorMessage = null;
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
          dpi: 200,
        );
        if (bytes != null) {
          _pageCache[p] = bytes;
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to render: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isImage = widget.document.mimeType.startsWith('image/');
    final file = File(widget.document.filePath);
    final totalSheets = _calculateTotalSheets();
    final currentPagesOnSheet = _pagesForCurrentSheet();

    final subtitleText = isImage
        ? 'Image Preview · ${_formatPaperName(widget.paperSize)} (${widget.landscape ? "Landscape" : "Portrait"})${widget.pagesPerSheet != PagesPerSheet.one ? " · ${widget.pagesPerSheet.count}-Up" : ""}'
        : widget.pagesPerSheet == PagesPerSheet.one
            ? (_printablePages.length == _rawTotalPages
                ? 'Page $_currentSheet of $_rawTotalPages · ${_formatPaperName(widget.paperSize)} (${widget.landscape ? "Landscape" : "Portrait"})'
                : 'Page ${currentPagesOnSheet.isNotEmpty ? currentPagesOnSheet.first : _currentSheet} of $_rawTotalPages ($_currentSheet/${_printablePages.length} to print) · ${_formatPaperName(widget.paperSize)} (${widget.landscape ? "Landscape" : "Portrait"})')
            : 'Sheet $_currentSheet of $totalSheets (p. ${currentPagesOnSheet.join(", ")}) of $_rawTotalPages pages · ${_formatPaperName(widget.paperSize)} (${widget.landscape ? "Landscape" : "Portrait"}) · ${widget.pagesPerSheet.count}-Up';

    return Dialog.fullscreen(
      backgroundColor: isDark ? Colors.black : Colors.white,
      child: SafeArea(
        child: Scaffold(
          backgroundColor: isDark ? Colors.black : Colors.white,
          appBar: AppBar(
            backgroundColor: isDark ? Colors.black : Colors.white,
            foregroundColor: isDark ? Colors.white : Colors.black,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.document.name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitleText,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFFBDBDBD)
                        : const Color(0xFF616161),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Close Preview',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: Center(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: _buildContent(isImage, file, isDark),
                  ),
                ),
              ),

              // Sheet navigator bar
              if (totalSheets > 1)
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF181818)
                        : const Color(0xFFF9F9F9),
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? const Color(0xFF333333)
                            : const Color(0xFFE0E0E0),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Previous'),
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
                                ? 'Page $_currentSheet / $_rawTotalPages'
                                : 'Page ${currentPagesOnSheet.isNotEmpty ? currentPagesOnSheet.first : _currentSheet} of $_rawTotalPages ($_currentSheet/${_printablePages.length} to print)')
                            : 'Sheet $_currentSheet / $totalSheets (p. ${currentPagesOnSheet.join(", ")})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('Next'),
                        onPressed: _currentSheet < totalSheets
                            ? () {
                                setState(() => _currentSheet++);
                                _renderCurrentSheetPages();
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool isImage, File file, bool isDark) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: isDark ? Colors.white : Colors.black,
        ),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      );
    }

    final paperDims = PaperDimensions.fromPaperSize(widget.paperSize);
    final ratio = widget.landscape
        ? paperDims.landscapeAspectRatio
        : paperDims.portraitAspectRatio;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: AspectRatio(
          aspectRatio: ratio,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF666666) : const Color(0xFFCCCCCC),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: isImage
                  ? Image.file(file, fit: BoxFit.contain)
                  : _buildEnlargedSheetContent(isDark),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnlargedSheetContent(bool isDark) {
    final pages = _pagesForCurrentSheet();
    if (pages.isEmpty) {
      return const SizedBox.shrink();
    }

    if (widget.pagesPerSheet == PagesPerSheet.one) {
      final pageNum = pages.first;
      final bytes = _pageCache[pageNum];
      if (bytes != null) {
        return Image.memory(bytes, fit: BoxFit.contain);
      }
      return Center(
        child: CircularProgressIndicator(
          color: isDark ? Colors.white : Colors.black,
        ),
      );
    }

    if (widget.pagesPerSheet == PagesPerSheet.two) {
      return widget.landscape
          ? Row(
              children: [
                Expanded(child: _buildEnlargedSlot(pages, 0, isDark)),
                Container(
                    width: 1.5,
                    color: isDark ? Colors.white12 : Colors.black12),
                Expanded(child: _buildEnlargedSlot(pages, 1, isDark)),
              ],
            )
          : Column(
              children: [
                Expanded(child: _buildEnlargedSlot(pages, 0, isDark)),
                Container(
                    height: 1.5,
                    color: isDark ? Colors.white12 : Colors.black12),
                Expanded(child: _buildEnlargedSlot(pages, 1, isDark)),
              ],
            );
    }

    // 4-Up (2x2 grid)
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildEnlargedSlot(pages, 0, isDark)),
              Container(
                  width: 1.5, color: isDark ? Colors.white12 : Colors.black12),
              Expanded(child: _buildEnlargedSlot(pages, 1, isDark)),
            ],
          ),
        ),
        Container(height: 1.5, color: isDark ? Colors.white12 : Colors.black12),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildEnlargedSlot(pages, 2, isDark)),
              Container(
                  width: 1.5, color: isDark ? Colors.white12 : Colors.black12),
              Expanded(child: _buildEnlargedSlot(pages, 3, isDark)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnlargedSlot(List<int> pages, int slotIndex, bool isDark) {
    if (slotIndex >= pages.length) {
      return Container(
        color: isDark ? Colors.white.withAlpha(5) : Colors.black.withAlpha(5),
      );
    }

    final pageNum = pages[slotIndex];
    final bytes = _pageCache[pageNum];

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141414) : const Color(0xFFFAFAFA),
        border: Border.all(
          color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
          width: 0.8,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: bytes != null
                ? Image.memory(bytes, fit: BoxFit.contain)
                : Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.75)
                    : Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                'Page $pageNum',
                style: TextStyle(
                  fontSize: 10,
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

  String _formatPaperName(String raw) {
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
}
