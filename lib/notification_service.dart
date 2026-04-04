import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'announcement_notification_utils.dart';
import 'firebase_options.dart';

final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final ValueNotifier<int?> pendingNotificationNavigationIndex =
    ValueNotifier<int?>(null);

const AndroidNotificationChannel _announcementNotificationChannel =
    AndroidNotificationChannel(
      'rally_club_announcements',
      'Announcements',
      description: 'Notifications for new Rally Club announcements.',
      importance: Importance.high,
    );

final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

bool _localNotificationsReady = false;
bool _localNotificationsConfigured = false;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.instance.handleBackgroundMessage(message);
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  StreamSubscription<RemoteMessage>? _foregroundMessagesSub;
  StreamSubscription<RemoteMessage>? _openedMessagesSub;
  StreamSubscription<String>? _tokenRefreshSub;
  bool _initialized = false;
  String? _subscribedAnnouncementTopic;
  String? _desiredAnnouncementTopic;

  bool get _supportsMessaging {
    if (kIsWeb) {
      return false;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return false;
    }
  }

  Future<void> initialize() async {
    if (_initialized || !_supportsMessaging) {
      return;
    }

    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _ensureLocalNotificationsReady();
    await _configureLocalNotificationResponses();

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _foregroundMessagesSub = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );
    _openedMessagesSub = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleOpenedMessage,
    );
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
      _handleTokenRefresh,
      onError: (Object error) {
        debugPrint('NotificationService: token refresh failed: $error');
      },
    );

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleOpenedMessage(initialMessage);
    }
  }

  Future<void> handleBackgroundMessage(RemoteMessage message) async {
    if (!_supportsMessaging || !isAnnouncementNotificationData(message.data)) {
      return;
    }

    await _ensureLocalNotificationsReady();

    if (defaultTargetPlatform != TargetPlatform.android ||
        message.notification != null) {
      return;
    }

    await _showAnnouncementNotification(message);
  }

  Future<void> syncAnnouncementSubscription({String? clubId}) async {
    if (!_supportsMessaging) {
      return;
    }

    await initialize();

    final desiredTopic = (clubId == null || clubId.isEmpty)
        ? null
        : announcementTopicForClub(clubId);
    _desiredAnnouncementTopic = desiredTopic;

    if (_subscribedAnnouncementTopic != null &&
        _subscribedAnnouncementTopic != desiredTopic) {
      await FirebaseMessaging.instance.unsubscribeFromTopic(
        _subscribedAnnouncementTopic!,
      );
      _subscribedAnnouncementTopic = null;
    }

    if (desiredTopic == null || _subscribedAnnouncementTopic == desiredTopic) {
      return;
    }

    final permissionGranted = await _ensureNotificationPermission();
    if (!permissionGranted) {
      debugPrint('NotificationService: notification permission not granted.');
      return;
    }

    await FirebaseMessaging.instance.subscribeToTopic(desiredTopic);
    _subscribedAnnouncementTopic = desiredTopic;
  }

  Future<void> clearAnnouncementSubscription() async {
    _desiredAnnouncementTopic = null;

    if (!_supportsMessaging || _subscribedAnnouncementTopic == null) {
      return;
    }

    await FirebaseMessaging.instance.unsubscribeFromTopic(
      _subscribedAnnouncementTopic!,
    );
    _subscribedAnnouncementTopic = null;
  }

  Future<bool> _ensureNotificationPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> _ensureLocalNotificationsReady() async {
    if (_localNotificationsReady) {
      return;
    }

    final androidNotifications = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidNotifications?.createNotificationChannel(
      _announcementNotificationChannel,
    );

    _localNotificationsReady = true;
  }

  Future<void> _configureLocalNotificationResponses() async {
    if (_localNotificationsConfigured) {
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _localNotificationsPlugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _handleLocalNotificationResponse,
    );

    final launchDetails = await _localNotificationsPlugin
        .getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _handleLocalNotificationPayload(
        launchDetails?.notificationResponse?.payload,
      );
    }

    _localNotificationsConfigured = true;
  }

  Future<void> _showAnnouncementNotification(RemoteMessage message) async {
    final title =
        message.notification?.title ??
        message.data['title']?.toString() ??
        'New announcement';
    final body =
        message.notification?.body ??
        message.data['body']?.toString() ??
        'A new Rally Club announcement is ready to view.';

    await _localNotificationsPlugin.show(
      id: _notificationIdForMessage(message),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _announcementNotificationChannel.id,
          _announcementNotificationChannel.name,
          channelDescription: _announcementNotificationChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      ),
      payload: _encodeNotificationPayload(message.data),
    );
  }

  int _notificationIdForMessage(RemoteMessage message) {
    final rawId =
        message.messageId?.hashCode ??
        message.sentTime?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch;
    return rawId & 0x7fffffff;
  }

  String _encodeNotificationPayload(Map<String, dynamic> data) {
    final normalized = data.map(
      (key, value) => MapEntry(key, value?.toString()),
    );
    return jsonEncode(normalized);
  }

  void _handleLocalNotificationResponse(NotificationResponse response) {
    _handleLocalNotificationPayload(response.payload);
  }

  void _handleLocalNotificationPayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        return;
      }

      final normalized = decoded.map<String, dynamic>(
        (key, value) => MapEntry(key.toString(), value),
      );
      if (!isAnnouncementNotificationData(normalized)) {
        return;
      }

      _requestAnnouncementsNavigation();
    } catch (error) {
      debugPrint(
        'NotificationService: failed to parse notification payload: $error',
      );
    }
  }

  Future<void> _handleTokenRefresh(String token) async {
    debugPrint(
      'NotificationService: FCM token refreshed (${token.length} chars).',
    );

    if (_desiredAnnouncementTopic == null) {
      return;
    }

    try {
      await FirebaseMessaging.instance.subscribeToTopic(
        _desiredAnnouncementTopic!,
      );
      _subscribedAnnouncementTopic = _desiredAnnouncementTopic;
    } catch (error) {
      debugPrint(
        'NotificationService: failed to restore announcement topic: $error',
      );
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (!isAnnouncementNotificationData(message.data)) {
      return;
    }

    final title =
        message.notification?.title ??
        message.data['title']?.toString() ??
        'New announcement';
    final body =
        message.notification?.body ??
        message.data['body']?.toString() ??
        'A new Rally Club announcement is ready to view.';

    appScaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('$title\n$body'),
          action: SnackBarAction(
            label: 'View',
            onPressed: _requestAnnouncementsNavigation,
          ),
        ),
      );
  }

  void _handleOpenedMessage(RemoteMessage message) {
    if (!isAnnouncementNotificationData(message.data)) {
      return;
    }

    _requestAnnouncementsNavigation();
  }

  void _requestAnnouncementsNavigation() {
    pendingNotificationNavigationIndex.value = announcementsTabIndex;
  }

  Future<void> dispose() async {
    await _foregroundMessagesSub?.cancel();
    await _openedMessagesSub?.cancel();
    await _tokenRefreshSub?.cancel();
    _foregroundMessagesSub = null;
    _openedMessagesSub = null;
    _tokenRefreshSub = null;
    _initialized = false;
  }
}
