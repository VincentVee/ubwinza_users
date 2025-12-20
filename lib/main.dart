import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubwinza_users/features/delivery/state/delivery_provider.dart';
import 'package:ubwinza_users/view_models/auth_view_model.dart';
import 'package:ubwinza_users/views/splashScreen/splash_screen.dart';

// --- Imports for the Location Fix ---
import 'core/bootstrap/app_bootstrap.dart';
import 'core/models/location_model.dart';
import 'features/food/state/cart_provider.dart';
import 'global/global_vars.dart';
// IMPORTANT: Add the missing LocationViewModel import
// ------------------------------------


Future<void> main() async {
  // 1. Ensure Flutter binding is initialized first (CRUCIAL)
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize platform/package dependencies
  await Firebase.initializeApp();
  sharedPreferences = await SharedPreferences.getInstance();

  // WARNING: Clearing all preferences here (`await prefs.clear();`)
  // will wipe all user settings, login tokens, etc., on every app launch.
  // This is usually only done during development or user logout.
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  sharedPreferences = prefs; // Assign the cleared instance

  // 3. Request location permission
  await Permission.locationWhenInUse.isDenied.then((valueOfPermission) {
    if (valueOfPermission) {
      Permission.locationWhenInUse.request();
    }
  });

  // 4. Initialize AppBootstrap
  // This must be done *before* the MultiProvider starts creating LocationViewModel,
  // as the ViewModel relies on AppBootstrap.I.places.
  await AppBootstrap.I.init(googleApiKey: googleApiKey);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => DeliveryProvider()),
        // =======================================================
        // *** FIX 1: Add LocationViewModel to the MultiProvider ***
        // =======================================================
        ChangeNotifierProvider(create: (_) => LocationViewModel()),
        ChangeNotifierProvider(create: (_) => AuthViewModel()),

      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ubwinza Users App',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const MySplashScreen(),
    );
  }
}