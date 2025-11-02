// lib/features/delivery/services/delivery_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:ubwinza_users/core/models/delivery_calculation.dart';

class DeliveryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _googleApiKey = 'YOUR_GOOGLE_API_KEY'; // Add to environment variables
  static const String _distanceMatrixBaseUrl = 'https://maps.googleapis.com/maps/api/distancematrix/json';

  // Caches
  final Map<String, double> _pricePerKmCache = {};
  final Map<String, double> _distanceCache = {}; // Cache for distance results

  /// 🚗 Calculate distance using Google Distance Matrix API (real road distance)
  Future<double?> calculateDrivingDistance(LatLng origin, LatLng destination) async {
    final cacheKey = '${origin.latitude},${origin.longitude}_${destination.latitude},${destination.longitude}';

    // Return cached distance if available
    if (_distanceCache.containsKey(cacheKey)) {
      return _distanceCache[cacheKey];
    }

    try {
      final url = '$_distanceMatrixBaseUrl?'
          'origins=${origin.latitude},${origin.longitude}'
          '&destinations=${destination.latitude},${destination.longitude}'
          '&mode=driving'
          '&key=$_googleApiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final element = data['rows'][0]['elements'][0];

          if (element['status'] == 'OK') {
            // Get distance in kilometers
            final distanceInMeters = element['distance']['value'] as int;
            final distanceInKm = distanceInMeters / 1000.0;

            // Cache the result
            _distanceCache[cacheKey] = distanceInKm;

            return distanceInKm;
          } else {
            print('Distance Matrix element status: ${element['status']}');
            // Fallback to Haversine if Google API fails
            return _calculateHaversineDistance(origin, destination);
          }
        } else {
          print('Distance Matrix API error: ${data['status']}');
          return _calculateHaversineDistance(origin, destination);
        }
      } else {
        print('HTTP error: ${response.statusCode}');
        return _calculateHaversineDistance(origin, destination);
      }
    } catch (e) {
      print('Error calling Distance Matrix API: $e');
      // Fallback to Haversine calculation
      return _calculateHaversineDistance(origin, destination);
    }
  }

  /// 📍 Fallback distance calculation using Haversine formula (straight-line)
  double _calculateHaversineDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double lat1 = start.latitude * pi / 180;
    double lon1 = start.longitude * pi / 180;
    double lat2 = end.latitude * pi / 180;
    double lon2 = end.longitude * pi / 180;

    double dLat = lat2 - lat1;
    double dLon = lon2 - lon1;

    double a = sin(dLat/2) * sin(dLat/2) +
        cos(lat1) * cos(lat2) * sin(dLon/2) * sin(dLon/2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// 🏪 Get seller information from Firestore
  Future<SellerInfo?> getSellerInfo(String sellerId) async {
    try {
      final doc = await _firestore.collection('sellers').doc(sellerId).get();
      if (!doc.exists) return null;
      return SellerInfo.fromMap(doc.data()!..putIfAbsent('id', () => sellerId));
    } catch (e) {
      print('Error getting seller info: $e');
      return null;
    }
  }

  /// 💰 Get price per kilometer from Firestore fares collection
  Future<double?> _getPricePerKm(String rideType) async {
    if (_pricePerKmCache.containsKey(rideType)) {
      return _pricePerKmCache[rideType];
    }
    try {
      final q = await _firestore
          .collection('fares')
          .where('rideType', isEqualTo: rideType)
          .limit(1)
          .get();

      if (q.docs.isEmpty) return null;
      final data = q.docs.first.data();
      final p = data['pricePerKilometer'];
      final v = (p is num) ? p.toDouble() : double.tryParse('$p');
      if (v != null) _pricePerKmCache[rideType] = v;
      return v;
    } catch (e) {
      print('Error getting fare: $e');
      return null;
    }
  }

  /// 🚚 Calculate delivery fee using Google API distance × pricePerKm
  Future<DeliveryCalculation?> calculateDeliveryFee({
    required String sellerId,
    required LatLng deliveryLocation,
    required String rideType,
    bool useRealDistance = true, // Switch between Google API and Haversine
  }) async {
    try {
      final sellerInfo = await getSellerInfo(sellerId);
      if (sellerInfo == null) return null;

      final pricePerKm = await _getPricePerKm(rideType);
      if (pricePerKm == null) return null;

      // Calculate distance (Google API with Haversine fallback)
      double distance;
      if (useRealDistance) {
        final realDistance = await calculateDrivingDistance(
            sellerInfo.location,
            deliveryLocation
        );
        distance = realDistance ?? _calculateHaversineDistance(sellerInfo.location, deliveryLocation);
      } else {
        distance = _calculateHaversineDistance(sellerInfo.location, deliveryLocation);
      }

      // Calculate delivery fee
      final fee = distance * pricePerKm;

      return DeliveryCalculation(
        distanceInKm: distance,
        deliveryFee: fee,
        sellerId: sellerId,
        sellerName: sellerInfo.name,
        sellerLocation: sellerInfo.location,
        rideType: rideType,
        pricePerKilometer: pricePerKm,
        isRealDistance: useRealDistance, // Flag to indicate if real distance was used
      );
    } catch (e) {
      print('Error calculating delivery fee: $e');
      return null;
    }
  }

  /// 🔄 Batch calculate delivery fees for multiple sellers
  Future<Map<String, DeliveryCalculation>> calculateMultipleDeliveryFees({
    required List<String> sellerIds,
    required LatLng deliveryLocation,
    required String rideType,
  }) async {
    final Map<String, DeliveryCalculation> results = {};

    for (final sellerId in sellerIds) {
      final calculation = await calculateDeliveryFee(
        sellerId: sellerId,
        deliveryLocation: deliveryLocation,
        rideType: rideType,
      );
      if (calculation != null) {
        results[sellerId] = calculation;
      }
    }

    return results;
  }

  /// 🗑️ Clear cache (useful for testing or when prices change)
  void clearCache() {
    _pricePerKmCache.clear();
    _distanceCache.clear();
  }

  Future<Map<String, SellerInfo>> getSellersInfo(List<String> sellerIds) async {
    final Map<String, SellerInfo> sellers = {};
    for (final id in sellerIds) {
      final info = await getSellerInfo(id);
      if (info != null) sellers[id] = info;
    }
    return sellers;
  }
}