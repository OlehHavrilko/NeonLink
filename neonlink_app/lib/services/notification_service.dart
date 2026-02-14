import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notification types
enum NotificationType {
  scriptStarted,
  scriptCompleted,
  scriptError,
  connectionLost,
  connectionRestored,
  backupCreated,
  updateAvailable,
}

/// Service for local notifications
class NotificationService {
  static NotificationService? _instance;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  NotificationService._();

  static NotificationService get instance {
    _instance ??= NotificationService._();
    return _instance!;
  }

  /// Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _initialized = true;
  }

  void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap
    // Can navigate to specific screen based on payload
  }

  /// Show notification
  Future<void> showNotification({
    required String title,
    required String body,
    NotificationType type = NotificationType.scriptCompleted,
    String? payload,
  }) async {
    if (!_initialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      'neonlink_${type.name}',
      _getChannelName(type),
      channelDescription: 'NeonLink notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  String _getChannelName(NotificationType type) {
    switch (type) {
      case NotificationType.scriptStarted:
        return 'Script Notifications';
      case NotificationType.scriptCompleted:
        return 'Script Notifications';
      case NotificationType.scriptError:
        return 'Error Notifications';
      case NotificationType.connectionLost:
        return 'Connection Notifications';
      case NotificationType.connectionRestored:
        return 'Connection Notifications';
      case NotificationType.backupCreated:
        return 'Backup Notifications';
      case NotificationType.updateAvailable:
        return 'Update Notifications';
    }
  }

  /// Notify script started
  Future<void> notifyScriptStarted(String scriptName) async {
    await showNotification(
      title: 'Script Started',
      body: 'Script "$scriptName" is now running',
      type: NotificationType.scriptStarted,
    );
  }

  /// Notify script completed
  Future<void> notifyScriptCompleted(
    String scriptName, {
    int? exitCode,
  }) async {
    await showNotification(
      title: 'Script Completed',
      body: exitCode == 0
          ? 'Script "$scriptName" completed successfully'
          : 'Script "$scriptName" finished with exit code $exitCode',
      type: NotificationType.scriptCompleted,
    );
  }

  /// Notify script error
  Future<void> notifyScriptError(String scriptName, String error) async {
    await showNotification(
      title: 'Script Error',
      body: 'Error in "$scriptName": $error',
      type: NotificationType.scriptError,
    );
  }

  /// Notify connection lost
  Future<void> notifyConnectionLost() async {
    await showNotification(
      title: 'Connection Lost',
      body: 'Lost connection to NeonLink server',
      type: NotificationType.connectionLost,
    );
  }

  /// Notify connection restored
  Future<void> notifyConnectionRestored() async {
    await showNotification(
      title: 'Connection Restored',
      body: 'Connection to NeonLink server restored',
      type: NotificationType.connectionRestored,
    );
  }

  /// Notify backup created
  Future<void> notifyBackupCreated() async {
    await showNotification(
      title: 'Backup Created',
      body: 'Configuration backup has been created',
      type: NotificationType.backupCreated,
    );
  }

  /// Notify update available
  Future<void> notifyUpdateAvailable(String version) async {
    await showNotification(
      title: 'Update Available',
      body: 'NeonLink Android v$version is available',
      type: NotificationType.updateAvailable,
    );
  }

  /// Request permissions (Android 13+)
  Future<bool> requestPermissions() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    return true;
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
