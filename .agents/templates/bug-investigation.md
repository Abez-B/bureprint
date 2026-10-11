# Task Template: Bug Investigation and Repair

Use this template when investigating defects, crashes, or protocol errors.

---

## 1. Problem Description & Reproduction
- **Defect Summary**: [e.g., App crashes when attempting to parse corrupted mDNS TXT record]
- **Affected Subsystem**: [e.g., Discovery / IPP Client / USB Transport]
- **Reproduction Steps**:
  1. Step 1
  2. Step 2
- **Observed Behavior**: [Stack trace, log output, or error state]
- **Expected Behavior**:

## 2. Root Cause Analysis (RCA)
- **Root Cause**: [Explain precisely why the bug occurs]
- **Affected Files**:
  - `path/to/file`

## 3. Proposed Fix & Minimal Scope
- Plan the minimal, non-invasive change that eliminates the defect without introducing side effects.

## 4. Regression Prevention
- [ ] New unit or widget test reproducing the defect added to `test/`
- [ ] Test fails before fix and passes after fix

## 5. Verification Log
- `dart format`: [Pass / Fail]
- `flutter analyze`: [Pass / Fail]
- `flutter test`: [Pass / Fail]

## 6. Documentation & Report
- Update relevant docs if defect was due to misaligned protocol expectations.
