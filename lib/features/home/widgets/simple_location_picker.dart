// lib/features/home/widgets/simple_location_picker.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/bootstrap/app_bootstrap.dart';
import '../../../core/services/places_service.dart';
import '../../common/widgets/place_autocomplete_field.dart';
import '../../maps/map_fullscreen_picker.dart';
// import '../../view_models/location_view_model.dart'; // No longer needed here

class SimpleLocationPickerScreen extends StatefulWidget {
  final String googleApiKey;
  final LatLng? initialLocation;

  const SimpleLocationPickerScreen({
    super.key,
    required this.googleApiKey,
    this.initialLocation,
  });

  @override
  State<SimpleLocationPickerScreen> createState() => _SimpleLocationPickerScreenState();
}

class _SimpleLocationPickerScreenState extends State<SimpleLocationPickerScreen> {
  final _locationCtrl = TextEditingController();

  late final PlaceService _places;
  LatLng? _me;
  LatLng? _selectedLocation;
  String? _address;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final boot = AppBootstrap.I;

    if (!boot.isReady) {
      // Assuming init was called in main.dart, but we ensure robustness
      await boot.init(googleApiKey: widget.googleApiKey);
    }

    if (!mounted) return;

    _me = boot.currentLocation;
    _places = boot.places;

    if (_me != null) {
      _places.setCurrentLocation(_me!);
    }

    // Determine the map's starting point (current GPS or initial)
    LatLng? locationToDisplay = widget.initialLocation ?? _me;
    String? addressToDisplay;

    // Reverse Geocode the starting point to get the initial address for the text field.
    if (locationToDisplay != null) {
      try {
        addressToDisplay = await _places.getReadableAddress(locationToDisplay);
      } catch (e) {
        debugPrint('Error during initial reverse geocoding: $e');
        addressToDisplay = 'Could not determine address';
      }
    }

    setState(() {
      _selectedLocation = locationToDisplay;
      _address = addressToDisplay;

      if (_address != null) {
        _locationCtrl.text = _address!;
      }
    });
  }

  // === Place pick result (autocomplete) ===
  Future<void> _onLocationPicked(PlaceDetail d) async {
    setState(() {
      _selectedLocation = d.latLng;
      _locationCtrl.text = d.address;
      _address = d.address;
    });
    // Location is picked via search, ready to confirm
  }

  // === Map Picker Trigger (Called when map icon in TextField is tapped) ===
  Future<void> _pickOnMap() async {
    // Temporarily clear the text field when moving to the map picker
    setState(() {
      _locationCtrl.clear();
    });

    // Use current selection or GPS location as the map's starting point
    final initial = _selectedLocation ?? _me ?? const LatLng(0, 0);

    final result = await showFullScreenMapPicker(
      context,
      initial: initial,
      title: 'Select Location on Map',
    );
    if (result == null) {
      // If user cancels, restore the previous text/state
      setState(() {
        if (_address != null) {
          _locationCtrl.text = _address!;
        }
      });
      return;
    }

    final ll = LatLng(
      (result['lat'] as num).toDouble(),
      (result['lng'] as num).toDouble(),
    );
    final addr = (result['address'] as String?) ?? '';

    setState(() {
      _selectedLocation = ll;
      _locationCtrl.text = addr;
      _address = addr;
    });
  }

  bool get _hasLocation => _selectedLocation != null && _address != null && _address!.isNotEmpty;

  void _onConfirm() {
    if (_hasLocation) {
      Navigator.pop(context, {
        'location': _selectedLocation,
        'address': _address,
      });
    }
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomSheetHeight = mediaQuery.size.height * 0.9;

    // Show loading indicator while fetching initial location/address
    if (_selectedLocation == null && _me == null && _address == null) {
      return Container(
        height: bottomSheetHeight,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    return Container(
      height: bottomSheetHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Custom Header
          _buildHeader(),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Location Autocomplete Input Field (Full Width)
                  _FieldTheme(
                    child: PlaceAutocompleteField(
                      controller: _locationCtrl,
                      service: _places,
                      label: 'Enter a full address or search location',
                      onPlacePicked: _onLocationPicked,
                      // *** FIX: Re-enable the Map button and link it to the picker method ***
                      onMapTap: _pickOnMap,
                      // Map icon should be the default icon, no need to set mapButtonIcon
                      // mapButtonIcon: Icons.map_outlined, // Remove this line
                      onClear: () {
                        setState(() {
                          _selectedLocation = null;
                          _address = null;
                          _locationCtrl.clear();
                        });
                      },
                    ),
                  ),

                  // =========================================================
                  // *** FIX: REMOVED THE REDUNDANT "Pick on Map" BUTTON ***
                  // =========================================================

                  // Display selected address (optional, for confirmation)
                  if (_address != null && _hasLocation)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(
                        'Selected: $_address',
                        style: const TextStyle(fontSize: 14, color: Colors.black),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Confirm Location Button
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              mediaQuery.padding.bottom + 16,
            ),
            color: Color(0xFF1A2B7B),
            child: ElevatedButton.icon(
              onPressed: _hasLocation ? _onConfirm : null,
              icon: const Icon(Icons.check),
              label: Text(_hasLocation ? 'Confirm Location' : 'Select a location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Custom Header for the bottom sheet (No Change)
  Widget _buildHeader() {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Color(0xFF1A2B7B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Select Location',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _FieldTheme extends StatelessWidget {
  const _FieldTheme({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        cardColor: Colors.white,
        dialogBackgroundColor: Colors.white,
        // Theming for the PlaceAutocompleteField dropdown/popup
        textTheme: base.textTheme.apply(bodyColor: Colors.white),
        listTileTheme: const ListTileThemeData(textColor: Colors.black),

        // Custom decoration for the main TextField itself
        inputDecorationTheme: const InputDecorationTheme(
          fillColor: Colors.white,
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide.none,
          ),
          hintStyle: TextStyle(color: Colors.grey),
        ),
      ),
      child: child,
    );
  }
}