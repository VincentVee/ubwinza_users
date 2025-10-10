import 'package:ubwinza_users/core/models/product_model.dart';

import 'option_model.dart';

class CartLine {
  final ProductModel product; int qty; final Map<String, List<OptionItem>> optionsByGroup;
  CartLine({required this.product, this.qty = 1, Map<String, List<OptionItem>>? optionsByGroup})
      : optionsByGroup = optionsByGroup ?? {};
  num get extra => optionsByGroup.values
      .expand((e) => e)
      .fold<num>(0, (p, n) => p + n.price);
  num get lineTotal => (product.price + extra) * qty;
}
class Cart { final List<CartLine> lines; Cart([List<CartLine>? l]) : lines = l ?? []; num get subtotal => lines.fold<num>(0,(p,n)=>p+n.lineTotal); }