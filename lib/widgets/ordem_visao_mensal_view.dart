import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design_system/taskflow_design_system.dart';
import '../models/ordem.dart';
import '../utils/responsive.dart';

/// Visão global das programações de Ordens mês a mês (`Jan`–`Dez`),
/// utilizando exclusivamente datas de início e fim (da tarefa vinculada
/// quando programada, ou `inicioBase`/`fimBase` da ordem), sem usar tolerância.
class OrdemVisaoMensalView extends StatefulWidget {
  final List<Ordem> ordens;
  final Map<String, List<Map<String, dynamic>>> ordensProgramadasInfo;
  final void Function(Ordem ordem)? onOrdemTap;
  final void Function(Ordem ordem)? onCriarTarefa;
  final void Function(Ordem ordem)? onVincularTarefa;
  final void Function(String taskId)? onVisualizarTarefa;
  final void Function(String taskId)? onEditarTarefa;
  final bool canEdit;

  const OrdemVisaoMensalView({
    super.key,
    required this.ordens,
    this.ordensProgramadasInfo = const {},
    this.onOrdemTap,
    this.onCriarTarefa,
    this.onVincularTarefa,
    this.onVisualizarTarefa,
    this.onEditarTarefa,
    this.canEdit = true,
  });

  @override
  State<OrdemVisaoMensalView> createState() => _OrdemVisaoMensalViewState();
}

class _OrdemVisaoMensalViewState extends State<OrdemVisaoMensalView> {
  static const List<String> _mesesCurtos = [
    'Jan',
    'Fev',
    'Mar',
    'Abr',
    'Mai',
    'Jun',
    'Jul',
    'Ago',
    'Set',
    'Out',
    'Nov',
    'Dez',
  ];

  static final DateFormat _fmtDiaMes = DateFormat('dd/MM');
  static final DateFormat _fmtDiaMesAno = DateFormat('dd/MM/yy');

  late int _anoSelecionado;
  int? _mesFiltrado; // 1..12 ou null para todo o ano
  final ScrollController _horizontalCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _anoSelecionado = _resolverAnoInicial();
  }

  @override
  void dispose() {
    _horizontalCtrl.dispose();
    super.dispose();
  }

  int _resolverAnoInicial() {
    final nowYear = DateTime.now().year;
    final anos = <int, int>{};
    for (final o in widget.ordens) {
      final p = _resolverPeriodo(o);
      if (p != null) {
        anos[p.inicio.year] = (anos[p.inicio.year] ?? 0) + 1;
      }
    }
    if (anos.containsKey(nowYear)) return nowYear;
    if (anos.isEmpty) return nowYear;
    return anos.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  _OrdemPeriodo? _resolverPeriodo(Ordem ordem) {
    final vinculos = widget.ordensProgramadasInfo[ordem.id];
    DateTime? minIni;
    DateTime? maxFim;
    bool temTarefa = false;
    final tarefasVinculadas = <String>[];
    final tarefaIds = <String>[];

    if (vinculos != null && vinculos.isNotEmpty) {
      for (final v in vinculos) {
        final tarefa = v['tarefa'] as Map<String, dynamic>?;
        if (tarefa == null) continue;
        final tid = tarefa['id']?.toString() ?? '';
        if (tid.isNotEmpty && !tarefaIds.contains(tid)) {
          tarefaIds.add(tid);
        }
        final titulo = tarefa['tarefa']?.toString().trim() ?? '';
        if (titulo.isNotEmpty) {
          tarefasVinculadas.add(titulo);
        }
        final ini = _parseDate(tarefa['data_inicio']);
        final fim = _parseDate(tarefa['data_fim']) ?? ini;
        if (ini != null) {
          temTarefa = true;
          if (minIni == null || ini.isBefore(minIni)) minIni = ini;
          if (fim != null && (maxFim == null || fim.isAfter(maxFim))) {
            maxFim = fim;
          }
        }
      }
    }

    if (minIni != null) {
      return _OrdemPeriodo(
        inicio: minIni,
        fim: maxFim ?? minIni,
        programadaEmTarefa: temTarefa,
        tarefasVinculadas: tarefasVinculadas,
        tarefaIds: tarefaIds,
      );
    }

    if (ordem.inicioBase != null) {
      final ini = ordem.inicioBase!.toLocal();
      final fim = (ordem.fimBase ?? ordem.inicioBase!).toLocal();
      return _OrdemPeriodo(
        inicio: ini,
        fim: fim.isBefore(ini) ? ini : fim,
        programadaEmTarefa: tarefasVinculadas.isNotEmpty,
        tarefasVinculadas: tarefasVinculadas,
        tarefaIds: tarefaIds,
      );
    }

    return null;
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toLocal();
    if (raw is String && raw.trim().isNotEmpty) {
      return DateTime.tryParse(raw.trim())?.toLocal();
    }
    return null;
  }

  bool _interceptaMes(_OrdemPeriodo p, int ano, int mes) {
    final inicioMes = DateTime(ano, mes, 1);
    final fimMes = DateTime(ano, mes + 1, 0, 23, 59, 59);
    return !p.fim.isBefore(inicioMes) && !p.inicio.isAfter(fimMes);
  }

  bool _isConcluida(Ordem o) {
    final st = (o.statusSistema ?? '').toUpperCase();
    return st.contains('ENCE') || st.contains('ENTE');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typo = context.tfTypography;
    final isMobile = Responsive.isMobile(context);

    final itensComPeriodo = <_OrdemComPeriodo>[];
    int semData = 0;

    for (final o in widget.ordens) {
      final p = _resolverPeriodo(o);
      if (p == null) {
        semData++;
        continue;
      }
      final noAno = !p.fim.isBefore(DateTime(_anoSelecionado, 1, 1)) &&
          !p.inicio.isAfter(DateTime(_anoSelecionado, 12, 31, 23, 59, 59));
      if (!noAno) continue;
      itensComPeriodo.add(_OrdemComPeriodo(ordem: o, periodo: p));
    }

    itensComPeriodo.sort((a, b) => a.periodo.inicio.compareTo(b.periodo.inicio));

    // Contadores mensais (Jan..Dez)
    final totalPorMes = List<int>.filled(12, 0);
    final progPorMes = List<int>.filled(12, 0);
    for (final item in itensComPeriodo) {
      for (int m = 1; m <= 12; m++) {
        if (_interceptaMes(item.periodo, _anoSelecionado, m)) {
          totalPorMes[m - 1]++;
          if (item.periodo.programadaEmTarefa) {
            progPorMes[m - 1]++;
          }
        }
      }
    }

    final itensVisiveis = _mesFiltrado == null
        ? itensComPeriodo
        : itensComPeriodo
            .where((i) => _interceptaMes(i.periodo, _anoSelecionado, _mesFiltrado!))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTopBar(
          colors,
          typo,
          totalAno: itensComPeriodo.length,
          semData: semData,
        ),
        _buildResumoMensal(colors, typo, totalPorMes, progPorMes),
        const Divider(height: 1),
        Expanded(
          child: itensVisiveis.isEmpty
              ? Center(
                  child: TFEmptyState(
                    icon: Icons.calendar_view_month_outlined,
                    title: _mesFiltrado != null
                        ? 'Nenhuma ordem em ${_mesesCurtos[_mesFiltrado! - 1]}/$_anoSelecionado'
                        : 'Nenhuma ordem com início/fim em $_anoSelecionado',
                    description: semData > 0
                        ? '$semData ordem(ns) sem data de início e fim definida não aparecem na linha do tempo.'
                        : 'Altere o ano ou os filtros acima para visualizar outras programações.',
                    action: _mesFiltrado != null
                        ? OutlinedButton(
                            onPressed: () => setState(() => _mesFiltrado = null),
                            child: const Text('Mostrar ano inteiro'),
                          )
                        : null,
                  ),
                )
              : isMobile
                  ? _buildMobileList(colors, typo, itensVisiveis)
                  : _buildDesktopMatrix(colors, typo, itensVisiveis),
        ),
      ],
    );
  }

  Widget _buildTopBar(
    TFSemanticColors colors,
    TFTypography typo, {
    required int totalAno,
    required int semData,
  }) {
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Ano anterior',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() {
                  _anoSelecionado--;
                  _mesFiltrado = null;
                }),
              ),
              Text(
                'Programação Global — $_anoSelecionado',
                style: typo.cardTitle.copyWith(color: colors.textPrimary),
              ),
              IconButton(
                tooltip: 'Próximo ano',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() {
                  _anoSelecionado++;
                  _mesFiltrado = null;
                }),
              ),
              if (_mesFiltrado != null) ...[
                const SizedBox(width: 8),
                InputChip(
                  label: Text('Mês: ${_mesesCurtos[_mesFiltrado! - 1]}'),
                  onDeleted: () => setState(() => _mesFiltrado = null),
                ),
              ],
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _LegendaCor(color: colors.primary, label: 'Programada (tarefa)'),
              _LegendaCor(color: colors.warning, label: 'Planejada (início/fim base)'),
              _LegendaCor(color: colors.success, label: 'Concluída'),
              TFStatusBadge(
                label: '$totalAno em $_anoSelecionado',
                severity: TFStatusSeverity.info,
                compact: true,
              ),
              if (semData > 0)
                TFStatusBadge(
                  label: '$semData sem início/fim',
                  severity: TFStatusSeverity.neutral,
                  compact: true,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumoMensal(
    TFSemanticColors colors,
    TFTypography typo,
    List<int> totalPorMes,
    List<int> progPorMes,
  ) {
    return Container(
      color: colors.surfaceSecondary.withValues(alpha: 0.45),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(12, (idx) {
            final mes = idx + 1;
            final total = totalPorMes[idx];
            final prog = progPorMes[idx];
            final selecionado = _mesFiltrado == mes;

            return Padding(
              padding: EdgeInsets.only(right: idx < 11 ? 8 : 0),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() {
                  _mesFiltrado = selecionado ? null : mes;
                }),
                child: Container(
                  width: 92,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selecionado
                        ? colors.primary.withValues(alpha: 0.12)
                        : colors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selecionado ? colors.primary : colors.borderSubtle,
                      width: selecionado ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _mesesCurtos[idx],
                        style: typo.labelMedium.copyWith(
                          color: selecionado
                              ? colors.primary
                              : colors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$total',
                        style: typo.cardTitle.copyWith(
                          color: total > 0
                              ? colors.textPrimary
                              : colors.textSecondary,
                        ),
                      ),
                      Text(
                        '$prog prog.',
                        style: typo.labelSmall.copyWith(
                          color: prog > 0
                              ? colors.primary
                              : colors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildDesktopMatrix(
    TFSemanticColors colors,
    TFTypography typo,
    List<_OrdemComPeriodo> itens,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const leftWidth = 475.0;
        final mesesAreaWidth = (constraints.maxWidth - leftWidth).clamp(600.0, 2400.0);
        final colWidth = mesesAreaWidth / 12;

        return Scrollbar(
          controller: _horizontalCtrl,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalCtrl,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: leftWidth + colWidth * 12,
              child: Column(
                children: [
                  // Cabeçalho da matriz
                  Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.surfaceSecondary,
                      border: Border(
                        bottom: BorderSide(color: colors.borderSubtle),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: leftWidth,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Ordem / Período (Início → Fim)',
                            style: typo.labelMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        for (int idx = 0; idx < 12; idx++)
                          Container(
                            width: colWidth,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _mesFiltrado == idx + 1
                                  ? colors.primary.withValues(alpha: 0.1)
                                  : null,
                              border: Border(
                                left: BorderSide(color: colors.borderSubtle),
                              ),
                            ),
                            child: Text(
                              _mesesCurtos[idx],
                              style: typo.labelMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: _mesFiltrado == idx + 1
                                    ? colors.primary
                                    : colors.textPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Linhas virtualizadas
                  Expanded(
                    child: ListView.builder(
                      itemCount: itens.length,
                      itemBuilder: (ctx, index) {
                        final item = itens[index];
                        final o = item.ordem;
                        final p = item.periodo;
                        final concluida = _isConcluida(o);
                        final barColor = concluida
                            ? colors.success
                            : (p.programadaEmTarefa
                                ? colors.primary
                                : colors.warning);
                        final periodoLabel = p.inicio.year == p.fim.year
                            ? '${_fmtDiaMes.format(p.inicio)} a ${_fmtDiaMes.format(p.fim)}'
                            : '${_fmtDiaMesAno.format(p.inicio)} a ${_fmtDiaMesAno.format(p.fim)}';

                        return InkWell(
                          onTap: widget.onOrdemTap != null
                              ? () => widget.onOrdemTap!(o)
                              : null,
                          child: Container(
                            height: 68,
                            decoration: BoxDecoration(
                              color: index.isEven
                                  ? colors.surface
                                  : colors.surfaceSecondary
                                      .withValues(alpha: 0.25),
                              border: Border(
                                bottom: BorderSide(
                                  color: colors.borderSubtle.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: leftWidth,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  o.ordem,
                                                  style: typo.labelMedium
                                                      .copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    color: colors.primary,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                if (o.local != null &&
                                                    o.local!.isNotEmpty)
                                                  TFStatusBadge(
                                                    label: o.local!,
                                                    severity:
                                                        TFStatusSeverity.neutral,
                                                    compact: true,
                                                  ),
                                                const SizedBox(width: 6),
                                                TFStatusBadge(
                                                  label: p.programadaEmTarefa
                                                      ? 'Programada'
                                                      : 'Não programada',
                                                  severity: p.programadaEmTarefa
                                                      ? TFStatusSeverity.success
                                                      : TFStatusSeverity.warning,
                                                  icon: p.programadaEmTarefa
                                                      ? Icons
                                                          .event_available_outlined
                                                      : Icons.schedule_outlined,
                                                  compact: true,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    periodoLabel,
                                                    textAlign: TextAlign.right,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: typo.labelSmall
                                                        .copyWith(
                                                      color:
                                                          colors.textSecondary,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              o.textoBreve ?? '-',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: typo.bodySmall.copyWith(
                                                color: colors.textPrimary,
                                              ),
                                            ),
                                            if (p.tarefasVinculadas.isNotEmpty)
                                              Text(
                                                'Atividade: ${p.tarefasVinculadas.join(', ')}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: typo.labelSmall.copyWith(
                                                  color: colors.primary,
                                                  fontSize: 11,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (p.tarefaIds.isNotEmpty &&
                                          widget.onVisualizarTarefa != null)
                                        IconButton(
                                          tooltip: 'Visualizar tarefa',
                                          visualDensity: VisualDensity.compact,
                                          iconSize: 18,
                                          color: colors.success,
                                          icon: const Icon(
                                              Icons.visibility_outlined),
                                          onPressed: () =>
                                              widget.onVisualizarTarefa!(
                                                  p.tarefaIds.first),
                                        ),
                                      if (p.tarefaIds.isNotEmpty &&
                                          widget.canEdit &&
                                          widget.onEditarTarefa != null)
                                        IconButton(
                                          tooltip: 'Editar tarefa',
                                          visualDensity: VisualDensity.compact,
                                          iconSize: 18,
                                          color: colors.primary,
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: () =>
                                              widget.onEditarTarefa!(
                                                  p.tarefaIds.first),
                                        ),
                                      if (widget.canEdit &&
                                          (widget.onCriarTarefa != null ||
                                              widget.onVincularTarefa !=
                                                  null)) ...[
                                        const SizedBox(width: 4),
                                        if (widget.onCriarTarefa != null)
                                          IconButton(
                                            tooltip: 'Criar tarefa',
                                            visualDensity:
                                                VisualDensity.compact,
                                            iconSize: 18,
                                            color: colors.primary,
                                            icon: const Icon(
                                                Icons.add_task_outlined),
                                            onPressed: () =>
                                                widget.onCriarTarefa!(o),
                                          ),
                                        if (widget.onVincularTarefa != null)
                                          IconButton(
                                            tooltip:
                                                'Vincular a tarefa existente',
                                            visualDensity:
                                                VisualDensity.compact,
                                            iconSize: 18,
                                            color: colors.info,
                                            icon: const Icon(Icons.link),
                                            onPressed: () =>
                                                widget.onVincularTarefa!(o),
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                                for (int m = 1; m <= 12; m++)
                                  Container(
                                    width: colWidth,
                                    height: 68,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        left: BorderSide(
                                          color: colors.borderSubtle
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ),
                                    child: _interceptaMes(p, _anoSelecionado, m)
                                        ? Center(
                                            child: Tooltip(
                                              message:
                                                  '${o.ordem} • $periodoLabel\n${p.programadaEmTarefa ? 'Programada em tarefa' : 'Planejada (Início/Fim base)'}',
                                              child: Container(
                                                height: 20,
                                                margin: const EdgeInsets.symmetric(
                                                  horizontal: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: barColor.withValues(
                                                    alpha: 0.85,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                              ),
                                            ),
                                          )
                                        : null,
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
          ),
        );
      },
    );
  }

  Widget _buildMobileList(
    TFSemanticColors colors,
    TFTypography typo,
    List<_OrdemComPeriodo> itens,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: itens.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, idx) {
        final item = itens[idx];
        final o = item.ordem;
        final p = item.periodo;
        final concluida = _isConcluida(o);
        final mesesAtivos = <String>[
          for (int m = 1; m <= 12; m++)
            if (_interceptaMes(p, _anoSelecionado, m)) _mesesCurtos[m - 1],
        ];
        final periodoLabel =
            '${_fmtDiaMesAno.format(p.inicio)} a ${_fmtDiaMesAno.format(p.fim)}';

        return TFCard(
          onTap: widget.onOrdemTap != null ? () => widget.onOrdemTap!(o) : null,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    o.ordem,
                    style: typo.labelMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (o.local != null && o.local!.isNotEmpty)
                    TFStatusBadge(
                      label: o.local!,
                      severity: TFStatusSeverity.neutral,
                      compact: true,
                    ),
                  const Spacer(),
                  TFStatusBadge(
                    label: concluida
                        ? 'Concluída'
                        : (p.programadaEmTarefa ? 'Programada' : 'Base'),
                    severity: concluida
                        ? TFStatusSeverity.success
                        : (p.programadaEmTarefa
                            ? TFStatusSeverity.info
                            : TFStatusSeverity.warning),
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                o.textoBreve ?? '-',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: typo.bodySmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Período: $periodoLabel',
                style: typo.labelSmall.copyWith(color: colors.textSecondary),
              ),
              if (p.tarefasVinculadas.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Atividade: ${p.tarefasVinculadas.join(', ')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typo.labelSmall.copyWith(color: colors.primary),
                ),
              ],
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: mesesAtivos
                    .map(
                      (m) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          m,
                          style: typo.labelSmall.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              if ((p.tarefaIds.isNotEmpty &&
                      widget.onVisualizarTarefa != null) ||
                  (widget.canEdit &&
                      (widget.onCriarTarefa != null ||
                          widget.onVincularTarefa != null))) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (p.tarefaIds.isNotEmpty &&
                        widget.onVisualizarTarefa != null)
                      OutlinedButton.icon(
                        onPressed: () =>
                            widget.onVisualizarTarefa!(p.tarefaIds.first),
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text('Ver tarefa'),
                      ),
                    if (p.tarefaIds.isNotEmpty &&
                        widget.canEdit &&
                        widget.onEditarTarefa != null)
                      OutlinedButton.icon(
                        onPressed: () =>
                            widget.onEditarTarefa!(p.tarefaIds.first),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Editar tarefa'),
                      ),
                    if (widget.canEdit && widget.onCriarTarefa != null)
                      OutlinedButton.icon(
                        onPressed: () => widget.onCriarTarefa!(o),
                        icon: const Icon(Icons.add_task_outlined, size: 16),
                        label: const Text('Criar tarefa'),
                      ),
                    if (widget.canEdit && widget.onVincularTarefa != null)
                      OutlinedButton.icon(
                        onPressed: () => widget.onVincularTarefa!(o),
                        icon: const Icon(Icons.link, size: 16),
                        label: const Text('Vincular tarefa'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _OrdemPeriodo {
  final DateTime inicio;
  final DateTime fim;
  final bool programadaEmTarefa;
  final List<String> tarefasVinculadas;
  final List<String> tarefaIds;

  const _OrdemPeriodo({
    required this.inicio,
    required this.fim,
    required this.programadaEmTarefa,
    this.tarefasVinculadas = const [],
    this.tarefaIds = const [],
  });
}

class _OrdemComPeriodo {
  final Ordem ordem;
  final _OrdemPeriodo periodo;

  const _OrdemComPeriodo({
    required this.ordem,
    required this.periodo,
  });
}

class _LegendaCor extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendaCor({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: context.tfTypography.labelSmall),
      ],
    );
  }
}

