# BurePrint Testing Strategy & Verification Report

## 1. Overview
BurePrint enforces strict automated testing across all architecture layers: domain models, IPP binary encoders/decoders, network transports, document processing engines, print queue state machines, and hardware safety layers.

---

## 2. Test Suites Summary

| Test Suite | File Path | Focus & Coverage |
|---|---|---|
| **Domain Models** | `test/domain_models_test.dart` | Print job 11-stage lifecycle, copyWith, equality, JSON round-trips, endpoint URI generation across security policies, capability predicates. |
| **IPP Codec** | `test/ipp/ipp_codec_test.dart` | RFC 8010 binary decoding, response fixtures, malformed packet detection, request encoding, repeated attributes, attached document payloads. |
| **Network & IPP Client** | `test/network/ipp_client_test.dart` | Get-Printer-Attributes capability query, capability-driven two-step submission (`Create-Job` + `Send-Document`), single-step fallback (`Print-Job`), and unsupported MIME type error prevention. |
| **Document Pipeline** | `test/document/document_pipeline_test.dart` | Safe page range parsing, format negotiation logic (direct PDF vs PWG Raster vs unsupported), and deterministic temporary file deletion. |
| **Print Queue** | `test/queue/queue_provider_test.dart` | Queue state machine transitions, asynchronous persistence via `PrintJobQueueStorage`, user cancellation requests, and safe batch cleanup of completed jobs. |
| **USB & Hardware Safety** | `test/usb/usb_transport_test.dart` | IPP-over-USB acceptance, permission verification, and safety rejection of raw byte dumping to unverified USB endpoints. |

---

## 3. Environment Execution Status & CI Validation

### Local Environment Note
- The host shell environment lacks locally installed `flutter` and `dart` binaries (`which: no flutter/dart in $PATH`).
- Therefore, in strict compliance with our **Agent Instructions Rule 5**, tests were **not executed locally** and are not falsely claimed to have run.

### GitHub Actions CI Verification
All written tests are structured as standard `package:flutter_test` unit tests conforming to Dart syntax and `flutter_lints` standards. They execute automatically in the GitHub Actions pipeline defined in [`.github/workflows/flutter-ci.yml`](file:///home/abe-z/Projects/bureprint/.github/workflows/flutter-ci.yml) upon push or pull request:
```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --coverage
```

---

## 4. Hardware Verification Distinction

- Automated unit and integration tests validate binary encoding and logic flows.
- Compatibility claims for physical printers remain marked as **"Not tested"** in [`docs/supported-printers.md`](file:///home/abe-z/Projects/bureprint/docs/supported-printers.md) until tested and verified with real physical devices.
