import 'package:flutter/material.dart';

/// Campo de búsqueda reutilizable: igual que un `TextField` normal, pero
/// muestra una "X" para borrar todo el contenido en cuanto hay texto.
class SearchField extends StatefulWidget {
  final String hintText;
  final ValueChanged<String> onChanged;
  final Color? fillColor;
  final EdgeInsetsGeometry? contentPadding;
  final double iconSize;

  const SearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.fillColor,
    this.contentPadding,
    this.iconSize = 20,
  });

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: Icon(Icons.search_rounded, size: widget.iconSize),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpiar búsqueda',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: _clear,
              ),
        contentPadding: widget.contentPadding,
        filled: widget.fillColor != null,
        fillColor: widget.fillColor,
      ),
    );
  }
}
