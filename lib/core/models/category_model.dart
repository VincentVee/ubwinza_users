class CategoryModel {
  final String id;
  final String name;
  final String? imageUrl;
  final bool active;
  CategoryModel({required this.id, required this.name, this.imageUrl, required this.active});
  factory CategoryModel.fromMap(String id, Map<String, dynamic> m) => CategoryModel(
    id: id,
    name: (m['name'] ?? '') as String,
    imageUrl: m['imageUrl'] as String?,
    active: (m['active'] as bool?) ?? true,
  );
}