---
name: usb-printing-compatibility
description: Guides USB OTG printer communication, Android USB Host device enumeration, permission flow, protocol identification, IPP-over-USB, vendor adapters, hardware testing, and compatibility matrix maintenance in BurePrint. Activate when developing USB features, printer driver backends, or updating hardware test results.
---

# Skill: USB Printing and Printer Compatibility

## Purpose
Directs the architecture, implementation, and empirical validation of USB OTG printer support, preventing hardware misuse and maintaining an evidence-based printer compatibility matrix.

---

## Hardware Safety Mandates

1. **NEVER SEND ARBITRARY BYTES**:
   - **Critical Directive**: Never dump raw document bytes (like raw PDF or PostScript) to an unverified USB endpoint. Doing so on unprepared printers causes paper runaways, firmware panics, or hundreds of pages of garbage text.
2. **Protocol Negotiation First**:
   - Attempt IPP-over-USB (USB class 7, subclass 1, protocol 4) where supported.
   - For vendor-specific protocols (ESC/POS, PCL, TSPL, CPCL), identify the device model and matching driver backend before opening data pipes.
3. **Honest Compatibility Reporting**:
   - Only document a printer as "Supported" in [docs/supported-printers.md](file:///home/abe-z/Projects/bureprint/docs/supported-printers.md) after successful verification on real physical hardware.
   - Disclose connection, tested firmware version, document types, and known limitations.

---

## USB Communication Architecture

```
[UI Screen] -> [PrintService] -> [UsbPrintTransport]
                                       | (MethodChannel)
                                       v
                              [Android UsbHostManager]
                                       |
                   +-------------------+-------------------+
                   |                                       |
          [IPP-over-USB Backend]               [Vendor Backend Adapter]
          (Standard IPP framed data)           (ESC/POS, PCL3GUI, etc.)
```

### Steps for USB Integration:
1. **Device Discovery & Filter**:
   - Filter devices matching USB Printer Class (`0x07`).
   - Extract `deviceId`, `vendorId`, `productId`, `manufacturerName`, and `productName`.
2. **Permission Request**:
   - Check if permission is already granted via `UsbManager.hasPermission()`.
   - If not, prompt the user with system dialog via `UsbManager.requestPermission()`.
3. **Descriptor & Protocol Inspection**:
   - Read interface descriptor:
     - Class 7, Subclass 1, Protocol 1: Unidirectional printer.
     - Class 7, Subclass 1, Protocol 2: Bidirectional printer.
     - Class 7, Subclass 1, Protocol 4: IPP-over-USB.
4. **Transport Streaming**:
   - Use bulk endpoints with appropriate transfer buffer sizes (typically 16KB-64KB chunks).
   - Check endpoint transfer results and handle timeouts gracefully.

---

## Updating the Compatibility Matrix

When physical hardware tests are performed, update [docs/supported-printers.md](file:///home/abe-z/Projects/bureprint/docs/supported-printers.md) with:
- Exact Printer Make & Model
- Connection Type (e.g. USB OTG via USB-C to USB-B)
- Negotiated Protocol / Backend
- Tested Input Formats (e.g., PDF direct, PWG raster)
- Result & Limitations (e.g., "Full duplex tested", "Only 300 DPI supported")
- Tester date / agent attribution
