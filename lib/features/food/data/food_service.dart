import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/food.dart';

class FoodService {
  final _db = FirebaseFirestore.instance;

final Map<String, String> _sellerNameCache = {};
  
  // Stream controller for seller name updates
  final _sellerNamesController = StreamController<Map<String, String>>.broadcast();
  Stream<Map<String, String>> get sellerNamesStream => _sellerNamesController.stream;
  
  StreamSubscription? _sellersSubscription;
  // Cache for seller names to avoid repeated queries
  // ignore: unused_field

  Future<List<String>> _approvedSellerIds() async {
    final snap = await _db
        .collection('sellers')
        .where('status', isEqualTo: "approved")
        .get();

    // also accept isApproved if your schema uses that
    final snap2 = await _db
        .collection('sellers')
        .where('isApproved', isEqualTo: true)
        .get();

    final ids = <String>{
      ...snap.docs.map((d) => d.id),
      ...snap2.docs.map((d) => d.id),
    }.toList();

    return ids;
  }

void startListeningToSellerNames() {
    print('👂 Starting real-time listener for seller names...');
    
    _sellersSubscription?.cancel();
    
    // Listen to all approved sellers
    _sellersSubscription = _db
        .collection('sellers')
        .where('isApproved', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      
      print('🔔 Seller data updated! Processing ${snapshot.docs.length} sellers...');
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        
        // Get the business name with proper fallbacks
        final businessName = data['businessName']?.toString().trim() ?? '';
        final restaurantName = data['restaurantName']?.toString().trim() ?? '';
        final name = data['name']?.toString().trim() ?? '';
        final displayName = data['displayName']?.toString().trim() ?? '';
        
        String finalName;
        if (businessName.isNotEmpty) {
          finalName = businessName;
        } else if (restaurantName.isNotEmpty) {
          finalName = restaurantName;
        } else if (name.isNotEmpty) {
          finalName = name;
        } else if (displayName.isNotEmpty) {
          finalName = displayName;
        } else {
          finalName = 'Restaurant ${doc.id.substring(0, 8)}';
        }
        
        // Update cache
        final oldName = _sellerNameCache[doc.id];
        if (oldName != finalName) {
          print('📝 Seller name updated: ${doc.id.substring(0, 8)}... "$oldName" -> "$finalName"');
        }
        
        _sellerNameCache[doc.id] = finalName;
      }
      
      // Notify listeners of the update
      _sellerNamesController.add(Map.from(_sellerNameCache));
    }, onError: (error) {
      print('❌ Error in seller names listener: $error');
    });
  }

  /// Stop listening to seller name changes
  void stopListeningToSellerNames() {
    _sellersSubscription?.cancel();
    _sellersSubscription = null;
  }

  /// Dispose resources
  void dispose() {
    stopListeningToSellerNames();
    _sellerNamesController.close();
  }
  // Firestore whereIn supports up to 10 values per query
  List<List<String>> _chunks(List<String> list, {int size = 10}) {
    final chunks = <List<String>>[];
    for (var i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(i, min(i + size, list.length)));
    }
    return chunks;
  }

/// Fetch seller names in bulk and cache them
Future<void> _fetchSellerNames(List<String> sellerIds) async {
  try {
    final uniqueIds = sellerIds.where((id) => !_sellerNameCache.containsKey(id)).toList();
    
    if (uniqueIds.isEmpty) {
      return;
    }


    for (final chunk in _chunks(uniqueIds)) {
      
      final snap = await _db
          .collection('sellers')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();


      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Try multiple field names - check if they exist AND are not empty
        final businessName = data['businessName']?.toString().trim() ?? '';
        final restaurantName = data['restaurantName']?.toString().trim() ?? '';
        final name = data['name']?.toString().trim() ?? '';
        final displayName = data['displayName']?.toString().trim() ?? '';
        
        // Use the FIRST non-empty value
        String finalName = '';
        if (businessName.isNotEmpty) {
          finalName = businessName;
        } else if (restaurantName.isNotEmpty) {
          finalName = restaurantName;
        } else if (name.isNotEmpty) {
          finalName = name;
        } else if (displayName.isNotEmpty) {
          finalName = displayName;
        } else {
          // If ALL fields are empty, generate default but also log warning
          finalName = 'Restaurant ${doc.id.substring(0, min(8, doc.id.length))}';

        }
        
        _sellerNameCache[doc.id] = finalName;
      }
    }

    // For any seller IDs not found in Firestore, set a default name
    for (final id in uniqueIds) {
      if (!_sellerNameCache.containsKey(id)) {
        final defaultName = 'Restaurant ${id.substring(0, min(8, id.length))}';
        _sellerNameCache[id] = defaultName;
      }
    }

  } catch (e, stackTrace) {

  }
}
  /// Fetch seller names in bulk and cache them
 /// Fetch seller names in bulk and cache them
Future<Map<String, String>> fetchSellerNames(List<String> sellerIds) async {
  try {
    final uniqueIds = sellerIds.toSet().toList();
    final sellerNames = <String, String>{};
    
    for (var i = 0; i < uniqueIds.length; i += 10) {
      final chunk = uniqueIds.sublist(i, i + 10 > uniqueIds.length ? uniqueIds.length : i + 10);
      
      final snap = await _db
          .collection('sellers')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        print('📝 Fetching name for seller ${doc.id.substring(0, 8)}...');
        print('   businessName: "${data['businessName']}"');
        print('   restaurantName: "${data['restaurantName']}"');
        print('   name: "${data['name']}"');
        print('   displayName: "${data['displayName']}"');
        
        // Try multiple field names and ensure we don't store empty strings
        final businessName = data['businessName']?.toString().trim() ?? '';
        final restaurantName = data['restaurantName']?.toString().trim() ?? '';
        final name = data['name']?.toString().trim() ?? '';
        final displayName = data['displayName']?.toString().trim() ?? '';
        
        // Use the first non-empty value
        String sellerName = '';
        if (businessName.isNotEmpty) {
          sellerName = businessName;
          print('   ✅ Using businessName: "$sellerName"');
        } else if (restaurantName.isNotEmpty) {
          sellerName = restaurantName;
          print('   ✅ Using restaurantName: "$sellerName"');
        } else if (name.isNotEmpty) {
          sellerName = name;
          print('   ✅ Using name: "$sellerName"');
        } else if (displayName.isNotEmpty) {
          sellerName = displayName;
          print('   ✅ Using displayName: "$sellerName"');
        } else {
          // Generate a default name if all fields are empty
          sellerName = 'Restaurant ${doc.id.substring(0, min(8, doc.id.length))}';
          print('   ⚠️ ALL fields empty! Using default: "$sellerName"');
          print('   ⚠️ ACTION REQUIRED: Update seller ${doc.id} with proper business name in Firestore!');
        }
        
        sellerNames[doc.id] = sellerName;
      }
    }

    // For any missing sellers, add default names
    for (final id in uniqueIds) {
      if (!sellerNames.containsKey(id)) {
        final defaultName = 'Restaurant ${id.substring(0, min(8, id.length))}';
        sellerNames[id] = defaultName;
        print('⚠️ Seller document missing for ID: $id, using default: "$defaultName"');
      }
    }

    print('✅ fetchSellerNames completed: ${sellerNames.length} sellers');
    return sellerNames;
  } catch (e) {
    print('❌ Error fetching seller names: $e');
    return {};
  }
}


void clearSellerNameCache() {
  _sellerNameCache.clear();
  print('🗑️ Seller name cache cleared');
}

/// Force refresh seller names from database
Future<void> refreshSellerNames() async {
  print('🔄 Force refreshing seller names from database...');
  _sellerNameCache.clear();
  
  final ids = await _approvedSellerIds();
  if (ids.isNotEmpty) {
    await _fetchSellerNames(ids);
  }
}
  /// Pull products from SUBCOLLECTION 'products' of APPROVED sellers only.
  /// Enhanced search with better filtering
 /// Pull products from SUBCOLLECTION 'products' of APPROVED sellers only.
/// Enhanced search with better filtering
/// Pull products from SUBCOLLECTION 'products' of APPROVED sellers only.
/// Enhanced search with better filtering
Future<List<Food>> fetchProducts({
  String? restaurant, // sellerId filter
  String? query,
}) async {
  try {
    final ids = await _approvedSellerIds();
    if (ids.isEmpty) {
      print('⚠️ No approved sellers found');
      return [];
    }

    // CRITICAL: Fetch and cache seller names FIRST
    await _fetchSellerNames(ids);

    final List<Food> out = [];

    // Determine which sellers to query
    List<String> sellerIdsToQuery = ids;
    if (restaurant != null && restaurant.isNotEmpty && restaurant != 'All') {
      sellerIdsToQuery = [restaurant];      
      final restaurantName = _sellerNameCache[restaurant] ?? 'Unknown Restaurant';
    }

    // Build the query
    for (final chunk in _chunks(sellerIdsToQuery)) {
      final q = _db.collectionGroup('products').where('sellerId', whereIn: chunk);
      
      final snap = await q.get();
      
      // Parse all products
      for (final doc in snap.docs) {
        try {
          final data = doc.data();
          
          // Get sellerId with multiple fallbacks
          String? sellerId = data['sellerId']?.toString();
          if (sellerId == null || sellerId.isEmpty) {
            sellerId = doc.reference.parent.parent?.id;
          }
          
          if (sellerId == null || sellerId.isEmpty) {
            continue;
          }

          // Get seller name from cache - THIS IS THE KEY PART
          final sellerBusinessName = _sellerNameCache[sellerId];
          
          // Parse food from document (without seller name)
          final baseFood = Food.fromDoc(doc);
          
          // Create new Food object with seller name EXPLICITLY set
          final foodWithSeller = Food(
            id: baseFood.id,
            sellerId: sellerId,
            name: baseFood.name,
            description: baseFood.description,
            category: baseFood.category,
            categoryId: baseFood.categoryId,
            price: baseFood.price,
            imageUrl: baseFood.imageUrl,
            rating: baseFood.rating,
            kcal: baseFood.kcal,
            prepTime: baseFood.prepTime,
            sizes: baseFood.sizes,
            sizeUnit: baseFood.sizeUnit,
            inStock: baseFood.inStock,
            variations: baseFood.variations,
            addons: baseFood.addons,
            sellerBusinessName: sellerBusinessName, // This should now have a value from cache
          );
          
          out.add(foodWithSeller);
        } catch (e, stackTrace) {
        }
      }
    }

    // Apply search filter if provided
    if (query != null && query.trim().isNotEmpty) {
      final searchTerms = query.trim().toLowerCase().split(' ');
      final before = out.length;
      
      out.retainWhere((food) {
        final searchableText = '${food.name} ${food.description} ${food.restaurantDisplayName} ${food.category}'.toLowerCase();
        return searchTerms.every((term) => searchableText.contains(term));
      });
          }

    // Final sorting
    out.sort((a, b) {
      if (a.inStock != b.inStock) return a.inStock ? -1 : 1;
      return b.rating.compareTo(a.rating);
    });

    return out;
  } catch (e, stackTrace) {

    return [];
  }
}

  /// Build restaurant list from approved sellers with proper names
  Future<List<String>> fetchRestaurants() async {
    try {
      final ids = await _approvedSellerIds();
      if (ids.isEmpty) return ['All'];

      // Fetch seller names
      await _fetchSellerNames(ids);

      final restaurants = <String>[];
      
      for (final sellerId in ids) {
        final restaurantName = _sellerNameCache[sellerId] ?? 'Unknown Restaurant';
        restaurants.add(restaurantName);
      }

      // Remove duplicates and sort
      final uniqueRestaurants = {'All', ...restaurants}.toList()..sort();
      return uniqueRestaurants;
    } catch (e) {
      return ['All'];
    }
  }

  /// Create mapping between restaurant names and seller IDs
  Future<Map<String, String>> getRestaurantNameToIdMap() async {
    try {
      final ids = await _approvedSellerIds();
      if (ids.isEmpty) return {};

      await _fetchSellerNames(ids);
      
      final Map<String, String> mapping = {};
      for (final sellerId in ids) {
        final restaurantName = _sellerNameCache[sellerId] ?? 'Unknown Restaurant';
        mapping[restaurantName] = sellerId;
      }
      
      return mapping;
    } catch (e) {
      return {};
    }
  }

  /// Fetch restaurant images
  Future<Map<String, String>> fetchRestaurantImages() async {
    try {
      final ids = await _approvedSellerIds();
      final Map<String, String> restaurantImages = {};

      if (ids.isEmpty) return restaurantImages;

      await _fetchSellerNames(ids);

      // First, try to get images from seller documents
      for (final chunk in _chunks(ids)) {
        final snap = await _db
            .collection('sellers')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in snap.docs) {
          final sellerId = doc.id;
          final restaurantName = _sellerNameCache[sellerId] ?? 'Unknown Restaurant';
          final data = doc.data() as Map<String, dynamic>;
          final imageUrl = data['profileImage'] ?? data['imageUrl'] ?? data['businessImage'] ?? '';
          
          if (imageUrl.toString().isNotEmpty) {
            restaurantImages[restaurantName] = imageUrl.toString();
          }
        }
      }

      // For restaurants without profile images, use the first product image as fallback
      final products = await fetchProducts();
      for (final restaurantName in _sellerNameCache.values) {
        if (!restaurantImages.containsKey(restaurantName) || restaurantImages[restaurantName]!.isEmpty) {
          final restaurantProduct = products.firstWhere(
            (food) => food.restaurantDisplayName == restaurantName,
            orElse: () => products.isNotEmpty ? products.first : Food(
              id: 'temp',
              sellerId: 'temp',
              name: 'Temp',
              description: 'Temp',
              category: 'Temp',
              categoryId: 'Temp',
              price: 0.0,
              imageUrl: '',
              rating: 4.5,
              kcal: 0,
              prepTime: '0 min',
              sizes: [],
              sizeUnit: 'g',
              inStock: true,
            ),
          );
          if (restaurantProduct.imageUrl.isNotEmpty) {
            restaurantImages[restaurantName] = restaurantProduct.imageUrl;
          }
        }
      }

      return restaurantImages;
    } catch (e) {
      print('Error in fetchRestaurantImages: $e');
      return {};
    }
  }

  // Keep your existing category methods...
  Future<List<String>> fetchCategories() async {
    try {
      final ids = await _approvedSellerIds();
      if (ids.isEmpty) return ['All'];

      final set = <String>{};
      for (final chunk in _chunks(ids)) {
        final snap = await _db
            .collectionGroup('products')
            .where('sellerId', whereIn: chunk)
            .get();
        for (final d in snap.docs) {
          final c = d.data()['categoryId'];
          if (c is String && c.trim().isNotEmpty) set.add(c.trim());
        }
      }

      final list = ['All', ...set.toList()..sort()];
      return list;
    } catch (e) {
      print('Error in fetchCategories: $e');
      return ['All'];
    }
  }

  Future<Map<String, String>> fetchCategoryImages() async {
    try {
      final ids = await _approvedSellerIds();
      final Map<String, String> out = {};

      try {
        final catsSnap = await _db.collection('categories').get();
        for (final d in catsSnap.docs) {
          final data = d.data() as Map<String, dynamic>;
          final imageUrl = (data['imageUrl'] ?? '').toString().trim();
          if (imageUrl.isEmpty) continue;

          final idKey   = d.id.trim().toLowerCase();
          final nameKey = (data['name'] ?? '').toString().trim().toLowerCase();

          if (idKey.isNotEmpty)   out[idKey] = imageUrl;
          if (nameKey.isNotEmpty) out[nameKey] = imageUrl;
        }
      } catch (_) {}

      if (ids.isNotEmpty) {
        for (final chunk in _chunks(ids)) {
          final snap = await _db
              .collectionGroup('products')
              .where('sellerId', whereIn: chunk)
              .get();

          for (final d in snap.docs) {
            final data = d.data() as Map<String, dynamic>;
            final catRaw = (data['categoryId'] ?? data['category'] ?? '').toString();
            final cat = catRaw.trim().toLowerCase();
            if (cat.isEmpty || out.containsKey(cat)) continue;

            String imageUrl = '';
            if (data['images'] is List && (data['images'] as List).isNotEmpty) {
              imageUrl = (data['images'][0] ?? '').toString().trim();
            } else if (data['imageUrl'] != null) {
              imageUrl = data['imageUrl'].toString().trim();
            }
            if (imageUrl.isNotEmpty) out[cat] = imageUrl;
          }
        }
      }

      return out;
    } catch (e) {
      return {};
    }
  }
}