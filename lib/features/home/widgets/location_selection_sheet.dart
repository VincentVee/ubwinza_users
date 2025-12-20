import 'package:flutter/material.dart';

// Define a simple callback for when a location is picked (either by search or map)
typedef LocationPickedCallback = void Function(String locationName);

class LocationSelectionSheet extends StatelessWidget {
  final LocationPickedCallback onLocationSelected;
  final VoidCallback onPickFromMap;

  const LocationSelectionSheet({
    super.key,
    required this.onLocationSelected,
    required this.onPickFromMap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        // Ensure the sheet clears the keyboard
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 16,
        left: 16,
        right: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // --- Drag Handle ---
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Search Text Field with Suggestions (Placeholder) ---
          TextFormField(
            decoration: InputDecoration(
              hintText: 'Search for a new location...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            // TODO: Implement actual autocomplete/suggestion logic here
            onFieldSubmitted: (value) {
              if (value.isNotEmpty) {
                onLocationSelected(value);
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(height: 16),

          // TODO: Add a ListView.builder for suggested locations here

          // --- Pick from Map Button ---
          ElevatedButton.icon(
            icon: const Icon(Icons.map_outlined),
            label: const Text('Pick from Map'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A2B7B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(context); // Dismiss the sheet
              onPickFromMap(); // Execute the map navigation callback
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}