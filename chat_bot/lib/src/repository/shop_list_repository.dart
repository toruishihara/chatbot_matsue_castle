import 'package:ai_shop_list/src/model/shop_item.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ShopListRepository {
  final Box _box;

  ShopListRepository(this._box);

  Future<void> addItem(ShopItem item) async {
    await _box.add(item.toJson());
  }

  Future<void> deleteItem(int index) async {
    await _box.deleteAt(index);
  }

  List<ShopItem> getItems() {
    return _box.values
        .map((v) => ShopItem.fromJson(Map<String, dynamic>.from(v)))
        .toList();
  }

  Future<void> clear() async {
    await _box.clear();
  }

  Future<void> saveAll(List<ShopItem> items) async {
    await _box.clear();
    for (final item in items) {
      await _box.add(item.toJson());
    }
  }
}
