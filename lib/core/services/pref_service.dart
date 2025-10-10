import 'package:shared_preferences/shared_preferences.dart';

import '../models/delivery_method.dart';

class PrefsService {
  PrefsService._();
  static final I = PrefsService._();

  static const _kDeliveryMethod = 'delivery_method';

  Future<void> setDeliveryMethod(DeliveryMethod m) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kDeliveryMethod, m.key);
  }

  Future<DeliveryMethod> getDeliveryMethod() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_kDeliveryMethod);
    return v == null ? DeliveryMethod.motorbike : DeliveryMethodX.fromKey(v);
  }

  static Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      print('Error clearing all data: $e');
    }
  }
}