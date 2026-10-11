# Task Template: Code Review

Use this template when performing automated or peer code review on pull requests or working tree diffs.

---

## 1. Review Metadata
- **Branch / PR**: [e.g., feature/ipp-attribute-parser]
- **Reviewer Persona**: [e.g., Architect / QA / Security Reviewer]
- **Scope of Review**: [List of touched files]

## 2. Architectural & Style Conformance
- [ ] Layer boundaries respected (no UI code speaking raw protocols, no platform code in domain)?
- [ ] Follows Dart / Kotlin coding standards?
- [ ] Sound null safety enforced (no unjustified `!` operators)?
- [ ] Immutability preserved where appropriate?

## 3. Error Handling & Edge Cases
- [ ] Asynchronous errors caught and handled cleanly?
- [ ] Network disconnects and hardware timeouts handled gracefully?
- [ ] Proper user-facing error messages provided?

## 4. Quality & Testing
- [ ] Unit/widget tests included for new logic?
- [ ] Edge cases (empty lists, corrupt payloads, cancelled operations) tested?
- [ ] Tests run and confirmed passing?

## 5. Security & Privacy
- [ ] Zero telemetry or tracking added?
- [ ] No sensitive credentials, document contents, or user data logged?
- [ ] Temp files safely cleaned up?

## 6. Review Recommendation
- [ ] **APPROVE**: Clean, safe, tested, adheres to principles.
- [ ] **REQUEST CHANGES**: Specify blocking issues and required remediation.
