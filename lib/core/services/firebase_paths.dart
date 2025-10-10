
class FirebasePaths {
  static const sellers = 'sellers';
  static const products = 'products'; // used as subcollection under sellers
  static const orders = 'orders';
}
class UFirebasePaths {
  static const riders = 'riders'; // each rider doc has: available(bool), vehicleType('motorbike'|'bicycle'), position:{geohash, geopoint}
  static const orders = 'orders';
}
