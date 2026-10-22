import 'dart:async';

import 'package:collapse_tinode/tinode.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

const _pushEnabled = bool.fromEnvironment('ENABLE_PUSH');

/// Notification payloads are presented by the native Firebase SDK.
/// Background isolates do not create another Tinode session or write chat data.
@pragma('vm:entry-point')
Future<void> collapseFirebaseBackgroundHandler(RemoteMessage message) async {
  if (!_pushEnabled) return;
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();
}

/// Restrict notification navigation to ordinary Tinode topic identifiers.
String? pushTopic(Map<String, dynamic> data) {
  var topic = data['topic'];
  if (topic == null || topic == '' || topic == 'me') topic = data['xfrom'];
  if (topic is! String) return null;
  return RegExp(r'^(usr|grp|chn)[A-Za-z0-9_-]+$').hasMatch(topic)
      ? topic
      : null;
}

class PushService {
  PushService(this.gateway, {bool enabled = _pushEnabled}) : _enabled = enabled;

  final TinodeGateway gateway;
  final bool _enabled;
  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<RemoteMessage>? _opened;
  Future<void>? _initializing;
  void Function(String topic)? _onOpenTopic;
  bool _ready = false;
  bool _disposed = false;
  bool _acceptTokenUpdates = true;
  int _epoch = 0;

  bool get configured =>
      _enabled &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Does not request permission or register a device before the user signs in.
  Future<void> initialize({void Function(String topic)? onOpenTopic}) {
    _onOpenTopic = onOpenTopic;
    if (!configured || _ready || _disposed) return Future.value();
    return _initializing ??= _initialize().whenComplete(
      () => _initializing = null,
    );
  }

  Future<void> _initialize() async {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(collapseFirebaseBackgroundHandler);
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
    if (_disposed) return;
    _ready = true;
    _tokenRefresh = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      if (gateway.userId == null || _disposed || !_acceptTokenUpdates) return;
      // A subsequent authenticated reconnect retries a failed device update.
      unawaited(
        gateway.setDeviceToken(token).catchError((Object error) {
          debugPrint('Push token registration failed (${error.runtimeType}).');
        }),
      );
    });
    _opened = FirebaseMessaging.onMessageOpenedApp.listen(_open);
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null && !_disposed) _open(initial);
    await synchronize();
  }

  void _open(RemoteMessage message) {
    final topic = pushTopic(message.data);
    if (topic != null && !_disposed) _onOpenTopic?.call(topic);
  }

  /// Call from an explicit user action, not automatically at startup.
  Future<bool> enable() async {
    if (!configured || _disposed) return false;
    if (!_ready) await initialize(onOpenTopic: _onOpenTopic);
    final settings = await FirebaseMessaging.instance.requestPermission();
    if (!_authorized(settings.authorizationStatus)) return false;
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    return synchronize();
  }

  /// Call after each authenticated connection. Never prompts for permission.
  Future<bool> synchronize() async {
    if (!_ready || _disposed || gateway.userId == null) return false;
    _acceptTokenUpdates = true;
    final user = gateway.userId;
    final epoch = _epoch;
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.getNotificationSettings();
    if (!_authorized(settings.authorizationStatus)) return false;
    await messaging.setAutoInitEnabled(true);
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        await messaging.getAPNSToken() == null) {
      // onTokenRefresh registers once APNs is ready on a physical device.
      return false;
    }
    final token = await messaging.getToken();
    if (_disposed ||
        epoch != _epoch ||
        gateway.userId != user ||
        token == null) {
      return false;
    }
    await gateway.setDeviceToken(token);
    return true;
  }

  bool _authorized(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;

  /// Must run before auth logout, while the old account is still authenticated.
  Future<void> logout() async {
    ++_epoch;
    _acceptTokenUpdates = false;
    if (!_ready) return;
    try {
      if (gateway.userId != null) await gateway.setDeviceToken(null);
    } finally {
      // Invalidating the FCM token also protects logout performed while offline.
      await FirebaseMessaging.instance.setAutoInitEnabled(false);
      await FirebaseMessaging.instance.deleteToken();
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    ++_epoch;
    await _tokenRefresh?.cancel();
    await _opened?.cancel();
    _onOpenTopic = null;
  }
}
