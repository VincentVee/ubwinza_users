import 'package:cloud_firestore/cloud_firestore.dart';

class Food {
  final String id;
  final String sellerId;
  final String name;
  final String description;
  final String category;
  final String categoryId;
  final double price;
  final String imageUrl;
  final double rating;
  final int kcal;
  final String prepTime;
  final List<Map<String, dynamic>> sizes;
  final String sizeUnit;
  final bool inStock;
  final List<String>? variations;
  final List<Map<String, dynamic>>? addons;
  final String? sellerBusinessName;

  Food({
    required this.id,
    required this.sellerId,
    required this.name,
    required this.description,
    required this.category,
    required this.categoryId,
    required this.price,
    required this.imageUrl,
    required this.rating,
    required this.kcal,
    required this.prepTime,
    required this.sizes,
    required this.sizeUnit,
    required this.inStock,
    this.variations,
    this.addons,
    this.sellerBusinessName,
  });

  double get basePrice => price;

  // Helper method to safely convert any value to double
  static double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // Helper method to safely get string
  static String _safeToString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  factory Food.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      final data = doc.data();

      String sellerId =
          data['sellerId']?.toString() ?? (doc.reference.parent.parent?.id ?? 'unknown');

      final basePrice = _safeToDouble(data['price']);

      // --- SIZES ---
      List<Map<String, dynamic>> sizes = [];
      if (data['sizes'] is List) {
        final rawSizes = data['sizes'] as List;
        for (var item in rawSizes) {
          if (item is Map<String, dynamic>) {
            // Check if it uses priceModifier or absolute price
            final priceModifier = _safeToDouble(item['priceModifier']);
            final absolutePrice = _safeToDouble(item['price']);
            
            // If priceModifier exists (non-zero), use it, otherwise use absolute price
            final finalPrice = priceModifier != 0.0 
                ? priceModifier  // Store modifier, will be added to base price later
                : absolutePrice != 0.0 
                    ? absolutePrice 
                    : basePrice;
            
            sizes.add({
              'name': _safeToString(item['name']),
              'price': finalPrice,
              'priceModifier': priceModifier, // Keep track of whether it's a modifier
            });
          } else if (item is String) {
            sizes.add({
              'name': item,
              'price': basePrice,
              'priceModifier': 0.0,
            });
          }
        }
      }
      
      // Create default sizes if none exist
      if (sizes.isEmpty) {
        sizes = [
          {'name': 'Regular', 'price': basePrice, 'priceModifier': 0.0},
          {'name': 'Large', 'price': basePrice + 5.0, 'priceModifier': 5.0},
        ];
      }

      // --- VARIATIONS ---
      List<String>? variations;
      if (data['variations'] is List) {
        variations = (data['variations'] as List).map((e) => _safeToString(e)).toList();
      }

      // --- ADDONS ---
      List<Map<String, dynamic>>? addons;
      if (data['addons'] is List) {
        addons = (data['addons'] as List).map((item) {
          if (item is Map<String, dynamic>) {
            return {
              'id': _safeToString(item['id'] ?? 
                  item['name']?.toString().toLowerCase().replaceAll(' ', '_') ?? 
                  'addon_${DateTime.now().millisecondsSinceEpoch}'),
              'name': _safeToString(item['name']),
              'description': _safeToString(item['description']),
              'price': _safeToDouble(item['price']),
              'inStock': item['inStock'] ?? true,
            };
          } else if (item is String) {
            return {
              'id': item.toLowerCase().replaceAll(' ', '_'),
              'name': item,
              'description': '',
              'price': 0.0,
              'inStock': true,
            };
          }
          return {
            'id': 'addon_${DateTime.now().millisecondsSinceEpoch}',
            'name': 'Unnamed Addon',
            'description': '',
            'price': 0.0,
            'inStock': true,
          };
        }).toList();
      }

      // --- PREP TIME ---
      String prepTime = '8–10 min';
      final prepTimeData = data['prepTimeMinutes'] ?? data['prepTime'];
      if (prepTimeData != null) {
        if (prepTimeData is int) {
          prepTime = '$prepTimeData min';
        } else if (prepTimeData is String) {
          prepTime = prepTimeData;
        } else if (prepTimeData is double) {
          prepTime = '${prepTimeData.round()} min';
        }
      }

      return Food(
        id: doc.id,
        sellerId: sellerId,
        name: _safeToString(data['name']),
        description: _safeToString(data['description']),
        category: _safeToString(data['categoryId'] ?? data['category']),
        categoryId: _safeToString(data['categoryId'] ?? data['category']),
        price: basePrice,
        imageUrl: (data['images'] is List && (data['images'] as List).isNotEmpty)
            ? _safeToString(data['images'][0])
            : _safeToString(data['imageUrl']),
        rating: _safeToDouble(data['rating']),
        kcal: (data['kcal'] is num) ? (data['kcal'] as num).toInt() : 320,
        prepTime: prepTime,
        sizes: sizes,
        sizeUnit: _safeToString(data['sizeUnit']),
        inStock: (data['inStock'] ?? true) as bool,
        variations: variations,
        addons: addons,
        sellerBusinessName: data['sellerBusinessName']?.toString(),
      );
    } catch (e) {
      print('❌ Error creating Food from document ${doc.id}: $e');
      return Food(
        id: doc.id,
        sellerId: 'unknown',
        name: 'Error Loading Food',
        description: 'There was an error loading this food item',
        category: 'Other',
        categoryId: 'Other',
        price: 0.0,
        imageUrl: '',
        rating: 4.5,
        kcal: 320,
        prepTime: '10 min',
        sizes: [
          {'name': 'Regular', 'price': 0.0, 'priceModifier': 0.0}
        ],
        sizeUnit: 'g',
        inStock: false,
        variations: null,
        addons: null,
        sellerBusinessName: null,
      );
    }
  }

  List<Map<String, dynamic>> get availableSizes {
    return sizes.map((size) {
      final priceModifier = _safeToDouble(size['priceModifier']);
      final absolutePrice = _safeToDouble(size['price']);
      
      // Calculate final price: base + modifier, or use absolute price
      final finalPrice = priceModifier != 0.0 
          ? priceModifier 
          : absolutePrice;
      
      return {
        'name': _safeToString(size['name']),
        'price': finalPrice,
        'selected': false,
      };
    }).toList();
  }

  List<Map<String, dynamic>> get availableVariations {
    if (variations == null || variations!.isEmpty) return [];
    return variations!
        .map((v) => {'name': _safeToString(v), 'selected': false, 'price': 0.0})
        .toList();
  }

  List<Map<String, dynamic>> get availableAddons {
    if (addons == null || addons!.isEmpty) return [];
    return addons!
        .map((a) => {
              'id': _safeToString(a['id']),
              'name': _safeToString(a['name']),
              'description': _safeToString(a['description']),
              'price': _safeToDouble(a['price']),
              'selected': false,
              'inStock': a['inStock'] ?? true,
            })
        .toList();
  }

  String get restaurantDisplayName {
    if (sellerBusinessName != null && sellerBusinessName!.isNotEmpty) {
      return sellerBusinessName!;
    }
    if (sellerId.length > 10 && sellerId.contains(RegExp(r'[a-zA-Z]'))) {
      return 'Restaurant ${sellerId.substring(0, 8)}...';
    }
    return sellerId;
  }
}