import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ubwinza_users/features/home/home_screen.dart';
import '../../global/global_instances.dart';
import '../../global/global_vars.dart';
import '../authScreens/auth_screen.dart';
import '../mainScreens/home_screen.dart';

class MySplashScreen extends StatefulWidget {
  const MySplashScreen({super.key});

  @override
  State<MySplashScreen> createState() => _MySplashScreenState();
}

class _MySplashScreenState extends State<MySplashScreen> {
  void startTimer() {
    Timer(const Duration(seconds: 3), () async {
      // Check if user data exists in SharedPreferences (your main auth system)
      final String? uid = sharedPreferences?.getString("uid");
      final String? name = sharedPreferences?.getString("name");
      final String? email = sharedPreferences?.getString("email");

      print('🔍 Splash Screen Check:');
      print('   UID from SharedPreferences: $uid');
      print('   Name from SharedPreferences: $name');
      print('   Email from SharedPreferences: $email');
      print('   Firebase User: ${FirebaseAuth.instance.currentUser?.uid}');

      if (uid != null && name != null && email != null) {
        // User data exists in SharedPreferences - navigate to home
        print('✅ Valid user data found, going to home screen');
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (c) => UserHomeScreen())
        );
      } else if (FirebaseAuth.instance.currentUser != null) {
        // Firebase has user but SharedPreferences doesn't - reload user data
        print('🔄 Firebase user found but no SharedPreferences data, reloading...');
        await _reloadUserData();
      } else {
        // No user data anywhere - go to auth screen
        print('❌ No user data found, going to auth screen');
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (c) => AuthScreen())
        );
      }
    });
  }

  Future<void> _reloadUserData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Use your auth view model to reload data from Firestore
        final success = await authViewModel.readDataFromFirestoreAndSetDataLocally(
            currentUser,
            context
        );

        if (success && mounted) {
          print('✅ User data reloaded successfully');
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (c) => UserHomeScreen())
          );
        } else {
          print('❌ Failed to reload user data');
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (c) => AuthScreen())
          );
        }
      }
    } catch (e) {
      print('❌ Error reloading user data: $e');
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (c) => AuthScreen())
      );
    }
  }

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Image.asset("images/welcome.png"),
            ),
            const Text(
              "Users App",
              textAlign: TextAlign.center,
              style: TextStyle(
                  letterSpacing: 3,
                  fontSize: 26,
                  color: Colors.grey
              ),
            )
          ],
        ),
      ),
    );
  }
}