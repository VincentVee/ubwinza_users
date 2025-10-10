import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart' as geo;

/// Push a full-screen picker page.
/// [title] e.g. "Pickup Address" / "Destination Address".
Future<Map<String, dynamic>?> showFullScreenMapPicker(
    BuildContext context, {
      required LatLng initial,
      required String title,
    }) {
  return Navigator.push<Map<String, dynamic>>(
    context,
    MaterialPageRoute(
      builder: (_) => _FullScreenMapPicker(initial: initial, title: title),
      fullscreenDialog: true,
    ),
  );
}

class _FullScreenMapPicker extends StatefulWidget {
  const _FullScreenMapPicker({required this.initial, required this.title});
  final LatLng initial;
  final String title;

  @override
  State<_FullScreenMapPicker> createState() => _FullScreenMapPickerState();
}

class _FullScreenMapPickerState extends State<_FullScreenMapPicker> {
  GoogleMapController? _map;
  late LatLng _center;
  String? _address; // human readable
  bool _revLoading = false;

  @override
  void initState() {
    super.initState();
    _center = widget.initial;
    _reverseGeocode(_center);
  }

  Future<void> _reverseGeocode(LatLng p) async {
    setState(() {
      _revLoading = true;
    });
    try {
      final placemarks =
      await geo.placemarkFromCoordinates(p.latitude, p.longitude);
      if (placemarks.isNotEmpty) {
        final m = placemarks.first;
        // Compose a nice readable address
        final pieces = [
          _join([m.name, m.street]),
          _join([m.subLocality, m.locality]),
          _join([m.administrativeArea, m.postalCode]),
          m.country
        ].where((e) => e != null && e!.trim().isNotEmpty).map((e) => e!).toList();
        setState(() => _address = pieces.join(', '));
      } else {
        setState(() => _address = '${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}');
      }
    } catch (_) {
      // Fallback to coords if geocoder fails
      setState(() => _address =
      '${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}');
    } finally {
      if (mounted) setState(() => _revLoading = false);
    }
  }

  String? _join(List<String?> parts) {
    final filtered = parts.where((e) => e != null && e!.trim().isNotEmpty).map((e) => e!).toList();
    if (filtered.isEmpty) return null;
    return filtered.join(' ');
  }

  void _recenter() {
    _map?.animateCamera(CameraUpdate.newLatLng(widget.initial));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // edges look cleaner
      body: Stack(
        children: [
          // MAP
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: widget.initial,
                zoom: 16,
              ),
              onMapCreated: (c) => _map = c,
              onCameraMove: (pos) => _center = pos.target,
              onCameraIdle: () => _reverseGeocode(_center),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
            ),
          ),

          // Center pin
          const IgnorePointer(
            child: Center(
              child: Icon(Icons.location_on, size: 44, color: Colors.red),
            ),
          ),

          // Top controls
          SafeArea(
            child: Row(
              children: [
                const SizedBox(width: 12),
                // Back
                FloatingActionButton(
                  heroTag: 'back_btn',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back, color: Colors.black),
                ),
                const Spacer(),
                // Recenter
                FloatingActionButton(
                  heroTag: 'center_btn',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: _recenter,
                  child: const Icon(Icons.near_me, color: Colors.black),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),

          // Bottom info + action
          Align(
            alignment: Alignment.bottomCenter,
            child: Positioned(
              bottom: 0,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.16),
                      blurRadius: 14,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black12, width: 1.2),
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
                                if (_revLoading)
                                  const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                else
                                  Text(
                                    _address ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
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
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _address == null
                            ? null
                            : () {
                          Navigator.pop<Map<String, dynamic>>(context, {
                            'lat': _center.latitude,
                            'lng': _center.longitude,
                            'address': _address!,
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF1A2B7B),
                          disabledBackgroundColor: Colors.black12,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
