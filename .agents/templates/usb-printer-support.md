# Task Template: USB Printer Support

Use this template when implementing or extending Android USB Host printer communication or vendor adapters.

---

## 1. Device & Hardware Context
- **Target Device**: [Make, Model, Vendor ID (VID), Product ID (PID)]
- **USB Interface Class**: [e.g., Class 7 (Printer), Subclass 1, Protocol 4 (IPP-USB) or Protocol 2 (Bidirectional)]
- **Target Backend**: [e.g., IPP-over-USB / ESC/POS / PCL3GUI / TSPL]

## 2. Safety & Protocol Verification
- [ ] **Arbitrary Byte Guard**: Absolute prohibition against piping unvalidated raw PDF or image bytes to USB endpoints.
- [ ] Permission check implemented via Android `UsbManager.requestPermission()`.
- [ ] Interface detachment and connection closure guaranteed in `finally` / teardown blocks.

## 3. Implementation Checklist
- [ ] Kotlin MethodChannel / EventChannel handlers in `android/`
- [ ] Dart transport wrapper implementing `PrintTransport` in `lib/data/`
- [ ] Timeout and error handling for disconnected cables mid-job

## 4. Hardware Verification & Matrix Update
- **Automated Tests**: Unit tests for Dart channel abstraction with mock messenger.
- **Physical Test Results**:
  - Device tested: [Exact model & firmware]
  - Android version: [e.g., Android 14]
  - Result: [Pass / Partial / Fail]
- [ ] `docs/supported-printers.md` updated with empirical test results
