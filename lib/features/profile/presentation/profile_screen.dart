import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Note: Ensure this import path is correct for your project structure
import 'package:ubwinza_users/view_models/auth_view_model.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // Define the common colors for clarity and reuse
  static const Color appPrimaryColor = Color(0xFF1A2B7B);
  static const Color accentColor = Color(0xFFFF5A3D);
  // User-specified Scaffold background color
  static const Color scaffoldBackgroundColor = Color(0xFF091342);

  @override
  Widget build(BuildContext context) {
    // Watch the AuthViewModel to get current user data
    final authViewModel = context.watch<AuthViewModel>();
    final user = authViewModel.getCurrentUser();

    // Default values if user is null or data is missing
    final String name = user?.name ?? 'Guest User';
    final String email = user?.email ?? 'N/A';
    final String imageUrl = user?.imageUrl ?? '';

    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,

      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: appPrimaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // -------------------
            // 1. Profile Picture (Editable via Icon Tap)
            // -------------------
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: imageUrl.isNotEmpty
                        ? NetworkImage(imageUrl)
                        : null,
                    child: imageUrl.isEmpty
                        ? const Icon(
                      Icons.person,
                      size: 60,
                      color: appPrimaryColor,
                    )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell( // Make camera icon tappable
                      onTap: () async {
                        await authViewModel.pickImageAndUpdate(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: accentColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // -------------------
            // 2. User Details (Name is editable)
            // -------------------
            _buildProfileDetailCard(
              icon: Icons.person_outline,
              label: 'Name',
              value: name,
              isEditable: true,
              onTap: () {
                _showEditNameDialog(context, authViewModel, name);
              },
            ),
            _buildProfileDetailCard(
              icon: Icons.email_outlined,
              label: 'Email',
              value: email,
              isEditable: false, // Not Editable
            ),
            _buildProfileDetailCard(
              icon: Icons.verified_user_outlined,
              label: 'Status',
              value: user?.status ?? 'Unknown',
              isEditable: false, // Not Editable
            ),

            const SizedBox(height: 32),

            // -------------------
            // 3. Action Buttons (Logout only)
            // -------------------
            // Removed the generic 'Edit Profile' button as edits are handled via cards/icon

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => authViewModel.logout(context),
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Logout'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper function to show a dialog for editing the user's name.
  void _showEditNameDialog(BuildContext context, AuthViewModel authViewModel, String currentName) {
    final TextEditingController nameController = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Color(0xFF1A2B7B),
          title: const Text('Edit Name'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: 'Enter new name'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty && newName != currentName) {
                  Navigator.of(dialogContext).pop();
                  // Call ViewModel function to update name
                  await authViewModel.updateUserName(newName, context);
                } else {
                  Navigator.of(dialogContext).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }


  /// Reusable widget for displaying profile details.
  Widget _buildProfileDetailCard({
    required IconData icon,
    required String label,
    required String value,
    bool isEditable = true, // Flag to control arrow/tap
    VoidCallback? onTap, // Action to take when tapped
  }) {
    return Card(
      elevation: 1,
      color: const Color(0xFFC3C4CA),
      margin: const EdgeInsets.only(bottom: 16),

      child: InkWell(
        onTap: isEditable ? onTap : null, // Only allow tap if editable

        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, color: appPrimaryColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              // Show the arrow icon ONLY if the field is editable
              if (isEditable)
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}