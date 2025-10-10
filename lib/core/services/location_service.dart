import 'package:geolocator/geolocator.dart';
class LocationService {
  static Future<Position> current() async {
    LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.deniedForever) {
      throw 'Location permission permanently denied';
    }
    return await Geolocator.getCurrentPosition();
  }
}