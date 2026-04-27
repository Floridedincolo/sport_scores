// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match_snapshot.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MatchSnapshotAdapter extends TypeAdapter<MatchSnapshot> {
  @override
  final int typeId = 1;

  @override
  MatchSnapshot read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MatchSnapshot(
      sportIndex: fields[0] as int,
      matchId: fields[1] as int,
      homeScore: fields[2] as int?,
      awayScore: fields[3] as int?,
      statusCode: fields[4] as String,
      notifiedEventIds: (fields[5] as List).cast<String>(),
      lastUpdated: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, MatchSnapshot obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.sportIndex)
      ..writeByte(1)
      ..write(obj.matchId)
      ..writeByte(2)
      ..write(obj.homeScore)
      ..writeByte(3)
      ..write(obj.awayScore)
      ..writeByte(4)
      ..write(obj.statusCode)
      ..writeByte(5)
      ..write(obj.notifiedEventIds)
      ..writeByte(6)
      ..write(obj.lastUpdated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatchSnapshotAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
