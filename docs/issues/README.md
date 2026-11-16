# BurePrint Junior & Intern Engineering Issues

Welcome! This directory contains ready-to-assign GitHub Issue specifications for junior engineers and interns contributing to the **BurePrint** project.

Each issue is structured with:
- **Background & User Story**
- **Architecture Boundaries & Strict Constraints**
- **Step-by-Step Implementation Guide** with exact files and code snippets
- **Testing & Verification Expectations**
- **Definition of Done (DoD) Checklist**

---

## Available Issues & Feature Epics

| # | Feature / Issue Title | Difficulty | Est. Days | Key Files / Areas | Spec File |
| :---: | :--- | :---: | :---: | :--- | :---: |
| **01** | **Direct Raw Socket TCP (Port 9100 / JetDirect)**<br>Direct printing to office network printers without IPP | ⭐⭐ | 3–5d | `domain/interfaces/`<br>`data/network/`<br>`features/printers/` | [01-raw-tcp-jetdirect.md](file:///home/abe-z/Projects/bureprint/docs/issues/01-raw-tcp-jetdirect.md) |
| **02** | **Bluetooth SPP / BLE Printing**<br>Wireless printing for mobile receipt & label printers | ⭐⭐⭐ | 5–7d | `MainActivity.kt`<br>`platform/bluetooth/`<br>`core/raster/` | [02-bluetooth-spp-ble.md](file:///home/abe-z/Projects/bureprint/docs/issues/02-bluetooth-spp-ble.md) |
| **03** | **In-App Web Page & HTML Printing**<br>Built-in browser to print web pages, tickets & online receipts | ⭐⭐ | 3–4d | `features/web/`<br>`core/document/`<br>`MainActivity.kt` | [03-in-app-web-html-printing.md](file:///home/abe-z/Projects/bureprint/docs/issues/03-in-app-web-html-printing.md) |
| **04** | **Local Microsoft Office Document Rendering**<br>Local parsing & printing for DOCX, XLSX & PPTX files | ⭐⭐⭐ | 5–7d | `core/document/`<br>`core/raster/`<br>`test/document/` | [04-office-docs-local-rendering.md](file:///home/abe-z/Projects/bureprint/docs/issues/04-office-docs-local-rendering.md) |

---

## Engineering Rules for Contributors

Before submitting a Pull Request, all contributors must adhere to:
1. **Rule 1**: Zero cloud dependencies. All rendering and processing must happen locally on device.
2. **Rule 2**: `dart format --set-exit-if-changed lib test` must pass cleanly.
3. **Rule 3**: `flutter analyze` must report zero errors and zero warnings.
4. **Rule 4**: Unit tests covering new logic must be included in `test/`.
5. **Rule 5**: Always verify protocol negotiation before transmitting bytes to unknown endpoints to protect hardware safety.
