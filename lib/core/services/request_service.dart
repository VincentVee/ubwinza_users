import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/request_model.dart';
import 'fare_service.dart';

class RequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FareService _fareService = FareService();


  // Create new ride request
  Future<String> createRideRequest(RideRequest request) async {
    final docRef = await _firestore.collection('requests').add(request.toMap());
    return docRef.id;
  }

  final _requests = FirebaseFirestore.instance.collection('requests');

  Future<void> cancelRideRequest(String requestId) async {
    await _requests.doc(requestId).update({
      'status': 'cancelled',
      'cancelledAt': DateTime.now(),
    });
  }

  // your other methods (calculateEstimatedFare, createRideRequest, etc.)


  // Get specific request stream
  Stream<RideRequest> getRequestStream(String requestId) {
    return _firestore
        .collection('requests')
        .doc(requestId)
        .snapshots()
        .map((snapshot) => RideRequest.fromFirestore(snapshot));
  }

  // Get all pending requests for drivers (filtered by vehicle type)
  Stream<List<RideRequest>> getPendingRequests(String vehicleType) {
    return _firestore
        .collection('requests')
        .where('status', isEqualTo: 'pending')
        .where('vehicleType', isEqualTo: vehicleType)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => RideRequest.fromFirestore(doc))
        .toList());
  }

  // Get user's active requests
  Stream<List<RideRequest>> getUserActiveRequests(String userId) {
    return _firestore
        .collection('requests')
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['pending', 'accepted', 'in_progress'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => RideRequest.fromFirestore(doc))
        .toList());
  }

  // Driver accepts request
  Future<void> acceptRequest({
    required String requestId,
    required String driverId,
    required String driverName,
    required String driverImage,
    required String driverPhone,
    required String driverVehicleType,
    required String driverVehicleModel,
    required String driverLicensePlate,
  }) async {
    await _firestore.collection('requests').doc(requestId).update({
      'status': 'accepted',
      'driverId': driverId,
      'driverName': driverName,
      'driverImage': driverImage,
      'driverPhone': driverPhone,
      'driverVehicleType': driverVehicleType,
      'driverVehicleModel': driverVehicleModel,
      'driverLicensePlate': driverLicensePlate,
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  // Update request status
  Future<void> updateRequestStatus(String requestId, String status) async {
    final updateData = {'status': status};

    if (status == 'in_progress') {
      updateData['startedAt'] = FieldValue.serverTimestamp() as String;
    } else if (status == 'completed') {
      updateData['completedAt'] = FieldValue.serverTimestamp() as String;
    }

    await _firestore.collection('requests').doc(requestId).update(updateData);
  }

  // Cancel request
  Future<void> cancelRequest(String requestId) async {
    await _firestore.collection('requests').doc(requestId).update({
      'status': 'cancelled',
    });
  }

  // Calculate estimated fare (simple distance-based calculation)
  Future<double> calculateEstimatedFare(double distance, String vehicleType) async {
    final baseFare = await _fareService.getBaseFare(vehicleType);
    final pricePerKm = await _fareService.getPricePerKm(vehicleType);
    return baseFare + (distance * pricePerKm);
  }
}