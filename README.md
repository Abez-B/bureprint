# BurePrint

BurePrint is an open-source, Flutter-first mobile printing project inspired by the everyday workflow of mobile printing apps. The name *BurePrint* is inspired by the Swahili word **bure** (“free / without charge”), reflecting a free-software, privacy-first direction.

> Status: early scaffold. This repository is an architectural starting point, not a finished printer driver or a universal printing app.

## Current scaffold
- Flutter app shell with Material 3 navigation
- Home, Documents, Printers, Queue, and Settings screens
- Domain models for printers, capabilities, print requests, and job state
- Abstract discovery and transport interfaces
- Fake printer discovery for UI development
- Unit tests for basic domain behavior

## Planned capabilities
- PDF and image import / preview
- IPP printer discovery and capability negotiation
- IPP job submission
- Android USB Host integration
- Print queue and job history
- Printer compatibility matrix

## Requirements
- Flutter stable SDK
- Dart version supported by your Flutter SDK
- Android Studio or Android SDK for Android builds

## Run
This is a source scaffold. Create the platform runner files with Flutter, then copy/merge this repository's `lib/`, `test/`, and `pubspec.yaml` into the generated Flutter project:

```bash
flutter create bureprint
# Copy this repository's lib/ and test/ directories into the generated project.
# Replace/merge pubspec.yaml, then:
cd bureprint
flutter pub get
flutter analyze
flutter test
flutter run
```

The zip includes `android/` design notes, but not generated Gradle/Android runner files. Generating platform folders with the local Flutter SDK avoids pinning an outdated generated template.

## Architecture
- `lib/core/`: app shell and navigation
- `lib/domain/`: printer and print-job models / interfaces
- `lib/features/`: feature screens
- `lib/data/`: fake data source for early UI development
- `test/`: starter tests

## Project principles
- Local-first document processing
- No account or cloud upload requirement
- No analytics by default
- Clear disclosure when a printer or format is unsupported
- Compatibility claims based on tested models and protocols

## License
Apache-2.0. Add a full license text before publishing a release.
