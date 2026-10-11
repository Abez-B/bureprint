import 'office_document_converter.dart';

/// Backward-compatible alias/delegate for DocxToPdfConverter.
class DocxToPdfConverter {
  const DocxToPdfConverter._();

  static const DocxToPdfConverter instance = DocxToPdfConverter._();

  static bool isDocxFile(String path, [String? mimeType]) {
    return OfficeDocumentConverter.isConvertibleOfficeDocument(path, mimeType);
  }

  Future<String?> convertToPdf(String inputPath) {
    return OfficeDocumentConverter.instance.convertToPdf(inputPath);
  }
}
