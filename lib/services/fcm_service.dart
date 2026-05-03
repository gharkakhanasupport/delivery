import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart' show rootNavigatorKey;
import 'dispatch_service.dart';

/// Background notification plugin (top-level for isolate handler)
final FlutterLocalNotificationsPlugin _bgLocalNotifications =
    FlutterLocalNotificationsPlugin();

/// Top-level background message handler.
/// Must be top-level function (not class method) for Flutter background isolate.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  debugPrint('🔔 Delivery BG message received');
  debugPrint('📦 Data payload: ${message.data}');

  final data = message.data;
  if (data.isEmpty || data['title'] == null) return;

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await _bgLocalNotifications.initialize(settings: initSettings);

  const androidChannel = AndroidNotificationChannel(
    'gkk_delivery_orders',
    'Delivery Order Alerts',
    description: 'New pickup & delivery status notifications',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  await _bgLocalNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(androidChannel);

  const androidDetails = AndroidNotificationDetails(
    'gkk_delivery_orders',
    'Delivery Order Alerts',
    channelDescription: 'New pickup & delivery status notifications',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
    icon: '@mipmap/ic_launcher',
    color: Color(0xFFEA580C),
    enableVibration: true,
    playSound: true,
  );

  final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  await _bgLocalNotifications.show(
    id: notificationId,
    title: data['title']?.toString() ?? 'Delivery',
    body: data['body']?.toString() ?? '',
    notificationDetails: const NotificationDetails(android: androidDetails),
  );

  debugPrint('✅ Delivery BG notification shown');
}

/// FCM push notification service for Delivery App.
///
/// Handles:
/// - new pickup alerts (from Kitchen marking order ready → Edge Function
///   broadcasts to all online partners within 5 km)
/// - status/handoff updates
///
/// Call [initialize] in main.dart; then [registerTokenWithSupabase] after
/// partner auth is confirmed.
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      await _requestPermissions();
      await _initializeLocalNotifications();

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      final token = await _messaging.getToken();
      debugPrint('📱 Delivery FCM Token: $token');

      _isInitialized = true;
      debugPrint('✅ Delivery FCM Service initialized');
    } catch (e) {
      debugPrint('❌ Delivery FCM init error: $e');
    }
  }

  Future<void> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('🔐 Delivery notif permission: ${settings.authorizationStatus}');
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('📲 Delivery notif tap: ${response.payload}');
      },
    );

    const androidChannel = AndroidNotificationChannel(
      'gkk_delivery_orders',
      'Delivery Order Alerts',
      description: 'New pickup & delivery status notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('🔔 Delivery FG message: ${message.data}');

    final data = message.data;
    if (data.isEmpty) return;

    // New pickup broadcast → show full-screen incoming order sheet
    if (data['type'] == 'new_pickup') {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null) {
        DispatchService().showIncomingOrder(
          ctx,
          Map<String, dynamic>.from(data),
        );
        return;
      }
    }

    // Fallback: silent local notification for other types
    if (data['title'] == null) return;
    final title = data['title']?.toString() ?? 'Delivery';
    final body = data['body']?.toString() ?? '';
    _showLocalNotification(title: title, body: body, payload: data.toString());
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'gkk_delivery_orders',
      'Delivery Order Alerts',
      channelDescription: 'New pickup & delivery status notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFFEA580C),
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('📲 Delivery notif tapped: ${message.data}');
    final data = message.data;
    if (data['type'] == 'new_pickup') {
      // Delay 500ms so UI is ready after cold start
      Future.delayed(const Duration(milliseconds: 500), () {
        final ctx = rootNavigatorKey.currentContext;
        if (ctx == null || !ctx.mounted) return;
        DispatchService().showIncomingOrder(
          ctx,
          Map<String, dynamic>.from(data),
        );
      });
    }
  }

  /// Returns current FCM device token.
  Future<String?> getToken() => _messaging.getToken();

  /// Register this device's FCM token in Supabase `fcm_tokens` table.
  /// Delivery uses Firebase phone auth; `agentId` should be the delivery_profiles
  /// row id (UUID as string). Also wires token refresh listener.
  Future<void> registerTokenWithSupabase(String agentId) async {
    if (agentId.isEmpty) {
      debugPrint('⚠️ Delivery FCM: agentId empty');
      return;
    }

    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('⚠️ Delivery FCM: no device token');
        return;
      }

      final platform = Platform.isAndroid
          ? 'android'
          : Platform.isIOS
          ? 'ios'
          : 'web';

      final actualUserId = Supabase.instance.client.auth.currentUser?.id ?? agentId;
      if (actualUserId.isNotEmpty) {
        await Supabase.instance.client.rpc(
          'register_unified_fcm_token',
          params: {
            'p_user_id': actualUserId,
            'p_device_token': token,
            'p_platform': platform,
          },
        );
        debugPrint('✅ Delivery FCM token registered for $actualUserId');

        _messaging.onTokenRefresh.listen((newToken) async {
          try {
            await Supabase.instance.client.rpc(
              'register_unified_fcm_token',
              params: {
                'p_user_id': actualUserId,
                'p_device_token': newToken,
                'p_platform': platform,
              },
            );
            debugPrint('✅ Delivery FCM token refreshed');
          } catch (e) {
            debugPrint('⚠️ Delivery FCM refresh failed: $e');
          }
        });
      }
    } catch (e) {
      debugPrint('⚠️ Delivery FCM register failed: $e');
    }
  }
}
