import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:ubwinza_users/features/packages/presentation/package_request_screen.dart';

import '../../../core/models/delivery_method.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/pref_service.dart';
import '../../../core/services/places_service.dart';

import '../../common/widgets/place_autocomplete_field.dart';
import '../../maps/map_fullscreen_picker.dart';

class PackageCreateScreen extends StatefulWidget {
  const PackageCreateScreen({super.key, required this.googleApiKey});
  final String googleApiKey;

  @override
  State<PackageCreateScreen> createState() => _PackageCreateScreenState();
}

class _PackageCreateScreenState extends State<PackageCreateScreen> {
  // Controllers
  final _pickupCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _pkgNameCtrl = TextEditingController();

  // Services
  late final PlaceService _places;

  // Map & state
  GoogleMapController? _map;
  LatLng? _me; // current user location
  LatLng? _pickup;
  LatLng? _dest;

  // Directions
  List<LatLng> _routePoints = const [];
  String? _distanceText; // e.g. "8.3 km"
  String? _durationText; // e.g. "16 mins"

  bool _fragile = false;
  DeliveryMethod _method = DeliveryMethod.motorbike;

  // Draggable sheet controller (so we can expand on keyboard)
  final _sheetCtrl = DraggableScrollableController();
  double _lastInset = 0;

  @override
  void initState() {
    super.initState();
    _places = PlaceService(widget.googleApiKey);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final pos = await LocationService.current();
    final saved = await PrefsService.I.getDeliveryMethod();
    setState(() {
      _me = LatLng(pos.latitude, pos.longitude);
      _method = saved;
    });
  }

  // === Helpers ===
  Future<void> _flyTo(LatLng target) async {
    await _map?.animateCamera(CameraUpdate.newLatLng(target));
  }

  Set<Marker> get _markers {
    final m = <Marker>{};
    if (_pickup != null) {
      m.add(Marker(
        markerId: const MarkerId('pickup'),
        position: _pickup!,
        infoWindow: const InfoWindow(title: 'Pickup'),
      ));
    }
    if (_dest != null) {
      m.add(Marker(
        markerId: const MarkerId('dest'),
        position: _dest!,
        infoWindow: const InfoWindow(title: 'Destination'),
      ));
    }
    return m;
  }

  Set<Polyline> get _polylines {
    if (_routePoints.isEmpty) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: _routePoints,
        width: 6,
        color: Colors.green, // nice green route
        endCap: Cap.roundCap,
        startCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    };
  }

  // === Directions ===
  Future<void> _updateRoute() async {
    if (_pickup == null || _dest == null) {
      setState(() {
        _routePoints = const [];
        _distanceText = null;
        _durationText = null;
      });
      return;
    }
    try {
      final res = await _fetchDirections(
        origin: _pickup!,
        destination: _dest!,
        apiKey: widget.googleApiKey,
      );
      setState(() {
        _routePoints = res.points;
        _distanceText = res.distanceText;
        _durationText = res.durationText;
      });

      // Fit the camera to the route
      if (_map != null && _routePoints.length >= 2) {
        final bounds = _boundsFromLatLngList(_routePoints);
        await _map!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 60),
        );
      }
    } catch (_) {
      // quietly fail to straight line if directions fail
      setState(() {
        _routePoints = [_pickup!, _dest!];
        _distanceText = null;
        _durationText = null;
      });
    }
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double? x0, x1, y0, y1;
    for (final latLng in list) {
      if (x0 == null) {
        x0 = x1 = latLng.latitude;
        y0 = y1 = latLng.longitude;
      } else {
        if (latLng.latitude > x1!) x1 = latLng.latitude;
        if (latLng.latitude < x0) x0 = latLng.latitude;
        if (latLng.longitude > y1!) y1 = latLng.longitude;
        if (latLng.longitude < y0!) y0 = latLng.longitude;
      }
    }
    return LatLngBounds(southwest: LatLng(x0!, y0!), northeast: LatLng(x1!, y1!));
  }

  // === Place pick results (autocomplete) ===
  Future<void> _onPickupPicked(PlaceDetail d) async {
    setState(() {
      _pickup = d.latLng;
      _pickupCtrl.text = d.address;
    });
    _flyTo(d.latLng);
    _updateRoute();
  }

  Future<void> _onDestPicked(PlaceDetail d) async {
    setState(() {
      _dest = d.latLng;
      _destCtrl.text = d.address;
    });
    _flyTo(d.latLng);
    _updateRoute();
  }

  Future<void> _pickOnMap({required bool forPickup}) async {
    // Clear the corresponding text when opening (as requested)
    setState(() {
      if (forPickup) {
        _pickupCtrl.clear();
      } else {
        _destCtrl.clear();
      }
    });

    final initial = forPickup ? (_pickup ?? _me!) : (_dest ?? _me!);

    final result = await showFullScreenMapPicker(
      context,
      initial: initial,
      title: forPickup ? 'Pickup Address' : 'Destination Address',
    );
    if (result == null) return;

    final ll = LatLng(
      (result['lat'] as num).toDouble(),
      (result['lng'] as num).toDouble(),
    );
    final addr = (result['address'] as String?) ?? '';

    setState(() {
      if (forPickup) {
        _pickup = ll;
        _pickupCtrl.text = addr;
      } else {
        _dest = ll;
        _destCtrl.text = addr;
      }
    });
    _flyTo(ll);
    _updateRoute();
  }

  // === Delivery method picker ===
  Future<void> _chooseMethod() async {
    final picked = await showDialog<DeliveryMethod>(
      context: context,
      builder: (_) => _MethodDialog(current: _method),
    );
    if (picked == null) return;
    setState(() => _method = picked);
    await PrefsService.I.setDeliveryMethod(picked);
  }

  bool get _canContinue =>
      _pickupCtrl.text.trim().isNotEmpty &&
          _destCtrl.text.trim().isNotEmpty &&
          _pickup != null &&
          _dest != null &&
          _pkgNameCtrl.text.trim().isNotEmpty;

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _destCtrl.dispose();
    _pkgNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_me == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // Auto-expand the sheet when keyboard opens (typing in any field)
    if (bottomInset > 0 && _lastInset == 0 && _sheetCtrl.isAttached) {
      _sheetCtrl.animateTo(
        0.72,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
    _lastInset = bottomInset;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Send a Package'),
        backgroundColor: Color(0xFF1A2B7B),
        foregroundColor: Colors.white,
      ),
      extendBody: true,
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _me!, zoom: 13.5),
            onMapCreated: (c) => _map = c,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: _markers,
            polylines: _polylines,
            compassEnabled: false,
            zoomControlsEnabled: false,
          ),

          // Distance chip (shows when we have a route)
          if (_distanceText != null || _durationText != null)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.12),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.route, size: 18,color: Colors.black,),
                      const SizedBox(width: 8),
                      Text(
                        [
                          if (_distanceText != null) _distanceText!,
                          if (_durationText != null) _durationText!,
                        ].join(' • '),
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Draggable full-width bottom modal
          DraggableScrollableSheet(
            controller: _sheetCtrl,
            initialChildSize: 0.34,
            minChildSize: 0.25,
            maxChildSize: 0.92,
            snap: true,
            snapSizes: const [0.34, 0.72, 0.92],
            builder: (context, scrollCtrl) {
              return Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    controller: scrollCtrl,
                    padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottomInset),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Drag handle
                        Center(
                          child: Container(
                            width: 42,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            margin: const EdgeInsets.only(bottom: 12),
                          ),
                        ),

                        // === Pickup
                        _FieldTheme(
                          child: PlaceAutocompleteField(
                            controller: _pickupCtrl,
                            service: _places,
                            label: 'Pickup Address',
                            onPlacePicked: _onPickupPicked,
                            onMapTap: () => _pickOnMap(forPickup: true),
                            onClear: () {
                              setState(() {
                                _pickup = null;
                                _pickupCtrl.clear();
                              });
                              _updateRoute();
                            },
                          ),
                        ),
                        const SizedBox(height: 14),

                        // === Destination
                        _FieldTheme(
                          child: PlaceAutocompleteField(
                            controller: _destCtrl,
                            service: _places,
                            label: 'Destination Address',
                            onPlacePicked: _onDestPicked,
                            onMapTap: () => _pickOnMap(forPickup: false),
                            onClear: () {
                              setState(() {
                                _dest = null;
                                _destCtrl.clear();
                              });
                              _updateRoute();
                            },
                          ),
                        ),
                        const SizedBox(height: 14),

                        // === Package name + Fragile
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: _LabeledField(
                                label: 'Package Name',
                                controller: _pkgNameCtrl,
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 140,
                              child: _FragileSwitch(
                                value: _fragile,
                                onChanged: (v) => setState(() => _fragile = v),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // === Current method (tap to change)
                        const Text(
                          'Current delivery method (tap to change)',
                          style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _chooseMethod,
                          borderRadius: BorderRadius.circular(12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  _method == DeliveryMethod.motorbike
                                      ? 'images/bike.jpg'
                                      : 'images/cycling.webp',
                                  width: 92,
                                  height: 64,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                _method == DeliveryMethod.motorbike
                                    ? Icons.two_wheeler
                                    : Icons.pedal_bike,
                                color: Colors.black87,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _method == DeliveryMethod.motorbike
                                    ? 'Motor bike'
                                    : 'Bicycle',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // === Continue

                    SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _canContinue
                                ? () {
                              showPackageRequestModal(
                                context: context,
                                pickupAddress: _pickupCtrl.text,
                                pickupLatLng: _pickup!,
                                destinationAddress: _destCtrl.text,
                                destinationLatLng: _dest!,
                                fragile: _fragile,
                                packageName: _pkgNameCtrl.text,
                                deliveryMethod:
                                _method == DeliveryMethod.motorbike ? 'Motorbike' : 'Bicycle', places: _places,
                              );
                            }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF1A2B7B),
                              disabledBackgroundColor: Colors.black12,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Continue',
                                style: TextStyle(fontSize: 18)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------- HTTP + Polyline Helpers ----------

class _DirectionsResult {
  _DirectionsResult({
    required this.points,
    required this.distanceText,
    required this.durationText,
  });

  final List<LatLng> points;
  final String? distanceText;
  final String? durationText;
}

Future<_DirectionsResult> _fetchDirections({
  required LatLng origin,
  required LatLng destination,
  required String apiKey,
}) async {
  final url = Uri.parse(
    'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=driving'
        '&key=$apiKey',
  );

  final resp = await http.get(url);
  if (resp.statusCode != 200) {
    throw Exception('Directions failed');
  }
  final data = json.decode(resp.body) as Map<String, dynamic>;
  final routes = data['routes'] as List?;
  if (routes == null || routes.isEmpty) {
    throw Exception('No route');
  }

  // Decode overview polyline
  final overview = routes.first['overview_polyline']?['points'] as String?;
  final points = overview == null ? <LatLng>[] : _decodePolyline(overview);

  // Distance & duration from first leg (if available)
  String? distanceText;
  String? durationText;
  final legs = routes.first['legs'] as List?;
  if (legs != null && legs.isNotEmpty) {
    final leg = legs.first as Map<String, dynamic>;
    distanceText = leg['distance']?['text'] as String?;
    durationText = leg['duration']?['text'] as String?;
  }

  return _DirectionsResult(
    points: points,
    distanceText: distanceText,
    durationText: durationText,
  );
}

/// Standard Google encoded polyline decoder.
List<LatLng> _decodePolyline(String encoded) {
  List<LatLng> poly = [];
  int index = 0, len = encoded.length;
  int lat = 0, lng = 0;

  while (index < len) {
    int b, shift = 0, result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lng += dlng;

    poly.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return poly;
}

// ---------- Small, focused widgets ----------

/// Wraps children so any popup/dropdown (e.g., TypeAhead inside PlaceAutocompleteField)
/// uses a white card with dark text without touching your global theme.
class _FieldTheme extends StatelessWidget {
  const _FieldTheme({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        cardColor: Colors.white,
        dialogBackgroundColor: Colors.white,
        textTheme: base.textTheme.apply(bodyColor: Colors.black),
        listTileTheme: const ListTileThemeData(textColor: Colors.black),
      ),
      child: child,
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.controller});
  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.black87, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            hintText: 'Enter ${label.toLowerCase()}',
            hintStyle: const TextStyle(color: Colors.black54),
            prefixIcon: const Icon(Icons.inventory_2_outlined,
                color: Colors.grey),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black87),
            ),
          ),
        ),
      ],
    );
  }
}

class _FragileSwitch extends StatelessWidget {
  const _FragileSwitch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Is Fragile?',
        labelStyle: TextStyle(
          color: Colors.black,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(Icons.inbox_outlined, color: Colors.grey),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Color(0xFF1A2B7B),
          ),
        ],
      ),
    );
  }
}

class _MethodDialog extends StatelessWidget {
  const _MethodDialog({required this.current});
  final DeliveryMethod current;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select delivery method'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<DeliveryMethod>(
            value: DeliveryMethod.motorbike,
            groupValue: current,
            title: const Text('Motor bike'),
            secondary: const Icon(Icons.two_wheeler),
            onChanged: (v) => Navigator.pop(context, v),
          ),
          RadioListTile<DeliveryMethod>(
            value: DeliveryMethod.bicycle,
            groupValue: current,
            title: const Text('Bicycle'),
            secondary: const Icon(Icons.pedal_bike),
            onChanged: (v) => Navigator.pop(context, v),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
      ],
    );
  }
}
