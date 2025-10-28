import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/food/state/cart_provider.dart';

class CartBadgeIcon extends StatelessWidget {
  const CartBadgeIcon({
    super.key,
    this.onPressed,
    this.icon,
    this.badgeColor = Colors.red,
    this.textColor = Colors.white,
    this.showZero = false,
  });

  final VoidCallback? onPressed;
  final IconData? icon;
  final Color badgeColor;
  final Color textColor;
  final bool showZero;

  @override
  Widget build(BuildContext context) {
    // Only rebuild this widget when the count changes
    return Selector<CartProvider, int>(
      selector: (_, p) => p.totalCount,
      builder: (_, count, __) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: onPressed,
              icon: Icon(icon ?? Icons.shopping_bag_outlined, color: Colors.white,),
            ),
            if (showZero || count > 0)
              Positioned(
                right: 4,
                top: 4,
                child: _Badge(count: count, color: badgeColor, textColor: textColor),
              ),
          ],
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count, required this.color, required this.textColor});
  final int count;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Semantics(
      label: 'Cart items: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
        ),
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
