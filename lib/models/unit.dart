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
      'buildingId': buildingId,
      'numero': number,
      'valorBase': baseValue,
      'creadoEn': createdAt.toIso8601String(),
    };
  }

  factory Unit.fromMap(Map<String, dynamic> map) {
    return Unit(
      id: map['id'],
      buildingId: map['buildingId'],
      number: map['numero'],
      baseValue: map['valorBase'],
      createdAt: DateTime.parse(map['creadoEn']),
    );
  }
}
