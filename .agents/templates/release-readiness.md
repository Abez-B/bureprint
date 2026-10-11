# Task Template: Release Readiness

Use this template before tagging a new release or publishing build artifacts for BurePrint.

---

## 1. Release Metadata
- **Target Version**: [e.g., `0.1.0+1` -> `0.2.0+2`]
- **Release Date**: [YYYY-MM-DD]
- **Release Engineer**: Documentation / Release Engineer Persona

## 2. Quality & CI Gate Verification
- [ ] `dart format --output=none --set-exit-if-changed lib test` passes cleanly
- [ ] `flutter analyze` reports zero errors, zero warnings, zero hints
- [ ] `flutter test` completes with all unit and widget tests passing
- [ ] GitHub Actions workflow (`.github/workflows/flutter-ci.yml`) is green on the target commit

## 3. Privacy, Security & License Audit
- [ ] Threat modeling & privacy audit confirmed (no telemetry, local-first intact)
- [ ] No uncleaned temp files or logging of sensitive parameters
- [ ] All dependencies in `pubspec.yaml` comply with Apache-2.0 licensing
- [ ] License header or full text verified

## 4. Documentation & Changelog
- [ ] `CHANGELOG.md` updated with added, changed, fixed, and removed entries
- [ ] `README.md` features and status updated accurately
- [ ] `docs/supported-printers.md` accurately reflects physical test evidence
- [ ] Version bumped in `pubspec.yaml`

## 5. Artifact Build & Verification
- [ ] Android APK built reproducibly (`flutter build apk --release`)
- [ ] APK tested on target Android test device / emulator
- [ ] Release notes prepared for GitHub release
