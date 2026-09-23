// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TxRecordAdapter extends TypeAdapter<TxRecord> {
  @override
  final int typeId = 4;

  @override
  TxRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TxRecord(
      id: fields[0] as String,
      type: fields[1] as TxType,
      amount: fields[2] as double,
      walletId: fields[3] as String,
      toWalletId: fields[4] as String?,
      categoryId: fields[5] as String,
      note: fields[6] as String,
      dateTime: fields[7] as DateTime,
      receiptPath: fields[8] as String?,
      isRecurring: fields[9] as bool?,
      frequency: fields[10] == null ? Frequency.once : fields[10] as Frequency,
    );
  }

  @override
  void write(BinaryWriter writer, TxRecord obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.walletId)
      ..writeByte(4)
      ..write(obj.toWalletId)
      ..writeByte(5)
      ..write(obj.categoryId)
      ..writeByte(6)
      ..write(obj.note)
      ..writeByte(7)
      ..write(obj.dateTime)
      ..writeByte(8)
      ..write(obj.receiptPath)
      ..writeByte(9)
      ..write(obj.isRecurring)
      ..writeByte(10)
      ..write(obj.frequency);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TxRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TxTypeAdapter extends TypeAdapter<TxType> {
  @override
  final int typeId = 2;

  @override
  TxType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TxType.income;
      case 1:
        return TxType.expense;
      case 2:
        return TxType.transfer;
      default:
        return TxType.income;
    }
  }

  @override
  void write(BinaryWriter writer, TxType obj) {
    switch (obj) {
      case TxType.income:
        writer.writeByte(0);
        break;
      case TxType.expense:
        writer.writeByte(1);
        break;
      case TxType.transfer:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TxTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
