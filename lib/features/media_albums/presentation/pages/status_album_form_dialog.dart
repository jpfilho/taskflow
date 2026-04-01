import 'package:flutter/material.dart';
import '../../data/models/status_album.dart';
import '../../data/repositories/status_album_repository.dart';
import '../../../../widgets/color_picker_dialog.dart';
import '../../../../widgets/form_dialog_helpers.dart';

class StatusAlbumFormDialog extends StatefulWidget {
  final StatusAlbum? statusAlbum;

  const StatusAlbumFormDialog({
    super.key,
    this.statusAlbum,
  });

  @override
  State<StatusAlbumFormDialog> createState() => _StatusAlbumFormDialogState();
}

class _StatusAlbumFormDialogState extends State<StatusAlbumFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeController;
  late TextEditingController _descricaoController;
  late TextEditingController _corFundoController;
  late TextEditingController _corTextoController;
  late TextEditingController _ordemController;
  final StatusAlbumRepository _repository = StatusAlbumRepository();
  bool _ativo = true;
  Color _selectedBackgroundColor = Colors.blue;
  Color _selectedTextColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(
      text: widget.statusAlbum?.nome ?? '',
    );
    _descricaoController = TextEditingController(
      text: widget.statusAlbum?.descricao ?? '',
    );
    final corFundoHex = widget.statusAlbum?.corFundo;
    _corFundoController = TextEditingController(text: corFundoHex ?? '');
    if (corFundoHex != null && corFundoHex.isNotEmpty) {
      _selectedBackgroundColor = _hexToColor(corFundoHex) ?? Colors.blue;
    }
    
    final corTextoHex = widget.statusAlbum?.corTexto;
    _corTextoController = TextEditingController(text: corTextoHex ?? '');
    if (corTextoHex != null && corTextoHex.isNotEmpty) {
      _selectedTextColor = _hexToColor(corTextoHex) ?? Colors.white;
    } else {
      _corTextoController.text = '#FFFFFF';
    }
    
    _ordemController = TextEditingController(
      text: widget.statusAlbum?.ordem.toString() ?? '0',
    );
    _ativo = widget.statusAlbum?.ativo ?? true;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _corFundoController.dispose();
    _corTextoController.dispose();
    _ordemController.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  Color? _hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return null;
    }
  }

  Future<void> _showBackgroundColorPicker() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => ColorPickerDialog(
        initialColor: _selectedBackgroundColor,
        title: 'Selecionar Cor de Fundo',
      ),
    );

    if (color != null) {
      setState(() {
        _selectedBackgroundColor = color;
        _corFundoController.text = _colorToHex(color);
      });
    }
  }

  Future<void> _showTextColorPicker() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => ColorPickerDialog(
        initialColor: _selectedTextColor,
        title: 'Selecionar Cor do Texto',
      ),
    );

    if (color != null) {
      setState(() {
        _selectedTextColor = color;
        _corTextoController.text = _colorToHex(color);
      });
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final corFundoHex = _corFundoController.text.trim();
      final corTextoHex = _corTextoController.text.trim();
      final ordem = int.tryParse(_ordemController.text.trim()) ?? 0;
      
      final statusAlbum = StatusAlbum(
        id: widget.statusAlbum?.id ?? '',
        nome: _nomeController.text.trim(),
        descricao: _descricaoController.text.trim().isEmpty
            ? null
            : _descricaoController.text.trim(),
        corFundo: corFundoHex.isNotEmpty ? corFundoHex : null,
        corTexto: corTextoHex.isNotEmpty ? corTextoHex : null,
        ativo: _ativo,
        ordem: ordem,
      );

      Navigator.of(context).pop(statusAlbum);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.statusAlbum != null;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    final dialogPadding = isMobile ? 12.0 : 16.0;
    final maxWidth = isMobile ? width * 0.96 : 512.0;
    final contentPadding = isMobile ? 16.0 : 32.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(dialogPadding),
      elevation: 0,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1e293b) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(contentPadding, contentPadding, contentPadding, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditing ? 'Editar Status de Álbum' : 'Novo Status de Álbum',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Configure o status e suas cores de exibição.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: contentPadding, vertical: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FloatingLabelTextField(
                        label: 'Nome *',
                        controller: _nomeController,
                        isDark: isDark,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Campo obrigatório';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      FloatingLabelTextField(
                        label: 'Descrição',
                        controller: _descricaoController,
                        isDark: isDark,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),
                      ColorPickerField(
                        label: 'Cor de Fundo',
                        color: _selectedBackgroundColor,
                        colorHex: _corFundoController.text.isEmpty ? 'Não definida' : _corFundoController.text,
                        isDark: isDark,
                        onTap: _showBackgroundColorPicker,
                        icon: Icons.color_lens,
                      ),
                      const SizedBox(height: 24),
                      ColorPickerField(
                        label: 'Cor do Texto',
                        color: _selectedTextColor,
                        colorHex: _corTextoController.text,
                        isDark: isDark,
                        onTap: _showTextColorPicker,
                        icon: Icons.format_color_text,
                      ),
                      const SizedBox(height: 24),
                      FloatingLabelTextField(
                        label: 'Ordem',
                        controller: _ordemController,
                        isDark: isDark,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            final ordem = int.tryParse(value.trim());
                            if (ordem == null || ordem < 0) {
                              return 'Ordem deve ser um número positivo';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SwitchListTile(
                          title: Text(
                            'Ativo',
                            style: TextStyle(
                              color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                            ),
                          ),
                          value: _ativo,
                          activeThumbColor: const Color(0xFF3b82f6),
                          onChanged: (value) {
                            setState(() {
                              _ativo = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer com botões
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0f172a).withOpacity(0.5) : const Color(0xFFf8fafc),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    ),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3b82f6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      isEditing ? 'Salvar Alterações' : 'Criar Status',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
