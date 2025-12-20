import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

// You will need to import your chosen Places package here, e.g.:
// import 'package:flutter_google_places/flutter_google_places.dart';

class DeliveryLocationResult {
  final LatLng latLng;
  final String? address;
  DeliveryLocationResult(this.latLng, {this.address});
}

Future<DeliveryLocationResult?> showDeliveryLocationSheet({
  required BuildContext context,
  LatLng? initialTarget,
}) {
  return showModalBottomSheet<DeliveryLocationResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true, // Allow standard dragging for better responsiveness
    builder: (_) => _DeliveryLocationSheet(initialTarget: initialTarget),
  );
}

class _DeliveryLocationSheet extends StatefulWidget {
  const _DeliveryLocationSheet({this.initialTarget});
  final LatLng? initialTarget;

  @override
  State<_DeliveryLocationSheet> createState() => _DeliveryLocationSheetState();
}

class _DeliveryLocationSheetState extends State<_DeliveryLocationSheet>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;

  LatLng? _currentPosition;
  CameraPosition? _initialCameraPosition;

  String _address = 'Move the map or search above to select location';
  bool _isLoadingAddress = false;
  bool _isDragging = false;
  bool _hasSelectedLocation = false;

  late AnimationController _pinAnimationController;
  late Animation<double> _pinAnimation;

  Timer? _debounceTimer;

  static const _zambiaCenter = LatLng(-13.435, 27.849);
  static const _debounceDuration = Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    _initializeData();

    _pinAnimationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _pinAnimation = Tween<double>(begin: 0, end: -20).animate(
      CurvedAnimation(
        parent: _pinAnimationController,
        curve: Curves.easeOut,
      ),
    );
  }

  void _initializeData() {
    _currentPosition = widget.initialTarget ?? _zambiaCenter;
    _initialCameraPosition = CameraPosition(
      target: _currentPosition!,
      zoom: widget.initialTarget != null ? 15 : 5,
    );
    _hasSelectedLocation = widget.initialTarget != null;
    if (_hasSelectedLocation) {
      Timer.run(() => _getAddressFromLatLng(_currentPosition!, isInitial: true));
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _pinAnimationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ==================== SEARCH INTEGRATION POINT ====================

  /// Placeholder for calling the external Places Autocomplete search.
  Future<void> _showPlacesSearch() async {
    // ⚠️ IMPORTANT: IMPLEMENT THIS METHOD
    // You will need a package like 'flutter_google_places' or 'map_location_picker'.

    // Example using a hypothetical package:
    /*
    final prediction = await PlacesAutocomplete.show(
      context: context,
      apiKey: 'YOUR_PLACES_API_KEY',
      mode: Mode.overlay, // or Mode.fullscreen
      language: 'en',
      components: [Component(Component.country, 'zm')], // Bias results to Zambia
    );

    if (prediction != null) {
      await _handleSearchSelection(prediction);
    }
    */

    // --- TEMPORARY Mock for demonstration ---
    final mockResult = DeliveryLocationResult(
        const LatLng(-15.4167, 28.2833), // Lusaka Mock
        address: 'Lusaka Main Mall'
    );
    if (mockResult != null) {
      _handleSearchSelection(mockResult.latLng, mockResult.address);
    }
    // --- END TEMPORARY Mock ---
  }

  /// Handles the result from the Places search and updates the map/state.
  Future<void> _handleSearchSelection(LatLng latLng, String? address) async {
    _currentPosition = latLng;
    // Animate the camera to the selected location
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: latLng, zoom: 17),
      ),
    );

    // Manually set the address from the Autocomplete result (faster than Geocoding)
    if (mounted) {
      setState(() {
        _address = address ?? 'Selected from Search';
        _hasSelectedLocation = true;
        _isLoadingAddress = false;
      });
    }
  }


  // ==================== GEOCODING & MAP HANDLERS (Optimized) ====================

  Future<void> _getAddressFromLatLng(LatLng position, {bool isInitial = false}) async {
    if (_isLoadingAddress && !isInitial) return;

    if (!mounted) return;
    setState(() {
      _isLoadingAddress = true;
      _address = 'Getting address...';
    });

    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 5));

      if (!mounted) return;

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks[0];
        setState(() {
          _address = _formatAddress(place);
          _isLoadingAddress = false;
          _hasSelectedLocation = true;
        });
      } else {
        setState(() {
          _address = 'Address not found. Please move the pin.';
          _isLoadingAddress = false;
          _hasSelectedLocation = true;
        });
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _address = 'Address lookup timed out.';
        _isLoadingAddress = false;
        _hasSelectedLocation = true;
      });
    } catch (e) {
      debugPrint("Geocoding Error: $e");
      if (!mounted) return;
      setState(() {
        _address = 'Unable to get address (Error)';
        _isLoadingAddress = false;
        _hasSelectedLocation = true;
      });
    }
  }

  String _formatAddress(Placemark place) {
    final List<String> parts = [
      if (place.street?.isNotEmpty == true) place.street!,
      if (place.subLocality?.isNotEmpty == true) place.subLocality!,
      if (place.locality?.isNotEmpty == true) place.locality!,
      if (place.administrativeArea?.isNotEmpty == true && place.administrativeArea != place.locality)
        place.administrativeArea!,
    ];

    final uniqueParts = parts.toSet().toList();

    return uniqueParts.isEmpty ? place.name ?? 'Selected Location' : uniqueParts.join(', ');
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _onCameraMove(CameraPosition position) {
    _currentPosition = position.target;

    if (!_isDragging) {
      if (mounted) {
        setState(() {
          _isDragging = true;
        });
      }
      if (!_pinAnimationController.isAnimating) {
        _pinAnimationController.forward();
      }
    }
  }

  void _onCameraIdle() {
    if (_pinAnimationController.status == AnimationStatus.forward) {
      _pinAnimationController.reverse();
    }

    if (mounted) {
      setState(() {
        _isDragging = false;
      });
    }

    _debounceTimer?.cancel();

    _debounceTimer = Timer(_debounceDuration, () {
      if (_currentPosition != null && mounted) {
        _getAddressFromLatLng(_currentPosition!);
      }
    });
  }

  void _onMyLocationPressed() {
    if (_mapController != null && _currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(_currentPosition!),
      );
    }
  }

  void _onConfirmPressed() {
    if (_currentPosition != null && !_isLoadingAddress && _hasSelectedLocation) {
      Navigator.pop(
        context,
        DeliveryLocationResult(
          _currentPosition!,
          address: _address,
        ),
      );
    }
  }

  void _onClosePressed() {
    Navigator.pop(context);
  }

  // ==================== WIDGET BUILDERS ====================

  Widget _buildMapWidget() {
    if (_initialCameraPosition == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return GoogleMap(
      initialCameraPosition: _initialCameraPosition!,
      onMapCreated: _onMapCreated,
      onCameraMove: _onCameraMove,
      onCameraIdle: _onCameraIdle,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      minMaxZoomPreference: const MinMaxZoomPreference(5, 20),
    );
  }

  Widget _buildPinWidget() {
    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _pinAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _pinAnimation.value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_pin,
                    size: 50,
                    color: _isLoadingAddress ? Colors.grey : const Color(0xFFFF5A3D),
                    shadows: const [
                      Shadow(
                        blurRadius: 4,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 20,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // NEW: Search Bar Widget
  Widget _buildSearchBar() {
    return InkWell(
      onTap: _showPlacesSearch, // Tapping opens the search screen
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.grey, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Search for a location or address...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressSection() {
    // ... (No changes here, remains the same as previous response) ...
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on,
            color: _isLoadingAddress ? Colors.grey : const Color(0xFFFF5A3D),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _isLoadingAddress
                ? Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    key: ValueKey('address_loading'),
                    strokeWidth: 2,
                    color: Color(0xFFFF5A3D),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _address,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            )
                : Text(
              _address,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    final bool isButtonEnabled =
        _currentPosition != null && !_isLoadingAddress && _hasSelectedLocation;
    final Color buttonColor =
    isButtonEnabled ? const Color(0xFFFF5A3D) : Colors.grey;

    return ElevatedButton.icon(
      onPressed: isButtonEnabled ? _onConfirmPressed : null,
      icon: const Icon(Icons.check_circle_outline),
      label: const Text('Confirm Location'),
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
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
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'Choose delivery location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
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

          const Divider(height: 1),

          // Map section with Search Bar overlay
          Expanded(
            child: Stack(
              children: [
                _buildMapWidget(), // GoogleMap

                // NEW: Search Bar Positioned at the top
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildSearchBar(),
                ),

                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.small(
                    onPressed: _onMyLocationPressed,
                    backgroundColor: Colors.white,
                    child: const Icon(
                      Icons.my_location,
                      color: Color(0xFFFF5A3D),
                      size: 20,
                    ),
                  ),
                ),
                _buildPinWidget(), // Location Pin
              ],
            ),
          ),

          // Bottom section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildAddressSection(),
                  const SizedBox(height: 16),
                  _buildConfirmButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}