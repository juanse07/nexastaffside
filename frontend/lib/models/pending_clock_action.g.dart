// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_clock_action.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PendingClockActionAdapter extends TypeAdapter<PendingClockAction> {
  @override
  final int typeId = 0;

  @override
  PendingClockAction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PendingClockAction(
      id: fields[0] as String,
      action: fields[1] as String,
      eventId: fields[2] as String,
      timestamp: fields[3] as DateTime,
      latitude: fields[4] as double?,
      longitude: fields[5] as double?,
      locationSource: fields[6] as String,
      retryCount: fields[7] as int,
      status: fields[8] as String,
      errorMessage: fields[9] as String?,
      lastRetryAt: fields[10] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, PendingClockAction obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.action)
      ..writeByte(2)
      ..write(obj.eventId)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.latitude)
      ..writeByte(5)
      ..write(obj.longitude)
      ..writeByte(6)
      ..write(obj.locationSource)
      ..writeByte(7)
      ..write(obj.retryCount)
      ..writeByte(8)
      ..write(obj.status)
      ..writeByte(9)
      ..write(obj.errorMessage)
      ..writeByte(10)
      ..write(obj.lastRetryAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingClockActionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
