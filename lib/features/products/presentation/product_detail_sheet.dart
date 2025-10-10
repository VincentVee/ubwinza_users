import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/product_model.dart';
import '../../../core/models/option_model.dart';
import '../../cart/presentation/cart_vm.dart';


class ProductDetailSheet extends StatefulWidget {
  final ProductModel product;
  const ProductDetailSheet({super.key, required this.product});
  @override State<ProductDetailSheet> createState() => _PDSState();
}

class _PDSState extends State<ProductDetailSheet> {
  int qty = 1;
// Demo add-ons (replace by Firestore if you want):
  final groups = <OptionGroup>[
    OptionGroup(id:'paste', title:'Paste Option', multi:false, items:[
      OptionItem(id:'tomayo', name:'Tomayo', price:0),
      OptionItem(id:'pizza_sauce', name:'Pizza Sauce', price:0),
    ]),
    OptionGroup(id:'cheese', title:'Extra Cheese Toppings', multi:true, items:[
      OptionItem(id:'cheese', name:'Cheese', price:25),
    ]),
  ];
  final chosen = <String, List<OptionItem>>{};

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    num extras() => chosen.values.expand((e)=>e).fold<num>(0,(t,i)=>t+i.price);
    num lineTotal() => (p.price + extras()) * qty;


    return DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
            child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(16),
                children: [
            ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(p.imageUrl, height: 220, fit: BoxFit.cover)),
        const SizedBox(height: 12),
        Text(p.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(p.description),
        const SizedBox(height: 16),
        for (final g in groups) ...[
    Text(g.title, style: const TextStyle(fontWeight: FontWeight.w700)),
    const SizedBox(height: 8),
    ...g.items.map((it){
    final selected = (chosen[g.id]??const[]).any((o)=>o.id==it.id);
    return ListTile(
    contentPadding: EdgeInsets.zero,
    leading: g.multi
    ? Checkbox(value: selected, onChanged: (v){ setState((){ final list=chosen[g.id]??=[]; if(v==true){ list.add(it);} else { list.removeWhere((x)=>x.id==it.id);} chosen[g.id]=list;}); })
        : Radio<bool>(value:true, groupValue: selected?true:null, onChanged: (_){ setState((){ chosen[g.id]=[it];}); }),
    title: Text(it.name),
    trailing: Text(it.price==0? '+0K' : '+${it.price}K'),
    );
    }).toList(),
    const SizedBox(height: 12),
    ],
                  const SizedBox(height: 8),
                  Row(children:[
                    _qtyButton('-', ()=> setState((){ if(qty>1) qty--; })),
                    Padding(padding: const EdgeInsets.symmetric(horizontal:16), child: Text('$qty', style: const TextStyle(fontSize:18,fontWeight: FontWeight.bold))),
                    _qtyButton('+', ()=> setState((){ qty++; })),
                    const Spacer(),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (){
                          context.read<CartVM>().add(p, qty: qty, options: chosen);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical:14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: Text('Add • ${lineTotal()}K'),
                      ),
                    ),
                  ])
                ],
            ),
        ),
    );
  }

  Widget _qtyButton(String s, VoidCallback onTap)=>InkWell(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal:16, vertical:10),
      child: Text(s, style: const TextStyle(fontSize:18,fontWeight: FontWeight.w600)),
    ),
  );
}
