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
          'driver_on_delivery',
          'in_progress'
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

  List<Map<String, dynamic>> _availableDrivers = [];

  String? _mainRouteDistance;
  String? _mainRouteDuration;
  String? _debugMessage = '';

  // Loading states
  bool _isLoadingMap = true;
  bool _isLoadingRoute = true;
  bool _isLoadingDrivers = true;

  // Map type toggle
  MapType _currentMapType = MapType.normal;

  StreamSubscription<DocumentSnapshot>? _driverLocationSubscription;
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
    _listenToDriverLocation();
    _listenToRequestUpdates();
    _listenToAvailableDrivers();
  }

  Future<void> _loadCustomIcons() async {
    try {
      _defaultDriverIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      _assignedDriverIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);

      _motorbikeIcon = await _createCustomIcon('images/bike.jpg', size: 180);
      _bicycleIcon = await _createCustomIcon('images/bicycle.png', size: 390);

      debugPrint('✅ Custom icons loaded successfully');
    } catch (e) {
      debugPrint('⚠️ Failed to load custom icons: $e');
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
      debugPrint('⚠️ Icon loading failed for $assetPath: $e');
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

    // Show feedback to user
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

  void _listenToDriverLocation() {
    if (_driverId == null || _driverId!.isEmpty) return;

    _driverLocationSubscription?.cancel();

    _driverLocationSubscription = FirebaseFirestore.instance
        .collection('riders')
        .doc(_driverId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data()!;
        final lat = data['latitude'] as double?;
        final lng = data['longitude'] as double?;

        if (lat != null && lng != null) {
          setState(() {
            _driverPosition = LatLng(lat, lng);
            _updateAssignedDriverMarker();
            _updateAssignedDriverRoute();
          });
        }
      }
    });
  }

  void _updateAssignedDriverMarker() {
    if (_driverPosition == null) return;

    _markers.removeWhere((marker) => marker.markerId.value == 'assigned_driver');

    final marker = Marker(
      markerId: const MarkerId('assigned_driver'),
      position: _driverPosition!,
      icon: _assignedDriverIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      infoWindow: const InfoWindow(
        title: '🚗 Your Driver',
        snippet: 'On the way to you',
      ),
      anchor: const Offset(0.5, 0.5),
      zIndex: 9,
    );

    _markers.add(marker);
    _fitAllMarkers();
  }

  void _updateAssignedDriverRoute() async {
    if (_driverPosition == null) return;

    final pickupLat = widget.deliveryData['pickupLat'] as double?;
    final pickupLng = widget.deliveryData['pickupLng'] as double?;
    final dropoffLat = (widget.deliveryData['dropoffLat'] ?? widget.deliveryData['destinationLat']) as double?;
    final dropoffLng = (widget.deliveryData['dropoffLng'] ?? widget.deliveryData['destinationLng']) as double?;

    _polylines.removeWhere((polyline) => polyline.polylineId.value == 'assigned_driver_route');

    LatLng? targetPoint;

    if (_currentStatus == 'accepted' || _currentStatus == 'driver_on_pickup') {
      if (pickupLat != null && pickupLng != null) {
        targetPoint = LatLng(pickupLat, pickupLng);
      }
    } else if (_currentStatus == 'driver_on_delivery' || _currentStatus == 'in_progress') {
      if (dropoffLat != null && dropoffLng != null) {
        targetPoint = LatLng(dropoffLat, dropoffLng);
      }
    }

    if (targetPoint != null) {
      final result = await _fetchDirections(_driverPosition!, targetPoint);

      if (result.points.isNotEmpty && mounted) {
        setState(() {
          _polylines.add(Polyline(
            polylineId: const PolylineId('assigned_driver_route'),
            color: Colors.orange,
            width: 6,
            points: result.points,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
            zIndex: 5,
          ));
        });
      }
    }
  }

  void _listenToRequestUpdates() {
    _requestUpdatesSubscription?.cancel();

    _requestUpdatesSubscription = FirebaseFirestore.instance
        .collection('requests')
        .doc(widget.requestId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data()!;
        final newStatus = data['status'] as String?;
        final newDriverId = data['driverId'] as String?;

        setState(() {
          _currentStatus = newStatus;
          if (newDriverId != null && newDriverId != _driverId) {
            _driverId = newDriverId;
            _listenToDriverLocation();
          }
        });
        _updateAssignedDriverRoute();
      }
    });
  }

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
        return _RouteResult(points: const []);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String?;

      if (status != 'OK') {
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

    for (final driver in _availableDrivers) {
      points.add(LatLng(driver['latitude'] as double, driver['longitude'] as double));
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
      case 'driver_on_pickup':
        return 'Driver Coming to Pickup';
      case 'in_progress':
      case 'driver_on_delivery':
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
      case 'driver_on_pickup':
        return 'Driver is heading to pickup location';
      case 'in_progress':
      case 'driver_on_delivery':
        return 'Package being delivered to destination';
      default:
        return 'Tracking your delivery';
    }
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
          buildingsEnabled: true,
          mapToolbarEnabled: false,
          mapType: _currentMapType, // Toggle between normal, satellite, hybrid
        ),

        // Map Type Toggle Button
        Positioned(
          top: MediaQuery.of(context).padding.top + 200,
          right: 16,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _toggleMapType,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _currentMapType == MapType.normal
                          ? Icons.layers
                          : _currentMapType == MapType.satellite
                          ? Icons.satellite_alt
                          : Icons.map,
                      color: const Color(0xFF1A2B7B),
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentMapType == MapType.normal
                          ? 'Street'
                          : _currentMapType == MapType.satellite
                          ? 'Satellite'
                          : 'Hybrid',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A2B7B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Loading overlay for map initialization
        if (_isLoadingMap || _isLoadingRoute)
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.8),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A2B7B)),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isLoadingMap ? 'Loading map...' : 'Calculating route...',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A2B7B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Top status card
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          right: 16,
          child: _buildStatusCard(),
        ),

        // Distance/Duration chip with loader
        if (_mainRouteDistance != null || _mainRouteDuration != null || _isLoadingRoute)
          Positioned(
            top: MediaQuery.of(context).padding.top + 140,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _isLoadingRoute
                    ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A2B7B)),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Calculating route...',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ],
                )
                    : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.route, size: 18, color: Colors.black87),
                    const SizedBox(width: 8),
                    Text(
                      [
                        if (_mainRouteDistance != null) _mainRouteDistance!,
                        if (_mainRouteDuration != null) _mainRouteDuration!,
                      ].join(' • '),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Legend
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 80,
          left: 16,
          right: 16,
          child: _buildLegend(),
        ),

        // Cancel button
        if (_currentStatus == 'pending' ||
            _currentStatus == 'searching' ||
            _currentStatus == 'accepted')
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 16,
            right: 16,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 8,
              ),
              icon: const Icon(Icons.cancel_outlined, size: 22),
              label: const Text(
                'Cancel Delivery',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: _showCancelDialog,
            ),
          ),
      ],
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2B7B),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildVehicleIcon(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStatusTitle(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (_isLoadingDrivers) ...[
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Finding drivers...',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ] else
                      Expanded(
                        child: Text(
                          _getStatusMessage(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
                if (_currentStatus == 'pending' || _currentStatus == 'searching') ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _vehicleType == 'motorbike' ? Colors.orange : Colors.lightGreen,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleIcon() {
    final isMotorbike = _vehicleType == 'motorbike';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isMotorbike ? Colors.orange : Colors.lightGreen,
        shape: BoxShape.circle,
      ),
      child: Icon(
        isMotorbike ? Icons.motorcycle : Icons.pedal_bike,
        color: Colors.white,
        size: 26,
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem('Pickup', Colors.green),
              _buildLegendItem('Destination', Colors.red),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem('Available', Colors.blue),
              _buildLegendItem('Your Driver', Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Future<void> _showCancelDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2B7B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Cancel Delivery',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to cancel this delivery request?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'No, Keep It',
              style: TextStyle(color: Colors.white),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('requests')
            .doc(widget.requestId)
            .update({
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          Navigator.of(context).pop('cancelled');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to cancel: $e'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _driverLocationSubscription?.cancel();
    _requestUpdatesSubscription?.cancel();
    _availableDriversSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}

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