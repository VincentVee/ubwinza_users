import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

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

  /// Returns list of maps like:
  /// [{'description': 'Lusaka, Zambia', 'place_id': 'xyz'}, ...]
  Future<List<Map<String, dynamic>>> fetchAutocomplete(
      String input, {
        String country = 'zm',
      }) async {
    final query = input.trim();
    if (query.isEmpty) return [];

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': query,
        'types': 'geocode',
        'components': 'country:$country',
        'key': apiKey,
      },
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

  /// Returns PlaceDetail with address + LatLng
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

  Future<List<PlaceSuggestion>> autocomplete(String input,
      {String country = 'zm'}) async {
    if (input.trim().isEmpty) return [];
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': input,
        'types': 'geocode',
        'components': 'country:$country',
        'key': apiKey,
      },
    );
    final r = await http.get(uri);
    final data = json.decode(r.body) as Map<String, dynamic>;
    final preds = (data['predictions'] as List?) ?? const [];
    return preds
        .map((p) => PlaceSuggestion(p['place_id'] as String, p['description'] as String))
        .toList();
  }
}
