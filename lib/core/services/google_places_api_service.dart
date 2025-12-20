// lib/shared/services/google_places_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
// Note: This model should ideally be imported from the sheet or defined here
// if you prefer to keep service files independent.
// For this structure, we'll assume PlaceSuggestion is accessible/defined.

// --- API Key ---
// ⚠️ IMPORTANT: Using the key you provided. This should be secured in a real app.
const String _googleApiKey = "AIzaSyC24a0-yk2HG6ONDtpbPRlL_lWkxeqqQ2Y";
const String _baseUrl = "https://maps.googleapis.com/maps/api/place";

// --- Data Model Dependency (Re-defined for service independence) ---
class PlaceSuggestion {
  final String description;
  final String placeId;
  PlaceSuggestion({required this.description, required this.placeId});
}
// -------------------------------------------------------------------

class GooglePlacesApiService {

  /// Fetches place suggestions using the Google Places Autocomplete API.
  static Future<List<PlaceSuggestion>> fetchPlaceSuggestions(String input) async {
    if (input.length < 3) return [];

    // Restrict to Zambia (components=country:zm)
    final url = Uri.parse(
        '$_baseUrl/autocomplete/json?input=$input&key=$_googleApiKey&language=en&components=country:zm');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final List predictions = data['predictions'];
          return predictions.map((p) =>
              PlaceSuggestion(
                  description: p['description'] ?? "Unknown Location",
                  placeId: p['place_id'] ?? ""
              )).toList();
        } else {
          print("Places Autocomplete API Status Error: ${data['status']}");
          return [];
        }
      } else {
        print("HTTP Error: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Places Autocomplete Exception: $e");
      return [];
    }
  }

  /// Fetches LatLng coordinates from the Place ID using the Google Places Details API.
  static Future<LatLng?> getCoordinatesFromPlaceId(String placeId) async {
    if (placeId.isEmpty) return null;

    final url = Uri.parse(
        '$_baseUrl/details/json?place_id=$placeId&fields=geometry/location&key=$_googleApiKey');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['result'] != null) {
          final location = data['result']['geometry']['location'];
          return LatLng(location['lat'], location['lng']);
        } else {
          print("Places Details API Status Error: ${data['status']}");
          return null;
        }
      } else {
        print("HTTP Error: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Places Details Exception: $e");
      return null;
    }
  }
}