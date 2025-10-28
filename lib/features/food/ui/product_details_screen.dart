import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ubwinza_users/features/food/models/food.dart';
import 'package:ubwinza_users/features/food/state/cart_provider.dart';
import 'package:ubwinza_users/shared/widgets/cart_badge_icon.dart';
import 'cart_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Food food;
  const ProductDetailsScreen({super.key, required this.food});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int _qty = 1;
  String? _selectedSize;
  String? _variation;
  final Set<String> _selectedAddons = {};

  @override
  void initState() {
    super.initState();
    if (widget.food.sizes.isNotEmpty) {
      _selectedSize = widget.food.sizes.first['name'];
    }
  }

  // 🧮 Total Price Calculation - FIXED to use exact DB prices
  double _calculateTotalPrice() {
    // Start with selected size price (EXACT from DB, no modifications)
    double total = _getSelectedSizePrice();

    // Add addons prices
    if (_selectedAddons.isNotEmpty && widget.food.addons != null) {
      for (final addonName in _selectedAddons) {
        final addon = widget.food.addons!.firstWhere(
          (a) => a['name'] == addonName,
          orElse: () => <String, dynamic>{},
        );
        if (addon.isNotEmpty) {
          total += _safePriceToDouble(addon['price']);
        }
      }
    }

    // Multiply by quantity at the END
    return total * _qty;
  }

  // 🧩 Helper for selected size price - EXACT from DB
  double _getSelectedSizePrice() {
    if (widget.food.sizes.isEmpty) return widget.food.price;
    
    final selected = widget.food.sizes.firstWhere(
      (s) => s['name'] == _selectedSize,
      orElse: () => {'price': widget.food.price},
    );
    
    // Return EXACT price from DB, no modifications
    return _safePriceToDouble(selected['price']);
  }

  // 🧩 Helper to safely convert any price value to double
  double _safePriceToDouble(dynamic price) {
    if (price == null) return 0.0;
    if (price is double) return price;
    if (price is int) return price.toDouble();
    if (price is String) return double.tryParse(price) ?? 0.0;
    return 0.0;
  }

  // 🛒 Add to Cart with all selections
  void _addToCart() {
    final totalPrice = _calculateTotalPrice();
    
    // Add to cart using your CartProvider with the calculated totalPrice
    Provider.of<CartProvider>(context, listen: false).add(
      widget.food,
      size: _selectedSize,
      variation: _variation,
      addons: _selectedAddons.isNotEmpty ? _selectedAddons.toList() : null,
      totalPrice: totalPrice, // ✅ Pass the calculated total price
      qty: _qty,
    );
    
    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added ${widget.food.name} (${_qty}x) - K${totalPrice.toStringAsFixed(2)} to cart!',
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
    
    // Optionally navigate back or to cart screen
    // Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.food;

    return Scaffold(
      appBar: AppBar(
        title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A2B7B),
        actions: [
          CartBadgeIcon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: const Color(0xFFB8B4B4),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🍽️ Food Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        f.imageUrl,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 220,
                          width: double.infinity,
                          color: Colors.grey[300],
                          child: const Icon(Icons.fastfood, size: 60, color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 📝 Name and Price
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            f.name,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                        ),
                        Text(
                          "K${_calculateTotalPrice().toStringAsFixed(2)}",
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // ⭐ Rating and Prep Info
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber.shade700, size: 20),
                        Text(f.rating.toString(), style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
                        const SizedBox(width: 10),
                        const Icon(Icons.timer_outlined, size: 18, color: Colors.black),
                        const SizedBox(width: 4),
                        Text(f.prepTime, style: const TextStyle(color: Colors.black)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 🧂 Description
                    Text(
                      f.description,
                      style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),

                    // 📏 Sizes (Dynamic) - Shows EXACT price from DB
                    if (f.sizes.isNotEmpty) ...[
                      const Text('Size',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black)),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: f.sizes.map((size) {
                          final name = size['name'] ?? 'Regular';
                          final price = _safePriceToDouble(size['price']); // EXACT DB price
                          final selected = _selectedSize == name;

                          return RadioListTile<String>(
                            value: name,
                            groupValue: _selectedSize,
                            onChanged: (value) {
                              setState(() {
                                _selectedSize = value;
                              });
                            },
                            activeColor: const Color(0xFF1A2B7B),
                            title: Text('$name (K${price.toStringAsFixed(2)})',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: selected ? const Color(0xFF1A2B7B) : Colors.black87,
                                )),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 🧁 Variations (Dynamic, if any)
                    if (f.variations != null && f.variations!.isNotEmpty) ...[
                      const Text('Variation',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        children: f.variations!.map((v) {
                          final selected = _variation == v;
                          return ChoiceChip(
                            label: Text(
                              v,
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            selected: selected,
                            selectedColor: const Color(0xFF1A2B7B),
                            onSelected: (_) => setState(() {
                              // Toggle: if already selected, unselect it
                              _variation = selected ? null : v;
                            }),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 🧩 Addons (Dynamic)
                    if (f.addons != null && f.addons!.isNotEmpty) ...[
                      const Text('Add-ons',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black)),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: f.addons!.map((addon) {
                          final name = addon['name'] ?? 'Unnamed';
                          final price = _safePriceToDouble(addon['price']);
                          final selected = _selectedAddons.contains(name);

                          return CheckboxListTile(
                            value: selected,
                            onChanged: (_) {
                              setState(() {
                                if (selected) {
                                  _selectedAddons.remove(name);
                                } else {
                                  _selectedAddons.add(name);
                                }
                              });
                            },
                            activeColor: const Color(0xFF1A2B7B),
                            checkColor: Colors.white,
                            title: Text('$name (+K${price.toStringAsFixed(2)})',
                                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ➕ Quantity Selector
                    const Text('Quantity',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.remove, color: _qty > 1 ? Colors.black : Colors.grey),
                                onPressed: _qty > 1 
                                    ? () => setState(() => _qty--) 
                                    : null,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  _qty.toString(),
                                  style: const TextStyle(
                                    fontSize: 18, 
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, color: Colors.black),
                                onPressed: () => setState(() => _qty++),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 100), // Extra space for button
                  ],
                ),
              ),
            ),
          ),

          // 🛒 Add to Cart Button - FIXED AT BOTTOM
          Container(
            color: const Color(0xFFB8B4B4),
            padding: const EdgeInsets.all(16),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A2B7B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  onPressed: _addToCart,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shopping_cart_outlined, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Add to Cart',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      Text(
                        'K${_calculateTotalPrice().toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}