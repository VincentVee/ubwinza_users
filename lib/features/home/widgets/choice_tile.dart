import 'package:flutter/material.dart';

class ChoiceTile extends StatelessWidget {
  final bool selected;
  final String label;
  final String image;
  final VoidCallback onTap;

  const ChoiceTile({
    super.key,
    required this.selected,
    required this.label,
    required this.image,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = Border.all(
      color: selected ? Colors.white : Colors.white24,
      width: selected ? 2.2 : 1.0,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Ink(
        decoration: BoxDecoration(
          border: border,
          borderRadius: BorderRadius.circular(10),
          color: Colors.white10,
        ),
        // 👇 Give the Stack finite size using AspectRatio (width is constrained by Expanded in the Row)
        child: AspectRatio(
          aspectRatio: 16 / 10, // adjust to taste (makes ~short card)
          child: Stack(
            children: [
              // background image
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    image,
                    fit: BoxFit.cover,
                    colorBlendMode: BlendMode.darken,
                    color: Colors.black12,
                  ),
                ),
              ),
              // label
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.yellow,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
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
