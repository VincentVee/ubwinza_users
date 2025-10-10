import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/models/driver_model.dart';

Marker createDriverMarker({
  required Driver driver,
  required bool isAccepted,
}) {
  return Marker(
    markerId: MarkerId('driver_${driver.id}'),
    position: LatLng(driver.latitude, driver.longitude),
    icon: isAccepted
        ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
        : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
    infoWindow: InfoWindow(
      title: driver.name,
      snippet: '${driver.vehicleType} - ${isAccepted ? 'Accepted' : 'Available'}',
    ),
    onTap: () {
      // Handle marker tap if needed
    },
  );
}