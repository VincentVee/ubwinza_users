// lib/features/packages/presentation/package_request_modal.dart
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../global/global_vars.dart';
import '../../maps/map_fullscreen_picker.dart';
import '../../../core/services/places_service.dart';
import '../../../core/models/request_model.dart';
import '../../../core/services/request_service.dart';
import '../../maps/presentation/request_map_screen.dart';
import '../../../core/services/fare_service.dart';

Future<void> showPackageRequestModal({
  required BuildContext context,
  required PlaceService places,
  required String pickupAddress,
  required LatLng pickupLatLng,
  required String destinationAddress,
  required LatLng destinationLatLng,
  required bool fragile,
  required String packageName,
  required String deliveryMethod,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PackageRequestModal(
      places: places,
      pickupAddress: pickupAddress,
      destinationAddress: destinationAddress,
      pickupLatLng: pickupLatLng,
      destinationLatLng: destinationLatLng,
      fragile: fragile,
      packageName: packageName,
      deliveryMethod: deliveryMethod,
    ),
  );
}

class PackageRequestModal extends StatefulWidget {
  final PlaceService places;
  final String pickupAddress;
  final String destinationAddress;
  final LatLng pickupLatLng;
  final LatLng destinationLatLng;
  final bool fragile;
  final String packageName;
  final String deliveryMethod;

  const PackageRequestModal({
    super.key,
    required this.places,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.pickupLatLng,
    required this.destinationLatLng,
    required this.fragile,
    required this.packageName,
    required this.deliveryMethod,
  });

  @override
  State<PackageRequestModal> createState() => _PackageRequestModalState();
}

class _PackageRequestModalState extends State<PackageRequestModal> {
  final _senderPhoneCtrl = TextEditingController();
  final _receiverPhoneCtrl = TextEditingController();
  final _pickupCtrl = TextEditingController();
  final _destCtrl = TextEditingController();

  double? totalCharge;
  List<File> pickupPhotos = [];
  List<File> destinationPhotos = [];

  late LatLng _currentPickupLatLng;
  late LatLng _currentDestinationLatLng;

  bool _isSubmitting = false;
  final FareService _fareService = FareService();

  String get _vehicleType => widget.deliveryMethod.toLowerCase();

  @override
  void initState() {
    super.initState();
    _pickupCtrl.text = widget.pickupAddress;
    _destCtrl.text = widget.destinationAddress;
    _currentPickupLatLng = widget.pickupLatLng;
    _currentDestinationLatLng = widget.destinationLatLng;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSenderPhone();
      _calculateAndUpdatePrice();
    });

    _senderPhoneCtrl.addListener(() => setState(() {}));
    _receiverPhoneCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _senderPhoneCtrl.dispose();
    _receiverPhoneCtrl.dispose();
    _pickupCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  // -------------------- SharedPrefs Phone --------------------

  Future<void> _loadSenderPhone() async {
    final prefs = sharedPreferences;
    if (prefs == null) return;
    final keys = <String>['phone', 'phoneNumber', 'mobile', 'msisdn'];
    for (final k in keys) {
      final v = prefs.getString(k);
      if (v != null && v.trim().isNotEmpty) {
        if (!mounted) return;
        setState(() => _senderPhoneCtrl.text = v.trim());
        break;
      }
    }
  }

  Future<void> _editSenderNumber() async {
    final ctrl = TextEditingController(text: _senderPhoneCtrl.text);

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2B7B),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        contentTextStyle: const TextStyle(color: Colors.white),
        title: const Text('Enter Sender Number'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'e.g. 0977 123 456 or +260 977 123 456',
            hintStyle: TextStyle(color: Colors.white70),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              final normalized = _normalizeZambiaPhone(ctrl.text.trim());
              if (_isValidZambiaPhone(normalized)) {
                Navigator.pop(context, normalized);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid Zambian number')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A2B7B)),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() => _senderPhoneCtrl.text = result);
      await sharedPreferences?.setString('phone', result);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sender number saved')),
      );
    }
  }

  String _normalizeZambiaPhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('2609') && digits.length == 12) return '+$digits';
    if (digits.startsWith('09') && digits.length == 10) return '+260${digits.substring(1)}';
    if (digits.startsWith('9') && digits.length == 9) return '+260$digits';
    if (input.startsWith('+2609') && digits.length == 12) return input;
    return input;
  }

  bool _isValidZambiaPhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('260')) return RegExp(r'^2609\d{8}$').hasMatch(digits);
    if (digits.startsWith('09')) return RegExp(r'^09\d{8}$').hasMatch(digits);
    if (digits.startsWith('9')) return RegExp(r'^9\d{8}$').hasMatch(digits);
    return false;
  }

  // -------------------- Pricing --------------------

  Future<void> _calculateAndUpdatePrice() async {
    final charge = await _estimateCharge();
    if (mounted) {
      setState(() => totalCharge = charge);
    }
  }

  Future<double> _estimateCharge() async {
    if (!_isValidLatLng(_currentPickupLatLng) ||
        !_isValidLatLng(_currentDestinationLatLng)) {
      return 0.0;
    }

    final baseFare = await _fareService.getBaseFare(_vehicleType);
    final pricePerKm = await _fareService.getPricePerKm(_vehicleType);

    final distance = _km(_currentPickupLatLng, _currentDestinationLatLng);

    // Debug logging
    print('📏 Calculated distance: ${distance.toStringAsFixed(2)} km');
    print('💰 Base fare: $baseFare, Price per km: $pricePerKm');

    final total = baseFare + (distance * pricePerKm);
    print('💵 Total charge: $total');

    return total;
  }

  bool _isValidLatLng(LatLng p) =>
      p.latitude >= -90 && p.latitude <= 90 && p.longitude >= -180 && p.longitude <= 180;

  double _km(LatLng a, LatLng b) {
    const R = 6371.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLng = _deg2rad(b.longitude - a.longitude);
    final la1 = _deg2rad(a.latitude);
    final la2 = _deg2rad(b.latitude);
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(la1) * cos(la2) * sin(dLng / 2) * sin(dLng / 2);
    return R * 2 * atan2(sqrt(h), sqrt(1 - h));
  }

  double _deg2rad(double deg) => deg * (pi / 180);

  bool get _isFormValid =>
      _pickupCtrl.text.trim().isNotEmpty &&
          _destCtrl.text.trim().isNotEmpty &&
          _senderPhoneCtrl.text.trim().isNotEmpty &&
          _receiverPhoneCtrl.text.trim().isNotEmpty &&
          _isValidLatLng(_currentPickupLatLng) &&
          _isValidLatLng(_currentDestinationLatLng);

  // -------------------- Contacts --------------------

  Future<void> _pickContact(TextEditingController controller) async {
    final permissionStatus = await Permission.contacts.request();
    if (!permissionStatus.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contacts permission is required')),
      );
      return;
    }

    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withThumbnail: false,
    );
    if (!mounted) return;

    final selected = await showModalBottomSheet<Contact>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) => _ContactListBottomSheet(contacts: contacts),
    );

    if (selected != null && selected.phones.isNotEmpty) {
      setState(() => controller.text = selected.phones.first.number);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Contact added: ${selected.displayName}')),
      );
    } else if (selected != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number found for this contact')),
      );
    }
  }

  // -------------------- Images --------------------

  Future<void> _pickImage(bool isPickup) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource?>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      if (source == ImageSource.gallery) {
        final List<XFile> picked = await picker.pickMultiImage(
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 80,
        );
        if (picked.isNotEmpty) {
          setState(() {
            if (isPickup) {
              pickupPhotos.addAll(picked.map((x) => File(x.path)));
            } else {
              destinationPhotos.addAll(picked.map((x) => File(x.path)));
            }
          });
        }
      } else {
        final XFile? photo = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 80,
        );
        if (photo != null) {
          setState(() {
            if (isPickup) {
              pickupPhotos.add(File(photo.path));
            } else {
              destinationPhotos.add(File(photo.path));
            }
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking images: $e')),
      );
    }
  }

  void _removeImage(bool isPickup, int index) {
    setState(() {
      if (isPickup) {
        pickupPhotos.removeAt(index);
      } else {
        destinationPhotos.removeAt(index);
      }
    });
  }

  // -------------------- Map pick & Autocomplete --------------------

  Future<void> _pickAddress(bool isPickup) async {
    final selected = await showFullScreenMapPicker(
      context,
      initial: isPickup ? _currentPickupLatLng : _currentDestinationLatLng,
      title: isPickup ? 'Pickup Address' : 'Destination Address',
    );
    if (selected == null) return;

    final lat = (selected['lat'] as num).toDouble();
    final lng = (selected['lng'] as num).toDouble();
    final addr = (selected['address'] as String?) ?? '';

    setState(() {
      if (isPickup) {
        _pickupCtrl.text = addr;
        _currentPickupLatLng = LatLng(lat, lng);
      } else {
        _destCtrl.text = addr;
        _currentDestinationLatLng = LatLng(lat, lng);
      }
    });
    _calculateAndUpdatePrice();
  }

  // -------------------- Submit --------------------

  Future<void> _submitRequest() async {
    if (!_isFormValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields correctly')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final prefs = sharedPreferences;
      final String? userId = prefs?.getString("uid");
      final String? userName = prefs?.getString("name");
      final String? userImage = prefs?.getString("imageUrl");
      final String? userPhone = prefs?.getString("phone");

      if (userId == null || userName == null || userImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User info missing. Please login again.')),
        );
        return;
      }

      final estimatedFare = totalCharge ?? 0.0;

      final req = RideRequest(
        id: '',
        userId: userId,
        userName: userName,
        userImage: userImage,
        userPhone: (userPhone ?? _senderPhoneCtrl.text).trim(),
        pickupAddress: _pickupCtrl.text.trim(),
        pickupLat: _currentPickupLatLng.latitude,
        pickupLng: _currentPickupLatLng.longitude,
        destinationAddress: _destCtrl.text.trim(),
        destinationLat: _currentDestinationLatLng.latitude,
        destinationLng: _currentDestinationLatLng.longitude,
        status: 'pending',
        vehicleType: _vehicleType,
        estimatedFare: estimatedFare,
        createdAt: DateTime.now(),
      );

      final String requestId = await RequestService().createRideRequest(req);
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RequestMapScreen(
            requestId: requestId,
            pickupAddress: _pickupCtrl.text.trim(),
            destinationAddress: _destCtrl.text.trim(),
            pickupLatLng: _currentPickupLatLng,
            destinationLatLng: _currentDestinationLatLng,
            vehicleType: _vehicleType,
          ),
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request sent. Finding $_vehicleType drivers...')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send request: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // -------------------- UI --------------------

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF1A2B7B);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // Handle
              Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(top: 16, bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const Text(
                'Package Delivery Details',
                style: TextStyle(
                  color: themeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),

              // Delivery method chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _vehicleType == 'motorbike' ? Icons.two_wheeler : Icons.pedal_bike,
                      color: themeColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Delivery Method: ${widget.deliveryMethod}',
                      style: TextStyle(
                        color: themeColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _sectionHeader('Pickup Location'),
                        const SizedBox(height: 8),
                        _addressField(label: 'Pickup Address', controller: _pickupCtrl, isPickup: true),
                        const SizedBox(height: 12),
                        _editablePhoneField(controller: _senderPhoneCtrl, onEdit: _editSenderNumber),
                        const SizedBox(height: 12),
                        _attachButton('Attach pickup photos', true),
                        if (pickupPhotos.isNotEmpty) _photoPreview(pickupPhotos, true),

                        const Divider(height: 30),

                        _sectionHeader('Destination Location'),
                        const SizedBox(height: 8),
                        _addressField(label: 'Destination Address', controller: _destCtrl, isPickup: false),
                        const SizedBox(height: 12),
                        _contactField('Receiver phone number', _receiverPhoneCtrl),
                        const SizedBox(height: 12),
                        _attachButton('Attach destination photos', false),
                        if (destinationPhotos.isNotEmpty) _photoPreview(destinationPhotos, false),

                        const SizedBox(height: 20),
                        Text(
                          'Estimated charge: K${totalCharge?.toStringAsFixed(2) ?? '0.00'}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
                        ),
                        SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 120), // Space for the button
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Fixed submit button at bottom
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomInset + 16,
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isFormValid && !_isSubmitting ? _submitRequest : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isFormValid && !_isSubmitting ? themeColor : Colors.grey,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                      : Text('Request ${_vehicleType.toUpperCase()} Delivery',
                      style: const TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ),

          if (_isSubmitting)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Center(
      child: Text(text,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black54)),
    ),
  );

  Widget _addressField({
    required String label,
    required TextEditingController controller,
    required bool isPickup,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        Theme(
          data: theme.copyWith(
            cardColor: Colors.white,
            dialogBackgroundColor: Colors.white,
            textTheme: theme.textTheme.apply(bodyColor: Colors.black),
            listTileTheme: const ListTileThemeData(textColor: Colors.black),
          ),
          child: TypeAheadField<Map<String, dynamic>>(
            suggestionsCallback: (pattern) async {
              if (pattern.trim().isEmpty) return [];
              return await widget.places.fetchAutocomplete(pattern);
            },
            itemBuilder: (context, suggestion) => ListTile(
              dense: true,
              leading: const Icon(Icons.location_on_outlined, color: Colors.black54),
              title: Text(
                suggestion['description'] ?? '',
                style: const TextStyle(color: Colors.black),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            onSelected: (suggestion) async {
              final placeId = suggestion['place_id'] as String?;
              if (placeId == null) return;
              final info = await widget.places.detail(placeId);
              setState(() {
                controller.text = info.address;
                if (isPickup) {
                  _currentPickupLatLng = info.latLng;
                } else {
                  _currentDestinationLatLng = info.latLng;
                }
              });
              _calculateAndUpdatePrice();
            },
            builder: (context, textController, focusNode) {
              if (textController.text != controller.text) {
                textController.text = controller.text;
                textController.selection = TextSelection.collapsed(
                    offset: textController.text.length);
              }
              return TextField(
                controller: textController,
                focusNode: focusNode,
                style: const TextStyle(color: Colors.black, fontSize: 16),
                onChanged: (v) => controller.text = v,
                decoration: InputDecoration(
                  hintText: 'Enter address or pick from map',
                  hintStyle: const TextStyle(color: Colors.black54),
                  prefixIcon: const Icon(Icons.search, color: Colors.black54),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Pick on map',
                        icon: const Icon(Icons.map_outlined, color: Color(0xFF1A2B7B)),
                        onPressed: () => _pickAddress(isPickup),
                      ),
                      IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear, color: Colors.black45),
                        onPressed: () {
                          setState(() {
                            controller.clear();
                            if (isPickup) {
                              _currentPickupLatLng = const LatLng(0, 0);
                            } else {
                              _currentDestinationLatLng = const LatLng(0, 0);
                            }
                          });
                          _calculateAndUpdatePrice();
                        },
                      ),
                    ],
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: const UnderlineInputBorder(),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF1A2B7B)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _editablePhoneField({
    required TextEditingController controller,
    required VoidCallback onEdit,
  }) {
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12))),
      child: Row(
        children: [
          const Icon(Icons.phone, color: Colors.black54),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              controller.text.isEmpty ? 'Tap pencil to add sender number' : controller.text,
              style: const TextStyle(fontSize: 16, color: Colors.black),
            ),
          ),
          IconButton(icon: const Icon(Icons.edit, color: Color(0xFF1A2B7B)), onPressed: onEdit),
        ],
      ),
    );
  }

  Widget _contactField(String hint, TextEditingController controller) {
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12))),
      child: Row(
        children: [
          const Icon(Icons.phone, color: Colors.black54),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.black, fontSize: 16),
              decoration: InputDecoration(hintText: hint, border: InputBorder.none),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: Color(0xFF1A2B7B)),
            onPressed: () => _pickContact(controller),
          ),
        ],
      ),
    );
  }

  Widget _attachButton(String text, bool isPickup) {
    final count = isPickup ? pickupPhotos.length : destinationPhotos.length;
    return InkWell(
      onTap: () => _pickImage(isPickup),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.black12)),
        ),
        child: Row(
          children: [
            const Icon(Icons.attach_file, color: Colors.black87),
            const SizedBox(width: 10),
            Text(text, style: const TextStyle(fontSize: 16, color: Colors.black87)),
            if (count > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _photoPreview(List<File> images, bool isPickup) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${images.length} image${images.length == 1 ? '' : 's'} attached',
            style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      images[i],
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: -6,
                    top: -6,
                    child: InkWell(
                      onTap: () => _removeImage(isPickup, i),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red),
                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Dark contact sheet
class _ContactListBottomSheet extends StatelessWidget {
  final List<Contact> contacts;
  const _ContactListBottomSheet({required this.contacts});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 5,
            margin: const EdgeInsets.only(bottom: 16),
            decoration:
            BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(8)),
          ),
          const Text('Select a Contact',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 20),
          Expanded(
            child: contacts.isEmpty
                ? const Center(child: Text('No contacts found', style: TextStyle(color: Colors.white70)))
                : ListView.builder(
              itemCount: contacts.length,
              itemBuilder: (context, i) {
                final c = contacts[i];
                final hasPhone = c.phones.isNotEmpty;
                final phone = hasPhone ? c.phones.first.number : 'No phone number';
                final name = c.displayName.isNotEmpty ? c.displayName : 'Unnamed Contact';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF1A2B7B),
                      child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                    subtitle: Text(phone, style: TextStyle(color: hasPhone ? Colors.white70 : Colors.red[400])),
                    onTap: hasPhone ? () => Navigator.pop(context, c) : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}