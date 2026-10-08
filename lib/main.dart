import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
// ------------------------------------

Future<void> main() async {
  // 1. Ensure Flutter binding is initialized first (CRUCIAL)
  WidgetsFlutterBinding.ensureInitialized();

  // =======================================================
  // *** FIX: Set Status Bar Style Globally ***
  // =======================================================
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // 2. Initialize platform/package dependencies
  await Firebase.initializeApp();
  sharedPreferences = await SharedPreferences.getInstance();

  // ⚠️ REMOVED: await prefs.clear();  // DO NOT CLEAR PREFERENCES ON APP START!

  // 3. Request location permission
  await Permission.locationWhenInUse.isDenied.then((valueOfPermission) {
    if (valueOfPermission) {
      Permission.locationWhenInUse.request();
    }
  });

  // 4. Initialize AppBootstrap
  await AppBootstrap.I.init(googleApiKey: googleApiKey);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => DeliveryProvider()),
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
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF8F9FF),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const MySplashScreen(),
    );
  }
}