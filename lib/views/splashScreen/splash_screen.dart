import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ubwinza_users/features/home/home_screen.dart';

import '../../global/global_instances.dart';
import '../../global/global_vars.dart';
import '../authScreens/auth_screen.dart';

class MySplashScreen extends StatefulWidget {
  const MySplashScreen({super.key});

  @override
  State<MySplashScreen> createState() => _MySplashScreenState();
}

class _MySplashScreenState extends State<MySplashScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    // 🔥 Animation setup
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fade = Tween<double>(begin: 0, end: 1).animate(_controller);
    _scale = Tween<double>(begin: 0.8, end: 1).animate(_controller);

    _controller.forward();

    startTimer();
  }

  void startTimer() {
    Timer(const Duration(seconds: 3), () async {
      final String? uid = sharedPreferences?.getString("uid");
      final String? name = sharedPreferences?.getString("name");
      final String? email = sharedPreferences?.getString("email");

      if (uid != null && name != null && email != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (c) => UserHomeScreen()),
        );
      } else if (FirebaseAuth.instance.currentUser != null) {
        await _reloadUserData();
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (c) => AuthScreen()),
        );
      }
    });
  }

  Future<void> _reloadUserData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        final success =
        await authViewModel.readDataFromFirestoreAndSetDataLocally(
          currentUser,
          context,
        );

        if (success && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (c) => UserHomeScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (c) => AuthScreen()),
          );
        }
      }
    } catch (e) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (c) => AuthScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A2B7B), // 🔥 brand color
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // 🔥 LOGO
                Image.asset(
                  "images/ubwinza_logo.png",
                  width: 140,
                ),

                const SizedBox(height: 20),

                // 🔥 APP NAME
                const Text(
                  "Ubwinza Users",
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                // 🔥 TAGLINE
                const Text(
                  "Smart • Seamless • Connected",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),

                const SizedBox(height: 30),

                // 🔄 LOADING INDICATOR
                const SizedBox(
                  width: 25,
                  height: 25,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}