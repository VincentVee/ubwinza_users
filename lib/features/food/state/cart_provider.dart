import 'package:flutter/foundation.dart';
import '../models/food.dart';
import '../models/cart_item.dart';

class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {}; // key: uniqueKey from CartItem
  double totalPrice = 0.0;

  Map<String, CartItem> get items => _items;

  // Recalculate total price from all items
  void _updateTotalPrice() {
    totalPrice = _items.values.fold(0.0, (sum, item) => sum + item.total);
  }

  void add(
    Food food, {
    String? size,
    String? variation,
    List<String>? addons,
    double totalPrice = 0,
    int qty = 1,
  }) {
    final cartItem = CartItem(
      food: food,
      selectedSize: size,
      selectedVariation: variation,
      selectedAddons: addons,
      quantity: qty,
    );

    final k = cartItem.uniqueKey;
    
    if (_items.containsKey(k)) {
      _items[k]!.quantity += qty;
    } else {
      _items[k] = cartItem;
    }
    _updateTotalPrice();
    notifyListeners();
  }

  void setQty(
    Food food, {
    String? size,
    String? variation,
    List<String>? addons,
    required int qty,
  }) {
    final cartItem = CartItem(
      food: food,
      selectedSize: size,
      selectedVariation: variation,
      selectedAddons: addons,
      quantity: qty,
    );

    final k = cartItem.uniqueKey;
    
    if (!_items.containsKey(k)) return;
    
    if (qty <= 0) {
      _items.remove(k);
    } else {
      _items[k]!.quantity = qty;
    }
    _updateTotalPrice();
    notifyListeners();
  }

  void remove(String uniqueKey) {
    _items.remove(uniqueKey);
    _updateTotalPrice();
    notifyListeners();
  }

  void increment(String uniqueKey) {
    if (_items.containsKey(uniqueKey)) {
      _items[uniqueKey]!.quantity++;
      _updateTotalPrice();
      notifyListeners();
    }
  }

  void decrement(String uniqueKey) {
    if (_items.containsKey(uniqueKey)) {
      if (_items[uniqueKey]!.quantity > 1) {
        _items[uniqueKey]!.quantity--;
      } else {
        _items.remove(uniqueKey);
      }
      _updateTotalPrice();
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    totalPrice = 0.0;
    notifyListeners();
  }

  // Helper method to get cart item by unique key
  CartItem? getItem(String uniqueKey) => _items[uniqueKey];

  // Check if a specific food with options is in cart
  bool contains(
    Food food, {
    String? size,
    String? variation,
    List<String>? addons,
  }) {
    final cartItem = CartItem(
      food: food,
      selectedSize: size,
      selectedVariation: variation,
      selectedAddons: addons,
      quantity: 1,
    );
    return _items.containsKey(cartItem.uniqueKey);
  }

  int get totalCount => _items.values.fold(0, (p, e) => p + e.quantity);
  double get subTotal => totalPrice; // Use totalPrice for subtotal

  double tax({double rate = 0.1}) => totalPrice * rate;
  double grandTotal({double rate = 0.1}) => totalPrice + tax(rate: rate);

  // Get all cart items as list (useful for UI)
  List<CartItem> get itemsList => _items.values.toList();

  void addWithCustomization(Food food, Map<String, dynamic> customization) {
    final customizationsKey = _generateCustomizationsKey(customization);
    final cartItemKey = '${food.id}_$customizationsKey';
    
    if (_items.containsKey(cartItemKey)) {
      _items[cartItemKey] = _items[cartItemKey]!.copyWith(
        quantity: _items[cartItemKey]!.quantity + 1,
      );
    } else {
      _items[cartItemKey] = CartItem(
        food: food,
        quantity: 1,
        customizations: customization,
      );
    }
    
    _updateTotalPrice();
    notifyListeners();
  }

  String _generateCustomizationsKey(Map<String, dynamic> customization) {
    final selectedSize = customization['selectedSize']?['name'] ?? '';
    final selectedVariations = (customization['selectedVariations'] as List)
        .map((v) => v['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList()
        .join(',');
    final selectedAddons = (customization['selectedAddons'] as List)
        .map((a) => a['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList()
        .join(',');
    
    return '${selectedSize}_${selectedVariations}_${selectedAddons}';
  }
}