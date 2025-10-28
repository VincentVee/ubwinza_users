// lib/features/maps/presentation/request_map_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../global/global_vars.dart'; // exposes googleApiKey
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
  /// 'motorbike' => uses motorbike.png else bicycle.png
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
  List<Driver> _drivers = [];

  // Main green route meta
  String? _distanceText;
  String? _durationText;
  String? _directionsWarning;

  // Selected driver card
  Driver? _selectedDriver;

  // Pre-rendered vehicle icon (static, no animation)
  BitmapDescriptor? _vehicleIcon;

  @override
  void initState() {
    super.initState();
    _loadVehicleIcon().then((_) {
      _addPickupDestinationMarkers();
      setState(() {});
    });
    _fetchMainRoute();
    _listenRequest();
    _listenDrivers();
  }

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  Future<void> _loadVehicleIcon() async {
    final asset = widget.vehicleType.toLowerCase() == 'motorbike'
        ? 'images/motorbike.png'
        : 'images/bicycle.png';

    final lower = widget.vehicleType.toLowerCase();
    final bool isBicycle = (lower == 'bicycle' || lower == 'bike');

    // Make the bicycle larger than motorbike
    final int width = isBicycle ? 180 : 128; // <-- increased bike size

    _vehicleIcon = await _bitmapFromAsset(assetPath: asset, width: width);// big, crisp
  }

  Future<BitmapDescriptor> _bitmapFromAsset({
    required String assetPath,
    int width = 132,
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

  void _addPickupDestinationMarkers() {
    _markers.addAll([
      Marker(
        markerId: const MarkerId('pickup'),
        position: widget.pickupLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Pickup', snippet: widget.pickupAddress),
        zIndex: 5,
      ),
      Marker(
        markerId: const MarkerId('dest'),
        position: widget.destinationLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow:
        InfoWindow(title: 'Destination', snippet: widget.destinationAddress),
        zIndex: 5,
      ),
    ]);
  }

  Future<void> _fitAll() async {
    if (_map == null) return;
    final points = <LatLng>[
      widget.pickupLatLng,
      widget.destinationLatLng,
      ..._drivers.map((d) => LatLng(d.latitude, d.longitude)),
    ];
    if (points.isEmpty) return;

    double? minLat, maxLat, minLng, maxLng;
    for (final p in points) {
      minLat = (minLat == null || p.latitude < minLat) ? p.latitude : minLat;
      maxLat = (maxLat == null || p.latitude > maxLat) ? p.latitude : maxLat;
      minLng = (minLng == null || p.longitude < minLng) ? p.longitude : minLng;
      maxLng = (maxLng == null || p.longitude > maxLng) ? p.longitude : maxLng;
    }
    await _map!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat!, minLng!),
          northeast: LatLng(maxLat!, maxLng!),
        ),
        72,
      ),
    );
  }

  // Streams
  void _listenRequest() {
    RequestService().getRequestStream(widget.requestId).listen((req) {
      setState(() => _request = req);
    });
  }

  void _listenDrivers() {
    DriverService()
        .getApprovedDrivers(vehicleType: widget.vehicleType)
        .listen((list) async {
      _drivers = list;
      _rebuildDriverMarkers();
      await _buildStaticBlueRoutes();
      if (mounted) {
        setState(() {});
        _fitAll();
      }
    });
  }

  void _rebuildDriverMarkers() {
    _markers.removeWhere((m) => m.markerId.value.startsWith('driver_'));
    for (final d in _drivers) {
      _markers.add(
        Marker(
          markerId: MarkerId('driver_${d.id}'),
          position: LatLng(d.latitude, d.longitude),
          icon: _vehicleIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          anchor: const Offset(.5, .5),
          zIndex: _request?.driverId == d.id ? 6 : 4,
          onTap: () => setState(() => _selectedDriver = d),
          infoWindow: InfoWindow(title: d.name, snippet: '${d.rating} ★'),
        ),
      );
    }
  }

  // Main green route (pickup -> destination)
  Future<void> _fetchMainRoute() async {
    final res = await _directions(widget.pickupLatLng, widget.destinationLatLng);
    if (!mounted) return;

    if (res.points.isNotEmpty) {
      _polylines.removeWhere((p) => p.polylineId.value == 'main_route');
      _polylines.add(Polyline(
        polylineId: const PolylineId('main_route'),
        color: Colors.green,
        width: 8,
        points: res.points,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ));
      setState(() {
        _distanceText = res.distanceText;
        _durationText = res.durationText;
        _directionsWarning = null;
      });
    } else {
      setState(() => _directionsWarning = res.statusMessage);
    }
  }

  // Static dotted blue routes (pickup -> each driver)
  Future<void> _buildStaticBlueRoutes() async {
    _polylines.removeWhere((p) => p.polylineId.value.startsWith('comm_'));

    for (final d in _drivers) {
      final res = await _directions(widget.pickupLatLng, LatLng(d.latitude, d.longitude));
      if (res.points.isEmpty) continue;

      _polylines.add(Polyline(
        polylineId: PolylineId('comm_${d.id}'),
        color: Colors.blue,
        width: 8, // make it as thick as green
        points: res.points,
        patterns:  [PatternItem.dash(10), PatternItem.gap(4)], // dotted look
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        zIndex: 6,
      ));
    }
  }

  // Directions client
  Future<_RouteResult> _directions(LatLng origin, LatLng dest) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${origin.latitude},${origin.longitude}'
          '&destination=${dest.latitude},${dest.longitude}'
          '&mode=driving'
          '&key=$kDirectionsKey',
    );

    try {
      final r = await http.get(url);
      if (r.statusCode != 200) {
        return _RouteResult(points: const [], statusMessage: 'HTTP ${r.statusCode}');
      }
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final status = data['status'] as String? ?? 'UNKNOWN';
      if (status != 'OK') {
        return _RouteResult(
          points: const [],
          statusMessage:
          '${data['status']} ${data['error_message'] ?? ''}'.trim(),
        );
      }

      final routes = (data['routes'] as List);
      if (routes.isEmpty) return _RouteResult(points: const []);

      final first = routes.first as Map<String, dynamic>;
      final polyStr = (first['overview_polyline']?['points'] as String?) ?? '';
      final points = _decodePolyline(polyStr);

      String? dist, dur;
      final legs = (first['legs'] as List?) ?? const [];
      if (legs.isNotEmpty) {
        final leg = legs.first as Map<String, dynamic>;
        dist = leg['distance']?['text'] as String?;
        dur = leg['duration']?['text'] as String?;
      }

      return _RouteResult(points: points, distanceText: dist, durationText: dur);
    } catch (e) {
      return _RouteResult(points: const [], statusMessage: 'Exception: $e');
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    if (encoded.isEmpty) return [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    final List<LatLng> out = [];

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

      out.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForStatus(_request?.status)),
        backgroundColor: Colors.blue,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (c) async {
              _map = c;
              await _fitAll();
            },
            onTap: (_) => setState(() => _selectedDriver = null),
            initialCameraPosition:
            CameraPosition(target: widget.pickupLatLng, zoom: 13.5),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            trafficEnabled: false,     // speed
            buildingsEnabled: false,   // speed
            tiltGesturesEnabled: false,// speed
            indoorViewEnabled: false,  // speed
            zoomControlsEnabled: false,
            compassEnabled: true,
          ),

          // Distance/duration chip (BLACK text)
          if (_distanceText != null || _durationText != null)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 10)
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.route, size: 18, color: Colors.black),
                      const SizedBox(width: 8),
                      Text(
                        [
                          if (_distanceText != null) _distanceText!,
                          if (_durationText != null) _durationText!,
                        ].join(' • '),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

              // 🔴 Cancel Button (only when searching)
              if (canCancel)
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 30,
                  left: 20,
                  right: 20,
                  child: SafeArea(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.cancel_outlined, size: 22),
                      label: const Text(
                        'Cancel Request',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Cancel Delivery Request'),
                            content: const Text(
                              'Are you sure you want to cancel this request?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('No'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
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
                              'cancelledAt': DateTime.now(),
                            });

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Request cancelled successfully.'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                              Navigator.of(context).pop();
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to cancel: $e'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RouteResult {
  _RouteResult({
    required this.points,
    this.distanceText,
    this.durationText,
    this.statusMessage,
  });

  final List<LatLng> points;
  final String? distanceText;
  final String? durationText;
  final String? statusMessage;
}
