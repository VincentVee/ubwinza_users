// lib/core/services/fare_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FareService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getFareByVehicleType(String vehicleType) async {
    try {
      print('🔍 Fetching fare for: $vehicleType');
      final snapshot = await _firestore
          .collection('fares')
          .where('rideType', isEqualTo: vehicleType.toLowerCase())
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        print('✅ Found fare data: $data');
        return data;
      }
      print('❌ No fare data found for: $vehicleType');
      return null;
    } catch (e) {
      print('❌ Error fetching fare: $e');
      return null;
    }
  }

  Future<double> getPricePerKm(String vehicleType) async {
    final fareData = await getFareByVehicleType(vehicleType);
    if (fareData != null && fareData.containsKey('pricePerKilometer')) {
      final price = (fareData['pricePerKilometer'] as num).toDouble();
      print('💰 Price per km for $vehicleType: $price');
      return price;
    }

    // Fallback prices if no data found
    final fallbackPrice = vehicleType.toLowerCase() == 'motorbike' ? 15.0 : 10.0;
    print('🔄 Using fallback price per km for $vehicleType: $fallbackPrice');
    return fallbackPrice;
  }

  Future<double> getBaseFare(String vehicleType) async {
    final fareData = await getFareByVehicleType(vehicleType);
    if (fareData != null && fareData.containsKey('baseFare')) {
      final base = (fareData['baseFare'] as num).toDouble();
      print('🏷️ Base fare for $vehicleType: $base');
      return base;
    }

    // Fallback base fares
    final fallbackBase = vehicleType.toLowerCase() == 'motorbike' ? 20.0 : 15.0;
    print('🔄 Using fallback base fare for $vehicleType: $fallbackBase');
    return fallbackBase;
  }
}