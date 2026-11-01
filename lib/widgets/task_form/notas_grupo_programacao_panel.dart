import 'package:flutter/material.dart';
import '../../models/nota_sap.dart';
import '../../models/nota_sap_analise.dart';
import '../../models/nota_sap_grupo.dart';

/// Painel para seleção de Notas SAP vinculadas a um Grupo Ativo no TaskFormDialog.
///
/// Princípios fundamentais:
/// - grupo != tarefa
/// - previsão != agendamento
/// - vínculo != obrigação de programar junto
/// - sugestão != seleção automática
///
/// Responsabilidades:
/// 1. Apresentar o cabeçalho do grupo (Nome, Previsão Mês/Ano e Motivo).
/// 2. Listar todas as Notas do grupo com situação de programação e análise.
/// 3. Garantir que a Nota que iniciou a programação permaneça selecionada e travada.
/// 4. Permitir ao programador selecionar/desmarcar notas adicionais livremente.
/// 5. Para notas já programadas em outra tarefa, exigir confirmação explícita antes de incluir.
/// 6. Disponibilizar atalhos para "Selecionar todas as não programadas" e "Limpar seleção adicional".
class NotasGrupoProgramacaoPanel extends StatefulWidget {
  final NotaSAP? notaOrigem;
  final NotaSapGrupo grupo;
  final List<NotaSapGrupoItem> itens;
  final Map<String, NotaSapAnalise> analises;
  final Set<String> selectedNotaIds;
  final ValueChanged<Set<String>> onSelectionChanged;
  final DateTime? dataProgramadaTarefa;
  final bool isEdicao;

  const NotasGrupoProgramacaoPanel({
    super.key,
    this.notaOrigem,
    required this.grupo,
    required this.itens,
    this.analises = const {},
    required this.selectedNotaIds,
    required this.onSelectionChanged,
    this.dataProgramadaTarefa,
    this.isEdicao = false,
  });

  @override
  State<NotasGrupoProgramacaoPanel> createState() =>
      _NotasGrupoProgramacaoPanelState();
}

class _NotasGrupoProgramacaoPanelState
    extends State<NotasGrupoProgramacaoPanel> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = theme.colorScheme.primary;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final cardBg = isDark
        ? theme.colorScheme.surface
        : Colors.grey.shade50;

    final statusProg = GrupoStatusProgramacao.calcular(widget.itens);
    final totalNotas = widget.itens.length;
    final totalSelecionadas = widget.selectedNotaIds.length;

    // Verificar se a data da tarefa está fora da previsão do grupo
    final bool dataForaDaPrevisao = _verificarDataForaDaPrevisao();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // CABEÇALHO DO GRUPO
          _buildHeader(context, primaryColor, totalSelecionadas, totalNotas),

          // CORPO EXPANSÍVEL
          if (_isExpanded) ...[
            const Divider(height: 1),

            // ALERTA DE DATA FORA DA PREVISÃO (INFORMATIVO, NÃO BLOQUEANTE)
            if (dataForaDaPrevisao) _buildAvisoDataForaPrevisao(context),

            // RESUMO DA SITUAÇÃO DO GRUPO
            _buildResumoSituacaoGrupo(context, statusProg),

            // BARRA DE AÇÕES RÁPIDAS E CONTADOR
            _buildBarraAcoes(context, primaryColor),

            const Divider(height: 1),

            // LISTA DE NOTAS DO GRUPO
            _buildListaNotas(context, borderColor, primaryColor),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // 1. CABEÇALHO PRINCIPAL
  // ===========================================================================

  Widget _buildHeader(
    BuildContext context,
    Color primaryColor,
    int totalSelecionadas,
    int totalNotas,
  ) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.hub_outlined,
                    color: primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'GRUPO DE NOTAS VINCULADAS',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$totalSelecionadas de $totalNotas selecionada${totalSelecionadas != 1 ? 's' : ''}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.grupo.nome,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  tooltip: _isExpanded ? 'Recolher painel' : 'Expandir painel',
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Metadados do grupo: Previsão e Motivo
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 15,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Previsão: ',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      widget.grupo.temPrevisao
                          ? widget.grupo.previsaoFormatada
                          : 'Não definida',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: widget.grupo.temPrevisao
                            ? primaryColor
                            : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                if (widget.grupo.motivo != null &&
                    widget.grupo.motivo!.trim().isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 15,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Motivo: ',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color:
                              theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          widget.grupo.motivo!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 2. AVISOS E SITUAÇÃO DO GRUPO
  // ===========================================================================

  bool _verificarDataForaDaPrevisao() {
    if (!widget.grupo.temPrevisao || widget.dataProgramadaTarefa == null) {
      return false;
    }
    final dt = widget.dataProgramadaTarefa!;
    return dt.month != widget.grupo.mesProgramacaoPrevisto ||
        dt.year != widget.grupo.anoProgramacaoPrevisto;
  }

  Widget _buildAvisoDataForaPrevisao(BuildContext context) {
    final theme = Theme.of(context);
    final dt = widget.dataProgramadaTarefa!;
    const meses = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
    ];
    final mesAnoTarefa = '${meses[dt.month - 1]}/${dt.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.amber.withValues(alpha: 0.12),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            size: 16,
            color: Colors.amber,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'A data programada ($mesAnoTarefa) está fora do mês inicialmente previsto para o grupo (${widget.grupo.previsaoFormatada}).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.amber.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumoSituacaoGrupo(
    BuildContext context,
    GrupoStatusProgramacao statusProg,
  ) {
    final theme = Theme.of(context);

    String textoDestaque;
    Color corDestaque;
    IconData iconeDestaque;

    if (statusProg.isTotal) {
      textoDestaque = 'Todas as Notas deste grupo já possuem programação.';
      corDestaque = Colors.blue.shade700;
      iconeDestaque = Icons.check_circle_outline;
    } else if (statusProg.isParcial) {
      final pendentes = statusProg.notasNaoProgramadas;
      textoDestaque = pendentes == 1
          ? 'Há outra 1 Nota ainda não programada neste grupo.'
          : 'Há outras $pendentes Notas ainda não programadas neste grupo.';
      corDestaque = Colors.teal.shade700;
      iconeDestaque = Icons.schedule_outlined;
    } else {
      textoDestaque = 'Nenhuma Nota deste grupo foi programada ainda.';
      corDestaque = Colors.indigo.shade700;
      iconeDestaque = Icons.format_list_bulleted_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: corDestaque.withValues(alpha: 0.06),
      child: Row(
        children: [
          Icon(iconeDestaque, size: 16, color: corDestaque),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              textoDestaque,
              style: theme.textTheme.bodySmall?.copyWith(
                color: corDestaque,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. BARRA DE AÇÕES RÁPIDAS
  // ===========================================================================

  Widget _buildBarraAcoes(BuildContext context, Color primaryColor) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    // Calcular se há notas adicionais selecionadas além da nota principal
    final int adicionaisSelecionadas = widget.notaOrigem != null
        ? widget.selectedNotaIds
            .where((id) => id != widget.notaOrigem!.id)
            .length
        : widget.selectedNotaIds.length;

    // Calcular notas não programadas que ainda não estão selecionadas
    final naoProgramadasNaoSelecionadas = widget.itens.where((item) {
      return !item.isProgramada && !widget.selectedNotaIds.contains(item.notaSapId);
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          // Contador contextual
          Text(
            widget.notaOrigem != null
                ? '1 Nota principal + $adicionaisSelecionadas adicional(is)'
                : '${widget.selectedNotaIds.length} de ${widget.itens.length} Notas selecionadas',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),

          // Botões de ação em lote
          Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (naoProgramadasNaoSelecionadas.isNotEmpty)
                TextButton.icon(
                  onPressed: _selecionarTodasNaoProgramadas,
                  icon: const Icon(Icons.playlist_add_check, size: 16),
                  label: Text(
                    isMobile ? 'Todas livres' : 'Selecionar todas as não programadas',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              if (adicionaisSelecionadas > 0)
                TextButton.icon(
                  onPressed: _limparSelecaoAdicional,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: Text(
                    isMobile ? 'Limpar extra' : 'Limpar seleção adicional',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. LISTA DE NOTAS DO GRUPO
  // ===========================================================================

  Widget _buildListaNotas(
    BuildContext context,
    Color borderColor,
    Color primaryColor,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.itens.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 16,
        endIndent: 16,
        color: borderColor,
      ),
      itemBuilder: (context, index) {
        final item = widget.itens[index];
        final nota = item.nota;
        final notaId = item.notaSapId;
        final isOrigem = widget.notaOrigem != null && widget.notaOrigem!.id == notaId;
        final isSelected = widget.selectedNotaIds.contains(notaId);
        final analise = widget.analises[notaId];

        return _buildItemNota(
          context: context,
          item: item,
          nota: nota,
          isOrigem: isOrigem,
          isSelected: isSelected,
          analise: analise,
          primaryColor: primaryColor,
        );
      },
    );
  }

  Widget _buildItemNota({
    required BuildContext context,
    required NotaSapGrupoItem item,
    required NotaSAP? nota,
    required bool isOrigem,
    required bool isSelected,
    required NotaSapAnalise? analise,
    required Color primaryColor,
  }) {
    final theme = Theme.of(context);
    final numeroNota = nota?.nota ?? item.notaSapId;
    final descricao = nota?.descricao ?? 'Sem descrição';
    final localOuEquip = nota?.equipamento ?? nota?.localInstalacao ?? '-';
    final statusSap = nota?.statusSistema ?? nota?.statusUsuario ?? '';

    return InkWell(
      onTap: isOrigem
          ? null
          : () => _toggleSelecaoNota(item, isSelected),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox com lógica de confirmação para já programadas
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: isOrigem
                  ? Tooltip(
                      message: 'Nota que iniciou a programação (obrigatória nesta tarefa)',
                      child: Checkbox(
                        value: true,
                        onChanged: null,
                        activeColor: primaryColor,
                      ),
                    )
                  : Checkbox(
                      value: isSelected,
                      onChanged: (val) => _toggleSelecaoNota(item, isSelected),
                      activeColor: primaryColor,
                    ),
            ),
            const SizedBox(width: 8),

            // Informações da Nota
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Linha 1: Número, Tag de Origem e Tags de Situação
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '#$numeroNota',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? primaryColor : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isOrigem)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Nota principal',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      const Spacer(),
                      // Badge da Análise Técnica
                      _buildBadgeAnalise(analise),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Linha 2: Descrição da Nota
                  Text(
                    descricao,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Linha 3: Local/Equipamento, Status SAP
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (localOuEquip != '-')
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.precision_manufacturing_outlined,
                              size: 13,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              localOuEquip,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      if (statusSap.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tag,
                              size: 13,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              statusSap,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Linha 4: Situação da Programação (tasks_notas_sap)
                  _buildBadgeSituacaoProgramacao(context, item),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 5. BADGES DE SITUAÇÃO E ANÁLISE
  // ===========================================================================

  Widget _buildBadgeSituacaoProgramacao(
    BuildContext context,
    NotaSapGrupoItem item,
  ) {
    final theme = Theme.of(context);

    if (!item.isProgramada) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.radio_button_unchecked, size: 12, color: Colors.green),
            const SizedBox(width: 6),
            Text(
              'Ainda não programada',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.green.shade800,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    final tarefas = item.tarefasVinculadas;
    if (tarefas.length == 1) {
      final t = tarefas.first;
      final identificador = t.id.length > 8 ? t.id.substring(0, 8) : t.id;
      final label = t.tarefaNome != null && t.tarefaNome!.trim().isNotEmpty
          ? 'Já programada na Tarefa #$identificador (${t.tarefaNome})'
          : 'Já programada na Tarefa #$identificador';

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.amber.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_available, size: 12, color: Colors.amber),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.amber.shade900,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Múltiplas tarefas
    final tarefasIdsFormatados = tarefas
        .map((t) => '#${t.id.length > 8 ? t.id.substring(0, 8) : t.id}')
        .join(', ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.purple.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.copy_all, size: 12, color: Colors.purple),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Programada em múltiplas tarefas: $tarefasIdsFormatados',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.purple.shade900,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeAnalise(NotaSapAnalise? analise) {
    if (analise == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Sem análise',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    if (analise.statusAnalise == NotaAnaliseStatus.concluida) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.teal.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'Análise concluída',
          style: TextStyle(
            fontSize: 10,
            color: Colors.teal.shade800,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Em análise',
        style: TextStyle(
          fontSize: 10,
          color: Colors.orange.shade800,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ===========================================================================
  // 6. LÓGICA DE SELEÇÃO E CONFIRMAÇÃO
  // ===========================================================================

  Future<void> _toggleSelecaoNota(
    NotaSapGrupoItem item,
    bool isSelectedCurrently,
  ) async {
    final notaId = item.notaSapId;

    // Se está sendo desmarcada, desmarca diretamente
    if (isSelectedCurrently) {
      final novaSelecao = Set<String>.from(widget.selectedNotaIds)..remove(notaId);
      widget.onSelectionChanged(novaSelecao);
      return;
    }

    // Se está sendo marcada e já está programada em outra tarefa:
    // Mostrar diálogo de confirmação explícito (Requisitos 12 e 13)
    if (item.isProgramada) {
      final confirmou = await _mostrarConfirmacaoNotaProgramada(item);
      if (confirmou != true) {
        return;
      }
    }

    // Marcar nota
    final novaSelecao = Set<String>.from(widget.selectedNotaIds)..add(notaId);
    widget.onSelectionChanged(novaSelecao);
  }

  Future<bool?> _mostrarConfirmacaoNotaProgramada(NotaSapGrupoItem item) {
    final tarefas = item.tarefasVinculadas;
    final tarefasTexto = tarefas
        .map((t) => '#${t.id.length > 8 ? t.id.substring(0, 8) : t.id}')
        .join(', ');
    final numeroNota = item.nota?.nota ?? item.notaSapId;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Nota Já Programada'),
          ],
        ),
        content: Text(
          'A Nota SAP $numeroNota já está vinculada à(s) Tarefa(s) $tarefasTexto.\n\n'
          'Deseja também vinculá-la a esta nova tarefa?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Incluir mesmo assim'),
          ),
        ],
      ),
    );
  }

  void _selecionarTodasNaoProgramadas() {
    final novaSelecao = Set<String>.from(widget.selectedNotaIds);
    for (final item in widget.itens) {
      if (!item.isProgramada) {
        novaSelecao.add(item.notaSapId);
      }
    }
    widget.onSelectionChanged(novaSelecao);
  }

  void _limparSelecaoAdicional() {
    final novaSelecao = <String>{};
    if (widget.notaOrigem != null) {
      novaSelecao.add(widget.notaOrigem!.id);
    }
    widget.onSelectionChanged(novaSelecao);
  }
}
