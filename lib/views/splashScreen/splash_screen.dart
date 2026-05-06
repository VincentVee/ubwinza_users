import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubwinza_users/features/home/professional_home_screen.dart';

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

    // Animation setup
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
      // Check if user is logged in via SharedPreferences
      final String? uid = sharedPreferences?.getString("uid");
      final String? name = sharedPreferences?.getString("name");
      final String? phone = sharedPreferences?.getString("phone");


        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (c) => const ProfessionalHomeScreen()),
        );

      // if (uid != null && name != null && phone != null) {
      //   // User is logged in - go to home
      //   if (mounted) {
      //     Navigator.pushReplacement(
      //       context,
      //       MaterialPageRoute(builder: (c) => const ProfessionalHomeScreen()),
      //     );
      //   }
      // } else {
      //   // User not logged in - go to auth screen
      //   if (mounted) {
      //     Navigator.pushReplacement(
      //       context,
      //       MaterialPageRoute(builder: (c) => const AuthScreen()),
      //     );
      //   }
      //}
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A2B7B),
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  "images/ubwinza_logo.png",
                  width: 140,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.fastfood,
                        size: 60,
                        color: Colors.white,
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // App Name
                const Text(
                  "Ubwinza",
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                // Tagline
                const Text(
                  "Food & Delivery",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),

                const SizedBox(height: 30),

                // Loading Indicator
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