class RestaurantModel {
  final String id;
  final String name;
  final String imageUrl;
  final String address;
  final double rating;
  final int minMins;
  final int maxMins;
  RestaurantModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.address,
    required this.rating,
    required this.minMins,
    required this.maxMins,
  });
  factory RestaurantModel.fromMap(String id, Map<String, dynamic> m) => RestaurantModel(
    id: id,
    name: (m['name'] ?? '') as String,
    imageUrl: (m['imageUrl'] ?? '') as String,
    address: (m['address'] ?? '') as String,
    rating: ((m['rating'] ?? 4.2) as num).toDouble(),
    minMins: (m['minMins'] ?? 20) as int,
    maxMins: (m['maxMins'] ?? 40) as int,
  );
}