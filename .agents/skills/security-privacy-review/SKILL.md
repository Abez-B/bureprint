---
name: security-privacy-review
description: Guides threat modeling, local-first document verification, network input validation, TLS security, sensitive data redaction, temporary file cleanup, dependency vulnerability scanning, and license compliance in BurePrint. Activate during security audits, PR reviews, network client changes, or dependency additions.
---

# Skill: Security and Privacy Review

## Purpose
Enforces BurePrint's core tenets: privacy by default, zero unauthorized data transmission, robust local document protection, and defense against untrusted network inputs.

---

## Security Review Checklist

### 1. Privacy & Data Handling
- [ ] **Zero Telemetry**: Verify no third-party trackers, analytics SDKs, crash reporters, or advertising frameworks exist.
- [ ] **Local-First Boundary**: Verify that documents never leave the local device network boundary.
- [ ] **Redacted Logging**: Ensure document contents, filenames containing PII, IP addresses, Wi-Fi credentials, and printer passwords are not printed to logcat, console, or error messages.

### 2. Network & Protocol Defense
- [ ] **Untrusted Input Validation**: All mDNS packets and IPP binary responses must be treated as untrusted network data. Verify that buffer lengths, string lengths, and attribute counts are validated before allocation.
- [ ] **Endpoint Validation**: Restrict network socket connections to user-selected printer endpoints; reject arbitrary URL redirection.
- [ ] **TLS Enforcement**: Default to TLS (`ipps://`). If insecure `ipp://` fallback is permitted, ensure a user warning is displayed.

### 3. Filesystem & Temporary Assets
- [ ] **Temporary Directory Isolation**: Document conversions and temp files must reside in the sandboxed app cache directory (`context.cacheDir`).
- [ ] **Guaranteed Purge**: Temporary files must be deleted in a `finally` block or when jobs complete, fail, or cancel.
- [ ] **Startup Cleanup**: The app must scan and purge orphaned cache files on startup.

### 4. Dependencies & Licensing
- [ ] **License Compatibility**: Ensure all dependencies in `pubspec.yaml` have permissive licenses compatible with Apache-2.0 (MIT, BSD-3-Clause, Apache-2.0). Reject viral or non-commercial licenses (GPLv3, AGPL, CC-BY-NC).
- [ ] **Supply Chain Audit**: Keep dependency trees small and audited.

---

## Step-by-Step Audit Workflow

1. Run git diff review targeting data flows, log statements, and file writes.
2. Search for any network requests using external internet domains.
3. Review temporary file paths and verify disposal lifecycles.
4. Execute static analysis and automated dependency audits.

```bash
# Check dependencies and license status
flutter pub deps
```
