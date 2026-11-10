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

  /// Id estable para el pago de un contrato en un mes/año dado. Los pagos
  /// mensuales se generan automáticamente en cada dispositivo al abrir la
  /// unidad; con un id aleatorio, dos dispositivos aún no sincronizados
  /// creaban cada uno su propia fila para el mismo mes (duplicados). Con un
  /// id derivado de (contrato, año, mes), ambos generan el MISMO id y el
  /// servidor los trata como una sola fila.
  static String deterministicId(String contractId, int year, int month) {
    return const Uuid().v5(
      Namespace.url.value,
      'arriendos-app/monthly-payment/$contractId/$year/$month',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'contract_id': contractId,
      'month': month,
      'year': year,
      'total_value': totalValue,
      'paid_value': paidValue,
      'due_date':
          "${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}",
      'status': status.name,
      'is_fully_paid': paidValue >= totalValue,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MonthlyPayment.fromMap(Map<String, dynamic> map) {
    final paid = (map['paid_value'] as num?)?.toDouble() ?? 0.0;
    final total = (map['total_value'] as num).toDouble();
    return MonthlyPayment(
      id: map['id'],
      contractId: map['contract_id'],
      month: map['month'],
      year: map['year'],
      totalValue: total,
      paidValue: paid,
      dueDate: DateTime.parse(map['due_date']),
      status: PaymentStatus.values.byName(map['status'] ?? 'pendiente'),
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
