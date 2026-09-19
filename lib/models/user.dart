import 'package:hive_flutter/hive_flutter.dart';

part 'user.g.dart';

@HiveType(typeId: 7)
class User extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String currencySymbol;

  @HiveField(3)
  String currencyCode;

  @HiveField(4)
  String? locale;

  @HiveField(5)
  bool darkMode;

  @HiveField(6)
  bool notificationsEnabled;

  @HiveField(7)
  String phone;

  @HiveField(8)
  String email;

  @HiveField(9)
  String incomeSource; // 'salary' or 'informal'

  @HiveField(10)
  String? occupation;

  @HiveField(11)
  DateTime? createdAt;

  User({
    this.id = 'default_user',
    this.name = 'Ian',
    this.currencySymbol = 'UGX',
    this.currencyCode = 'UGX',
    this.locale,
    this.darkMode = false,
    this.notificationsEnabled = true,
    this.phone = '',
    this.email = '',
    this.incomeSource = 'salary',
    this.occupation,
    this.createdAt,
  });
}
