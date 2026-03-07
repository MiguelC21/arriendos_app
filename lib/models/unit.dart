import 'package:uuid/uuid.dart';

class Unit {
  final String id;
  final String buildingId;
  final String number;
  final double baseValue;
  final DateTime createdAt;

  Unit({
    String? id,
    required this.buildingId,
    required this.number,
    required this.baseValue,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'building_id': buildingId,
      'number': number,
      'base_value': baseValue,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Unit.fromMap(Map<String, dynamic> map) {
    return Unit(
      id: map['id'],
      buildingId: map['building_id'],
      number: map['number'],
      baseValue: (map['base_value'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
