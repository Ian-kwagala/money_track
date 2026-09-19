// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 6;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      profileName: fields[0] as String,
      currencySymbol: fields[1] as String,
      currencyCode: fields[2] as String,
      darkMode: fields[3] as bool,
      notificationsEnabled: fields[4] as bool,
      locale: fields[5] as String?,
      onboardingCompleted: fields[6] as bool,
      appLockEnabled: fields[7] as bool,
      appLockPin: fields[8] as String?,
      appLockPasswordHash: fields[9] as String?,
      budgetWarningsEnabled: fields[10] as bool,
      billRemindersEnabled: fields[11] as bool,
      unusualSpendingEnabled: fields[12] as bool,
      weeklySummaryEnabled: fields[13] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.profileName)
      ..writeByte(1)
      ..write(obj.currencySymbol)
      ..writeByte(2)
      ..write(obj.currencyCode)
      ..writeByte(3)
      ..write(obj.darkMode)
      ..writeByte(4)
      ..write(obj.notificationsEnabled)
      ..writeByte(5)
      ..write(obj.locale)
      ..writeByte(6)
      ..write(obj.onboardingCompleted)
      ..writeByte(7)
      ..write(obj.appLockEnabled)
      ..writeByte(8)
      ..write(obj.appLockPin)
      ..writeByte(9)
      ..write(obj.appLockPasswordHash)
      ..writeByte(10)
      ..write(obj.budgetWarningsEnabled)
      ..writeByte(11)
      ..write(obj.billRemindersEnabled)
      ..writeByte(12)
      ..write(obj.unusualSpendingEnabled)
      ..writeByte(13)
      ..write(obj.weeklySummaryEnabled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
