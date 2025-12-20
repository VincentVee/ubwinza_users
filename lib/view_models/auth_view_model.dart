import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // REQUIRED for ChangeNotifier and BuildContext
import 'package:image_picker/image_picker.dart'; // REQUIRED for image picking
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_storage/firebase_storage.dart' as fs_store;
import 'package:ubwinza_users/features/home/home_screen.dart';
import 'package:ubwinza_users/views/splashScreen/splash_screen.dart';

import '../core/bootstrap/app_bootstrap.dart';
import '../global/global_instances.dart';
import '../global/global_vars.dart';
import '../views/mainScreens/home_screen.dart';
import '../core/models/user_model.dart';

// FIX: Ensure this class extends ChangeNotifier to work with the Provider package
class AuthViewModel extends ChangeNotifier {

  // Enhanced debug logging method
  void _log(String message, {String type = 'INFO'}) {
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('🕒 [$timestamp] 🔐 AUTH_$type: $message');
  }

  // Debug SharedPreferences state
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
  // 💡 EDIT LOGIC 1: Update User Name (ADDED)
  // =========================================================
  Future<void> updateUserName(String newName, BuildContext context) async {
    if (sharedPreferences == null || sharedPreferences!.getString("uid") == null) {
      commonViewModel.showSnackBar("User not logged in.", context);
      return;
    }

    commonViewModel.showSnackBar("Updating profile name...", context);

    try {
      final String uid = sharedPreferences!.getString("uid")!;

      // 1. Update Firestore
      await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .update({"name": newName});

      _log('Name updated in Firestore to: $newName');

      // 2. Update SharedPreferences (Local State)
      await sharedPreferences!.setString("name", newName);

      // 3. Notify listeners to update the UI (ProfileScreen will react)
      notifyListeners();

      commonViewModel.showSnackBar("Name updated successfully!", context);

    } on FirebaseException catch (e) {
      commonViewModel.showSnackBar("Failed to update name: ${e.message}", context);
    } catch (e) {
      commonViewModel.showSnackBar("An unexpected error occurred: $e", context);
    }
  }

  // =========================================================
  // 💡 EDIT LOGIC 2: Update Profile Image (ADDED)
  // =========================================================
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

      // 1. Upload new image to Firebase Storage
      final String newImageUrl = await uploadImageToFirebase(pickedFile);
      _log('Image successfully uploaded. URL: $newImageUrl');

      // 2. Update Firestore
      await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .update({"imageUrl": newImageUrl});

      // 3. Update SharedPreferences (Local State)
      await sharedPreferences!.setString("imageUrl", newImageUrl);

      // 4. Notify listeners to update the UI
      notifyListeners();

      commonViewModel.showSnackBar("Profile image updated successfully!", context);

    } on Exception catch (e) {
      commonViewModel.showSnackBar("Failed to update image: ${e.toString()}", context);
    }
  }

  // =========================================================
  // EXISTING SIGN UP METHODS
  // =========================================================

  Future<void> validateSignUpForm(
      XFile? image,
      String password,
      String confirm,
      String email,
      String name,
      String phone,
      BuildContext context,
      ) async {

    if (image == null) {
      commonViewModel.showSnackBar("Please select the image from gallery", context);
      return;
    }

    if (password != confirm) {
      commonViewModel.showSnackBar("Password and confirmation do not match!", context);
      return;
    }

    if (password.isEmpty || confirm.isEmpty || email.isEmpty || name.isEmpty || phone.isEmpty) {
      commonViewModel.showSnackBar("Please enter all the fields!", context);
      return;
    }

    commonViewModel.showSnackBar("Please wait...", context);

    final fb_auth.User? currentUser = await createUserInFirebase(email, password, context);

    if (currentUser == null) {
      fb_auth.FirebaseAuth.instance.signOut();
      return;
    }

    final String downloadUrl = await uploadImageToFirebase(image);

    final ok = await saveUserToFireStore(
      currentUser: currentUser,
      downloadUrl: downloadUrl,
      email: email,
      name: name,
      phone: phone,
      context: context,
    );

    if (!ok) {
      _log('❌ Failed to save user to Firestore', type: 'ERROR');
      return;
    }

    _log('✅ User saved successfully, navigating to home screen');

    if (context.mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => UserHomeScreen()));
      commonViewModel.showSnackBar("Account created successfully", context);
    }

    _log('=== SIGN UP COMPLETED SUCCESSFULLY ===');
  }

  Future<fb_auth.User?> createUserInFirebase(
      String email,
      String password,
      BuildContext context,
      ) async {
    try {
      final cred = await fb_auth.FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      return cred.user;
    } on fb_auth.FirebaseAuthException catch (e) {
      commonViewModel.showSnackBar(e.message ?? e.code, context);
      return null;
    } catch (e) {
      commonViewModel.showSnackBar(e.toString(), context);
      return null;
    }
  }

  // Reused by pickImageAndUpdate for profile image update
  Future<String> uploadImageToFirebase(XFile image) async {
    _log('Starting image upload...');
    _log('Image path: ${image.path}, name: ${image.name}');

    try {
      final String fileName = DateTime.now().microsecondsSinceEpoch.toString();
      final fs_store.Reference ref = fs_store.FirebaseStorage.instance
          .ref()
          .child('usersimages/$fileName');

      _log('Uploading to path: usersimages/$fileName');

      final fs_store.UploadTask task = ref.putFile(File(image.path));
      final fs_store.TaskSnapshot snap = await task;

      final String url = await snap.ref.getDownloadURL();

      return url;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> saveUserToFireStore({
    required fb_auth.User currentUser,
    required String downloadUrl,
    required String email,
    required String name,
    required String phone,
    required BuildContext context
  }) async {

    try {
      final userModel = UserModel(
        uid: currentUser.uid,
        email: email,
        name: name,
        imageUrl: downloadUrl,
        phone: phone,
        status: "approved",
        userCart: ["garbageValue"],
      );


      await FirebaseFirestore.instance
          .collection("users")
          .doc(currentUser.uid)
          .set(userModel.toFirestore());
      // Save to SharedPreferences using individual keys (more reliable)
      await sharedPreferences!.setString("uid", userModel.uid);
      await sharedPreferences!.setString("email", userModel.email);
      await sharedPreferences!.setString("name", userModel.name);
      await sharedPreferences!.setString("imageUrl", userModel.imageUrl);
      await sharedPreferences!.setString("status", userModel.status);
      await sharedPreferences!.setStringList("userCart", userModel.userCart);
      await sharedPreferences!.setString("phone", userModel.phone??'');

      await _debugSharedPreferences();

      return true;
    } on FirebaseException catch (e) {
      commonViewModel.showSnackBar(
        "Firestore error: ${e.message ?? e.code}",
        context,
      );
      return false;
    } catch (e) {
      commonViewModel.showSnackBar("Error: ${e.toString()}", context);
      return false;
    }
  }

  // =========================================================
  // EXISTING SIGN IN METHODS
  // =========================================================

  Future<void> validateSignInForm(String email, String password, BuildContext context) async {

    if (email.isEmpty || password.isEmpty) {
      commonViewModel.showSnackBar("Email and Password are required!", context);
      return;
    }

    commonViewModel.showSnackBar("Checking your credentials...!", context);

    fb_auth.User? currentFirebaseUser = await signInUser(email, password, context);

    if (currentFirebaseUser == null) {

      return;
    }

    bool success = await readDataFromFirestoreAndSetDataLocally(currentFirebaseUser, context);

    if (success && context.mounted) {
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => UserHomeScreen())
      );
      commonViewModel.showSnackBar("Signed in successfully...!", context);
    } else {
    }
  }

  Future<fb_auth.User?> signInUser(String email, String password, BuildContext context) async {

    try {
      final valueAuth = await fb_auth.FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      return valueAuth.user;
    } on fb_auth.FirebaseAuthException catch (e) {
      String message = "";
      switch (e.code) {
        case "invalid-email":
          message = "The email address is badly formatted.";
          break;
        case "user-not-found":
          message = "No user found for this email.";
          break;
        case "wrong-password":
          message = "Wrong password provided.";
          break;
        case "user-disabled":
          message = "This account has been disabled.";
          break;
        default:
          message = "An unexpected error occurred: ${e.message}";
      }

      commonViewModel.showSnackBar(message, context);
      return null;
    } catch (e) {
      commonViewModel.showSnackBar("Something went wrong: $e", context);
      return null;
    }
  }

  Future<bool> readDataFromFirestoreAndSetDataLocally(
      fb_auth.User currentFirebaseUser,
      BuildContext context
      ) async {


    try {
      final DocumentSnapshot dataSnapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(currentFirebaseUser.uid)
          .get();

      _log('Firestore query completed, exists: ${dataSnapshot.exists}');

      if (dataSnapshot.exists) {

        // Use the UserModel to safely parse the data
        final userModel = UserModel.fromFirestore(dataSnapshot);

        if (userModel.status == "approved") {

          // Save individual values to SharedPreferences
          await sharedPreferences!.setString("uid", userModel.uid);
          await sharedPreferences!.setString("email", userModel.email);
          await sharedPreferences!.setString("name", userModel.name);
          await sharedPreferences!.setString("imageUrl", userModel.imageUrl);
          await sharedPreferences!.setString("status", userModel.status);
          await sharedPreferences!.setString("phone", userModel.phone??'');
          await sharedPreferences!.setStringList("userCart", userModel.userCart);

          // Clear any potential corrupted data
          await sharedPreferences!.remove('userData'); // Remove any old map data

          // Debug the current state
          await _debugSharedPreferences();

          return true;
        } else {
          commonViewModel.showSnackBar("You are blocked by admin!", context);
          await fb_auth.FirebaseAuth.instance.signOut();
          return false;
        }
      } else {
        commonViewModel.showSnackBar("This user record does not exist", context);
        await fb_auth.FirebaseAuth.instance.signOut();
        return false;
      }
    } catch (e) {
      commonViewModel.showSnackBar("Error reading user data. Please try again.", context);
      await fb_auth.FirebaseAuth.instance.signOut();
      return false;
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

      if (uid == null || email == null || name == null) {
        return null;
      }

      return UserModel(
        uid: uid,
        email: email,
        name: name,
        imageUrl: imageUrl ?? '',
        status: status ?? 'approved',
        phone: phone?? '',
        userCart: userCart ?? ['garbageValue'],
      );
    } catch (e) {
      return null;
    }
  }

  // Additional debug method to check authentication state
  Future<void> debugAuthState() async {

    // Check Firebase Auth state
    final currentFirebaseUser = fb_auth.FirebaseAuth.instance.currentUser;

    // Check SharedPreferences state
    await _debugSharedPreferences();

    // Check getCurrentUser() method
    final userModel = getCurrentUser();

  }

  Future<void> logout(BuildContext context) async {
    try {
      _log('🚪 Logging out user');

      // 1️⃣ Firebase sign out
      await fb_auth.FirebaseAuth.instance.signOut();

      // 2️⃣ Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 3️⃣ Reset in-memory bootstrap cache
      await AppBootstrap.I.reset();

      _log('✅ Logout successful, local state cleared');

      if (!context.mounted) return;

      // 4️⃣ Navigate to login screen & clear stack
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MySplashScreen()), // or LoginScreen
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