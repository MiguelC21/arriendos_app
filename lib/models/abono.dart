import 'package:uuid/uuid.dart';

class Abono {
  final String id;
  final String paymentId;
  final double value;
  final DateTime date;
  final String method;
  final DateTime createdAt;

  Abono({
    String? id,
    required this.paymentId,
    required this.value,
    required this.date,
    required this.method,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pagoId': paymentId,
      'valor': value,
      'fecha': date.toIso8601String(),
      'metodo': method,
      'creadoEn': createdAt.toIso8601String(),
    };
  }

  factory Abono.fromMap(Map<String, dynamic> map) {
    return Abono(
      id: map['id'],
      paymentId: map['pagoId'],
      value: map['valor'],
      date: DateTime.parse(map['fecha']),
      method: map['metodo'],
      createdAt: DateTime.parse(map['creadoEn']),
    );
  }
}
