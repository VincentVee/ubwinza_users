import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/models/current_location.dart';
import '../../core/models/driver_model.dart';

class NearbyDriversViewModel extends ChangeNotifier {
  NearbyDriversViewModel({required this.vehicleType}) {
    _init();
  }

  final String vehicleType;
  bool loading = true;
  String? error;
  List<Driver> drivers = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  Future<void> _init() async {
    try {
      final me = await getCurrentLocation();

      // simple ~5km bounding box
      const km = 5.0;
      const degPerKmLat = 1 / 110.574;
      final dLat = km * degPerKmLat;
      final dLng = km * (1 / (111.320 * math.cos(_degToRad(me.lat))));

      final minLat = me.lat - dLat;
      final maxLat = me.lat + dLat;
      final minLng = me.lng - dLng;
      final maxLng = me.lng + dLng;

      final q = FirebaseFirestore.instance
          .collection('riders')
          .where('vehicleType', isEqualTo: vehicleType)
          .where('status', isEqualTo: 'approved') // Changed from 'available' to 'status'
          .where('latitude', isGreaterThanOrEqualTo: minLat)
          .where('latitude', isLessThanOrEqualTo: maxLat);

      _sub = q.snapshots().listen((snap) {
        final all = snap.docs
            .map((d) => Driver.fromFirestore(d)) // Updated to use fromFirestore
            .where((d) => d.longitude >= minLng && d.longitude <= maxLng)
            .toList();
        drivers = all;
        loading = false;
        error = null;
        notifyListeners();
      }, onError: (e) {
        error = e.toString();
        loading = false;
        notifyListeners();
      });
    } catch (e) {
      error = e.toString();
      loading = false;
      notifyListeners();
    }
  }

  // Refresh nearby drivers
  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();

    // Cancel existing subscription
    _sub?.cancel();

    // Reinitialize
    await _init();
  }

  // Get drivers within specific radius in meters
  List<Driver> getDriversWithinRadius(double radiusInMeters, double userLat, double userLng) {
    return drivers.where((driver) {
      final distance = _calculateDistance(
          userLat,
          userLng,
          driver.latitude,
          driver.longitude
      );
      return distance <= radiusInMeters;
    }).toList();
  }

  // Calculate distance between two points using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0; // Earth's radius in meters
    final phi1 = _degToRad(lat1);
    final phi2 = _degToRad(lat2);
    final deltaPhi = _degToRad(lat2 - lat1);
    final deltaLambda = _degToRad(lon2 - lon1);

    final a = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
        math.cos(phi1) * math.cos(phi2) *
            math.sin(deltaLambda / 2) * math.sin(deltaLambda / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return R * c;
  }

  // Get closest driver
  Driver? getClosestDriver(double userLat, double userLng) {
    if (drivers.isEmpty) return null;

    Driver closestDriver = drivers.first;
    double minDistance = _calculateDistance(
        userLat, userLng,
        closestDriver.latitude, closestDriver.longitude
    );

    for (final driver in drivers.skip(1)) {
      final distance = _calculateDistance(
          userLat, userLng,
          driver.latitude, driver.longitude
      );
      if (distance < minDistance) {
        minDistance = distance;
        closestDriver = driver;
      }
    }

    return closestDriver;
  }

  // Filter drivers by additional criteria
  List<Driver> filterDrivers({
    double? minRating,
    int? minRides,
    List<String>? excludedDriverIds,
  }) {
    var filtered = drivers;

    if (minRating != null) {
      filtered = filtered.where((driver) => driver!.rating >= minRating).toList();
    }

    if (minRides != null) {
      filtered = filtered.where((driver) => driver!.totalRides >= minRides).toList();
    }

    if (excludedDriverIds != null && excludedDriverIds.isNotEmpty) {
      filtered = filtered.where((driver) => !excludedDriverIds.contains(driver?.id)).toList();
    }

    return filtered;
  }

  // Update driver availability
  Future<void> updateDriverAvailability(String driverId, bool available) async {
    try {
      await FirebaseFirestore.instance
          .collection('riders')
          .doc(driverId)
          .update({
        'available': available,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating driver availability: $e');
      rethrow;
    }
  }

  // Get driver count by vehicle type
  Map<String, int> getDriverCountByVehicleType() {
    final countMap = <String, int>{};

    for (final driver in drivers) {
      countMap.update(
          driver.vehicleType,
              (value) => value + 1,
          ifAbsent: () => 1
      );
    }

    return countMap;
  }

  double _degToRad(double d) => d * math.pi / 180.0;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}