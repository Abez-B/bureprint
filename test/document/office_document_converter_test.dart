import 'package:flutter_test/flutter_test.dart';
import 'package:bureprint/core/document/office_document_converter.dart';

void main() {
  group('OfficeDocumentConverter Format Identification', () {
    test('identifies docx and doc files correctly', () {
      expect(
        OfficeDocumentConverter.isConvertibleOfficeDocument(
            '/path/to/report.docx'),
        isTrue,
      );
      expect(
        OfficeDocumentConverter.isConvertibleOfficeDocument(
            '/path/to/invoice.doc'),
        isTrue,
      );
    });

    test('identifies odt and rtf files correctly', () {
      expect(
        OfficeDocumentConverter.isConvertibleOfficeDocument(
            '/path/to/thesis.odt'),
        isTrue,
      );
      expect(
        OfficeDocumentConverter.isConvertibleOfficeDocument(
            '/path/to/letter.rtf'),
        isTrue,
      );
    });

    test('identifies plain text files correctly', () {
      expect(
        OfficeDocumentConverter.isConvertibleOfficeDocument(
            '/path/to/notes.txt'),
        isTrue,
      );
    });

    test('identifies office documents by MIME types', () {
      expect(
        OfficeDocumentConverter.isConvertibleOfficeDocument(
          '/path/to/file',
          'application/vnd.oasis.opendocument.text',
        ),
        isTrue,
      );
      expect(
        OfficeDocumentConverter.isConvertibleOfficeDocument(
          '/path/to/file',
          'application/rtf',
        ),
        isTrue,
      );
      expect(
        OfficeDocumentConverter.isConvertibleOfficeDocument(
          '/path/to/file',
          'text/plain',
        ),
        isTrue,
      );
    });

    test('rejects non-convertible file extensions and MIME types', () {
      expect(
        OfficeDocumentConverter.isConvertibleOfficeDocument(
            '/path/to/image.png'),
        isFalse,
      );
      expect(
        OfficeDocumentConverter.isConvertibleOfficeDocument(
            '/path/to/archive.zip'),
        isFalse,
      );
      expect(
        OfficeDocumentConverter.isConvertibleOfficeDocument(
          '/path/to/file',
          'application/octet-stream',
        ),
        isFalse,
      );
    });
  });
}
