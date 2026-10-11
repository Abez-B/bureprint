import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/imported_document.dart';
import '../../domain/models/print_request.dart';

enum DocumentViewMode { list, grid }

class DocumentState {
  const DocumentState({
    this.documents = const [],
    this.selectedDocument,
    this.selectedIds = const {},
    this.currentSettings = const PrintSettings(),
    this.viewMode = DocumentViewMode.list,
  });

  final List<ImportedDocument> documents;
  final ImportedDocument? selectedDocument;
  final Set<String> selectedIds;
  final PrintSettings currentSettings;
  final DocumentViewMode viewMode;

  bool get isMultiSelecting => selectedIds.isNotEmpty;

  DocumentState copyWith({
    List<ImportedDocument>? documents,
    ImportedDocument? selectedDocument,
    Set<String>? selectedIds,
    PrintSettings? currentSettings,
    DocumentViewMode? viewMode,
  }) {
    return DocumentState(
      documents: documents ?? this.documents,
      selectedDocument: selectedDocument ?? this.selectedDocument,
      selectedIds: selectedIds ?? this.selectedIds,
      currentSettings: currentSettings ?? this.currentSettings,
      viewMode: viewMode ?? this.viewMode,
    );
  }
}

class DocumentManagerNotifier extends Notifier<DocumentState> {
  @override
  DocumentState build() {
    return const DocumentState();
  }

  void addDocument(ImportedDocument document) {
    state = state.copyWith(
      documents: [document, ...state.documents],
      selectedDocument: document,
    );
  }

  void selectDocument(ImportedDocument? document) {
    state = state.copyWith(selectedDocument: document);
  }

  void toggleSelection(String documentId) {
    final updated = Set<String>.from(state.selectedIds);
    if (updated.contains(documentId)) {
      updated.remove(documentId);
    } else {
      updated.add(documentId);
    }
    state = state.copyWith(selectedIds: updated);
  }

  void selectAll() {
    state = state.copyWith(
      selectedIds: state.documents.map((d) => d.id).toSet(),
    );
  }

  void clearMultiSelection() {
    state = state.copyWith(selectedIds: {});
  }

  void toggleViewMode() {
    state = state.copyWith(
      viewMode: state.viewMode == DocumentViewMode.list
          ? DocumentViewMode.grid
          : DocumentViewMode.list,
    );
  }

  void setViewMode(DocumentViewMode mode) {
    state = state.copyWith(viewMode: mode);
  }

  void updateSettings(PrintSettings settings) {
    state = state.copyWith(currentSettings: settings);
  }

  void removeDocument(String documentId) {
    final remaining = state.documents.where((d) => d.id != documentId).toList();
    state = state.copyWith(
      documents: remaining,
      selectedDocument: state.selectedDocument?.id == documentId
          ? (remaining.isNotEmpty ? remaining.first : null)
          : state.selectedDocument,
    );
  }
}

final documentManagerProvider =
    NotifierProvider<DocumentManagerNotifier, DocumentState>(
  DocumentManagerNotifier.new,
);
