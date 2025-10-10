import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../cart/presentation/cart_vm.dart';
import '../../products/presentation/product_detail_sheet.dart';
import '../../cart/presentation/cart_sheet.dart';
import '../../restaurants/data/restaurant_repository.dart';
import '../../../core/models/restaurant_model.dart';
import '../../../core/models/product_model.dart';


class RestaurantListScreen extends StatelessWidget {
  final String vehicleType;
  const RestaurantListScreen({super.key, required this.vehicleType});


  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => RestaurantRepository()),
        ChangeNotifierProvider(create: (_) => CartVM()),
      ],
      child: const _RestaurantUI(),
    );
  }
}
class _RestaurantUI extends StatelessWidget {
  const _RestaurantUI();
  @override
  Widget build(BuildContext context) {
    final repo = context.read<RestaurantRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Restaurants')),
      body: StreamBuilder<List<RestaurantModel>>(
        stream: repo.watchRestaurants(),
        builder: (context, rs) {
          if (!rs.hasData) return const Center(child: CircularProgressIndicator());
          final restaurants = rs.data!;
          return ListView.builder(
            itemCount: restaurants.length,
            itemBuilder: (_, i) {
              final r = restaurants[i];
              return _RestaurantTile(r: r);
            },
          );
        },
      ),
    );
  }
}

class _RestaurantTile extends StatelessWidget {
  final RestaurantModel r;
  const _RestaurantTile({required this.r});
  @override
  Widget build(BuildContext context) {
    final repo = context.read<RestaurantRepository>();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ExpansionTile(
        leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(r.imageUrl, width: 56, height: 56, fit: BoxFit.cover)),
        title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${r.rating} ★ • ${r.minMins}-${r.maxMins} min'),
        children: [
          StreamBuilder<List<ProductModel>>(
            stream: repo.watchMenu(r.id),
            builder: (context, ps) {
              if (!ps.hasData) return const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator());
              final menu = ps.data!;
              return GridView.builder(
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: .85, crossAxisSpacing: 8, mainAxisSpacing: 8),
                padding: const EdgeInsets.all(12),
                itemCount: menu.length,
                itemBuilder: (_, i) => _ProductCard(p: menu[i], sellerId: r.id, sellerName: r.name),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel p; final String sellerId; final String sellerName;
  const _ProductCard({required this.p, required this.sellerId, required this.sellerName});
  @override Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showModalBottomSheet(
        context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
        builder: (_) => ProductDetailSheet(product: p),
      ),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
          Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), child: Image.network(p.imageUrl, fit: BoxFit.cover, width: double.infinity))),
          Padding(padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
            Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('K${p.price}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ]))
        ]),
      ),
    );
  }
}