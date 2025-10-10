enum DeliveryMethod { motorbike, bicycle }

extension DeliveryMethodX on DeliveryMethod {
  String get label => this == DeliveryMethod.motorbike ? 'Motor bike' : 'Bicycle';
  String get key => toString().split('.').last;
  static DeliveryMethod fromKey(String k) =>
      k == 'bicycle' ? DeliveryMethod.bicycle : DeliveryMethod.motorbike;
}
