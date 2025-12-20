// lib/view_models/location_view_model.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../bootstrap/app_bootstrap.dart';
// Note: Assuming PlaceService is accessible or AppBootstrap is accessible
// You may need to add an import for PlaceService or LocationService if they are used directly

class LocationViewModel extends ChangeNotifier {
  LatLng? _currentLocation;
  String _currentAddress = 'Getting location...';
  bool _isLoading = true;

  LatLng? get currentLocation => _currentLocation;
  String get currentAddress => _currentAddress;
  bool get isLoading => _isLoading;

  LocationViewModel() {
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    final boot = AppBootstrap.I;

    // 1. Ensure boot is ready
    if (!boot.isReady) {
      // You must handle initialization in main.dart or ensure the Google API key
      // is available here if it wasn't initialized yet. We assume it's initialized.
      // If the app relies on it being ready, you might need a loading screen here.
      // For now, we wait for the bootstrap state.
    }

    // Wait until it's ready before proceeding
    while (!boot.isReady) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // 2. Get the LatLng
    final userLatLng = boot.currentLocation;
    String address = 'Unknown Location';

    if (userLatLng != null) {

      try {
        // 3. Perform Reverse Geocoding using the PlaceService available in AppBootstrap
        // This replaces the incorrect reliance on boot.currentAddress.
        address = await boot.places.getReadableAddress(userLatLng);
        _currentLocation = userLatLng;
      } catch (e) {
        debugPrint('Error fetching initial address: $e');
        address = 'Location not found';
      }
    } else {
      address = 'Location not set';
    }

    // 4. Update the state
    _currentAddress = address;
    _isLoading = false;
    notifyListeners();
  }

  /// Updates the location state from the picker screen.
  void updateLocation(LatLng location, String address) {
    _currentLocation = location;
    _currentAddress = address;
    notifyListeners();
  }
}