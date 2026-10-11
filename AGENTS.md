# BurePrint Agent Instructions & Engineering Rules

Welcome to the **BurePrint** workspace. BurePrint is an open-source, privacy-first mobile printing application inspired by NokoPrint.

> **CRITICAL RULE FOR ALL AGENTS**:
> 1. Treat the current codebase as an **early architectural scaffold**. Never assume a feature exists simply because it is described in the roadmap or docs. Always inspect actual code.
> 2. Clearly distinguish between **implemented**, **partially implemented**, **mocked**, and **planned** functionality.
> 3. Make minimal, focused, coherent changes.
> 4. Inspect git status and existing code before touching files. Never silently discard uncommitted changes.
> 5. **Never claim tests passed unless they actually ran and succeeded in your execution context.** If the runtime environment lacks Flutter or Dart, explicitly report that tests could not be run locally and specify which CI checks must validate the change.
> 6. Never commit or push automatically unless explicitly instructed by the user.

---

## 1. Project Goals & Technology Stack

- **Domain**: Mobile printing across local networks (Wi-Fi) and USB OTG.
- **Principles**:
  - **Local-first document processing**: Zero external cloud or server dependencies for rendering or printing.
  - **Privacy by default**: No tracking, telemetry, or third-party analytics. No credentials or document content logged.
  - **Truth in compatibility**: Printer support claims must be backed by empirical evidence on real hardware. Unsupported protocols/printers must fail safely and explicitly.
- **Technology Stack**:
  - **App & Presentation**: Flutter (Dart) with Material 3 and Riverpod for state management.
  - **Android Platform**: Kotlin via Flutter platform channels / method channels for USB Host API, network sockets, or low-level OS services.
  - **Network Printing**: Standards-based IPP/IPPS (Internet Printing Protocol over HTTP/HTTPS) and mDNS/DNS-SD discovery.
  - **USB Printing**: Android USB Host API (`android.hardware.usb`) supporting IPP-over-USB and vendor-specific protocol bridges.

---

## 2. Architecture Boundaries & Dependency Direction

Follow strict architectural layer separation:
```
lib/
├── core/         # Cross-cutting primitives: routing, theme, error models, logging
├── domain/       # Pure Dart domain entities, value objects, and repository/transport interfaces
│   ├── models/
│   └── interfaces/
├── data/         # Implementations of domain interfaces (network, persistence, mock/fake services)
└── features/     # Feature-driven presentation layer (Riverpod providers, widgets, screens)
```

### Architectural Constraints:
1. **Domain Layer Independence**: The `domain/` layer MUST NOT import Flutter widgets, platform-specific code (`dart:io` where avoidable, Kotlin bridges), or UI libraries.
2. **UI Layer Protocol Isolation**: UI code (`features/`) MUST NOT speak raw printer protocols, execute byte conversions, or make direct HTTP/socket calls. It must interact exclusively with domain interfaces and state providers.
3. **Data & Transport Separation**: Document processing (rasterization, format conversion) must be decoupled from transport mechanisms (IPP socket, USB endpoint).
4. **Platform Channels**: Platform-specific Kotlin code must be isolated behind Dart abstract interface contracts in `domain/interfaces/` with concrete implementations in `data/` or `platform/`.

---

## 3. Coding Conventions

### Dart Conventions
- Strictly adhere to `analysis_options.yaml` (using `package:flutter_lints`).
- Enforce sound null safety: avoid force-unwrapping (`!`) unless accompanied by an explicit invariant assertion.
- Prefer immutable data models (`@immutable`, `final` fields, `copyWith` methods).
- Handle asynchronous flows safely: handle `Future` errors, clean up `StreamSubscription`s, and honor cancellation tokens.
- Keep dependencies minimal: evaluate dependency weight, license, and maintenance before adding packages to `pubspec.yaml`.

### Kotlin & Android Conventions
- Use modern idiomatic Kotlin with coroutines for background I/O operations.
- Isolate Flutter MethodChannel/EventChannel handlers into dedicated controller classes.
- Follow Android runtime permission guidelines: check, request, and gracefully handle denied permissions (e.g., USB device attachment, local network permissions).
- Safely close Android USB connections (`UsbDeviceConnection.close()`) and release interfaces in `finally` blocks or lifecycle teardowns.

---

## 4. Error Handling & Safe Failure

1. **Protocol Negotiation**: Discovered printers MUST NOT be assumed to accept PDF or standard formats. Query printer capabilities (`Get-Printer-Attributes`) first.
2. **Safe Failure**: When a printer does not support a document MIME type or operation, fail gracefully with user-actionable error messages (e.g., "Printer does not support direct PDF; rasterization required").
3. **Hardware Safety**: **NEVER send arbitrary bytes or raw strings to an unknown USB or network endpoint.** Always negotiate or verify protocol compatibility before transmitting payloads.

---

## 5. Security & Privacy Requirements

- **Sensitive Data in Logs**: NEVER log document names, document payloads, file paths with sensitive user data, network credentials, or printer passwords.
- **Temporary File Lifecycle**: Temporary files created during document processing or conversion MUST be stored in the app's cache directory and explicitly deleted immediately after job completion, cancellation, or failure.
- **Untrusted Input**: Treat all mDNS/DNS-SD discovery packets and raw IPP responses as untrusted network data. Validate byte lengths, attribute types, and buffer limits against integer overflows or OOM attacks.
- **Network Security**: Prefer encrypted IPPS (port 631 with TLS). Validate TLS certificates when possible; clearly indicate insecure network transport to the user if fallback occurs.

---

## 6. Testing & Validation Expectations

- **Unit Tests**: All domain models, parsing routines, state reducers, and protocol encoders/decoders must have pure Dart unit tests in `test/`.
- **Widget Tests**: Feature screens must have widget tests verifying rendering, loading, error, and empty states.
- **Mocking Boundaries**: Use domain interfaces to mock hardware and transport layers for testing.
- **Physical Hardware Distinction**: Automated tests pass in CI; however, printer compatibility status in [docs/supported-printers.md](file:///home/abe-z/Projects/bureprint/docs/supported-printers.md) requires verified real-device hardware validation.
- **Verification Rule**: Never say "All tests pass" without running `flutter test` or explaining that tests were verified via code analysis / CI simulation when the Flutter SDK is absent in the host environment.

---

## 7. Definition of Done (DoD)

A task or PR is considered complete only when:
1. `dart format --output=none --set-exit-if-changed lib test` passes cleanly.
2. `flutter analyze` reports zero errors and zero warnings.
3. Unit and widget tests cover the new logic and existing regression tests pass.
4. Security and privacy rules are observed (no leaks, temp files cleaned).
5. Documentation and capability matrices are updated if behavior changed.
6. Git diff is clean, minimal, and focused on the requested scope.
