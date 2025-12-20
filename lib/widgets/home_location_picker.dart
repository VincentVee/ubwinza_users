// lib/shared/widgets/home_location_picker.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ubwinza_users/shared/widgets/delivery_location_sheet.dart';

// --- Data Model Dependency ---
class DeliveryLocationResult {
  final LatLng latLng;
  final String? address;
  DeliveryLocationResult(this.latLng, {this.address});
}
// -----------------------------

class HomeLocationPicker extends StatefulWidget {
  final Function(DeliveryLocationResult) onLocationSelected;

  const HomeLocationPicker({
    super.key,
    required this.onLocationSelected,
  });

  @override
  State<HomeLocationPicker> createState() => _HomeLocationPickerState();
}

class _HomeLocationPickerState extends State<HomeLocationPicker> {
  String _currentLocationDisplay = 'Tenth Ave 85';
  LatLng? _lastSelectedLatLng;

  void _openLocationSheet() async {
    final result = await showDeliveryLocationSheet(
      context: context,
      initialTarget: _lastSelectedLatLng,
    );

    if (result != null) {
      setState(() {
        _lastSelectedLatLng = result.latLng;
        _currentLocationDisplay = result.address ?? 'Location Selected';
      });
      widget.onLocationSelected(result as DeliveryLocationResult);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _openLocationSheet,
      child: Container(
        height: 60,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Location Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5A3D),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.person_pin_circle_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),

            const SizedBox(width: 12),

            // Location Text
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Location',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _currentLocationDisplay,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Map Button
            SizedBox(
              height: 40,
              child: TextButton(
                onPressed: _openLocationSheet,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.grey[100],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Map',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}