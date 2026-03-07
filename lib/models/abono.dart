import 'package:uuid/uuid.dart';

class Abono {
  final String id;
  final String paymentId;
  final double amount;
  final DateTime date;
  final String note;
  final DateTime createdAt;

  Abono({
    String? id,
    required this.paymentId,
    required this.amount,
    required this.date,
    required this.note,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'payment_id': paymentId,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Abono.fromMap(Map<String, dynamic> map) {
    return Abono(
      id: map['id'],
      paymentId: map['payment_id'],
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date']),
      note: map['note'] ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
    );
  }
}
