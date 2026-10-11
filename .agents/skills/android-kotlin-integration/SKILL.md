---
name: android-kotlin-integration
description: Guides Flutter platform channels, Kotlin platform-bridge implementation, Android lifecycle, runtime permissions, USB Host API, network permissions, and Android device compatibility in BurePrint. Activate when developing Android-specific native code, platform channels, or hardware bridges.
---

# Skill: Android and Kotlin Integration

## Purpose
Governs the development of Android platform bridges using Kotlin and Flutter Method/Event Channels. Covers hardware integration (USB Host API), network discovery sockets, and runtime permissions.

---

## Architectural Principles

1. **Clean Dart-to-Kotlin Boundary**:
   - Platform channel message schemas must be strictly defined with typed arguments and predictable error codes.
   - All platform channel communication should be encapsulated behind a Dart interface (e.g. `UsbPrinterTransport` implementing `PrintTransport`).
2. **Kotlin Conventions**:
   - Modern idiomatic Kotlin (null safety, coroutines, structured concurrency).
   - Use `CoroutineScope(Dispatchers.IO)` for USB and socket operations; do not block the Android UI thread.
3. **Android Lifecycle & Permissions**:
   - Handle Android runtime permissions cleanly (e.g., local network permission, notification permission for job progress).
   - Listen to USB device attach/detach broadcasts (`ACTION_USB_DEVICE_ATTACHED`, `ACTION_USB_DEVICE_DETACHED`).
   - Cleanly release USB interfaces and close file descriptors when devices disconnect or the app backgrounds.

---

## Android USB Host Workflow

1. **Manifest Configuration**:
   - Add `<uses-feature android:name="android.hardware.usb.host" android:required="false" />`.
2. **Device Enumeration**:
   - Enumerate connected devices using `UsbManager.getDeviceList()`.
   - Filter by USB printer class (`UsbConstants.USB_CLASS_PRINTER` = 7) or known vendor IDs.
3. **Permission Request**:
   - Call `UsbManager.requestPermission(device, permissionIntent)`.
   - Handle user approval or denial via `BroadcastReceiver`.
4. **Endpoint Communication**:
   - Claim `UsbInterface`, locate bulk IN and bulk OUT `UsbEndpoint`s.
   - Stream data safely in chunks, monitoring timeouts and connection drops.

---

## Validation & Testing

- **Unit Testing**: Test serialization and platform channel protocol handling on the Dart side with mock binary messengers.
- **Android Device Testing**: Real USB OTG testing must be conducted on hardware devices running Android 8.0+ (API 26+) through Android 15+.
- **Mock Verification**: Provide fake channel responses in tests to verify Dart handler resiliency.

```bash
# Build Android APK (when Flutter SDK and Android SDK are present)
flutter build apk --debug
```
