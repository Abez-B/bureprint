import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../core/document/file_exporter_service.dart';
import '../../core/document/universal_pdf_renderer.dart';
import '../../core/raster/document_rasterizer_engine.dart';
import '../../core/raster/printer_driver_registry.dart';
import '../../data/ipp/ipp_client.dart';
import '../../domain/models/imported_document.dart';
import '../../domain/models/print_job.dart';
import '../../domain/models/print_request.dart';
import '../../domain/models/printer_capabilities.dart';
import '../../domain/models/printer_device.dart';
import '../../platform/usb/usb_host_bridge.dart';
import '../../platform/usb/usb_print_transport.dart';
import '../../platform/usb/usb_printer_device.dart';
import '../printers/printers_provider.dart';
import '../queue/queue_provider.dart';
import 'document_preview_carousel.dart';
import 'document_provider.dart';
import 'duplex_info_dialog.dart';

class PrintSettingsModal extends ConsumerStatefulWidget {
  const PrintSettingsModal({
    required this.document,
    super.key,
  });

  final ImportedDocument document;

  static Future<void> show(BuildContext context, ImportedDocument doc) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PrintSettingsModal(document: doc),
    );
  }

  @override
  ConsumerState<PrintSettingsModal> createState() => _PrintSettingsModalState();
}

class _PrintSettingsModalState extends ConsumerState<PrintSettingsModal> {
  late int _copies;
  late String _paperSize;
  late bool _landscape;
  late bool _color;
  late DuplexMode _duplexMode;
  late ScalingMode _scalingMode;
  late PrintQuality _quality;
  late PageSelectionMode _pageSelectionMode;
  late PagesPerSheet _pagesPerSheet;
  late TextEditingController _pageRangeController;
  int? _resolvedTotalPages;
  bool _collate = true;

  static const _supportedPaperSizes = [
    'iso_a4_210x297mm',
    'iso_a3_297x420mm',
    'iso_a5_148x210mm',
    'na_letter_8.5x11in',
    'na_legal_8.5x14in',
    'na_tabloid_11x17in',
    'na_index-4x6_4x6in',
    'na_5x7_5x7in',
    'roll_58mm_receipt',
    'roll_80mm_receipt',
  ];

  String _formatPaperName(String raw) {
    if (raw.contains('a4')) return 'A4 (210 × 297 mm)';
    if (raw.contains('a3')) return 'A3 (297 × 420 mm)';
    if (raw.contains('a5')) return 'A5 (148 × 210 mm)';
    if (raw.contains('letter')) return 'US Letter (8.5 × 11 in)';
    if (raw.contains('legal')) return 'US Legal (8.5 × 14 in)';
    if (raw.contains('tabloid')) return 'Tabloid (11 × 17 in)';
    if (raw.contains('4x6')) return 'Photo 4 × 6 in (10 × 15 cm)';
    if (raw.contains('5x7')) return 'Photo 5 × 7 in (13 × 18 cm)';
    if (raw.contains('58mm')) return '58mm Thermal Receipt';
    if (raw.contains('80mm')) return '80mm Thermal Receipt';
    return raw;
  }

  @override
  void initState() {
    super.initState();
    final current = ref.read(documentManagerProvider).currentSettings;
    _copies = current.copies;
    _paperSize = current.paperSize;
    _landscape = current.landscape;
    _color = current.color;
    _duplexMode = current.duplexMode;
    _scalingMode = current.scalingMode;
    _quality = current.quality;
    _pageSelectionMode = current.pageSelectionMode;
    _pagesPerSheet = current.pagesPerSheet;
    _resolvedTotalPages = widget.document.pageCount;
    _pageRangeController = TextEditingController(text: current.customPageRange);
    _pageRangeController.addListener(_onPageRangeChanged);
    _detectDocumentOrientation();
  }

  void _detectDocumentOrientation() async {
    final mime = widget.document.mimeType;
    if (mime.startsWith('image/')) {
      final file = File(widget.document.filePath);
      if (await file.exists()) {
        try {
          final bytes = await file.readAsBytes();
          final decoded = img.decodeImage(bytes);
          if (decoded != null && decoded.width > decoded.height) {
            if (mounted && !_landscape) {
              setState(() => _landscape = true);
            }
          }
        } catch (_) {}
      }
    } else {
      try {
        final dims = await UniversalPdfRenderer.instance
            .getPageDimensions(widget.document.filePath);
        if (dims != null && dims.width > dims.height) {
          if (mounted && !_landscape) {
            setState(() => _landscape = true);
          }
        }
      } catch (_) {}
    }
  }

  void _onPageRangeChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _pageRangeController.removeListener(_onPageRangeChanged);
    _pageRangeController.dispose();
    super.dispose();
  }

  String get _advancedSummary {
    final pageStr = _pageSelectionMode == PageSelectionMode.all
        ? 'All pages'
        : (_pageSelectionMode == PageSelectionMode.oddOnly
            ? 'Odd only'
            : (_pageSelectionMode == PageSelectionMode.evenOnly
                ? 'Even only'
                : 'Custom pages'));
    final duplexStr = _duplexMode == DuplexMode.oneSided ? '1-Sided' : 'Duplex';
    return '$pageStr · $duplexStr · ${_pagesPerSheet.displayName} · ${_quality.displayName}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final printerState = ref.watch(printerRegistryProvider);
    final selectedPrinter = printerState.selectedPrinter;
    final totalPages = _resolvedTotalPages ?? widget.document.pageCount ?? 1;

    return Material(
      color: theme.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(
          color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.only(
            top: 12,
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.94,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top drag pill
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Modal Header
              Row(
                children: [
                  const Icon(Icons.print_outlined, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Print Options',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          widget.document.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFFBDBDBD)
                                : const Color(0xFF616161),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Save Settings as Default',
                    icon: const Icon(Icons.bookmark_add_outlined, size: 20),
                    onPressed: () => _saveSettingsAsDefault(context, isDark),
                  ),
                  IconButton(
                    tooltip: 'Export PDF',
                    icon: const Icon(Icons.download_outlined, size: 20),
                    onPressed: () => _handleExportPdf(context),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 16),

              // Main Scrollable Area
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // Document Preview Card - height 224 perfectly accommodates 175px sheet + 36px controls + spacing with ZERO overflow
                    Container(
                      height: 224,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E1E1E)
                            : const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF333333)
                              : const Color(0xFFE9ECEF),
                        ),
                      ),
                      child: Center(
                        child: DocumentPreviewCarousel(
                          document: widget.document,
                          landscape: _landscape,
                          scalingMode: _scalingMode,
                          paperSize: _paperSize,
                          pagesPerSheet: _pagesPerSheet,
                          pageSelectionMode: _pageSelectionMode,
                          customPageRange: _pageRangeController.text,
                          compact: true,
                          onPageCountResolved: (count) {
                            if (_resolvedTotalPages != count) {
                              setState(() {
                                _resolvedTotalPages = count;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Destination Printer Card
                    _buildPrinterSelectorCard(
                      context,
                      isDark,
                      selectedPrinter,
                      printerState,
                    ),
                    const SizedBox(height: 10),

                    // Primary Settings Card (The ONLY necessary settings unhidden)
                    _buildPrimarySettingsCard(
                      context,
                      isDark,
                      selectedPrinter,
                      printerState,
                    ),
                    const SizedBox(height: 10),

                    // Advanced Settings Accordion
                    _buildAdvancedSettingsCard(
                      context,
                      isDark,
                      totalPages,
                      theme,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              // Bottom Prominent Print Now Action
              _buildBottomAction(
                context,
                isDark,
                selectedPrinter,
                totalPages,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrinterSelectorCard(
    BuildContext context,
    bool isDark,
    PrinterDevice? selectedPrinter,
    PrinterRegistryState printerState,
  ) {
    final isUsb = selectedPrinter?.connectionType == PrinterConnectionType.usb;
    final isVirtual = selectedPrinter?.id == 'save-as-pdf-virtual';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFE9ECEF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isVirtual
                      ? Icons.download_rounded
                      : (isUsb ? Icons.usb_rounded : Icons.wifi_rounded),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedPrinter?.id,
                    isDense: true,
                    isExpanded: true,
                    hint: const Text(
                      'Select a destination printer...',
                      style: TextStyle(fontSize: 13),
                    ),
                    items: [
                      DropdownMenuItem<String>(
                        value: PrinterRegistryNotifier.saveAsPdfPrinter.id,
                        child: const Row(
                          children: [
                            Icon(Icons.download_rounded, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Save as PDF (Device Storage)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...printerState.savedPrinters.map((p) {
                        final pUsb =
                            p.connectionType == PrinterConnectionType.usb;
                        return DropdownMenuItem<String>(
                          value: p.id,
                          child: Row(
                            children: [
                              Icon(
                                pUsb ? Icons.usb_rounded : Icons.wifi_rounded,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${p.name} (${pUsb ? "USB OTG" : "Wi-Fi"})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      ...printerState.usbPrinters
                          .where((u) => !printerState.savedPrinters.any((sp) =>
                              sp.vendorId == u.vendorId &&
                              sp.productId == u.productId))
                          .map((u) {
                        final p = u.toPrinterDevice();
                        return DropdownMenuItem<String>(
                          value: p.id,
                          child: Row(
                            children: [
                              const Icon(Icons.usb_rounded, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${p.name} (USB OTG)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      ...printerState.discoveredPrinters
                          .where((dp) =>
                              dp.connectionType ==
                                  PrinterConnectionType.network &&
                              !printerState.savedPrinters
                                  .any((sp) => sp.id == dp.id))
                          .map((p) {
                        return DropdownMenuItem<String>(
                          value: p.id,
                          child: Row(
                            children: [
                              const Icon(Icons.wifi_rounded, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${p.name} (Wi-Fi)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    onChanged: (printerId) {
                      if (printerId == null) return;
                      if (printerId ==
                          PrinterRegistryNotifier.saveAsPdfPrinter.id) {
                        ref
                            .read(printerRegistryProvider.notifier)
                            .selectPrinter(
                                PrinterRegistryNotifier.saveAsPdfPrinter);
                        return;
                      }
                      final allPrinters = [
                        ...printerState.savedPrinters,
                        ...printerState.usbPrinters
                            .map((u) => u.toPrinterDevice()),
                        ...printerState.discoveredPrinters,
                      ];
                      final matches =
                          allPrinters.where((p) => p.id == printerId);
                      if (matches.isNotEmpty) {
                        ref
                            .read(printerRegistryProvider.notifier)
                            .selectPrinter(matches.first);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          if (selectedPrinter != null &&
              selectedPrinter.id != 'save-as-pdf-virtual') ...[
            Builder(builder: (context) {
              final matchedDriver =
                  PrinterDriverRegistry.resolveDriver(selectedPrinter);
              if (matchedDriver == null) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 6, left: 42),
                child: Row(
                  children: [
                    const Icon(Icons.verified_outlined,
                        size: 13, color: Colors.green),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Engine: ${matchedDriver.displayName}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFF81C784)
                              : const Color(0xFF2E7D32),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (printerState.capabilitiesMap[selectedPrinter.id]?.markerSupplies
                    .isNotEmpty ??
                false) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 42),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: printerState
                      .capabilitiesMap[selectedPrinter.id]!.markerSupplies
                      .map((s) {
                    final color = Color(int.parse(
                            s.colorHex.replaceFirst('#', '').padLeft(6, '0'),
                            radix: 16) |
                        0xFF000000);
                    final percent = s.levelPercent.clamp(0, 100);

                    return Tooltip(
                      message: '${s.name}: $percent%',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? Colors.white54 : Colors.black26,
                                width: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 24,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: percent / 100.0,
                                backgroundColor:
                                    isDark ? Colors.white12 : Colors.black12,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  color == Colors.black && isDark
                                      ? Colors.white70
                                      : color,
                                ),
                                minHeight: 4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '$percent%',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFFBDBDBD)
                                  : const Color(0xFF616161),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPrimarySettingsCard(
    BuildContext context,
    bool isDark,
    PrinterDevice? selectedPrinter,
    PrinterRegistryState printerState,
  ) {
    final printerCaps = selectedPrinter != null
        ? printerState.capabilitiesMap[selectedPrinter.id]
        : null;
    final isMonoOnly = printerCaps != null && !printerCaps.supportsColor;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Copies Counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.content_copy_outlined, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Copies',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton.outlined(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.remove, size: 16),
                    onPressed:
                        _copies > 1 ? () => setState(() => _copies--) : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      '$_copies',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton.outlined(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.add, size: 16),
                    onPressed: () => setState(() => _copies++),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 18),

          // Row 2: Paper Size (Dedicated full-width row - zero horizontal squishing/overflow)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.description_outlined, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Paper Size',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _paperSize,
                isDense: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _supportedPaperSizes.map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Text(
                      _formatPaperName(s),
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _paperSize = val);
                },
              ),
            ],
          ),
          const Divider(height: 18),

          // Row 3: Orientation (Clean dedicated row - zero text wrapping)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.screen_rotation_outlined, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Orientation',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text(
                      'Portrait',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(
                      'Landscape',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                selected: {_landscape},
                onSelectionChanged: (val) =>
                    setState(() => _landscape = val.first),
              ),
            ],
          ),
          const Divider(height: 18),

          // Row 4: Color vs Monochrome
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.palette_outlined, size: 18),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Color Mode',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      if (isMonoOnly)
                        const Text(
                          'Printer is monochrome only',
                          style:
                              TextStyle(fontSize: 11, color: Color(0xFF888888)),
                        ),
                    ],
                  ),
                ],
              ),
              if (isMonoOnly)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2C2C2E)
                        : const Color(0xFFE9ECEF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'B&W Only',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                )
              else
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('B&W',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Color',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                  selected: {_color},
                  onSelectionChanged: (val) =>
                      setState(() => _color = val.first),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSettingsCard(
    BuildContext context,
    bool isDark,
    int totalPages,
    ThemeData theme,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
        ),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding:
              const EdgeInsets.only(left: 14, right: 14, bottom: 14),
          leading: const Icon(Icons.tune_rounded, size: 20),
          title: const Text(
            'Advanced Settings',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            _advancedSummary,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF9E9E9E) : const Color(0xFF757575),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Advanced 1: Pages to Print Filter (Full width dropdown)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pages to Print',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  '$totalPages ${totalPages == 1 ? "page" : "pages"} total',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFF9E9E9E)
                        : const Color(0xFF757575),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<PageSelectionMode>(
              initialValue: _pageSelectionMode,
              isDense: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              items: [
                DropdownMenuItem(
                  value: PageSelectionMode.all,
                  child: Text('All Pages (1 to $totalPages)'),
                ),
                const DropdownMenuItem(
                  value: PageSelectionMode.oddOnly,
                  child: Text('Odd Pages Only'),
                ),
                const DropdownMenuItem(
                  value: PageSelectionMode.evenOnly,
                  child: Text('Even Pages Only'),
                ),
                const DropdownMenuItem(
                  value: PageSelectionMode.custom,
                  child: Text('Custom Page Range...'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _pageSelectionMode = val);
              },
            ),
            if (_pageSelectionMode == PageSelectionMode.custom) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _pageRangeController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Custom Range (e.g. 1-15, 18-19)',
                  hintText: 'e.g. 1-3, 5, 8-10',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                keyboardType: TextInputType.text,
              ),
            ],
            const SizedBox(height: 14),

            // Advanced 2: Two-Sided Printing (Duplex with showSelectedIcon: false)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Two-Sided (Duplex)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.info_outline, size: 18),
                  tooltip: 'Duplex Flip Guide',
                  onPressed: () => DuplexInfoDialog.show(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<DuplexMode>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                segments: const [
                  ButtonSegment(
                    value: DuplexMode.oneSided,
                    label: Text('1-Sided',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  ButtonSegment(
                    value: DuplexMode.longEdge,
                    label: Text('Long Edge',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  ButtonSegment(
                    value: DuplexMode.shortEdge,
                    label: Text('Short Edge',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
                selected: {_duplexMode},
                onSelectionChanged: (val) =>
                    setState(() => _duplexMode = val.first),
              ),
            ),
            const SizedBox(height: 14),

            // Advanced 3: Pages Per Sheet (N-Up Layout with showSelectedIcon: false)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Pages Per Sheet (N-Up Layout)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<PagesPerSheet>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                segments: const [
                  ButtonSegment(
                    value: PagesPerSheet.one,
                    label: Text('1-Up',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  ButtonSegment(
                    value: PagesPerSheet.two,
                    label: Text('2-Up',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  ButtonSegment(
                    value: PagesPerSheet.four,
                    label: Text('4-Up',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
                selected: {_pagesPerSheet},
                onSelectionChanged: (val) =>
                    setState(() => _pagesPerSheet = val.first),
              ),
            ),
            const SizedBox(height: 14),

            // Advanced 4: Page Scaling (Full width dropdown)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Page Scaling',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<ScalingMode>(
                  initialValue: _scalingMode,
                  isDense: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: ScalingMode.values.map((s) {
                    return DropdownMenuItem(
                      value: s,
                      child: Text(
                        s.displayName,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _scalingMode = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Advanced 5: Print Quality (Full width dropdown)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Print Quality',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<PrintQuality>(
                  initialValue: _quality,
                  isDense: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: PrintQuality.values.map((q) {
                    return DropdownMenuItem(
                      value: q,
                      child: Text(
                        q.displayName,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _quality = val);
                  },
                ),
              ],
            ),

            // Advanced 6: Collate Copies Toggle
            if (_copies > 1) ...[
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Collate Copies',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                subtitle: Text(
                  _collate
                      ? 'Sets: (1, 2, 3), (1, 2, 3)'
                      : 'Grouped: (1, 1), (2, 2), (3, 3)',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFF9E9E9E)
                        : const Color(0xFF757575),
                  ),
                ),
                value: _collate,
                onChanged: (val) => setState(() => _collate = val),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction(
    BuildContext context,
    bool isDark,
    PrinterDevice? selectedPrinter,
    int totalPages,
  ) {
    final isVirtual = selectedPrinter?.id == 'save-as-pdf-virtual';
    final buttonLabel = isVirtual
        ? 'Save as PDF'
        : (selectedPrinter == null
            ? 'Select a Printer to Print'
            : 'Print Now • $_copies ${_copies > 1 ? "Copies" : "Copy"} ($totalPages ${totalPages > 1 ? "Pages" : "Page"})');

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(
          isVirtual
              ? Icons.download_rounded
              : (selectedPrinter == null
                  ? Icons.print_disabled_outlined
                  : Icons.print_rounded),
          size: 20,
        ),
        label: Text(
          buttonLabel,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis,
        ),
        onPressed: () => _executePrint(context, isDark, selectedPrinter),
      ),
    );
  }

  void _saveSettingsAsDefault(BuildContext context, bool isDark) {
    final newSettings = PrintSettings(
      copies: _copies,
      paperSize: _paperSize,
      landscape: _landscape,
      color: _color,
      duplex: _duplexMode != DuplexMode.oneSided,
      duplexMode: _duplexMode,
      scalingMode: _scalingMode,
      quality: _quality,
      pageSelectionMode: _pageSelectionMode,
      customPageRange: _pageRangeController.text.trim(),
      pagesPerSheet: _pagesPerSheet,
    );
    ref.read(documentManagerProvider.notifier).updateSettings(newSettings);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Print settings saved as default',
          style: TextStyle(color: isDark ? Colors.black : Colors.white),
        ),
        backgroundColor: isDark ? Colors.white : Colors.black,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _executePrint(
    BuildContext context,
    bool isDark,
    PrinterDevice? targetPrinter,
  ) {
    // If 'Save as PDF' virtual printer is selected, export to device directly
    if (targetPrinter?.id == 'save-as-pdf-virtual') {
      _handleExportPdf(context);
      return;
    }

    if (targetPrinter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a destination printer first!')),
      );
      return;
    }

    final isUsb = targetPrinter.connectionType == PrinterConnectionType.usb;
    final jobId = 'job-${DateTime.now().millisecondsSinceEpoch}';

    // Enqueue print job into the Print Queue
    final printJob = PrintJob(
      id: jobId,
      name: widget.document.name,
      status: PrintJobStatus.printing,
      printerId: targetPrinter.id,
      printerName: targetPrinter.name,
      createdAt: DateTime.now(),
      copies: _copies,
      pageCount: widget.document.pageCount ?? 1,
      message: isUsb
          ? 'Rasterizing & transmitting to USB...'
          : 'Transmitting (${_quality.name.toUpperCase()}) via IPP...',
    );

    final printQueueNotifier = ref.read(printQueueProvider.notifier);
    final printerRegistryNotifier = ref.read(printerRegistryProvider.notifier);
    final bridge = ref.read(usbHostBridgeProvider);
    final usbPrinters = ref.read(printerRegistryProvider).usbPrinters;

    printQueueNotifier.addJob(printJob);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Submitted "${widget.document.name}" to ${targetPrinter.name}!',
          style: TextStyle(color: isDark ? Colors.black : Colors.white),
        ),
        backgroundColor: isDark ? Colors.white : Colors.black,
        duration: const Duration(seconds: 3),
      ),
    );

    final settings = PrintSettings(
      copies: _copies,
      paperSize: _paperSize,
      landscape: _landscape,
      color: _color,
      duplex: _duplexMode != DuplexMode.oneSided,
      duplexMode: _duplexMode,
      scalingMode: _scalingMode,
      quality: _quality,
      pageSelectionMode: _pageSelectionMode,
      customPageRange: _pageRangeController.text.trim(),
      pagesPerSheet: _pagesPerSheet,
    );

    // If USB printer, execute transmission directly
    if (isUsb) {
      final matchedUsb = usbPrinters.cast<UsbPrinterDevice?>().firstWhere(
                (u) =>
                    u != null &&
                    (u.deviceId == targetPrinter.usbDeviceId ||
                        (targetPrinter.vendorId != null &&
                            targetPrinter.productId != null &&
                            u.vendorId == targetPrinter.vendorId &&
                            u.productId == targetPrinter.productId) ||
                        'usb-${u.deviceId}' == targetPrinter.id ||
                        targetPrinter.id
                            .contains(u.vendorId.toRadixString(16))),
                orElse: () => null,
              ) ??
          (usbPrinters.isNotEmpty
              ? usbPrinters.first
              : UsbPrinterDevice.fromPrinterDevice(targetPrinter));

      final transport = UsbPrintTransport(
        device: matchedUsb,
        bridge: bridge,
      );

      final request = PrintRequest(
        jobName: widget.document.name,
        filePath: widget.document.filePath,
        mimeType: widget.document.mimeType,
        printerId: targetPrinter.id,
        settings: settings,
      );

      transport.submit(
        request,
        onProgress: (current, total, stage) {
          printQueueNotifier.updateJobStatus(
            jobId,
            PrintJobStatus.printing,
            message: stage,
            sheetsCompleted: current,
          );
        },
      ).then((result) {
        printQueueNotifier.updateJobStatus(
          jobId,
          result.accepted ? PrintJobStatus.completed : PrintJobStatus.failed,
          message: result.message,
        );
      }).catchError((err) {
        printQueueNotifier.updateJobStatus(
          jobId,
          PrintJobStatus.failed,
          message: 'USB Print Error: $err',
        );
      });
    } else {
      // Wi-Fi / Network IPP printer transmission
      final ippClient = IppClient();
      final docFile = File(widget.document.filePath);
      docFile.readAsBytes().then((bytes) async {
        final printerState = ref.read(printerRegistryProvider);
        var caps = printerState.capabilitiesMap[targetPrinter.id];
        if (caps == null) {
          try {
            caps = await ippClient.getCapabilities(targetPrinter);
            printerRegistryNotifier.setPrinterCapabilities(
                targetPrinter.id, caps);
          } catch (_) {
            caps = PrinterCapabilities(
              printerName: targetPrinter.name,
              operationsSupported: const [0x0002],
              documentFormats: const [
                'application/pdf',
                'application/octet-stream',
              ],
            );
          }
        }

        final supportsPdf = caps.documentFormats.contains('application/pdf');
        final List<int> jobBytes;
        final String submitMime;

        if (supportsPdf &&
            _pageSelectionMode == PageSelectionMode.all &&
            _pagesPerSheet == PagesPerSheet.one &&
            widget.document.mimeType.contains('pdf')) {
          // Direct PDF submission
          jobBytes = await docFile.readAsBytes();
          submitMime = 'application/pdf';
        } else {
          // Rasterized submission (PWG-Raster or PCL)
          printQueueNotifier.updateJobStatus(
            jobId,
            PrintJobStatus.printing,
            message: 'Rasterizing document for Wi-Fi printer...',
          );
          const rasterEngine = DocumentRasterizerEngine();
          final rasterBytes = await rasterEngine.rasterizeDocument(
            filePath: widget.document.filePath,
            mimeType: widget.document.mimeType,
            settings: settings,
            device: targetPrinter,
            jobName: widget.document.name,
            onProgress: (current, total) {
              printQueueNotifier.updateJobStatus(
                jobId,
                PrintJobStatus.printing,
                message: 'Rasterizing sheet $current of $total...',
                sheetsCompleted: current,
              );
            },
          );

          final supportsPwg = caps.documentFormats.contains('image/pwg-raster');
          final supportsUrf = caps.documentFormats.contains('image/urf');

          if (supportsPwg) {
            submitMime = 'image/pwg-raster';
            jobBytes = rasterBytes;
          } else if (supportsUrf) {
            submitMime = 'image/urf';
            jobBytes = rasterBytes;
          } else {
            submitMime = caps.documentFormats.isNotEmpty
                ? caps.documentFormats.first
                : 'application/octet-stream';
            jobBytes = rasterBytes;
          }
        }

        final jobIdNum = await ippClient.submitJob(
          printer: targetPrinter,
          capabilities: caps,
          jobName: widget.document.name,
          mimeType: submitMime,
          documentBytes: jobBytes,
          copies: _copies,
        );

        printQueueNotifier.updateJobStatus(
          jobId,
          PrintJobStatus.completed,
          message: 'IPP Job #$jobIdNum finished successfully',
        );
      }).catchError((err) {
        printQueueNotifier.updateJobStatus(
          jobId,
          PrintJobStatus.failed,
          message: 'Network Print Error: $err',
        );
      });
    }
  }

  Future<void> _handleExportPdf(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const exporter = FileExporterService();

    try {
      final savedPath = await exporter.exportDocument(widget.document);
      if (savedPath != null && context.mounted) {
        Navigator.of(context).pop();
        final displayPath = savedPath.contains('/BurePrint/')
            ? 'BurePrint/${savedPath.split('/').last}'
            : savedPath;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PDF exported successfully to $displayPath',
              style: TextStyle(color: isDark ? Colors.black : Colors.white),
            ),
            backgroundColor: isDark ? Colors.white : Colors.black,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to export PDF: $e',
              style: TextStyle(color: isDark ? Colors.black : Colors.white),
            ),
            backgroundColor: isDark ? Colors.white : Colors.black,
          ),
        );
      }
    }
  }
}
