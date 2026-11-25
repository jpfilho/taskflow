import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../design_system/taskflow_design_system.dart';
import '../../../../models/task.dart';
import '../../domain/enums/task_apoio_enums.dart';

/// Resultado do diálogo "Vincular atividade existente".
class TaskApoioVincularResultado {
  final Task taskSelecionada;
  final TaskApoioFinalidadeVinculo finalidade;
  final bool autorizadoDireto;
  final String? observacao;

  const TaskApoioVincularResultado({
    required this.taskSelecionada,
    required this.finalidade,
    required this.autorizadoDireto,
    this.observacao,
  });
}

/// Diálogo "Vincular atividade existente" (Item 12).
/// Realiza pesquisa paginada/sob demanda usando callback fornecido pelo chamador,
/// evitando carregar toda a programação de outras divisões indiscriminadamente.
class TaskApoioVincularDialog extends StatefulWidget {
  final String taskPrincipalId;
  final String? divisaoPrincipalId;
  final Future<List<Task>> Function({
    String? termo,
    String? regional,
    String? divisao,
    String? status,
    int limit,
    int offset,
  }) onBuscarAtividades;
  final bool Function(Task taskDestino)? verificarAutorizacaoDireta;

  const TaskApoioVincularDialog({
    super.key,
    required this.taskPrincipalId,
    this.divisaoPrincipalId,
    required this.onBuscarAtividades,
    this.verificarAutorizacaoDireta,
  });

  @override
  State<TaskApoioVincularDialog> createState() =>
      _TaskApoioVincularDialogState();
}

class _TaskApoioVincularDialogState extends State<TaskApoioVincularDialog> {
  final _buscaCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  final _fmt = DateFormat('dd/MM HH:mm');

  TaskApoioFinalidadeVinculo _finalidade =
      TaskApoioFinalidadeVinculo.apoioOperacional;
  List<Task> _resultados = const [];
  Task? _selecionada;
  bool _carregando = false;
  String? _erro;
  int _offset = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _executarBusca(reset: true);
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _executarBusca({bool reset = false}) async {
    if (reset) _offset = 0;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final lista = await widget.onBuscarAtividades(
        termo: _buscaCtrl.text.trim(),
        limit: _pageSize,
        offset: _offset,
      );
      if (!mounted) return;
      setState(() {
        _resultados = lista
            .where((t) => t.id != widget.taskPrincipalId)
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typo = context.tfTypography;

    final autorizadoDireto = _selecionada != null &&
        (widget.verificarAutorizacaoDireta?.call(_selecionada!) ??
            (_selecionada!.divisaoId == widget.divisaoPrincipalId));

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.link_rounded, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Vincular atividade existente',
              style: typo.sectionTitle,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 580,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _buscaCtrl,
                    decoration: const InputDecoration(
                      labelText:
                          'Buscar por descrição, local, Nota/Ordem SAP ou unidade',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _executarBusca(reset: true),
                  ),
                ),
                const SizedBox(width: 8),
                TFButton(
                  label: 'Buscar',
                  size: TFButtonSize.small,
                  variant: TFButtonVariant.secondary,
                  onPressed: () => _executarBusca(reset: true),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<TaskApoioFinalidadeVinculo>(
              initialValue: _finalidade,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Finalidade do relacionamento',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(
                  value: TaskApoioFinalidadeVinculo.apoioOperacional,
                  child: Text('Atendimento de solicitação existente'),
                ),
                DropdownMenuItem(
                  value: TaskApoioFinalidadeVinculo.vinculoDireto,
                  child: Text('Apoio direto'),
                ),
                DropdownMenuItem(
                  value: TaskApoioFinalidadeVinculo.programacaoConjunta,
                  child: Text('Programação conjunta'),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _finalidade = v);
              },
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _carregando
                  ? const Center(child: CircularProgressIndicator())
                  : _erro != null
                      ? Center(
                          child: TFStatusBadge(
                            label: 'Falha na busca: $_erro',
                            severity: TFStatusSeverity.danger,
                            icon: Icons.error_outline,
                          ),
                        )
                      : _resultados.isEmpty
                          ? Center(
                              child: Text(
                                'Nenhuma atividade encontrada para os filtros.',
                                style: typo.bodySmall,
                              ),
                            )
                          : ListView.separated(
                              itemCount: _resultados.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (_, idx) {
                                final t = _resultados[idx];
                                final selected = _selecionada?.id == t.id;
                                return TFCard(
                                  variant: TFCardVariant.interactive,
                                  selected: selected,
                                  padding: const EdgeInsets.all(10),
                                  onTap: () => setState(() => _selecionada = t),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              t.tarefa,
                                              style: typo.labelMedium.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          TFStatusBadge(
                                            label: t.status,
                                            compact: true,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${t.regional} / ${t.divisao} • ${t.locais.join(', ')}',
                                        style: typo.bodySmall.copyWith(
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        'Período: ${_fmt.format(t.dataInicio.toLocal())} – ${_fmt.format(t.dataFim.toLocal())}'
                                        '${t.frota.isNotEmpty ? ' • Frota: ${t.frota}' : ''}',
                                        style: typo.bodySmall.copyWith(
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
            if (_selecionada != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: autorizadoDireto
                      ? colors.successBackground
                      : colors.warningBackground,
                  borderRadius: TFRadius.borderRadiusSm,
                  border: Border.all(
                    color: (autorizadoDireto ? colors.success : colors.warning)
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      autorizadoDireto
                          ? Icons.verified_user_outlined
                          : Icons.hourglass_top_rounded,
                      size: 16,
                      color: autorizadoDireto ? colors.success : colors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        autorizadoDireto
                            ? 'Vínculo direto autorizado entre atividades sob sua gestão'
                            : 'Outra unidade: vínculo ficará aguardando confirmação da unidade responsável',
                        style: typo.bodySmall.copyWith(
                          color: autorizadoDireto
                              ? colors.success
                              : colors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _obsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Observação do vínculo (opcional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TFButton(
          label: 'Cancelar',
          variant: TFButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        TFButton(
          label: autorizadoDireto
              ? 'Vincular atividade'
              : 'Solicitar confirmação de vínculo',
          variant: TFButtonVariant.primary,
          leadingIcon: Icons.link_rounded,
          onPressed: _selecionada == null
              ? null
              : () => Navigator.of(context).pop(
                    TaskApoioVincularResultado(
                      taskSelecionada: _selecionada!,
                      finalidade: _finalidade,
                      autorizadoDireto: autorizadoDireto,
                      observacao: _obsCtrl.text.trim().isEmpty
                          ? null
                          : _obsCtrl.text.trim(),
                    ),
                  ),
        ),
      ],
    );
  }
}
