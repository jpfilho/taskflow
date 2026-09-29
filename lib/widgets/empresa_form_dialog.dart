import 'package:flutter/material.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/empresa.dart';
import '../models/regional.dart';
import '../models/divisao.dart';
import '../services/regional_service.dart';
import '../services/divisao_service.dart';

class EmpresaFormDialog extends StatefulWidget {
  final Empresa? empresa;

  const EmpresaFormDialog({
    super.key,
    this.empresa,
  });

  @override
  State<EmpresaFormDialog> createState() => _EmpresaFormDialogState();
}

class _EmpresaFormDialogState extends State<EmpresaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _empresaController;
  final RegionalService _regionalService = RegionalService();
  final DivisaoService _divisaoService = DivisaoService();
  List<Regional> _regionais = [];
  List<Divisao> _divisoes = [];
  Regional? _selectedRegional;
  Divisao? _selectedDivisao;
  String _selectedTipo = 'PROPRIA';
  bool _isLoadingRegionais = true;
  bool _isLoadingDivisoes = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _empresaController = TextEditingController(
      text: widget.empresa?.empresa ?? '',
    );
    _selectedTipo = widget.empresa?.tipo ?? 'PROPRIA';
    _loadRegionais();
  }

  @override
  void dispose() {
    _empresaController.dispose();
    super.dispose();
  }

  Future<void> _loadRegionais() async {
    setState(() {
      _isLoadingRegionais = true;
    });

    try {
      final regionais = await _regionalService.getAllRegionais();
      setState(() {
        _regionais = regionais;
        _isLoadingRegionais = false;

        if (widget.empresa != null && widget.empresa!.regionalId.isNotEmpty) {
          _selectedRegional = regionais.firstWhere(
            (r) => r.id == widget.empresa!.regionalId,
            orElse: () => regionais.isNotEmpty ? regionais.first : regionais.first,
          );
          _loadDivisoes();
        } else if (regionais.isNotEmpty) {
          _selectedRegional = regionais.first;
          _loadDivisoes();
        }
      });
    } catch (e) {
      print('Erro ao carregar regionais: $e');
      setState(() {
        _isLoadingRegionais = false;
      });
    }
  }

  Future<void> _loadDivisoes() async {
    if (_selectedRegional == null) return;

    setState(() {
      _isLoadingDivisoes = true;
    });

    try {
      final divisoes = await _divisaoService.getAllDivisoes();
      final divisoesFiltradas = divisoes
          .where((d) => d.atuaNaRegional(_selectedRegional!.id))
          .toList();

      setState(() {
        _divisoes = divisoesFiltradas;
        _isLoadingDivisoes = false;

        if (widget.empresa != null && widget.empresa!.divisaoId.isNotEmpty) {
          _selectedDivisao = divisoesFiltradas.firstWhere(
            (d) => d.id == widget.empresa!.divisaoId,
            orElse: () => divisoesFiltradas.isNotEmpty
                ? divisoesFiltradas.first
                : divisoesFiltradas.first,
          );
        } else if (divisoesFiltradas.isNotEmpty) {
          _selectedDivisao = divisoesFiltradas.first;
        } else {
          _selectedDivisao = null;
        }
      });
    } catch (e) {
      print('Erro ao carregar divisões: $e');
      setState(() {
        _isLoadingDivisoes = false;
      });
    }
  }

  void _onRegionalChanged(Regional? regional) {
    setState(() {
      _selectedRegional = regional;
      _selectedDivisao = null;
    });
    _loadDivisoes();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      if (_selectedRegional == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione uma regional.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_selectedDivisao == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione uma divisão.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isSaving = true);

      final empresa = Empresa(
        id: widget.empresa?.id ?? '',
        empresa: _empresaController.text.trim(),
        regionalId: _selectedRegional!.id,
        divisaoId: _selectedDivisao!.id,
        tipo: _selectedTipo,
      );

      Navigator.of(context).pop(empresa);
    }
  }

  String _getRegionalDisplayText(Regional regional) {
    return '${regional.regional} - ${regional.divisao} - ${regional.empresa}';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.empresa != null;
    final spacing = context.tfSpacing;

    return TFFormDialog(
      title: isEditing ? 'Editar Empresa' : 'Nova Empresa',
      subtitle: 'Atualize as informações da empresa contratada ou própria.',
      saveLabel: isEditing ? 'Salvar Alterações' : 'Criar Empresa',
      isSaving: _isSaving,
      onSave: _save,
      onCancel: () => Navigator.of(context).pop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TFTextField(
              label: 'Nome da Empresa',
              controller: _empresaController,
              required: true,
              hint: 'Informe a razão social ou nome fantasia',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Campo obrigatório';
                }
                return null;
              },
            ),
            SizedBox(height: spacing.md),
            TFDropdown<Regional>(
              label: 'Regional',
              isRequired: true,
              value: _selectedRegional,
              items: _regionais,
              isLoading: _isLoadingRegionais,
              displayText: (regional) => _getRegionalDisplayText(regional),
              onChanged: _onRegionalChanged,
              validator: (value) {
                if (value == null) {
                  return 'Selecione uma regional';
                }
                return null;
              },
            ),
            SizedBox(height: spacing.md),
            TFDropdown<Divisao>(
              label: 'Divisão',
              isRequired: true,
              value: _selectedDivisao,
              items: _divisoes,
              isLoading: _isLoadingDivisoes,
              hint: _selectedRegional == null
                  ? 'Selecione uma regional primeiro'
                  : 'Selecione a divisão correspondente',
              displayText: (divisao) => divisao.divisao,
              onChanged: (divisao) {
                setState(() {
                  _selectedDivisao = divisao;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Selecione uma divisão';
                }
                return null;
              },
            ),
            SizedBox(height: spacing.md),
            TFDropdown<String>(
              label: 'Tipo',
              isRequired: true,
              value: _selectedTipo,
              items: const ['PROPRIA', 'TERCEIRA'],
              displayText: (tipo) => tipo == 'PROPRIA' ? 'Própria' : 'Terceira',
              onChanged: (tipo) {
                if (tipo != null) {
                  setState(() {
                    _selectedTipo = tipo;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
