import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_storage/firebase_storage.dart' as fs_store;
import 'package:ubwinza_users/features/home/professional_home_screen.dart';
import 'package:ubwinza_users/views/splashScreen/splash_screen.dart';

import '../core/bootstrap/app_bootstrap.dart';
import '../global/global_instances.dart';
import '../global/global_vars.dart';
import '../core/models/user_model.dart';

class AuthViewModel extends ChangeNotifier {

  void _log(String message, {String type = 'INFO'}) {
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('🕒 [$timestamp] 🔐 AUTH_$type: $message');
  }

  Future<void> _debugSharedPreferences() async {
    try {
      _log('=== SHARED_PREFERENCES DEBUG ===');
      final allKeys = sharedPreferences?.getKeys() ?? <String>{};
      _log('Total keys in SharedPreferences: ${allKeys.length}');

      for (String key in allKeys) {
        final value = sharedPreferences?.get(key);
        _log('  $key: $value');
      }
      _log('=== END SHARED_PREFERENCES DEBUG ===');
    } catch (e) {
      _log('Error debugging SharedPreferences: $e', type: 'ERROR');
    }
  }

  // =========================================================
  // HELPER: Format Phone Number
  // =========================================================

  String _formatPhoneNumber(String phone) {
    String cleaned = phone.trim().replaceAll(' ', '');
    if (cleaned.startsWith('+260')) {
      cleaned = cleaned.substring(4);
    } else if (cleaned.startsWith('260')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.length == 9) {
      return '+260$cleaned';
    } else if (cleaned.length == 10 && cleaned.startsWith('0')) {
      return '+260${cleaned.substring(1)}';
    }
    return '+260$cleaned';
  }

  // Update User Name
  Future<void> updateUserName(String newName, BuildContext context) async {
    if (sharedPreferences == null || sharedPreferences!.getString("uid") == null) {
      commonViewModel.showSnackBar("User not logged in.", context);
      return;
    }

    commonViewModel.showSnackBar("Updating profile name...", context);

    try {
      final String uid = sharedPreferences!.getString("uid")!;

      await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .update({"name": newName});

      _log('Name updated in Firestore to: $newName');
      await sharedPreferences!.setString("name", newName);
      notifyListeners();
      commonViewModel.showSnackBar("Name updated successfully!", context);

    } on FirebaseException catch (e) {
      commonViewModel.showSnackBar("Failed to update name: ${e.message}", context);
    } catch (e) {
      commonViewModel.showSnackBar("An unexpected error occurred: $e", context);
    }
  }

  // Update Profile Image
  Future<void> pickImageAndUpdate(BuildContext context) async {
    if (sharedPreferences == null || sharedPreferences!.getString("uid") == null) {
      commonViewModel.showSnackBar("User not logged in.", context);
      return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) {
      commonViewModel.showSnackBar("Image selection cancelled.", context);
      return;
    }

    commonViewModel.showSnackBar("Uploading new profile image...", context);

    try {
      final String uid = sharedPreferences!.getString("uid")!;
      final String newImageUrl = await uploadImageToFirebase(pickedFile);
      _log('Image successfully uploaded. URL: $newImageUrl');

      await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .update({"imageUrl": newImageUrl});

      await sharedPreferences!.setString("imageUrl", newImageUrl);
      notifyListeners();
      commonViewModel.showSnackBar("Profile image updated successfully!", context);

    } on Exception catch (e) {
      commonViewModel.showSnackBar("Failed to update image: ${e.toString()}", context);
    }
  }

  // =========================================================
  // SIMPLE PHONE REGISTRATION (No Password)
  // =========================================================

  Future<void> registerWithPhone(
      XFile? image,
      String name,
      String phone,
      BuildContext context,
      ) async {
    if (name.isEmpty || phone.isEmpty) {
      commonViewModel.showSnackBar("Please enter name and phone number!", context);
      return;
    }

    commonViewModel.showSnackBar("Creating your account...", context);

    try {
      String downloadUrl = "";
      if (image != null) {
        downloadUrl = await uploadImageToFirebase(image);
      }

      final String userId = DateTime.now().millisecondsSinceEpoch.toString();
      final String formattedPhone = _formatPhoneNumber(phone);

      final userModel = UserModel(
        uid: userId,
        email: "$formattedPhone@ubwinza.com",
        name: name,
        imageUrl: downloadUrl,
        phone: formattedPhone,
        status: "approved",
        userCart: ["garbageValue"],
      );

      await FirebaseFirestore.instance
          .collection("users")
          .doc(userId)
          .set(userModel.toFirestore());

      await sharedPreferences!.setString("uid", userModel.uid);
      await sharedPreferences!.setString("email", userModel.email);
      await sharedPreferences!.setString("name", userModel.name);
      await sharedPreferences!.setString("imageUrl", userModel.imageUrl);
      await sharedPreferences!.setString("status", userModel.status);
      await sharedPreferences!.setStringList("userCart", userModel.userCart);
      await sharedPreferences!.setString("phone", userModel.phone??'');

      _log('✅ User registered successfully: $name, $formattedPhone');

      if (context.mounted) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ProfessionalHomeScreen())
        );
        commonViewModel.showSnackBar("Account created successfully!", context);
      }
    } catch (e) {
      commonViewModel.showSnackBar("Registration failed: $e", context);
    }
  }

  // =========================================================
  // SIMPLE PHONE LOGIN (No Password)
  // =========================================================

  Future<bool> loginWithPhone(String phone, BuildContext context) async {
    final formattedPhone = _formatPhoneNumber(phone);

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: formattedPhone)
          .get();

      if (query.docs.isNotEmpty) {
        final userData = query.docs.first;

        await sharedPreferences!.setString("uid", userData['uid']);
        await sharedPreferences!.setString("email", userData['email'] ?? '');
        await sharedPreferences!.setString("name", userData['name'] ?? '');
        await sharedPreferences!.setString("imageUrl", userData['imageUrl'] ?? '');
        await sharedPreferences!.setString("status", userData['status'] ?? 'approved');
        await sharedPreferences!.setString("phone", userData['phone'] ?? '');

        _log('✅ User logged in: ${userData['name']}, $formattedPhone');
        return true;
      }
      return false;
    } catch (e) {
      _log('Login error: $e', type: 'ERROR');
      return false;
    }
  }

  // =========================================================
  // REGISTER WITH EMAIL, USERNAME, PASSWORD AND PHONE
  // =========================================================

  Future<void> registerWithEmailPassword(
      String email,
      String username,
      String password,
      String phone,
      BuildContext context,
      ) async {
    if (email.isEmpty || username.isEmpty || password.isEmpty || phone.isEmpty) {
      commonViewModel.showSnackBar("Please fill all fields!", context);
      return;
    }

    if (password.length < 6) {
      commonViewModel.showSnackBar("Password must be at least 6 characters!", context);
      return;
    }

    commonViewModel.showSnackBar("Creating your account...", context);

    try {
      final String userId = DateTime.now().millisecondsSinceEpoch.toString();
      final String formattedPhone = _formatPhoneNumber(phone);
      final String formattedEmail = email.trim().toLowerCase();
      final String formattedUsername = username.trim().toLowerCase();

      // Create UserModel instance
      final userModel = UserModel(
        uid: userId,
        email: formattedEmail,
        name: username.trim(),
        imageUrl: "",
        status: "approved",
        userCart: ["garbageValue"],
        phone: formattedPhone,
        address: null,
        username: formattedUsername,
      );

      // Store in Firestore with password (⚠️ In production, hash this password!)
      final userData = userModel.toFirestore();
      userData['password'] = password; // Add password field
      userData['username'] = formattedUsername; // Ensure username is saved

      await FirebaseFirestore.instance
          .collection("users")
          .doc(userId)
          .set(userData);

      // Save to SharedPreferences
      await sharedPreferences!.setString("uid", userModel.uid);
      await sharedPreferences!.setString("email", userModel.email);
      await sharedPreferences!.setString("name", userModel.name);
      await sharedPreferences!.setString("username", formattedUsername);
      await sharedPreferences!.setString("imageUrl", userModel.imageUrl);
      await sharedPreferences!.setString("status", userModel.status);
      await sharedPreferences!.setStringList("userCart", userModel.userCart);
      await sharedPreferences!.setString("phone", userModel.phone ?? '');
      if (userModel.address != null) {
        await sharedPreferences!.setString("address", userModel.address!);
      }

      _log('✅ User registered successfully: $username, $formattedEmail');

      if (context.mounted) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ProfessionalHomeScreen())
        );
        commonViewModel.showSnackBar("Account created successfully!", context);
      }
    } catch (e) {
      commonViewModel.showSnackBar("Registration failed: $e", context);
      _log('Registration error: $e', type: 'ERROR');
    }
  }

  // =========================================================
  // LOGIN WITH EMAIL OR USERNAME AND PASSWORD
  // =========================================================

  Future<void> validateSignInForm(
      String emailOrUsername,
      String password,
      BuildContext context,
      ) async {
    if (emailOrUsername.isEmpty || password.isEmpty) {
      commonViewModel.showSnackBar("Please enter email/username and password!", context);
      return;
    }

    try {
      QuerySnapshot query;

      // Check if input is email (contains @) or username
      if (emailOrUsername.contains('@')) {
        // Login with email
        _log('Attempting login with email: $emailOrUsername');
        query = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: emailOrUsername.trim().toLowerCase())
            .get();
      } else {
        // Login with username
        _log('Attempting login with username: $emailOrUsername');
        query = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: emailOrUsername.trim().toLowerCase())
            .get();
      }

      if (query.docs.isEmpty) {
        _log('No account found for: $emailOrUsername', type: 'WARNING');
        commonViewModel.showSnackBar("Account not found!", context);
        return;
      }

      final userDoc = query.docs.first;
      final userData = userDoc.data() as Map<String, dynamic>;
      final storedPassword = userData['password'] as String?;

      // Simple password comparison (⚠️ In production, use hashed password comparison!)
      if (storedPassword == null || storedPassword != password) {
        _log('Incorrect password for: $emailOrUsername', type: 'WARNING');
        commonViewModel.showSnackBar("Incorrect password!", context);
        return;
      }

      // Create UserModel from Firestore data
      final userModel = UserModel.fromFirestore(userDoc);

      // Save user data to SharedPreferences
      await sharedPreferences!.setString("uid", userModel.uid);
      await sharedPreferences!.setString("email", userModel.email);
      await sharedPreferences!.setString("name", userModel.name);
      await sharedPreferences!.setString("username", userData['username'] ?? '');
      await sharedPreferences!.setString("imageUrl", userModel.imageUrl);
      await sharedPreferences!.setString("status", userModel.status);
      await sharedPreferences!.setStringList("userCart", userModel.userCart);
      await sharedPreferences!.setString("phone", userModel.phone ?? '');
      if (userModel.address != null) {
        await sharedPreferences!.setString("address", userModel.address!);
      }

      _log('✅ User logged in successfully: ${userModel.name} (${userModel.email})');

      if (context.mounted) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ProfessionalHomeScreen())
        );
        commonViewModel.showSnackBar("Login successful! Welcome back ${userModel.name}", context);
      }
    } catch (e) {
      _log('Login error: $e', type: 'ERROR');
      commonViewModel.showSnackBar("Login failed: $e", context);
    }
  }

  // =========================================================
  // CHECK IF EMAIL IS TAKEN
  // =========================================================

  Future<bool> isEmailTaken(String email) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      _log('Error checking email: $e', type: 'ERROR');
      return false;
    }
  }

  // =========================================================
  // CHECK IF USERNAME IS TAKEN
  // =========================================================

  Future<bool> isUsernameTaken(String username) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username.trim().toLowerCase())
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      _log('Error checking username: $e', type: 'ERROR');
      return false;
    }
  }

  // =========================================================
  // UPDATE USERNAME (Optional utility method)
  // =========================================================

  Future<void> updateUsername(String newUsername, BuildContext context) async {
    if (sharedPreferences == null || sharedPreferences!.getString("uid") == null) {
      commonViewModel.showSnackBar("User not logged in.", context);
      return;
    }

    final String uid = sharedPreferences!.getString("uid")!;
    final String formattedUsername = newUsername.trim().toLowerCase();

    // Check if username is taken
    final isTaken = await isUsernameTaken(formattedUsername);
    if (isTaken) {
      commonViewModel.showSnackBar("Username already taken!", context);
      return;
    }

    commonViewModel.showSnackBar("Updating username...", context);

    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .update({"username": formattedUsername});

      await sharedPreferences!.setString("username", formattedUsername);

      // Notify listeners to update UI
      notifyListeners();

      commonViewModel.showSnackBar("Username updated successfully!", context);
      _log('Username updated to: $formattedUsername');
    } catch (e) {
      commonViewModel.showSnackBar("Failed to update username: $e", context);
      _log('Error updating username: $e', type: 'ERROR');
    }
  }

  // =========================================================
  // GET CURRENT USER AS USERMODEL
  // =========================================================

  UserModel? getCurrentUserModel() {
    try {
      final String? uid = sharedPreferences?.getString("uid");
      final String? email = sharedPreferences?.getString("email");
      final String? name = sharedPreferences?.getString("name");
      final String? username = sharedPreferences?.getString("username");
      final String? imageUrl = sharedPreferences?.getString("imageUrl");
      final String? status = sharedPreferences?.getString("status");
      final String? phone = sharedPreferences?.getString("phone");
      final String? address = sharedPreferences?.getString("address");
      final List<String>? userCart = sharedPreferences?.getStringList("userCart");

      if (uid == null || name == null) {
        return null;
      }

      return UserModel(
        uid: uid,
        email: email ?? '',
        name: name,
        imageUrl: imageUrl ?? '',
        status: status ?? 'approved',
        userCart: userCart ?? ['garbageValue'],
        phone: phone,
        address: address,
        username: username,
      );
    } catch (e) {
      _log('Error getting current user: $e', type: 'ERROR');
      return null;
    }
  }

  Future<String> uploadImageToFirebase(XFile image) async {
    try {
      final String fileName = DateTime.now().microsecondsSinceEpoch.toString();
      final fs_store.Reference ref = fs_store.FirebaseStorage.instance
          .ref()
          .child('usersimages/$fileName');

      final fs_store.UploadTask task = ref.putFile(File(image.path));
      final fs_store.TaskSnapshot snap = await task;
      return await snap.ref.getDownloadURL();
    } catch (e) {
      rethrow;
    }
  }

  // Helper method to get current user from SharedPreferences
  UserModel? getCurrentUser() {
    try {
      final String? uid = sharedPreferences?.getString("uid");
      final String? email = sharedPreferences?.getString("email");
      final String? name = sharedPreferences?.getString("name");
      final String? imageUrl = sharedPreferences?.getString("imageUrl");
      final String? status = sharedPreferences?.getString("status");
      final String? phone = sharedPreferences?.getString("phone");
      final List<String>? userCart = sharedPreferences?.getStringList("userCart");

      if (uid == null || name == null) {
        return null;
      }

      return UserModel(
        uid: uid,
        email: email ?? '',
        name: name,
        imageUrl: imageUrl ?? '',
        status: status ?? 'approved',
        phone: phone ?? '',
        userCart: userCart ?? ['garbageValue'],
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> logout(BuildContext context) async {
    try {
      _log('🚪 Logging out user');
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await AppBootstrap.I.reset();
      _log('✅ Logout successful, local state cleared');

      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MySplashScreen()),
            (_) => false,
      );
    } catch (e) {
      _log('❌ Logout failed: $e', type: 'ERROR');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logout failed. Please try again.')),
        );
      }
    }
  }
}