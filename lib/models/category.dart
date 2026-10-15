import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/material.dart' show IconData, Icons;

import 'frequency.dart';
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

  /// How often spending in this category usually happens, as a [Frequency]
  /// name ('monthly', 'weekly', 'once', ...); older categories only use
  /// 'monthly' or 'once'. The category manager groups by it ("Recurring" vs
  /// "One-time"), and Quick add picks it when the category is chosen.
  @HiveField(7)
  String frequency;

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

  /// [frequency] as a [Frequency]; unknown values read as monthly.
  Frequency get usualFrequency => Frequency.values.asNameMap()[frequency] ?? Frequency.monthly;

  /// Icon names offered when someone makes their own category.
  static const pickerIcons = <String>[
    'shopping_cart', 'restaurant', 'local_cafe', 'local_taxi', 'two_wheeler', 'directions_bus',
    'local_gas_station', 'house', 'bolt', 'water_drop', 'wifi', 'phone_iphone',
    'tv', 'medical_services', 'school', 'checkroom', 'content_cut', 'fitness_center',
    'church', 'family_restroom', 'card_giftcard', 'celebration', 'pets', 'flight',
    'build', 'inventory_2', 'savings', 'payments', 'work', 'attach_money',
  ];

  /// A sensible icon for a name someone typed, e.g. "Boda boda" → a
  /// motorbike. Matches the start of words ("Clothes" → clothing), not any
  /// part of one ("Parents" isn't rent). Null when nothing fits.
  static String? suggestIcon(String name) {
    final text = name.toLowerCase();
    final words = text.split(RegExp(r'[^a-z0-9]+'));
    bool hit(String hint) => _oneWord.hasMatch(hint) ? words.any((w) => w.startsWith(hint)) : text.contains(hint);
    for (final (hints, icon) in _iconHints) {
      if (hints.any(hit)) return icon;
    }
    return null;
  }

  static final _oneWord = RegExp(r'^[a-z0-9]+$');

  /// Checked in order; the first match wins.
  static const _iconHints = <(List<String>, String)>[
    (['boda', 'motorbike', 'motorcycle'], 'two_wheeler'),
    (['taxi', 'uber', 'bolt ride', 'special hire'], 'local_taxi'),
    (['business', 'stock', 'supplies'], 'inventory_2'),
    (['bus', 'transport', 'fare', 'matatu'], 'directions_bus'),
    (['fuel', 'petrol', 'diesel'], 'local_gas_station'),
    (['salon', 'hair', 'barber', 'beauty', 'nails'], 'content_cut'),
    (['church', 'tithe', 'offering', 'mosque', 'zakat'], 'church'),
    (['family', 'parent', 'mum', 'mom', 'dad', 'relative'], 'family_restroom'),
    (['gift', 'present', 'contribution'], 'card_giftcard'),
    (['wedding', 'party', 'introduction', 'birthday', 'function'], 'celebration'),
    (['cloth', 'shoe', 'dress', 'fashion'], 'checkroom'),
    (['gym', 'sport', 'fitness', 'football'], 'fitness_center'),
    (['hospital', 'clinic', 'medic', 'drug', 'pharma', 'doctor'], 'medical_services'),
    (['school', 'fees', 'tuition', 'book', 'course'], 'school'),
    (['internet', 'wifi', 'wi-fi'], 'wifi'),
    (['airtime', 'data', 'bundle', 'phone'], 'phone_iphone'),
    (['tv', 'dstv', 'gotv', 'netflix', 'startimes', 'showmax'], 'tv'),
    (['yaka', 'umeme', 'power', 'electric'], 'bolt'),
    (['water', 'nwsc'], 'water_drop'),
    (['rent', 'house', 'home'], 'house'),
    (['repair', 'mechanic', 'maintenance'], 'build'),
    (['coffee', 'cafe', 'snack'], 'local_cafe'),
    (['food', 'lunch', 'breakfast', 'supper', 'dinner', 'restaurant', 'rolex'], 'restaurant'),
    (['market', 'grocer', 'shop', 'supermarket'], 'shopping_cart'),
    (['pets', 'pet food', 'dog', 'cat food'], 'pets'),
    (['travel', 'trip', 'flight', 'holiday'], 'flight'),
    (['sacco', 'saving', 'invest'], 'savings'),
    (['salary', 'wage', 'pay'], 'payments'),
  ];

  /// Maps a stored icon key to a Material icon: the names used by seed
  /// data and Quick add, then the ones Settings → Categories uses. The maps
  /// are const lookups (rather than building icons from strings) so
  /// Flutter's icon tree-shaking keeps working. Unknown keys get a generic
  /// category icon.
  static IconData materialIcon(String name) => _icons[name] ?? _managerIcons[name] ?? Icons.category_outlined;

  static const _icons = <String, IconData>{
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
    'two_wheeler': Icons.two_wheeler,
    'tv': Icons.tv,
    'content_cut': Icons.content_cut,
    'fitness_center': Icons.fitness_center,
    'church': Icons.church,
    'family_restroom': Icons.family_restroom,
    'build': Icons.build,
  };

  /// Names used by Settings → Categories.
  static const _managerIcons = <String, IconData>{
    'ShoppingBag': Icons.shopping_bag_outlined,
    'Bus': Icons.directions_bus_outlined,
    'Home': Icons.home_outlined,
    'Zap': Icons.bolt_outlined,
    'Droplets': Icons.water_drop_outlined,
    'Fuel': Icons.local_gas_station_outlined,
    'Spray': Icons.cleaning_services_outlined,
    'Heart': Icons.favorite_outline,
    'Music': Icons.music_note_outlined,
    'Coffee': Icons.local_cafe_outlined,
    'Smartphone': Icons.smartphone_outlined,
    'GraduationCap': Icons.school_outlined,
    'Shield': Icons.shield_outlined,
    'Laptop': Icons.laptop_outlined,
    'MapPin': Icons.location_on_outlined,
    'Plane': Icons.flight_outlined,
    'PiggyBank': Icons.savings_outlined,
    'AttachMoney': Icons.attach_money_outlined,
    'Briefcase': Icons.work_outlined,
    'PawPrint': Icons.pets_outlined,
    'Gamepad2': Icons.sports_esports_outlined,
    'Film': Icons.movie_outlined,
    'PartyPopper': Icons.celebration_outlined,
    'Package2': Icons.inventory_2_outlined,
    'Utensils': Icons.restaurant_outlined,
    'Tram': Icons.tram_outlined,
    'Building': Icons.apartment_outlined,
    'Wind': Icons.air_outlined,
    'Waves': Icons.waves_outlined,
    'Leaf': Icons.eco_outlined,
    'Stethoscope': Icons.medical_services_outlined,
    'Headphones': Icons.headphones_outlined,
    'Cake': Icons.cake_outlined,
    'Phone': Icons.phone_outlined,
    'BookOpen': Icons.menu_book_outlined,
    'BadgeCheck': Icons.verified_outlined,
    'Building2': Icons.business_outlined,
    'Map': Icons.map_outlined,
    'Rocket': Icons.rocket_launch_outlined,
    'Target': Icons.center_focus_strong_outlined,
    'Gem': Icons.diamond_outlined,
    'BriefcaseMedical': Icons.medical_information_outlined,
    'Bone': Icons.accessibility_outlined,
    'Controller': Icons.videogame_asset_outlined,
    'Clapperboard': Icons.theater_comedy_outlined,
    'Gift': Icons.card_giftcard_outlined,
    'Box': Icons.inventory_outlined,
  };
}