// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alert_rule.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AlertRuleAdapter extends TypeAdapter<AlertRule> {
  @override
  final int typeId = 15;

  @override
  AlertRule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AlertRule(
      id: fields[0] as String,
      type: fields[1] as AlertType,
      targetId: fields[2] as String,
      threshold: fields[3] as double,
      isActive: fields[4] as bool,
      message: fields[5] as String?,
      createdAt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, AlertRule obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.targetId)
      ..writeByte(3)
      ..write(obj.threshold)
      ..writeByte(4)
      ..write(obj.isActive)
      ..writeByte(5)
      ..write(obj.message)
      ..writeByte(6)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlertRuleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AlertTypeAdapter extends TypeAdapter<AlertType> {
  @override
  final int typeId = 14;

  @override
  AlertType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AlertType.budgetWarning;
      case 1:
        return AlertType.lowBalance;
      case 2:
        return AlertType.unusualSpending;
      case 3:
        return AlertType.goalPace;
      case 4:
        return AlertType.dueDate;
      default:
        return AlertType.budgetWarning;
    }
  }

  @override
  void write(BinaryWriter writer, AlertType obj) {
    switch (obj) {
      case AlertType.budgetWarning:
        writer.writeByte(0);
        break;
      case AlertType.lowBalance:
        writer.writeByte(1);
        break;
      case AlertType.unusualSpending:
        writer.writeByte(2);
        break;
      case AlertType.goalPace:
        writer.writeByte(3);
        break;
      case AlertType.dueDate:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlertTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
