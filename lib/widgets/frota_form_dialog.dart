import 'package:flutter/material.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/frota.dart';
import '../models/regional.dart';
import '../models/divisao.dart';
import '../models/segmento.dart';
import '../services/regional_service.dart';
import '../services/divisao_service.dart';
import '../services/segmento_service.dart';

class FrotaFormDialog extends StatefulWidget {
  final Frota? frota;

  const FrotaFormDialog({
    super.key,
    this.frota,
  });

  @override
  State<FrotaFormDialog> createState() => _FrotaFormDialogState();
}

class _FrotaFormDialogState extends State<FrotaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeController;
  late TextEditingController _marcaController;
  late TextEditingController _placaController;
  late TextEditingController _observacoesController;
  final RegionalService _regionalService = RegionalService();
  final DivisaoService _divisaoService = DivisaoService();
  final SegmentoService _segmentoService = SegmentoService();
  List<Regional> _regionais = [];
  List<Divisao> _divisoes = [];
  List<Segmento> _segmentos = [];
  Regional? _selectedRegional;
  Divisao? _selectedDivisao;
  Segmento? _selectedSegmento;
  String _tipoVeiculo = 'CARRO_LEVE';
  String _propriedade = Frota.PROPRIO;
  bool _emManutencao = false;
  bool _ativo = true;
  bool _isSaving = false;

  final List<Map<String, String>> _propriedades = [
    {'value': Frota.PROPRIO, 'label': 'Próprio'},
    {'value': Frota.LOCADO, 'label': 'Locado'},
    {'value': Frota.TERCEIRO, 'label': 'Terceiro'},
  ];

  final List<Map<String, String>> _tiposVeiculos = [
    {'value': 'CARRO_LEVE', 'label': 'Carro Leve'},
    {'value': 'MUNCK', 'label': 'Munck'},
    {'value': 'TRATOR', 'label': 'Trator'},
    {'value': 'CAMINHAO', 'label': 'Caminhão'},
    {'value': 'PICKUP', 'label': 'Pickup'},
    {'value': 'VAN', 'label': 'Van'},
    {'value': 'MOTO', 'label': 'Moto'},
    {'value': 'ONIBUS', 'label': 'Ônibus'},
    {'value': 'OUTRO', 'label': 'Outro'},
  ];

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(
      text: widget.frota?.nome ?? '',
    );
    _marcaController = TextEditingController(
      text: widget.frota?.marca ?? '',
    );
    _placaController = TextEditingController(
      text: widget.frota?.placa ?? '',
    );
    _observacoesController = TextEditingController(
      text: widget.frota?.observacoes ?? '',
    );
    _tipoVeiculo = widget.frota?.tipoVeiculo ?? 'CARRO_LEVE';
    _propriedade = widget.frota?.propriedade ?? Frota.PROPRIO;
    _emManutencao = widget.frota?.emManutencao ?? false;
    _ativo = widget.frota?.ativo ?? true;
    _loadDependencies();
  }

  Future<void> _loadDependencies() async {
    try {
      final results = await Future.wait([
        _regionalService.getAllRegionais(),
        _divisaoService.getAllDivisoes(),
        _segmentoService.getAllSegmentos(),
      ]);

      if (mounted) {
        final regionais = results[0] as List<Regional>;
        final divisoes = results[1] as List<Divisao>;
        final segmentos = results[2] as List<Segmento>;

        setState(() {
          _regionais = regionais;
          _divisoes = divisoes;
          _segmentos = segmentos;

          if (widget.frota?.regionalId != null) {
            _selectedRegional = regionais.cast<Regional?>().firstWhere(
              (r) => r?.id == widget.frota!.regionalId,
              orElse: () => null,
            );
          }

          if (widget.frota?.divisaoId != null) {
            _selectedDivisao = divisoes.cast<Divisao?>().firstWhere(
              (d) => d?.id == widget.frota!.divisaoId,
              orElse: () => null,
            );
          }

          if (widget.frota?.segmentoId != null) {
            _selectedSegmento = segmentos.cast<Segmento?>().firstWhere(
              (s) => s?.id == widget.frota!.segmentoId,
              orElse: () => null,
            );
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _marcaController.dispose();
    _placaController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  void _save() {
    if (_isSaving) return;

    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      final frota = Frota(
        id: widget.frota?.id ?? '',
        nome: _nomeController.text.trim(),
        marca: _marcaController.text.trim().isEmpty
            ? null
            : _marcaController.text.trim(),
        tipoVeiculo: _tipoVeiculo,
        placa: _placaController.text.trim().toUpperCase(),
        propriedade: _propriedade,
        regionalId: _selectedRegional?.id,
        divisaoId: _selectedDivisao?.id,
        segmentoId: _selectedSegmento?.id,
        emManutencao: _emManutencao,
        observacoes: _observacoesController.text.trim().isEmpty
            ? null
            : _observacoesController.text.trim(),
        ativo: _ativo,
      );

      Navigator.of(context).pop(frota);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.frota != null;
    final spacing = context.tfSpacing;

    return TFFormDialog(
      title: isEditing ? 'Editar Frota' : 'Nova Frota',
      subtitle: 'Cadastre veículos e equipamentos operacionais da frota.',
      saveLabel: isEditing ? 'Salvar Alterações' : 'Criar Frota',
      isSaving: _isSaving,
      onSave: _save,
      onCancel: () => Navigator.of(context).pop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TFTextField(
              controller: _nomeController,
              label: 'Nome do Veículo',
              hint: 'Ex: Caminhão Munck 01, Picape Campo',
              required: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nome é obrigatório';
                }
                return null;
              },
            ),
            SizedBox(height: spacing.md),
            TFTextField(
              controller: _marcaController,
              label: 'Marca / Modelo',
              hint: 'Ex: Ford Cargo, Toyota Hilux',
            ),
            SizedBox(height: spacing.md),
            TFDropdown<String>(
              label: 'Tipo de Veículo',
              isRequired: true,
              value: _tipoVeiculo,
              items: _tiposVeiculos.map((t) => t['value']!).toList(),
              displayText: (val) {
                final match = _tiposVeiculos.firstWhere(
                  (t) => t['value'] == val,
                  orElse: () => {'label': val},
                );
                return match['label']!;
              },
              onChanged: (value) {
                if (value != null) {
                  setState(() => _tipoVeiculo = value);
                }
              },
            ),
            SizedBox(height: spacing.md),
            TFDropdown<String>(
              label: 'Propriedade',
              isRequired: true,
              value: _propriedade,
              items: _propriedades.map((p) => p['value']!).toList(),
              displayText: (val) {
                final match = _propriedades.firstWhere(
                  (p) => p['value'] == val,
                  orElse: () => {'label': val},
                );
                return match['label']!;
              },
              onChanged: (value) {
                if (value != null) {
                  setState(() => _propriedade = value);
                }
              },
            ),
            SizedBox(height: spacing.md),
            TFTextField(
              controller: _placaController,
              label: 'Placa',
              hint: 'Ex: ABC1D23 ou ABC-1234',
              required: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Placa é obrigatória';
                }
                return null;
              },
            ),
            SizedBox(height: spacing.md),
            TFDropdown<Regional?>(
              label: 'Regional (opcional)',
              value: _selectedRegional,
              items: [null, ..._regionais],
              displayText: (r) => r?.regional ?? 'Nenhuma',
              onChanged: (regional) {
                setState(() => _selectedRegional = regional);
              },
            ),
            SizedBox(height: spacing.md),
            TFDropdown<Divisao?>(
              label: 'Divisão (opcional)',
              value: _selectedDivisao,
              items: [null, ..._divisoes],
              displayText: (d) => d?.divisao ?? 'Nenhuma',
              onChanged: (divisao) {
                setState(() => _selectedDivisao = divisao);
              },
            ),
            SizedBox(height: spacing.md),
            TFDropdown<Segmento?>(
              label: 'Segmento (opcional)',
              value: _selectedSegmento,
              items: [null, ..._segmentos],
              displayText: (s) => s?.segmento ?? 'Nenhum',
              onChanged: (segmento) {
                setState(() => _selectedSegmento = segmento);
              },
            ),
            SizedBox(height: spacing.md),
            TFSwitch(
              value: _emManutencao,
              label: 'Em Manutenção',
              description: 'Indica se o veículo está temporariamente fora de operação',
              onChanged: (val) => setState(() => _emManutencao = val),
            ),
            SizedBox(height: spacing.md),
            TFTextField(
              controller: _observacoesController,
              label: 'Observações',
              hint: 'Informações adicionais ou restrições de uso',
              maxLines: 3,
            ),
            SizedBox(height: spacing.md),
            TFSwitch(
              value: _ativo,
              label: 'Veículo Ativo',
              description: 'Desative caso o veículo seja desmobilizado',
              onChanged: (val) => setState(() => _ativo = val),
            ),
          ],
        ),
      ),
    );
  }
}
