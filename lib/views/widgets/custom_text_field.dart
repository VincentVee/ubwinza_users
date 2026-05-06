import 'package:flutter/material.dart';

class CustomeTextField extends StatefulWidget {
  final TextEditingController? textEditingController;
  final IconData? iconData;
  final String? hintString;
  final bool isObsecure; // Changed to non-nullable for cleaner code
  final bool enable;
  final TextInputType inputType;

  const CustomeTextField({
    super.key,
    this.textEditingController,
    this.iconData,
    this.hintString,
    this.isObsecure = false, // Default to false
    this.enable = true,
    this.inputType = TextInputType.text,
  });

  @override
  State<CustomeTextField> createState() => _CustomeTextFieldState();
}

class _CustomeTextFieldState extends State<CustomeTextField> {
  @override
  Widget build(BuildContext context) {
    return Container(
      // Margin to match the spacing in your PhoneLoginScreen
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5), // Light grey background
        borderRadius: BorderRadius.circular(16), // Rounded corners
      ),
      child: TextFormField(
        style: const TextStyle(
          color: Color(0xFF1A1A2E), // Dark text for readability
          fontSize: 15,
        ),
        enabled: widget.enable,
        controller: widget.textEditingController,
        obscureText: widget.isObsecure,
        keyboardType: widget.inputType,
        decoration: InputDecoration(
          // Removes the underline border
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,

          // Padding to keep text away from edges
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),

          prefixIcon: widget.iconData != null
              ? Icon(
            widget.iconData,
            color: const Color(0xFF6C63FF), // Professional Purple
            size: 22,
          )
              : null,

          hintText: widget.hintString,
          hintStyle: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}