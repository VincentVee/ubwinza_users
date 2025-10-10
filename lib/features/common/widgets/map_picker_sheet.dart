import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<LatLng?> showMapPickerSheet(BuildContext context, LatLng initial) {
  return showModalBottomSheet<LatLng>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _MapPicker(initial: initial),
  );
}

class _MapPicker extends StatefulWidget {
  const _MapPicker({required this.initial});
  final LatLng initial;
  @override
  State<_MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<_MapPicker> {
  GoogleMapController? _c;
  LatLng? _picked;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .75,
        child: Column(
          children: [
            Expanded(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: widget.initial, zoom: 15),
                onMapCreated: (c) => _c = c,
                onCameraIdle: () async {
                  final p = await _c!.getVisibleRegion(); // forces camera update
                  // ignore p; we just want camera target below:
                  final cam = await _c!.getZoomLevel(); // still forces update
                },
                onTap: (latLng) => setState(() => _picked = latLng),
                markers: {
                  if (_picked != null) Marker(markerId: const MarkerId('picked'), position: _picked!)
                },
                myLocationEnabled: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton(
                onPressed: _picked == null ? null : () => Navigator.pop(context, _picked),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Use this location', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
