import '../../../core/models/parcel_order_model.dart';
import '../../../core/services/firebase_paths.dart';
import '../../../core/services/firebase_service.dart';

class ParcelRepository {
  final _db = UFirebaseService.I.db;
  Future<void> create(ParcelOrderModel m) async {
    await _db.collection(UFirebasePaths.orders).doc(m.id).set(m.toMap());
  }
}