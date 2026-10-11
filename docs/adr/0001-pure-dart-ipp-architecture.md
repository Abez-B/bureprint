# ADR 0001: Pure Dart IPP Protocol Architecture and Modular Printing Pipeline

## Status
Accepted

## Date
2026-10-11

## Context
BurePrint aims to provide private, local-first printing across Android devices over Wi-Fi (IPP/IPPS) and USB OTG. The project requires an RFC-compliant, reliable printing pipeline without depending on cloud servers or heavy native dependencies (such as C-based libcups).

During architectural alignment via `/grill-me`, we evaluated the implementation strategy for IPP/IPPS (RFC 8010 & RFC 8011), capability negotiation, transport security, and device transport abstraction.

## Decision

1. **Pure Dart IPP Codec & Client**:
   - Implement the IPP protocol stack (`lib/core/ipp/` or `lib/data/ipp/`) in pure Dart.
   - Decouple binary frame serialization/deserialization (versions, operation IDs, status codes, attribute groups, value tags, syntax parsing) from transport logic.
   - Maintain strict unit test coverage with binary fixture captures from real printers.

2. **Capability-Driven Dynamic Selection**:
   - Always query `Get-Printer-Attributes` (operation `0x000B`) first.
   - Inspect `operations-supported` to dynamically select between:
     - Two-step submission: `Create-Job` (`0x0005`) followed by `Send-Document` (`0x0006`).
     - Single-step submission: `Print-Job` (`0x0002`).
   - Never assume all printers support both modes. Handle incomplete jobs explicitly if `Send-Document` fails.

3. **Per-Printer Transport Security**:
   - Support per-printer transport configuration with secure defaults:
     - IPPS (port 631 over TLS) with strict certificate validation.
     - Optional printer-scoped certificate exceptions for self-signed embedded printer certificates.
     - Explicit user-configured fallback to plain IPP (HTTP), disabled by default and never silently downgraded.

4. **Fail-Safe Format Negotiation**:
   - Inspect `document-format-supported`.
   - If `application/pdf` is not advertised, do not force raw PDF transmission.
   - Provide a safe fail & prompt mechanism with format conversion options (PWG Raster / PCLm) only when confirmed supported by both the app's converter and the target printer.

5. **Transport Abstraction**:
   - The IPP protocol engine communicates via an abstract `ByteTransport` / `Socket` contract.
   - This enables the exact same pure Dart IPP frame encoder to execute over network HTTP/TLS sockets and Android USB bulk endpoints (IPP-over-USB).

## Consequences

### Positive
- Fully testable in Dart VM / Flutter unit tests without requiring Android emulators or physical printers.
- Cross-platform portability across Android, desktop, and CLI tools.
- Zero risk of untrusted arbitrary byte streams causing printer firmware crashes or paper runaways.
- Transparent security posture that protects user document contents from silent downgrades.

### Negative / Trade-offs
- Requires implementing and maintaining binary parser logic for IPP attribute types (integer, boolean, octetString, dateTime, resolution, rangeOfInteger, text, name, uri).
- Format rasterization (PDF to PWG Raster) must be handled locally when printers lack direct PDF support.
