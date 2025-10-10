import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String imageUrl;
  final String status;
  final List<String> userCart;
  final String? phone;
  final String? address;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.imageUrl,
    required this.status,
    required this.userCart,
    this.phone,
    this.address,
  });

  // Convert Firestore document to UserModel
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: data['uid'] ?? doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      status: data['status'] ?? 'approved',
      userCart: data['userCart'] is List
          ? List<String>.from(data['userCart'])
          : ['garbageValue'],
      phone: data['phone'],
      address: data['address'],
    );
  }

  // Convert UserModel to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'imageUrl': imageUrl,
      'status': status,
      'userCart': userCart,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
    };
  }

  // Convert UserModel to Map for SharedPreferences
  Map<String, dynamic> toSharedPrefsMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'imageUrl': imageUrl,
      'status': status,
      'userCart': userCart,
      'phone': phone ?? '',
      'address': address ?? '',
    };
  }

  // Create UserModel from SharedPreferences map
  factory UserModel.fromSharedPrefsMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      status: map['status'] ?? 'approved',
      userCart: map['userCart'] is List
          ? List<String>.from(map['userCart'])
          : ['garbageValue'],
      phone: map['phone'],
      address: map['address'],
    );
  }
}