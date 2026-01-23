import 'package:flutter/material.dart';

class ColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final String title;

  const ColorPickerDialog({
    super.key,
    required this.initialColor,
    required this.title,
  });

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late Color _selectedColor;
  late HSVColor _hsvColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    _hsvColor = HSVColor.fromColor(_selectedColor);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview da cor selecionada
            Container(
              width: double.infinity,
              height: 100,
              decoration: BoxDecoration(
                color: _selectedColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
              child: Center(
                child: Text(
                  '#${_selectedColor.value.toRadixString(16).substring(2).toUpperCase()}',
                  style: TextStyle(
                    color: _getContrastColor(_selectedColor),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Slider de Matiz (Hue)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Matiz (H): ${_hsvColor.hue.round()}°',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Slider(
                  value: _hsvColor.hue,
                  min: 0,
                  max: 360,
                  divisions: 360,
                  label: '${_hsvColor.hue.round()}°',
                  onChanged: (value) {
                    setState(() {
                      _hsvColor = _hsvColor.withHue(value);
                      _selectedColor = _hsvColor.toColor();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Slider de Saturação (Saturation)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saturação (S): ${(_hsvColor.saturation * 100).round()}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Slider(
                  value: _hsvColor.saturation,
                  min: 0,
                  max: 1,
                  divisions: 100,
                  label: '${(_hsvColor.saturation * 100).round()}%',
                  onChanged: (value) {
                    setState(() {
                      _hsvColor = _hsvColor.withSaturation(value);
                      _selectedColor = _hsvColor.toColor();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Slider de Brilho (Value/Brightness)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Brilho (V): ${(_hsvColor.value * 100).round()}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Slider(
                  value: _hsvColor.value,
                  min: 0,
                  max: 1,
                  divisions: 100,
                  label: '${(_hsvColor.value * 100).round()}%',
                  onChanged: (value) {
                    setState(() {
                      _hsvColor = _hsvColor.withValue(value);
                      _selectedColor = _hsvColor.toColor();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Paleta de cores rápidas
            Text(
              'Cores Rápidas',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickColorButton(Colors.blue),
                _buildQuickColorButton(Colors.red),
                _buildQuickColorButton(Colors.green),
                _buildQuickColorButton(Colors.orange),
                _buildQuickColorButton(Colors.purple),
                _buildQuickColorButton(Colors.teal),
                _buildQuickColorButton(Colors.pink),
                _buildQuickColorButton(Colors.indigo),
                _buildQuickColorButton(Colors.amber),
                _buildQuickColorButton(Colors.cyan),
                _buildQuickColorButton(Colors.brown),
                _buildQuickColorButton(Colors.grey),
                _buildQuickColorButton(Colors.black),
                _buildQuickColorButton(Colors.white),
                _buildQuickColorButton(const Color(0xFF1E3A5F)), // Azul escuro padrão
                _buildQuickColorButton(const Color(0xFF0D1B2A)), // Azul muito escuro
                _buildQuickColorButton(const Color(0xFF0A003C)), // Axia Navy
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_selectedColor),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }

  Widget _buildQuickColorButton(Color color) {
    final isSelected = _selectedColor.value == color.value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColor = color;
          _hsvColor = HSVColor.fromColor(color);
        });
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey[300]!,
            width: isSelected ? 3 : 1,
          ),
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }

  Color _getContrastColor(Color color) {
    // Calcula o brilho relativo da cor
    final luminance = (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
    // Retorna branco para cores escuras e preto para cores claras
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
