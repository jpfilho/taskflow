import 'package:flutter/material.dart';
import '../design_system/theme/taskflow_theme_extension.dart';
import '../models/carteira_manutencao_models.dart';
import '../services/carteira_service.dart';

/// Modal dialog para atribuição ou reprogramação de previsão de atendimento (Individual ou em Lote).
class PrevisaoDialog extends StatefulWidget {
  final String? notaSapId;
  final String? numeroNota;
  final DateTime? dataVencimento;
  final int? mesAtual;
  final int? anoAtual;
  final String? motivoAtual;

  // Parâmetros para modo em lote
  final bool isLote;
  final List<String> notaSapIds;
  final Map<String, String> numeroPorNotaId;
  final Map<String, DateTime?> vencimentoPorNotaId;

  const PrevisaoDialog({
    super.key,
    this.notaSapId,
    this.numeroNota,
    this.dataVencimento,
    this.mesAtual,
    this.anoAtual,
    this.motivoAtual,
    this.isLote = false,
    this.notaSapIds = const [],
    this.numeroPorNotaId = const {},
    this.vencimentoPorNotaId = const {},
  });

  /// Abre o modal para uma nota individual
  static Future<bool?> showIndividual(
    BuildContext context, {
    required String notaSapId,
    required String numeroNota,
    DateTime? dataVencimento,
    int? mesAtual,
    int? anoAtual,
    String? motivoAtual,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PrevisaoDialog(
        notaSapId: notaSapId,
        numeroNota: numeroNota,
        dataVencimento: dataVencimento,
        mesAtual: mesAtual,
        anoAtual: anoAtual,
        motivoAtual: motivoAtual,
        isLote: false,
      ),
    );
  }

  /// Abre o modal para seleção em lote
  static Future<String?> showLote(
    BuildContext context, {
    required List<String> notaSapIds,
    required Map<String, String> numeroPorNotaId,
    required Map<String, DateTime?> vencimentoPorNotaId,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PrevisaoDialog(
        isLote: true,
        notaSapIds: notaSapIds,
        numeroPorNotaId: numeroPorNotaId,
        vencimentoPorNotaId: vencimentoPorNotaId,
      ),
    );
  }

  @override
  State<PrevisaoDialog> createState() => _PrevisaoDialogState();
}

class _PrevisaoDialogState extends State<PrevisaoDialog> {
  late int _mesSelecionado;
  late int _anoSelecionado;
  late TextEditingController _motivoController;
  bool _salvando = false;
  List<HistoricoPrevisaoNota>? _historico;
  bool _carregandoHistorico = false;
  bool _mostrarHistorico = false;

  static const List<String> _nomesMeses = [
    'Janeiro (01)',
    'Fevereiro (02)',
    'Março (03)',
    'Abril (04)',
    'Maio (05)',
    'Junho (06)',
    'Julho (07)',
    'Agosto (08)',
    'Setembro (09)',
    'Outubro (10)',
    'Novembro (11)',
    'Dezembro (12)',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _mesSelecionado = widget.mesAtual ?? (now.month == 12 ? 1 : now.month + 1);
    _anoSelecionado = widget.anoAtual ?? (now.month == 12 ? now.year + 1 : now.year);
    _motivoController = TextEditingController(text: widget.motivoAtual ?? '');

    if (!widget.isLote && widget.notaSapId != null) {
      _carregarHistorico();
    }
  }

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _carregarHistorico() async {
    setState(() => _carregandoHistorico = true);
    final hist = await CarteiraService().obterHistoricoPrevisoes(notaSapId: widget.notaSapId!);
    if (mounted) {
      setState(() {
        _historico = hist;
        _carregandoHistorico = false;
      });
    }
  }

  /// Confronta o mês e ano selecionados com os vencimentos para alertar risco
  Map<String, dynamic> _analisarRisco() {
    if (widget.isLote) {
      int violacoes = 0;
      int coincidem = 0;

      for (final id in widget.notaSapIds) {
        final venc = widget.vencimentoPorNotaId[id];
        if (venc != null) {
          if (_anoSelecionado > venc.year || (_anoSelecionado == venc.year && _mesSelecionado > venc.month)) {
            violacoes++;
          } else if (_anoSelecionado == venc.year && _mesSelecionado == venc.month) {
            coincidem++;
          }
        }
      }

      return {
        'temRisco': violacoes > 0,
        'violacoes': violacoes,
        'coincidem': coincidem,
      };
    } else {
      final venc = widget.dataVencimento;
      if (venc == null) return {'temRisco': false, 'tipo': 'sem_prazo'};

      if (_anoSelecionado > venc.year || (_anoSelecionado == venc.year && _mesSelecionado > venc.month)) {
        return {
          'temRisco': true,
          'tipo': 'violacao',
          'mensagem': 'A previsão é posterior ao vencimento da nota (${venc.day.toString().padLeft(2, '0')}/${venc.month.toString().padLeft(2, '0')}/${venc.year}) — Risco Crítico de Violação (SIT-3).',
        };
      } else if (_anoSelecionado == venc.year && _mesSelecionado == venc.month) {
        return {
          'temRisco': true,
          'tipo': 'atencao',
          'mensagem': 'A previsão coincide com o mês de vencimento da nota (${venc.day.toString().padLeft(2, '0')}/${venc.month.toString().padLeft(2, '0')}/${venc.year}) — Risco de Incerteza Temporal (SIT-2).',
        };
      }

      return {'temRisco': false, 'tipo': 'compativel'};
    }
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    final motivo = _motivoController.text.trim();

    if (widget.isLote) {
      final loteId = await CarteiraService().atribuirPrevisaoEmLote(
        notaSapIds: widget.notaSapIds,
        numeroPorNotaId: widget.numeroPorNotaId,
        mes: _mesSelecionado,
        ano: _anoSelecionado,
        motivo: motivo.isEmpty ? 'Atribuição em lote' : motivo,
      );

      if (mounted) {
        setState(() => _salvando = false);
        Navigator.of(context).pop(loteId);
      }
    } else {
      final ok = await CarteiraService().atribuirPrevisaoIndividual(
        notaSapId: widget.notaSapId!,
        numeroNota: widget.numeroNota ?? '',
        mes: _mesSelecionado,
        ano: _anoSelecionado,
        motivo: motivo.isEmpty ? null : motivo,
      );

      if (mounted) {
        setState(() => _salvando = false);
        Navigator.of(context).pop(ok);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<TaskFlowThemeExtension>();
    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final anos = List.generate(6, (i) => now.year + i);
    final analiseRisco = _analisarRisco();

    final titulo = widget.isLote
        ? 'Definir Previsão em Lote (${widget.notaSapIds.length} notas)'
        : 'Previsão de Atendimento — Nota ${widget.numeroNota ?? ""}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (ext?.colors.primary ?? colors.primary).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.calendar_month, color: ext?.colors.primary ?? colors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.isLote
                              ? 'Atribui mês e ano de atendimento para as notas selecionadas'
                              : 'Gerenciamento da previsão individual de atendimento',
                          style: TextStyle(fontSize: 12, color: ext?.colors.textSecondary ?? Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ],
              ),
              const Divider(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Seleção de Mês e Ano
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<int>(
                              value: _mesSelecionado,
                              decoration: const InputDecoration(
                                labelText: 'Mês de Atendimento',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              ),
                              items: List.generate(12, (index) {
                                final mes = index + 1;
                                return DropdownMenuItem<int>(
                                  value: mes,
                                  child: Text(_nomesMeses[index], style: const TextStyle(fontSize: 13)),
                                );
                              }),
                              onChanged: (val) {
                                if (val != null) setState(() => _mesSelecionado = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<int>(
                              value: _anoSelecionado,
                              decoration: const InputDecoration(
                                labelText: 'Ano',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              ),
                              items: anos.map((ano) {
                                return DropdownMenuItem<int>(
                                  value: ano,
                                  child: Text(ano.toString(), style: const TextStyle(fontSize: 13)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _anoSelecionado = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Alerta de Prazo e Risco
                      if (analiseRisco['temRisco'] == true) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: analiseRisco['tipo'] == 'violacao' || (analiseRisco['violacoes'] ?? 0) > 0
                                ? (ext?.colors.danger ?? Colors.red).withOpacity(0.08)
                                : (ext?.colors.warning ?? Colors.amber).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: analiseRisco['tipo'] == 'violacao' || (analiseRisco['violacoes'] ?? 0) > 0
                                  ? (ext?.colors.danger ?? Colors.red).withOpacity(0.4)
                                  : (ext?.colors.warning ?? Colors.amber).withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 20,
                                color: analiseRisco['tipo'] == 'violacao' || (analiseRisco['violacoes'] ?? 0) > 0
                                    ? (ext?.colors.danger ?? Colors.red)
                                    : (ext?.colors.warning ?? Colors.amber.shade800),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  widget.isLote
                                      ? '${analiseRisco["violacoes"]} nota(s) possuem prazo SAP anterior à previsão escolhida!'
                                      : analiseRisco['mensagem'].toString(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: analiseRisco['tipo'] == 'violacao' || (analiseRisco['violacoes'] ?? 0) > 0
                                        ? (ext?.colors.danger ?? Colors.red.shade900)
                                        : (ext?.colors.warning ?? Colors.amber.shade900),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Motivo ou Justificativa da Previsão
                      TextField(
                        controller: _motivoController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Motivo / Justificativa da Previsão (Opcional)',
                          hintText: 'Ex: Disponibilidade de equipe, janela de desligamento, etc.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Sugestões de Motivo
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          'Disponibilidade de equipe',
                          'Janela de desligamento',
                          'Aguardando sobressalente',
                          'Alinhamento com cliente',
                        ].map((sugestao) {
                          return ActionChip(
                            label: Text(sugestao, style: const TextStyle(fontSize: 10)),
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              setState(() {
                                _motivoController.text = sugestao;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Histórico de Alterações (se modo individual)
                      if (!widget.isLote) ...[
                        InkWell(
                          onTap: () {
                            setState(() => _mostrarHistorico = !_mostrarHistorico);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  _mostrarHistorico ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                                  size: 18,
                                  color: ext?.colors.primary ?? colors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Histórico de Reprogramações (${_historico?.length ?? 0})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: ext?.colors.primary ?? colors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_mostrarHistorico) ...[
                          const SizedBox(height: 8),
                          if (_carregandoHistorico)
                            const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
                          else if (_historico == null || _historico!.isEmpty)
                            Text(
                              'Nenhum histórico registrado para esta nota.',
                              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                children: _historico!.map((h) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.history, size: 14, color: Colors.grey.shade600),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                h.descricaoMudanca,
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                              Text(
                                                'Por: ${h.alteradoPorNome ?? "Usuário"} em ${h.alteradoEm.day}/${h.alteradoEm.month}/${h.alteradoEm.year} ${h.alteradoEm.hour}:${h.alteradoEm.minute.toString().padLeft(2, '0')}',
                                                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                              ),
                                              if (h.motivo != null && h.motivo!.isNotEmpty)
                                                Text(
                                                  'Motivo: ${h.motivo}',
                                                  style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey.shade700),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              const Divider(height: 24),

              // Botões de Ação
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _salvando ? null : () => Navigator.of(context).pop(null),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _salvando ? null : _salvar,
                    icon: _salvando
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check, size: 16),
                    label: Text(_salvando ? 'Salvando...' : 'Salvar Previsão'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ext?.colors.primary ?? colors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
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
