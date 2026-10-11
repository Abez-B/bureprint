<p align="center">
  <img src="assets/brand/icon-512.png" width="128" height="128" alt="BurePrint Logo" style="border-radius: 24px;" />
</p>

<h1 align="center">BurePrint</h1>

<p align="center">
  <strong>Private, local-first mobile printing for Android. Free and open-source.</strong>
</p>

<p align="center">
  <a href="https://github.com/Abez-B/bureprint/actions"><img src="https://img.shields.io/badge/CI-Passing-22c55e.svg?style=flat-square&logo=githubactions&logoColor=white" alt="CI Status" /></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-%3E%3D3.4-02569B.svg?style=flat-square&logo=flutter&logoColor=white" alt="Flutter" /></a>
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-%3E%3D3.4-0175C2.svg?style=flat-square&logo=dart&logoColor=white" alt="Dart" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-000000.svg?style=flat-square" alt="License: MIT" /></a>
  <a href="https://tools.ietf.org/html/rfc8011"><img src="https://img.shields.io/badge/Protocol-IPP%2FIPPS%20RFC8011-blue.svg?style=flat-square" alt="RFC 8011" /></a>
  <a href="#privacy--security"><img src="https://img.shields.io/badge/Telemetry-Zero-black.svg?style=flat-square" alt="Zero Telemetry" /></a>
</p>

---

## 📖 Overview

**BurePrint** is an open-source, privacy-first mobile printing application inspired by the workflow of mobile utility print apps. The name *BurePrint* derives from the Swahili word **bure** (*“free / without charge”*), reflecting our commitment to zero-cloud, ad-free, account-free local computing.

Unlike conventional proprietary mobile printing suites, BurePrint processes all documents **100% on-device**. No PDF files, rendered raster slices, or print credentials ever leave your local network.

---

## ✨ Features & Capabilities

### 🖨️ Printing & Connectivity
- **RFC 8010/8011 IPP Client**: Pure Dart Internet Printing Protocol implementation with binary parser/encoder supporting `Get-Printer-Attributes`, `Print-Job`, `Create-Job`, `Send-Document`, and `Cancel-Job`.
- **IPPS & Transport Security**: Encrypted printing over TLS (port 631) with strict hostname validation and explicit downgrade warnings.
- **Manual IP / Host Printer Pairing**: Add network printers directly via Hostname/IP, Port, and Queue Resource Path (`/ipp/print`) when mDNS / DNS-SD broadcast fails.
- **Supply Level Telemetry**: Real-time marker level gauges for Black toner, Cyan, Magenta, and Yellow supplies parsed directly from IPP attributes.
- **Monochrome & Single-Purpose Detection**: Automatically identifies single-purpose monochrome printers, locks color toggles to prevent hardware errors, and streams optimized 1-bit/8-bit grayscale raster streams.
- **Android USB Host (OTG)**: Platform channel contract for direct bulk-endpoint printing and IPP-over-USB protocol communication.

### 📄 Document Processing & Preview
- **Reactive Document Preview Carousel**: True WYSIWYG sheet preview that calculates and renders exact aspect ratios for ISO A4, A3, A5, US Letter, Legal, Tabloid, 4×6", and 5×7".
- **Zero-Jitter Staged Preview**: Completely locked preview viewport stage—changing settings like Pages to Print, N-Up, Scale, or Paper Size never causes surrounding modal controls to shift.
- **N-Up Multi-Page Layout**: Render 1, 2, or 4 logical document pages per physical sheet with automatic layout division and sheet index stepping.
- **Page Selection & Filtering**: Flexible page filtering supporting *All Pages*, *Odd Only*, *Even Only*, and *Custom Ranges* (e.g. `1, 3-5, 8`).
- **Multi-File PDF Merge & Export**: Batch-select multiple PDFs, photos, or documents and merge them locally into a single organized document.
- **"Save as PDF" Virtual Printer**: Built-in virtual driver to export, save, or download re-composed and N-Up documents straight to local storage.

### 📱 Android Integration
- **Android Share Sheet (`ACTION_SEND` / `ACTION_SEND_MULTIPLE`)**: Share documents, PDFs, and photos straight into BurePrint from Chrome, WhatsApp, Drive, or Files.
- **Monochrome Material 3 System**: Clean, accessible high-contrast design system honoring system Dark and Light themes with pure `#000000` and `#FFFFFF` styling.

---

## 🔒 Privacy & Security First

| Guarantee | Policy in BurePrint |
|---|---|
| **Cloud Independence** | 100% on-device rendering; zero third-party cloud backends. |
| **Telemetry & Tracking** | **Zero.** No Google Analytics, Firebase, Sentry, or user tracking. |
| **Data Retention** | Temporary raster buffers and cache files are purged automatically upon job completion, failure, or cancellation. |
| **Network Safety** | Unknown endpoints are never probed with raw unvalidated bytes. Hardware protocol safety checks precede all transmissions. |

---

## 🏛️ Architecture

BurePrint adheres strictly to clean architectural separation and dependency inversion:

```
lib/
├── core/         # Routing (go_router), Theme (BurePrintTheme), and Engine Primitives
│   ├── document/ # PDF rasterizers, page-range parsers, file exporters, PDF mergers
│   └── ipp/      # RFC 8010 binary protocol parser and serializer
├── domain/       # Pure Dart domain entities and interfaces (Zero Flutter UI imports)
│   ├── models/   # PrintJob, PrinterDevice, PrinterCapabilities, PrintRequest, Settings
│   └── interfaces/ # PrintTransport, PrinterDiscovery contracts
├── data/         # IPP network client and persistence layers
├── platform/     # Android USB Host & Share Sheet platform channel bridges
└── features/     # Feature modules (Riverpod Notifiers & Material 3 UI)
    ├── home/
    ├── documents/
    ├── printers/
    ├── queue/
    └── settings/
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (`>= 3.4.0`)
- [Dart SDK](https://dart.dev) (`>= 3.4.0`)
- Android Studio / Android SDK (API 26+ for physical testing)

### Installation & Execution

```bash
# Clone repository
git clone https://github.com/Abez-B/bureprint.git
cd bureprint

# Install dependencies
flutter pub get

# Verify code analysis & formatting
dart format --output=none --set-exit-if-changed lib test
flutter analyze

# Run unit and widget test suite
flutter test

# Run application
flutter run
```

---

## 🧪 Testing

BurePrint maintains extensive test coverage across domain logic, protocol serialization, and reactive preview widgets:

```bash
flutter test
```

### Verified Test Suites:
- `test/domain_models_test.dart`: Serialization, equality, and state transitions of PrintJob, PrinterDevice, PrinterCapabilities, PrinterSupplyLevel, and PaperDimensions.
- `test/document/document_pipeline_test.dart`: Page selection engine (all, odd, even, custom ranges) and printer format capability negotiation.
- `test/document/document_preview_carousel_test.dart`: N-Up page grouping, responsive scaling, and carousel reactivity.
- `test/document/office_document_converter_test.dart`: Safe MIME type detection and format conversion pipelines.
- `test/document/file_exporter_service_test.dart`: Local storage document export and error handling.
- `test/ipp/ipp_codec_test.dart`: RFC 8010 binary decoding and encoding of IPP attributes and responses.
- `test/queue/queue_provider_test.dart`: Print job queue state machine, persistence, and cancellation lifecycles.

---

## 🤝 Contributing

Contributions are welcome! Please ensure all pull requests satisfy the **Definition of Done**:
1. `dart format --output=none --set-exit-if-changed lib test` passes cleanly.
2. `flutter analyze` reports 0 errors and 0 warnings.
3. Relevant unit/widget tests are included and all regression tests pass.
4. Strictly respects privacy safeguards (no telemetry, temp files cleaned).

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.
