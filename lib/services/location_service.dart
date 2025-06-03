import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart' as permission;

class LocationService {
  final loc.Location _location = loc.Location();
  StreamSubscription<Position>? _locationSubscription;
  final _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Initialize notifications
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _notificationsPlugin.initialize(initializationSettings);

    // Initialize background service
    await initializeBackgroundService();
  }

  Future<void> initializeBackgroundService() async {
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'convoy_location',
        initialNotificationTitle: 'Convoy Location Service',
        initialNotificationContent: 'Running in background',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // Background service logic
    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Add periodic location updates in background
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          // Update location
          try {
            Position position = await Geolocator.getCurrentPosition();
            service.invoke(
              'update',
              {
                'latitude': position.latitude,
                'longitude': position.longitude,
              },
            );
          } catch (e) {
            print('Error getting location in background: $e');
          }
        }
      }
    });
  }

  Future<bool> requestPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await showLocationDisabledNotification();
      return false;
    }

    // Request location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    // Request background location permission
    if (permission == LocationPermission.whileInUse) {
      final backgroundStatus = await permission.Permission.locationAlways.status;
      if (!backgroundStatus.isGranted) {
        final result = await permission.Permission.locationAlways.request();
        if (!result.isGranted) {
          return false;
        }
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<void> showLocationDisabledNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'location_channel',
      'Location Services',
      channelDescription: 'Notifications about location services',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      0,
      'Location Services Disabled',
      'Please enable location services to use the convoy feature',
      details,
    );
  }

  Future<LatLng?> getCurrentLocation() async {
    try {
      if (!await requestPermissions()) {
        throw Exception('Location permissions not granted');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }

  Future<void> startLocationUpdates(Function(Position) onLocationUpdate) async {
    if (!await requestPermissions()) {
      throw Exception('Location permissions not granted');
    }

    _locationSubscription?.cancel();
    _locationSubscription = getLocationStream().listen(
      onLocationUpdate,
      onError: (error) {
        print('Location stream error: $error');
      },
    );
  }

  Future<void> stopLocationUpdates() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  Future<double> calculateDistance(LatLng start, LatLng end) async {
    return Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
  }

  Future<String> getEstimatedArrivalTime(
    double distance,
    double averageSpeed,
  ) async {
    // Assuming averageSpeed is in km/h and distance is in meters
    final hours = distance / 1000 / averageSpeed;
    final minutes = (hours * 60).round();

    if (minutes < 60) {
      return '$minutes minutes';
    } else {
      final remainingMinutes = minutes % 60;
      final hourCount = minutes ~/ 60;
      return '$hourCount hours ${remainingMinutes > 0 ? '$remainingMinutes minutes' : ''}';
    }
  }
}