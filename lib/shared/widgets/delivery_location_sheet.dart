import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

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
    enableDrag: true,
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
    with TickerProviderStateMixin {  // Changed from SingleTickerProviderStateMixin
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  CameraPosition? _initialCameraPosition;
  String _address = 'Move the map to select location';
  bool _isLoadingAddress = false;
  bool _isDragging = false;
  bool _hasSelectedLocation = false;

  late AnimationController _pinAnimationController;
  late Animation<double> _pinAnimation;
  late AnimationController _bounceController;

  Timer? _debounceTimer;
  TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchPredictions = [];
  bool _isSearching = false;
  bool _showSearchResults = false;

  static const _zambiaCenter = LatLng(-15.3875, 28.3228); // Lusaka
  static const _debounceDuration = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _initializeData();

    // Initialize animation controllers with proper vsync
    _pinAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pinAnimation = Tween<double>(begin: 0, end: -25).animate(
      CurvedAnimation(
        parent: _pinAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _initializeData() {
    _currentPosition = widget.initialTarget ?? _zambiaCenter;
    _initialCameraPosition = CameraPosition(
      target: _currentPosition!,
      zoom: widget.initialTarget != null ? 16 : 13,
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
    _bounceController.dispose();
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchPredictions = [];
        _showSearchResults = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final predictions = await locationFromAddress('$query, Zambia');

      setState(() {
        _searchPredictions = predictions;
        _showSearchResults = true;
        _isSearching = false;
      });
    } catch (e) {
      debugPrint("Search error: $e");
      setState(() {
        _searchPredictions = [];
        _isSearching = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      _searchPlaces(value);
    });
  }

  Future<void> _selectSearchResult(dynamic result) async {
    final location = result as Location;
    final latLng = LatLng(location.latitude, location.longitude);

    setState(() {
      _currentPosition = latLng;
      _showSearchResults = false;
      _searchController.clear();
      _isLoadingAddress = true;
      _hasSelectedLocation = true;
    });

    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: latLng, zoom: 17),
      ),
    );

    await _getAddressFromLatLng(latLng);
  }

  Future<void> _getAddressFromLatLng(LatLng position, {bool isInitial = false}) async {
    if (_isLoadingAddress && !isInitial) return;
    if (!mounted) return;

    setState(() {
      _isLoadingAddress = true;
      _address = 'Getting address details...';
    });

    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 8));

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
        _address = 'Address lookup timed out. Please try again.';
        _isLoadingAddress = false;
      });
    } catch (e) {
      debugPrint("Geocoding Error: $e");
      if (!mounted) return;
      setState(() {
        _address = 'Unable to get address. Please try again.';
        _isLoadingAddress = false;
      });
    }
  }

  String _formatAddress(Placemark place) {
    final List<String> parts = [
      if (place.name?.isNotEmpty == true && place.name != place.street) place.name!,
      if (place.street?.isNotEmpty == true) place.street!,
      if (place.subLocality?.isNotEmpty == true) place.subLocality!,
      if (place.locality?.isNotEmpty == true) place.locality!,
    ];

    final uniqueParts = parts.where((p) => p.isNotEmpty).toSet().toList();
    return uniqueParts.isEmpty ? 'Selected Location' : uniqueParts.take(3).join(', ');
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _onCameraMove(CameraPosition position) {
    _currentPosition = position.target;
    if (!_isDragging) {
      setState(() => _isDragging = true);
      if (!_pinAnimationController.isAnimating) {
        _pinAnimationController.forward();
      }
    }
  }

  void _onCameraIdle() {
    if (_pinAnimationController.status == AnimationStatus.forward) {
      _pinAnimationController.reverse();
    }

    setState(() => _isDragging = false);

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      if (_currentPosition != null && mounted) {
        _getAddressFromLatLng(_currentPosition!);
      }
    });
  }

  void _onMyLocationPressed() async {
    if (_mapController != null && _currentPosition != null) {
      _bounceController.forward().then((_) => _bounceController.reverse());
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentPosition!, zoom: 16),
        ),
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

  Widget _buildSearchBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_showSearchResults ? 16 : 30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            onTap: () => setState(() => _showSearchResults = true),
            decoration: InputDecoration(
              hintText: 'Search for area, street, or landmark...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.search, color: const Color(0xFF6C63FF)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: Icon(Icons.clear, color: Colors.grey.shade400),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchPredictions = [];
                    _showSearchResults = false;
                  });
                },
              )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_showSearchResults ? 16 : 30),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          if (_showSearchResults && _searchPredictions.isNotEmpty)
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchPredictions.length,
                itemBuilder: (context, index) {
                  final location = _searchPredictions[index];
                  return InkWell(
                    onTap: () => _selectSearchResult(location),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, size: 18, color: const Color(0xFF6C63FF)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  location.featureName ?? location.locality ?? 'Location',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF1A1A2E),
                                  ),
                                ),
                                if (location.locality != null)
                                  Text(
                                    location.locality!,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          if (_isSearching && _showSearchResults)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapWidget() {
    if (_initialCameraPosition == null) {
      return Container(
        color: Colors.grey.shade100,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
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
      minMaxZoomPreference: const MinMaxZoomPreference(10, 20),
      padding: const EdgeInsets.only(bottom: 100),
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _isDragging ? '📍 Drop here' : '📍 Drag to move',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.location_pin,
                    size: 48,
                    color: const Color(0xFF6C63FF),
                    shadows: const [
                      Shadow(
                        blurRadius: 8,
                        color: Colors.black26,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 24,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.15),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.location_on,
              color: _isLoadingAddress ? Colors.grey : const Color(0xFF6C63FF),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _isLoadingAddress
                ? Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF6C63FF),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _address,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            )
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selected Location',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Text(
                  _address,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A2E),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    final bool isButtonEnabled = _currentPosition != null && !_isLoadingAddress && _hasSelectedLocation;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: ElevatedButton(
        onPressed: isButtonEnabled ? _onConfirmPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          disabledBackgroundColor: Colors.grey.shade300,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: isButtonEnabled ? 2 : 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Confirm Delivery Location',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 50,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.location_searching, size: 20, color: Color(0xFF6C63FF)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Choose Delivery Location',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 24, color: Color(0xFF1A1A2E)),
                  onPressed: _onClosePressed,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          // Map section with search overlay
          Expanded(
            child: Stack(
              children: [
                _buildMapWidget(),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildSearchBar(),
                ),
                Positioned(
                  right: 16,
                  bottom: 100,
                  child: AnimatedBuilder(
                    animation: _bounceController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1 + (_bounceController.value * 0.1),
                        child: FloatingActionButton(
                          onPressed: _onMyLocationPressed,
                          backgroundColor: Colors.white,
                          mini: true,
                          elevation: 2,
                          child: const Icon(
                            Icons.my_location,
                            color: Color(0xFF6C63FF),
                            size: 20,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                _buildPinWidget(),
              ],
            ),
          ),
          // Bottom section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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