import 'package:flutter/material.dart';
import '../../global/global_instances.dart';
import '../widgets/custom_text_field.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  TextEditingController emailController = TextEditingController();
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();
  TextEditingController phoneController = TextEditingController();

  // Validation states
  bool _isEmailAvailable = true;
  bool _isUsernameAvailable = true;
  bool _checkingEmail = false;
  bool _checkingUsername = false;

  bool _isLoading = false;
  String _errorMessage = '';

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    emailController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _checkEmailAvailability() async {
    final email = emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _isEmailAvailable = true;
        _checkingEmail = false;
      });
      return;
    }

    setState(() {
      _checkingEmail = true;
    });

    final isTaken = await authViewModel.isEmailTaken(email);

    setState(() {
      _isEmailAvailable = !isTaken;
      _checkingEmail = false;
    });
  }

  Future<void> _checkUsernameAvailability() async {
    final username = usernameController.text.trim();
    if (username.isEmpty) {
      setState(() {
        _isUsernameAvailable = true;
        _checkingUsername = false;
      });
      return;
    }

    setState(() {
      _checkingUsername = true;
    });

    final isTaken = await authViewModel.isUsernameTaken(username);

    setState(() {
      _isUsernameAvailable = !isTaken;
      _checkingUsername = false;
    });
  }

  Future<void> _signUp() async {
    final email = emailController.text.trim();
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();
    final phone = phoneController.text.trim();

    // Validate all fields
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email');
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }

    if (!_isEmailAvailable) {
      setState(() => _errorMessage = 'Email already registered');
      return;
    }

    if (username.isEmpty) {
      setState(() => _errorMessage = 'Please enter a username');
      return;
    }

    if (!_isUsernameAvailable) {
      setState(() => _errorMessage = 'Username already taken');
      return;
    }

    if (phone.isEmpty) {
      setState(() => _errorMessage = 'Please enter your phone number');
      return;
    }

    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter a password');
      return;
    }

    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }

    if (password != confirmPassword) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await authViewModel.registerWithEmailPassword(
        email,
        username,
        password,
        phone,
        context,
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Registration failed: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),

          // Icon
          // Container(
          //   height: 120,
          //   decoration: BoxDecoration(
          //     color: const Color(0xFFF5F5F5),
          //     borderRadius: BorderRadius.circular(20),
          //   ),
          //   child: const Icon(
          //     Icons.person_add,
          //     size: 70,
          //     color: Color(0xFF6C63FF),
          //   ),
          // ),

          const SizedBox(height: 32),

          const Text(
            'Create Account',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sign up to get started',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),

          const SizedBox(height: 32),

          // Email Field
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              controller: emailController,
              onChanged: (_) => _checkEmailAvailability(),
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'Email Address',
                prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF6C63FF)),
                suffixIcon: _checkingEmail
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
                    : (emailController.text.isNotEmpty
                    ? Icon(
                  _isEmailAvailable ? Icons.check_circle : Icons.cancel,
                  color: _isEmailAvailable ? Colors.green : Colors.red,
                )
                    : null),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ),

          if (emailController.text.isNotEmpty && !_checkingEmail)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: Text(
                _isEmailAvailable ? 'Email available' : 'Email already registered',
                style: TextStyle(
                  fontSize: 12,
                  color: _isEmailAvailable ? Colors.green : Colors.red,
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Username Field
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              controller: usernameController,
              onChanged: (_) => _checkUsernameAvailability(),
              decoration: InputDecoration(
                hintText: 'Username',
                prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF6C63FF)),
                suffixIcon: _checkingUsername
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
                    : (usernameController.text.isNotEmpty
                    ? Icon(
                  _isUsernameAvailable ? Icons.check_circle : Icons.cancel,
                  color: _isUsernameAvailable ? Colors.green : Colors.red,
                )
                    : null),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ),

          if (usernameController.text.isNotEmpty && !_checkingUsername)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: Text(
                _isUsernameAvailable ? 'Username available' : 'Username already taken',
                style: TextStyle(
                  fontSize: 12,
                  color: _isUsernameAvailable ? Colors.green : Colors.red,
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Phone Field
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: 'Phone Number (e.g., 0977123456)',
                prefixIcon: Icon(Icons.phone, color: Color(0xFF6C63FF)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Color(0xFFF5F5F5),
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Password Field
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              alignment: Alignment.centerRight,
              children: [
                TextField(
                  controller: passwordController,
                  obscureText: _obscurePassword,
                  decoration: const InputDecoration(
                    hintText: 'Password (min. 6 characters)',
                    prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF6C63FF)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Color(0xFFF5F5F5),
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
                Positioned(
                  right: 16,
                  child: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Confirm Password Field
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              alignment: Alignment.centerRight,
              children: [
                TextField(
                  controller: confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: const InputDecoration(
                    hintText: 'Confirm Password',
                    prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF6C63FF)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Color(0xFFF5F5F5),
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
                Positioned(
                  right: 16,
                  child: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Error Message
          if (_errorMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),

          // Sign Up Button
          ElevatedButton(
            onPressed: _isLoading ? null : _signUp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Text(
              'Sign Up',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white
              ),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}