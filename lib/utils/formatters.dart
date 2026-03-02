import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    // Limpiar el texto de cualquier caracter que no sea número
    String cleanText = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (cleanText.isEmpty) {
      return newValue.copyWith(text: '');
    }

    double value = double.parse(cleanText);

    final formatter = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '',
      decimalDigits: 0,
    );

    String newText = formatter.format(value).trim();

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
