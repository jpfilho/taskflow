import 'package:flutter/material.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/divisao.dart';
import '../models/regional.dart';
import '../models/segmento.dart';
import '../services/regional_service.dart';
import '../services/segmento_service.dart';
import '../services/divisao_service.dart';
import '../config/supabase_config.dart';

class DivisaoFormDialog extends StatefulWidget {
  final Divisao? divisao;

  const DivisaoFormDialog({
    super.key,
    this.divisao,
  });

  @override
  State<DivisaoFormDialog> createState() => _DivisaoFormDialogState();
}

class _DivisaoFormDialogState extends State<DivisaoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _divisaoController;
  final RegionalService _regionalService = RegionalService();
  final SegmentoService _segmentoService = SegmentoService();
  List<Regional> _regionais = [];
  List<Segmento> _segmentos = [];
  List<String> _selectedRegionalIds = [];
  List<String> _selectedSegmentoIds = [];
  bool _isLoadingRegionais = true;
  bool _isLoadingSegmentos = true;
  bool _isSaving = false;
  final Map<String, TextEditingController> _telegramChatIdControllers = {};

  @override
  void initState() {
    super.initState();
    _divisaoController = TextEditingController(
      text: widget.divisao?.divisao ?? '',
    );

    if (widget.divisao != null) {
      if (widget.divisao!.regionalIds.isNotEmpty) {
        _selectedRegionalIds = List<String>.from(widget.divisao!.regionalIds);
      } else if (widget.divisao!.regionalId.isNotEmpty) {
        _selectedRegionalIds = [widget.divisao!.regionalId];
      }

      if (widget.divisao!.segmentoIds.isNotEmpty) {
        _selectedSegmentoIds = List<String>.from(widget.divisao!.segmentoIds);
      }
    }

    _loadRegionais();
    _loadSegmentos().then((_) {
      if (widget.divisao != null) {
        _loadTelegramChatIds();
      }
    }).catchError((e) {
      print('Erro ao carregar segmentos: $e');
    });
  }

  Future<void> _loadTelegramChatIds() async {
    if (widget.divisao == null || widget.divisao!.segmentoIds.isEmpty) {
      return;
    }

    try {
      final supabase = SupabaseConfig.client;
      final divisaoId = widget.divisao!.id;

      final divisaoCompleta = await DivisaoService().getDivisaoById(divisaoId);
      if (divisaoCompleta == null) {
        return;
      }

      for (var regionalId in divisaoCompleta.regionalIds) {
        for (var segmentoId in divisaoCompleta.segmentoIds) {
          final comunidade = await supabase
              .from('comunidades')
              .select('id')
              .eq('regional_id', regionalId)
              .eq('divisao_id', divisaoId)
              .eq('segmento_id', segmentoId)
              .maybeSingle();

          if (comunidade != null && comunidade['id'] != null) {
            final telegramCommunity = await supabase
                .from('telegram_communities')
                .select('telegram_chat_id')
                .eq('community_id', comunidade['id'])
                .maybeSingle();

            if (telegramCommunity != null && telegramCommunity['telegram_chat_id'] != null) {
              final chatId = telegramCommunity['telegram_chat_id'].toString();
              if (!_telegramChatIdControllers.containsKey(segmentoId)) {
                _telegramChatIdControllers[segmentoId] = TextEditingController();
              }
              _telegramChatIdControllers[segmentoId]!.text = chatId;
            }
          }
        }
      }
    } catch (e) {
      print('Erro ao carregar Chat IDs do Telegram: $e');
    }
  }

  TextEditingController _getChatIdController(String segmentoId) {
    if (!_telegramChatIdControllers.containsKey(segmentoId)) {
      _telegramChatIdControllers[segmentoId] = TextEditingController();
    }
    return _telegramChatIdControllers[segmentoId]!;
  }

  @override
  void dispose() {
    _divisaoController.dispose();
    for (var controller in _telegramChatIdControllers.values) {
      controller.dispose();
    }
    _telegramChatIdControllers.clear();
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

        // Se for criação e nenhuma selecionada, não pré-seleciona para o usuário escolher conscientemente
      });
    } catch (e) {
      print('Erro ao carregar regionais: $e');
      setState(() {
        _isLoadingRegionais = false;
      });
    }
  }

  Future<void> _loadSegmentos() async {
    setState(() {
      _isLoadingSegmentos = true;
    });

    try {
      final segmentos = await _segmentoService.getAllSegmentos();

      setState(() {
        _segmentos = segmentos;
        _isLoadingSegmentos = false;
      });
    } catch (e) {
      print('Erro ao carregar segmentos: $e');
      setState(() {
        _isLoadingSegmentos = false;
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedRegionalIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione pelo menos uma regional'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedSegmentoIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione pelo menos um segmento'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    // Mapear nomes de regionais
    final regionaisNomes = _regionais
        .where((r) => _selectedRegionalIds.contains(r.id))
        .map((r) => r.regional)
        .toList();

    // Mapear nomes de segmentos
    final segmentosNomes = _segmentos
        .where((s) => _selectedSegmentoIds.contains(s.id))
        .map((s) => s.segmento)
        .toList();

    // Preservar regional legada estável
    String legacyRegionalId = '';
    String legacyRegionalNome = '';

    if (widget.divisao != null && _selectedRegionalIds.contains(widget.divisao!.regionalId)) {
      legacyRegionalId = widget.divisao!.regionalId;
      legacyRegionalNome = widget.divisao!.regional;
    } else if (_selectedRegionalIds.isNotEmpty) {
      legacyRegionalId = _selectedRegionalIds.first;
      final matchReg = _regionais.where((r) => r.id == legacyRegionalId);
      legacyRegionalNome = matchReg.isNotEmpty ? matchReg.first.regional : '';
    }

    final divisao = Divisao(
      id: widget.divisao?.id ?? '',
      divisao: _divisaoController.text.trim(),
      regionalId: legacyRegionalId,
      regional: legacyRegionalNome,
      regionalIds: _selectedRegionalIds,
      regionais: regionaisNomes,
      segmentoIds: _selectedSegmentoIds,
      segmentos: segmentosNomes,
      createdAt: widget.divisao?.createdAt,
      updatedAt: DateTime.now(),
    );

    final telegramChatIds = <String, String>{};
    for (var segmentoId in _selectedSegmentoIds) {
      final controller = _telegramChatIdControllers[segmentoId];
      if (controller != null) {
        var chatId = controller.text.trim();
        if (chatId.isNotEmpty) {
          chatId = chatId.replaceAll(RegExp(r'[^0-9-]'), '');

          if (chatId.isNotEmpty && chatId.startsWith('-') && chatId.length >= 10) {
            telegramChatIds[segmentoId] = chatId;
          }
        }
      }
    }

    Navigator.of(context).pop({
      'divisao': divisao,
      'telegram_chat_ids': telegramChatIds.isEmpty ? null : telegramChatIds,
    });
  }

  String _getRegionalDisplayText(Regional regional) {
    return '${regional.regional} (${regional.empresa})';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.divisao != null;
    final spacing = context.tfSpacing;
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return TFFormDialog(
      title: isEditing ? 'Editar Divisão' : 'Nova Divisão',
      subtitle: 'Configure as regionais de atuação e segmentos vinculados.',
      saveLabel: isEditing ? 'Salvar Alterações' : 'Criar Divisão',
      isSaving: _isSaving,
      onSave: _save,
      onCancel: () => Navigator.of(context).pop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TFTextField(
              label: 'Divisão',
              controller: _divisaoController,
              required: true,
              hint: 'Informe o nome da divisão (ex: NEPTMC)',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Campo obrigatório';
                }
                return null;
              },
            ),
            SizedBox(height: spacing.md),

            // SELEÇÃO MÚLTIPLA DE REGIONAIS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Regionais de Atuação *',
                  style: typography.bodyMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_selectedRegionalIds.isNotEmpty)
                  Text(
                    '${_selectedRegionalIds.length} selecionada(s)',
                    style: typography.bodySmall.copyWith(color: colors.primary),
                  ),
              ],
            ),
            SizedBox(height: spacing.xs),
            Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(TFRadius.r12),
                border: Border.all(color: colors.borderSubtle),
              ),
              padding: EdgeInsets.all(spacing.sm),
              child: _isLoadingRegionais
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _regionais.isEmpty
                      ? Padding(
                          padding: EdgeInsets.all(spacing.sm),
                          child: Text(
                            'Nenhuma regional cadastrada',
                            style: typography.bodySmall.copyWith(color: colors.textSecondary),
                          ),
                        )
                      : Column(
                          children: _regionais.map((regional) {
                            final isSelected = _selectedRegionalIds.contains(regional.id);
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedRegionalIds.remove(regional.id);
                                  } else {
                                    _selectedRegionalIds.add(regional.id);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(TFRadius.r8),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: spacing.xs,
                                  vertical: spacing.xs,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _getRegionalDisplayText(regional),
                                        style: typography.bodyMedium.copyWith(
                                          color: isSelected ? colors.textPrimary : colors.textSecondary,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    Checkbox(
                                      value: isSelected,
                                      onChanged: (value) {
                                        setState(() {
                                          if (value == true) {
                                            _selectedRegionalIds.add(regional.id);
                                          } else {
                                            _selectedRegionalIds.remove(regional.id);
                                          }
                                        });
                                      },
                                      activeColor: colors.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(TFRadius.r4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
            ),
            SizedBox(height: spacing.md),

            // SELEÇÃO MÚLTIPLA DE SEGMENTOS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Segmentos *',
                  style: typography.bodyMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_selectedSegmentoIds.isNotEmpty)
                  Text(
                    '${_selectedSegmentoIds.length} selecionado(s)',
                    style: typography.bodySmall.copyWith(color: colors.primary),
                  ),
              ],
            ),
            SizedBox(height: spacing.xs),
            Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(TFRadius.r12),
                border: Border.all(color: colors.borderSubtle),
              ),
              padding: EdgeInsets.all(spacing.sm),
              child: _isLoadingSegmentos
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _segmentos.isEmpty
                      ? Padding(
                          padding: EdgeInsets.all(spacing.sm),
                          child: Text(
                            'Nenhum segmento disponível',
                            style: typography.bodySmall.copyWith(color: colors.textSecondary),
                          ),
                        )
                      : Column(
                          children: _segmentos.map((segmento) {
                            final isSelected = _selectedSegmentoIds.contains(segmento.id);
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedSegmentoIds.remove(segmento.id);
                                    _telegramChatIdControllers[segmento.id]?.dispose();
                                    _telegramChatIdControllers.remove(segmento.id);
                                  } else {
                                    _selectedSegmentoIds.add(segmento.id);
                                    if (!_telegramChatIdControllers.containsKey(segmento.id)) {
                                      _telegramChatIdControllers[segmento.id] = TextEditingController();
                                    }
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(TFRadius.r8),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: spacing.xs,
                                  vertical: spacing.xs,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        segmento.segmento,
                                        style: typography.bodyMedium.copyWith(
                                          color: isSelected ? colors.textPrimary : colors.textSecondary,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    Checkbox(
                                      value: isSelected,
                                      onChanged: (value) {
                                        setState(() {
                                          if (value == true) {
                                            _selectedSegmentoIds.add(segmento.id);
                                            if (!_telegramChatIdControllers.containsKey(segmento.id)) {
                                              _telegramChatIdControllers[segmento.id] = TextEditingController();
                                            }
                                          } else {
                                            _selectedSegmentoIds.remove(segmento.id);
                                            _telegramChatIdControllers[segmento.id]?.dispose();
                                            _telegramChatIdControllers.remove(segmento.id);
                                          }
                                        });
                                      },
                                      activeColor: colors.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(TFRadius.r4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
            ),
            if (_selectedSegmentoIds.isNotEmpty) ...[
              SizedBox(height: spacing.lg),
              Divider(color: colors.borderSubtle),
              SizedBox(height: spacing.sm),
              Row(
                children: [
                  Icon(Icons.send_rounded, size: 16, color: colors.primary),
                  SizedBox(width: spacing.xs),
                  Text(
                    'Chat IDs do Telegram (Opcional)',
                    style: typography.cardTitle.copyWith(color: colors.textPrimary),
                  ),
                ],
              ),
              SizedBox(height: spacing.xs),
              Text(
                'Configure o ID numérico do grupo do Telegram para notificações automáticas das comunidades.',
                style: typography.bodySmall.copyWith(color: colors.textSecondary),
              ),
              SizedBox(height: spacing.md),
              ..._selectedSegmentoIds.map((segmentoId) {
                final segmento = _segmentos.firstWhere(
                  (s) => s.id == segmentoId,
                  orElse: () => Segmento(
                    id: segmentoId,
                    segmento: 'Segmento',
                  ),
                );
                final controller = _getChatIdController(segmentoId);
                return Padding(
                  padding: EdgeInsets.only(bottom: spacing.md),
                  child: TFTextField(
                    label: 'Chat ID - ${segmento.segmento}',
                    controller: controller,
                    hint: 'Ex: -1001234567890',
                    helperText: 'ID do grupo Telegram para as comunidades deste segmento',
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
