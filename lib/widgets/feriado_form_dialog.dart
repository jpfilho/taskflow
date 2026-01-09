import 'package:flutter/material.dart';
import '../models/feriado.dart';
import '../services/feriado_service.dart';

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
      _paisController.text = 'Brasil'; // País padrão
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
      // Limpar campos baseado no tipo
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

    // Validar campos baseado no tipo
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
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      child: Container(
        width: isMobile ? double.infinity : 500,
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.feriado != null ? 'Editar Feriado' : 'Novo Feriado',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              // Data
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data *',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _selectedDate != null
                        ? '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}'
                        : 'Selecione uma data',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Descrição
              TextFormField(
                controller: _descricaoController,
                decoration: const InputDecoration(
                  labelText: 'Descrição *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, informe a descrição';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Tipo
              DropdownButtonFormField<String>(
                value: _selectedTipo,
                decoration: const InputDecoration(
                  labelText: 'Tipo *',
                  border: OutlineInputBorder(),
                ),
                items: _tipos.map((tipo) {
                  return DropdownMenuItem(
                    value: tipo,
                    child: Text(tipo),
                  );
                }).toList(),
                onChanged: _onTipoChanged,
                validator: (value) {
                  if (value == null) {
                    return 'Por favor, selecione o tipo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // País
              TextFormField(
                controller: _paisController,
                decoration: const InputDecoration(
                  labelText: 'País *',
                  border: OutlineInputBorder(),
                ),
                enabled: _selectedTipo != null,
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
              const SizedBox(height: 16),
              // Estado
              TextFormField(
                controller: _estadoController,
                decoration: const InputDecoration(
                  labelText: 'Estado',
                  border: OutlineInputBorder(),
                ),
                enabled: _selectedTipo != null && 
                        (_selectedTipo == 'ESTADUAL' || _selectedTipo == 'MUNICIPAL'),
                validator: (value) {
                  if (_selectedTipo == 'ESTADUAL' || _selectedTipo == 'MUNICIPAL') {
                    if (value == null || value.trim().isEmpty) {
                      return 'Estado é obrigatório';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Cidade
              TextFormField(
                controller: _cidadeController,
                decoration: const InputDecoration(
                  labelText: 'Cidade',
                  border: OutlineInputBorder(),
                ),
                enabled: _selectedTipo == 'MUNICIPAL',
                validator: (value) {
                  if (_selectedTipo == 'MUNICIPAL') {
                    if (value == null || value.trim().isEmpty) {
                      return 'Cidade é obrigatória';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              // Botões
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _save,
                    child: const Text('Salvar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

