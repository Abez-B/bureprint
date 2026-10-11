## Description
<!-- Provide a clear, concise summary of the changes introduced in this Pull Request. Explain what problem is solved or what feature is added. -->

## Type of Change
<!-- Mark the relevant options with an [x] -->
- [ ] 🐛 Bug fix (non-breaking change fixing an existing issue)
- [ ] ✨ New feature (non-breaking change adding new functionality)
- [ ] 🎨 UI / UX refinement
- [ ] ⚡ Performance improvement
- [ ] 🛠️ Platform bridge / hardware driver update (Android USB / IPP network)
- [ ] 📝 Documentation update
- [ ] 🧪 Test suite addition / fix

## Linked Issue(s)
<!-- Reference issues resolved by this PR (e.g. Closes #123, Fixes #45) -->
Closes #

---

## Architectural & Privacy Checklist
<!-- BureauPrint is local-first, privacy-by-default, and hardware-safe. Verify all items below: -->
- [ ] **Privacy Preservation**: No personal data, document content, network credentials, or sensitive tokens are logged.
- [ ] **Hardware Safety**: No arbitrary or untested raw bytes are dispatched to unknown printers without verified protocol negotiation.
- [ ] **Local-First Boundary**: Processing & conversions run entirely offline on-device without third-party cloud dependencies.
- [ ] **Temporary File Cleanup**: Any temporary files generated during processing are cleaned up safely.

---

## Testing & Quality Validation
<!-- Follow AGENTS.md rules: report actual command execution results. -->
- [ ] `dart format --output=none --set-exit-if-changed lib test` passes cleanly.
- [ ] `flutter analyze` reports 0 errors and 0 warnings.
- [ ] `flutter test` passes all unit and widget tests.
- [ ] Tested on physical hardware or Android emulator:
  - Device model & OS version:
  - Printer model & connection type (Wi-Fi IPP or USB OTG):

---

## Screenshots or Screen Recordings (Optional)
<!-- Attach before/after screenshots if this PR touches presentation or UI -->
| Before | After |
| :---: | :---: |
| *(Image)* | *(Image)* |

---

## Additional Notes
<!-- Any architectural considerations, caveats, or follow-up tasks -->
