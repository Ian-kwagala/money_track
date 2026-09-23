// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'income_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IncomeFrequencyAdapter extends TypeAdapter<IncomeFrequency> {
  @override
  final int typeId = 17;

  @override
  IncomeFrequency read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return IncomeFrequency.daily;
      case 1:
        return IncomeFrequency.weekly;
      case 2:
        return IncomeFrequency.biweekly;
      case 3:
        return IncomeFrequency.monthly;
      case 4:
        return IncomeFrequency.irregular;
      default:
        return IncomeFrequency.daily;
    }
  }

  @override
  void write(BinaryWriter writer, IncomeFrequency obj) {
    switch (obj) {
      case IncomeFrequency.daily:
        writer.writeByte(0);
        break;
      case IncomeFrequency.weekly:
        writer.writeByte(1);
        break;
      case IncomeFrequency.biweekly:
        writer.writeByte(2);
        break;
      case IncomeFrequency.monthly:
        writer.writeByte(3);
        break;
      case IncomeFrequency.irregular:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IncomeFrequencyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class IncomeTypeAdapter extends TypeAdapter<IncomeType> {
  @override
  final int typeId = 18;

  @override
  IncomeType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return IncomeType.formal;
      case 1:
        return IncomeType.informal;
      case 2:
        return IncomeType.variable;
      default:
        return IncomeType.formal;
    }
  }

  @override
  void write(BinaryWriter writer, IncomeType obj) {
    switch (obj) {
      case IncomeType.formal:
        writer.writeByte(0);
        break;
      case IncomeType.informal:
        writer.writeByte(1);
        break;
      case IncomeType.variable:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IncomeTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
