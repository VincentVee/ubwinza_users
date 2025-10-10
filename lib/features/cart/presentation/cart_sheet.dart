import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../checkout/create_order.dart';
import 'cart_vm.dart';


class CartSheet extends StatelessWidget {
  final String sellerId; final String sellerName;
  const CartSheet({super.key, required this.sellerId, required this.sellerName});
  @override Widget build(BuildContext context) {
    final vm = context.watch<CartVM>();
    final cart = vm.cart;
    return DraggableScrollableSheet(
        initialChildSize: 0.85,
        builder: (context, controller) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children:[
              const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 12),
          Text(sellerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: cart.lines.length,
              itemBuilder: (_,i){
                final l = cart.lines[i];
                return ListTile(
                  title: Text(l.product.name),
                  subtitle: Text('x${l.qty}'),
                  trailing: Text('K${l.lineTotal}'),
                  leading: IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: ()=> vm.remove(l)),
                );
              },
            ),
          ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children:[
                Text('Subtotal', style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('K${cart.subtotal}', style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16,0,16,20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: cart.lines.isEmpty? null : () async {
                    //await createOrderFromCart(context, sellerId: sellerId);
                  },
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical:14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Next'),
                ),
              ),
            )
          ]),
        ),
    );
  }
}
