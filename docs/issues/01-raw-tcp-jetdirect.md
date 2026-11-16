# Issue: Implement Direct RAW TCP Socket Printing (Port 9100 / HP JetDirect)

- **Labels**: `enhancement`, `network`, `good-first-issue`, `intern-friendly`
- **Difficulty**: ⭐⭐ (Intermediate)
- **Estimated Effort**: 3–5 Days
- **Architecture Area**: `lib/domain/interfaces/`, `lib/data/network/`, `lib/features/printers/`

---

## 1. Background & User Story

As a user with a networked office laser printer (HP LaserJet, Brother, Kyocera, Lexmark, Xerox) that has IPP disabled or unconfigured in corporate environments, I want to print directly to the printer's IP address on **TCP Port 9100 (HP JetDirect / AppSocket / RAW)**, so that I can print reliably without requiring mDNS or IPP protocol negotiation.

Currently, BurePrint supports **IPP/IPPS (Port 631)** and **USB OTG**, but office printers commonly listen on raw socket port 9100.

---

## 2. Architecture Boundaries & Constraints (Read Carefully!)

1. **Local-First & Safety First**: Never send random strings or test probes without user action. Validate IP addresses before connecting.
2. **Layering**:
   - `domain/models/printer_device.dart`: Add `PrinterConnectionType.rawTcp` or support port 9100 in `PrinterConnectionType.network`.
   - `domain/interfaces/print_transport.dart`: Implement a concrete `RawTcpPrintTransport`.
   - `data/network/raw_tcp_client.dart`: Handles raw socket I/O using pure Dart `dart:io` `Socket`.
   - `features/printers/`: Update "Add by IP/Host" dialog to allow specifying Port 9100 (Raw Socket).
3. **Driver Integration**: Connect raw socket transmission to `DocumentRasterizerEngine` (which generates PCL, PWG-Raster, Samsung SPL, or ESC/P-R based on printer brand).

---

## 3. Sub-Tasks & Step-by-Step Implementation

### Task 1: Extend Domain Models
- File: `lib/domain/models/printer_device.dart`
- In `PrinterConnectionType`, ensure `rawTcp` or `network` can carry a specific port (e.g., `port: 9100`).
- Add a helper `bool get isRawTcp => port == 9100 || connectionType == PrinterConnectionType.rawTcp;`.

### Task 2: Implement `RawTcpClient`
- File: `lib/data/network/raw_tcp_client.dart`
- Specifications:
  ```dart
  class RawTcpClient {
    const RawTcpClient({
      this.timeout = const Duration(seconds: 15),
      this.chunkSize = 64 * 1024, // 64 KB per socket write
    });

    final Duration timeout;
    final int chunkSize;

    /// Tests whether the printer is reachable on port 9100
    Future<bool> probePrinter(String host, int port);

    /// Streams raw rasterized print payload to the socket
    Future<void> sendBytes({
      required String host,
      required int port,
      required List<int> bytes,
      void Function(int sentBytes, int totalBytes)? onProgress,
    });
  }
  ```
- Important: Handle `SocketException`, `TimeoutException`, and socket write buffer draining (`await socket.flush()`).

### Task 3: Implement `RawTcpPrintTransport`
- File: `lib/data/network/raw_tcp_print_transport.dart`
- Implement `PrintTransport`:
  ```dart
  class RawTcpPrintTransport implements PrintTransport {
    // 1. Resolves driver via PrinterDriverRegistry
    // 2. Rasterizes document using DocumentRasterizerEngine
    // 3. Streams bytes via RawTcpClient to target host:port
  }
  ```

### Task 4: UI Integration in "Add Printer by IP/Host"
- File: `lib/features/printers/printers_screen.dart`
- In `_showAddPrinterDialog`:
  - Add a Protocol toggle: `[ IPP (Port 631) ]` vs `[ RAW JetDirect (Port 9100) ]`.
  - When RAW is selected, auto-fill port 9100.
  - Probe connection before saving.

---

## 4. Verification & Testing Requirements

1. **Unit Test**: `test/network/raw_tcp_client_test.dart`
   - Bind a temporary `ServerSocket.bind(InternetAddress.loopbackIPv4, 0)` in test.
   - Send mock raster bytes (e.g. 128 KB).
   - Assert all bytes are received intact and `onProgress` callbacks fire sequentially.
2. **Static Analysis**: `flutter analyze` must report **0 issues**.
3. **Format**: `dart format --set-exit-if-changed lib test` must pass.

---

## 5. Definition of Done Checklist

- [ ] `RawTcpClient` implemented with chunking, timeouts, and error handling.
- [ ] `RawTcpPrintTransport` implemented adhering to `PrintTransport` interface.
- [ ] UI allows manual entry and probing of port 9100 printers.
- [ ] Unit tests pass with 100% mocked server coverage.
- [ ] Documentation updated in `docs/supported-printers.md`.
