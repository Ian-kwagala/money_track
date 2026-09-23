// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'frequency.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FrequencyAdapter extends TypeAdapter<Frequency> {
  @override
  final int typeId = 16;

  @override
  Frequency read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return Frequency.once;
      case 1:
        return Frequency.daily;
      case 2:
        return Frequency.weekly;
      case 3:
        return Frequency.biweekly;
      case 4:
        return Frequency.monthly;
      case 5:
        return Frequency.quarterly;
      case 6:
        return Frequency.yearly;
      case 7:
        return Frequency.random;
      case 8:
        return Frequency.custom;
      default:
        return Frequency.once;
    }
  }

  @override
  void write(BinaryWriter writer, Frequency obj) {
    switch (obj) {
      case Frequency.once:
        writer.writeByte(0);
        break;
      case Frequency.daily:
        writer.writeByte(1);
        break;
      case Frequency.weekly:
        writer.writeByte(2);
        break;
      case Frequency.biweekly:
        writer.writeByte(3);
        break;
      case Frequency.monthly:
        writer.writeByte(4);
        break;
      case Frequency.quarterly:
        writer.writeByte(5);
        break;
      case Frequency.yearly:
        writer.writeByte(6);
        break;
      case Frequency.random:
        writer.writeByte(7);
        break;
      case Frequency.custom:
        writer.writeByte(8);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FrequencyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
