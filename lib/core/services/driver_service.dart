import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/driver_model.dart';

class DriverService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all approved drivers with optional vehicle type filter
  Stream<List<Driver>> getApprovedDrivers({String? vehicleType}) {
    Query query = _firestore
        .collection('riders')
        .where('status', isEqualTo: 'approved');

    if (vehicleType != null && vehicleType.isNotEmpty) {
      query = query.where('vehicleType', isEqualTo: vehicleType);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Driver.fromFirestore(doc)).toList());
  }

  // Update driver status
  Future<void> updateDriverStatus(String driverId, String status) async {
    await _firestore.collection('riders').doc(driverId).update({
      'status': status,
    });
  }

  // Update driver location
  Future<void> updateDriverLocation(
      String driverId,
      double latitude,
      double longitude
      ) async {
    await _firestore.collection('riders').doc(driverId).update({
      'latitude': latitude,
      'longitude': longitude,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  // Get driver by ID
  Future<Driver?> getDriverById(String driverId) async {
    final doc = await _firestore.collection('riders').doc(driverId).get();
    return doc.exists ? Driver.fromFirestore(doc) : null;
  }
}