# Task Template: IPP Protocol Implementation

Use this template when implementing or extending IPP/IPPS client operations, attribute parsers, or status pollers.

---

## 1. Protocol Operation
- **IPP Version**: [e.g., IPP/1.1 (RFC 8010/8011), IPP/2.0]
- **Operation**: [e.g., `Get-Printer-Attributes` (0x000B), `Print-Job` (0x0002), `Create-Job` (0x0005)]
- **Target Transport**: [HTTP/IPPS over TLS on port 631]

## 2. Capability Negotiation Strategy
- [ ] Queries `document-format-supported` before sending print payload
- [ ] Checks `media-supported`, `sides-supported`, and `copies-supported`
- [ ] Safe fallback when requested format (e.g. PDF) is unsupported

## 3. Input Validation & Packet Bounds Checks
- [ ] Binary packet header parsing verifies version, operation-id/status-code, and request-id
- [ ] Attribute group tags and value-length fields bounded against stream length
- [ ] Protection against truncated packets and malformed UTF-8 strings

## 4. Test Fixtures & Unit Tests
- [ ] Recorded raw binary response fixture added in `test/fixtures/ipp/`
- [ ] Unit tests verify decoding of standard printer responses (HP, Canon, Epson, Brother)
- [ ] Error response codes (`client-error-not-authorized`, `client-error-document-format-not-supported`) tested

## 5. Verification
- `dart format`: [Pass / Fail]
- `flutter analyze`: [Pass / Fail]
- `flutter test`: [Pass / Fail]
- **Note**: Physical printer confirmation status noted in `docs/supported-printers.md`
