// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'debt.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DebtAdapter extends TypeAdapter<Debt> {
  @override
  final int typeId = 13;

  @override
  Debt read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Debt(
      id: fields[0] as String,
      counterparty: fields[1] as String,
      amount: fields[2] as double,
      direction: fields[3] as DebtDirection,
      dueDate: fields[4] as DateTime?,
      description: fields[5] as String?,
      isSettled: fields[6] as bool,
      createdAt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Debt obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.counterparty)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.direction)
      ..writeByte(4)
      ..write(obj.dueDate)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.isSettled)
      ..writeByte(7)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DebtAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DebtDirectionAdapter extends TypeAdapter<DebtDirection> {
  @override
  final int typeId = 12;

  @override
  DebtDirection read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DebtDirection.owedToMe;
      case 1:
        return DebtDirection.owedByMe;
      default:
        return DebtDirection.owedToMe;
    }
  }

  @override
  void write(BinaryWriter writer, DebtDirection obj) {
    switch (obj) {
      case DebtDirection.owedToMe:
        writer.writeByte(0);
        break;
      case DebtDirection.owedByMe:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DebtDirectionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
