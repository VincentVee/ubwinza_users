// lib/features/common/widgets/place_autocomplete_field.dart
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

import '../../../core/services/places_service.dart';

class PlaceAutocompleteField extends StatelessWidget {
  const PlaceAutocompleteField({
    super.key,
    required this.controller,
    required this.service,
    required this.label,
    required this.onPlacePicked,
    this.onMapTap, required Null Function() onClear,
  });

  final TextEditingController controller;
  final PlaceService service;
  final String label;
  final Future<void> Function(PlaceDetail detail) onPlacePicked;
  final VoidCallback? onMapTap;

  @override
  Widget build(BuildContext context) {
    final labelStyle = const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 8),
        TypeAheadField<PlaceSuggestion>(
          debounceDuration: const Duration(milliseconds: 250),
          hideOnEmpty: true,
          suggestionsCallback: (pattern) => service.autocomplete(pattern),
          builder: (context, ctrl, focus) {
            // keep our external controller in sync
            ctrl
              ..text = controller.text
              ..selection = controller.selection;
            ctrl.addListener(() => controller.value = ctrl.value);

            return TextField(
              controller: ctrl,
              focusNode: focus,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                hintText: 'Start typing an address',
                hintStyle: const TextStyle(color: Colors.black54),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: IconButton(
                  onPressed: onMapTap,
                  icon: const Icon(Icons.map_sharp, color: Colors.grey),
                  tooltip: 'Pick from map',
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          },
          itemBuilder: (context, suggestion) => ListTile(
            leading: const Icon(Icons.location_on, color: Colors.black87),
            title: Text(suggestion.description, style: const TextStyle(color: Colors.black)),
          ),
          onSelected: (s) async {
            final detail = await service.detail(s.placeId);
            controller.text = detail.address;
            await onPlacePicked(detail);
          },
        ),
      ],
    );
  }
}
