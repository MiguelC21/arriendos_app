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
      'unit_id': unitId,
      'tenant_name': tenantName,
      'phone': phone,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'contract_value': contractValue,
      'active': active,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Contract.fromMap(Map<String, dynamic> map) {
    return Contract(
      id: map['id'],
      unitId: map['unit_id'],
      tenantName: map['tenant_name'],
      phone: map['phone'],
      startDate: DateTime.parse(map['start_date']),
      endDate: map['end_date'] != null ? DateTime.parse(map['end_date']) : null,
      contractValue: (map['contract_value'] as num).toDouble(),
      active: map['active'] ?? true,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Contract copyWith({
    String? tenantName,
    String? phone,
    double? contractValue,
    bool? active,
    DateTime? endDate,
  }) {
    return Contract(
      id: id,
      unitId: unitId,
      tenantName: tenantName ?? this.tenantName,
      phone: phone ?? this.phone,
      startDate: startDate,
      endDate: endDate ?? this.endDate,
      contractValue: contractValue ?? this.contractValue,
      active: active ?? this.active,
      createdAt: createdAt,
    );
  }
}
