import 'package:hive/hive.dart';

part 'scan_item.g.dart';

@HiveType(typeId: 0)
class ScanItem extends HiveObject {
  @HiveField(0)
  final String content;

  @HiveField(1)
  final DateTime dateTime;

  @HiveField(2)
  final String type; // 'scan' or 'create'

  ScanItem({
    required this.content,
    required this.dateTime,
    required this.type,
  });
}
