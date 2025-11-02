// lib/features/delivery/models/delivery_calculation.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DeliveryCalculation {
  final double distanceInKm;
  final double deliveryFee;
  final String sellerId;
  final String sellerName;
  final LatLng sellerLocation;
  final String rideType;
  final double pricePerKilometer;
  final bool isRealDistance; // New field to indicate if real distance was used


  DeliveryCalculation({
    required this.distanceInKm,
    required this.deliveryFee,
    required this.sellerId,
    required this.sellerName,
    required this.sellerLocation,
    required this.rideType,
    required this.pricePerKilometer,
    this.isRealDistance = true,
  });

  @override
  String toString() {
    return 'DeliveryCalculation(distance: ${distanceInKm.toStringAsFixed(2)}km, fee: K$deliveryFee, seller: $sellerName, rideType: $rideType)';
  }
}

// lib/features/delivery/models/ride_fare.dart
class RideFare {
  final String rideType;
  final double pricePerKilometer;
  final DateTime createdAt;

  RideFare({
    required this.rideType,
    required this.pricePerKilometer,
    required this.createdAt,
  });

  factory RideFare.fromMap(Map<String, dynamic> data) {
    return RideFare(
      rideType: data['rideType'] ?? 'motorbike',
      pricePerKilometer: (data['pricePerKilometer'] ?? 0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}

// lib/features/delivery/models/seller_info.dart
class SellerInfo {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String imageUrl;
  final double latitude;
  final double longitude;
  final String status;
  final double earnings;

  SellerInfo({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.earnings,
  });

  LatLng get location => LatLng(latitude, longitude);

  factory SellerInfo.fromMap(Map<String, dynamic> data) {
    return SellerInfo(
      uid: data['uid'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      status: data['status'] ?? '',
      earnings: (data['earnings'] ?? 0).toDouble(),
    );
  }
}