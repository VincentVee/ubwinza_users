import 'package:flutter/material.dart';
import '../../core/services/termii_service.dart';
import '../../global/global_instances.dart';
import '../../features/home/professional_home_screen.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _isLoading = false;
  bool _otpSent = false;
  String _pinId = '';
  String _errorMessage = '';
  int _resendTimer = 0;
  String _verifiedPhone = '';

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // Timer logic remains the same...
  void _startResendTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendTimer > 0) {
        setState(() {
          _resendTimer--;
          _startResendTimer();
        });
      }
    });
  }

  // Number formatting remains the same...
  String _formatPhoneNumber(String phone) {
    String cleaned = phone.trim().replaceAll(' ', '');
    if (cleaned.startsWith('+260')) {
      cleaned = cleaned.substring(4);
    } else if (cleaned.startsWith('260')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.length == 9) return '+260$cleaned';
    if (cleaned.length == 10 && cleaned.startsWith('0')) return '+260${cleaned.substring(1)}';
    return '+260$cleaned';
  }

  // API Methods remain the same...
  Future<void> _sendOTP() async { /* Your existing logic */ }
  Future<void> _verifyOTP() async { /* Your existing logic */ }
  void _resendOTP() async { if (_resendTimer > 0) return; await _sendOTP(); }

  @override
  Widget build(BuildContext context) {
    // REMOVED SafeArea and SingleChildScrollView from here
    // because the parent AuthScreen handles scrolling
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4), // Reduced padding since parent has it
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min, // Added to prevent taking infinite space
        children: [
          const SizedBox(height: 10),

          // Illustration (Slightly smaller to save space)
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.phone_android_rounded,
              size: 60,
              color: Color(0xFF6C63FF),
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Sign in with phone',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'We will send you a verification code',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),

          const SizedBox(height: 24),

          // Phone Input
          if (!_otpSent)
            _buildInputField(
              controller: _phoneController,
              hint: 'Phone number (e.g., 0977123456)',
              icon: Icons.phone_iphone_rounded,
              type: TextInputType.phone,
            ),

          // OTP Input
          if (_otpSent) ...[
            _buildOTPField(),
            const SizedBox(height: 12),
            Text(
              'Code sent to ${_phoneController.text}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],

          const SizedBox(height: 20),

          // Error Message
          if (_errorMessage.isNotEmpty) _buildErrorWidget(),

          // Single Action Button
          _buildActionButton(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInputField({required TextEditingController controller, required String hint, required IconData icon, required TextInputType type}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        keyboardType: type,
        enabled: !_isLoading,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFF6C63FF)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildOTPField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              enabled: !_isLoading,
              decoration: const InputDecoration(
                hintText: 'Enter 6-digit OTP',
                prefixIcon: Icon(Icons.security_rounded, color: Color(0xFF6C63FF)),
                border: InputBorder.none,
                counterText: '',
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ),
          _resendTimer > 0
              ? Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text('${_resendTimer}s', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          )
              : TextButton(onPressed: _resendOTP, child: const Text('Resend')),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.1)),
      ),
      child: Text(_errorMessage, style: const TextStyle(color: Colors.red, fontSize: 13), textAlign: TextAlign.center),
    );
  }

  Widget _buildActionButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : (_otpSent ? _verifyOTP : _sendOTP),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: _isLoading
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(_otpSent ? 'Verify & Login' : 'Send OTP', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }
}