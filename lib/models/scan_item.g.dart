// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScanItemAdapter extends TypeAdapter<ScanItem> {
  @override
  final int typeId = 0;

  @override
  ScanItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScanItem(
      content: fields[0] as String,
      dateTime: fields[1] as DateTime,
      type: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ScanItem obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.content)
      ..writeByte(1)
      ..write(obj.dateTime)
      ..writeByte(2)
      ..write(obj.type);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
