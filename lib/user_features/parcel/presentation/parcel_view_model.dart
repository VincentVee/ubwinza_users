import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/models/parcel_order_model.dart';
import '../data/parcel_repository.dart';


class ParcelViewModel extends ChangeNotifier {
  final repo = ParcelRepository();


  String vehicleType = 'motorbike'; // or 'bicycle'
  String fromAddress = '';
  String toAddress = '';
  double? fromLat; double? fromLng; double? toLat; double? toLng;
  String note = '';
  num distanceKm = 0; num fee = 0;
  bool busy = false; String? error;


  void setVehicle(String v) { vehicleType = v; notifyListeners(); }
  void setFrom(String a, double lat, double lng) { fromAddress = a; fromLat = lat; fromLng = lng; _recompute(); }
  void setTo(String a, double lat, double lng) { toAddress = a; toLat = lat; toLng = lng; _recompute(); }
  void setNote(String n) { note = n; notifyListeners(); }


  Future<Position> locate() => Geolocator.getCurrentPosition();


  void _recompute() {
    if (fromLat != null && toLat != null) {
      final d = Geolocator.distanceBetween(fromLat!, fromLng!, toLat!, toLng!) / 1000.0; // km
      distanceKm = d;
// simple fee: base + per-km, cheaper for bicycle
      final base = vehicleType == 'bicycle' ? 6 : 10;
      final perKm = vehicleType == 'bicycle' ? 3 : 5;
      fee = base + (perKm * max(1, d)).round();
    }
    notifyListeners();
  }

  Future<void> createOrder({required String userId}) async {
    if (fromLat == null || toLat == null) { error = 'Pick both addresses'; notifyListeners(); return; }
    try {
      busy = true; error = null; notifyListeners();
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final m = ParcelOrderModel(
        id: id,
        userId: userId,
        riderId: null,
        type: 'parcel',
        status: 'new',
        vehicleType: vehicleType,
        fromAddress: fromAddress,
        fromLat: fromLat!,
        fromLng: fromLng!,
        toAddress: toAddress,
        toLat: toLat!,
        toLng: toLng!,
        note: note,
        distanceKm: distanceKm,
        deliveryFee: fee,
        createdAt: DateTime.now(),
      );
      await repo.create(m);
    } catch (e) { error = e.toString(); } finally { busy = false; notifyListeners(); }
  }
}