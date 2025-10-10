import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import '../../drivers/data/nearby_driver_repository.dart';
import 'parcel_view_model.dart';


class ParcelCreateScreen extends StatelessWidget {
  final String userId;
  const ParcelCreateScreen({super.key, required this.userId});


  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ParcelViewModel(),
      child: _ParcelScaffold(userId: userId),
    );
  }
}

class _ParcelScaffold extends StatefulWidget {
  final String userId; const _ParcelScaffold({required this.userId});
  @override State<_ParcelScaffold> createState() => _ParcelScaffoldState();
}


class _ParcelScaffoldState extends State<_ParcelScaffold> {
  GoogleMapController? _map;
  LatLng? _center;
  final _nearbyRepo = NearbyDriverRepository();


  @override
  void initState() { super.initState(); _seed(); }
  Future<void> _seed() async {
    final pos = await Geolocator.getCurrentPosition();
    setState(() => _center = LatLng(pos.latitude, pos.longitude));
  }

  Future<void> _pickOnMap({required bool from}) async {
    if (_center == null) return;
    LatLng chosen = _center!;
    await showModalBottomSheet(context: context, isScrollControlled: true, builder: (c){
      return SizedBox(height: MediaQuery.of(c).size.height*0.8, child: StatefulBuilder(
        builder: (c, setS){
          return Stack(children:[
            GoogleMap(
              initialCameraPosition: CameraPosition(target: chosen, zoom: 15),
              onMapCreated: (gm){},
              onCameraMove: (pos){ setS(()=> chosen = pos.target); },
            ),
            const Center(child: Icon(Icons.location_pin, size: 48, color: Colors.redAccent)),
            Positioned(
              left: 16, right: 16, bottom: 24,
              child: ElevatedButton(onPressed: ()=> Navigator.pop(c), child: const Text('Use this location')),
            ),
          ]);
        },
      ));
    });

    final placemarks = await geo.placemarkFromCoordinates(chosen.latitude, chosen.longitude);
    final line = '${placemarks.first.street ?? ''}, ${placemarks.first.locality ?? ''}';
    final vm = context.read<ParcelViewModel>();
    if (from) {
      vm.setFrom(line, chosen.latitude, chosen.longitude);
    } else {
      vm.setTo(line, chosen.latitude, chosen.longitude);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ParcelViewModel>();
    final theme = Theme.of(context);


    final drivers = (_center != null)
        ? _nearbyRepo.watchNearby(lat: _center!.latitude, lng: _center!.longitude, radiusKm: 5, vehicleType: vm.vehicleType)
        : const Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>.empty();


    return Scaffold(
      appBar: AppBar(title: const Text('Send a parcel')),
      body: _center == null
          ? const Center(child: CircularProgressIndicator())
          : Column(children:[
// map preview with vehicle switch
        SizedBox(
        height: 220,
        child: Stack(children:[
          GoogleMap(
            myLocationEnabled: true,
            initialCameraPosition: CameraPosition(target: _center!, zoom: 14.5),
            onMapCreated: (c){ _map = c; },
          ),
          Positioned(
            right: 12, top: 12,
            child: ToggleButtons(
              isSelected: [vm.vehicleType=='motorbike', vm.vehicleType=='bicycle'],
              onPressed: (i){ vm.setVehicle(i==0? 'motorbike':'bicycle'); },
              children: const [Padding(padding: EdgeInsets.all(8), child: Text('Motorbike')), Padding(padding: EdgeInsets.all(8), child: Text('Bicycle'))],
            ),
          )
        ]),
      ),

      // From / To rows
      Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(children:[
          _AddrTile(label: 'Pickup from', value: vm.fromAddress.isEmpty? 'Choose on map' : vm.fromAddress, onTap: ()=> _pickOnMap(from: true)),
          const SizedBox(height: 8),
          _AddrTile(label: 'Deliver to', value: vm.toAddress.isEmpty? 'Choose on map' : vm.toAddress, onTap: ()=> _pickOnMap(from: false)),
        ]),
      ),


// Note
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: TextField(
          decoration: const InputDecoration(labelText: 'What are we delivering? (optional)'),
          onChanged: vm.setNote,
        ),
      ),
      const SizedBox(height: 8),


// Nearby drivers strip
      SizedBox(
        height: 64,
        child: StreamBuilder(
          stream: drivers,
          builder: (context, snap){
            final cnt = (snap.data?.length ?? 0);
            return Center(child: Text(cnt==0 ? 'Looking for nearby ${vm.vehicleType}s…' : '$cnt nearby ${vm.vehicleType}s online'));
          },
        ),
      ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Estimated: K${vm.fee} / ${vm.distanceKm.toStringAsFixed(1)} km', style: theme.textTheme.titleMedium),
              ElevatedButton(
                onPressed: vm.busy ? null : () async {
                  await vm.createOrder(userId: widget.userId);
                  if (!mounted) return;
                  if (vm.error!=null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(vm.error!))); }
                  else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parcel requested'))); Navigator.pop(context); }
                },
                child: Text(vm.busy? 'Requesting…' : 'Request courier'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ]),
    );
  }
}

class _AddrTile extends StatelessWidget {
  final String label; final String value; final VoidCallback onTap;
  const _AddrTile({required this.label, required this.value, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: const Icon(Icons.place_outlined),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.edit_location_alt),
      onTap: onTap,
    );
  }
}