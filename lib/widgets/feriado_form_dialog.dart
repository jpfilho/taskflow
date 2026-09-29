import 'package:flutter/material.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/feriado.dart';
import '../models/local.dart';
import '../services/feriado_service.dart';
import '../services/local_service.dart';

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
  final _localService = LocalService();

  DateTime? _selectedDate;
  final _descricaoController = TextEditingController();
  String _selectedTipo = 'NACIONAL';
  final _paisController = TextEditingController(text: 'Brasil');
  final _estadoController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _searchController = TextEditingController();

  final List<String> _tipos = ['NACIONAL', 'ESTADUAL', 'MUNICIPAL', 'EVENTO'];

  bool _isLoadingLocais = true;
  bool _isSaving = false;
  List<Local> _locaisPermitidos = [];
  List<Local> _todosLocais = [];
  Set<String> _locaisSelecionados = {};

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
    _loadLocais();
    _searchController.addListener(() => setState(() {}));
  }

  Future<void> _loadLocais() async {
    final locaisPermitidos = await _feriadoService.getLocaisPermitidosParaUsuarioAtual();
    final todosLocais = await _localService.getAllLocais();
    
    if (!mounted) return;
    setState(() {
      _locaisPermitidos = locaisPermitidos;
      _todosLocais = todosLocais;
      
      if (widget.feriado != null) {
        _locaisSelecionados = widget.feriado!.localIds.toSet();
      } else {
        if (_selectedTipo == 'NACIONAL') {
          _locaisSelecionados = todosLocais.map((l) => l.id).toSet();
        } else {
          _locaisSelecionados = locaisPermitidos.map((l) => l.id).toSet();
        }
      }
      _isLoadingLocais = false;
    });
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _paisController.dispose();
    _estadoController.dispose();
    _cidadeController.dispose();
    _searchController.dispose();
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
    if (tipo == null) return;
    setState(() {
      _selectedTipo = tipo;
      if (tipo == 'NACIONAL') {
        _estadoController.clear();
        _cidadeController.clear();
        _locaisSelecionados = _todosLocais.map((l) => l.id).toSet();
      } else if (tipo == 'ESTADUAL') {
        _cidadeController.clear();
      }
    });
  }

  List<Local> _getFilteredLocais() {
    final query = _searchController.text.toLowerCase().trim();
    final source = _selectedTipo == 'NACIONAL' ? _todosLocais : _locaisPermitidos;
    
    if (query.isEmpty) return source;
    
    return source.where((l) {
      return l.local.toLowerCase().contains(query) ||
             l.regional.toLowerCase().contains(query) ||
             l.divisao.toLowerCase().contains(query) ||
             l.segmento.toLowerCase().contains(query);
    }).toList();
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

    if (_locaisSelecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione pelo menos um local aplicável')),
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

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final feriado = Feriado(
        id: widget.feriado?.id ?? '',
        data: _selectedDate!,
        descricao: _descricaoController.text.trim(),
        tipo: _selectedTipo,
        pais: _paisController.text.trim().isEmpty ? null : _paisController.text.trim(),
        estado: _estadoController.text.trim().isEmpty ? null : _estadoController.text.trim(),
        cidade: _cidadeController.text.trim().isEmpty ? null : _cidadeController.text.trim(),
        localIds: _locaisSelecionados.toList(),
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
        setState(() => _isSaving = false);
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
    final spacing = context.tfSpacing;
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final filteredLocais = _getFilteredLocais();

    final formattedDate = _selectedDate == null
        ? 'Selecione a data'
        : '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}';

    return TFFormDialog(
      title: isEditing ? 'Editar Feriado' : 'Novo Feriado',
      subtitle: 'Atualize as datas e as localidades com vigência de feriado.',
      saveLabel: isEditing ? 'Salvar Alterações' : 'Criar Feriado',
      isSaving: _isSaving,
      onSave: _save,
      onCancel: () => Navigator.of(context).pop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => _selectDate(context),
              borderRadius: BorderRadius.circular(TFRadius.r8),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(TFRadius.r8),
                  border: Border.all(color: colors.borderSubtle),
                  color: colors.surface,
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 20, color: colors.primary),
                    SizedBox(width: spacing.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Data do Feriado *',
                          style: typography.bodySmall.copyWith(color: colors.textSecondary),
                        ),
                        Text(
                          formattedDate,
                          style: typography.bodyMedium.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: spacing.md),
            TFTextField(
              label: 'Descrição do Feriado',
              controller: _descricaoController,
              required: true,
              hint: 'Ex: Confraternização Universal, Aniversário da Cidade',
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Campo obrigatório';
                return null;
              },
            ),
            SizedBox(height: spacing.md),
            TFDropdown<String>(
              label: 'Tipo de Feriado',
              isRequired: true,
              value: _selectedTipo,
              items: _tipos,
              displayText: (t) => t,
              onChanged: _onTipoChanged,
            ),
            SizedBox(height: spacing.md),
            TFTextField(
              label: 'País',
              controller: _paisController,
              hint: 'Brasil',
            ),
            if (_selectedTipo == 'ESTADUAL' || _selectedTipo == 'MUNICIPAL') ...[
              SizedBox(height: spacing.md),
              TFTextField(
                label: 'Estado (UF)',
                controller: _estadoController,
                required: true,
                hint: 'Ex: SP, RJ, MG',
              ),
            ],
            if (_selectedTipo == 'MUNICIPAL') ...[
              SizedBox(height: spacing.md),
              TFTextField(
                label: 'Cidade',
                controller: _cidadeController,
                required: true,
                hint: 'Ex: São Paulo, Campinas',
              ),
            ],
            SizedBox(height: spacing.lg),
            Text(
              'Locais Aplicáveis (${_locaisSelecionados.length} selecionados)',
              style: typography.bodyMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: spacing.xs),
            TFTextField(
              label: 'Filtrar Locais',
              controller: _searchController,
              hint: 'Buscar local por nome, regional ou divisão...',
            ),
            SizedBox(height: spacing.xs),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(TFRadius.r12),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: _isLoadingLocais
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ))
                  : filteredLocais.isEmpty
                      ? Padding(
                          padding: EdgeInsets.all(spacing.md),
                          child: Center(
                            child: Text(
                              'Nenhum local encontrado',
                              style: typography.bodySmall.copyWith(color: colors.textSecondary),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: filteredLocais.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: colors.borderSubtle),
                          itemBuilder: (context, index) {
                            final local = filteredLocais[index];
                            final isSelected = _locaisSelecionados.contains(local.id);
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _locaisSelecionados.remove(local.id);
                                  } else {
                                    _locaisSelecionados.add(local.id);
                                  }
                                });
                              },
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            local.local,
                                            style: typography.bodyMedium.copyWith(
                                              color: colors.textPrimary,
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                            ),
                                          ),
                                          Text(
                                            '${local.regional} • ${local.divisao} • ${local.segmento}',
                                            style: typography.bodySmall.copyWith(color: colors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Checkbox(
                                      value: isSelected,
                                      activeColor: colors.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(TFRadius.r4),
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _locaisSelecionados.add(local.id);
                                          } else {
                                            _locaisSelecionados.remove(local.id);
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
