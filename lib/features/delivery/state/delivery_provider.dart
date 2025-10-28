// lib/features/delivery/state/delivery_provider.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ubwinza_users/core/models/delivery_calculation.dart';
import 'package:ubwinza_users/core/models/delivery_method.dart';
import 'package:ubwinza_users/core/services/pref_service.dart';
import 'package:ubwinza_users/features/delivery/services/delivery_service.dart';

class DeliveryProvider with ChangeNotifier {
  final DeliveryService _deliveryService = DeliveryService();

  final Map<String, DeliveryCalculation> _deliveryCalculations = {};
  final Map<String, SellerInfo> _sellersInfo = {};
  LatLng? _deliveryLocation;

  // 🔑 keep track of current rideType
  String _rideType =
      PrefsService.I.getDeliveryMethod() == DeliveryMethod.bicycle
          ? 'bicycle'
          : 'motorbike';

  // Optional public setter to switch rideType and recompute
  Future<void> setRideType(String rideType) async {
    if (rideType == _rideType) return;
    _rideType = rideType;
    await _recalculateAllFees();
    notifyListeners();
  }

  Map<String, DeliveryCalculation> get deliveryCalculations => _deliveryCalculations;
  Map<String, SellerInfo> get sellersInfo => _sellersInfo;
  LatLng? get deliveryLocation => _deliveryLocation;
  String get rideType => _rideType;

  Future<void> setDeliveryLocation(LatLng location) async {
    _deliveryLocation = location;
    await _recalculateAllFees();
    notifyListeners();
  }

  DeliveryCalculation? getDeliveryCalculation(String sellerId) =>
      _deliveryCalculations[sellerId];

  SellerInfo? getSellerInfo(String sellerId) => _sellersInfo[sellerId];

  Future<void> addSellerAndCalculateFee({
    required String sellerId,
    String? rideType, // allow override but default to current
  }) async {
    if (_deliveryLocation == null) {
      print('Delivery location not set');
      return;
    }

    final sellerInfo = await _deliveryService.getSellerInfo(sellerId);
    if (sellerInfo != null) {
      _sellersInfo[sellerId] = sellerInfo;
    }

    final calculation = await _deliveryService.calculateDeliveryFee(
      sellerId: sellerId,
      deliveryLocation: _deliveryLocation!,
      rideType: rideType ?? _rideType,
    );

    if (calculation != null) {
      _deliveryCalculations[sellerId] = calculation;
      notifyListeners();
    }
  }

  Future<void> _recalculateAllFees() async {
    if (_deliveryLocation == null) return;

    for (final sellerId in _sellersInfo.keys) {
      final calc = await _deliveryService.calculateDeliveryFee(
        sellerId: sellerId,
        deliveryLocation: _deliveryLocation!,
        rideType: _rideType, // ✅ use selected type
      );
      if (calc != null) {
        _deliveryCalculations[sellerId] = calc;
      }
    }
    notifyListeners();
  }

  void clear() {
    _deliveryCalculations.clear();
    _sellersInfo.clear();
    _deliveryLocation = null;
    notifyListeners();
  }

// Recalculate fees for a subset of sellers (e.g., the ones in the cart)
Future<void> recalculateForSellers(
  List<String> sellerIds, {
  required String rideType, // 'motorbike' or 'bicycle'
}) async {
  if (_deliveryLocation == null) return;

  for (final sellerId in sellerIds) {
    final calculation = await _deliveryService.calculateDeliveryFee(
      sellerId: sellerId,
      deliveryLocation: _deliveryLocation!,
      rideType: rideType,
    );
    if (calculation != null) {
      _deliveryCalculations[sellerId] = calculation;
    }
  }
  notifyListeners();
}

  double getTotalDeliveryFee(List<String> sellerIds) {
    double total = 0;
    for (final id in sellerIds) {
      final calc = _deliveryCalculations[id];
      if (calc != null) total += calc.deliveryFee;
    }
    return total;
  }
}
