# Android Share Sheet Integration Architecture

## 1. Overview
BurePrint integrates seamlessly with the Android OS Share Sheet (`ACTION_SEND` and `ACTION_SEND_MULTIPLE`). When users browse PDFs, images, or documents in other Android apps (Files, Google Drive, WhatsApp, Email, Chrome) and tap **Share -> BurePrint**, the file is seamlessly imported into BurePrint's local cache and opens directly in the print settings preview.

## 2. Android Manifest Configuration

In `android/app/src/main/AndroidManifest.xml`, the main activity (`MainActivity`) registers intent filters to accept incoming shared single and multiple files:

```xml
<activity
    android:name=".MainActivity"
    android:launchMode="singleTask"
    android:theme="@style/LaunchTheme"
    android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
    android:hardwareAccelerated="true"
    android:windowSoftInputMode="adjustResize"
    android:exported="true">

    <!-- Standard App Launch Filter -->
    <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>

    <!-- Share Sheet Filter: Single File (ACTION_SEND) -->
    <intent-filter>
        <action android:name="android.intent.action.SEND" />
        <category android:name="android.intent.category.DEFAULT" />
        
        <!-- Supported MIME types -->
        <data android:mimeType="application/pdf" />
        <data android:mimeType="image/*" />
        <data android:mimeType="text/plain" />
        <data android:mimeType="application/vnd.openxmlformats-officedocument.wordprocessingml.document" />
        <data android:mimeType="application/msword" />
        <data android:mimeType="application/vnd.oasis.opendocument.text" />
    </intent-filter>

    <!-- Share Sheet Filter: Multiple Files (ACTION_SEND_MULTIPLE) -->
    <intent-filter>
        <action android:name="android.intent.action.SEND_MULTIPLE" />
        <category android:name="android.intent.category.DEFAULT" />

        <data android:mimeType="application/pdf" />
        <data android:mimeType="image/*" />
    </intent-filter>
</activity>
```

## 3. Kotlin Platform Channel Implementation

### Channel Names:
- MethodChannel: `org.bureprint/share_receiver`
- EventChannel: `org.bureprint/share_events`

### Android Content URI Resolution & Security Safeguards:
1. External apps share files via `content://` URIs with transient read permissions (`FLAG_GRANT_READ_URI_PERMISSION`).
2. Native Kotlin code reads the stream using `ContentResolver.openInputStream(uri)` and copies it immediately into the app's internal cache directory: `context.cacheDir/shared_incoming/<sanitized_name>`.
3. Never log URI paths containing sensitive user identifiers or document titles.
4. If an intent is received while the app is already open, `onNewIntent(intent: Intent)` extracts the files and broadcasts them via `EventChannel`.
5. If the app is launched cold from the share sheet, `getInitialSharedFiles` provides the payload to Flutter during application startup.

## 4. Dart Bridge & Presentation Layer

- Dart contract: `lib/platform/share/share_sheet_bridge.dart`
- Consumed by `documentManagerProvider` or startup listener to automatically append incoming documents to the active document list and immediately display the Print Settings sheet.
