import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const StatusBadge({
    super.key,
    required this.status,
    this.fontSize = 11.5,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();

    Color color;
    String text = status;

    if (normalized.contains('al día') || normalized == 'al dia' || normalized == 'pagado') {
      color = const Color(0xFF10B981); // Emerald Green
      text = 'Al Día';
    } else if (normalized.contains('mora')) {
      color = const Color(0xFFEF4444); // Crimson Red
      text = 'En Mora';
    } else if (normalized.contains('parcial')) {
      color = const Color(0xFFF59E0B); // Amber Orange
      text = 'Parcial';
    } else if (normalized.contains('pendiente')) {
      color = const Color(0xFF38BDF8); // Cyan Blue
      text = 'Pendiente';
    } else if (normalized.contains('disponible')) {
      color = const Color(0xFF94A3B8); // Slate Gray
      text = 'Disponible';
    } else {
      color = const Color(0xFF818CF8); // Indigo
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.28),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
