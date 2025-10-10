import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Show the map picker as a tall bottom sheet like the screenshots.
/// [title] should be "PICKUP ADDRESS" or "DESTINATION ADDRESS".
Future<Map<String, dynamic>?> showMapPickerSheet(
    BuildContext context, {
      required LatLng initial,
      required String title,
    }) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent, // rounded card on top
    builder: (_) => _MapPickerSheet(initial: initial, title: title),
  );
}

class _MapPickerSheet extends StatefulWidget {
  const _MapPickerSheet({required this.initial, required this.title});
  final LatLng initial;
  final String title;

  @override
  State<_MapPickerSheet> createState() => _MapPickerSheetState();
}

class _MapPickerSheetState extends State<_MapPickerSheet> {
  GoogleMapController? _map;
  late LatLng _center;
  String _addressText = '';

  @override
  void initState() {
    super.initState();
    _center = widget.initial;
    _addressText = _fmtAddress(_center);
  }

  String _fmtAddress(LatLng p) {
    // Simple async-free placeholder. Replace with your reverse geocode later.
    return '${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}';
  }

  void _recenter() {
    _map?.animateCamera(CameraUpdate.newLatLng(widget.initial));
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final sheetHeight = h * 0.9; // nice and tall, like the reference

    return SizedBox(
      height: sheetHeight,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: Material(
          color: Colors.white,
          child: Stack(
            children: [
              /// Map
              Positioned.fill(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: widget.initial,
                    zoom: 16,
                  ),
                  onMapCreated: (c) => _map = c,
                  onCameraMove: (pos) {
                    // track the center as user swipes the map
                    _center = pos.target;
                  },
                  onCameraIdle: () {
                    // when camera settles, update the address text
                    setState(() => _addressText = _fmtAddress(_center));
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: false,
                  mapToolbarEnabled: false,
                ),
              ),

              /// Center PIN
              const IgnorePointer(
                child: Center(
                  child: Icon(Icons.location_on, size: 40, color: Colors.red),
                ),
              ),

              /// "Swipe to move map" hint
              Positioned(
                top: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.08),
                          blurRadius: 8,
                        )
                      ],
                    ),
                    child: const Text(
                      'Swipe to move map',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),

              /// Back (close) button
              Positioned(
                left: 16,
                bottom: 200,
                child: FloatingActionButton(
                  heroTag: 'back_btn',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back, color: Colors.black),
                ),
              ),

              /// Recenter button
              Positioned(
                right: 16,
                bottom: 200,
                child: FloatingActionButton(
                  heroTag: 'center_btn',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: _recenter,
                  child: const Icon(Icons.near_me, color: Colors.black),
                ),
              ),

              /// Bottom info panel (title, address row, Done)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(22)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.12),
                        blurRadius: 16,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// Title (bold like the screenshot)
                      Text(
                        widget.title.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 12),

                      /// Selected address row
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border:
                          Border.all(color: Colors.black12, width: 1.2),
                          borderRadius: BorderRadius.circular(14),
                          color: Colors.white,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(.06),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.place_outlined,
                                  color: Colors.black87),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_addressText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Selected location',
                                    style: TextStyle(
                                        color: Colors.black54, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: Colors.black54),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      /// Done button (big & rounded)
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop<Map<String, dynamic>>(context, {
                              'lat': _center.latitude,
                              'lng': _center.longitude,
                              'address': _addressText,
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE53935), // red-ish like sample
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            'Done',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
