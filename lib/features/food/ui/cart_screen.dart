// lib/features/cart/ui/cart_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

// Prefix delivery_calculation.dart for DeliveryCalculation and SellerInfo type
import 'package:ubwinza_users/core/models/delivery_calculation.dart' as calc;
import 'package:ubwinza_users/core/models/delivery_method.dart';
import 'package:ubwinza_users/core/services/pref_service.dart';
// Prefix delivery_provider.dart for DeliveryProvider and its SellerInfo type
import 'package:ubwinza_users/features/delivery/state/delivery_provider.dart' as dp;
import 'package:ubwinza_users/features/food/models/cart_item.dart';
import 'package:ubwinza_users/features/food/models/food.dart';
import 'package:ubwinza_users/features/food/state/cart_provider.dart';
import 'package:ubwinza_users/features/order/data/order_service.dart';
import 'package:ubwinza_users/shared/widgets/delivery_location_sheet.dart';
import '../../../core/models/location_model.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setInitialDeliveryLocation();
    });
  }

  /// Ensures the DeliveryProvider's location is updated if the LocationViewModel
  /// has a newer location (e.g., set from UserHomeScreen) and triggers fee recalculation.
  Future<void> _setInitialDeliveryLocation() async {
    final locationVM = context.read<LocationViewModel>();
    final deliveryProvider = context.read<dp.DeliveryProvider>();
    final cartProvider = context.read<CartProvider>();

    final LatLng? latestLocation = locationVM.currentLocation;
    final LatLng? currentDeliveryLocation = deliveryProvider.deliveryLocation;
    final String? latestAddress = locationVM.currentAddress;

    // Determine if an update is needed:
    // 1. latestLocation is available.
    // 2. AND (Delivery location is null OR Delivery location does not match latest location).
    bool needsUpdate = false;

    if (latestLocation != null) {
      if (currentDeliveryLocation == null || currentDeliveryLocation != latestLocation) {
        needsUpdate = true;
      }
    }

    if (needsUpdate) {
      await deliveryProvider.setDeliveryLocation(
        latestLocation!,
        latestAddress,
      );

      // Recalculate fees for all unique sellers
      if (cartProvider.items.isNotEmpty) {
        final sellerIds = cartProvider.items.values
            .map((e) => e.food.sellerId)
            .toSet()
            .toList();

        final dm = PrefsService.I.getDeliveryMethod();
        final rideType = (dm == DeliveryMethod.bicycle) ? 'bicycle' : 'motorbike';

        await deliveryProvider.recalculateForSellers(sellerIds, rideType: rideType);

        // Trigger rebuild to show calculated fees (if needed)
        if (mounted) {
          setState(() {});
        }
      }
    }
  }

  // Helper to check calculation status
  bool _isReadyForCheckout(dp.DeliveryProvider deliveryProvider, List<String> sellerIds) {
    if (deliveryProvider.deliveryLocation == null) return false;
    if (sellerIds.isEmpty) return true;

    for (final id in sellerIds) {
      if (deliveryProvider.getDeliveryCalculation(id) == null) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Watch providers to trigger rebuilds when state changes
    final cartProvider = context.watch<CartProvider>();
    final deliveryProvider = context.watch<dp.DeliveryProvider>();

    final cartEntries = cartProvider.items.entries.toList();
    final sellerIds = cartEntries.map((e) => e.value.food.sellerId).toSet().toList();

    final isReady = _isReadyForCheckout(deliveryProvider, sellerIds);

    final subtotal = cartProvider.subTotal;
    final totalDeliveryFee = deliveryProvider.getTotalDeliveryFee(sellerIds);
    final grandTotal = subtotal + totalDeliveryFee;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Cart'),
        backgroundColor: const Color(0xFF1A2B7B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (cartEntries.isNotEmpty)
            IconButton(
              tooltip: 'Clear Cart',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _showClearCartDialog(context, cartProvider),
            ),
        ],
      ),
      body: Container(
        color: const Color(0xFFB8B4B4),
        child: Column(
          children: [
            // Button to open the location sheet

            Expanded(
              child: cartEntries.isEmpty
                  ? _buildEmptyCart()
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: cartEntries.length,
                itemBuilder: (context, index) {
                  final entry = cartEntries[index];
                  final uniqueKey = entry.key;
                  final item = entry.value;

                  // Ensure correct type and lookup is used for each cart item
                  final sellerInfo = deliveryProvider.getSellerInfo(item.food.sellerId);
                  final deliveryCalculation =
                  deliveryProvider.getDeliveryCalculation(item.food.sellerId);

                  return _buildCartItem(
                    uniqueKey: uniqueKey,
                    item: item,
                    sellerInfo: sellerInfo,
                    deliveryCalculation: deliveryCalculation,
                    cartProvider: cartProvider,
                  );
                },
              ),
            ),

            if (cartEntries.isNotEmpty)
              _buildCheckoutSection(
                subtotal: subtotal,
                totalDeliveryFee: totalDeliveryFee,
                grandTotal: grandTotal,
                deliveryProvider: deliveryProvider,
                cartProvider: cartProvider,
                isReadyForCheckout: isReady,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add some delicious food to get started!',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5A3D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('Browse Foods'),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem({
    required String uniqueKey,
    required CartItem item,
    required dp.SellerInfo? sellerInfo,
    required calc.DeliveryCalculation? deliveryCalculation,
    required CartProvider cartProvider,
  }) {
    final Food food = item.food;

    return Dismissible(
      key: Key(uniqueKey),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete, color: Colors.white, size: 32),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmation(context, food.name);
      },
      onDismissed: (direction) {
        cartProvider.remove(uniqueKey);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${food.name} removed from cart'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () {
                cartProvider.add(
                  food,
                  size: item.size,
                  variation: item.selectedVariation,
                  addons: item.selectedAddons,
                  totalPrice: item.total / item.quantity,
                  qty: item.quantity,
                );
              },
            ),
          ),
        );
      },
      child: Card(
        color: const Color(0xFF1A2B7B),
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  food.imageUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[200],
                    child: const Icon(Icons.fastfood, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      food.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Seller
                    if (sellerInfo != null)
                      Row(
                        children: [
                          Icon(Icons.store, size: 14, color: Colors.grey[300]),
                          const SizedBox(width: 4),
                          Text(
                            sellerInfo.name,
                            style: TextStyle(fontSize: 12, color: Colors.grey[300]),
                          ),
                        ],
                      ),

                    // Delivery info (per-seller)
                    // FIX APPLIED HERE: Using correct Collection If/Else Syntax
                    if (deliveryCalculation != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.local_shipping, size: 14, color: Colors.green[300]),
                            const SizedBox(width: 4),
                            Text(
                              '${deliveryCalculation.distanceInKm.toStringAsFixed(1)}km • K${deliveryCalculation.deliveryFee.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[300],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                    // Provide a loading/placeholder state if calculation is missing
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Calculating delivery fee...',
                          style: TextStyle(fontSize: 12, color: Colors.yellow[300]),
                        ),
                      ),


                    const SizedBox(height: 8),

                    // Price & quantity controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'K${item.total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFF5A3D),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () {
                                if (item.quantity > 1) {
                                  cartProvider.decrement(uniqueKey);
                                } else {
                                  _showDeleteConfirmation(context, food.name).then((confirm) {
                                    if (confirm == true) {
                                      cartProvider.remove(uniqueKey);
                                    }
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.remove_circle_outline,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(4),
                                color: Colors.white,
                              ),
                              child: Text(
                                item.quantity.toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => cartProvider.increment(uniqueKey),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.add_circle_outline,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () async {
                                final confirm = await _showDeleteConfirmation(context, food.name);
                                if (confirm == true) {
                                  cartProvider.remove(uniqueKey);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('${food.name} removed from cart'),
                                        backgroundColor: Colors.green,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context, String itemName) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2B7B),
        title: const Text(
          'Remove Item',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Remove $itemName from cart?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutSection({
    required double subtotal,
    required double totalDeliveryFee,
    required double grandTotal,
    required dp.DeliveryProvider deliveryProvider,
    required CartProvider cartProvider,
    required bool isReadyForCheckout,
  }) {
    final isCheckoutDisabled = _isLoading || cartProvider.items.isEmpty || !isReadyForCheckout;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[400],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          _buildPriceRow('Subtotal', subtotal),
          _buildPriceRow('Delivery Fee', totalDeliveryFee), // Aggregate delivery fees
          const Divider(height: 20),
          _buildPriceRow('Total', grandTotal, isTotal: true),

          const SizedBox(height: 16),

          SafeArea(
            child: ElevatedButton(
              onPressed: isCheckoutDisabled
                  ? null
                  : () => _proceedToCheckout(deliveryProvider, cartProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5A3D),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Text(
                'Place Order',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.black : Colors.black,
            ),
          ),
          Text(
            'K${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: isTotal ? const Color(0xFFFF5A3D) : Colors.black,
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _showDeliveryLocationSheet(dp.DeliveryProvider deliveryProvider) async {
    final locationVM = context.read<LocationViewModel>();

    final result = await showDeliveryLocationSheet(
      context: context,
      initialTarget: deliveryProvider.deliveryLocation ?? locationVM.currentLocation,
    );

    if (result != null) {
      // 1. Update the LocationViewModel (fires notifyListeners internally)
      locationVM.updateLocation(result.latLng, result.address as String);

      // 2. Update the DeliveryProvider
      await deliveryProvider.setDeliveryLocation(result.latLng, result.address);

      final dm = PrefsService.I.getDeliveryMethod();
      final rideType = (dm == DeliveryMethod.bicycle) ? 'bicycle' : 'motorbike';

      final sellerIds = context.read<CartProvider>().items.values
          .map((e) => e.food.sellerId)
          .toSet()
          .toList();

      // 3. Recalculate fees
      await deliveryProvider.recalculateForSellers(sellerIds, rideType: rideType);

      // 4. Manually trigger a rebuild if mounted to ensure immediate display update
      if (mounted) {
        setState(() {});
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delivery location and fees updated!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _proceedToCheckout(
      dp.DeliveryProvider deliveryProvider,
      CartProvider cartProvider,
      ) async {
    final sellerIds = cartProvider.items.values.map((e) => e.food.sellerId).toSet().toList();

    if (deliveryProvider.deliveryLocation == null || !_isReadyForCheckout(deliveryProvider, sellerIds)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delivery location or fees are still calculating. Please wait.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw 'Not signed in';
      }

      final dm = PrefsService.I.getDeliveryMethod();
      final rideType = (dm == DeliveryMethod.bicycle) ? 'bicycle' : 'motorbike';

      final entries = cartProvider.items.entries.toList();
      final Map<String, List<CartItem>> itemsBySeller = {};
      for (final e in entries) {
        final sellerId = e.value.food.sellerId;
        itemsBySeller.putIfAbsent(sellerId, () => []).add(e.value);
      }

      final createdOrderIds = <String>[];
      final orderSvc = OrderService();

      for (final sellerId in sellerIds) {
        final calc = deliveryProvider.getDeliveryCalculation(sellerId);
        if (calc == null) {
          throw 'Missing delivery fee for seller $sellerId';
        }
        final orderId = await orderSvc.createOrder(
          userId: userId,
          sellerId: sellerId,
          items: itemsBySeller[sellerId]!,
          delivery: calc,
          dropoff: deliveryProvider.deliveryLocation!,
          rideType: rideType,
        );
        createdOrderIds.add(orderId);
      }

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A2B7B),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Order Placed!', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Orders created: ${createdOrderIds.length}',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'IDs:\n${createdOrderIds.join('\n')}',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                cartProvider.clear();
                deliveryProvider.clear();
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Continue Shopping', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checkout failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showClearCartDialog(
      BuildContext context,
      CartProvider cartProvider,
      ) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2B7B),
        title: const Text('Clear Cart', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to remove all items from your cart?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              cartProvider.clear();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cart cleared'), backgroundColor: Colors.green),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}