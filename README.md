<p align="center">
  <img src="https://github.com/user-attachments/assets/e18e6324-69ba-4d09-8d2e-d647339a2b1c" width="128" height="128" alt="BurePrint Logo" style="border-radius: 24px;" />
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

**BurePrint** is an open-source, privacy-first mobile printing application designed for reliable printing across local Wi-Fi networks and direct USB OTG connections. The name *BurePrint* derives from the Swahili word **bure** (*“free / without charge”*), reflecting our commitment to zero-cloud, ad-free, account-free local computing.

Unlike conventional proprietary mobile printing suites, BurePrint processes all documents **100% on-device**. No PDF files, rendered raster slices, or print credentials ever leave your phone or local network.

---

## ✨ Features & Capabilities

### 🖨️ Universal Printer Driver & Hardware Engine
Discovered printers are automatically matched to pure local drivers with visual engine verification badges:

| Driver Engine | Target Printer Families | Protocols & Commands | Status |
| :--- | :--- | :--- | :---: |
| **PWG Raster (`RaS2`)** | Universal IPP-over-USB, AirPrint, Mopria, HP OfficeJet/Envy | PWG 5102.4 `RaS2` standard bitstream | ✅ Verified |
| **Epson ESC/P-R** | Epson EcoTank (L3110, L3250), WorkForce, Stylus, XP | `ESC @`, `ESC ( G`, `ESC ( U`, `ESC .` raster | ✅ Verified |
| **Samsung SPL / QPDL** | Samsung ML, SCX, CLP, SL-M laser series | PJL wrapped SPL binary compression | ✅ Verified |
| **TSPL / TSPL2** | Thermal shipping label printers (TSC, Munbyn, Xprinter, Zebra) | TSPL `SIZE`, `GAP`, `BITMAP` 203 DPI commands | ✅ Verified |
| **HP PCL & Host-Based** | HP LaserJet, DeskJet, P1005/P1006/P1008/M1005 MFP | PCL3/5/6 and XQX / JBIG stream encoding | ✅ Verified |
| **Brother PJL** | Brother HL/DCP/MFC monochrome laser series | PJL header + brlaser delta raster bands | ✅ Verified |
| **Standard ESC/POS** | 58mm & 80mm mobile receipt printers | 256-dot vertical chunked raster bitstream | ✅ Verified |

### 🔌 Persistent USB OTG Streaming Architecture
- **Held-Open Hardware Sessions**: Native Android USB Host bridge (`MainActivity.kt` & `usb_host_bridge.dart`) maintains a persistent hardware session across all 256 KB Binder chunks. This prevents hardware FIFO buffer resets and stops printers from prematurely ejecting sheets before completion.
- **Full-Sheet Canvas Compositing**: Composites 1-Up prints onto padded true-geometry canvases to eliminate page truncation across fixed-frame printer engines.

### 📄 Document Processing & Responsive Preview
- **Reactive Document Preview**: True WYSIWYG sheet preview that calculates and renders exact aspect ratios for ISO A4, A3, A5, US Letter, Legal, Tabloid, Photo 4×6", Photo 5×7", and 58mm/80mm thermal rolls.
- **Streamlined Print Options UI**: Clean separation of primary controls (Printer, Copies stepper, Paper Size, Orientation, Color mode) from an expandable **Advanced Settings** accordion (Pages to print dropdown, Duplex mode, N-Up sheet layouts, Scaling modes, Print quality, Collation).
- **Zero-Overflow Mobile Layout**: Sized for responsive mobile viewports (360–420dp) with zero text wrapping glitches or layout shifts.
- **Built-in Diagnostic Test Page**: One-tap diagnostic sheet featuring CMYK/RGB calibration wedges, grayscale density gradient, 360° nozzle radial star, line frequency ladders, micro-type ladder (4pt–17pt), margin rulers (cm/in), corner alignment targets, and an emerald green bottom-of-page verification banner.
- **Multi-File PDF Merge & Export**: Batch-select multiple PDFs, photos, or documents and merge them locally into a single organized document.
- **"Save as PDF" Virtual Printer**: Built-in virtual driver to export, save, or download re-composed and N-Up documents straight to local storage.

### 📱 Android Integration
- **Android Share Sheet (`ACTION_SEND` / `ACTION_SEND_MULTIPLE`)**: Share documents, PDFs, and photos straight into BurePrint from Chrome, WhatsApp, Drive, or Files.
- **Monochrome Material 3 System**: Clean, accessible high-contrast design system honoring system Dark and Light themes.

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
├── core/         # Routing, theme, raster engine, and protocol primitives
│   ├── document/ # PDF rasterizers, page-range parsers, file exporters, test sheet loader
│   ├── ipp/      # RFC 8010/8011 binary protocol parser and serializer
│   └── raster/   # Multi-driver registry (PWG, Epson, Samsung, TSPL, HP, Brother, ESC/POS)
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

## 🗺️ Contributor Issues & Feature Roadmap

Ready-to-assign GitHub Issue specifications for junior engineers and interns are organized in [`docs/issues/`](docs/issues/README.md):

- [x] **Universal Multi-Brand USB Driver Engine**: Completed (PWG, ESC/P-R, SPL, TSPL, PCL, PJL, ESC/POS).
- [x] **Persistent USB OTG Session Streaming**: Completed.
- [x] **Printer Diagnostic & Alignment Test Sheet**: Completed.
- [ ] [Issue #1: Direct RAW TCP Socket Printing (Port 9100 / JetDirect)](docs/issues/01-raw-tcp-jetdirect.md)
- [ ] [Issue #2: Bluetooth SPP / BLE Printing for Mobile Thermal & Labelers](docs/issues/02-bluetooth-spp-ble.md)
- [ ] [Issue #3: In-App Web Browser & HTML Page Printing](docs/issues/03-in-app-web-html-printing.md)
- [ ] [Issue #4: Local Microsoft Office Document Support (DOCX, XLSX, PPTX)](docs/issues/04-office-docs-local-rendering.md)

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

# Run application on connected device
flutter run
```

---

## 🧪 Testing

BurePrint maintains extensive test coverage across domain logic, raster drivers, protocol serialization, and reactive preview widgets:

```bash
flutter test
```

### Verified Test Suites (78 Passing Tests):
- `test/raster/rasterizer_engine_test.dart`: End-to-end rasterization and protocol syntax verification for PWG Raster, Epson ESC/P-R, Samsung SPL, TSPL, Brother PJL, HP LaserJet P1000 XQX/JBIG, ESC/POS, and PCL.
- `test/usb/usb_transport_test.dart`: USB OTG permission flows, session management, and hardware safety rejections.
- `test/domain_models_test.dart`: Serialization, equality, and state transitions of PrintJob, PrinterDevice, PrinterCapabilities, and PaperDimensions.
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
3. Relevant unit/widget tests are included and all regression tests pass (`flutter test`).
4. Strictly respects privacy safeguards (no telemetry, temp files cleaned).

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.
