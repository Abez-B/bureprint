# Issue: Implement Local Microsoft Office Document Rendering (DOCX, XLSX, PPTX)

- **Labels**: `enhancement`, `document-processing`, `local-first`, `privacy`
- **Difficulty**: ⭐⭐⭐ (Advanced / Parser)
- **Estimated Effort**: 5–7 Days
- **Architecture Area**: `lib/core/document/`, `lib/core/raster/`, `test/document/`

---

## 1. Background & User Story

As a privacy-conscious user printing confidential business contracts, spreadsheets, or presentations from my phone, I need to open and print Microsoft Office documents (`.docx`, `.xlsx`, `.pptx`) **completely locally on my device**, with zero data sent to external cloud conversion APIs.

Currently, BurePrint has an initial scaffold in `docx_converter.dart` and `office_document_converter.dart`, but it needs robust parsing and pagination for production formatting.

---

## 2. Technical Context & Office Open XML (OOXML)

Office files are `.zip` packages containing XML files:
1. **DOCX (Word)**:
   - `word/document.xml`: Paragraphs (`<w:p>`), Runs (`<w:r>`), Text (`<w:t>`), Tables (`<w:tbl>`).
   - Formatting: Bold (`<w:b>`), Italic (`<w:i>`), Size (`<w:sz>`), Alignment (`<w:jc>`).
2. **XLSX (Excel)**:
   - `xl/workbook.xml` & `xl/worksheets/sheet1.xml`: Cell data (`<c r="A1"><v>123</v></c>`).
   - `xl/sharedStrings.xml`: Lookup table for string values.
3. **PPTX (PowerPoint)**:
   - `ppt/slides/slide1.xml`: Slide shapes, text boxes, and images.

---

## 3. Sub-Tasks & Step-by-Step Implementation

### Task 1: Complete Pure Dart DOCX Flow Layout
- File: `lib/core/document/docx_converter.dart`
- Steps:
  1. Unzip document bytes using `package:archive`.
  2. Parse `word/document.xml` using `dart:convert` and XML event stream or DOM parser.
  3. Support flow elements:
     - Headings (H1, H2, H3 with custom font sizes).
     - Paragraphs with bold, italic, underline, strikethrough runs.
     - Bullet points and numbered lists (`<w:numPr>`).
     - Tables with column widths, borders, and cell text wrapping.
  4. Measure text using Flutter's `TextPainter` or pure Dart layout metrics.
  5. Flow lines onto paginated canvases (A4 / Letter size) and serialize to vector PDF.

### Task 2: Implement XLSX Spreadsheet Layout Engine
- File: `lib/core/document/xlsx_converter.dart`
- Steps:
  1. Unzip `.xlsx` file, read `xl/sharedStrings.xml` into memory.
  2. Parse sheet dimensions (e.g. `A1:F50`).
  3. Determine column widths and row heights.
  4. Render tabular gridlines with cell borders and text alignment.
  5. Paginate wide sheets: auto-fit columns to page width or paginate across sheets.

### Task 3: Android Native QuickLook Fallback (Optional Platform Booster)
- File: `android/app/src/main/kotlin/com/example/bureprint/OfficeDocumentBridge.kt`
- If a document contains complex 3D shapes or proprietary macros, leverage Android's built-in `PdfDocument` / print spooler services to render a pixel-perfect preview fallback.

### Task 4: Integrate with `UniversalPdfRenderer` & `FilePicker`
- File: `lib/core/document/universal_pdf_renderer.dart`:
  - When a `.docx` or `.xlsx` is passed, automatically convert to temporary PDF in cache.
  - Return exact page count and dimensions.
  - Carousel preview and rasterizer will then render pages seamlessly!

---

## 4. Verification & Testing Requirements

1. **Unit Tests**: `test/document/office_document_converter_test.dart`:
   - Test with sample fixtures:
     - Simple text paragraph `.docx`.
     - Multi-page document with headings and bullets.
     - Table with 3 columns and 5 rows.
     - 10-row spreadsheet `.xlsx`.
   - Verify non-empty output PDF and valid page count (`>= 1`).
2. **Privacy Audit**:
   - Verify zero network requests are made during conversion.
   - Verify temporary unzipped files are wiped from cache immediately after conversion.

---

## 5. Definition of Done Checklist

- [ ] DOCX parser extracts paragraphs, headings, bold/italic, lists, and tables.
- [ ] XLSX parser extracts sheets, shared strings, and renders paginated tables.
- [ ] Converted PDF feeds transparently into `DocumentPreviewCarousel` and `PrintSettingsModal`.
- [ ] Temporary files managed safely by `TemporaryDocumentManager`.
- [ ] Unit tests pass with test fixtures in `test/fixtures/office/`.
