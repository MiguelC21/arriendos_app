import 'package:uuid/uuid.dart';

class Contract {
  final String id;
  final String unitId;
  final String tenantName;
  final String phone;
  final DateTime startDate;
  final DateTime? endDate;
  final double contractValue;
  final bool active;
  final DateTime createdAt;

  Contract({
    String? id,
    required this.unitId,
    required this.tenantName,
    required this.phone,
    required this.startDate,
    this.endDate,
    required this.contractValue,
    this.active = true,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'apartamentoId': unitId,
      'nombreInquilino': tenantName,
      'telefono': phone,
      'fechaInicio': startDate.toIso8601String(),
      'fechaFin': endDate?.toIso8601String(),
      'valorContrato': contractValue,
      'activo': active ? 1 : 0,
      'creadoEn': createdAt.toIso8601String(),
    };
  }

  factory Contract.fromMap(Map<String, dynamic> map) {
    return Contract(
      id: map['id'],
      unitId: map['apartamentoId'],
      tenantName: map['nombreInquilino'],
      phone: map['telefono'],
      startDate: DateTime.parse(map['fechaInicio']),
      endDate: map['fechaFin'] != null ? DateTime.parse(map['fechaFin']) : null,
      contractValue: map['valorContrato'],
      active: map['activo'] == 1,
      createdAt: DateTime.parse(map['creadoEn']),
    );
  }
}
