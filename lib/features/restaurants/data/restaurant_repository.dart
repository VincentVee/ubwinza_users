import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/restaurant_model.dart';
import '../../../core/models/product_model.dart';
import '../../../core/services/firebase_paths.dart';
import '../../../core/services/firebase_service.dart';


class RestaurantRepository {
  final _db = FirebaseService.I.db;


  Stream<List<RestaurantModel>> watchRestaurants() => _db
      .collection(FirebasePaths.sellers)
      .where('status', isEqualTo: 'approved')
      .snapshots()
      .map((s) => s.docs.map((d) => RestaurantModel.fromMap(d.id, d.data())).toList());


  Stream<List<ProductModel>> watchMenu(String sellerId) => _db
      .collection('${FirebasePaths.sellers}/$sellerId/${FirebasePaths.products}')
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map((d) => ProductModel.fromMap(d.id, d.data())).toList());
}

