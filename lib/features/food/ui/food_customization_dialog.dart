import 'package:flutter/material.dart';
import '../models/food.dart';

class FoodCustomizationDialog extends StatefulWidget {
  final Food food;
  final Function(Food, Map<String, dynamic>) onAddToCart;

  const FoodCustomizationDialog({
    super.key,
    required this.food,
    required this.onAddToCart,
  });

  @override
  State<FoodCustomizationDialog> createState() => _FoodCustomizationDialogState();
}

class _FoodCustomizationDialogState extends State<FoodCustomizationDialog> {
  late List<Map<String, dynamic>> _sizes;
  late List<Map<String, dynamic>> _variations;
  late List<Map<String, dynamic>> _addons;
  double _totalPrice = 0.0;
  int _selectedSizeIndex = 0;

  @override
  void initState() {
    super.initState();
    
    // Use the ORIGINAL sizes data directly, not availableSizes
    _sizes = _createSizesList(widget.food.sizes);
    _variations = widget.food.availableVariations;
    _addons = widget.food.availableAddons;
    
    // Select first size by default but don't add to total yet
    if (_sizes.isNotEmpty) {
      _sizes[0]['selected'] = true;
      _selectedSizeIndex = 0;
    }
    
    _calculateTotalPrice();
  }

  // Create sizes list directly from the original sizes data
  List<Map<String, dynamic>> _createSizesList(List<Map<String, dynamic>> originalSizes) {
    return originalSizes.map((size) {
      // TAKE THE PRICE EXACTLY AS IT IS FROM DATABASE - NO MODIFICATIONS
      final rawPrice = _getPrice(size['price']);
      
      return {
        'name': size['name'] ?? 'Regular',
        'price': rawPrice, // Use exact price from DB, no additions, no modifications
        'selected': false,
      };
    }).toList();
  }

  // Safe price conversion method (same as in Food model)
  double _getPrice(dynamic price) {
    if (price == null) return 0.0;
    if (price is double) return price;
    if (price is int) return price.toDouble();
    if (price is num) return price.toDouble();
    if (price is String) return double.tryParse(price) ?? 0.0;
    return 0.0;
  }

  void _calculateTotalPrice() {
    double total = 0.0;

    // Add selected size price (use the actual price from DB, not base price)
    for (final size in _sizes) {
      if (size['selected'] == true) {
        total += _getPrice(size['price']);
        break;
      }
    }

    // Add variations cost
    for (final variation in _variations) {
      if (variation['selected'] == true) {
        total += _getPrice(variation['price']);
      }
    }

    // Add addons cost
    for (final addon in _addons) {
      if (addon['selected'] == true && (addon['inStock'] ?? true) == true) {
        total += _getPrice(addon['price']);
      }
    }

    setState(() {
      _totalPrice = total;
    });
  }

  void _onSizeSelected(int index) {
    setState(() {
      for (int i = 0; i < _sizes.length; i++) {
        _sizes[i]['selected'] = i == index;
      }
      _selectedSizeIndex = index;
      _calculateTotalPrice();
    });
  }

  void _onVariationToggled(int index) {
    setState(() {
      _variations[index]['selected'] = !(_variations[index]['selected'] ?? false);
      _calculateTotalPrice();
    });
  }

  void _onAddonToggled(int index) {
    setState(() {
      if ((_addons[index]['inStock'] ?? true) == true) {
        _addons[index]['selected'] = !(_addons[index]['selected'] ?? false);
        _calculateTotalPrice();
      }
    });
  }

  void _addToCart() {
    final selectedSize = _sizes.firstWhere(
      (size) => size['selected'] == true,
      orElse: () => _sizes.isNotEmpty ? _sizes.first : {},
    );

    final selectedVariations = _variations.where((v) => v['selected'] == true).toList();
    final selectedAddons = _addons.where((a) => a['selected'] == true).toList();

    final customization = {
      'selectedSize': selectedSize,
      'selectedVariations': selectedVariations,
      'selectedAddons': selectedAddons,
      'totalPrice': _totalPrice,
    };

    widget.onAddToCart(widget.food, customization);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A2B7B),
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Close button
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Customize ${widget.food.name}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Food Info
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.food.imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[300],
                        child: const Icon(Icons.fastfood, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.food.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Base price: K${widget.food.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(color: Colors.white54),

              // Sizes Section
              if (_sizes.isNotEmpty) ...[
                _buildSectionHeader('Sizes'),
                const SizedBox(height: 12),
                Column(
                  children: _sizes.asMap().entries.map((entry) {
                    final index = entry.key;
                    final size = entry.value;
                    final isSelected = size['selected'] == true;
                    final sizePrice = _getPrice(size['price']);
                    
                    return RadioListTile<bool>(
                      value: true,
                      groupValue: isSelected,
                      onChanged: (_) => _onSizeSelected(index),
                      activeColor: Colors.white,
                      title: Text(
                        size['name'],
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        'K${sizePrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.trailing,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],

              // Variations Section
              if (_variations.isNotEmpty) ...[
                _buildSectionHeader('Variations'),
                const SizedBox(height: 12),
                Column(
                  children: _variations.asMap().entries.map((entry) {
                    final index = entry.key;
                    final variation = entry.value;
                    final isSelected = variation['selected'] == true;
                    final variationPrice = _getPrice(variation['price']);
                    
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (_) => _onVariationToggled(index),
                      activeColor: Colors.white,
                      checkColor: const Color(0xFF1A2B7B),
                      title: Text(
                        variation['name'],
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        'K${variationPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.trailing,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],

              // Addons Section
              if (_addons.isNotEmpty) ...[
                _buildSectionHeader('Add Extra'),
                const SizedBox(height: 12),
                Column(
                  children: _addons.asMap().entries.map((entry) {
                    final index = entry.key;
                    final addon = entry.value;
                    final isSelected = addon['selected'] == true;
                    final isOutOfStock = addon['inStock'] == false;
                    final addonPrice = _getPrice(addon['price']);
                    
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: isOutOfStock ? null : (_) => _onAddonToggled(index),
                      activeColor: Colors.white,
                      checkColor: const Color(0xFF1A2B7B),
                      title: Text(
                        addon['name'],
                        style: TextStyle(
                          fontSize: 16,
                          color: isOutOfStock ? Colors.grey : Colors.white,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'K${addonPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: isOutOfStock ? Colors.grey : Colors.white70,
                            ),
                          ),
                          if (isOutOfStock)
                            Text(
                              'Out of Stock',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red[400],
                              ),
                            ),
                        ],
                      ),
                      controlAffinity: ListTileControlAffinity.trailing,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],

              const Divider(color: Colors.white54),

              // Total and Add to Cart Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        'K${_totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: _addToCart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1A2B7B),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text(
                      'Add to Cart',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }
}