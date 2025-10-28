// lib/features/delivery/services/delivery_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ubwinza_users/core/models/delivery_calculation.dart';

class DeliveryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // simple in-memory cache: {'motorbike': 8.0, 'bicycle': 4.0}
  final Map<String, double> _pricePerKmCache = {};

  double calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371;
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

  /// 🔁 Get pricePerKilometer for a specific rideType from 'fares'
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

  /// 💰 Calculate delivery fee using distance × pricePerKm (by rideType)
  Future<DeliveryCalculation?> calculateDeliveryFee({
    required String sellerId,
    required LatLng deliveryLocation,
    required String rideType,
  }) async {
    try {
      final sellerInfo = await getSellerInfo(sellerId);
      if (sellerInfo == null) return null;

      final pricePerKm = await _getPricePerKm(rideType);
      if (pricePerKm == null) return null;

      final distance = calculateDistance(sellerInfo.location, deliveryLocation);
      final fee = distance * pricePerKm;

      return DeliveryCalculation(
        distanceInKm: distance,
        deliveryFee: fee,
        sellerId: sellerId,
        sellerName: sellerInfo.name,
        sellerLocation: sellerInfo.location,
        rideType: rideType,
        pricePerKilometer: pricePerKm,
      );
    } catch (e) {
      print('Error calculating delivery fee: $e');
      return null;
    }
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
