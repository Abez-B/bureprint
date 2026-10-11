---
name: dart-quality-testing
description: Guides Dart formatting, static analysis, sound null safety, asynchronous programming, error handling, cancellation, unit testing, and test coverage in BurePrint. Activate when writing Dart code, refactoring logic, or adding unit/integration tests.
---

# Skill: Dart Quality and Testing

## Purpose
Ensures all Dart code in BurePrint is sound, idiomatic, thoroughly tested, and compliant with `flutter_lints` and strict null safety standards.

---

## Coding Standards & Conventions

1. **Static Analysis & Formatting**:
   - Zero tolerance for warnings and hints in `flutter analyze`.
   - All code must be formatted using standard 80-column line limits via `dart format`.
2. **Null Safety**:
   - Enforce non-nullable types by default.
   - Do not use `!` (force unwrap) without documented assertions or invariant guarantees.
   - Prefer `?.` conditional member access and `??` default coalescing.
3. **Asynchronous Code & Cancellation**:
   - Avoid unhandled asynchronous errors; wrap `Future` bodies with structured try/catch blocks.
   - For cancellable operations (e.g. printer discovery scan, long print data transfer), accept `CancellationToken` or manage `StreamSubscription.cancel()`.
   - Never ignore unawaited futures: use `unawaited(...)` explicitly from `dart:async` only when deliberately detached.
4. **Minimal Dependencies**:
   - Do not introduce heavy third-party packages for trivial helper logic.
   - Prefer standard library packages (`dart:async`, `dart:typed_data`, `dart:convert`).

---

## Testing Workflow

1. **Unit Testing Pure Domain Logic**:
   - Every model in `lib/domain/models/` must test serialization, copyWith, equality (`operator ==` / `hashCode`), and validation rules.
   - Tests go into `test/` mirroring the `lib/` directory structure.
2. **Mocking & Isolation**:
   - Use Dart interfaces for fake or mock implementations (see [fake_printer_discovery.dart](file:///home/abe-z/Projects/bureprint/lib/data/fake_printer_discovery.dart) as an example).
   - Test happy path, network disconnects, timeout behaviors, and malformed inputs.
3. **Execution & CI Verification**:
   - Verify locally with `dart test` or `flutter test`.
   - If local Flutter environment is not installed, verify syntactical consistency and write unit tests compatible with standard test runners.

---

## Common Commands

```bash
# Verify formatting
dart format --output=none --set-exit-if-changed lib test

# Run linter
flutter analyze

# Run all unit and widget tests
flutter test --coverage
```

## Deliverables & Acceptance Criteria
- Clean static analysis results (`0 issues found`).
- High test coverage across domain models and business logic.
- Robust error handling for edge cases without unhandled exceptions or memory leaks.
