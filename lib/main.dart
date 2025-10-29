import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubwinza_users/features/delivery/state/delivery_provider.dart';
import 'package:ubwinza_users/features/home/home_screen.dart';
import 'package:ubwinza_users/views/splashScreen/splash_screen.dart';

import 'features/food/state/cart_provider.dart';
import 'global/global_vars.dart';


Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();
  sharedPreferences = await SharedPreferences.getInstance();
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  await Firebase.initializeApp();
 sharedPreferences = await SharedPreferences.getInstance();

  await Permission.locationWhenInUse.isDenied.then((valueOfPermission) {

    if(valueOfPermission) {
      Permission.locationWhenInUse.request();
    }
  });

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => CartProvider()),
      ChangeNotifierProvider(create: (_) => DeliveryProvider()), // Add this!

    ],
    child: const MyApp(),
  ),);
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
