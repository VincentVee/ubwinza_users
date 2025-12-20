// lib/features/delivery/state/delivery_provider.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// FIX: Using latlong2 LatLng for consistency across the app, assuming you use it
// elsewhere like in CartScreen. Replacing google_maps_flutter LatLng.
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'package:ubwinza_users/core/models/delivery_calculation.dart';
import 'package:ubwinza_users/core/models/delivery_method.dart';
import 'package:ubwinza_users/core/services/pref_service.dart';
import 'package:ubwinza_users/features/delivery/services/delivery_service.dart';

// NOTE: Assuming SellerInfo is defined elsewhere in your project
class SellerInfo { /* placeholder, replace with your actual class */
  final String name;
  SellerInfo({required this.name});
}


class DeliveryProvider with ChangeNotifier {
  final DeliveryService _deliveryService = DeliveryService();

  bool _isLocationInitialized = false;
  String? _initializationError;

  // FIX: Using latlong2 LatLng for consistency
  static const LatLng _kitweFallback = LatLng(-12.8202, 28.2127);
  static const String _kitweFallbackAddress = 'Kitwe City Center (Default)';

  final Map<String, DeliveryCalculation> _deliveryCalculations = {};
  final Map<String, SellerInfo> _sellersInfo = {};
  LatLng? _deliveryLocation;
  String? _deliveryAddress;

  String _rideType =
  PrefsService.I.getDeliveryMethod() == DeliveryMethod.bicycle
      ? 'bicycle'
      : 'motorbike';

  // ==================== CONSTRUCTOR & INITIALIZATION ====================

  DeliveryProvider() {
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    if (_isLocationInitialized) return;

    Position? position;
    String initialAddress = _kitweFallbackAddress;
    LatLng initialLatLng = _kitweFallback;

    try {
      // 1. Check Permissions and Enablement
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled on the device.';
      }
      LocationPermission p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.deniedForever) {
        throw 'Location permission permanently denied.';
      }

      // 2. Fetch Position with aggressive settings
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      );

      position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
        timeLimit: const Duration(seconds: 15),
      );
      // FIX: Ensure correct conversion from Geolocator Position to LatLng (latlong2)
      initialLatLng = LatLng(position.latitude, position.longitude);

      // 3. Perform Reverse Geocoding
      List<Placemark> placemarks = await placemarkFromCoordinates(
        initialLatLng.latitude,
        initialLatLng.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark p = placemarks.first;
        initialAddress = '${p.street}, ${p.subLocality}, ${p.locality}';
        initialAddress = initialAddress.replaceAll(RegExp(r'(^, )|(, $)'), '').trim();
        if (initialAddress.isEmpty) initialAddress = p.name ?? 'Selected Point';
      }

    } catch (e) {
      _initializationError = e.toString();
      debugPrint('Initial Location Error: $_initializationError');

    } finally {
      _deliveryLocation = initialLatLng;
      _deliveryAddress = initialAddress;
      _isLocationInitialized = true;
      notifyListeners();
    }
  }


  // ==================== GETTERS ====================

  Map<String, DeliveryCalculation> get deliveryCalculations => _deliveryCalculations;
  Map<String, SellerInfo> get sellersInfo => _sellersInfo;
  LatLng? get deliveryLocation => _deliveryLocation;
  String? get deliveryAddress => _deliveryAddress;
  String get rideType => _rideType;
  bool get isLocationInitialized => _isLocationInitialized;
  String? get initializationError => _initializationError;

  DeliveryCalculation? getDeliveryCalculation(String sellerId) =>
      _deliveryCalculations[sellerId];

  SellerInfo? getSellerInfo(String sellerId) => _sellersInfo[sellerId];

  bool allCalculated(List<String> sellerIds) {
    if (_deliveryLocation == null) return false;
    if (sellerIds.isEmpty) return true;

    // Check if every seller ID has an entry in _deliveryCalculations
    for (final id in sellerIds) {
      if (_deliveryCalculations[id] == null) return false;
    }
    return true;
  }


  // ==================== SETTERS & PUBLIC METHODS ====================

  Future<void> setRideType(String rideType) async {
    if (rideType == _rideType) return;
    _rideType = rideType;
    await _recalculateAllFees();
    // Removed redundant notifyListeners() as _recalculateAllFees now calls it per seller.
    // If no sellers are present, _recalculateAllFees doesn't notify, so we add a check here:
    if (_sellersInfo.isEmpty) notifyListeners();
  }

  Future<void> setDeliveryLocation(LatLng location, String? address) async {
    _deliveryLocation = location;
    _deliveryAddress = address;
    _isLocationInitialized = true;

    // Recalculate fees for all existing cart items (sellers)
    await _recalculateAllFees();

    // Only notify if there are no sellers, as _recalculateAllFees notifies if there are.
    if (_sellersInfo.isEmpty) notifyListeners();
  }

  Future<void> addSellerAndCalculateFee({
    required String sellerId,
    String? rideType,
  }) async {
    if (_deliveryLocation == null) {
      debugPrint('Delivery location not set');
      return;
    }

    final sellerInfo = await _deliveryService.getSellerInfo(sellerId);
    if (sellerInfo != null) {
      // Assuming getSellerInfo returns the correct SellerInfo type
      _sellersInfo[sellerId] = sellerInfo as SellerInfo;
      // FIX: Notify here so seller name appears immediately
      notifyListeners();
    }

    final calculation = await _deliveryService.calculateDeliveryFee(
      sellerId: sellerId,
      deliveryLocation: _deliveryLocation!,
      rideType: rideType ?? _rideType,
    );

    if (calculation != null) {
      _deliveryCalculations[sellerId] = calculation;
      // FIX: Notify here so the fee appears immediately
      notifyListeners();
    }
  }

  Future<void> recalculateForSellers(
      List<String> sellerIds, {
        required String rideType,
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
        // CRITICAL FIX: Notify listeners for each successful calculation
        notifyListeners();
      }
    }
    // Final notify is often redundant but safe if nothing was calculated.
    // But since CartScreen uses _isRecalculating flag, we skip the final notify here
    // to let the per-seller notify handle the updates.
  }

  double getTotalDeliveryFee(List<String> sellerIds) {
    double total = 0;
    for (final id in sellerIds) {
      final calc = _deliveryCalculations[id];
      if (calc != null) total += calc.deliveryFee;
    }
    return total;
  }

  void clear() {
    _deliveryCalculations.clear();
    _sellersInfo.clear();
    _deliveryLocation = null;
    _isLocationInitialized = false;
    notifyListeners();
  }


  // ==================== INTERNAL METHODS ====================

  Future<void> _recalculateAllFees() async {
    if (_deliveryLocation == null) return;

    for (final sellerId in _sellersInfo.keys) {
      final calc = await _deliveryService.calculateDeliveryFee(
        sellerId: sellerId,
        deliveryLocation: _deliveryLocation!,
        rideType: _rideType,
      );
      if (calc != null) {
        _deliveryCalculations[sellerId] = calc;
        // CRITICAL FIX: Notify listeners for each successful calculation
        notifyListeners();
      }
    }
    // No final notifyListeners needed here either.
  }
}