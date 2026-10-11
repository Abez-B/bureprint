import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/document/file_exporter_service.dart';
import '../../core/document/file_picker_service.dart';
import '../../core/document/pdf_merge_service.dart';
import '../../domain/models/imported_document.dart';
import 'document_provider.dart';
import 'document_thumbnail_view.dart';
import 'print_settings_modal.dart';

final filePickerServiceProvider = Provider<FilePickerService>((ref) {
  return const SystemFilePickerService();
});

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docState = ref.watch(documentManagerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMultiSelecting = docState.isMultiSelecting;

    return Scaffold(
      appBar: isMultiSelecting
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancel Selection',
                onPressed: () => ref
                    .read(documentManagerProvider.notifier)
                    .clearMultiSelection(),
              ),
              title: Text('${docState.selectedIds.length} Selected'),
              actions: [
                if (docState.selectedIds.length < docState.documents.length)
                  IconButton(
                    icon: const Icon(Icons.select_all_outlined),
                    tooltip: 'Select All',
                    onPressed: () =>
                        ref.read(documentManagerProvider.notifier).selectAll(),
                  ),
                if (docState.selectedIds.length >= 2)
                  IconButton(
                    icon: const Icon(Icons.merge_type_outlined),
                    tooltip: 'Merge Selected Files',
                    onPressed: () {
                      final selectedDocs = docState.documents
                          .where((d) => docState.selectedIds.contains(d.id))
                          .toList();
                      _mergeDocuments(context, ref, selectedDocs);
                    },
                  ),
              ],
            )
          : AppBar(
              title: const Text('Documents'),
              actions: [
                if (docState.documents.isNotEmpty)
                  IconButton(
                    tooltip: docState.viewMode == DocumentViewMode.grid
                        ? 'Switch to List View'
                        : 'Switch to Grid View',
                    icon: Icon(
                      docState.viewMode == DocumentViewMode.grid
                          ? Icons.view_list_outlined
                          : Icons.grid_view_outlined,
                    ),
                    onPressed: () => ref
                        .read(documentManagerProvider.notifier)
                        .toggleViewMode(),
                  ),
                PopupMenuButton<DocumentPickMode>(
                  tooltip: 'Import',
                  icon: const Icon(Icons.add_circle_outline),
                  onSelected: (mode) => _pickFiles(context, ref, mode),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: DocumentPickMode.images,
                      child: Row(
                        children: [
                          Icon(Icons.photo_library_outlined, size: 20),
                          SizedBox(width: 10),
                          Text('Photos / Image'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: DocumentPickMode.documents,
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf_outlined, size: 20),
                          SizedBox(width: 10),
                          Text('PDF Document'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: DocumentPickMode.allFiles,
                      child: Row(
                        children: [
                          Icon(Icons.folder_open_outlined, size: 20),
                          SizedBox(width: 10),
                          Text('All Files'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
      body: docState.documents.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 64,
                    color: isDark
                        ? const Color(0xFF757575)
                        : const Color(0xFF9E9E9E),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No documents imported',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                      'Select an image from photos or import a PDF document.'),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: () =>
                            _pickFiles(context, ref, DocumentPickMode.images),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Open Photos / Image'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _pickFiles(
                            context, ref, DocumentPickMode.documents),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Open PDF Document'),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : docState.viewMode == DocumentViewMode.grid
              ? GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.68,
                  ),
                  itemCount: docState.documents.length,
                  itemBuilder: (context, index) {
                    final doc = docState.documents[index];
                    final isChecked = docState.selectedIds.contains(doc.id);
                    final isCurrentTarget =
                        docState.selectedDocument?.id == doc.id;

                    return Card(
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isChecked
                              ? (isDark ? Colors.white : Colors.black)
                              : isCurrentTarget
                                  ? (isDark
                                      ? const Color(0xFF888888)
                                      : const Color(0xFF444444))
                                  : (isDark
                                      ? const Color(0xFF333333)
                                      : const Color(0xFFE0E0E0)),
                          width: isChecked || isCurrentTarget ? 2.0 : 1.0,
                        ),
                      ),
                      child: InkWell(
                        onLongPress: () {
                          // Long press triggers multi-selection mode for merging
                          ref
                              .read(documentManagerProvider.notifier)
                              .toggleSelection(doc.id);
                        },
                        onTap: () {
                          if (isMultiSelecting) {
                            ref
                                .read(documentManagerProvider.notifier)
                                .toggleSelection(doc.id);
                          } else {
                            ref
                                .read(documentManagerProvider.notifier)
                                .selectDocument(doc);
                            PrintSettingsModal.show(context, doc);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Visual Document Thumbnail (PDF or Image)
                              Expanded(
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: DocumentThumbnailView(
                                        document: doc,
                                        width: double.infinity,
                                        height: double.infinity,
                                      ),
                                    ),
                                    if (isMultiSelecting)
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isChecked
                                                ? (isDark
                                                    ? Colors.white
                                                    : Colors.black)
                                                : (isDark
                                                    ? Colors.black87
                                                    : Colors.white70),
                                            border: Border.all(
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Icon(
                                            isChecked
                                                ? Icons.check
                                                : Icons.circle_outlined,
                                            size: 16,
                                            color: isChecked
                                                ? (isDark
                                                    ? Colors.black
                                                    : Colors.white)
                                                : Colors.transparent,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Filename and Action Menu row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          doc.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${doc.formattedFileSize}${doc.pageCount != null ? " · ${doc.pageCount} p" : ""}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark
                                                ? const Color(0xFF9E9E9E)
                                                : const Color(0xFF757575),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!isMultiSelecting)
                                    PopupMenuButton<String>(
                                      icon:
                                          const Icon(Icons.more_vert, size: 18),
                                      padding: EdgeInsets.zero,
                                      onSelected: (val) {
                                        if (val == 'settings') {
                                          PrintSettingsModal.show(context, doc);
                                        } else if (val == 'download') {
                                          _downloadDocument(context, doc);
                                        } else if (val == 'select') {
                                          ref
                                              .read(documentManagerProvider
                                                  .notifier)
                                              .toggleSelection(doc.id);
                                        } else if (val == 'remove') {
                                          ref
                                              .read(documentManagerProvider
                                                  .notifier)
                                              .removeDocument(doc.id);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(
                                          value: 'settings',
                                          child: Text('Print Settings'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'download',
                                          child: Text('Save / Download PDF'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'select',
                                          child: Text('Select for Merge'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'remove',
                                          child: Text('Remove'),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docState.documents.length,
                  itemBuilder: (context, index) {
                    final doc = docState.documents[index];
                    final isChecked = docState.selectedIds.contains(doc.id);
                    final isCurrentTarget =
                        docState.selectedDocument?.id == doc.id;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isChecked
                              ? (isDark ? Colors.white : Colors.black)
                              : isCurrentTarget
                                  ? (isDark
                                      ? const Color(0xFF888888)
                                      : const Color(0xFF444444))
                                  : (isDark
                                      ? const Color(0xFF333333)
                                      : const Color(0xFFE0E0E0)),
                          width: isChecked || isCurrentTarget ? 2.0 : 1.0,
                        ),
                      ),
                      child: ListTile(
                        onLongPress: () {
                          ref
                              .read(documentManagerProvider.notifier)
                              .toggleSelection(doc.id);
                        },
                        selected: isChecked || isCurrentTarget,
                        onTap: () {
                          if (isMultiSelecting) {
                            ref
                                .read(documentManagerProvider.notifier)
                                .toggleSelection(doc.id);
                          } else {
                            ref
                                .read(documentManagerProvider.notifier)
                                .selectDocument(doc);
                            PrintSettingsModal.show(context, doc);
                          }
                        },
                        leading: isMultiSelecting
                            ? Checkbox(
                                value: isChecked,
                                onChanged: (_) {
                                  ref
                                      .read(documentManagerProvider.notifier)
                                      .toggleSelection(doc.id);
                                },
                              )
                            : SizedBox(
                                width: 44,
                                height: 44,
                                child: DocumentThumbnailView(
                                  document: doc,
                                  width: 44,
                                  height: 44,
                                ),
                              ),
                        title: Text(
                          doc.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${doc.formattedFileSize}${doc.pageCount != null ? " · ${doc.pageCount} pages" : ""}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Save / Download PDF',
                              icon:
                                  const Icon(Icons.download_outlined, size: 20),
                              onPressed: () => _downloadDocument(context, doc),
                            ),
                            IconButton(
                              tooltip: 'Print Settings',
                              icon: const Icon(Icons.tune_outlined, size: 20),
                              onPressed: () =>
                                  PrintSettingsModal.show(context, doc),
                            ),
                            IconButton(
                              tooltip: 'Remove',
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => ref
                                  .read(documentManagerProvider.notifier)
                                  .removeDocument(doc.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _pickFiles(
    BuildContext context,
    WidgetRef ref,
    DocumentPickMode mode,
  ) async {
    final picker = ref.read(filePickerServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    try {
      final picked = await picker.pickFiles(mode: mode, allowMultiple: true);
      if (picked.isEmpty) return;

      for (final doc in picked) {
        ref.read(documentManagerProvider.notifier).addDocument(doc);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported ${picked.length} file(s) successfully',
              style: TextStyle(color: isDark ? Colors.black : Colors.white),
            ),
            backgroundColor: isDark ? Colors.white : Colors.black,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to pick file: $e',
              style: TextStyle(color: isDark ? Colors.black : Colors.white),
            ),
            backgroundColor: isDark ? Colors.white : Colors.black,
          ),
        );
      }
    }
  }

  Future<void> _mergeDocuments(
    BuildContext context,
    WidgetRef ref,
    List<ImportedDocument> docs,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const mergeService = LocalPdfMergeService();

    try {
      final merged = await mergeService.mergeDocuments(docs);
      ref.read(documentManagerProvider.notifier).addDocument(merged);
      ref.read(documentManagerProvider.notifier).clearMultiSelection();

      if (context.mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Merged ${docs.length} files into "${merged.name}"',
              style: TextStyle(color: isDark ? Colors.black : Colors.white),
            ),
            backgroundColor: isDark ? Colors.white : Colors.black,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'DOWNLOAD',
              textColor: isDark ? Colors.black : Colors.white,
              onPressed: () => _downloadDocument(context, merged),
            ),
          ),
        );
        // Automatically open print settings for the freshly merged document!
        PrintSettingsModal.show(context, merged);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to merge files: $e',
              style: TextStyle(color: isDark ? Colors.black : Colors.white),
            ),
            backgroundColor: isDark ? Colors.white : Colors.black,
          ),
        );
      }
    }
  }

  Future<void> _downloadDocument(
    BuildContext context,
    ImportedDocument doc,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const exporter = FileExporterService();

    try {
      final savedPath = await exporter.exportDocument(doc);
      if (savedPath != null && context.mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Saved to: $savedPath',
              style: TextStyle(color: isDark ? Colors.black : Colors.white),
            ),
            backgroundColor: isDark ? Colors.white : Colors.black,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Failed to download document: $e',
              style: TextStyle(color: isDark ? Colors.black : Colors.white),
            ),
            backgroundColor: isDark ? Colors.white : Colors.black,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
