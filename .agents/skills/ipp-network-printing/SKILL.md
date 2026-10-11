---
name: ipp-network-printing
description: Guides IPP/IPPS client implementation, mDNS/DNS-SD discovery, printer attribute negotiation, print job submission, queue monitoring, TLS handling, and protocol error recovery in BurePrint. Activate when implementing network printer discovery, IPP requests, attributes parsing, or print submission.
---

# Skill: IPP and Network Printing

## Purpose
Directs the implementation of standards-compliant Internet Printing Protocol (IPP/1.1 and IPP/2.0+ via RFC 8010 & RFC 8011) over HTTP and HTTPS (IPPS), including mDNS discovery and capability negotiation.

---

## Key Principles & Guardrails

1. **Never Assume Capabilities**:
   - **Crucial Rule**: Never assume a discovered printer accepts `application/pdf`, `image/pwg-raster`, or `image/urf`.
   - Before submitting a job, the agent must query `Get-Printer-Attributes` and inspect `document-format-supported`.
2. **Untrusted Network Input**:
   - Parse binary IPP attribute frames using strict bounds checks to avoid buffer overflows or infinite loops on corrupted packets.
   - Enforce maximum byte limits on response payloads.
3. **Transport Security (TLS / IPPS)**:
   - Default to IPPS (`ipps://` on port 631).
   - If an insecure fallback to plain `ipp://` is requested, log clearly and require explicit user consent.
4. **Discovery vs. Capability**:
   - mDNS (`_ipp._tcp`, `_ipps._tcp`) discovery records (TXT records like `rp`, `pdl`, `ty`) provide hints, not authoritative guarantees. Authoritative capabilities must come from `Get-Printer-Attributes`.

---

## Step-by-Step Implementation Workflow

1. **mDNS / DNS-SD Discovery**:
   - Discover IPP services on local subnet.
   - Extract printer URI path (defaulting to `/ipp/print` if unspecified).
   - Allow manual host/IP and port entry for static setups.
2. **Capability Query (`Get-Printer-Attributes`)**:
   - Send IPP request with operation ID `0x000B` (`Get-Printer-Attributes`).
   - Request attributes:
     - `printer-name`, `printer-make-and-model`
     - `printer-state`, `printer-state-reasons`
     - `document-format-supported`
     - `media-supported`, `media-default`
     - `sides-supported` (duplex), `color-supported`
     - `copies-supported`, `printer-resolution-supported`
3. **Job Creation & Submission**:
   - Evaluate document format compatibility against `document-format-supported`.
   - Submit via single-step `Print-Job` (`0x0002`) or two-step `Create-Job` (`0x0005`) + `Send-Document` (`0x0006`).
4. **Job Status Tracking**:
   - Poll `Get-Job-Attributes` (`0x0009`) with exponential backoff until completion (`completed`, `aborted`, `canceled`).

---

## Validation & Testing

- **Binary Frame Unit Tests**: Test IPP request encoder and response decoder against recorded binary fixtures.
- **Error Condition Tests**:
  - Test timeout recovery when a network printer drops off mid-transfer.
  - Test `client-error-document-format-not-supported` (`0x040A`) response handling.
- **Physical Hardware Distinction**: Automated unit tests verify frame syntax; real network printing requires physical hardware test logs.
