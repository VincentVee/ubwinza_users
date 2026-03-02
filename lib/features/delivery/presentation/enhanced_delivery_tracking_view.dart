import 'dart:async';
import 'dart:convert';
import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ubwinza_users/global/global_vars.dart';

class DeliveryTrackingView extends StatefulWidget {
  final Map<String, dynamic> deliveryData;
  final String requestId;

  const DeliveryTrackingView({
    super.key,
    required this.deliveryData,
    required this.requestId,
  });

  @override
  State<DeliveryTrackingView> createState() =>
      _DeliveryTrackingViewState();
}

class _DeliveryTrackingViewState
    extends State<DeliveryTrackingView> {
  final Completer<GoogleMapController> _controller = Completer();

  // Location data
  LatLng? pickupLatLng;
  LatLng? destinationLatLng;
  LatLng? driverLatLng;
  
  // Map elements
  Marker? driverMarker;
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};

  // Custom Icon variable
  BitmapDescriptor? driverIcon;

  // Firestore stream for driver updates
  Stream<DocumentSnapshot>? driverStream;

  // IMPORTANT: Using a placeholder key since global_vars is not available

  @override
  void initState() {
    super.initState();
    loadCustomMarkerIcon(); // Load the custom image
    loadLocations();
  }
  
  // Method to load the custom asset image
  void loadCustomMarkerIcon() async {
    // The path 'images/ubwinzadeli.png' matches your pubspec.yaml asset definition.
    // The size is set correctly to load the asset as a BitmapDescriptor.
    final icon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'images/download.png', 
    );

    if (mounted) {
      setState(() {
        driverIcon = icon;
        // If driverLatLng is already known, we need to redraw the marker immediately
        // to use the newly loaded custom icon.
        if (driverLatLng != null && driverMarker != null) {
          addDriverMarker(driverLatLng!, driverMarker!.rotation);
        }
      });
    }
  }

  void loadLocations() async {
    final data = widget.deliveryData;

    pickupLatLng = LatLng(data['pickupLat'], data['pickupLng']);
    destinationLatLng = LatLng(data['destinationLat'], data['destinationLng']);

    addPickupAndDestinationMarkers();

    // 1. Draw the static route from Pickup to Destination
    await getFinalRoutePolyline();

    await Future.delayed(const Duration(milliseconds: 300));
    moveCameraToFitRoute();

    // 2. Start the live driver tracking
    startDriverLocationListener();
  }

  // -------------------------------------------------------
  // MARKER MANAGEMENT
  // -------------------------------------------------------

  void addPickupAndDestinationMarkers() {
    markers.add(Marker(
      markerId: const MarkerId("pickup"),
      position: pickupLatLng!,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: const InfoWindow(title: "Pickup"),
    ));

    markers.add(Marker(
      markerId: const MarkerId("destination"),
      position: destinationLatLng!,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: const InfoWindow(title: "Destination"),
    ));
  }

  // Replace your addDriverMarker method with this improved version:



// Also update the animateDriverMarker method to ensure smooth rotation:

// Replace your addDriverMarker method with this improved version:


// Replace your entire startDriverLocationListener method:




  // -------------------------------------------------------
  // DRIVER LIVE TRACKING & ANIMATION
  // -------------------------------------------------------


  // -------------------------------------------------------
  // ROUTE DRAWING (DIRECTIONS API)
  // -------------------------------------------------------

////////////----------------------------\

// Replace your addDriverMarker method with this improved version:

void addDriverMarker(LatLng pos, double bearing) {
  // Ensure bearing is normalized to 0-360 range
  double normalizedBearing = bearing % 360;
  if (normalizedBearing < 0) normalizedBearing += 360;

  driverMarker = Marker(
    markerId: const MarkerId("driver"),
    position: pos,
    rotation: normalizedBearing, 
    flat: true, // CRITICAL: keeps marker flat on map and allows rotation
    anchor: const Offset(0.5, 0.5), // Center anchor point
    icon: driverIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
    infoWindow: const InfoWindow(title: "Driver"),
  );

  setState(() {
    markers.removeWhere((m) => m.markerId == const MarkerId("driver"));
    markers.add(driverMarker!);
  });
}

// Replace your entire startDriverLocationListener method:

void startDriverLocationListener() {
  driverStream = FirebaseFirestore.instance
      .collection('requests')
      .doc(widget.requestId)
      .snapshots();

  driverStream!.listen((snapshot) {
    if (!snapshot.exists) return;

    double? lat = snapshot['driverLat'];
    double? log = snapshot['driverLog']; 

    if (lat == null || log == null) return;

    LatLng newPos = LatLng(lat, log);

    if (driverLatLng == null) {
      // Initial position setup: calculate bearing towards pickup
      driverLatLng = newPos;
      double initialBearing = 0;
      
      // Calculate bearing from driver's current position to pickup
      if (pickupLatLng != null) {
        initialBearing = calculateBearing(
          newPos.latitude,
          newPos.longitude,
          pickupLatLng!.latitude,
          pickupLatLng!.longitude,
        );
      }
      
      addDriverMarker(newPos, initialBearing);
      
      // Set initial camera with bearing towards pickup
      _controller.future.then((controller) {
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: newPos,
              zoom: 17,
              bearing: initialBearing, // Map points where driver is heading
              tilt: 45,
            ),
          ),
        );
      }); 
    } else if (newPos != driverLatLng) {
      // Animate from old position to new position
      // The marker will face the direction it's moving (from old to new)
      animateDriverMarker(driverLatLng!, newPos);
    }

    driverLatLng = newPos;
    
    // Update the live route from Driver to Pickup
    getDriverToPickupPolyline(newPos);
  });
}

void animateDriverMarker(LatLng from, LatLng to) async {
  final GoogleMapController controller = await _controller.future;

  // Calculate bearing for rotation (FROM current position TO next position)
  // This makes the marker face the direction it's GOING, not where it came from
  double bearing = calculateBearing(
    from.latitude,
    from.longitude,
    to.latitude,
    to.longitude,
  );

  const int animationTime = 600; // ms
  const int steps = 30;
  const int stepTime = animationTime ~/ steps;

  // Get the current rotation to interpolate smoothly
  double startBearing = driverMarker?.rotation ?? 0;
  
  // Handle rotation direction (shortest path)
  double bearingDiff = bearing - startBearing;
  if (bearingDiff > 180) bearingDiff -= 360;
  if (bearingDiff < -180) bearingDiff += 360;

  // Smoothly interpolate both position and rotation
  for (int i = 0; i < steps; i++) {
    double t = i / steps;
    double lat = from.latitude + (to.latitude - from.latitude) * t;
    double log = from.longitude + (to.longitude - from.longitude) * t;
    double interpolatedBearing = startBearing + bearingDiff * t;

    addDriverMarker(LatLng(lat, log), interpolatedBearing);

    // Smoothly rotate the map during animation
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(lat, log),
          zoom: 17,
          bearing: interpolatedBearing, // Map rotates with driver
          tilt: 45,
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: stepTime));
  }

  // Final position update
  addDriverMarker(to, bearing);

  // Auto follow driver with rotated map view
  // The map rotates so the driver always appears to be moving "up" the screen
  controller.animateCamera(
    CameraUpdate.newCameraPosition(
      CameraPosition(
        target: to,
        zoom: 17, // Closer zoom for driving view
        bearing: bearing, // Rotate map to match driver's heading
        tilt: 45, // Optional: add tilt for 3D perspective
      ),
    ),
  );
}
///------------------------------------



  // Draws the static Pickup to Destination route (GREEN)
  Future<void> getFinalRoutePolyline() async {
    final url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${pickupLatLng!.latitude},${pickupLatLng!.longitude}&destination=${destinationLatLng!.latitude},${destinationLatLng!.longitude}&mode=driving&key=$googleApiKey";

    final response = await http.get(Uri.parse(url));
    final data = jsonDecode(response.body);

    if (data["routes"] == null || data["routes"].isEmpty) return;

    final points = data["routes"][0]["overview_polyline"]["points"];

    List<LatLng> polylineCoords = decodePolyline(points);

    polylines.add(Polyline(
      polylineId: const PolylineId("finalRoute"),
      points: polylineCoords,
      width: 6,
      color: Colors.green,
    ));

    setState(() {});
  }

  // Draws the dynamic Driver to Pickup route (BLUE)
  Future<void> getDriverToPickupPolyline(LatLng driverPos) async {
    if (pickupLatLng == null) return;

    final url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${driverPos.latitude},${driverPos.longitude}&destination=${pickupLatLng!.latitude},${pickupLatLng!.longitude}&mode=driving&key=$googleApiKey";

    final response = await http.get(Uri.parse(url));
    final data = jsonDecode(response.body);

    if (data["routes"] == null || data["routes"].isEmpty) return;

    final points = data["routes"][0]["overview_polyline"]["points"];

    List<LatLng> polylineCoords = decodePolyline(points);

    // Remove the old driver route and add the new one
    polylines.removeWhere((p) => p.polylineId == const PolylineId("driverRoute"));
    polylines.add(
      Polyline(
        polylineId: const PolylineId("driverRoute"),
        points: polylineCoords,
        width: 6,
        color: Colors.blue, 
      ),
    );

    setState(() {});
  }

  // Decodes the Polyline string received from the Directions API
  List<LatLng> decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return polyline;
  }

  // -------------------------------------------------------
  // CAMERA & BEARING UTILITY
  // -------------------------------------------------------

  Future<void> moveCameraToFitRoute() async {
    final GoogleMapController controller = await _controller.future;

    final finalRoute = polylines.firstWhere(
      (p) => p.polylineId == const PolylineId("finalRoute"), 
      orElse: () => const Polyline(polylineId: PolylineId("empty")),
    );
    
    if (finalRoute.points.length < 2) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(pickupLatLng!, 16),
      );
      return;
    }

    final routePoints = finalRoute.points;

    double minLat = routePoints.first.latitude;
    double maxLat = routePoints.first.latitude;
    double minLng = routePoints.first.longitude;
    double maxLng = routePoints.first.longitude;

    for (LatLng point in routePoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    // Expand collapsed bounds to avoid Google Maps crash
    if ((maxLat - minLat).abs() < 0.0001) {
      minLat -= 0.0005;
      maxLat += 0.0005;
    }

    if ((maxLng - minLng).abs() < 0.0001) {
      minLng -= 0.0005;
      maxLng += 0.0005;
    }

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 80), 
      );
    } catch (e) {
      await Future.delayed(const Duration(milliseconds: 300));
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 80),
      );
    }
  }
  
  double _degreesToRadians(double degrees) {
    return degrees * Math.pi / 180;
  }

  double _radiansToDegrees(double radians) {
    return radians * 180 / Math.pi;
  }

  double calculateBearing(lat1, lon1, lat2, lon2) {
    lat1 = _degreesToRadians(lat1);
    lon1 = _degreesToRadians(lon1);
    lat2 = _degreesToRadians(lat2);
    lon2 = _degreesToRadians(lon2);

    double dLon = (lon2 - lon1);
    double y = Math.sin(dLon) * Math.cos(lat2);
    double x = Math.cos(lat1) * Math.sin(lat2) -
        Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLon);
    double brng = Math.atan2(y, x);
    
    brng = (_radiansToDegrees(brng) + 360) % 360;
    return brng;
  }


  // -------------------------------------------------------
  // BUILD METHOD
  // -------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Delivery Tracking"),
        backgroundColor: const Color(0xFF1A2B7B),
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(-15.4167, 28.2833),
          zoom: 12,
        ),
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
        },
        markers: markers,
        polylines: polylines,
        myLocationEnabled: false,
        zoomControlsEnabled: true,
      ),
    );
  }
}