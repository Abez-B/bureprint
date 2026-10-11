# Task Template: Security Review

Use this template when auditing code, external dependencies, or network communications for privacy and security risks.

---

## 1. Audit Target
- **Target Component**: [e.g., Network discovery, IPPS client, Temp file pipeline]
- **Auditor**: Security Reviewer Persona
- **Date**: [YYYY-MM-DD]

## 2. Threat Modeling & Attack Surface
- **External Inputs**: [e.g., mDNS broadcast packets, IPP HTTP responses, USB endpoint buffers]
- **Potential Vectors**:
  - Buffer over-allocation or integer overflow during binary parsing
  - Insecure network fallback (silent downgrade to unencrypted HTTP)
  - Information leakage via system logs (`logcat` / `print`)
  - Orphaned document remnants in shared storage

## 3. Checklist Verification
- [ ] **Privacy Default**: Zero third-party telemetry, tracking, or ad libraries.
- [ ] **Local-First Boundary**: Documents are never transmitted to unauthorized internet hosts.
- [ ] **Log Scrubbing**: No document text, images, PII, Wi-Fi credentials, or printer passwords logged.
- [ ] **Input Bounds Check**: Binary parsing explicitly checks byte lengths against packet buffer boundaries.
- [ ] **Secure Storage**: Sensitive preferences (if any) stored securely; temporary files kept in private app cache.
- [ ] **Deterministic Disposal**: All temporary document artifacts explicitly wiped on completion or error.

## 4. Findings & Remediation
- **Critical / High Severity**:
- **Medium / Low Severity**:
- **Recommendations**:

## 5. Security Verdict
- [ ] **PASS**: Meets BurePrint privacy and security standards.
- [ ] **FAIL / VETO**: Must be resolved prior to merge.
