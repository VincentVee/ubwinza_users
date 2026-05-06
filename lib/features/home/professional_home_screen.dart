import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:ubwinza_users/features/delivery/state/delivery_provider.dart';
import 'package:ubwinza_users/features/food/data/food_service.dart';
import 'package:ubwinza_users/features/food/models/food.dart';
import 'package:ubwinza_users/features/food/ui/cart_screen.dart';
import 'package:ubwinza_users/features/food/ui/product_details_screen.dart';
import 'package:ubwinza_users/features/food/state/cart_provider.dart';
import 'package:ubwinza_users/features/home/professional_food_card.dart';
import 'package:ubwinza_users/features/home/widgets/simple_location_picker.dart';
import 'package:ubwinza_users/features/packages/presentation/package_create_screen.dart';
import 'package:ubwinza_users/shared/widgets/cart_badge_icon.dart';
import '../../core/bootstrap/app_bootstrap.dart';
import '../../core/models/location_model.dart';
import '../../global/global_instances.dart';
import '../../global/global_vars.dart';
import '../../view_models/auth_view_model.dart';
import '../../views/authScreens/auth_screen.dart';
import '../delivery/presentation/deliveries_list_screen.dart';
import '../food/models/cart_item.dart';
import '../order/data/presentation/order_history_page.dart';
import '../profile/presentation/profile_screen.dart';

class ProfessionalHomeScreen extends StatefulWidget {
  const ProfessionalHomeScreen({super.key});

  @override
  State<ProfessionalHomeScreen> createState() => _ProfessionalHomeScreenState();
}

class _ProfessionalHomeScreenState extends State<ProfessionalHomeScreen> with SingleTickerProviderStateMixin {
  final FoodService _foodService = FoodService();
  late TabController _tabController;
  String _selectedService = 'food';

  // Data from your existing logic
  List<Food> _allFoods = [];
  List<String> _restaurants = ['All'];
  String _selectedRestaurant = 'All';
  final Map<String, String> _restaurantToSellerId = {};
  final Map<String, String> _restaurantImages = {};
  bool _isLoading = true;
  String? _error;

  StreamSubscription? _sellerNamesSubscription;

  // Drawer menu items
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();

    // Fix Status Bar Color
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));

    _tabController = TabController(length: 2, vsync: this);

    // Listen to seller name updates
    _foodService.startListeningToSellerNames();
    _sellerNamesSubscription = _foodService.sellerNamesStream.listen((updatedNames) {
      print('🔄 Seller names updated, refreshing UI...');
      _loadData();
    });

    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sellerNamesSubscription?.cancel();
    _foodService.stopListeningToSellerNames();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final foods = await _foodService.fetchProducts();
      await _buildRestaurantMapping(foods);
      final images = await _foodService.fetchRestaurantImages();

      setState(() {
        _allFoods = foods;
        _restaurantImages.addAll(images);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      print('Error loading data: $e');
    }
  }

  Future<void> _buildRestaurantMapping(List<Food> foods) async {
    try {
      final sellerIds = foods.map((f) => f.sellerId).toSet().toList();
      final sellerNames = await _foodService.fetchSellerNames(sellerIds);

      _restaurantToSellerId.clear();
      sellerNames.forEach((sellerId, sellerName) {
        _restaurantToSellerId[sellerName] = sellerId;
      });

      final restaurantNames = ['All', ..._restaurantToSellerId.keys.toList()];

      setState(() {
        _restaurants = restaurantNames;
      });

      print('✅ Loaded ${_restaurants.length - 1} restaurants');
    } catch (e) {
      print('Error building restaurant mapping: $e');
    }
  }

  List<Food> get _filteredFoods {
    if (_selectedRestaurant == 'All') return _allFoods;
    final sellerId = _restaurantToSellerId[_selectedRestaurant];
    return _allFoods.where((f) => f.sellerId == sellerId).toList();
  }

  List<String> get _restaurantsNoAll =>
      _restaurants.where((r) => r != 'All' && r.isNotEmpty).toList();

  // Check if user is logged in
  bool _isUserLoggedIn() {
    final String? uid = sharedPreferences?.getString("uid");
    final String? name = sharedPreferences?.getString("name");
    final String? phone = sharedPreferences?.getString("phone");
    return uid != null && name != null && phone != null;
  }

  // ================= SIDE DRAWER MENU =================
  Widget _buildDrawer() {
    final user = authViewModel.getCurrentUser();

    return Container(
      width: MediaQuery.of(context).size.width * 0.75,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF443EA6),
            Color(0xFF424867),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // User Profile Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.2),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF6C63FF), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: user?.imageUrl != null && user!.imageUrl!.isNotEmpty
                          ? ClipOval(
                        child: Image.network(
                          user.imageUrl!,
                          fit: BoxFit.cover,
                          width: 80,
                          height: 80,
                          errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 40, color: Color(0xFF6C63FF)),
                        ),
                      )
                          : const Icon(Icons.person, size: 40, color: Color(0xFF6C63FF)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.name ?? user?.email?.split('@').first ?? 'Guest User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.phone ?? 'No phone number',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Menu Items
            _buildDrawerItem(
              icon: Icons.home_outlined,
              title: 'Home',
              onTap: () {
                Navigator.pop(context);
              },
            ),
            _buildDrawerItem(
              icon: Icons.shopping_bag_outlined,
              title: 'My Orders',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OrdersHistoryScreen()),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.delivery_dining_outlined,
              title: 'My Deliveries',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DeliveriesListScreen()),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.favorite_border,
              title: 'Favorites',
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to favorites
              },
            ),
            _buildDrawerItem(
              icon: Icons.person_outline,
              title: 'Profile',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.support_agent,
              title: 'Support',
              onTap: () {
                Navigator.pop(context);
                _showSupportDialog();
              },
            ),
            const Spacer(),
            Divider(color: Colors.grey.withOpacity(0.2), height: 1),
            _buildDrawerItem(
              icon: Icons.logout,
              title: 'Logout',
              isLogout: true,
              onTap: () {
                Navigator.pop(context);
                _showLogoutDialog();
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isLogout ? Colors.red : Colors.white, size: 24),
      title: Text(
        title,
        style: TextStyle(
          color: isLogout ? Colors.red : Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      hoverColor: const Color(0xFF6C63FF).withOpacity(0.2),
      splashColor: const Color(0xFF6C63FF).withOpacity(0.3),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              AuthViewModel().logout(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showSupportDialog() {
    showDialog(
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
                  color: const Color(0xFF6C63FF).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.support_agent, size: 48, color: Color(0xFF6C63FF)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Support Center',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Email: support@ubwinza.com\nPhone: +260 XXX XXX XXX',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  minimumSize: const Size(double.infinity, 45),
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
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
                  color: const Color(0xFF6C63FF).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: Color(0xFF6C63FF),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Login Required',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please login to start a delivery',
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
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (c) => const AuthScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Login', style: TextStyle(fontSize: 15)),
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

  void _checkAuthAndStartDelivery() {
    final String? uid = sharedPreferences?.getString("uid");
    final String? name = sharedPreferences?.getString("name");
    final String? phone = sharedPreferences?.getString("phone");

    if (uid != null && name != null && phone != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PackageCreateScreen(googleApiKey: googleApiKey),
        ),
      );
    } else {
      _showLoginRequiredDialog();
    }
  }

  // ================= RESTAURANT HERO SLIDER =================
  Widget _buildRestaurantHeroSlider() {
    final restaurants = _restaurantsNoAll;
    if (restaurants.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Popular Restaurants',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: restaurants.length,
            itemBuilder: (_, index) {
              final restaurant = restaurants[index];
              final imageUrl = _restaurantImages[restaurant] ?? '';

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedRestaurant = restaurant;
                  });
                },
                child: Container(
                  width: 220,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          imageUrl.isNotEmpty ? imageUrl : 'https://via.placeholder.com/400x200',
                          width: 220,
                          height: 160,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 220,
                            height: 160,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.restaurant, size: 40, color: Colors.grey),
                          ),
                        ),
                      ),
                      Container(
                        width: 220,
                        height: 160,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              restaurant,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star, size: 11, color: Color(0xFFFFB800)),
                                const SizedBox(width: 3),
                                Text(
                                  '${_getRestaurantRating(restaurant).toStringAsFixed(1)}',
                                  style: const TextStyle(color: Colors.white, fontSize: 11),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.access_time, size: 11, color: Colors.white),
                                const SizedBox(width: 3),
                                Text(
                                  '${_getRestaurantDeliveryTime(restaurant)} min',
                                  style: const TextStyle(color: Colors.white, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (_selectedRestaurant == restaurant)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: Color(0xFF6C63FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  double _getRestaurantRating(String restaurant) {
    final sellerId = _restaurantToSellerId[restaurant];
    final foods = _allFoods.where((f) => f.sellerId == sellerId).toList();
    if (foods.isEmpty) return 4.5;
    final avgRating = foods.map((f) => f.rating).reduce((a, b) => a + b) / foods.length;
    return avgRating;
  }

  String _getRestaurantDeliveryTime(String restaurant) {
    final sellerId = _restaurantToSellerId[restaurant];
    final foods = _allFoods.where((f) => f.sellerId == sellerId).toList();
    if (foods.isEmpty) return '20-30';
    return '25-35';
  }

  Widget _buildServiceToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedService = 'food');
                _tabController.animateTo(0);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedService == 'food' ? const Color(0xFF6C63FF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.restaurant,
                      color: _selectedService == 'food' ? Colors.white : const Color(0xFF6C63FF),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Food',
                      style: TextStyle(
                        color: _selectedService == 'food' ? Colors.white : const Color(0xFF1A1A2E),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedService = 'delivery');
                _tabController.animateTo(1);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedService == 'delivery' ? const Color(0xFF6C63FF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_shipping,
                      color: _selectedService == 'delivery' ? Colors.white : const Color(0xFF6C63FF),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Delivery',
                      style: TextStyle(
                        color: _selectedService == 'delivery' ? Colors.white : const Color(0xFF1A1A2E),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationBar() {
    return GestureDetector(
      onTap: () async {
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
              initialLocation: context.read<LocationViewModel>().currentLocation,
            );
          },
        );

        if (result != null && result is Map<String, dynamic>) {
          final location = result['location'];
          final address = result['address'] as String;
          if (location != null) {
            context.read<LocationViewModel>().updateLocation(location as LatLng, address);

            if (mounted) {
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
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.location_on, color: Color(0xFF6C63FF), size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Consumer<LocationViewModel>(
                builder: (context, locationVM, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Deliver to',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      Text(
                        locationVM.isLoading ? 'Select location...' : locationVM.currentAddress,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  );
                },
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF6C63FF)),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantChips() {
    if (_restaurants.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _restaurants.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final restaurant = _restaurants[index];
          final isSelected = restaurant == _selectedRestaurant;

          return FilterChip(
            label: Text(
              restaurant,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF1A1A2E),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            selected: isSelected,
            onSelected: (_) {
              setState(() {
                _selectedRestaurant = restaurant;
              });
            },
            backgroundColor: Colors.white,
            selectedColor: const Color(0xFF6C63FF),
            shape: StadiumBorder(
              side: BorderSide(
                color: isSelected ? const Color(0xFF6C63FF) : Colors.grey.shade300,
              ),
            ),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedFoodsSection() {
    final foods = _filteredFoods;

    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (foods.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No items found in this restaurant'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedRestaurant == 'All' ? 'Recommended For You' : 'Menu Items',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              if (_selectedRestaurant != 'All')
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedRestaurant = 'All';
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 30),
                  ),
                  child: const Text(
                    'View All >',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6C63FF)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SafeArea(
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: foods.length,
            itemBuilder: (_, index) {
              final food = foods[index];
              return ProfessionalFoodCard(
                food: food,
                onTap: () {
                  final deliveryProvider = Provider.of<DeliveryProvider>(context, listen: false);
                  deliveryProvider.addSellerAndCalculateFee(
                    sellerId: food.sellerId,
                    rideType: 'motorbike',
                  );

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailsScreen(food: food),
                    ),
                  );
                },
                onAddToCart: () {
                  context.read<CartProvider>().add(food);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${food.name} added to cart', style: TextStyle(color: Colors.white),),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: const Color(0xFF6C63FF),
                    ),
                  );
                },
                onRemoveFromCart: () {
                  final tempCartItem = CartItem(food: food, quantity: 1);
                  context.read<CartProvider>().remove(tempCartItem.uniqueKey);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${food.name} removed from cart', style: TextStyle(color: Colors.white),),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.red.shade600,
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildFoodContent() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: 8),
              _buildRestaurantHeroSlider(),
              const SizedBox(height: 16),
              _buildRestaurantChips(),
              const SizedBox(height: 16),
              _buildFeaturedFoodsSection(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryContent() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_shipping,
                size: 60,
                color: Color(0xFF6C63FF),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Quick Package Delivery',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Send packages anywhere in the city',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _checkAuthAndStartDelivery,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('Start a Delivery', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = _isUserLoggedIn();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8F9FF),
      endDrawerEnableOpenDragGesture: false,
      drawer: isLoggedIn ? _buildDrawer() : null,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'UBWINZA',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6C63FF),
            letterSpacing: 1,
          ),
        ),
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        leading: isLoggedIn
            ? IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFF6C63FF), size: 24),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        )
            : null,
        actions: [
          CartBadgeIcon(
            badgeColor: Colors.red,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
          ),
          const SizedBox(width: 12),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              _buildLocationBar(),
              _buildServiceToggle(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFoodContent(),
          _buildDeliveryContent(),
        ],
      ),
    );
  }
}