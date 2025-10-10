import 'package:flutter/foundation.dart';
import '../../../core/models/cart_models.dart';
import '../../../core/models/option_model.dart';
import '../../../core/models/product_model.dart';


class CartVM extends ChangeNotifier {
  final cart = Cart();
  void add(ProductModel p, {int qty = 1, Map<String, List<OptionItem>>? options}) {
    cart.lines.add(CartLine(product: p, qty: qty, optionsByGroup: options));
    notifyListeners();
  }
  void remove(CartLine l) { cart.lines.remove(l); notifyListeners(); }
  void inc(CartLine l) { l.qty++; notifyListeners(); }
  void dec(CartLine l) { if (l.qty>1) { l.qty--; notifyListeners(); } }
  void clear(){ cart.lines.clear(); notifyListeners(); }
}