import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../global/global_vars.dart';
import '../../../core/models/driver_model.dart';
import '../../../core/models/request_model.dart';
import '../../../core/services/driver_service.dart';
import '../../../core/services/request_service.dart';

final String kDirectionsKey = googleApiKey;

class RequestMapScreen extends StatefulWidget {
  final String requestId;
  final String pickupAddress;
  final String destinationAddress;
  final LatLng pickupLatLng;
  final LatLng destinationLatLng;
  final String vehicleType;

  const RequestMapScreen({
    super.key,
    required this.requestId,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.pickupLatLng,
    required this.destinationLatLng,
    required this.vehicleType,
  });

  @override
  State<RequestMapScreen> createState() => _RequestMapScreenState();
}

class _RequestMapScreenState extends State<RequestMapScreen> {
  GoogleMapController? _map;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  RideRequest? _request;

  List<Driver> _allDrivers = [];
  List<Driver> _drivers = [];

  // Tracks the driver's last known location for rotation calculation
  LatLng? _lastDriverLocation;

  double _driverRadiusKm = 5.0;
  BitmapDescriptor? _vehicleIcon;

  bool get _hasDriverAccepted =>
      _request?.status == 'accepted' || _request?.status == 'in-progress';

  @override
  void initState() {
    super.initState();
    _loadVehicleIcon();
    _addPickupDestinationMarkers();
    _fetchMainRoute();
    _listenRequest();
    _listenDrivers();
  }

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // ICON
  // ---------------------------------------------------------------------------

  Future<void> _loadVehicleIcon() async {
    final asset = widget.vehicleType.toLowerCase() == 'motorbike'
        ? 'images/bike-delivery-icon.png'
        : 'images/bicycle.png';

    _vehicleIcon = await _bitmapFromAsset(assetPath: asset);
  }

  Future<BitmapDescriptor> _bitmapFromAsset({
    required String assetPath,
    int width = 128,
  }) async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    final frame = await codec.getNextFrame();
    final bytes =
    (await frame.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    return BitmapDescriptor.fromBytes(bytes);
  }

  // ---------------------------------------------------------------------------
  // MAP HELPERS (GEOMETRY)
  // ---------------------------------------------------------------------------

  void _addPickupDestinationMarkers() {
    _markers.addAll([
      Marker(
        markerId: const MarkerId('pickup'),
        position: widget.pickupLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      Marker(
        markerId: const MarkerId('dest'),
        position: widget.destinationLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    ]);
  }

  double _kmBetween(LatLng a, LatLng b) {
    const R = 6371.0;
    final dLat = (b.latitude - a.latitude) * (math.pi / 180);
    final dLng = (b.longitude - a.longitude) * (math.pi / 180);
    final la1 = a.latitude * (math.pi / 180);
    final la2 = b.latitude * (math.pi / 180);

    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(la1) *
            math.cos(la2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    return R * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  // Finds the index of the point in the route polyline closest to the driver
  int _findClosestPolylineIndex(LatLng driverLocation, List<LatLng> routePoints) {
    double minDistance = double.infinity;
    int closestIndex = 0;

    for (int i = 0; i < routePoints.length; i++) {
      final dist = _kmBetween(driverLocation, routePoints[i]);
      if (dist < minDistance) {
        minDistance = dist;
        closestIndex = i;
      }
    }
    return closestIndex;
  }

  // Calculates the bearing (angle) between two LatLng points for marker rotation
  double _calculateBearing(LatLng start, LatLng end) {
    final startLat = start.latitude * (math.pi / 180);
    final startLng = start.longitude * (math.pi / 180);
    final endLat = end.latitude * (math.pi / 180);
    final endLng = end.longitude * (math.pi / 180);

    final dLng = endLng - startLng;

    final y = math.sin(dLng) * math.cos(endLat);
    final x = math.cos(startLat) * math.sin(endLat) -
        math.sin(startLat) * math.cos(endLat) * math.cos(dLng);

    double bearing = math.atan2(y, x) * (180 / math.pi);
    return (bearing + 360) % 360; // Normalize to 0-360 degrees
  }

  // ---------------------------------------------------------------------------
  // STREAMS
  // ---------------------------------------------------------------------------

  void _listenRequest() {
    RequestService().getRequestStream(widget.requestId).listen((req) {
      if (!mounted) return;
      setState(() {
        _request = req;
        // Debug prints to ensure state is changing correctly
        print('Request Status from Stream: ${_request?.status}');
        print('Has Driver Accepted?: $_hasDriverAccepted');

        // When the request is accepted or in progress
        if (_hasDriverAccepted) {
          _updateAcceptedDriverMarker();
          _fetchDriverToPickupRoute();
        }
      });
    });
  }

  void _listenDrivers() {
    DriverService()
        .getApprovedDrivers(vehicleType: widget.vehicleType)
        .listen((list) {
      if (_hasDriverAccepted) return;
      _allDrivers = list;
      _applyRadiusLogic();
    });
  }

  void _applyRadiusLogic() {
    // IMPORTANT: If a driver has been accepted, we stop drawing nearby drivers.
    if (_hasDriverAccepted) {
      _markers.removeWhere((m) => m.markerId.value.startsWith('driver_'));
      setState(() {});
      return;
    }

    final pickup = widget.pickupLatLng;

    _drivers = _allDrivers.where((d) {
      final dist = _kmBetween(
        pickup,
        LatLng(d.latitude, d.longitude),
      );
      return dist <= _driverRadiusKm;
    }).toList();

    // Remove only the *temporary* nearby driver markers
    _markers.removeWhere((m) => m.markerId.value.startsWith('driver_'));

    for (final d in _drivers) {
      _markers.add(
        Marker(
          markerId: MarkerId('driver_${d.id}'),
          position: LatLng(d.latitude, d.longitude),
          icon: _vehicleIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure),
        ),
      );
    }

    setState(() {});
  }

  // ---------------------------------------------------------------------------
  // ROUTE HELPERS
  // ---------------------------------------------------------------------------

  Future<void> _fetchMainRoute() async {
    final res =
    await _directions(widget.pickupLatLng, widget.destinationLatLng);

    if (res.points.isNotEmpty) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('main'),
          points: res.points,
          // Green route (Pickup to Destination)
          color: Colors.green,
          width: 8,
        ),
      );
      setState(() {});
    }
  }

  // Fetches and draws the route from the accepted driver to the pickup location,
  // splitting it into gray (past) and blue (future) segments.
  Future<void> _fetchDriverToPickupRoute() async {
    // Check for acceptance and location data
    if (!_hasDriverAccepted ||
        _request?.driverLat == null ||
        _request?.driverLog == null) {
      // Clear the routes if conditions fail
      _polylines.removeWhere((p) => p.polylineId.value.startsWith('driver_route'));
      setState(() {});
      return;
    }

    // Correctly accessing double? from the model
    final driverLat = _request!.driverLat ?? 0.0;
    final driverLng = _request!.driverLog ?? 0.0;

    if (driverLat == 0.0 && driverLng == 0.0) return;

    final driverLocation = LatLng(driverLat, driverLng);
    final pickupLocation = widget.pickupLatLng;

    // 1. Get the full route
    final res = await _directions(driverLocation, pickupLocation);
    final fullRoutePoints = res.points;

    // Clear previous polyline segments
    _polylines.removeWhere((p) => p.polylineId.value.startsWith('driver_route'));

    if (fullRoutePoints.isNotEmpty) {
      // 2. Find the point on the route closest to the current driver location
      final closestIndex = _findClosestPolylineIndex(driverLocation, fullRoutePoints);

      // 3. Create Past Route (Gray)
      final List<LatLng> pastPoints = fullRoutePoints.sublist(0, closestIndex + 1);

      // 4. Create Future Route (Blue)
      // Start the future path *from* the driver's current exact location for smoothness.
      final List<LatLng> futurePoints = [driverLocation];
      if (closestIndex < fullRoutePoints.length) {
        futurePoints.addAll(fullRoutePoints.sublist(closestIndex));
      }

      // Add Past (Grey) Segment
      if (pastPoints.isNotEmpty) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('driver_route_past'),
            points: pastPoints,
            color: Colors.grey, // Grey for the path already traveled
            width: 8,
          ),
        );
      }

      // Add Future (Blue) Segment
      if (futurePoints.isNotEmpty) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('driver_route_future'),
            points: futurePoints,
            color: Colors.blue, // Blue for the remaining path
            width: 8,
          ),
        );
      }
    }
    setState(() {});
  }

  // Updates the accepted driver's marker, centers the map, and sets rotation.
  void _updateAcceptedDriverMarker() {
    // Check for acceptance and location data
    if (!_hasDriverAccepted ||
        _request?.driverLat == null ||
        _request?.driverLog == null) {
      return;
    }

    // Correctly accessing double? from the model
    final driverLat = _request!.driverLat ?? 0.0;
    final driverLng = _request!.driverLog ?? 0.0;

    if (driverLat == 0.0 && driverLng == 0.0) return;

    final newDriverLocation = LatLng(driverLat, driverLng);

    // Calculate rotation
    double rotation = 0.0;
    if (_lastDriverLocation != null) {
      rotation = _calculateBearing(_lastDriverLocation!, newDriverLocation);
    }
    _lastDriverLocation = newDriverLocation; // Update last location for the next change

    // 1. Remove old driver markers
    _markers.removeWhere((m) => m.markerId.value.startsWith('driver_'));

    // 2. Add the single accepted driver marker with rotation
    _markers.add(
      Marker(
        markerId: const MarkerId('driver_accepted'),
        position: newDriverLocation,
        icon: _vehicleIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        // Apply the rotation
        rotation: rotation,
        anchor: const Offset(0.5, 0.5), // Center the icon
        flat: true, // Marker flat on the map for better rotation viewing
      ),
    );

    // 3. Center map on the driver's current location
    if (_map != null) {
      _map!.animateCamera(CameraUpdate.newLatLngZoom(newDriverLocation, 14.0));
    }
  }

  // Directions API Call
  Future<_RouteResult> _directions(LatLng o, LatLng d) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${o.latitude},${o.longitude}'
          '&destination=${d.latitude},${d.longitude}'
          '&mode=driving'
          '&key=$kDirectionsKey',
    );

    final r = await http.get(url);
    final data = jsonDecode(r.body);
    final routes = data['routes'] as List?;
    if (routes == null || routes.isEmpty) {
      return _RouteResult(points: const []);
    }

    return _RouteResult(
      points: _decodePolyline(
        routes.first['overview_polyline']['points'],
      ),
    );
  }

  // Polyline Decoder
  List<LatLng> _decodePolyline(String encoded) {
    int i = 0, lat = 0, lng = 0;
    final List<LatLng> out = [];

    while (i < encoded.length) {
      int b, shift = 0, res = 0;
      do {
        b = encoded.codeUnitAt(i++) - 63;
        res |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (res & 1) != 0 ? ~(res >> 1) : (res >> 1);

      shift = 0;
      res = 0;
      do {
        b = encoded.codeUnitAt(i++) - 63;
        res |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (res & 1) != 0 ? ~(res >> 1) : (res >> 1);

      out.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
        Text(_hasDriverAccepted ? 'Driver Assigned' : 'Finding Drivers'),
        backgroundColor: const Color(0xFF1A2B7B),
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (c) => _map = c,
            initialCameraPosition:
            CameraPosition(target: widget.pickupLatLng, zoom: 13),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
          ),

          // Radius slider (pending only)
          if (!_hasDriverAccepted)
            Positioned(
              left: 16,
              right: 16,
              bottom: 90,
              child: SafeArea(
                child: Card(
                  color: const Color(0xFF1A2B7B),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Text(
                          'Driver radius: ${_driverRadiusKm.toStringAsFixed(1)} km',
                          style: const TextStyle(color: Colors.white),
                        ),
                        Slider(
                          min: 1,
                          max: 15,
                          divisions: 14,
                          value: _driverRadiusKm,
                          onChanged: (v) {
                            setState(() => _driverRadiusKm = v);
                            _applyRadiusLogic();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Cancel button (pending only)
          if (!_hasDriverAccepted)
            Positioned(
              bottom: 16,
              left: 20,
              right: 20,
              child: SafeArea(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    await RequestService()
                        .cancelRideRequest(widget.requestId);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text(
                    'Cancel Request',
                    style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),

          // DRIVER ACCEPTED BOTTOM SHEET
          if (_hasDriverAccepted && _request != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: _DriverAcceptedBottomSheet(
                request: _request!,
                pickupAddress: widget.pickupAddress,
                destinationAddress: widget.destinationAddress,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DRIVER ACCEPTED BOTTOM SHEET
// ---------------------------------------------------------------------------

class _DriverAcceptedBottomSheet extends StatelessWidget {
  final RideRequest request;
  final String pickupAddress;
  final String destinationAddress;

  const _DriverAcceptedBottomSheet({
    required this.request,
    required this.pickupAddress,
    required this.destinationAddress,
  });

  @override
  Widget build(BuildContext context) {
    // Determine the estimated fare string
    final String estimatedFare = request.estimatedFare.toStringAsFixed(2);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1A2B7B),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Driver Info and Call Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: request.driverImage != null
                    ? NetworkImage(request.driverImage!)
                    : null,
                child: request.driverImage == null
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      request.driverName ?? 'Driver',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.driverPhone ?? 'N/A',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fare: \$$estimatedFare',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.call, color: Colors.green, size: 28),
                onPressed: () {
                  final phone = request.driverPhone;
                  if (phone != null) {
                    launchUrl(Uri.parse('tel:$phone'));
                  }
                },
              ),
            ],
          ),

          const Divider(height: 24, thickness: 1, color: Colors.white30),

          // Row 2: Addresses
          _buildAddressRow(
            icon: Icons.circle,
            iconColor: Colors.greenAccent,
            label: 'From',
            address: pickupAddress,
          ),
          const SizedBox(height: 10),
          _buildAddressRow(
            icon: Icons.location_on,
            iconColor: Colors.redAccent,
            label: 'To',
            address: destinationAddress,
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label:',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.white70,
                ),
              ),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RouteResult {
  _RouteResult({required this.points});
  final List<LatLng> points;
}