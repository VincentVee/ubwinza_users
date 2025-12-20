// lib/features/home/ui/widgets/hero_header.dart

import 'package:flutter/material.dart';
import 'package:ubwinza_users/features/food/ui/food_home_screen.dart';
import 'package:ubwinza_users/global/global_instances.dart';
import 'package:ubwinza_users/global/global_vars.dart';
import '../../packages/presentation/package_create_screen.dart';
import 'choice_tile.dart';

class HeroHeader extends StatelessWidget {
  final VoidCallback onPickMotor;
  final VoidCallback onPickBicycle;
  final String vehicleType;

  // MODIFIED: Widget is now nullable and defaults to a Sizedbox.shrink()
  final Widget? locationHeader;

  const HeroHeader({
    super.key,
    required this.onPickMotor,
    required this.onPickBicycle,
    required this.vehicleType,
    this.locationHeader, // <-- NO LONGER REQUIRED
  });

  @override
  Widget build(BuildContext context) {
    final isMotor = vehicleType == 'motorbike';

    return Padding(
      padding: const EdgeInsets.all(0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A2B7B),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 10, offset: const Offset(0, 6))],
        ),
        // Adjusted padding to account for the content inside
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // Ubwinza Title
            // const Row(children: [
            //   Text('Ubwinza', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            // ]),

            // Location Header: Only show if provided
            if (locationHeader != null) ...[
              const SizedBox(height: 4),
              locationHeader!, // <-- Display the optional widget
              const SizedBox(height: 14),
            ] else
              const SizedBox(height: 14), // Maintain spacing if no location header is present


            // Vehicle Picker (Bike/Car)
            Row(children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    color: isMotor ? Colors.grey : null,
                  ),
                  child: ChoiceTile(
                    selected: isMotor,
                    label: 'Bike Delivery',
                    image: 'images/bike-delivery.jpg',
                    onTap: onPickMotor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    color: isMotor ? null : Colors.grey,
                  ),
                  child: ChoiceTile(
                    selected: !isMotor,
                    label: 'Car Delivery coming soon',
                    image: 'images/delivery-truck.avif',
                    onTap: ()=> null,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 18),

            // Delivery Items Text
            const Text(
              'We can deliver the following items right at your doorstep:',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 10),

            // Clickable delivery items (Packages, Food)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => PackageCreateScreen(googleApiKey: googleApiKey)));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.local_shipping, color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text('Packages', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                        Spacer(),
                        Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
                      ],
                    ),
                  ),
                ),

                GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const FoodHomeScreen()));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.fastfood, color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text('Food', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                        Spacer(),
                        Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}