import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:ubwinza_users/global/global_vars.dart';

// Assuming 'googleApiKey' is defined in global_vars.dart
String kGoogleApiKey = googleApiKey;

class EnhancedDeliveryTrackingView extends StatefulWidget {
  final Map<String, dynamic> deliveryData;
  final String requestId;

  const EnhancedDeliveryTrackingView({
    super.key,
    required this.deliveryData,
    required this.requestId,
  });

  @override
  State<EnhancedDeliveryTrackingView> createState() =>
      _EnhancedDeliveryTrackingViewState();
}

class _EnhancedDeliveryTrackingViewState
    extends State<EnhancedDeliveryTrackingView> {
  final String? userId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'No user logged in.',
            style: TextStyle(fontSize: 16, color: Colors.red),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Delivery Tracking',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A2B7B),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('requests')
            .where('userId', isEqualTo: userId)
            .where('status', whereIn: [
          'pending',
          'searching',
          'accepted',
          'driver_on_pickup',
          'heading_to_destination',
          'in-progress',
        ]).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingScreen();
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading deliveries: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'You have no active deliveries.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          QueryDocumentSnapshot? delivery;
          try {
            delivery = docs.firstWhere(
                  (doc) => doc.id == widget.requestId,
            ) as QueryDocumentSnapshot;
          } catch (e) {
            delivery = docs.first as QueryDocumentSnapshot;
          }

          final data = delivery.data() as Map<String, dynamic>;

          return _DeliveryMapTracker(
            requestId: delivery.id,
            deliveryData: data,
          );
        },
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A2B7B)),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Loading delivery details...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A2B7B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryMapTracker extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> deliveryData;

  const _DeliveryMapTracker({
    required this.requestId,
    required this.deliveryData,
  });

  @override
  State<_DeliveryMapTracker> createState() => _DeliveryMapTrackerState();
}

// Helper class for Directions API result
class _RouteResult {
  final List<LatLng> points;
  final String? distanceText;
  final String? durationText;

  _RouteResult({
    required this.points,
    this.distanceText,
    this.durationText,
  });
}

class _DeliveryMapTrackerState extends State<_DeliveryMapTracker> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  LatLng? _driverPosition;
  String? _driverId;
  String? _currentStatus;
  String? _vehicleType;

  BitmapDescriptor? _motorbikeIcon;
  BitmapDescriptor? _bicycleIcon;
  BitmapDescriptor? _assignedDriverIcon;
  BitmapDescriptor? _defaultDriverIcon;

  LatLng? _lastDriverLocation;

  List<Map<String, dynamic>> _availableDrivers = [];

  String? _mainRouteDistance;
  String? _mainRouteDuration;
  // String? _debugMessage = ''; // Unused, commented out

  // Loading states
  bool _isLoadingMap = true;
  bool _isLoadingRoute = true;
  bool _isLoadingDrivers = true;

  // Map type toggle
  MapType _currentMapType = MapType.normal;

  // Removed _driverLocationSubscription as it is no longer needed
  // StreamSubscription<DocumentSnapshot>? _driverLocationSubscription;
  StreamSubscription<DocumentSnapshot>? _requestUpdatesSubscription;
  StreamSubscription<QuerySnapshot>? _availableDriversSubscription;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.deliveryData['status'];
    _driverId = widget.deliveryData['driverId'];
    _vehicleType = widget.deliveryData['vehicleType'] ?? 'motorbike';

    debugPrint('🟢 Initializing map with data: ${widget.deliveryData}');

    _loadCustomIcons();
    _initializeMapData();
    _fetchMainRoute();
    // Removed call to _listenToDriverLocation()
    _listenToRequestUpdates();

    if (!(_currentStatus == 'accepted' || _currentStatus == 'in-progress' || _currentStatus == 'heading_to_destination')) {
      _listenToAvailableDrivers();
    }
  }

  @override
  void dispose() {
    // _driverLocationSubscription?.cancel(); // Cancelled as it's removed
    _requestUpdatesSubscription?.cancel();
    _availableDriversSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadCustomIcons() async {
    try {
      _defaultDriverIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      _assignedDriverIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);

      // NOTE: Ensure 'images/bike-delivery-icon.png' and 'images/bicycle.png' are in your assets folder and registered in pubspec.yaml
      _motorbikeIcon = await _createCustomIcon('images/bike-delivery-icon.png', size: 128);
      _bicycleIcon = await _createCustomIcon('images/bicycle.png', size: 128);

    } catch (e) {
      _motorbikeIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      _bicycleIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
      _assignedDriverIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
  }

  Future<BitmapDescriptor> _createCustomIcon(String assetPath, {int size = 150}) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: size,
      );
      final frame = await codec.getNextFrame();
      final bytes = (await frame.image.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      return BitmapDescriptor.fromBytes(bytes);
    } catch (e) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
  }

  void _initializeMapData() {
    final pickupLat = widget.deliveryData['pickupLat'] as double?;
    final pickupLng = widget.deliveryData['pickupLng'] as double?;
    final dropoffLat = (widget.deliveryData['dropoffLat'] ?? widget.deliveryData['destinationLat']) as double?;
    final dropoffLng = (widget.deliveryData['dropoffLng'] ?? widget.deliveryData['destinationLng']) as double?;

    _markers.clear();

    if (pickupLat != null && pickupLng != null) {
      final pickupMarker = Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(pickupLat, pickupLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: '📦 Pickup Location',
          snippet: widget.deliveryData['pickupAddress']?.toString() ?? 'Pickup',
        ),
        zIndex: 10,
      );
      _markers.add(pickupMarker);
    }

    if (dropoffLat != null && dropoffLng != null) {
      final destMarker = Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(dropoffLat, dropoffLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: '🏁 Delivery Destination',
          snippet: (widget.deliveryData['dropoffAddress'] ?? widget.deliveryData['destinationAddress'])?.toString() ?? 'Destination',
        ),
        zIndex: 10,
      );
      _markers.add(destMarker);
    }

    if (pickupLat != null && pickupLng != null && dropoffLat != null && dropoffLng != null) {
      _polylines.add(Polyline(
        polylineId: const PolylineId('simple_route'),
        color: Colors.green.withOpacity(0.7),
        width: 6,
        points: [
          LatLng(pickupLat, pickupLng),
          LatLng(dropoffLat, dropoffLng),
        ],
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        zIndex: 1,
      ));
    }

    setState(() {
      _isLoadingMap = false;
    });
  }

  void _toggleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.normal
          ? MapType.satellite
          : _currentMapType == MapType.satellite
          ? MapType.hybrid
          : MapType.normal;
    });

    String mapTypeName = _currentMapType == MapType.normal
        ? 'Street View'
        : _currentMapType == MapType.satellite
        ? 'Satellite View'
        : 'Hybrid View';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Switched to $mapTypeName'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1A2B7B),
      ),
    );
  }

  Future<void> _fetchMainRoute() async {
    setState(() {
      _isLoadingRoute = true;
    });

    final pickupLat = widget.deliveryData['pickupLat'] as double?;
    final pickupLng = widget.deliveryData['pickupLng'] as double?;
    final dropoffLat = (widget.deliveryData['dropoffLat'] ?? widget.deliveryData['destinationLat']) as double?;
    final dropoffLng = (widget.deliveryData['dropoffLng'] ?? widget.deliveryData['destinationLng']) as double?;

    if (pickupLat == null || pickupLng == null || dropoffLat == null || dropoffLng == null) {
      setState(() {
        _isLoadingRoute = false;
      });
      return;
    }

    final result = await _fetchDirections(
      LatLng(pickupLat, pickupLng),
      LatLng(dropoffLat, dropoffLng),
    );

    if (result.points.isNotEmpty && mounted) {
      setState(() {
        _polylines.removeWhere((p) => p.polylineId.value == 'simple_route');
        _polylines.removeWhere((p) => p.polylineId.value == 'main_route');

        _polylines.add(Polyline(
          polylineId: const PolylineId('main_route'),
          color: Colors.green,
          width: 8,
          points: result.points,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
          zIndex: 3,
        ));
        _mainRouteDistance = result.distanceText;
        _mainRouteDuration = result.durationText;
        _isLoadingRoute = false;
      });
    } else {
      setState(() {
        _isLoadingRoute = false;
      });
    }
  }

  void _listenToAvailableDrivers() {
    _availableDriversSubscription?.cancel();

    if (_driverId != null && _driverId!.isNotEmpty) {
      return;
    }

    _availableDriversSubscription = FirebaseFirestore.instance
        .collection('riders')
        .where('vehicleType', isEqualTo: _vehicleType)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _availableDrivers = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'latitude': data['latitude'] as double?,
              'longitude': data['longitude'] as double?,
              'name': data['name'] as String? ?? 'Driver ${doc.id}',
              'rating': data['rating'] as double? ?? 0.0,
              'vehicleType': data['vehicleType'] as String? ?? 'motorbike',
            };
          }).where((driver) =>
          driver['latitude'] != null &&
              driver['longitude'] != null &&
              driver['id'] != _driverId).toList();

          _isLoadingDrivers = false;
        });

        _updateAvailableDriverMarkers();
        _updateDriverConnectionLines();
      }
    });
  }

  void _updateAvailableDriverMarkers() {
    if (_driverId != null && _driverId!.isNotEmpty) {
      _markers.removeWhere((marker) => marker.markerId.value.startsWith('available_driver_'));
      _polylines.removeWhere((polyline) => polyline.polylineId.value.startsWith('connection_'));
      if(mounted) setState(() {});
      return;
    }

    _markers.removeWhere((marker) => marker.markerId.value.startsWith('available_driver_'));

    for (final driver in _availableDrivers) {
      final lat = driver['latitude'] as double;
      final lng = driver['longitude'] as double;
      final driverId = driver['id'] as String;
      final vehicleType = driver['vehicleType'] as String;
      final driverName = driver['name'] as String;

      BitmapDescriptor icon;
      if (vehicleType.toLowerCase() == 'motorbike') {
        icon = _motorbikeIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      } else if (vehicleType.toLowerCase() == 'bicycle') {
        icon = _bicycleIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
      } else {
        icon = _defaultDriverIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      }

      final marker = Marker(
        markerId: MarkerId('available_driver_$driverId'),
        position: LatLng(lat, lng),
        icon: icon,
        infoWindow: InfoWindow(
          title: '🚴 $driverName',
          snippet: '$vehicleType • Rating: ${driver['rating']} ★',
        ),
        anchor: const Offset(0.5, 0.5),
        zIndex: 8,
      );

      _markers.add(marker);
    }

    if (mounted) setState(() {});
  }

  void _updateDriverConnectionLines() async {
    if (_driverId != null && _driverId!.isNotEmpty) {
      _polylines.removeWhere((polyline) => polyline.polylineId.value.startsWith('connection_'));
      if(mounted) setState(() {});
      return;
    }

    _polylines.removeWhere((polyline) => polyline.polylineId.value.startsWith('connection_'));

    final pickupLat = widget.deliveryData['pickupLat'] as double?;
    final pickupLng = widget.deliveryData['pickupLng'] as double?;

    if (pickupLat == null || pickupLng == null) return;

    final pickupPoint = LatLng(pickupLat, pickupLng);

    for (final driver in _availableDrivers) {
      final driverLat = driver['latitude'] as double;
      final driverLng = driver['longitude'] as double;
      final driverPoint = LatLng(driverLat, driverLng);
      final driverId = driver['id'] as String;

      final routeResult = await _fetchDirections(driverPoint, pickupPoint);

      if (routeResult.points.isNotEmpty) {
        _polylines.add(Polyline(
          polylineId: PolylineId('connection_$driverId'),
          color: Colors.blue.withOpacity(0.6),
          width: 4,
          points: routeResult.points,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
          zIndex: 2,
        ));
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (mounted) setState(() {});
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


  // ------------------------------------------------------------------
  // MODIFIED/NEW LOGIC: Handle driver location updates from the request document
  // ------------------------------------------------------------------

  // Removed: _listenToDriverLocation()

  void _updateDriverPositionFromRequest({required double lat, required double lng}) {
    if (!mounted) return;

    setState(() {
      _driverPosition = LatLng(lat, lng);
      _updateAssignedDriverMarker();
      _updateAssignedDriverRoute();

      // Center map on the driver's current location when moving
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_driverPosition!, 15));
    });
  }

  void _updateAssignedDriverMarker() {
    if (_driverPosition == null) return;

    double rotation = 0.0;
    if (_lastDriverLocation != null) {
      rotation = _calculateBearing(_lastDriverLocation!, _driverPosition!);
    }
    _lastDriverLocation = _driverPosition;

    _markers.removeWhere((marker) => marker.markerId.value == 'assigned_driver');

    BitmapDescriptor iconToUse = _vehicleType?.toLowerCase() == 'motorbike'
        ? _motorbikeIcon ?? _assignedDriverIcon!
        : _bicycleIcon ?? _assignedDriverIcon!;

    final marker = Marker(
      markerId: const MarkerId('assigned_driver'),
      position: _driverPosition!,
      icon: iconToUse,
      infoWindow: const InfoWindow(
        title: '🏍️ Your Driver',
      ),
      rotation: rotation,
      flat: true,
      anchor: const Offset(0.5, 0.5),
      zIndex: 9,
    );

    _markers.add(marker);
  }

  void _updateAssignedDriverRoute() async {
    if (_driverPosition == null) return;

    final pickupLat = widget.deliveryData['pickupLat'] as double?;
    final pickupLng = widget.deliveryData['pickupLng'] as double?;
    final dropoffLat = (widget.deliveryData['dropoffLat'] ?? widget.deliveryData['destinationLat']) as double?;
    final dropoffLng = (widget.deliveryData['dropoffLng'] ?? widget.deliveryData['destinationLng']) as double?;

    LatLng? targetPoint;

    // Determine the route target based on status
    if (_currentStatus == 'accepted' || _currentStatus == 'in-progress') {
      if (pickupLat != null && pickupLng != null) {
        targetPoint = LatLng(pickupLat, pickupLng);
      }
    } else if (_currentStatus == 'heading_to_destination') {
      if (dropoffLat != null && dropoffLng != null) {
        targetPoint = LatLng(dropoffLat, dropoffLng);
      }
    }

    // CRITICAL GUARD: Ensure we have a valid target point before proceeding.
    if (targetPoint == null) {
      _polylines.removeWhere((polyline) => polyline.polylineId.value.startsWith('assigned_driver_route_'));
      setState(() {});
      return;
    }

    // Clear previous segmented polylines
    _polylines.removeWhere((polyline) => polyline.polylineId.value.startsWith('assigned_driver_route_'));

    // Fetch the route from the driver's current position to the target point
    final result = await _fetchDirections(_driverPosition!, targetPoint);
    final fullRoutePoints = result.points;

    if (fullRoutePoints.isNotEmpty && mounted) {
      // Draw the entire path from the driver to the target in blue
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('assigned_driver_route_future'),
          points: fullRoutePoints,
          color: Colors.blue, // Blue for the remaining path
          width: 8,
          jointType: JointType.round,
          zIndex: 5,
        ),
      );
    }

    setState(() {});
  }

  // MODIFIED: This function now handles both status updates AND location updates
  void _listenToRequestUpdates() {
    _requestUpdatesSubscription?.cancel();

    // After assignment, stop listening to nearby drivers
    _availableDriversSubscription?.cancel();

    // Clear nearby driver markers/polylines
    _updateAvailableDriverMarkers();
    _polylines.removeWhere((polyline) => polyline.polylineId.value.startsWith('connection_'));

    _requestUpdatesSubscription = FirebaseFirestore.instance
        .collection('requests')
        .doc(widget.requestId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data()!;
        final newStatus = data['status'] as String?;
        final newDriverId = data['driverId'] as String?;
        final driverLat = data['driverLat'] as double?; // <-- New field extraction
        final driverLng = data['driverLog'] as double?; // <-- New field extraction

        setState(() {
          _currentStatus = newStatus;
          // The driverId check remains useful for initial setup logic
          if (newDriverId != null && newDriverId != _driverId) {
            _driverId = newDriverId;
            // Since we rely on the request stream now, no need to call another listener here.
            // But we do need to stop listening to nearby drivers if a driver is assigned.
            _availableDriversSubscription?.cancel();
          }
        });

        // Use the extracted driver location for updates
        if (driverLat != null && driverLng != null) {
          _updateDriverPositionFromRequest(lat: driverLat, lng: driverLng);
        } else if (_driverId != null && _driverId!.isNotEmpty) {
          // If a driver is assigned but location is momentarily null,
          // ensure markers/routes are cleared if delivery is completed or cancelled.
          if (_currentStatus == 'delivered' || _currentStatus == 'cancelled') {
            _driverPosition = null;
            _markers.removeWhere((marker) => marker.markerId.value == 'assigned_driver');
            _polylines.removeWhere((polyline) => polyline.polylineId.value.startsWith('assigned_driver_route_'));
            if(mounted) setState(() {});
          }
        }
      }
    });

  }
  // ------------------------------------------------------------------
  // END OF MODIFIED/NEW LOGIC
  // ------------------------------------------------------------------

  Future<_RouteResult> _fetchDirections(LatLng origin, LatLng dest) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${origin.latitude},${origin.longitude}'
          '&destination=${dest.latitude},${dest.longitude}'
          '&mode=driving'
          '&key=$kGoogleApiKey',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint('⚠️ Directions API failed with status code: ${response.statusCode}');
        return _RouteResult(points: const []);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String?;

      if (status != 'OK') {
        debugPrint('⚠️ Directions API status not OK: $status. Error: ${data['error_message']}');
        return _RouteResult(points: const []);
      }

      final routes = (data['routes'] as List);
      if (routes.isEmpty) {
        return _RouteResult(points: const []);
      }

      final route = routes.first as Map<String, dynamic>;
      final polylineStr = (route['overview_polyline']?['points'] as String?) ?? '';
      final points = _decodePolyline(polylineStr);

      String? distance, duration;
      final legs = (route['legs'] as List?) ?? const [];
      if (legs.isNotEmpty) {
        final leg = legs.first as Map<String, dynamic>;
        distance = leg['distance']?['text'] as String?;
        duration = leg['duration']?['text'] as String?;
      }

      return _RouteResult(
        points: points,
        distanceText: distance,
        durationText: duration,
      );
    } catch (e) {
      debugPrint('🚨 Error fetching directions: $e');
      return _RouteResult(points: const []);
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    if (encoded.isEmpty) return [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    final List<LatLng> points = [];

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  void _fitAllMarkers() {
    if (_mapController == null) return;

    final points = <LatLng>[];

    final pickupLat = widget.deliveryData['pickupLat'] as double?;
    final pickupLng = widget.deliveryData['pickupLng'] as double?;
    final dropoffLat = (widget.deliveryData['dropoffLat'] ?? widget.deliveryData['destinationLat']) as double?;
    final dropoffLng = (widget.deliveryData['dropoffLng'] ?? widget.deliveryData['destinationLng']) as double?;

    if (pickupLat != null && pickupLng != null) {
      points.add(LatLng(pickupLat, pickupLng));
    }
    if (dropoffLat != null && dropoffLng != null) {
      points.add(LatLng(dropoffLat, dropoffLng));
    }
    if (_driverPosition != null) points.add(_driverPosition!);

    if (_driverId == null || _driverId!.isEmpty) {
      for (final driver in _availableDrivers) {
        points.add(LatLng(driver['latitude'] as double, driver['longitude'] as double));
      }
    }


    if (points.length < 2) return;

    double? minLat, maxLat, minLng, maxLng;
    for (final point in points) {
      minLat = (minLat == null || point.latitude < minLat) ? point.latitude : minLat;
      maxLat = (maxLat == null || point.latitude > maxLat) ? point.latitude : maxLat;
      minLng = (minLng == null || point.longitude < minLng) ? point.longitude : minLng;
      maxLng = (maxLng == null || point.longitude > maxLng) ? point.longitude : maxLng;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat!, minLng!),
          northeast: LatLng(maxLat!, maxLng!),
        ),
        100,
      ),
    );
  }

  String _getStatusTitle() {
    switch (_currentStatus) {
      case 'pending':
      case 'searching':
        return 'Finding ${_vehicleType == 'motorbike' ? 'Motorbike' : 'Bicycle'} Drivers';
      case 'accepted':
      case 'in-progress':
        return 'Driver Coming to Pickup';
      case 'heading_to_destination':
        return 'On the Way to Destination';
      default:
        return 'Delivery Tracking';
    }
  }

  String _getStatusMessage() {

    final count = _availableDrivers.length;
    switch (_currentStatus) {
      case 'pending':
      case 'searching':
        return '$count ${_vehicleType == 'motorbike' ? 'motorbikes' : 'bicycles'} available nearby';
      case 'accepted':
      case 'in-progress':
        return 'Driver is heading to pickup location';
      case 'heading_to_destination':
        return 'Package being delivered to destination';
      default:
        return 'Tracking your delivery';
    }

  }

  String statusMessage() {
    return _getStatusMessage();
  }

  @override
  Widget build(BuildContext context) {
    final pickupLat = widget.deliveryData['pickupLat'] as double?;
    final pickupLng = widget.deliveryData['pickupLng'] as double?;

    return Stack(
      children: [
        // Main Google Map with Street View toggle
        GoogleMap(
          onMapCreated: (controller) {
            _mapController = controller;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fitAllMarkers();
            });
          },
          initialCameraPosition: CameraPosition(
            target: pickupLat != null && pickupLng != null
                ? LatLng(pickupLat, pickupLng)
                : const LatLng(0, 0),
            zoom: 13,
          ),
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: false,
          compassEnabled: true,
          trafficEnabled: false,
          mapType: _currentMapType,
        ),

        // Toggle Map Type Button
        Positioned(
          top: 10,
          right: 10,
          child: FloatingActionButton.small(
            heroTag: 'mapType',
            onPressed: _toggleMapType,
            backgroundColor: const Color(0xFF1A2B7B),
            elevation: 4,
            child: const Icon(
              Icons.layers,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),

        // Recenter Button
        Positioned(
          top: 70,
          right: 10,
          child: FloatingActionButton.small(
            heroTag: 'recenter',
            onPressed: _fitAllMarkers,
            backgroundColor: Colors.white,
            elevation: 4,
            child: const Icon(
              Icons.screen_rotation_alt,
              color: Color(0xFF1A2B7B),
              size: 20,
            ),
          ),
        ),

        // Status Card
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 5,
                  offset: const Offset(0, -3),
                ),
              ],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getStatusTitle(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A2B7B),
                        ),
                      ),
                      // if (_isLoadingRoute || _isLoadingDrivers)
                      //   const SizedBox(
                      //     width: 16,
                      //     height: 16,
                      //     child: CircularProgressIndicator(
                      //       strokeWidth: 2,
                      //       valueColor: AlwaysStoppedAnimation<Color>(
                      //           Color(0xFF1A2B7B)),
                      //     ),
                      //   ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _getStatusMessage(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_mainRouteDistance != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.route, color: Colors.green, size: 18),
                        const SizedBox(width: 5),
                        Text(
                          'Trip Distance: ${_mainRouteDistance ?? 'N/A'}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black
                          ),
                        ),
                        const SizedBox(width: 15),
                        const Icon(Icons.timer, color: Colors.green, size: 18),
                        const SizedBox(width: 5),
                        Text(
                          'Duration: ${_mainRouteDuration ?? 'N/A'}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Example of a conditional button based on status
                  if (_currentStatus == 'searching')
                    Padding(
                      padding: const EdgeInsets.only(top: 15.0),
                      child: ElevatedButton(
                        onPressed: () {
                          // Handle cancel request logic here
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Cancelling request... (Not implemented)')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          minimumSize: const Size(double.infinity, 45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Cancel Delivery Request',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}