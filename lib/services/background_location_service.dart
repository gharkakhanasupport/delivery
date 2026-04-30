import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service to keep location tracking alive even when app is killed or in background
class BackgroundLocationService {
  static final BackgroundLocationService _instance = BackgroundLocationService._internal();
  factory BackgroundLocationService() => _instance;
  BackgroundLocationService._internal();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final service = FlutterBackgroundService();

    // Setup Notification Channel for Foreground Service
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'gkk_delivery_tracking', // id
      'Active Delivery Tracking', // title
      description: 'This channel is used to track your location while delivering.',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // This will be executed when app is in background
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'gkk_delivery_tracking',
        initialNotificationTitle: 'GKK Delivery Active',
        initialNotificationContent: 'Tracking your location for the customer',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
    
    _isInitialized = true;
  }

  void startTracking() async {
    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();
    if (!isRunning) {
      service.startService();
    }
  }

  void stopTracking() async {
    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();
    if (isRunning) {
      service.invoke("stopService");
    }
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Only available for flutter 3.0.0 and later
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Re-initialize dependencies for the background isolate
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  final client = Supabase.instance.client;
  
  // High accuracy for active delivery
  const locationSettings = LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 10,
  );

  final userId = client.auth.currentUser?.id;

  // Stream location updates
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        try {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: locationSettings,
          );
          if (userId != null) {
            // Update location in Delivery DB so User App can track it
            await client.from('delivery_profiles').update({
              'current_location': 'POINT(${pos.longitude} ${pos.latitude})',
              'last_active_at': DateTime.now().toIso8601String(),
            }).eq('id', userId);
            
            service.setForegroundNotificationInfo(
              title: "GKK Delivery Active",
              content: "Updating location... (${pos.speed.toStringAsFixed(1)} m/s)",
            );
          }
        } catch (e) {
          debugPrint('Background location error: $e');
        }
      }
    }
  });
}
