import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/delivery_method.dart';
import '../services/location_service.dart';
import '../services/pref_service.dart';
import '../services/places_service.dart';

class AppBootstrap {
  AppBootstrap._();
  static final AppBootstrap I = AppBootstrap._();

  LatLng? _currentLocation;
  DeliveryMethod? _deliveryMethod;
  PlaceService? _places;
  String? _userPhone;

  bool _initialized = false;

  bool get isReady => _initialized;

  LatLng get currentLocation => _currentLocation!;
  DeliveryMethod get deliveryMethod => _deliveryMethod!;
  PlaceService get places => _places!;
  String? get userPhone => _userPhone;

  Future<void> init({required String googleApiKey}) async {
    if (_initialized) return;

    final pos = await LocationService.current();
    final method = await PrefsService.I.getDeliveryMethod();
    final prefs = await SharedPreferences.getInstance();

    _currentLocation = LatLng(pos.latitude, pos.longitude);
    _deliveryMethod = method;
    _places = PlaceService(googleApiKey);

    // Load phone once
    _userPhone = prefs.getString('phone');

    _initialized = true;
  }

  /// Call this when user edits phone
  Future<void> setUserPhone(String phone) async {
    _userPhone = phone;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('phone', phone);
  }

  Future<void> reset() async {
    _currentLocation = null;
    _deliveryMethod = null;
    _places = null;
    _userPhone = null;
    _initialized = false;
  }

}
