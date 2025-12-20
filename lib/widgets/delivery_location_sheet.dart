// lib/shared/widgets/delivery_location_sheet.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
// Import the API service

import '../core/services/google_places_api_service.dart';

// --- Data Models ---
class DeliveryLocationResult {
  final LatLng latLng;
  final String? address;
  DeliveryLocationResult(this.latLng, {this.address});
}

// NOTE: PlaceSuggestion is re-defined in the API Service for independence.
// We will use the model from the API Service to ensure compatibility.
// If you prefer to define it here:
/*
class PlaceSuggestion {
  final String description;
  final String placeId;
  PlaceSuggestion({required this.description, required this.placeId});
}
*/

// --- Public Function ---

Future<DeliveryLocationResult?> showDeliveryLocationSheet({
  required BuildContext context,
  LatLng? initialTarget,
}) {
  return showModalBottomSheet<DeliveryLocationResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (_) => _CentralizedLocationSheet(initialTarget: initialTarget),
  );
}

// --- Main Widget Implementation ---

class _CentralizedLocationSheet extends StatefulWidget {
  const _CentralizedLocationSheet({this.initialTarget});
  final LatLng? initialTarget;

  @override
  State<_CentralizedLocationSheet> createState() => _CentralizedLocationSheetState();
}

class _CentralizedLocationSheetState extends State<_CentralizedLocationSheet> {
  // --- State ---
  bool _isConfirmMode = false;
  LatLng? _currentPosition;
  String _address = '';

  // --- Search State ---
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<PlaceSuggestion> _suggestions = [];
  Timer? _searchDebounce;
  bool _isSearching = false;

  // --- Map State ---
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  static const _zambiaCenter = LatLng(-13.435, 27.849);
  static const _searchDebounceDuration = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.initialTarget ?? _zambiaCenter;
    if (widget.initialTarget != null) {
      _isConfirmMode = true;
      Timer.run(() => _getAddressFromLatLng(_currentPosition!));
    }

    _searchController.addListener(_onSearchChanged);

    if (!_isConfirmMode) {
      Timer.run(() => _searchFocusNode.requestFocus());
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ==================== SEARCH LOGIC ====================

  void _onSearchChanged() {
    if (_searchController.text.isEmpty) {
      setState(() {
        _suggestions.clear();
        _isSearching = false;
      });
      _searchDebounce?.cancel();
      return;
    }

    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDuration, () {
      _fetchPlaceSuggestions(_searchController.text);
    });
  }

  Future<void> _fetchPlaceSuggestions(String input) async {
    if (!mounted) return;
    setState(() => _isSearching = true);

    // Call the API service
    final List<PlaceSuggestion> fetchedSuggestions =
    await GooglePlacesApiService.fetchPlaceSuggestions(input);

    if (!mounted) return;
    setState(() {
      _suggestions = fetchedSuggestions;
      _isSearching = false;
    });
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    if (!mounted) return;
    _searchFocusNode.unfocus();
    setState(() => _address = 'Resolving location for ${suggestion.description}...');

    // Call the API service to get coordinates
    final LatLng? latLng = await GooglePlacesApiService.getCoordinatesFromPlaceId(suggestion.placeId);

    if (latLng == null) {
      if(mounted) setState(() => _address = 'Could not resolve coordinates.');
      return;
    }

    if (!mounted) return;

    setState(() {
      _currentPosition = latLng;
      _address = suggestion.description;
      _isConfirmMode = true;
      _suggestions.clear();
      _searchController.clear();
      _updateMapMarker();
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(latLng, 17),
    );
  }

  // ==================== MAP & GEOCODING LOGIC (Fixed) ====================

  Future<void> _getAddressFromLatLng(LatLng position) async {
    if (!mounted) return;
    setState(() => _address = 'Updating address...');

    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 5));

      if (placemarks.isNotEmpty && mounted) {
        final Placemark place = placemarks[0];
        setState(() => _address = _formatAddress(place));
      } else if (mounted) {
        setState(() => _address = 'Address not found at this point.');
      }
    } catch (e) {
      if (mounted) setState(() => _address = 'Unable to get address (Error)');
    }
  }

  String _formatAddress(Placemark place) {
    final List<String> parts = [
      if (place.street?.isNotEmpty == true) place.street!,
      if (place.subLocality?.isNotEmpty == true) place.subLocality!,
      if (place.locality?.isNotEmpty == true) place.locality!,
    ];
    final uniqueParts = parts.toSet().toList();
    return uniqueParts.isEmpty ? place.name ?? 'Selected Location' : uniqueParts.join(', ');
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_isConfirmMode) {
      _updateMapMarker();
    }
  }

  // FIX for getCameraPosition error: Track position on move, process on idle
  void _onCameraMove(CameraPosition position) {
    _currentPosition = position.target;
  }

  void _onCameraIdle() {
    if (_mapController == null || _currentPosition == null || !mounted) return;

    // Trigger the marker update and address lookup using the position captured by onCameraMove
    _updateMapMarker();
    _getAddressFromLatLng(_currentPosition!);
  }

  void _updateMapMarker() {
    _markers.clear();
    if (_currentPosition != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('selected_location'),
          position: _currentPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }
  }

  // ==================== UI ACTIONS & BUILDERS ====================

  void _onConfirmPressed() {
    if (_currentPosition != null) {
      Navigator.pop(
        context,
        DeliveryLocationResult(
          _currentPosition!,
          address: _address,
        ),
      );
    }
  }

  void _onBackToSearchPressed() {
    setState(() {
      _isConfirmMode = false;
      _searchFocusNode.requestFocus();
    });
  }

  void _onClosePressed() {
    Navigator.pop(context);
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search for street, area, or address...',
          prefixIcon: const Icon(Icons.search, color: Color(0xFFFF5A3D)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear, color: Colors.grey),
            onPressed: () {
              _searchController.clear();
              _suggestions.clear();
              setState(() {});
            },
          )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        ),
        onSubmitted: (value) {
          if (_suggestions.isNotEmpty) {
            _selectSuggestion(_suggestions.first);
          }
        },
      ),
    );
  }

  Widget _buildSearchContent() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_suggestions.isEmpty && _searchController.text.isNotEmpty) {
      return const Center(child: Text('No matching places found.'));
    }

    if (_searchController.text.isEmpty) {
      return const Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Text(
              'Start typing your destination address to see suggestions.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          )
      );
    }

    return ListView.builder(
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        return ListTile(
          leading: const Icon(Icons.location_on, color: Color(0xFFFF5A3D)),
          title: Text(suggestion.description, maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () => _selectSuggestion(suggestion),
        );
      },
    );
  }

  Widget _buildMapConfirmation() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.only(left: 8, right: 16, top: 8, bottom: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: _onBackToSearchPressed,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current Location:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      _address,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _onConfirmPressed,
                child: const Text('CONFIRM', style: TextStyle(color: Color(0xFFFF5A3D), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: Stack(
            children: [
              _currentPosition == null
                  ? const Center(child: CircularProgressIndicator())
                  : GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentPosition!,
                  zoom: 17,
                ),
                onMapCreated: _onMapCreated,
                onCameraIdle: _onCameraIdle,
                // ADDED the fix: track camera movement to get the latest position
                onCameraMove: _onCameraMove,
                markers: _markers,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: true,
              ),

              IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 30),
                    child: const Icon(
                      Icons.location_pin,
                      size: 40,
                      color: Color(0xFFFF5A3D),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8, right: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Spacer(),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 24),
                  onPressed: _onClosePressed,
                ),
              ],
            ),
          ),

          _isConfirmMode
              ? Expanded(child: _buildMapConfirmation())
              : Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSearchBar(),
                const Divider(height: 1),
                Expanded(child: _buildSearchContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}