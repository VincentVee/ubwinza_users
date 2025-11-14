import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ubwinza_users/features/delivery/presentation/deliveries_tracking_view.dart';
import 'package:ubwinza_users/features/delivery/state/delivery_provider.dart';
import 'package:ubwinza_users/features/order/data/presentation/order_tracking_view.dart';
import '../../core/models/current_location.dart';
import '../../core/models/delivery_method.dart';
import '../../core/services/pref_service.dart';
import '../delivery/presentation/deliveries_list_screen.dart';
import '../maps/nearby_drivers_view_model.dart';
import 'widgets/drivers_map.dart';
import 'widgets/hero_header.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  GoogleMapController? _map;
  LatLng? _center;
  String _vehicle = 'motorbike';
  int _selectedIndex = 0;
  final String googleApiKey = "AIzaSyC24a0-yk2HG6ONDtpbPRlL_lWkxeqqQ2Y";

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final me = await getCurrentLocation();
    setState(() => _center = LatLng(me.lat, me.lng));
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildBody() {
    if (_selectedIndex == 0) {
      if (_center == null) {
        return const Center(child: CircularProgressIndicator());
      }

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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'The drivers near you',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: DriversMap(
                initial: _center!,
                onCreated: (c) => _map = c,
              ),
            ),
          ],
        ),
      );
    } else if (_selectedIndex == 1) {
      return const DeliveriesListScreen();
    } else if (_selectedIndex == 2) {
      return const OrdersTrackingView();
    } else {
      return const Center(child: Text('History Page'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF1A2B7B),
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amberAccent,
        unselectedItemColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.delivery_dining_outlined),
            activeIcon: Icon(Icons.delivery_dining),
            label: 'Deliveries',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_outlined),
            activeIcon: Icon(Icons.shopping_bag),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}

