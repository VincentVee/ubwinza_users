
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

Position? position;
String googleApiKey = "AIzaSyC24a0-yk2HG6ONDtpbPRlL_lWkxeqqQ2Y";

List<Placemark>? placeMark;

String fullAddress = "";
SharedPreferences? sharedPreferences;

String get currentUserId => sharedPreferences?.getString("uid") ?? "";
String get currentUserEmail => sharedPreferences?.getString("email") ?? "";
String get currentUserName => sharedPreferences?.getString("name") ?? "";
String get currentUserImage => sharedPreferences?.getString("imageUrl") ?? "";
String get currentUserStatus => sharedPreferences?.getString("status") ?? "approved";
List<String> get currentUserCart => sharedPreferences?.getStringList("userCart") ?? ["garbageValue"];