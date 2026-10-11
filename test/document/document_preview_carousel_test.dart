import 'package:bureprint/domain/models/imported_document.dart';
import 'package:bureprint/domain/models/print_request.dart';
import 'package:bureprint/features/documents/document_preview_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final testDocument = ImportedDocument(
    id: 'test-doc-1',
    name: 'Sample.pdf',
    filePath: '/tmp/sample.pdf',
    fileSizeBytes: 1024,
    importedAt: DateTime(2026, 1, 1),
    mimeType: 'application/pdf',
    pageCount: 6,
  );

  group('DocumentPreviewCarousel UI & Settings Reactivity Tests', () {
    testWidgets('renders initial 1-Up sheet without crashing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentPreviewCarousel(
              document: testDocument,
              landscape: false,
              scalingMode: ScalingMode.fitPrintableArea,
              paperSize: 'iso_a4_210x297mm',
              pagesPerSheet: PagesPerSheet.one,
            ),
          ),
        ),
      );

      expect(find.byType(DocumentPreviewCarousel), findsOneWidget);
      expect(find.text('A4'), findsOneWidget);
    });

    testWidgets('updates badge and sheet calculation for 2-Up and 4-Up',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentPreviewCarousel(
              document: testDocument,
              landscape: false,
              scalingMode: ScalingMode.fitPrintableArea,
              paperSize: 'iso_a4_210x297mm',
              pagesPerSheet: PagesPerSheet.two,
            ),
          ),
        ),
      );

      expect(find.text('2-Up'), findsOneWidget);

      // Re-pump with 4-Up
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentPreviewCarousel(
              document: testDocument,
              landscape: false,
              scalingMode: ScalingMode.fitPrintableArea,
              paperSize: 'iso_a4_210x297mm',
              pagesPerSheet: PagesPerSheet.four,
            ),
          ),
        ),
      );

      expect(find.text('4-Up'), findsOneWidget);
    });

    testWidgets('renders originalSize scaling without throwing overflow',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentPreviewCarousel(
              document: testDocument,
              landscape: true,
              scalingMode: ScalingMode.originalSize,
              paperSize: 'na_letter_8.5x11in',
              pagesPerSheet: PagesPerSheet.one,
            ),
          ),
        ),
      );

      expect(find.byType(DocumentPreviewCarousel), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
