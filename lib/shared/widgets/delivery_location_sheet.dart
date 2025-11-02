// lib/shared/widgets/delivery_location_sheet.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

class DeliveryLocationResult {
  final LatLng latLng;
  final String? address;
  DeliveryLocationResult(this.latLng, {this.address});
}

/// Opens a bottom sheet with an interactive Google Map to pick a location.
/// Returns null if the user cancels.
Future<DeliveryLocationResult?> showDeliveryLocationSheet({
  required BuildContext context,
  LatLng? initialTarget,
}) {
  return showModalBottomSheet<DeliveryLocationResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: false,
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
  String _address = 'Move the map to select location';
  bool _isLoadingAddress = false;
  bool _isDragging = false;
  bool _hasSelectedLocation = false;
  late AnimationController _pinAnimationController;
  late Animation<double> _pinAnimation;

  // Debounce timer for address lookup
  Timer? _debounceTimer;

  // Camera position state
  CameraPosition? _currentCameraPosition;

  static const _fallback = LatLng(-15.3875, 28.3228); // Lusaka, Zambia
  static const _debounceDuration = Duration(milliseconds: 800);

  @override
  void initState() {
    super.initState();
    _initializeData();

    // Setup pin animation
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
    _currentPosition = widget.initialTarget ?? _fallback;
    _currentCameraPosition = CameraPosition(
      target: _currentPosition!,
      zoom: 15,
    );
    _hasSelectedLocation = widget.initialTarget != null;
    if (_hasSelectedLocation) {
      _getAddressFromLatLng(_currentPosition!);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _pinAnimationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    if (_isLoadingAddress) return;

    if (!mounted) return;
    setState(() {
      _isLoadingAddress = true;
    });

    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

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
          _address = 'Address not found';
          _isLoadingAddress = false;
          _hasSelectedLocation = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _address = 'Unable to get address';
        _isLoadingAddress = false;
        _hasSelectedLocation = true;
      });
    }
  }

  String _formatAddress(Placemark place) {
    final List<String> parts = [];

    if (place.street != null && place.street!.isNotEmpty) {
      parts.add(place.street!);
    }
    if (place.subLocality != null && place.subLocality!.isNotEmpty) {
      parts.add(place.subLocality!);
    }
    if (place.locality != null && place.locality!.isNotEmpty) {
      parts.add(place.locality!);
    }
    if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
      parts.add(place.administrativeArea!);
    }
    if (place.country != null && place.country!.isNotEmpty) {
      parts.add(place.country!);
    }

    return parts.isEmpty ? 'Unknown location' : parts.join(', ');
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _onCameraMove(CameraPosition position) {
    // Update position without setState to avoid rebuilds during drag
    _currentPosition = position.target;

    // Only animate pin up once when dragging starts
    if (!_isDragging) {
      if (mounted) {
        setState(() {
          _isDragging = true;
        });
      }
      if (!_pinAnimationController.isAnimating && _pinAnimationController.value == 0) {
        _pinAnimationController.forward();
      }
    }
  }

  void _onCameraIdle() {
    if (mounted) {
      setState(() {
        _isDragging = false;
      });
    }

    // Animate pin down when dragging stops
    _pinAnimationController.reverse();

    // Cancel any pending address lookup
    _debounceTimer?.cancel();

    // Debounce address lookup to avoid excessive API calls
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

  Widget _buildMapWidget() {
    if (_currentCameraPosition == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return GoogleMap(
      initialCameraPosition: _currentCameraPosition!,
      onMapCreated: _onMapCreated,
      onCameraMove: _onCameraMove,
      onCameraIdle: _onCameraIdle,
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      tiltGesturesEnabled: false, // Disable tilt for better performance
      rotateGesturesEnabled: false, // Disable rotation for better performance
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      minMaxZoomPreference: const MinMaxZoomPreference(10, 20), // Limit zoom range
      cameraTargetBounds: CameraTargetBounds.unbounded,
      compassEnabled: false,
      buildingsEnabled: true,
      indoorViewEnabled: false,
      trafficEnabled: false,
      liteModeEnabled: false, // Use full rendering for smoother experience
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

  Widget _buildAddressSection() {
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
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: const Color(0xFFFF5A3D),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Getting address...',
                  style: TextStyle(
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

  /*
  Widget _buildDeliveryInformation() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon(
              //   Icons.local_shipping,
              //   color: Colors.green[700],
              //   size: 20,
              // ),
              const SizedBox(width: 8),
              // Text(
              //   'Delivery Information',
              //   style: TextStyle(
              //     fontSize: 16,
              //     fontWeight: FontWeight.w600,
              //     color: Colors.green[700],
              //   ),
              // ),
            ],
          ),
          // const SizedBox(height: 8),
          // Text(
          //   'Delivery Fee: K0',
          //   style: const TextStyle(
          //     fontSize: 14,
          //     color: Colors.black87,
          //     fontWeight: FontWeight.w500,
          //   ),
          // ),
          const SizedBox(height: 4),
          // Text(
          //   'Estimated delivery: 30-45 min',
          //   style: TextStyle(
          //     fontSize: 14,
          //     color: Colors.grey[600],
          //   ),
          // ),
        ],
      ),
    );
  }*/

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
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
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

          // Map section
          Expanded(
            child: Stack(
              children: [
                _buildMapWidget(),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.small(
                    onPressed: _onMyLocationPressed,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.my_location,
                      color: const Color(0xFFFF5A3D),
                      size: 20,
                    ),
                  ),
                ),
                _buildPinWidget(),
              ],
            ),
          ),

          // Bottom section with address and confirm button
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Address display
                  _buildAddressSection(),

                  // Conditionally show delivery information
                  // if (_hasSelectedLocation && !_isLoadingAddress) ...[
                  //   const SizedBox(height: 16),
                  //   _buildDeliveryInformation(),
                  // ],

                  const SizedBox(height: 16),
                  // Confirm button
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