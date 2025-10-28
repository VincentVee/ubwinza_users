// lib/features/food/ui/food_home_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ubwinza_users/features/delivery/state/delivery_provider.dart';
import 'package:ubwinza_users/features/food/data/food_service.dart';
import 'package:ubwinza_users/features/food/models/food.dart';
import 'package:ubwinza_users/features/food/state/cart_provider.dart';
import 'package:ubwinza_users/shared/widgets/cart_badge_icon.dart';
import 'product_details_screen.dart';
import 'cart_screen.dart';

class FoodHomeScreen extends StatefulWidget {
  const FoodHomeScreen({super.key});

  @override
  State<FoodHomeScreen> createState() => _FoodHomeScreenState();
}

class _FoodHomeScreenState extends State<FoodHomeScreen> {
  final _svc = FoodService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  StreamSubscription? _sellerNamesSubscription;
  List<String> _restaurants = const ['All'];
  String _selectedRestaurant = 'All';
  final Map<String, String> _sellerNameCache = {}; 
  // Map to store restaurant name -> seller ID mapping
  final Map<String, String> _restaurantToSellerId = {};
  Future<List<Food>>? _future;

  final PageController _restaurantController = PageController(viewportFraction: 0.88);
  Map<String, String> _restaurantImages = {};

  @override
  void initState() {
    super.initState();

     _svc.startListeningToSellerNames();
    
    // Listen to seller name updates and refresh UI
    _sellerNamesSubscription = _svc.sellerNamesStream.listen((updatedNames) {
      print('🔔 Seller names updated in UI, refreshing...');
      _bootstrap(); // Rebuild everything when seller names change
    });

    _bootstrap();
  }

  @override
  void dispose() {
    _restaurantController.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
     _sellerNamesSubscription?.cancel();
    _svc.stopListeningToSellerNames();
    super.dispose();
  }

  List<List<T>> _chunks<T>(List<T> list, [int size = 10]) {
    return List.generate((list.length / size).ceil(), 
        (i) => list.sublist(i * size, min(i * size + size, list.length)));
  }

  // Add this in _bootstrap() after _load()
  Future<void> _bootstrap() async {
    try {
      // Build mapping with real seller names
      await _buildRestaurantMapping();
      
      // Update restaurants list with actual seller names
      final restaurantNames = ['All', ..._restaurantToSellerId.keys.toList()];
      
      final images = await _svc.fetchRestaurantImages();
      
      setState(() {
        _restaurants = restaurantNames;
        _restaurantImages = images;
      });
      _load();
    } catch (e) {
      print('Error: $e');
      setState(() {
        _restaurants = ['All'];
        _restaurantImages = {};
      });
    }
  }

  // NEW: Build mapping between restaurant names and seller IDs using fetchProducts
  Future<void> _buildRestaurantMapping() async {
    try {
      final allProducts = await _svc.fetchProducts();
      _restaurantToSellerId.clear();

      // Get all unique seller IDs from products
      final sellerIds = allProducts.map((p) => p.sellerId).toSet().toList();
      
      // Get seller names using the method that's ALREADY in FoodService
      final sellerNames = await _svc.fetchSellerNames(sellerIds);
      
      // Build restaurant mapping
      sellerNames.forEach((sellerId, sellerName) {
        _restaurantToSellerId[sellerName] = sellerId;
      });

      print('Restaurant mapping: $_restaurantToSellerId');
    } catch (e) {
      print('Error: $e');
    }
  }

  void _load() {
    setState(() {
      // Use seller ID for filtering, or null for 'All'
      final sellerId = _selectedRestaurant == 'All' 
          ? null 
          : _restaurantToSellerId[_selectedRestaurant];
      
      _future = _svc.fetchProducts(
        restaurant: sellerId,
        query: _searchCtrl.text.trim(),
      );
    });
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  // NEW: When a product is selected, get seller info and calculate delivery
  void _onProductSelected(Food food, BuildContext context) {
    final deliveryProvider = Provider.of<DeliveryProvider>(context, listen: false);
    
    // Add seller to delivery provider
    deliveryProvider.addSellerAndCalculateFee(
      sellerId: food.sellerId,
      rideType: 'motorbike', // You can get this from user selection
    );

    // Navigate to product details
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => ProductDetailsScreen(food: food),
      ),
    );
  }

  List<String> get _restaurantsNoAll =>
          _restaurants.where((c) => c != 'All' && c.isNotEmpty).toList();

  Widget _restaurantHeroCard(String restaurant) {
    final img = _restaurantImages[restaurant];

    return GestureDetector(
      onTap: () {
        setState(() => _selectedRestaurant = restaurant);
        _load();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
          color: Colors.grey[200],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (img != null && img.isNotEmpty)
              CachedNetworkImage(
                imageUrl: img,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: Colors.grey[300]),
                errorWidget: (_, __, ___) => Container(color: Colors.grey[300]),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.10),
                    Colors.black.withOpacity(0.35),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.9),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text(
                        'Restaurant',
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      restaurant,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantHeroSlider() {
    final items = _restaurantsNoAll;
    if (items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 140,
      child: PageView.builder(
        controller: _restaurantController,
        padEnds: false,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (_, i) => _restaurantHeroCard(items[i]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFF5A3D);

    return Scaffold(
      backgroundColor: const Color(0xFFB8B4B4),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        title: const Text(
          'Discover Foods',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        actions: [
          IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white,),
          tooltip: 'Refresh data',
          onPressed: () async {
            // Show loading indicator
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Refreshing...'),
                duration: Duration(seconds: 1),
              ),
            );
            
            // Clear cache and reload
            _svc.clearSellerNameCache();
            await _bootstrap();
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Data refreshed!'),
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
          CartBadgeIcon(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    style: TextStyle(
                      color: Colors.black,
                    ),
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    decoration: const InputDecoration(
                      hintText: 'Search your food, groceries',
                      border: InputBorder.none,
                      icon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                _buildRestaurantHeroSlider(),
                const SizedBox(height: 16),

                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _restaurants.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final r = _restaurants[i];
                      final selected = r == _selectedRestaurant;
                      return ChoiceChip(
                        label: Text(
                          r,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        selected: selected,
                        backgroundColor: Colors.white,
                        selectedColor: accent.withOpacity(.15),
                        labelStyle: TextStyle(
                          color: selected ? accent : Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        onSelected: (_) {
                          setState(() => _selectedRestaurant = r);
                          _load();
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children:  [
                    Text(
                      'Recommended For You',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black,
                      ),
                    ),
                    GestureDetector(
                      child: Text(
                        'See all',
                        style: TextStyle(color: Colors.black, fontSize: 13),
                      ),
                      onTap: (){
                        _selectedRestaurant = "All";
                        _searchCtrl.text = "";
                        _load();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),

          Expanded(
            child: FutureBuilder<List<Food>>(
              future: _future,
              builder: (_, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final foods = snap.data ?? const [];
                if (foods.isEmpty) {
                  return const Center(child: Text('No foods found'));
                }
                return SafeArea(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: foods.length,
                    itemBuilder: (_, i) {
                      final f = foods[i];
                      return _FoodCard(
                        food: f,
                        onTap: () => _onProductSelected(f, context),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodCard extends StatelessWidget {
  const _FoodCard({required this.food, required this.onTap});
  final Food food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    const accent = Color(0xFFFF5A3D);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Hero(
                tag: 'food_${food.id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: food.imageUrl,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(width: 72, height: 72, color: Colors.grey[200]),
                    errorWidget: (_, __, ___) =>
                        Container(color: Colors.grey[300], width: 72, height: 72),
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 20,
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 16, color: Color(0xFFFFB000)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${food.rating.toStringAsFixed(1)}  •  ${food.restaurantDisplayName}',
                              style: const TextStyle(color: Colors.black54),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'K${food.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  // Navigate to ProductDetailsScreen when + button is clicked
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductDetailsScreen(food: food),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5A3D),
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  minimumSize: const Size(44, 42),
                ),
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ),
    );
  }
}