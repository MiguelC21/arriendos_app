import 'package:uuid/uuid.dart';

enum PaymentStatus { pendiente, parcial, pagado, mora }

class MonthlyPayment {
  final String id;
  final String contractId;
  final int month;
  final int year;
  final double totalValue;
  final double paidValue;
  final DateTime dueDate;
  final PaymentStatus status;
  final DateTime createdAt;

  MonthlyPayment({
    String? id,
    required this.contractId,
    required this.month,
    required this.year,
    required this.totalValue,
    this.paidValue = 0.0,
    required this.dueDate,
    this.status = PaymentStatus.pendiente,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'contratoId': contractId,
      'mes': month,
      'año': year,
      'valorTotal': totalValue,
      'valorPagado': paidValue,
      'fechaVencimiento': dueDate.toIso8601String(),
      'estado': status.name,
      'creadoEn': createdAt.toIso8601String(),
    };
  }

  factory MonthlyPayment.fromMap(Map<String, dynamic> map) {
    return MonthlyPayment(
      id: map['id'],
      contractId: map['contratoId'],
      month: map['mes'],
      year: map['año'],
      totalValue: map['valorTotal'],
      paidValue: map['valorPagado'],
      dueDate: DateTime.parse(map['fechaVencimiento']),
      status: PaymentStatus.values.byName(map['estado']),
      createdAt: DateTime.parse(map['creadoEn']),
    );
  }
}
