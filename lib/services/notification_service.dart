import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local notifications for incoming messages. No push server is involved: the
/// mesh runs in a foreground service, so when a message arrives while the app
/// is backgrounded (or on another screen) we post a notification directly.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const String _channelId = 'messages';
  static const String _channelName = 'Messages';

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Initialise the plugin and create the Android notification channel. Safe to
  /// call once at startup; failures are swallowed so notifications never block
  /// the app from running.
  Future<void> init() async {
    try {
      const AndroidInitializationSettings android =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(
        const InitializationSettings(android: android),
      );
      await _android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'New Kabootar messages',
          importance: Importance.high,
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('NotificationService init failed: $e');
    }
  }

  /// Ask for the POST_NOTIFICATIONS runtime permission (Android 13+). A no-op
  /// on older versions where the permission is granted at install time.
  Future<void> requestPermission() async {
    try {
      await _android?.requestNotificationsPermission();
    } catch (_) {
      // Permission APIs vary by OS version; ignore if unavailable.
    }
  }

  /// Show (or update) a message notification. [threadKey] groups messages from
  /// the same conversation onto a single, replaceable notification.
  Future<void> showMessage({
    required String title,
    required String body,
    required String threadKey,
  }) async {
    if (!_ready) return;
    const AndroidNotificationDetails android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'New Kabootar messages',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'New message',
    );
    try {
      await _plugin.show(
        threadKey.hashCode & 0x7fffffff,
        title,
        body,
        const NotificationDetails(android: android),
      );
    } catch (e) {
      debugPrint('NotificationService show failed: $e');
    }
  }
}
