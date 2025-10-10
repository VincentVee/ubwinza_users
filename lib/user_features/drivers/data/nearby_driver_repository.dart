import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';
import '../../../core/services/firebase_paths.dart';
import '../../../core/services/firebase_service.dart';

class NearbyDriverRepository {
  final _db = UFirebaseService.I.db;
  final _geo = GeoFlutterFire();

  /// Live stream of nearby drivers by radius (km) and vehicle type
  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> watchNearby({
    required double lat,
    required double lng,
    required double radiusKm,
    required String vehicleType, // motorbike | bicycle
  }) {
    final center = GeoFirePoint(lat, lng);
    final ref = _db
        .collection(UFirebasePaths.riders)
        .where('available', isEqualTo: true)
        .where('vehicleType', isEqualTo: vehicleType);

    // GeoFlutterFire returns List<DocumentSnapshot>
    return _geo
        .collection(collectionRef: ref)
        .within(
      center: center,
      radius: radiusKm,
      field: 'position',
      strictMode: true,
    )
        .map((docs) => docs.cast<DocumentSnapshot<Map<String, dynamic>>>());
  }
}