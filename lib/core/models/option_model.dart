class OptionItem { final String id; final String name; final num price; OptionItem({required this.id, required this.name, required this.price}); }
class OptionGroup {
  final String id; final String title; final bool multi; final List<OptionItem> items;
  OptionGroup({required this.id, required this.title, required this.multi, required this.items});
}