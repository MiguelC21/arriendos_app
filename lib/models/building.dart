import 'package:uuid/uuid.dart';

class Building {
  final String id;
  final String name;
  final String address;
  final DateTime createdAt;

  Building({
    String? id,
    required this.name,
    required this.address,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Building.fromMap(Map<String, dynamic> map) {
    return Building(
      id: map['id'],
      name: map['name'],
      address: map['address'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}
