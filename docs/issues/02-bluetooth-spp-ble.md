# Issue: Implement Bluetooth Printing (RFCOMM SPP & BLE) for Mobile Thermal & Label Printers

- **Labels**: `enhancement`, `hardware`, `platform-android`, `bluetooth`
- **Difficulty**: ⭐⭐⭐ (Advanced / Hardware)
- **Estimated Effort**: 5–7 Days
- **Architecture Area**: `android/app/.../MainActivity.kt`, `lib/platform/bluetooth/`, `lib/features/printers/`

---

## 1. Background & User Story

As a mobile vendor, delivery courier, or warehouse worker using a portable Bluetooth receipt or label printer (58mm/80mm ESC/POS or 203 DPI TSPL/CPCL), I want to discover and pair Bluetooth printers directly inside BurePrint and print receipts and shipping labels wirelessly without needing Wi-Fi or USB cables.

---

## 2. Technical Context & Protocols

1. **Bluetooth Classic RFCOMM SPP (Serial Port Profile)**:
   - Standard UUID: `00001101-0000-1000-8000-00805F9B34FB` (SerialPortServiceClass_UUID).
   - Used by 95% of mobile receipt printers (Epson, Star, Xprinter, MUNBYN, GOOJPRT).
2. **Bluetooth Low Energy (BLE GATT)**:
   - Used by newer ultra-compact thermal labelers (Niimbot, Phomemo).
3. **Android Lifecycle & Permissions**:
   - Android 12+ (API 31+) requires `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT`.
   - Android 11 and below requires `ACCESS_FINE_LOCATION`.

---

## 3. Sub-Tasks & Step-by-Step Implementation

### Task 1: Android Platform Channel Bridge (Kotlin)
- File: `android/app/src/main/kotlin/com/example/bureprint/BluetoothHostBridge.kt` (or inside `MainActivity.kt`)
- Method Channel: `com.example.bureprint/bluetooth`
- Methods to implement:
  - `getPairedDevices()`: Returns list of already-bonded Bluetooth devices filtered by Major Device Class `0x0600` (Imaging/Printer) or name keywords.
  - `startDiscovery()` / `stopDiscovery()`: EventChannel broadcasting discovered devices.
  - `connect(address: String)`: Opens an RFCOMM socket using `device.createRfcommSocketToServiceRecord(SPP_UUID)` on a background coroutine dispatcher (`Dispatchers.IO`).
  - `sendBytes(address: String, bytes: ByteArray)`: Writes chunked byte streams with keep-alive socket.
  - `disconnect(address: String)`: Safely closes socket and frees resources.

### Task 2: Dart Platform Bridge & Domain Model
- File: `lib/platform/bluetooth/bluetooth_printer_device.dart`
  - Model: `BluetoothPrinterDevice(address, name, isBonded, type)`.
- File: `lib/platform/bluetooth/bluetooth_host_bridge.dart`
  - Abstract interface `BluetoothHostBridge` and `AndroidBluetoothHostBridge`.
- File: `lib/domain/models/printer_device.dart`
  - Add `PrinterConnectionType.bluetooth`.

### Task 3: Bluetooth Print Transport
- File: `lib/platform/bluetooth/bluetooth_print_transport.dart`
  - Implements `PrintTransport`.
  - Integrates with `EscPosRasterizer` (for 58mm/80mm receipts) and `TsplRasterizer` (for 203 DPI shipping labels).
  - Handles streaming in 512-byte or 1024-byte packets (Bluetooth MTU limits).

### Task 4: UI Discovery & Printers Tab
- File: `lib/features/printers/printers_screen.dart`
  - Add a dedicated **Bluetooth Printers** section.
  - "Scan Bluetooth" button with progress indicator.
  - List paired and available printers with pairing prompt.

---

## 4. Verification & Testing Requirements

1. **Unit Tests**:
   - `test/bluetooth/bluetooth_transport_test.dart` using a mock `FakeBluetoothHostBridge`.
   - Verify permission rejection handling.
   - Verify ESC/POS byte streaming.
2. **Android Lint**: Check Android runtime permissions gracefully prompt the user on Android 12–15.
3. **Zero Leaks**: Ensure `BluetoothSocket.close()` is always called in `finally` blocks.

---

## 5. Definition of Done Checklist

- [ ] Android Kotlin RFCOMM SPP bridge created with background coroutines.
- [ ] Dart `BluetoothHostBridge` and `BluetoothPrintTransport` implemented.
- [ ] Runtime permissions (`BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`) handled with user prompts.
- [ ] ESC/POS and TSPL rasterizers verified to route over Bluetooth.
- [ ] Unit tests pass with fake bridge.
