---
name: flutter-architecture-ui
description: Guides feature-based Flutter architecture, Material 3 responsive UI, Riverpod state management, navigation, accessibility, and UI testing in BurePrint. Activate when designing screens, widgets, routing, or state models.
---

# Skill: Flutter Architecture and UI

## Purpose
Enforces clean separation between presentation, domain, and data layers within BurePrint using Flutter, Material 3, and Riverpod. Ensures accessibility, responsiveness across phone and tablet form factors, and solid widget testing.

---

## Architectural Guidelines

1. **Feature Structure**:
   Organize `lib/features/<feature_name>/` as:
   - `presentation/`: Widgets, screens, dialogs, and Riverpod providers/notifiers.
   - Avoid putting raw network calls, protocol encoders, or platform method channels inside `presentation/`.
2. **State Management**:
   - Use `flutter_riverpod` providers (`NotifierProvider`, `AsyncNotifierProvider`).
   - Keep UI state immutable.
   - Represent asynchronous states using `AsyncValue` (handle `loading`, `error`, `data` cleanly).
3. **Responsive UI & Material 3**:
   - Utilize Material 3 widgets (`NavigationBar`, `Card`, `FilledButton`, `ListTile`).
   - Support dark mode and dynamic color schemes where applicable.
   - Use `LayoutBuilder` or responsive breakpoints for tablet and multi-window views.
4. **Accessibility (a11y)**:
   - Provide `Semantics` labels for icon-only buttons.
   - Respect system text scaling factors without clipping UI text.

---

## Step-by-Step Workflow

1. **Review Domain Interface**: Before building UI components, verify that required domain models (`lib/domain/models/`) and repository/service interfaces (`lib/domain/interfaces/`) exist.
2. **Define State Provider**: Create a Riverpod `Notifier` or state provider managing the screen state. Mock underlying interfaces for tests.
3. **Build Widgets**:
   - Break large screens into small, reusable widgets.
   - Ensure widgets accept parameters or watch granular providers to avoid unnecessary rebuilds.
4. **Implement Navigation**:
   - Use `go_router` routes declared in `lib/core/app.dart`.
5. **Write Widget Tests**:
   - Write tests in `test/features/<feature_name>/` using `WidgetTester`.
   - Wrap test widgets with `ProviderScope` and provide overrides for dependency interfaces.

---

## Commands & Validation

```bash
# Format code
dart format lib test

# Run static analysis
flutter analyze

# Run widget tests
flutter test test/features/
```

## Deliverables & Acceptance Criteria
- Clean, responsive UI adhering to Material 3 guidelines.
- Riverpod state providers cleanly decoupled from domain logic.
- Accompanying widget tests covering loading, success, and error states.
