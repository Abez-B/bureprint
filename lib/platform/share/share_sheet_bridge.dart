import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/imported_document.dart';

/// Representation of incoming file data received via Android Send / Share Sheet.
class SharedIncomingFile {
  const SharedIncomingFile({
    required this.filePath,
    required this.mimeType,
    this.name,
  });

  final String filePath;
  final String mimeType;
  final String? name;

  factory SharedIncomingFile.fromMap(Map<dynamic, dynamic> map) {
    return SharedIncomingFile(
      filePath: map['filePath'] as String? ?? '',
      mimeType: map['mimeType'] as String? ?? 'application/octet-stream',
      name: map['name'] as String?,
    );
  }

  ImportedDocument toImportedDocument() {
    final file = File(filePath);
    final size = file.existsSync() ? file.lengthSync() : 0;
    final displayName = name ?? filePath.split('/').last;

    String resolvedMime = mimeType;
    if (resolvedMime == 'application/octet-stream' || resolvedMime.isEmpty) {
      final ext = displayName.contains('.')
          ? displayName.split('.').last.toLowerCase()
          : '';
      switch (ext) {
        case 'pdf':
          resolvedMime = 'application/pdf';
        case 'jpg' || 'jpeg':
          resolvedMime = 'image/jpeg';
        case 'png':
          resolvedMime = 'image/png';
        case 'webp':
          resolvedMime = 'image/webp';
        case 'docx':
          resolvedMime =
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        case 'doc':
          resolvedMime = 'application/msword';
        case 'odt':
          resolvedMime = 'application/vnd.oasis.opendocument.text';
        case 'txt':
          resolvedMime = 'text/plain';
      }
    }

    return ImportedDocument(
      id: 'shared-${DateTime.now().millisecondsSinceEpoch}-${filePath.hashCode}',
      name: displayName,
      filePath: filePath,
      fileSizeBytes: size,
      mimeType: resolvedMime,
      importedAt: DateTime.now(),
    );
  }
}

/// Abstract contract for interacting with Android Share Sheet intents.
abstract interface class ShareSheetBridge {
  /// Fetches files shared at app launch or initial intent.
  Future<List<SharedIncomingFile>> getInitialSharedFiles();

  /// Stream of files shared into BurePrint while the app is running in the background/foreground.
  Stream<List<SharedIncomingFile>> get onFilesShared;

  /// Notifies the Android Media Scanner that a new file was saved.
  Future<void> notifyMediaScanner(String filePath);

  /// Opens an external URL in the system browser.
  Future<void> openUrl(String url);
}

/// Concrete implementation utilizing Flutter MethodChannel and EventChannel.
class AndroidShareSheetBridge implements ShareSheetBridge {
  AndroidShareSheetBridge({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methodChannel = methodChannel ??
            const MethodChannel('org.bureprint/share_receiver'),
        _eventChannel =
            eventChannel ?? const EventChannel('org.bureprint/share_events') {
    _initEventListener();
  }

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  final _sharedFilesController =
      StreamController<List<SharedIncomingFile>>.broadcast();

  StreamSubscription<dynamic>? _subscription;

  bool get _isSupportedPlatform =>
      Platform.isAndroid || Platform.environment.containsKey('FLUTTER_TEST');

  void _initEventListener() {
    if (!_isSupportedPlatform) return;
    try {
      _subscription = _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is List) {
            final files = event
                .whereType<Map>()
                .map((m) => SharedIncomingFile.fromMap(m))
                .where((f) => f.filePath.isNotEmpty)
                .toList();
            if (files.isNotEmpty) {
              _sharedFilesController.add(files);
            }
          }
        },
        onError: (_) {
          // Gracefully ignore stream errors
        },
      );
    } catch (_) {
      // Platform channels may be unmocked in test runner
    }
  }

  @override
  Future<void> notifyMediaScanner(String filePath) async {
    if (!_isSupportedPlatform) return;
    try {
      await _methodChannel.invokeMethod('scanFile', {'path': filePath});
    } catch (_) {}
  }

  @override
  Future<void> openUrl(String url) async {
    if (!_isSupportedPlatform) return;
    try {
      await _methodChannel.invokeMethod('openUrl', {'url': url});
    } catch (_) {}
  }

  @override
  Future<List<SharedIncomingFile>> getInitialSharedFiles() async {
    if (!_isSupportedPlatform) return const [];
    try {
      final result = await _methodChannel
          .invokeMethod<List<dynamic>>('getInitialSharedFiles');
      if (result == null) return const [];
      return result
          .whereType<Map>()
          .map((m) => SharedIncomingFile.fromMap(m))
          .where((f) => f.filePath.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Stream<List<SharedIncomingFile>> get onFilesShared =>
      _sharedFilesController.stream;

  void dispose() {
    _subscription?.cancel();
    _sharedFilesController.close();
  }
}

final shareSheetBridgeProvider = Provider<ShareSheetBridge>((ref) {
  final bridge = AndroidShareSheetBridge();
  ref.onDispose(bridge.dispose);
  return bridge;
});
