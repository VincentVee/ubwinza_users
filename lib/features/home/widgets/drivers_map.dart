import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../maps/nearby_drivers_view_model.dart';

class DriversMap extends StatefulWidget {
  final LatLng initial;
  final void Function(GoogleMapController) onCreated;

  const DriversMap({
    super.key,
    required this.initial,
    required this.onCreated,
  });

  @override
  State<DriversMap> createState() => _DriversMapState();
}

class _DriversMapState extends State<DriversMap> {
  MapType _mapType = MapType.normal;
  BitmapDescriptor? _bikeIcon;
  BitmapDescriptor? _bicycleIcon;

  @override
  void initState() {
    super.initState();
    _loadCustomIcons();
  }

  /// Resize and convert asset image to a smaller BitmapDescriptor
  Future<BitmapDescriptor> _resizeImage(String asset, int width) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    final frame = await codec.getNextFrame();
    final resized = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(resized!.buffer.asUint8List());
  }

  Future<void> _loadCustomIcons() async {
    final bike = await _resizeImage('images/motorbike.png', 280);   // smaller size
    final bicycle = await _resizeImage('images/bicycle.png', 290); // smaller size

    setState(() {
      _bikeIcon = bike;
      _bicycleIcon = bicycle;
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NearbyDriversViewModel>();

    if (_bikeIcon == null || _bicycleIcon == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final markers = <Marker>{
      for (final d in vm.drivers)
        Marker(
          markerId: MarkerId(d.id),
          position: LatLng(d.latitude, d.longitude),
          icon: d.vehicleType == 'motorbike' ? _bikeIcon! : _bicycleIcon!,
          infoWindow: InfoWindow(
            title: d.name.isEmpty
                ? (d.vehicleType == 'motorbike' ? 'Motorbike' : 'Bicycle')
                : d.name,
            snippet: d.vehicleType,
          ),
        ),
    };

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: widget.initial,
            zoom: 17.5, // deeper street view
            tilt: 60,   // stronger 3D angle
            bearing: 30,
          ),
          onMapCreated: widget.onCreated,
          mapType: _mapType,
          markers: markers,
          buildingsEnabled: true,
          trafficEnabled: true,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          compassEnabled: true,
          zoomControlsEnabled: false,
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
          },
        ),

        // Map type toggle button
        Positioned(
          top: 16,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: Colors.white,
            onPressed: () {
              setState(() {
                _mapType = _mapType == MapType.normal
                    ? MapType.hybrid
                    : MapType.normal;
              });
            },
            child: const Icon(Icons.map, color: Colors.black),
          ),
        ),

        if (vm.loading)
          const Center(child: CircularProgressIndicator()),

        if (vm.error != null)
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Material(
              color: Colors.red.withOpacity(.9),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  vm.error!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
