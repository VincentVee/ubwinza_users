import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

// (Your PlaceSuggestion and PlaceDetail classes remain the same)
class PlaceSuggestion {
  final String placeId;
  final String description;
  PlaceSuggestion(this.placeId, this.description);
}

class PlaceDetail {
  final String address;
  final LatLng latLng;
  PlaceDetail(this.address, this.latLng);
}


class PlaceService {
  PlaceService(this.apiKey);
  final String apiKey;

  // You will need to store the user's location to bias the search.
  // We'll assume this setter is called when _me is available in PackageCreateScreen.
  LatLng? currentLocation;
  void setCurrentLocation(LatLng location) => currentLocation = location;

  /// Returns list of maps like:
  /// [{'description': 'Lusaka, Zambia', 'place_id': 'xyz'}, ...]
  Future<List<Map<String, dynamic>>> fetchAutocomplete(
      String input, {
        String country = 'zm',
      }) async {
    final query = input.trim();
    if (query.isEmpty) return [];

    final Map<String, dynamic> params = {
      'input': query,
      // Removed 'types': 'geocode' to allow POIs (Points of Interest)
      'components': 'country:$country',
      'key': apiKey,
    };

    // *** LOCATION BIAS ***
    // Bias results toward the user's current location if available.
    // NOTE: This uses 'location' and 'radius', which biases the results.
    if (currentLocation != null) {
      params['location'] = '${currentLocation!.latitude},${currentLocation!.longitude}';
      // Search within a 50km radius (in meters)
      params['radius'] = '50000';
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      params,
    );

    final r = await http.get(uri);
    if (r.statusCode != 200) return [];

    final data = jsonDecode(r.body) as Map<String, dynamic>;
    if ((data['status'] as String?) != 'OK') return [];

    final preds = (data['predictions'] as List?) ?? const [];
    return preds
        .map<Map<String, dynamic>>((p) => {
      'description': p['description'] ?? '',
      'place_id': p['place_id'] ?? '',
    })
        .where((m) => (m['description'] as String).isNotEmpty && (m['place_id'] as String).isNotEmpty)
        .toList();
  }

  /// Returns PlaceDetail with address + LatLng (remains unchanged)
  Future<PlaceDetail> detail(String placeId) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'fields': 'geometry/location,formatted_address',
        'key': apiKey,
      },
    );
    final r = await http.get(uri);
    if (r.statusCode != 200) {
      throw Exception('Place Details HTTP ${r.statusCode}');
    }
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    if ((data['status'] as String?) != 'OK') {
      throw Exception('Place Details ${data['status']} ${data['error_message'] ?? ''}');
    }

    final res = data['result'] as Map<String, dynamic>;
    final addr = (res['formatted_address'] as String?) ?? '';
    final loc = res['geometry']?['location'] as Map<String, dynamic>;
    final lat = (loc['lat'] as num).toDouble();
    final lng = (loc['lng'] as num).toDouble();
    return PlaceDetail(addr, LatLng(lat, lng));
  }

  // =========================================================
  // *** NEW: REVERSE GEOCODING METHOD ***
  // This is the method required by SimpleLocationPickerScreen to get
  // the address for the initialLocation (Latlng).
  // =========================================================
  Future<String> getReadableAddress(LatLng location) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {
        'latlng': '${location.latitude},${location.longitude}',
        'key': apiKey,
      },
    );

    final r = await http.get(uri);
    if (r.statusCode != 200) {
      throw Exception('Reverse Geocoding HTTP ${r.statusCode}');
    }

    final data = jsonDecode(r.body) as Map<String, dynamic>;
    if ((data['status'] as String?) != 'OK') {
      throw Exception('Reverse Geocoding ${data['status']} ${data['error_message'] ?? ''}');
    }

    // Geocoding API returns an array of results. We usually take the first one
    // (most precise/relevant).
    final results = (data['results'] as List?) ?? const [];

    if (results.isNotEmpty) {
      final firstResult = results.first as Map<String, dynamic>;
      final formattedAddress = firstResult['formatted_address'] as String?;
      return formattedAddress ?? 'Unknown Location';
    }

    throw Exception('No address found for these coordinates.');
  }
  // =========================================================

  // This method calls fetchAutocomplete, so it should also be updated.
  Future<List<PlaceSuggestion>> autocomplete(String input,
      {String country = 'zm'}) async {
    final results = await fetchAutocomplete(input, country: country);
    return results
        .map((p) => PlaceSuggestion(p['place_id'] as String, p['description'] as String))
        .toList();
  }
}