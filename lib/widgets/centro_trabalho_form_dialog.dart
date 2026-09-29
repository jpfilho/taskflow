import 'package:flutter/material.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/centro_trabalho.dart';
import '../models/regional.dart';
import '../models/divisao.dart';
import '../models/segmento.dart';
import '../services/regional_service.dart';
import '../services/divisao_service.dart';
import '../services/segmento_service.dart';

class CentroTrabalhoFormDialog extends StatefulWidget {
  final CentroTrabalho? centroTrabalho;

  const CentroTrabalhoFormDialog({
    super.key,
    this.centroTrabalho,
  });

  @override
  State<CentroTrabalhoFormDialog> createState() => _CentroTrabalhoFormDialogState();
}

class _CentroTrabalhoFormDialogState extends State<CentroTrabalhoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _centroTrabalhoController;
  late TextEditingController _descricaoController;
  late TextEditingController _gpmController;
  
  final RegionalService _regionalService = RegionalService();
  final DivisaoService _divisaoService = DivisaoService();
  final SegmentoService _segmentoService = SegmentoService();
  
  List<Regional> _regionais = [];
  List<Divisao> _divisoes = [];
  List<Segmento> _segmentos = [];
  
  bool _isLoading = true;
  bool _isSaving = false;
  bool _ativo = true;
  
  // Seleções obrigatórias
  Regional? _selectedRegional;
  Divisao? _selectedDivisao;
  Segmento? _selectedSegmento;

  @override
  void initState() {
    super.initState();
    _centroTrabalhoController = TextEditingController(
      text: widget.centroTrabalho?.centroTrabalho ?? '',
    );
    _descricaoController = TextEditingController(
      text: widget.centroTrabalho?.descricao ?? '',
    );
    _gpmController = TextEditingController(
      text: widget.centroTrabalho?.gpm?.toString() ?? '',
    );
    
    // Inicializar valores se estiver editando
    if (widget.centroTrabalho != null) {
      _ativo = widget.centroTrabalho!.ativo;
    }
    
    _loadData();
  }

  @override
  void dispose() {
    _centroTrabalhoController.dispose();
    _descricaoController.dispose();
    _gpmController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final futures = await Future.wait([
        _regionalService.getAllRegionais(),
        _divisaoService.getAllDivisoes(),
        _segmentoService.getAllSegmentos(),
      ]);

      setState(() {
        _regionais = futures[0] as List<Regional>;
        _divisoes = futures[1] as List<Divisao>;
        _segmentos = futures[2] as List<Segmento>;
        _isLoading = false;

        // Selecionar valores se estiver editando
        if (widget.centroTrabalho != null) {
          if (widget.centroTrabalho!.regionalId.isNotEmpty) {
            _selectedRegional = _regionais.firstWhere(
              (r) => r.id == widget.centroTrabalho!.regionalId,
              orElse: () => _regionais.isNotEmpty ? _regionais.first : _regionais.first,
            );
          }
          if (widget.centroTrabalho!.divisaoId.isNotEmpty) {
            _selectedDivisao = _divisoes.firstWhere(
              (d) => d.id == widget.centroTrabalho!.divisaoId,
              orElse: () => _divisoes.isNotEmpty ? _divisoes.first : _divisoes.first,
            );
          }
          if (widget.centroTrabalho!.segmentoId.isNotEmpty) {
            _selectedSegmento = _segmentos.firstWhere(
              (s) => s.id == widget.centroTrabalho!.segmentoId,
              orElse: () => _segmentos.isNotEmpty ? _segmentos.first : _segmentos.first,
            );
          }
        }
      });
    } catch (e) {
      debugPrint('Erro ao carregar dados: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onRegionalChanged(Regional? regional) {
    setState(() {
      _selectedRegional = regional;
      // Limpar divisão e segmento quando mudar a regional
      _selectedDivisao = null;
      _selectedSegmento = null;
    });
  }

  void _onDivisaoChanged(Divisao? divisao) {
    setState(() {
      _selectedDivisao = divisao;
      // Limpar segmento quando mudar a divisão
      _selectedSegmento = null;
    });
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      // Validar que todos os vínculos foram selecionados (obrigatórios)
      if (_selectedRegional == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione uma Regional'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_selectedDivisao == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione uma Divisão'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_selectedSegmento == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione um Segmento'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isSaving = true);
      final centroTrabalho = CentroTrabalho(
        id: widget.centroTrabalho?.id ?? '',
        centroTrabalho: _centroTrabalhoController.text.trim(),
        descricao: _descricaoController.text.trim().isEmpty
            ? null
            : _descricaoController.text.trim(),
        regionalId: _selectedRegional!.id,
        divisaoId: _selectedDivisao!.id,
        segmentoId: _selectedSegmento!.id,
        gpm: _gpmController.text.trim().isEmpty
            ? null
            : int.tryParse(_gpmController.text.trim()),
        ativo: _ativo,
        createdAt: widget.centroTrabalho?.createdAt,
        updatedAt: DateTime.now(),
      );

      Navigator.of(context).pop(centroTrabalho);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.centroTrabalho != null;
    final spacing = context.tfSpacing;
    final colors = context.tfColors;
    final typography = context.tfTypography;

    final filteredDivisoes = _divisoes
        .where((d) => _selectedRegional == null || d.atuaNaRegional(_selectedRegional!.id))
        .toList();

    final filteredSegmentos = _segmentos
        .where((s) => _selectedDivisao == null || _selectedDivisao!.segmentoIds.contains(s.id))
        .toList();

    return TFFormDialog(
      title: isEditing ? 'Editar Centro de Trabalho' : 'Novo Centro de Trabalho',
      subtitle: 'Atualize as informações e vínculos operacionais.',
      saveLabel: isEditing ? 'Salvar Alterações' : 'Criar Centro de Trabalho',
      isSaving: _isSaving,
      onSave: _save,
      onCancel: () => Navigator.of(context).pop(),
      child: _isLoading
          ? const SizedBox(
              height: 200,
              child: Center(child: TFLoading(message: 'Carregando dados...')),
            )
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TFTextField(
                    label: 'Centro de Trabalho',
                    controller: _centroTrabalhoController,
                    required: true,
                    hint: 'Digite o nome do centro de trabalho',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Campo obrigatório';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: spacing.md),
                  TFTextField(
                    label: 'Descrição',
                    controller: _descricaoController,
                    hint: 'Digite uma descrição (opcional)',
                    maxLines: 2,
                  ),
                  SizedBox(height: spacing.md),
                  TFTextField(
                    label: 'GPM',
                    controller: _gpmController,
                    hint: 'Digite o GPM (numérico)',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        final gpm = int.tryParse(value.trim());
                        if (gpm == null) {
                          return 'Digite um número válido';
                        }
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: spacing.lg),
                  Text(
                    'Vínculos Organizacionais',
                    style: typography.bodyMedium.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: spacing.sm),
                  TFDropdown<Regional>(
                    label: 'Regional',
                    isRequired: true,
                    hint: 'Selecione uma regional',
                    value: _selectedRegional,
                    items: _regionais,
                    displayText: (r) => r.regional,
                    onChanged: _onRegionalChanged,
                    validator: (val) {
                      if (val == null) return 'Selecione uma Regional';
                      return null;
                    },
                  ),
                  SizedBox(height: spacing.md),
                  TFDropdown<Divisao>(
                    label: 'Divisão',
                    isRequired: true,
                    hint: 'Selecione uma divisão',
                    value: _selectedDivisao,
                    items: filteredDivisoes,
                    displayText: (d) => d.divisao,
                    onChanged: _onDivisaoChanged,
                    validator: (val) {
                      if (val == null) return 'Selecione uma Divisão';
                      return null;
                    },
                  ),
                  SizedBox(height: spacing.md),
                  TFDropdown<Segmento>(
                    label: 'Segmento',
                    isRequired: true,
                    hint: 'Selecione um segmento',
                    value: _selectedSegmento,
                    items: filteredSegmentos,
                    displayText: (s) => s.segmento,
                    onChanged: (segmento) {
                      setState(() {
                        _selectedSegmento = segmento;
                      });
                    },
                    validator: (val) {
                      if (val == null) return 'Selecione um Segmento';
                      return null;
                    },
                  ),
                  SizedBox(height: spacing.lg),
                  TFSwitch(
                    label: 'Ativo',
                    description: 'Define se o centro de trabalho está habilitado no sistema',
                    value: _ativo,
                    onChanged: (value) {
                      setState(() {
                        _ativo = value;
                      });
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

