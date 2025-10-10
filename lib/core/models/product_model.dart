class ProductModel {
  final String id;
  final String sellerId;
  final String name;
  final String description;
  final num price;
  final String imageUrl;
  final bool isActive;
  ProductModel({
    required this.id,
    required this.sellerId,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.isActive,
  });
  factory ProductModel.fromMap(String id, Map<String, dynamic> m) => ProductModel(
    id: id,
    sellerId: m['sellerId'] as String,
    name: (m['name'] ?? '') as String,
    description: (m['description'] ?? '') as String,
    price: (m['price'] ?? 0) as num,
    imageUrl: (m['images'] != null && (m['images'] as List).isNotEmpty)
        ? (m['images'] as List).first as String
        : (m['imageUrl'] ?? '') as String,
    isActive: (m['isActive'] as bool?) ?? true,
  );
}