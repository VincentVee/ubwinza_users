import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ubwinza_users/core/models/delivery_calculation.dart';
import 'package:ubwinza_users/features/food/models/cart_item.dart';

class OrderService {
  final _db = FirebaseFirestore.instance;

  Future<String> createOrder({
    required String userId,
    required String sellerId,
    required List<CartItem> items,
    required DeliveryCalculation delivery, // from your DeliveryProvider
    required LatLng dropoff, // user’s chosen delivery location
    required String rideType,              // 'motorbike' | 'bicycle'
    String? note,
    double? driverLat,
    double? driverLng,
    String? driverName,
    String? driverImage,
    String? driverId,
  }) async {
    final doc = _db.collection('orders').doc();

    final itemPayload = items.map((ci) {
      // try to preserve the exact unit price you calculated in the details page
      final unitPrice = (ci.total / ci.quantity);
      return {
        'foodId'    : ci.food.id,
        'name'      : ci.food.name,
        'imageUrl'  : ci.food.imageUrl,
        'qty'       : ci.quantity,
        'unitPrice' : unitPrice,
        'total'     : ci.total,
        'size'      : ci.selectedSize,
        'variation' : ci.selectedVariation,
        'addons'    : ci.selectedAddons, // list or null
      };
    }).toList();

    final subtotal = items.fold<double>(0, (s, ci) => s + ci.total);
    final total    = subtotal + delivery.deliveryFee;

    await doc.set({
      'id'          : doc.id,
      'status'      : 'pending',          // pending | accepted | on_the_way | delivered | cancelled
      'createdAt'   : FieldValue.serverTimestamp(),
      'userId'      : userId,
      'sellerId'    : sellerId,

      // money
      'subtotal'    : subtotal,
      'deliveryFee' : delivery.deliveryFee,
      'total'       : total,

      // delivery meta
      'rideType'    : rideType,
      'pricePerKm'  : delivery.pricePerKilometer,
      'distanceKm'  : delivery.distanceInKm,

      // locations
      'dropoff'     : {'lat': dropoff.latitude, 'lng': dropoff.longitude},
      'seller'      : {
        'id'  : delivery.sellerId,
        'name': delivery.sellerName,
        'lat' : delivery.sellerLocation.latitude,
        'lng' : delivery.sellerLocation.longitude,
      },

      // items as an embedded array (simple + fast)
      'items'       : itemPayload,

      // optional free text
      'note'        : note,
      'driverLat': driverLat,
      'driverLng': driverLng,
      'driverName': driverName,
      'driverImage': driverImage,
      'driverId': driverId
    });

    return doc.id;
  }
}
