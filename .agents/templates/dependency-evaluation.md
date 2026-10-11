# Task Template: Dependency Evaluation

Use this template before adding or updating third-party dependencies in `pubspec.yaml` or Android Gradle files.

---

## 1. Candidate Dependency
- **Package Name**: [e.g., `pdf`, `image`, `printing`]
- **Proposed Version**:
- **Publisher / Repository**: [e.g., pub.dev URL, GitHub URL]

## 2. Need & Alternatives
- **Why is this package necessary?**:
- **Can this be implemented with Flutter/Dart standard library?**: [Yes / No, explain]
- **What lighter alternatives were considered?**:

## 3. License & Compliance
- **Package License**: [Must be permissive: Apache-2.0, MIT, BSD-3-Clause]
- **Compatible with BurePrint Apache-2.0 License?**: [Yes / No]
- **Transitive Dependencies License Check**: [Verify licenses of dependencies pulled in]

## 4. Footprint & Security
- **Binary / Package Weight**:
- **Platform Limitations**: Does it support modern Android (API 26+) and pure Dart desktop environments?
- **Known CVEs / Supply Chain Risks**:

## 5. Decision & Architectural Sign-off
- [ ] Approved by Architect
- [ ] Approved by Security Reviewer
- [ ] Added to `pubspec.yaml` with pinned or caret version constraint
