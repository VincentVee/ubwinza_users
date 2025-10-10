import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../maps/nearby_drivers_view_model.dart';

class DriversMap extends StatelessWidget {
  final LatLng initial;
  final void Function(GoogleMapController) onCreated;
  const DriversMap({super.key, required this.initial, required this.onCreated});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NearbyDriversViewModel>();

    final markers = <Marker>{
      for (final d in vm.drivers)
        Marker(
          markerId: MarkerId(d.id),
          position: LatLng(d.latitude, d.longitude),
          infoWindow: InfoWindow(
            title: d.name.isEmpty ? (d.vehicleType == 'motorbike' ? 'Motorbike' : 'Bicycle') : d.name,
            snippet: d.vehicleType,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            d.vehicleType == 'motorbike' ? BitmapDescriptor.hueRed : BitmapDescriptor.hueGreen,
          ),
        ),
    };

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: initial, zoom: 13.5),
          onMapCreated: onCreated,
          markers: markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          compassEnabled: false,
          zoomControlsEnabled: false,
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(() =>
                EagerGestureRecognizer()),
          }
        ),
        if (vm.loading)
          const Positioned.fill(child: IgnorePointer(ignoring: true, child: Center(child: CircularProgressIndicator()))),
        if (vm.error != null)
          Positioned(
            left: 12, right: 12, top: 12,
            child: Material(
              color: Colors.red.withOpacity(.9),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(vm.error!, style: const TextStyle(color: Colors.white)),
              ),
            ),
          ),
      ],
    );
  }
}
