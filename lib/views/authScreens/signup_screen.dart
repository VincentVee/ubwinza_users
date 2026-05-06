import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/termii_service.dart';
import '../../global/global_instances.dart';
import '../widgets/custom_text_field.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  XFile? imageFile;
  ImagePicker pickerImage = ImagePicker();

  TextEditingController nameTextEditingController = TextEditingController();
  TextEditingController phoneTextEditingController = TextEditingController();
  TextEditingController otpTextEditingController = TextEditingController();

  // OTP verification states
  bool _isOtpSent = false;
  bool _isLoading = false;
  String _pinId = '';
  String _errorMessage = '';
  int _resendTimer = 0;

  @override
  void dispose() {
    nameTextEditingController.dispose();
    phoneTextEditingController.dispose();
    otpTextEditingController.dispose();
    super.dispose();
  }

  pickImageFromGallery() async {
    imageFile = await pickerImage.pickImage(source: ImageSource.gallery);
    setState(() {
      imageFile;
    });
  }

  // Send OTP
  Future<void> _sendOTP() async {
    final phone = phoneTextEditingController.text.trim();

    if (phone.isEmpty) {
      setState(() => _errorMessage = 'Please enter your phone number');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await TermiiService.sendOTP(phone);

      if (response.containsKey('pinId')) {
        setState(() {
          _pinId = response['pinId'];
          _isOtpSent = true;
          _isLoading = false;
          _resendTimer = 60;
          _startResendTimer();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent successfully! Check your phone'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to send OTP';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error. Please check your connection.';
        _isLoading = false;
      });
    }
  }

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

  Future<void> _resendOTP() async {
    if (_resendTimer > 0) return;
    await _sendOTP();
  }

  // Verify OTP and register
  Future<void> _verifyOTPAndRegister() async {
    final otp = otpTextEditingController.text.trim();
    final name = nameTextEditingController.text.trim();

    if (otp.isEmpty) {
      setState(() => _errorMessage = 'Please enter the OTP');
      return;
    }

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your name');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await TermiiService.verifyOTP(_pinId, otp);

      if (response['verified'] == true || response['status'] == 'success') {
        // Register with phone number and name
        await authViewModel.registerWithPhone(
          imageFile,
          name,
          phoneTextEditingController.text.trim(),
          context,
        );
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Invalid OTP. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Verification failed: $e';
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

          const SizedBox(height: 96),

          // Name Field
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: CustomeTextField(
              textEditingController: nameTextEditingController,
              iconData: Icons.person_outlined,
              hintString: "Full Name",
              isObsecure: false,
              enable: true,
            ),
          ),
          const SizedBox(height: 16),

          // Phone Field
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: CustomeTextField(
                    textEditingController: phoneTextEditingController,
                    iconData: Icons.phone,
                    hintString: "Phone Number (e.g., 0977123456)",
                    isObsecure: false,
                    enable: !_isOtpSent,
                  ),
                ),
          // OTP Field (shown after sending)
          if (_isOtpSent) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: CustomeTextField(
                      textEditingController: otpTextEditingController,
                      iconData: Icons.security,
                      hintString: "Enter 6-digit OTP",
                      isObsecure: false,
                      enable: true,
                    ),
                  ),
                  if (_resendTimer > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        'Resend in ${_resendTimer}s',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: TextButton(
                        onPressed: _resendOTP,
                        child: const Text('Resend OTP'),
                      ),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Error Message
          if (_errorMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),

          const SizedBox(height: 16),

          // Sign Up Button
          ElevatedButton(
            onPressed: _isLoading
                ? null
                : _isOtpSent
                ? _verifyOTPAndRegister
                : _sendOTP,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              padding: const EdgeInsets.symmetric(vertical: 14),
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
                : Text(
              _isOtpSent ? 'Verify & Sign Up' : 'Send OTP',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}