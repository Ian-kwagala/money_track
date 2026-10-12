// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'captured_sms.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CapturedSmsAdapter extends TypeAdapter<CapturedSms> {
  @override
  final int typeId = 20;

  @override
  CapturedSms read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CapturedSms(
      id: fields[0] as String,
      dedupeKey: fields[1] as String,
      sender: fields[2] as String,
      body: fields[3] as String,
      receivedAt: fields[4] as DateTime,
      status: fields[5] as CaptureStatus,
      transactionIds: (fields[6] as List?)?.cast<String>(),
      handledAt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, CapturedSms obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.dedupeKey)
      ..writeByte(2)
      ..write(obj.sender)
      ..writeByte(3)
      ..write(obj.body)
      ..writeByte(4)
      ..write(obj.receivedAt)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.transactionIds)
      ..writeByte(7)
      ..write(obj.handledAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CapturedSmsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CaptureStatusAdapter extends TypeAdapter<CaptureStatus> {
  @override
  final int typeId = 19;

  @override
  CaptureStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CaptureStatus.pending;
      case 1:
        return CaptureStatus.confirmed;
      case 2:
        return CaptureStatus.ignored;
      default:
        return CaptureStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, CaptureStatus obj) {
    switch (obj) {
      case CaptureStatus.pending:
        writer.writeByte(0);
        break;
      case CaptureStatus.confirmed:
        writer.writeByte(1);
        break;
      case CaptureStatus.ignored:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CaptureStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
