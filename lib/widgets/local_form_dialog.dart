import 'package:flutter/material.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/local.dart';
import '../models/regional.dart';
import '../models/divisao.dart';
import '../models/segmento.dart';
import '../services/regional_service.dart';
import '../services/divisao_service.dart';
import '../services/segmento_service.dart';

class LocalFormDialog extends StatefulWidget {
  final Local? local;

  const LocalFormDialog({
    super.key,
    this.local,
  });

  @override
  State<LocalFormDialog> createState() => _LocalFormDialogState();
}

class _LocalFormDialogState extends State<LocalFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _localController;
  late TextEditingController _descricaoController;
  late TextEditingController _localInstalacaoSapController;
  
  final RegionalService _regionalService = RegionalService();
  final DivisaoService _divisaoService = DivisaoService();
  final SegmentoService _segmentoService = SegmentoService();
  
  List<Regional> _regionais = [];
  List<Divisao> _divisoes = [];
  List<Segmento> _segmentos = [];
  
  bool _isLoading = true;
  bool _isSaving = false;
  
  // Flags de associação
  bool _paraTodaRegional = false;
  bool _paraTodaDivisao = false;
  
  // Seleções específicas
  Regional? _selectedRegional;
  Divisao? _selectedDivisao;
  Segmento? _selectedSegmento;

  @override
  void initState() {
    super.initState();
    _localController = TextEditingController(
      text: widget.local?.local ?? '',
    );
    _descricaoController = TextEditingController(
      text: widget.local?.descricao ?? '',
    );
    _localInstalacaoSapController = TextEditingController(
      text: widget.local?.localInstalacaoSap ?? '',
    );
    
    if (widget.local != null) {
      _paraTodaRegional = widget.local!.paraTodaRegional;
      _paraTodaDivisao = widget.local!.paraTodaDivisao;
    }
    
    _loadData();
  }

  @override
  void dispose() {
    _localController.dispose();
    _descricaoController.dispose();
    _localInstalacaoSapController.dispose();
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

        if (widget.local != null) {
          if (widget.local!.regionalId != null && widget.local!.regionalId!.isNotEmpty) {
            _selectedRegional = _regionais.firstWhere(
              (r) => r.id == widget.local!.regionalId,
              orElse: () => _regionais.isNotEmpty ? _regionais.first : _regionais.first,
            );
          }
          if (widget.local!.divisaoId != null && widget.local!.divisaoId!.isNotEmpty) {
            _selectedDivisao = _divisoes.firstWhere(
              (d) => d.id == widget.local!.divisaoId,
              orElse: () => _divisoes.isNotEmpty ? _divisoes.first : _divisoes.first,
            );
          }
          if (widget.local!.segmentoId != null && widget.local!.segmentoId!.isNotEmpty) {
            _selectedSegmento = _segmentos.firstWhere(
              (s) => s.id == widget.local!.segmentoId,
              orElse: () => _segmentos.isNotEmpty ? _segmentos.first : _segmentos.first,
            );
          }
        }
      });
    } catch (e) {
      print('Erro ao carregar dados: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      if (!_paraTodaRegional && 
          !_paraTodaDivisao && 
          _selectedRegional == null && 
          _selectedDivisao == null && 
          _selectedSegmento == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione pelo menos uma associação (Toda Regional, Toda Divisão, ou uma associação específica)'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isSaving = true);

      final local = Local(
        id: widget.local?.id ?? '',
        local: _localController.text.trim(),
        descricao: _descricaoController.text.trim().isEmpty
            ? null
            : _descricaoController.text.trim(),
        localInstalacaoSap: _localInstalacaoSapController.text.trim().isEmpty
            ? null
            : _localInstalacaoSapController.text.trim(),
        paraTodaRegional: _paraTodaRegional,
        paraTodaDivisao: _paraTodaDivisao,
        regionalId: _paraTodaRegional ? null : _selectedRegional?.id,
        divisaoId: _paraTodaDivisao ? null : _selectedDivisao?.id,
        segmentoId: _selectedSegmento?.id,
        createdAt: widget.local?.createdAt,
        updatedAt: DateTime.now(),
      );

      Navigator.of(context).pop(local);
    }
  }

  String _getRegionalDisplayText(Regional regional) {
    return '${regional.regional} - ${regional.divisao} - ${regional.empresa}';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.local != null;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;
    final colors = context.tfColors;

    return TFFormDialog(
      title: isEditing ? 'Editar Local' : 'Novo Local',
      subtitle: 'Atualize as informações do local e suas associações operacionais.',
      saveLabel: isEditing ? 'Salvar Alterações' : 'Criar Local',
      isSaving: _isSaving,
      onSave: _save,
      onCancel: () => Navigator.of(context).pop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TFTextField(
              label: 'Local',
              controller: _localController,
              required: true,
              hint: 'Ex: Subestação Centro, Almoxarifado Central',
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
              hint: 'Descrição do local e pontos de referência',
              maxLines: 2,
            ),
            SizedBox(height: spacing.md),
            TFTextField(
              label: 'Local de Instalação SAP',
              controller: _localInstalacaoSapController,
              hint: 'Ex: BR-SE-01-TR01',
            ),
            SizedBox(height: spacing.lg),
            Text(
              'Escopo de Associação',
              style: typography.bodyMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: spacing.xs),
            Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(TFRadius.r12),
                border: Border.all(color: colors.borderSubtle),
              ),
              padding: EdgeInsets.all(spacing.sm),
              child: Column(
                children: [
                  TFSwitch(
                    label: 'Para Toda Regional',
                    description: 'Disponível em todas as regionais cadastradas',
                    value: _paraTodaRegional,
                    onChanged: (val) {
                      setState(() {
                        _paraTodaRegional = val;
                        if (_paraTodaRegional) _selectedRegional = null;
                      });
                    },
                  ),
                  Divider(height: spacing.md, color: colors.borderSubtle),
                  TFSwitch(
                    label: 'Para Toda Divisão',
                    description: 'Disponível em todas as divisões operacionais',
                    value: _paraTodaDivisao,
                    onChanged: (val) {
                      setState(() {
                        _paraTodaDivisao = val;
                        if (_paraTodaDivisao) _selectedDivisao = null;
                      });
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing.lg),
            Text(
              'Associações Específicas',
              style: typography.bodyMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: spacing.xs),
            TFDropdown<Regional>(
              label: 'Regional Específica',
              value: _selectedRegional,
              items: _regionais,
              isLoading: _isLoading,
              enabled: !_paraTodaRegional,
              displayText: (regional) => _getRegionalDisplayText(regional),
              onChanged: (value) => setState(() => _selectedRegional = value),
            ),
            SizedBox(height: spacing.md),
            TFDropdown<Divisao>(
              label: 'Divisão Específica',
              value: _selectedDivisao,
              items: _divisoes,
              isLoading: _isLoading,
              enabled: !_paraTodaDivisao,
              displayText: (divisao) => '${divisao.divisao} - ${divisao.regional}',
              onChanged: (value) => setState(() => _selectedDivisao = value),
            ),
            SizedBox(height: spacing.md),
            TFDropdown<Segmento>(
              label: 'Segmento Específico',
              value: _selectedSegmento,
              items: _segmentos,
              isLoading: _isLoading,
              displayText: (segmento) => segmento.segmento,
              onChanged: (value) => setState(() => _selectedSegmento = value),
            ),
          ],
        ),
      ),
    );
  }
}
