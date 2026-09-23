// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bill.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BillAdapter extends TypeAdapter<Bill> {
  @override
  final int typeId = 11;

  @override
  Bill read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Bill(
      id: fields[0] as String,
      name: fields[1] as String,
      amount: fields[2] as double,
      dueDate: fields[3] as DateTime,
      walletId: fields[4] as String,
      categoryId: fields[5] as String?,
      reminderDaysBefore: fields[6] as int,
      recurrenceRuleId: fields[7] as String?,
      isPaid: fields[8] as bool,
      frequency: fields[9] == null ? Frequency.monthly : fields[9] as Frequency,
      customDays: fields[10] as int?,
      isPaused: fields[11] == null ? false : fields[11] as bool,
      lastPaidDate: fields[12] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Bill obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.dueDate)
      ..writeByte(4)
      ..write(obj.walletId)
      ..writeByte(5)
      ..write(obj.categoryId)
      ..writeByte(6)
      ..write(obj.reminderDaysBefore)
      ..writeByte(7)
      ..write(obj.recurrenceRuleId)
      ..writeByte(8)
      ..write(obj.isPaid)
      ..writeByte(9)
      ..write(obj.frequency)
      ..writeByte(10)
      ..write(obj.customDays)
      ..writeByte(11)
      ..write(obj.isPaused)
      ..writeByte(12)
      ..write(obj.lastPaidDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
