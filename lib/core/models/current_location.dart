class CurrentLocation {
  final double lat, lng;
  const CurrentLocation(this.lat, this.lng);
}

/// TODO: Replace with your real LocationService.current()
Future<CurrentLocation> getCurrentLocation() async {
  // Lusaka (example)
  return const CurrentLocation(-15.4167, 28.2833);
}

