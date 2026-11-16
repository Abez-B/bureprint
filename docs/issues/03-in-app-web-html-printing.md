# Issue: Implement In-App Web Browser & HTML Page Printing

- **Labels**: `enhancement`, `feature`, `presentation`, `document-processing`
- **Difficulty**: ⭐⭐ (Intermediate)
- **Estimated Effort**: 3–4 Days
- **Architecture Area**: `lib/features/web/`, `lib/core/document/`, `lib/platform/`

---

## 1. Background & User Story

As a mobile user, I frequently need to print web receipts, event tickets, flight itineraries, shipping confirmations, and online invoices directly from websites without having to take screenshots or manually download PDFs.

I want a built-in lightweight web browser inside BurePrint that lets me navigate to any URL (or view an HTML snippet) and tap a single "Print" button to convert the web page into a high-quality printable document.

---

## 2. Technical Context & Conversion Strategies

1. **In-App WebView**:
   - Flutter official package: `webview_flutter`.
   - Allows navigating, executing JavaScript, and loading custom HTML strings or remote URLs.
2. **Web-to-PDF Conversion on Android**:
   - Android native `WebView` provides `createPrintDocumentAdapter("WebPage")` or `PrintedPdfDocument`.
   - Alternatively, `window.print()` interception or headless canvas snapshotting.
   - Recommended robust approach:
     - Android platform channel: pass WebView ID or URL to Android `PrintDocumentAdapter` -> write to temporary PDF in cache -> pass to `UniversalPdfRenderer` and `PrintSettingsModal`.

---

## 3. Sub-Tasks & Step-by-Step Implementation

### Task 1: Add Dependency & Screen Scaffold
- File: `pubspec.yaml`: Add `webview_flutter: ^4.10.0`.
- File: `lib/features/web/web_print_screen.dart`:
  - Navigation bar: URL input field, Back, Forward, Refresh, and Page Title.
  - Floating Action Button or AppBar Action: `[ 🖨️ Print This Page ]`.
  - Progress bar showing page load progress.

### Task 2: Implement Platform Web-to-PDF Exporter
- File: `android/app/src/main/kotlin/com/example/bureprint/WebPrintBridge.kt`
  - MethodChannel: `com.example.bureprint/web_print`
  - Method: `convertWebPageToPdf(url: String, outputPath: String)`:
    - Uses Android `PrintAttributes` (Letter or A4, 300 DPI, margins 0).
    - Writes generated PDF directly to app cache.
- File: `lib/core/document/web_document_converter.dart`:
  - Exposes `Future<ImportedDocument> convertUrlToDocument(String url)`.
  - Exposes `Future<ImportedDocument> convertHtmlStringToDocument(String html)`.

### Task 3: Integration with Documents Screen & Home
- File: `lib/features/documents/documents_screen.dart`:
  - Add "Print Web Page / URL" to the Import popup menu.
  - Tapping opens `WebPrintScreen`.
- When user taps "Print This Page" in `WebPrintScreen`:
  - Show subtle loading dialog ("Rendering web page to print layout...").
  - Convert to temporary PDF in cache.
  - Register as `ImportedDocument`.
  - Open `PrintSettingsModal` ready to print!

---

## 4. Verification & Testing Requirements

1. **Widget Test**: `test/web/web_print_screen_test.dart`:
   - Verify URL text field accepts input.
   - Verify navigation buttons toggle enabled/disabled states.
   - Verify "Print This Page" triggers conversion callback.
2. **Security & Privacy**:
   - WebView storage/cookies must be private.
   - Generated temporary PDFs must be cleaned up by `TemporaryDocumentManager`.

---

## 5. Definition of Done Checklist

- [ ] `WebPrintScreen` implemented with URL navigation bar and loading indicator.
- [ ] Native Android Web-to-PDF print adapter implemented.
- [ ] Conversion directly registers as `ImportedDocument` and opens `PrintSettingsModal`.
- [ ] Temporary PDF files are strictly scoped to app cache and purged on cleanup.
- [ ] `flutter analyze` and widget tests pass cleanly.
