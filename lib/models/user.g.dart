// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserAdapter extends TypeAdapter<User> {
  @override
  final int typeId = 7;

  @override
  User read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return User(
      id: fields[0] as String,
      name: fields[1] as String,
      currencySymbol: fields[2] as String,
      currencyCode: fields[3] as String,
      locale: fields[4] as String?,
      darkMode: fields[5] as bool,
      notificationsEnabled: fields[6] as bool,
      phone: fields[7] as String,
      email: fields[8] as String,
      incomeSource: fields[9] as String,
      occupation: fields[10] as String?,
      createdAt: fields[11] as DateTime?,
      dateOfBirth: fields[12] as DateTime?,
      incomeFrequency: fields[13] == null
          ? IncomeFrequency.monthly
          : fields[13] as IncomeFrequency,
      expectedMonthlyIncome: fields[14] == null ? 0.0 : fields[14] as double,
      incomeType:
          fields[15] == null ? IncomeType.formal : fields[15] as IncomeType,
      isVariable: fields[16] == null ? false : fields[16] as bool,
      lastPayDate: fields[17] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, User obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.currencySymbol)
      ..writeByte(3)
      ..write(obj.currencyCode)
      ..writeByte(4)
      ..write(obj.locale)
      ..writeByte(5)
      ..write(obj.darkMode)
      ..writeByte(6)
      ..write(obj.notificationsEnabled)
      ..writeByte(7)
      ..write(obj.phone)
      ..writeByte(8)
      ..write(obj.email)
      ..writeByte(9)
      ..write(obj.incomeSource)
      ..writeByte(10)
      ..write(obj.occupation)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.dateOfBirth)
      ..writeByte(13)
      ..write(obj.incomeFrequency)
      ..writeByte(14)
      ..write(obj.expectedMonthlyIncome)
      ..writeByte(15)
      ..write(obj.incomeType)
      ..writeByte(16)
      ..write(obj.isVariable)
      ..writeByte(17)
      ..write(obj.lastPayDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
