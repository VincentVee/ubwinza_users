import 'package:ubwinza_users/features/food/models/food.dart';

class CartItem {
  final Food food;
  final String? selectedSize;
  final String? selectedVariation;
  final List<String> selectedAddons;
  int quantity;
  final String uniqueKey;
  final Map<String, dynamic>? customizations;

  CartItem({
    required this.food,
    this.selectedSize,
    this.selectedVariation,
    List<String>? selectedAddons,
    required this.quantity,
    this.customizations
  }) : 
    selectedAddons = selectedAddons ?? [],
    uniqueKey = _generateUniqueKey(
      food.id, 
      selectedSize, 
      selectedVariation, 
      selectedAddons ?? []
    );

  static String _generateUniqueKey(
    String foodId, 
    String? size, 
    String? variation, 
    List<String> addons
  ) {
    final sortedAddons = List<String>.from(addons)..sort();
    return '$foodId::${size ?? "no-size"}::${variation ?? "no-variation"}::${sortedAddons.join(",")}';
  }

  // Helper to safely convert price values to double
  double _safePriceToDouble(dynamic price) {
    if (price == null) return 0.0;
    if (price is double) return price;
    if (price is int) return price.toDouble();
    if (price is String) return double.tryParse(price) ?? 0.0;
    return 0.0;
  }

  // Get the price for the selected size (or base price if no size selected)
  double get _sizePrice {
    if (selectedSize == null || food.sizes.isEmpty) {
      return food.price;
    }
    
    final sizeData = food.sizes.firstWhere(
      (s) => s['name'] == selectedSize,
      orElse: () => {'price': food.price},
    );
    
    return _safePriceToDouble(sizeData['price']);
  }

  // Calculate total price including size and addons
  double get total {
    // Start with the selected size price
    double basePrice = _sizePrice;
    
    // Add addon prices
    double addonsPrice = 0.0;
    if (selectedAddons.isNotEmpty && food.addons != null) {
      for (final addonName in selectedAddons) {
        final addon = food.addons!.firstWhere(
          (a) => a['name'] == addonName,
          orElse: () => <String, dynamic>{},
        );
        if (addon.isNotEmpty) {
          addonsPrice += _safePriceToDouble(addon['price']);
        }
      }
    }
    
    // Multiply by quantity
    return (basePrice + addonsPrice) * quantity;
  }

  double get displayPrice {
    if (customizations != null && customizations!['totalPrice'] != null) {
      return customizations!['totalPrice'];
    }
    return total;
  }

  // Get display name with options
  String get displayName {
    String name = food.name;
    
    // Show selected size
    if (selectedSize != null && selectedSize!.isNotEmpty) {
      name += ' ($selectedSize)';
    }
    
    // Show selected variation
    if (selectedVariation != null && selectedVariation!.isNotEmpty) {
      name += ' - $selectedVariation';
    }
    
    // Show selected addons
    if (selectedAddons.isNotEmpty) {
      name += ' + ${selectedAddons.join(", ")}';
    }
    
    // Also handle customizations format if present
    if (customizations != null) {
      final size = customizations!['selectedSize']?['name'];
      if (size != null && size.isNotEmpty && selectedSize == null) {
        name += ' ($size)';
      }
      
      final variations = customizations!['selectedVariations'] as List?;
      if (variations != null && variations.isNotEmpty) {
        final variationNames = variations.map((v) => v['name']).join(', ');
        name += ' - $variationNames';
      }
    }
    
    return name;
  }
  
  CartItem copyWith({
    Food? food,
    int? quantity,
    Map<String, dynamic>? customizations,
  }) {
    return CartItem(
      food: food ?? this.food,
      quantity: quantity ?? this.quantity,
      customizations: customizations ?? this.customizations,
    );
  }

  // Unit price (per single item with current selections)
  double get unitPrice => total / quantity;

  // ADD THESE CONVENIENCE GETTERS FOR UI ACCESS
  // These provide easy access to commonly needed properties
  String get id => uniqueKey;  // Use uniqueKey as the cart item ID
  String get imageUrl => food.imageUrl;
  String get name => displayName;  // Use the display name that includes customizations
  double get price => unitPrice;  // Use the calculated unit price
  String get sellerId => food.sellerId;
}