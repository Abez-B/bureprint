import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/document/file_exporter_service.dart';
import '../../data/ipp/ipp_client.dart';
import '../../domain/models/imported_document.dart';
import '../../domain/models/print_job.dart';
import '../../domain/models/print_request.dart';
import '../../domain/models/printer_capabilities.dart';
import '../../domain/models/printer_device.dart';
import '../../platform/usb/usb_host_bridge.dart';
import '../../platform/usb/usb_print_transport.dart';
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

  static const _supportedPaperSizes = [
    'iso_a4_210x297mm',
    'iso_a3_297x420mm',
    'iso_a5_148x210mm',
    'na_letter_8.5x11in',
    'na_legal_8.5x14in',
    'na_tabloid_11x17in',
    'na_index-4x6_4x6in',
    'na_5x7_5x7in',
  ];

  String _formatPaperName(String raw) {
    if (raw.contains('a4')) return 'A4 (210 × 297 mm)';
    if (raw.contains('a3')) return 'A3 (297 × 420 mm)';
    if (raw.contains('a5')) return 'A5 (148 × 210 mm)';
    if (raw.contains('letter')) return 'US Letter (8.5 × 11 in)';
    if (raw.contains('legal')) return 'US Legal (8.5 × 14 in)';
    if (raw.contains('tabloid')) return 'Tabloid (11 × 17 in)';
    if (raw.contains('4x6')) return 'Photo 4 × 6 in';
    if (raw.contains('5x7')) return 'Photo 5 × 7 in';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final printerState = ref.watch(printerRegistryProvider);
    final selectedPrinter = printerState.selectedPrinter;

    return Material(
      color: theme.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(
          color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.only(
            top: 16,
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.92,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Print Settings',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.document.name,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? const Color(0xFFBDBDBD)
                                : const Color(0xFF616161),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Save / Download PDF',
                    icon: const Icon(Icons.download_outlined),
                    onPressed: () => _handleExportPdf(context),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 16),

              // Content Area: Responsive Left Preview + Right Settings
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 420;
                    final previewWidget = DocumentPreviewCarousel(
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
                    );

                    final totalPages =
                        _resolvedTotalPages ?? widget.document.pageCount ?? 1;

                    final settingsControls = ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        // Copies Counter
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Copies',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            Row(
                              children: [
                                IconButton.outlined(
                                  icon: const Icon(Icons.remove, size: 18),
                                  onPressed: _copies > 1
                                      ? () => setState(() => _copies--)
                                      : null,
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Text(
                                    '$_copies',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                ),
                                IconButton.outlined(
                                  icon: const Icon(Icons.add, size: 18),
                                  onPressed: () => setState(() => _copies++),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Paper Size Preset
                        const Text('Paper Size',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _paperSize,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          items: _supportedPaperSizes.map((s) {
                            return DropdownMenuItem(
                              value: s,
                              child: Text(_formatPaperName(s)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _paperSize = val);
                          },
                        ),
                        const SizedBox(height: 14),

                        // Orientation Toggle
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Orientation',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(
                                    value: false, label: Text('Portrait')),
                                ButtonSegment(
                                    value: true, label: Text('Landscape')),
                              ],
                              selected: {_landscape},
                              onSelectionChanged: (val) =>
                                  setState(() => _landscape = val.first),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Color / Monochrome Toggle
                        Builder(builder: (context) {
                          final printerCaps = selectedPrinter != null
                              ? printerState.capabilitiesMap[selectedPrinter.id]
                              : null;
                          final isMonoOnly =
                              printerCaps != null && !printerCaps.supportsColor;

                          return SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Color Printing',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: isMonoOnly
                                ? const Text(
                                    'Printer is monochrome only',
                                    style: TextStyle(
                                        fontSize: 11, color: Color(0xFF888888)),
                                  )
                                : null,
                            value: isMonoOnly ? false : _color,
                            onChanged: isMonoOnly
                                ? null
                                : (val) => setState(() => _color = val),
                          );
                        }),
                        const SizedBox(height: 14),

                        // Pages to Print Filter (All, Odd Only, Even Only, Custom)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Pages to Print',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              '$totalPages ${totalPages == 1 ? "page" : "pages"} total',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFF9E9E9E)
                                    : const Color(0xFF757575),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SegmentedButton<PageSelectionMode>(
                          segments: const [
                            ButtonSegment(
                              value: PageSelectionMode.all,
                              label: Text('All'),
                            ),
                            ButtonSegment(
                              value: PageSelectionMode.oddOnly,
                              label: Text('Odd'),
                            ),
                            ButtonSegment(
                              value: PageSelectionMode.evenOnly,
                              label: Text('Even'),
                            ),
                            ButtonSegment(
                              value: PageSelectionMode.custom,
                              label: Text('Custom'),
                            ),
                          ],
                          selected: {_pageSelectionMode},
                          onSelectionChanged: (val) =>
                              setState(() => _pageSelectionMode = val.first),
                        ),
                        if (_pageSelectionMode == PageSelectionMode.custom) ...[
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _pageRangeController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Custom Range (e.g. 1-15, 18-19)',
                              hintText: 'e.g. 1-3, 5, 8-10',
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                            keyboardType: TextInputType.text,
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Advanced Settings Accordion
                        Theme(
                          data:
                              theme.copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding:
                                const EdgeInsets.only(top: 8, bottom: 8),
                            leading: const Icon(Icons.tune_outlined, size: 20),
                            title: const Text(
                              'Advanced Settings',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${_duplexMode == DuplexMode.oneSided ? "1-Sided" : "Duplex"} · ${_pagesPerSheet.displayName} · ${_scalingMode.displayName}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? const Color(0xFF9E9E9E)
                                    : const Color(0xFF757575),
                              ),
                            ),
                            children: [
                              // Duplex (Three-way switch with Visual Info Guide)
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Two-Sided (Duplex)',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  IconButton(
                                    icon: const Icon(Icons.info_outline,
                                        size: 20),
                                    tooltip: 'Duplex Flip Guide',
                                    onPressed: () =>
                                        DuplexInfoDialog.show(context),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: double.infinity,
                                child: SegmentedButton<DuplexMode>(
                                  segments: const [
                                    ButtonSegment(
                                        value: DuplexMode.oneSided,
                                        label: Text('1-Sided')),
                                    ButtonSegment(
                                        value: DuplexMode.longEdge,
                                        label: Text('Long Edge')),
                                    ButtonSegment(
                                        value: DuplexMode.shortEdge,
                                        label: Text('Short Edge')),
                                  ],
                                  selected: {_duplexMode},
                                  onSelectionChanged: (val) =>
                                      setState(() => _duplexMode = val.first),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // N-Up Pages Per Sheet Selector
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Pages Per Sheet (N-Up)',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                child: SegmentedButton<PagesPerSheet>(
                                  segments: const [
                                    ButtonSegment(
                                      value: PagesPerSheet.one,
                                      label: Text('1-Up'),
                                    ),
                                    ButtonSegment(
                                      value: PagesPerSheet.two,
                                      label: Text('2-Up'),
                                    ),
                                    ButtonSegment(
                                      value: PagesPerSheet.four,
                                      label: Text('4-Up'),
                                    ),
                                  ],
                                  selected: {_pagesPerSheet},
                                  onSelectionChanged: (val) => setState(
                                      () => _pagesPerSheet = val.first),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Page Scaling Mode
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Page Scaling',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<ScalingMode>(
                                initialValue: _scalingMode,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                ),
                                items: ScalingMode.values.map((mode) {
                                  return DropdownMenuItem(
                                    value: mode,
                                    child: Text(mode.displayName),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _scalingMode = val);
                                  }
                                },
                              ),
                              const SizedBox(height: 14),

                              // Print Quality Selector
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Print Quality',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<PrintQuality>(
                                initialValue: _quality,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                ),
                                items: PrintQuality.values.map((q) {
                                  return DropdownMenuItem(
                                    value: q,
                                    child: Text(q.displayName),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _quality = val);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    );

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 190,
                            height: 232,
                            child: Center(child: previewWidget),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: settingsControls),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        SizedBox(
                          height: 224,
                          width: double.infinity,
                          child: Center(child: previewWidget),
                        ),
                        const SizedBox(height: 8),
                        Expanded(child: settingsControls),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),
              // Target Printer Selector (Allows selecting between all available printers)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1E1E)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF333333)
                        : const Color(0xFFE0E0E0),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.print_outlined, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedPrinter?.id,
                              isDense: true,
                              isExpanded: true,
                              hint:
                                  const Text('Select a destination printer...'),
                              items: [
                                DropdownMenuItem<String>(
                                  value: PrinterRegistryNotifier
                                      .saveAsPdfPrinter.id,
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
                                  return DropdownMenuItem<String>(
                                    value: p.id,
                                    child: Text(
                                      '${p.name} (Saved)',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }),
                                ...printerState.discoveredPrinters
                                    .where((dp) => !printerState.savedPrinters
                                        .any((sp) => sp.id == dp.id))
                                    .map((p) {
                                  return DropdownMenuItem<String>(
                                    value: p.id,
                                    child: Text(
                                      '${p.name} (Discovered)',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (printerId) {
                                if (printerId == null) return;
                                if (printerId ==
                                    PrinterRegistryNotifier
                                        .saveAsPdfPrinter.id) {
                                  ref
                                      .read(printerRegistryProvider.notifier)
                                      .selectPrinter(PrinterRegistryNotifier
                                          .saveAsPdfPrinter);
                                  return;
                                }
                                final allPrinters = [
                                  ...printerState.savedPrinters,
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
                    if (selectedPrinter != null) ...[
                      if (printerState.capabilitiesMap[selectedPrinter.id]
                              ?.markerSupplies.isNotEmpty ??
                          false) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: printerState
                                .capabilitiesMap[selectedPrinter.id]!
                                .markerSupplies
                                .map((s) {
                              final color = Color(int.parse(
                                      s.colorHex
                                          .replaceFirst('#', '')
                                          .padLeft(6, '0'),
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
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black26,
                                          width: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    SizedBox(
                                      width: 28,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(2),
                                        child: LinearProgressIndicator(
                                          value: percent / 100.0,
                                          backgroundColor: isDark
                                              ? Colors.white12
                                              : Colors.black12,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
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
                      ] else if (printerState.capabilitiesMap
                          .containsKey(selectedPrinter.id)) ...[
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Icon(
                                (printerState
                                            .capabilitiesMap[selectedPrinter.id]
                                            ?.supportsColor ??
                                        false)
                                    ? Icons.palette_outlined
                                    : Icons.print_outlined,
                                size: 13,
                                color: isDark
                                    ? const Color(0xFF888888)
                                    : const Color(0xFF777777),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                (printerState
                                            .capabilitiesMap[selectedPrinter.id]
                                            ?.supportsColor ??
                                        false)
                                    ? 'Color Printer (Supply levels not reported)'
                                    : 'Monochrome Printer (Black Toner / Ink)',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? const Color(0xFF888888)
                                      : const Color(0xFF777777),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Print Action Buttons
              LayoutBuilder(
                builder: (context, actionConstraints) {
                  final isNarrow = actionConstraints.maxWidth < 360;

                  final saveBtn = OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 12),
                    ),
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Save Settings',
                        overflow: TextOverflow.ellipsis),
                    onPressed: () {
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
                      ref
                          .read(documentManagerProvider.notifier)
                          .updateSettings(newSettings);
                      Navigator.of(context).pop();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Print settings saved',
                            style: TextStyle(
                                color: isDark ? Colors.black : Colors.white),
                          ),
                          backgroundColor: isDark ? Colors.white : Colors.black,
                        ),
                      );
                    },
                  );

                  final printBtn = FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 12),
                    ),
                    onPressed: () {
                      final targetPrinter =
                          ref.read(printerRegistryProvider).selectedPrinter;

                      // If 'Save as PDF' virtual printer is selected, export to device directly
                      if (targetPrinter?.id == 'save-as-pdf-virtual') {
                        _handleExportPdf(context);
                        return;
                      }

                      if (targetPrinter == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please select a printer first!')),
                        );
                        return;
                      }

                      final isUsb = targetPrinter.connectionType ==
                          PrinterConnectionType.usb;
                      final jobId =
                          'job-${DateTime.now().millisecondsSinceEpoch}';

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

                      ref.read(printQueueProvider.notifier).addJob(printJob);
                      Navigator.of(context).pop();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Submitted "${widget.document.name}" to ${targetPrinter.name}!',
                            style: TextStyle(
                                color: isDark ? Colors.black : Colors.white),
                          ),
                          backgroundColor: isDark ? Colors.white : Colors.black,
                          duration: const Duration(seconds: 3),
                        ),
                      );

                      // If USB printer, execute transmission directly
                      if (isUsb) {
                        final usbPrinters =
                            ref.read(printerRegistryProvider).usbPrinters;
                        final matchedUsb = usbPrinters.firstWhere(
                          (u) =>
                              u.deviceId == targetPrinter.usbDeviceId ||
                              'usb-${u.deviceId}' == targetPrinter.id,
                          orElse: () => usbPrinters.first,
                        );

                        final bridge = ref.read(usbHostBridgeProvider);
                        final transport = UsbPrintTransport(
                          device: matchedUsb,
                          bridge: bridge,
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

                        final request = PrintRequest(
                          jobName: widget.document.name,
                          filePath: widget.document.filePath,
                          mimeType: widget.document.mimeType,
                          printerId: targetPrinter.id,
                          settings: settings,
                        );

                        transport.submit(request).then((result) {
                          ref.read(printQueueProvider.notifier).updateJobStatus(
                                jobId,
                                result.accepted
                                    ? PrintJobStatus.completed
                                    : PrintJobStatus.failed,
                                message: result.message,
                              );
                        }).catchError((err) {
                          ref.read(printQueueProvider.notifier).updateJobStatus(
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
                          var caps =
                              printerState.capabilitiesMap[targetPrinter.id];
                          if (caps == null) {
                            try {
                              caps = await ippClient
                                  .getCapabilities(targetPrinter);
                              ref
                                  .read(printerRegistryProvider.notifier)
                                  .setPrinterCapabilities(
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

                          final mime = widget.document.mimeType.contains('pdf')
                              ? 'application/pdf'
                              : 'application/octet-stream';

                          final jobIdNum = await ippClient.submitJob(
                            printer: targetPrinter,
                            capabilities: caps,
                            jobName: widget.document.name,
                            mimeType: mime,
                            documentBytes: bytes,
                            copies: _copies,
                          );

                          ref.read(printQueueProvider.notifier).updateJobStatus(
                                jobId,
                                PrintJobStatus.completed,
                                message:
                                    'IPP Job #$jobIdNum finished successfully',
                              );
                        }).catchError((err) {
                          ref.read(printQueueProvider.notifier).updateJobStatus(
                                jobId,
                                PrintJobStatus.failed,
                                message: 'Network Print Error: $err',
                              );
                        });
                      }
                    },
                    icon: Icon(selectedPrinter?.id == 'save-as-pdf-virtual'
                        ? Icons.download_rounded
                        : (selectedPrinter == null
                            ? Icons.print_disabled_outlined
                            : Icons.print)),
                    label: Text(
                      selectedPrinter?.id == 'save-as-pdf-virtual'
                          ? 'Save PDF'
                          : (selectedPrinter == null
                              ? 'Select Printer'
                              : 'Print Now'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        printBtn,
                        const SizedBox(height: 8),
                        saveBtn,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(flex: 2, child: saveBtn),
                      const SizedBox(width: 8),
                      Expanded(flex: 3, child: printBtn),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
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
            : savedPath.split('/').last;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: isDark ? Colors.black : Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Saved to $displayPath',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.black : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: isDark ? Colors.white : const Color(0xFF1E1E1E),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save PDF: $e',
              style: TextStyle(color: isDark ? Colors.black : Colors.white),
            ),
            backgroundColor: isDark ? Colors.white : Colors.black,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }
}
