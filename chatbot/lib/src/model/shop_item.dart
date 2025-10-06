class ShopItem {
  final String name;
  final int quantity;
  final String? unit;

  ShopItem({
    required this.name,
    required this.quantity,
    this.unit,
  });

  factory ShopItem.fromJson(Map<String, dynamic> json) {
    return ShopItem(
      name: json['name'] as String,
      quantity: json['quantity'] as int,
      unit: json['unit'] as String?, // null is allowed
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'unit': unit,
      };
}