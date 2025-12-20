import 'dart:async';

import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Aggressively fetches the current device location with high accuracy and a timeout.
  static Future<Position> current() async {
    // 1. Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Location services are disabled on the device.';
    }

    // 2. Check and request permissions
    LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }

    // 3. Handle permanent denial
    if (p == LocationPermission.deniedForever) {
      throw 'Location permission permanently denied. Please enable it in device settings.';
    }

    // 4. Set aggressive location settings to force a fresh, high-accuracy fix
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation, // Highest possible accuracy
      distanceFilter: 0,
    );

    try {
      // 5. Get the position, applying the settings and a timeout
      return await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
        timeLimit: const Duration(seconds: 15),
      );
    } on TimeoutException {
      throw 'Failed to acquire location within the time limit.';
    } catch (e) {
      throw 'An error occurred while fetching location: $e';
    }
  }
}