import 'package:flutter/material.dart';
import '../models/feriado.dart';
import '../services/feriado_service.dart';
import 'form_dialog_helpers.dart';

class FeriadoFormDialog extends StatefulWidget {
  final Feriado? feriado;
  final Function()? onSaved;

  const FeriadoFormDialog({
    super.key,
    this.feriado,
    this.onSaved,
  });

  @override
  State<FeriadoFormDialog> createState() => _FeriadoFormDialogState();
}

class _FeriadoFormDialogState extends State<FeriadoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _feriadoService = FeriadoService();

  DateTime? _selectedDate;
  final _descricaoController = TextEditingController();
  String? _selectedTipo;
  final _paisController = TextEditingController(text: 'Brasil');
  final _estadoController = TextEditingController();
  final _cidadeController = TextEditingController();

  final List<String> _tipos = ['NACIONAL', 'ESTADUAL', 'MUNICIPAL'];

  @override
  void initState() {
    super.initState();
    if (widget.feriado != null) {
      _selectedDate = widget.feriado!.data;
      _descricaoController.text = widget.feriado!.descricao;
      _selectedTipo = widget.feriado!.tipo;
      _paisController.text = widget.feriado!.pais ?? 'Brasil';
      _estadoController.text = widget.feriado!.estado ?? '';
      _cidadeController.text = widget.feriado!.cidade ?? '';
    } else {
      _selectedDate = DateTime.now();
      _paisController.text = 'Brasil';
    }
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _paisController.dispose();
    _estadoController.dispose();
    _cidadeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _onTipoChanged(String? tipo) {
    setState(() {
      _selectedTipo = tipo;
      if (tipo == 'NACIONAL') {
        _estadoController.clear();
        _cidadeController.clear();
      } else if (tipo == 'ESTADUAL') {
        _cidadeController.clear();
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione uma data')),
      );
      return;
    }

    if (_selectedTipo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione o tipo de feriado')),
      );
      return;
    }

    if (_selectedTipo == 'NACIONAL' && _paisController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('País é obrigatório para feriado nacional')),
      );
      return;
    }

    if (_selectedTipo == 'ESTADUAL' && 
        (_paisController.text.isEmpty || _estadoController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('País e Estado são obrigatórios para feriado estadual')),
      );
      return;
    }

    if (_selectedTipo == 'MUNICIPAL' && 
        (_paisController.text.isEmpty || 
         _estadoController.text.isEmpty || 
         _cidadeController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('País, Estado e Cidade são obrigatórios para feriado municipal')),
      );
      return;
    }

    try {
      final now = DateTime.now();
      final feriado = Feriado(
        id: widget.feriado?.id ?? '',
        data: _selectedDate!,
        descricao: _descricaoController.text.trim(),
        tipo: _selectedTipo!,
        pais: _paisController.text.trim().isEmpty ? null : _paisController.text.trim(),
        estado: _estadoController.text.trim().isEmpty ? null : _estadoController.text.trim(),
        cidade: _cidadeController.text.trim().isEmpty ? null : _cidadeController.text.trim(),
        createdAt: widget.feriado?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.feriado != null) {
        await _feriadoService.updateFeriado(feriado);
      } else {
        await _feriadoService.createFeriado(feriado);
      }

      if (mounted) {
        Navigator.of(context).pop();
        if (widget.onSaved != null) {
          widget.onSaved!();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.feriado != null 
                ? 'Feriado atualizado com sucesso' 
                : 'Feriado criado com sucesso'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar feriado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.feriado != null;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 512),
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
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditing ? 'Editar Feriado' : 'Novo Feriado',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Atualize as informações do feriado.',
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
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => _selectDate(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Data *',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF3b82f6),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _selectedDate != null
                                    ? '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}'
                                    : 'Selecione uma data',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? const Color(0xFFcbd5e1) : const Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.calendar_today,
                                color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FloatingLabelTextField(
                        label: 'Descrição *',
                        controller: _descricaoController,
                        isDark: isDark,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor, informe a descrição';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      FloatingLabelDropdown<String>(
                        label: 'Tipo *',
                        value: _selectedTipo,
                        items: _tipos,
                        isLoading: false,
                        displayText: (tipo) => tipo,
                        onChanged: _onTipoChanged,
                        isDark: isDark,
                        validator: (value) {
                          if (value == null) {
                            return 'Por favor, selecione o tipo';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      FloatingLabelTextField(
                        label: 'País *',
                        controller: _paisController,
                        isDark: isDark,
                        validator: (value) {
                          if (_selectedTipo != null && 
                              (_selectedTipo == 'NACIONAL' || 
                               _selectedTipo == 'ESTADUAL' || 
                               _selectedTipo == 'MUNICIPAL')) {
                            if (value == null || value.trim().isEmpty) {
                              return 'País é obrigatório';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      FloatingLabelTextField(
                        label: 'Estado',
                        controller: _estadoController,
                        isDark: isDark,
                        validator: (value) {
                          if (_selectedTipo == 'ESTADUAL' || _selectedTipo == 'MUNICIPAL') {
                            if (value == null || value.trim().isEmpty) {
                              return 'Estado é obrigatório';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      FloatingLabelTextField(
                        label: 'Cidade',
                        controller: _cidadeController,
                        isDark: isDark,
                        validator: (value) {
                          if (_selectedTipo == 'MUNICIPAL') {
                            if (value == null || value.trim().isEmpty) {
                              return 'Cidade é obrigatória';
                            }
                          }
                          return null;
                        },
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
                      isEditing ? 'Salvar Alterações' : 'Criar Feriado',
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
