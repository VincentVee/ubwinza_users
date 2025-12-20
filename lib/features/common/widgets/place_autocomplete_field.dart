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
    this.onMapTap,
    required this.onClear, // <--- Mandatory for state management
  });

  final TextEditingController controller;
  final PlaceService service;
  final String label;
  final Future<void> Function(PlaceDetail detail) onPlacePicked;
  final VoidCallback? onMapTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final labelStyle =
    const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 8),

        // KEY FIX: Passing the external controller directly
        TypeAheadField<PlaceSuggestion>(
          controller: controller, // <--- This ensures synchronization
          debounceDuration: const Duration(milliseconds: 250),
          hideOnEmpty: true,
          suggestionsCallback: (pattern) => service.autocomplete(pattern),

          builder: (context, ctrl, focus) {
            // Use ValueListenableBuilder to automatically update icons based on text
            return ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, child) {
                return TextField(
                  controller: ctrl,
                  focusNode: focus,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Start typing an address',
                    hintStyle: const TextStyle(color: Colors.black54),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Clear button: Only show if text is present
                        if (value.text.isNotEmpty)
                          IconButton(
                            onPressed: () {
                              controller.clear();
                              onClear(); // Clears the state in the parent (e.g., _pickup = null)
                              FocusScope.of(context).unfocus(); // Dismiss keyboard
                            },
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            tooltip: 'Clear input',
                          ),
                        IconButton(
                          onPressed: onMapTap,
                          icon: const Icon(Icons.map_sharp, color: Colors.grey),
                          tooltip: 'Pick from map',
                        ),
                      ],
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                      const BorderSide(color: Color(0xFF1A2B7B)),
                    ),
                  ),
                );
              },
            );
          },

          itemBuilder: (context, suggestion) => ListTile(
            leading: const Icon(Icons.location_on, color: Colors.black87),
            title: Text(suggestion.description,
                style: const TextStyle(color: Colors.black)),
            subtitle: Text(suggestion.description, // Often shows secondary text
                style: const TextStyle(color: Colors.black54, fontSize: 12)),
          ),
          onSelected: (s) async {
            final detail = await service.detail(s.placeId);
            controller.text = detail.address;
            await onPlacePicked(detail);
            FocusScope.of(context).unfocus(); // Dismiss keyboard after selection
          },
        ),
      ],
    );
  }
}