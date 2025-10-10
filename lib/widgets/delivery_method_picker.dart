import 'package:flutter/material.dart';
import '../core/models/delivery_method.dart';

Future<DeliveryMethod?> showDeliveryMethodPicker({
  required BuildContext context,
  required DeliveryMethod current,
}) {
  return showDialog<DeliveryMethod>(
    context: context,
    builder: (_) {
      return AlertDialog(
        title: const Text('Choose delivery method'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Tile(
              label: 'Motor bike',
              selected: current == DeliveryMethod.motorbike,
              onTap: () => Navigator.pop(context, DeliveryMethod.motorbike),
              icon: Icons.motorcycle,
            ),
            const SizedBox(height: 8),
            _Tile(
              label: 'Bicycle',
              selected: current == DeliveryMethod.bicycle,
              onTap: () => Navigator.pop(context, DeliveryMethod.bicycle),
              icon: Icons.pedal_bike,
            ),
          ],
        ),
      );
    },
  );
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.icon,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300, width: 2),
        ),
        child: Row(children: [
          Icon(icon),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? Theme.of(context).colorScheme.primary : Colors.grey),
        ]),
      ),
    );
  }
}
