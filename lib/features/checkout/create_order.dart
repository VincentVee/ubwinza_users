// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import '../../core/services/firebase_service.dart';
// import '../../core/services/firebase_paths.dart';
// import '../maps/map_picker_screen.dart';
// import '../cart/presentation/cart_vm.dart';
// import 'package:provider/provider.dart';
//
// Future<void> createOrderFromCart(BuildContext context, {required String sellerId}) async {
// // Pick delivery location first
//    LatLng _initial = LatLng(29,20);
//   final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => MapPickerScreen()));
//   if (result == null) return; // cancelled
//
//
//   final address = result['address'] as String; final lat = result['lat'] as double; final lng = result['lng'] as double;
//   final cart = context.read<CartVM>().cart;
//   final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
//
//
//   final items = cart.lines.map((l) => {
//     'productId': l.product.id,
//     'name': l.product.name,
//     'categoryId': '',
//     'price': l.product.price,
//     'qty': l.qty,
//     'imageUrl': l.product.imageUrl,
//   }).toList();
//
//
//   final fee = 0; // compute via distance matrix or tariff later
//
//
//   await FirebaseService.I.db.collection(FirebasePaths.orders).add({
//     'sellerId': sellerId,
//     'userId': userId,
//     'status': 'new',
//     'subtotal': cart.subtotal,
//     'deliveryFee': fee,
//     'total': cart.subtotal + fee,
//     'createdAt': FieldValue.serverTimestamp(),
//     'items': items,
//     'shippingAddress': address,
//     'dropoff': {'lat': lat, 'lng': lng},
//   });
//
//
//   if (context.mounted) {
//     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order placed')));
//     Navigator.pop(context); // close cart
//   }
// }