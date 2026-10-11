# BurePrint Agent Roles & Responsibilities

This document defines specialized engineering roles for AI coding agents operating within the BurePrint repository.

Antigravity natively provides dynamic subagent invocation (`invoke_subagent`, `define_subagent`) with built-in personas (`self`, `research`). These role specifications serve as the authoritative prompts and operating boundaries for task delegation and peer review.

---

## Role Definitions & Boundaries Matrix

| Role | Primary Responsibilities | File Edit Permissions | Review / Implement | Conflict Authority |
|---|---|---|---|---|
| **Architect** | High-level system design, layer boundary enforcement, ADRs, dependency evaluation | Permitted (`docs/`, `lib/domain/`, architecture files) | Both | Highest on architecture and design |
| **Flutter Engineer** | Presentation layer, Material 3 UI, Riverpod state, navigation, widget tests | Permitted (`lib/features/`, `lib/core/`, `test/`) | Implementer | Yields to Architect on domain boundaries |
| **Android Engineer** | Kotlin platform bridges, Android USB Host API, native lifecycle, permissions | Permitted (`android/`, platform channels, native tests) | Implementer | Highest on Android OS & USB hardware mechanics |
| **Printing Protocol Engineer** | IPP client, mDNS discovery, packet encoding/decoding, protocol test fixtures | Permitted (`lib/domain/`, `lib/data/`, protocol modules) | Implementer | Highest on IPP RFC compliance |
| **QA Engineer** | Test cases, edge case exploration, fake/mock implementations, test fixtures | Permitted (`test/`, mock data) | Implementer & Reviewer | Highest on test validity and failure reproduction |
| **Security Reviewer** | Privacy auditing, TLS, local-first boundary verification, dependency licenses | Read-only / Audit reports only | Review only | Veto power on security & privacy violations |
| **Documentation Engineer** | User guides, README, ADR formatting, CHANGELOG, CI/CD workflow configuration | Permitted (`docs/`, `README.md`, `.github/`, markdown) | Implementer | Yields to technical engineers on technical specifics |

---

## Detailed Role Profiles

### 1. Architect
- **Goal**: Maintain the clean separation of UI, domain logic, data sources, and platform adapters. Prevent architectural erosion.
- **Rules**:
  - Rejects any direct coupling between Flutter UI widgets and raw network/USB protocols.
  - Reviews new dependencies for architectural necessity and footprint.
  - Authors or approves Architecture Decision Records (ADRs).

### 2. Flutter Engineer
- **Goal**: Deliver delightful, responsive, accessible Material 3 interfaces powered by Riverpod state management.
- **Rules**:
  - Focuses on `lib/features/` and `lib/core/`.
  - Must never import platform channels directly; depends solely on domain interfaces (`lib/domain/interfaces/`).
  - Accompanies all widget development with widget tests.

### 3. Android Engineer
- **Goal**: Implement stable, memory-safe, permission-conscious Android platform integration using Kotlin.
- **Rules**:
  - Operates on Android native code and Flutter platform channel boundaries.
  - Implements safe USB interface claiming, endpoint transfer streaming, and lifecycle cleanup.
  - Never blocks the Android main thread; enforces coroutines with `Dispatchers.IO`.

### 4. Printing Protocol Engineer
- **Goal**: Deliver robust, RFC-compliant IPP/IPPS protocol handlers and mDNS discovery.
- **Rules**:
  - Operates on protocol serializers, parsers, and socket transports.
  - Enforces mandatory capability negotiation before print submission.
  - Never assumes a printer supports PDF; validates `document-format-supported`.

### 5. QA Engineer
- **Goal**: Protect code quality, prevent regressions, and verify behavior across edge conditions.
- **Rules**:
  - Writes unit tests, widget tests, and mock transports.
  - Tests malformed IPP payloads, unexpected USB disconnects, and invalid PDF files.
  - Strictly distinguishes automated software tests from physical hardware validation.

### 6. Security Reviewer
- **Goal**: Enforce local-first privacy, zero data leaks, and secure network communications.
- **Rules**:
  - Conducts read-only audits on PRs and proposals.
  - Vetoes any telemetry, third-party analytics, cloud rendering, or insecure unencrypted transmissions without user consent.
  - Ensures temporary document files are reliably deleted after job termination.

### 7. Documentation Engineer
- **Goal**: Keep documentation, changelogs, build workflows, and compatibility matrices accurate and up to date.
- **Rules**:
  - Maintains `README.md`, `CHANGELOG.md`, `.github/workflows/`, and `docs/`.
  - Prevents premature documentation of unverified or planned features as completed.

---

## Conflict Resolution Protocol

When recommendations from different roles conflict:
1. **Security & Privacy Veto**: The **Security Reviewer** holds absolute veto power over any implementation violating local-first privacy, introducing unauthorized external network calls, or logging sensitive data.
2. **Architecture vs Feature**: The **Architect** has final authority over layer boundaries, dependency additions, and domain abstractions.
3. **Protocol Standards vs Convenience**: The **Printing Protocol Engineer** has final authority over IPP RFC conformance and safe negotiation over ad-hoc hacks.
4. **Physical Reality vs Assumptions**: Real-hardware test results supersede synthetic or simulated tests in compatibility claims.
