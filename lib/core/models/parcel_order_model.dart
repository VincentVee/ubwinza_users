class ParcelOrderModel {
  final String id;
  final String userId;
  final String? riderId; // selected later
  final String type; // 'parcel'
  final String status; // new, accepted, picked, delivering, delivered, cancelled
  final String vehicleType; // motorbike | bicycle
  final String fromAddress;
  final double fromLat;
  final double fromLng;
  final String toAddress;
  final double toLat;
  final double toLng;
  final String note; // what is in the parcel
  final num distanceKm;
  final num deliveryFee;
  final DateTime createdAt;

  ParcelOrderModel({
    required this.id,
    required this.userId,
    required this.riderId,
    required this.type,
    required this.status,
    required this.vehicleType,
    required this.fromAddress,
    required this.fromLat,
    required this.fromLng,
    required this.toAddress,
    required this.toLat,
    required this.toLng,
    required this.note,
    required this.distanceKm,
    required this.deliveryFee,
    required this.createdAt,
  });
  
Map<String, dynamic> toMap() => {
  'userId': userId,
  'riderId': riderId,
  'type': type,
  'status': status,
  'vehicleType': vehicleType,
  'fromAddress': fromAddress,
  'fromLat': fromLat,
  'fromLng': fromLng,
  'toAddress': toAddress,
  'toLat': toLat,
  'toLng': toLng,
  'note': note,
  'distanceKm': distanceKm,
  'deliveryFee': deliveryFee,
  'createdAt': createdAt,
};
}