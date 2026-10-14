import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/material.dart' show IconData, Icons;

import 'transaction.dart';

part 'category.g.dart';

/// A label for grouping transactions, such as "Food" or "Salary".
///
/// The app ships with a default set (see SeedData); users can add, edit
/// and delete their own in the category manager.
@HiveType(typeId: 3)
class Category extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  /// Icon key; turned into an [IconData] by [materialIcon].
  @HiveField(2)
  String icon;

  /// ARGB colour value, used as `Color(color)`.
  @HiveField(3)
  int color;

  /// Whether this is an income or an expense category.
  @HiveField(4)
  TxType type;

  /// Reserved for sub-categories; stored and synced but not used yet.
  @HiveField(5)
  String? parentCategoryId;

  /// True for the default categories the app created.
  @HiveField(6)
  bool isBuiltIn;

  /// How often spending in this category usually happens. The category
  /// manager groups by it ("Monthly" vs "One-time").
  @HiveField(7)
  String frequency; // 'monthly' or 'once'

  Category({
    required this.id,
    required this.name,
    this.icon = '',
    this.color = 0xFF42A5F5,
    this.type = TxType.expense,
    this.parentCategoryId,
    this.isBuiltIn = false,
    this.frequency = 'monthly',
  });

  IconData get iconData => materialIcon(icon);

  /// Maps a stored icon key to a Material icon. The map is a const lookup
  /// (rather than building icons from strings) so Flutter's icon
  /// tree-shaking keeps working. Unknown keys get a generic category icon.
  static IconData materialIcon(String name) {
    const map = <String, IconData>{
      'restaurant': Icons.restaurant,
      'local_pizza': Icons.local_pizza,
      'local_cafe': Icons.local_cafe,
      'directions_bus': Icons.directions_bus,
      'local_taxi': Icons.local_taxi,
      'directions_car': Icons.directions_car,
      'local_gas_station': Icons.local_gas_station,
      'oil_barrel': Icons.oil_barrel,
      'house': Icons.house,
      'receipt_long': Icons.receipt_long,
      'bolt': Icons.bolt,
      'lightbulb': Icons.lightbulb,
      'water_drop': Icons.water_drop,
      'sanitary': Icons.cleaning_services, // sparkles/sanitary
      'wifi': Icons.wifi,
      'phone_iphone': Icons.phone_iphone,
      'healing': Icons.healing,
      'favorite': Icons.favorite,
      'medical_services': Icons.medical_services,
      'shopping_cart': Icons.shopping_cart,
      'shopping_bag': Icons.shopping_bag,
      'checkroom': Icons.checkroom,
      'sports_esports': Icons.sports_esports,
      'movie': Icons.movie,
      'music_note': Icons.music_note,
      'celebration': Icons.celebration,
      'school': Icons.school,
      'work': Icons.work,
      'payments': Icons.payments,
      'savings': Icons.savings,
      'attach_money': Icons.attach_money,
      'currency_exchange': Icons.currency_exchange,
      'trending_up': Icons.trending_up,
      'confirmation_number': Icons.confirmation_number,
      'model_training': Icons.model_training,
      'pets': Icons.pets,
      'card_giftcard': Icons.card_giftcard,
      'other_houses': Icons.other_houses,
      'inventory_2': Icons.inventory_2,
      'flight': Icons.flight,
    };
    return map[name] ?? Icons.category_outlined;
  }
}