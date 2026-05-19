import 'package:flutter/material.dart';
import 'package:ubwinza_users/views/authScreens/phone_login.dart';
import 'package:ubwinza_users/views/authScreens/signin_screen.dart';
import '../../features/home/professional_home_screen.dart';
import 'signup_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      // Keep this true to allow the viewport to shrink for the keyboard
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6C63FF),
              Color(0xFF3F3D9E),
              Color(0xFF16213E),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  const SizedBox(height: 50),
                  _buildHeader(),
                  const SizedBox(height: 30),
                  _buildTabArea(),

                  // Main Content Card
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(40),
                          topRight: Radius.circular(40),
                        ),
                      ),
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildFormWrapper(const SignInScreen(), keyboardHeight),
                          _buildFormWrapper(const SignupScreen(), keyboardHeight),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Navigation Arrow
              Positioned(
                top: 10,
                left: 10,
                child: IconButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfessionalHomeScreen()),
                  ),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormWrapper(Widget child, double keyboardHeight) {
    return SingleChildScrollView(
      // physics: ClampingScrollPhysics() ensures it doesn't "bounce" and get stuck
      physics: const ClampingScrollPhysics(),
      // Add padding at the bottom only when keyboard is up to lift the button
      padding: EdgeInsets.fromLTRB(20, 30, 20, keyboardHeight > 0 ? 20 : 50),
      child: child,
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
          ),
          child: const Icon(Icons.fastfood_rounded, size: 40, color: Colors.white),
        ),
        const SizedBox(height: 12),
        const Text(
          'UBWINZA',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2),
        ),
      ],
    );
  }

  Widget _buildTabArea() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 45, vertical: 10),
      height: 45,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.15),
        borderRadius: BorderRadius.circular(25),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
        ),
        labelColor: const Color(0xFF3F3D9E),
        unselectedLabelColor: Colors.white60,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        tabs: const [
          Tab(text: "LOGIN"),
          Tab(text: "SIGN UP"),
        ],
      ),
    );
  }
}