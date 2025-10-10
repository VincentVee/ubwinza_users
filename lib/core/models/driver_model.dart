import 'package:cloud_firestore/cloud_firestore.dart';

class Driver {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String imageUrl;
  final String status; // approved, active, busy, offline
  final double latitude;
  final double longitude;
  final String address;
  final double earnings;
  final String vehicleType; // standard, premium, bike, truck
  final String vehicleModel;
  final String vehicleColor;
  final String licensePlate;
  final double rating;
  final int totalRides;

  Driver({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.imageUrl,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.earnings,
    required this.vehicleType,
    required this.vehicleModel,
    required this.vehicleColor,
    required this.licensePlate,
    this.rating = 5.0,
    this.totalRides = 0,
  });

  // Convert Firestore document to Driver object
  factory Driver.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Driver(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      status: data['status'] ?? 'approved',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      address: data['address'] ?? '',
      earnings: (data['earnings'] ?? 0.0).toDouble(),
      vehicleType: data['vehicleType'] ?? 'standard',
      vehicleModel: data['vehicleModel'] ?? '',
      vehicleColor: data['vehicleColor'] ?? '',
      licensePlate: data['licensePlate'] ?? '',
      rating: (data['rating'] ?? 5.0).toDouble(),
      totalRides: (data['totalRides'] ?? 0).toInt(),
    );
  }

  // Convert Driver object to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'imageUrl': imageUrl,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'earnings': earnings,
      'vehicleType': vehicleType,
      'vehicleModel': vehicleModel,
      'vehicleColor': vehicleColor,
      'licensePlate': licensePlate,
      'rating': rating,
      'totalRides': totalRides,
    };
  }

  // Copy with method for updates
  Driver copyWith({
    String? status,
    double? latitude,
    double? longitude,
    double? earnings,
    double? rating,
    int? totalRides,
  }) {
    return Driver(
      id: id,
      name: name,
      email: email,
      phone: phone,
      imageUrl: imageUrl,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address,
      earnings: earnings ?? this.earnings,
      vehicleType: vehicleType,
      vehicleModel: vehicleModel,
      vehicleColor: vehicleColor,
      licensePlate: licensePlate,
      rating: rating ?? this.rating,
      totalRides: totalRides ?? this.totalRides,
    );
  }
}