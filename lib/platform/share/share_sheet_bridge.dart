import 'dart:async';
import 'package:flutter/services.dart';

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
}

/// Abstract contract for interacting with Android Share Sheet intents.
abstract interface class ShareSheetBridge {
  /// Fetches files shared at app launch or initial intent.
  Future<List<SharedIncomingFile>> getInitialSharedFiles();

  /// Stream of files shared into BurePrint while the app is running in the background/foreground.
  Stream<List<SharedIncomingFile>> get onFilesShared;
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

  void _initEventListener() {
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
  Future<List<SharedIncomingFile>> getInitialSharedFiles() async {
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
