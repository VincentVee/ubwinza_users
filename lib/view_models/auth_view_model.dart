import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_storage/firebase_storage.dart' as fs_store;
import 'package:ubwinza_users/features/home/home_screen.dart';

import '../global/global_instances.dart';
import '../global/global_vars.dart';
import '../views/mainScreens/home_screen.dart';
import '../core/models/user_model.dart';

class AuthViewModel {

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

  Future<void> validateSignUpForm(
      XFile? image,
      String password,
      String confirm,
      String email,
      String name,
      BuildContext context,
      ) async {
    _log('=== STARTING SIGN UP VALIDATION ===');
    _log('Email: $email, Name: $name, Password length: ${password.length}');

    if (image == null) {
      _log('❌ No image selected', type: 'ERROR');
      commonViewModel.showSnackBar("Please select the image from gallery", context);
      return;
    }

    if (password != confirm) {
      _log('❌ Password mismatch: $password vs $confirm', type: 'ERROR');
      commonViewModel.showSnackBar("Password and confirmation do not match!", context);
      return;
    }

    if (password.isEmpty || confirm.isEmpty || email.isEmpty || name.isEmpty) {
      _log('❌ Empty fields detected', type: 'ERROR');
      commonViewModel.showSnackBar("Please enter all the fields!", context);
      return;
    }

    _log('✅ Form validation passed');
    commonViewModel.showSnackBar("Please wait...", context);

    _log('Creating Firebase user...');
    final fb_auth.User? currentUser = await createUserInFirebase(email, password, context);

    if (currentUser == null) {
      _log('❌ Firebase user creation failed', type: 'ERROR');
      fb_auth.FirebaseAuth.instance.signOut();
      return;
    }

    _log('✅ Firebase user created: ${currentUser.uid}');
    _log('Uploading profile image...');

    final String downloadUrl = await uploadImageToFirebase(image);
    _log('✅ Image uploaded: $downloadUrl');

    _log('Saving user to Firestore...');
    final ok = await saveUserToFireStore(
      currentUser: currentUser,
      downloadUrl: downloadUrl,
      email: email,
      name: name,
      context: context,
    );

    if (!ok) {
      _log('❌ Failed to save user to Firestore', type: 'ERROR');
      return;
    }

    _log('✅ User saved successfully, navigating to home screen');

    if (context.mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
      commonViewModel.showSnackBar("Account created successfully", context);
    }

    _log('=== SIGN UP COMPLETED SUCCESSFULLY ===');
  }

  Future<fb_auth.User?> createUserInFirebase(
      String email,
      String password,
      BuildContext context,
      ) async {
    _log('Attempting to create Firebase user with email: $email');

    try {
      final cred = await fb_auth.FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      _log('✅ Firebase user created successfully: ${cred.user?.uid}');
      return cred.user;
    } on fb_auth.FirebaseAuthException catch (e) {
      _log('❌ Firebase Auth Exception: ${e.code} - ${e.message}', type: 'ERROR');
      commonViewModel.showSnackBar(e.message ?? e.code, context);
      return null;
    } catch (e) {
      _log('❌ Unexpected error creating Firebase user: $e', type: 'ERROR');
      commonViewModel.showSnackBar(e.toString(), context);
      return null;
    }
  }

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

      _log('✅ Image upload completed, getting download URL...');

      final String url = await snap.ref.getDownloadURL();
      _log('✅ Download URL obtained: $url');

      return url;
    } catch (e) {
      _log('❌ Error uploading image: $e', type: 'ERROR');
      rethrow;
    }
  }

  Future<bool> saveUserToFireStore({
    required fb_auth.User currentUser,
    required String downloadUrl,
    required String email,
    required String name,
    required BuildContext context
  }) async {
    _log('=== SAVING USER TO FIRESTORE ===');
    _log('User ID: ${currentUser.uid}');
    _log('Email: $email, Name: $name');

    try {
      final userModel = UserModel(
        uid: currentUser.uid,
        email: email,
        name: name,
        imageUrl: downloadUrl,
        status: "approved",
        userCart: ["garbageValue"],
      );

      _log('User model created, saving to Firestore...');

      await FirebaseFirestore.instance
          .collection("users")
          .doc(currentUser.uid)
          .set(userModel.toFirestore());

      _log('✅ User saved to Firestore successfully');

      _log('Saving to SharedPreferences...');
      // Save to SharedPreferences using individual keys (more reliable)
      await sharedPreferences!.setString("uid", userModel.uid);
      await sharedPreferences!.setString("email", userModel.email);
      await sharedPreferences!.setString("name", userModel.name);
      await sharedPreferences!.setString("imageUrl", userModel.imageUrl);
      await sharedPreferences!.setString("status", userModel.status);
      await sharedPreferences!.setStringList("userCart", userModel.userCart);

      _log('✅ SharedPreferences updated');

      // Debug the saved data
      await _debugSharedPreferences();

      _log('=== USER SAVE COMPLETED SUCCESSFULLY ===');
      return true;
    } on FirebaseException catch (e) {
      _log('❌ Firestore Exception: ${e.code} - ${e.message}', type: 'ERROR');
      commonViewModel.showSnackBar(
        "Firestore error: ${e.message ?? e.code}",
        context,
      );
      return false;
    } catch (e) {
      _log('❌ Unexpected error saving user: $e', type: 'ERROR');
      commonViewModel.showSnackBar("Error: ${e.toString()}", context);
      return false;
    }
  }

  Future<void> validateSignInForm(String email, String password, BuildContext context) async {
    _log('=== STARTING SIGN IN VALIDATION ===');
    _log('Email: $email, Password length: ${password.length}');

    if (email.isEmpty || password.isEmpty) {
      _log('❌ Empty email or password', type: 'ERROR');
      commonViewModel.showSnackBar("Email and Password are required!", context);
      return;
    }

    _log('✅ Form validation passed');
    commonViewModel.showSnackBar("Checking your credentials...!", context);

    _log('Attempting to sign in user...');
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
    _log('Attempting Firebase sign in for: $email');

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

      _log('❌ Firebase Auth Exception: ${e.code} - $message', type: 'ERROR');
      commonViewModel.showSnackBar(message, context);
      return null;
    } catch (e) {
      _log('❌ Unexpected sign in error: $e', type: 'ERROR');
      commonViewModel.showSnackBar("Something went wrong: $e", context);
      return null;
    }
  }

  Future<bool> readDataFromFirestoreAndSetDataLocally(
      fb_auth.User currentFirebaseUser,
      BuildContext context
      ) async {
    _log('=== READING USER DATA FROM FIRESTORE ===');
    _log('User ID: ${currentFirebaseUser.uid}');

    try {
      _log('Fetching user document from Firestore...');
      final DocumentSnapshot dataSnapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(currentFirebaseUser.uid)
          .get();

      _log('Firestore query completed, exists: ${dataSnapshot.exists}');

      if (dataSnapshot.exists) {
        _log('✅ User document found in Firestore');

        // Use the UserModel to safely parse the data
        final userModel = UserModel.fromFirestore(dataSnapshot);
        _log('User model parsed: ${userModel.name}, ${userModel.email}, status: ${userModel.status}');

        if (userModel.status == "approved") {
          _log('✅ User status is approved, saving to SharedPreferences...');

          // Save individual values to SharedPreferences
          await sharedPreferences!.setString("uid", userModel.uid);
          await sharedPreferences!.setString("email", userModel.email);
          await sharedPreferences!.setString("name", userModel.name);
          await sharedPreferences!.setString("imageUrl", userModel.imageUrl);
          await sharedPreferences!.setString("status", userModel.status);
          await sharedPreferences!.setStringList("userCart", userModel.userCart);

          _log('✅ SharedPreferences updated successfully');

          // Clear any potential corrupted data
          await sharedPreferences!.remove('userData'); // Remove any old map data
          _log('Cleared old userData from SharedPreferences');

          // Debug the current state
          await _debugSharedPreferences();

          _log('=== USER DATA READ AND SAVE COMPLETED SUCCESSFULLY ===');
          return true;
        } else {
          _log('❌ User status is not approved: ${userModel.status}', type: 'ERROR');
          commonViewModel.showSnackBar("You are blocked by admin!", context);
          await fb_auth.FirebaseAuth.instance.signOut();
          return false;
        }
      } else {
        _log('❌ User document does not exist in Firestore', type: 'ERROR');
        commonViewModel.showSnackBar("This user record does not exist", context);
        await fb_auth.FirebaseAuth.instance.signOut();
        return false;
      }
    } catch (e) {
      _log('❌ Error reading user data: $e', type: 'ERROR');
      commonViewModel.showSnackBar("Error reading user data. Please try again.", context);
      await fb_auth.FirebaseAuth.instance.signOut();
      return false;
    }
  }

  // Helper method to get current user from SharedPreferences
  UserModel? getCurrentUser() {
    _log('Getting current user from SharedPreferences...');

    try {
      final String? uid = sharedPreferences?.getString("uid");
      final String? email = sharedPreferences?.getString("email");
      final String? name = sharedPreferences?.getString("name");
      final String? imageUrl = sharedPreferences?.getString("imageUrl");
      final String? status = sharedPreferences?.getString("status");
      final List<String>? userCart = sharedPreferences?.getStringList("userCart");

      _log('Retrieved from SharedPreferences - UID: $uid, Email: $email, Name: $name');

      if (uid == null || email == null || name == null) {
        _log('❌ Incomplete user data in SharedPreferences', type: 'WARNING');
        return null;
      }

      _log('✅ Current user retrieved successfully');
      return UserModel(
        uid: uid,
        email: email,
        name: name,
        imageUrl: imageUrl ?? '',
        status: status ?? 'approved',
        userCart: userCart ?? ['garbageValue'],
      );
    } catch (e) {
      _log('❌ Error getting current user: $e', type: 'ERROR');
      return null;
    }
  }

  // Additional debug method to check authentication state
  Future<void> debugAuthState() async {
    _log('=== AUTH STATE DEBUG ===');

    // Check Firebase Auth state
    final currentFirebaseUser = fb_auth.FirebaseAuth.instance.currentUser;
    _log('Firebase Auth Current User: ${currentFirebaseUser?.uid ?? "NULL"}');
    _log('Firebase Auth Logged in: ${currentFirebaseUser != null}');

    // Check SharedPreferences state
    await _debugSharedPreferences();

    // Check getCurrentUser() method
    final userModel = getCurrentUser();
    _log('getCurrentUser() result: ${userModel != null ? "VALID" : "NULL"}');

    _log('=== END AUTH STATE DEBUG ===');
  }
}