import 'dart:async';
import 'package:flutter/services.dart';

import 'usb_printer_device.dart';

/// Dart abstract interface for Android USB Host communication.
abstract interface class UsbHostBridge {
  Future<List<UsbPrinterDevice>> enumerateDevices();
  Future<bool> requestPermission(int deviceId);
  Future<bool> hasPermission(int deviceId);
  Future<bool> sendBytes(int deviceId, List<int> bytes);
  Stream<UsbPrinterDevice> get onDeviceAttached;
  Stream<int> get onDeviceDetached;
}

/// Production implementation communicating with Kotlin via Flutter Platform Channels.
class AndroidUsbHostBridge implements UsbHostBridge {
  AndroidUsbHostBridge({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methodChannel =
            methodChannel ?? const MethodChannel('org.bureprint/usb_host'),
        _eventChannel =
            eventChannel ?? const EventChannel('org.bureprint/usb_events') {
    _initEventListener();
  }

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  final _attachedController = StreamController<UsbPrinterDevice>.broadcast();
  final _detachedController = StreamController<int>.broadcast();

  StreamSubscription<dynamic>? _eventSubscription;

  void _initEventListener() {
    try {
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is Map) {
            final type = event['type'] as String?;
            if (type == 'attached') {
              final deviceData =
                  Map<String, dynamic>.from(event['device'] as Map);
              _attachedController.add(UsbPrinterDevice.fromJson(deviceData));
            } else if (type == 'detached') {
              final deviceId = event['deviceId'] as int;
              _detachedController.add(deviceId);
            }
          }
        },
        onError: (_) {
          // Gracefully ignore event stream errors
        },
      );
    } catch (_) {
      // Platform channels may be unmocked in pure Dart test runners
    }
  }

  @override
  Stream<UsbPrinterDevice> get onDeviceAttached => _attachedController.stream;

  @override
  Stream<int> get onDeviceDetached => _detachedController.stream;

  @override
  Future<List<UsbPrinterDevice>> enumerateDevices() async {
    try {
      final List<dynamic>? result =
          await _methodChannel.invokeListMethod<dynamic>('enumerateDevices');
      if (result == null) return const [];
      return result
          .map((item) =>
              UsbPrinterDevice.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } on PlatformException {
      return const [];
    }
  }

  @override
  Future<bool> hasPermission(int deviceId) async {
    try {
      final bool? result = await _methodChannel
          .invokeMethod<bool>('hasPermission', {'deviceId': deviceId});
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> requestPermission(int deviceId) async {
    try {
      final bool? result = await _methodChannel
          .invokeMethod<bool>('requestPermission', {'deviceId': deviceId});
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> sendBytes(int deviceId, List<int> bytes) async {
    try {
      final bool? result =
          await _methodChannel.invokeMethod<bool>('sendBytes', {
        'deviceId': deviceId,
        'bytes': bytes,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  void dispose() {
    _eventSubscription?.cancel();
    _attachedController.close();
    _detachedController.close();
  }
}
