import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:ubwinza_users/features/packages/presentation/package_create_screen.dart';

import '../../core/models/current_location.dart';
import '../../core/models/delivery_method.dart';
import '../../core/services/pref_service.dart';
import '../maps/nearby_drivers_view_model.dart';
import 'widgets/drivers_map.dart';
import 'widgets/hero_header.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});
  @override State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  GoogleMapController? _map;
  LatLng? _center;
  String _vehicle = 'motorbike';
  final String googleApiKey = "AIzaSyC24a0-yk2HG6ONDtpbPRlL_lWkxeqqQ2Y";

  @override
  void initState() { super.initState(); _bootstrap(); }

  Future<void> _bootstrap() async {
    final me = await getCurrentLocation();
    setState(() => _center = LatLng(me.lat, me.lng));
  }

  @override
  Widget build(BuildContext context) {
    if (_center == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ChangeNotifierProvider(
      key: ValueKey(_vehicle),
      create: (_) => NearbyDriversViewModel(vehicleType: _vehicle),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: HeroHeader(
                vehicleType: _vehicle,
                onPickMotor: () {
                  setState(() => _vehicle = 'motorbike');
                  PrefsService.I.setDeliveryMethod(DeliveryMethod.motorbike);

                },
                onPickBicycle: () {
                  setState(() => _vehicle = 'bicycle');
                  PrefsService.I.setDeliveryMethod(DeliveryMethod.bicycle);
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'The drivers near you',
                  style: TextStyle(
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
      ),
    );
  }
}
