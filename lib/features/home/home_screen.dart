import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:ubwinza_users/features/home/widgets/simple_location_picker.dart';
import 'package:ubwinza_users/features/order/data/presentation/order_history_page.dart';
import '../../core/bootstrap/app_bootstrap.dart';
import '../../core/models/delivery_method.dart';
import '../../core/models/location_model.dart';
import '../../core/services/pref_service.dart';
import '../../global/global_vars.dart';
import '../../view_models/auth_view_model.dart';
// Import the new ProfileScreen
import '../delivery/presentation/deliveries_list_screen.dart';
import '../delivery/presentation/history.dart';
import '../delivery/state/delivery_provider.dart';
import '../maps/nearby_drivers_view_model.dart';
import '../profile/presentation/profile_screen.dart';
import 'widgets/hero_header.dart';


class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  String _vehicle = 'motorbike';

  @override
  void initState() {
    super.initState();
    // The LocationViewModel should be initialized in main.dart via MultiProvider.
    // Reading it here is generally safe if the Provider is above this widget.
  }

  // ================= LOCATION DISPLAY/MENU =================
  Widget _locationDisplay(BuildContext context) {
    return InkWell(
      onTap: () async {
        final boot = AppBootstrap.I;
        // Check if boot is ready before proceeding
        if (!boot.isReady) {
          // You should not call init here if it was done in main.dart,
          // but we keep the logic for robustness.
          await boot.init(googleApiKey: googleApiKey);
        }

        final result = await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (BuildContext context) {
            return SimpleLocationPickerScreen(
              googleApiKey: googleApiKey,
              initialLocation: context.read<LocationViewModel>().currentLocation,
            );
          },
        );

        // Update location if a result is returned
        if (result != null && result is Map<String, dynamic>) {
          final location = result['location'];
          final address = result['address'] as String;
          if (location != null) {
            // Note: The result LatLng type is typically google_maps_flutter.LatLng
            context.read<LocationViewModel>().updateLocation(location as LatLng, address);
          }
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_on_outlined,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 4),

            // =========================================================
            // *** FIX: Use Flexible/Expanded to prevent Row Overflow ***
            // =========================================================
            Flexible(
              child: Consumer<LocationViewModel>(
                builder: (context, locationVM, child) {
                  return Text(
                    locationVM.isLoading
                        ? 'Getting location...'
                        : locationVM.currentAddress,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    // Ensure long addresses don't wrap or push off-screen
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  );
                },
              ),
            ),

            const Icon(
              Icons.expand_more,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ================= PROFILE MENU (UPDATED) =================
  Widget _profileMenu(BuildContext context) {

    return PopupMenuButton<String>(
      color: Color(0xFF020A30),
      onSelected: (value) {
        if (value == 'profile') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ProfileScreen(),
            ),
          );
        } else if (value == 'logout') {
          AuthViewModel().logout(context);
        }
      },

      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.person_outline, color: Colors.yellowAccent),
              SizedBox(width: 8),
              Text('Profile'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 8),
              Text('Logout'),
            ],
          ),
        ),
      ],
      // Use a child for the avatar/icon
      child: Consumer<AuthViewModel>(
        builder: (context, authVM, child) {
          final imageUrl = authVM.getCurrentUser()?.imageUrl;
          return CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white,
            backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                ? NetworkImage(imageUrl)
                : null,
            child: imageUrl == null || imageUrl.isEmpty
                ? const Icon(Icons.person, color: Color(0xFF1A2B7B))
                : null,
          );
        },
      ),
    );
  }

  // ================= BODY (No Change) =================
  Widget _buildBody() {
    return ChangeNotifierProvider(
      key: ValueKey(_vehicle),
      create: (_) => NearbyDriversViewModel(vehicleType: _vehicle),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: HeroHeader(
              vehicleType: _vehicle,
              onPickMotor: () {
                setState(() => _vehicle = 'motorbike');
                PrefsService.I.setDeliveryMethod(DeliveryMethod.motorbike);
                context.read<DeliveryProvider>().setRideType('motorbike');
              },
              onPickBicycle: () {
                setState(() => _vehicle = 'bicycle');
                PrefsService.I.setDeliveryMethod(DeliveryMethod.bicycle);
                context.read<DeliveryProvider>().setRideType('bicycle');
              },
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              delegate: SliverChildListDelegate(
                [
                  _HomeCard(
                    icon: Icons.delivery_dining,
                    title: 'Deliveries',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DeliveriesListScreen(),
                        ),
                      );
                    },
                  ),
                  _HomeCard(
                    icon: Icons.shopping_bag,
                    title: 'Orders',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OrdersHistoryScreen(),
                        ),
                      );
                    },
                  ),
                  _HomeCard(
                    icon: Icons.history,
                    title: 'History',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DeliveryHistoryPage(),
                        ),
                      );
                    },
                  ),
                  _HomeCard(
                    icon: Icons.support_agent,
                    title: 'Support',
                    onTap: () {
                      // TODO: Support action
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= SCAFFOLD (No Change) =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A2B7B),
              Color(0xFF203A43),
              Color(0xFF2C5364),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom Header Row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 1. Location (Now uses Flexible)
                    Flexible(child: _locationDisplay(context)),
                    // 2. Profile/Avatar
                    _profileMenu(context),
                  ],
                ),
              ),
              // Main content body
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }
}

// ... _HomeCard widget remains the same (No Change)
class _HomeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _HomeCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blueGrey,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 40,
              color: const Color(0xFF1A2B7B),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}