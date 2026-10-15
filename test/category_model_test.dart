import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_track/models/category.dart';
import 'package:money_track/models/frequency.dart';

void main() {
  test('usualFrequency reads the stored name; unknown values read as monthly', () {
    expect(Category(id: 'a', name: 'A', frequency: 'weekly').usualFrequency, Frequency.weekly);
    expect(Category(id: 'a', name: 'A', frequency: 'once').usualFrequency, Frequency.once);
    expect(Category(id: 'a', name: 'A').usualFrequency, Frequency.monthly);
    expect(Category(id: 'a', name: 'A', frequency: 'fortnightly?').usualFrequency, Frequency.monthly);
  });

  test('icons from Settings → Categories show everywhere, not as a blank', () {
    expect(Category.materialIcon('ShoppingBag'), Icons.shopping_bag_outlined);
    expect(Category.materialIcon('GraduationCap'), Icons.school_outlined);
    expect(Category.materialIcon('restaurant'), Icons.restaurant);
    expect(Category.materialIcon('no such icon'), Icons.category_outlined);
  });

  test('every icon on offer has a picture', () {
    for (final name in Category.pickerIcons) {
      expect(Category.materialIcon(name), isNot(Icons.category_outlined), reason: name);
    }
  });

  test('a typed name suggests a fitting icon', () {
    expect(Category.suggestIcon('Boda boda'), 'two_wheeler');
    expect(Category.suggestIcon('Church offering'), 'church');
    expect(Category.suggestIcon('Salon'), 'content_cut');
    expect(Category.suggestIcon('Clothes'), 'checkroom');
    expect(Category.suggestIcon('Business stock'), 'inventory_2', reason: 'not the bus');
    expect(Category.suggestIcon('Support parents'), 'family_restroom', reason: '"parents" is not rent');
    expect(Category.suggestIcon('Petty cash'), isNull, reason: '"petty" is not pets');
    expect(Category.suggestIcon('Home Wi-Fi'), 'wifi');
    expect(Category.suggestIcon('Xyz'), isNull);
  });

  test('every suggestion is one the picker shows, so it appears selected', () {
    const names = [
      'boda', 'taxi', 'business', 'bus', 'fuel', 'salon', 'church', 'family', 'gift', 'wedding', 'clothes', 'gym',
      'clinic', 'school', 'internet', 'airtime', 'dstv', 'yaka', 'water', 'rent', 'repair', 'coffee', 'lunch',
      'market', 'pets', 'travel', 'sacco', 'salary',
    ];
    for (final n in names) {
      final icon = Category.suggestIcon(n);
      expect(icon, isNotNull, reason: n);
      expect(Category.pickerIcons, contains(icon), reason: n);
    }
  });
}
