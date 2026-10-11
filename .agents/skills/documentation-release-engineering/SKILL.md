---
name: documentation-release-engineering
description: Guides README maintenance, Architecture Decision Records (ADRs), contributor documentation, changelog generation, GitHub Actions CI/CD workflows, reproducible builds, and release validation in BurePrint. Activate when preparing releases, modifying CI workflows, writing ADRs, or updating documentation.
---

# Skill: Documentation and Release Engineering

## Purpose
Ensures BurePrint maintains high-quality documentation, transparent architectural decision tracking, reliable CI/CD pipelines, and verified releases.

---

## Documentation Standards

1. **Architecture Decision Records (ADRs)**:
   - When making architectural changes (e.g., introducing a rasterization library, redesigning transport layers), create an ADR in `docs/adr/XXXX-title.md`.
   - ADR Structure: Context, Decision, Consequences, Alternatives Considered.
2. **README Maintenance**:
   - Keep status, setup steps, requirements, and architecture summaries in sync with the codebase.
   - Accurately report what is implemented vs planned.
3. **Changelog & Semantic Versioning**:
   - Follow Keep a Changelog format in `CHANGELOG.md`.
   - Bump versions in `pubspec.yaml` following SemVer (`MAJOR.MINOR.PATCH+BUILD`).

---

## CI/CD & Build Engineering

1. **GitHub Actions Workflows**:
   - Maintain `.github/workflows/flutter-ci.yml`.
   - Workflow must enforce:
     1. Checkout & Flutter setup.
     2. Dependency resolution (`flutter pub get`).
     3. Formatting verification (`dart format --output=none --set-exit-if-changed lib test`).
     4. Static analysis (`flutter analyze`).
     5. Unit & widget tests (`flutter test`).
2. **Reproducible Builds**:
   - Avoid hardcoded local paths or machine-specific environment dependencies.
   - Ensure reproducible Android APK artifacts.

---

## Release Checklist

- [ ] All CI workflows pass without warnings.
- [ ] Version updated in `pubspec.yaml`.
- [ ] `CHANGELOG.md` entry documented.
- [ ] Dependency licenses verified against Apache-2.0.
- [ ] `docs/supported-printers.md` accurately reflects real tested hardware.
