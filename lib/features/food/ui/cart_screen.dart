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
import '../../../core/bootstrap/app_bootstrap.dart';
import '../../../core/models/location_model.dart';
import '../../../global/global_vars.dart';
import '../../home/widgets/simple_location_picker.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _isCalculatingFees = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setInitialDeliveryLocation();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _setInitialDeliveryLocation() async {
    final locationVM = context.read<LocationViewModel>();
    final deliveryProvider = context.read<dp.DeliveryProvider>();
    final cartProvider = context.read<CartProvider>();

    final LatLng? latestLocation = locationVM.currentLocation;
    final LatLng? currentDeliveryLocation = deliveryProvider.deliveryLocation;
    final String? latestAddress = locationVM.currentAddress;

    bool needsUpdate = false;

    if (latestLocation != null) {
      if (currentDeliveryLocation == null || currentDeliveryLocation != latestLocation) {
        needsUpdate = true;
      }
    }

    if (needsUpdate) {
      setState(() => _isCalculatingFees = true);

      await deliveryProvider.setDeliveryLocation(
        latestLocation!,
        latestAddress,
      );

      if (cartProvider.items.isNotEmpty) {
        final sellerIds = cartProvider.items.values
            .map((e) => e.food.sellerId)
            .toSet()
            .toList();

        final dm = PrefsService.I.getDeliveryMethod();
        final rideType = (dm == DeliveryMethod.bicycle) ? 'bicycle' : 'motorbike';

        await deliveryProvider.recalculateForSellers(sellerIds, rideType: rideType);
      }

      setState(() => _isCalculatingFees = false);
    }
  }

  bool _isReadyForCheckout(dp.DeliveryProvider deliveryProvider, List<String> sellerIds) {
    if (deliveryProvider.deliveryLocation == null) return false;
    if (sellerIds.isEmpty) return false;
    for (final id in sellerIds) {
      final calculation = deliveryProvider.getDeliveryCalculation(id);
      if (calculation == null) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();
    final deliveryProvider = context.watch<dp.DeliveryProvider>();

    final cartEntries = cartProvider.items.entries.toList();
    final sellerIds = cartEntries.map((e) => e.value.food.sellerId).toSet().toList();
    final hasValidLocation = deliveryProvider.deliveryLocation != null;
    final allFeesCalculated = _areAllFeesCalculated(deliveryProvider, sellerIds);
    final isReady = hasValidLocation && cartEntries.isNotEmpty && allFeesCalculated && !_isCalculatingFees;

    final subtotal = cartProvider.subTotal;
    final totalDeliveryFee = deliveryProvider.getTotalDeliveryFee(sellerIds);
    final grandTotal = subtotal + totalDeliveryFee;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: _buildPremiumAppBar(cartEntries.isNotEmpty, cartProvider),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: cartEntries.isEmpty
            ? _buildEmptyCart()
            : Column(
          children: [
            _buildLocationSection(deliveryProvider, hasValidLocation),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: cartEntries.length,
                itemBuilder: (context, index) {
                  final entry = cartEntries[index];
                  final uniqueKey = entry.key;
                  final item = entry.value;
                  final sellerInfo = deliveryProvider.getSellerInfo(item.food.sellerId);
                  final deliveryCalculation = deliveryProvider.getDeliveryCalculation(item.food.sellerId);

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
            _buildCheckoutSection(
              subtotal: subtotal,
              totalDeliveryFee: totalDeliveryFee,
              grandTotal: grandTotal,
              deliveryProvider: deliveryProvider,
              cartProvider: cartProvider,
              isReadyForCheckout: isReady,
              hasValidLocation: hasValidLocation,
              isCalculatingFees: _isCalculatingFees,
            ),
          ],
        ),
      ),
    );
  }

  bool _areAllFeesCalculated(dp.DeliveryProvider deliveryProvider, List<String> sellerIds) {
    if (sellerIds.isEmpty) return false;
    for (final id in sellerIds) {
      if (deliveryProvider.getDeliveryCalculation(id) == null) {
        return false;
      }
    }
    return true;
  }

  PreferredSizeWidget _buildPremiumAppBar(bool hasItems, CartProvider cartProvider) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      title: const Text(
        'My Cart',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A1A2E),
        ),
      ),
      centerTitle: true,
      actions: [
        if (hasItems)
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _showClearCartDialog(context, cartProvider),
            ),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildLocationSection(dp.DeliveryProvider deliveryProvider, bool hasValidLocation) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: hasValidLocation ? const Color(0xFF6C63FF).withOpacity(0.3) : Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: hasValidLocation
                  ? const Color(0xFF6C63FF).withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.location_on,
              color: hasValidLocation ? const Color(0xFF6C63FF) : Colors.red,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Delivery Address',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (!hasValidLocation)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Required',
                          style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Consumer<LocationViewModel>(
                  builder: (context, locationVM, child) {
                    final address = locationVM.currentAddress;
                    return Text(
                      address.isNotEmpty ? address : 'Select delivery location',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: address.isNotEmpty ? const Color(0xFF1A1A2E) : Colors.red,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showLocationPicker(deliveryProvider),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF).withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Change',
              style: TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // NEW: Use the existing SimpleLocationPickerScreen
  Future<void> _showLocationPicker(dp.DeliveryProvider deliveryProvider) async {
    final boot = AppBootstrap.I;
    if (!boot.isReady) {
      await boot.init(googleApiKey: googleApiKey);
    }

    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SimpleLocationPickerScreen(
          googleApiKey: googleApiKey,
          initialLocation: deliveryProvider.deliveryLocation ?? context.read<LocationViewModel>().currentLocation,
        );
      },
    );

    if (result != null && result is Map<String, dynamic> && mounted) {
      final location = result['location'];
      final address = result['address'] as String;

      if (location != null) {
        setState(() => _isCalculatingFees = true);

        // Update LocationViewModel
        context.read<LocationViewModel>().updateLocation(location as LatLng, address);

        // Update DeliveryProvider
        await deliveryProvider.setDeliveryLocation(location, address);

        final dm = PrefsService.I.getDeliveryMethod();
        final rideType = (dm == DeliveryMethod.bicycle) ? 'bicycle' : 'motorbike';

        final sellerIds = context.read<CartProvider>().items.values
            .map((e) => e.food.sellerId)
            .toSet()
            .toList();

        if (sellerIds.isNotEmpty) {
          await deliveryProvider.recalculateForSellers(sellerIds, rideType: rideType);
        }

        setState(() => _isCalculatingFees = false);

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location updated to: $address'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF6C63FF),
          ),
        );
      }
    }
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shopping_cart_outlined,
              size: 70,
              color: Color(0xFF6C63FF),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add some delicious food to get started!',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text('Browse Foods', style: TextStyle(fontSize: 16)),
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
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmation(context, food.name);
      },
      onDismissed: (direction) {
        cartProvider.remove(uniqueKey);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${food.name} removed from cart'),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () {
                cartProvider.add(
                  food,
                  size: item.selectedSize,
                  variation: item.selectedVariation,
                  addons: item.selectedAddons,
                  totalPrice: (item.total / item.quantity),
                  qty: item.quantity,
                );
              },
            ),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        child: Material(
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      food.imageUrl,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 70,
                        height: 70,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.fastfood, color: Colors.grey, size: 30),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          food.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (sellerInfo != null)
                          Row(
                            children: [
                              Icon(Icons.store, size: 12, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(
                                sellerInfo.name,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        if (item.selectedSize != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Size: ${item.selectedSize}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ),
                        if (item.selectedVariation != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Variation: ${item.selectedVariation}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ),
                        if (item.selectedAddons != null && item.selectedAddons!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Addons: ${item.selectedAddons!.join(', ')}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (deliveryCalculation != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C63FF).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.local_shipping, size: 12, color: const Color(0xFF6C63FF)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${deliveryCalculation.distanceInKm.toStringAsFixed(1)}km • K${deliveryCalculation.deliveryFee.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: const Color(0xFF6C63FF),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'K${item.total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF6C63FF),
                                  ),
                                ),
                                if (item.quantity > 1)
                                  Text(
                                    'K${(item.total / item.quantity).toStringAsFixed(2)} each',
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                  ),
                              ],
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () {
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
                                    icon: Icon(Icons.remove, size: 18, color: const Color(0xFF6C63FF)),
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    padding: EdgeInsets.zero,
                                  ),
                                  Container(
                                    width: 35,
                                    child: Text(
                                      item.quantity.toString(),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF1A1A2E),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => cartProvider.increment(uniqueKey),
                                    icon: Icon(Icons.add, size: 18, color: const Color(0xFF6C63FF)),
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
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
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context, String itemName) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline, size: 48, color: Colors.red),
              ),
              const SizedBox(height: 20),
              const Text(
                'Remove Item',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
              ),
              const SizedBox(height: 8),
              Text(
                'Remove $itemName from your cart?',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Remove', style: TextStyle(fontSize: 15)),
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

  Widget _buildCheckoutSection({
    required double subtotal,
    required double totalDeliveryFee,
    required double grandTotal,
    required dp.DeliveryProvider deliveryProvider,
    required CartProvider cartProvider,
    required bool isReadyForCheckout,
    required bool hasValidLocation,
    required bool isCalculatingFees,
  }) {
    String? disabledReason;
    if (cartProvider.items.isEmpty) {
      disabledReason = 'Cart is empty';
    } else if (!hasValidLocation) {
      disabledReason = 'Select delivery location';
    } else if (isCalculatingFees) {
      disabledReason = 'Calculating delivery fees...';
    } else if (!isReadyForCheckout) {
      disabledReason = 'Calculating delivery fees...';
    }

    final isCheckoutDisabled = _isLoading || cartProvider.items.isEmpty || !hasValidLocation || !isReadyForCheckout || isCalculatingFees;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          _buildPriceRow('Subtotal', subtotal),
          _buildPriceRow('Delivery Fee', totalDeliveryFee),
          const Divider(height: 24, thickness: 1),
          _buildPriceRow('Total', grandTotal, isTotal: true),
          const SizedBox(height: 12),

          if (disabledReason != null && !_isLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      disabledReason,
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                    ),
                  ),
                ],
              ),
            ),

          SafeArea(
            child: ElevatedButton(
              onPressed: isCheckoutDisabled
                  ? null
                  : () => _proceedToCheckout(deliveryProvider, cartProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              child: _isLoading
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Text(
                'Place Order',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? const Color(0xFF1A1A2E) : Colors.grey.shade700,
            ),
          ),
          Text(
            'K${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 22 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: isTotal ? const Color(0xFF6C63FF) : const Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _proceedToCheckout(
      dp.DeliveryProvider deliveryProvider,
      CartProvider cartProvider,
      ) async {
    final sellerIds = cartProvider.items.values.map((e) => e.food.sellerId).toSet().toList();

    if (deliveryProvider.deliveryLocation == null) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
          content: Text('Please select a delivery location first'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (!_areAllFeesCalculated(deliveryProvider, sellerIds)) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
          content: Text('Calculating delivery fees, please wait...'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, size: 60, color: Colors.green),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Order Placed Successfully!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                ),
                const SizedBox(height: 8),
                Text(
                  '${createdOrderIds.length} order(s) created',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      cartProvider.clear();
                      deliveryProvider.clear();
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Continue Shopping', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Checkout failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showClearCartDialog(BuildContext context, CartProvider cartProvider) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_sweep, size: 48, color: Colors.red),
              ),
              const SizedBox(height: 20),
              const Text(
                'Clear Cart',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Are you sure you want to remove all items from your cart?',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        cartProvider.clear();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(
                            content: Text('Cart cleared'),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Clear', style: TextStyle(fontSize: 15)),
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
}