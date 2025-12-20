import 'package:cloud_firestore/cloud_firestore.dart';

class RideRequest {
  final String id;
  final String userId;
  final String userName;
  final String userImage;
  final String userPhone;
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String destinationAddress;
  final double destinationLat;
  final double destinationLng;
  final String status; // pending, accepted, in_progress, completed, cancelled
  final String vehicleType; // motorbike, bicycle, car, truck
  final double estimatedFare;
  final double? actualFare;
  final String? driverId;
  final String? driverName;
  final String? driverImage;
  final String? driverPhone;
  final String? driverVehicleType;
  final String? driverVehicleModel;
  final String? driverLicensePlate;
  final double? driverLat;
  final double? driverLog;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  RideRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userImage,
    required this.userPhone,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.destinationAddress,
    required this.destinationLat,
    required this.destinationLng,
    required this.status,
    required this.vehicleType,
    required this.estimatedFare,
    this.actualFare,
    this.driverId,
    this.driverName,
    this.driverImage,
    this.driverPhone,
    this.driverVehicleType,
    this.driverVehicleModel,
    this.driverLicensePlate,
    this.driverLat,
    this.driverLog,
    required this.createdAt,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
  });

  factory RideRequest.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return RideRequest(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userImage: data['userImage'] ?? '',
      userPhone: data['userPhone'] ?? '',
      pickupAddress: data['pickupAddress'] ?? '',
      pickupLat: (data['pickupLat'] ?? 0.0).toDouble(),
      pickupLng: (data['pickupLng'] ?? 0.0).toDouble(),
      destinationAddress: data['destinationAddress'] ?? '',
      destinationLat: (data['destinationLat'] ?? 0.0).toDouble(),
      destinationLng: (data['destinationLng'] ?? 0.0).toDouble(),
      status: data['status'] ?? 'pending',
      vehicleType: data['vehicleType'] ?? 'motorbike',
      estimatedFare: (data['estimatedFare'] ?? 0.0).toDouble(),
      actualFare: data['actualFare']?.toDouble(),
      driverId: data['driverId'],
      driverName: data['driverName'],
      driverImage: data['driverImage'],
      driverPhone: data['driverPhone'],
      driverVehicleType: data['driverVehicleType'],
      driverVehicleModel: data['driverVehicleModel'],
      driverLicensePlate: data['driverLicensePlate'],
      driverLat: data['driverLat'],
      driverLog: data['driverLog'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      acceptedAt: data['acceptedAt'] != null
          ? (data['acceptedAt'] as Timestamp).toDate()
          : null,
      startedAt: data['startedAt'] != null
          ? (data['startedAt'] as Timestamp).toDate()
          : null,
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userImage': userImage,
      'userPhone': userPhone,
      'pickupAddress': pickupAddress,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'destinationAddress': destinationAddress,
      'destinationLat': destinationLat,
      'destinationLng': destinationLng,
      'status': status,
      'vehicleType': vehicleType,
      'estimatedFare': estimatedFare,
      'actualFare': actualFare,
      'driverId': driverId,
      'driverName': driverName,
      'driverImage': driverImage,
      'driverPhone': driverPhone,
      'driverVehicleType': driverVehicleType,
      'driverVehicleModel': driverVehicleModel,
      'driverLicensePlate': driverLicensePlate,
      'driverLat': driverLat,
      'driverLog': driverLog,
      'createdAt': Timestamp.fromDate(createdAt),
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }
}