import 'package:flutter/material.dart';
import '../../design_system/theme/taskflow_theme_extension.dart';
import '../../models/capacidade_operacional_models.dart';
import '../../models/backlog_macro_models.dart';
import '../../services/capacidade_service.dart';

/// Painel Gerencial de Balanceamento de Capacidade Operacional,
/// Indicadores de Confiabilidade, Memória de Cálculo, Priorização Explicável e Simulação.
class CapacidadeBalanceamentoPanel extends StatefulWidget {
  final BalanceamentoCapacidadeMes balanceamento;
  final List<CapacidadeExecutorMes> capacidadesExecutores;
  final List<BacklogNotaItem> notasDoMes;
  final List<BacklogGrupoItem> gruposDoMes;
  final ConfiguracaoCapacidade configuracao;
  final Function(ConfiguracaoCapacidade novaConfig)? onConfigChanged;
  final Function(String filtroTipo, {String? valor})? onDrillDown;

  const CapacidadeBalanceamentoPanel({
    super.key,
    required this.balanceamento,
    this.capacidadesExecutores = const [],
    this.notasDoMes = const [],
    this.gruposDoMes = const [],
    this.configuracao = const ConfiguracaoCapacidade(),
    this.onConfigChanged,
    this.onDrillDown,
  });

  @override
  State<CapacidadeBalanceamentoPanel> createState() => _CapacidadeBalanceamentoPanelState();
}

class _CapacidadeBalanceamentoPanelState extends State<CapacidadeBalanceamentoPanel> {
  final CapacidadeService _capacidadeService = CapacidadeService();

  // Modo de visualização: 'resumo', 'priorizacao', 'simulacao', 'executores'
  String _abaInterna = 'resumo';

  // Estado de simulação em memória
  bool _modoSimulacaoAtivo = false;
  int _deltaExecutores = 0;
  double _fatorEficienciaSimulado = 0.85;
  final Map<String, ({int ano, int mes})> _mudancasPrevisaoNotas = {};
  final Map<String, ({int ano, int mes})> _mudancasPrevisaoGrupos = {};
  BalanceamentoCapacidadeMes? _balanceamentoSimulado;
  ComparativoCenarioSimulacao? _comparativoSimulado;

  @override
  void initState() {
    super.initState();
    _fatorEficienciaSimulado = widget.configuracao.fatorEficiencia;
  }

  void _recalcularSimulacao() {
    final cenario = CenarioSimulacao(
      id: 'sim_local',
      nome: 'Simulação Rápida',
      criadoEm: DateTime.now(),
      ajusteExecutoresDisponiveis: _deltaExecutores,
      fatorEficienciaSimulado: _fatorEficienciaSimulado,
      mudancasPrevisaoNotas: Map.from(_mudancasPrevisaoNotas),
      mudancasPrevisaoGrupos: Map.from(_mudancasPrevisaoGrupos),
    );

    final sim = _capacidadeService.simularCenario(
      balancoBase: widget.balanceamento,
      cenario: cenario,
      capacidadesExecutoresOriginais: widget.capacidadesExecutores,
      todasNotasCarteira: widget.notasDoMes,
      config: widget.configuracao,
    );

    final comp = _capacidadeService.gerarComparativoSimulacao(
      balancoBase: widget.balanceamento,
      balancoSimulado: sim,
      cenario: cenario,
      notasAvaliadas: widget.notasDoMes,
    );

    setState(() {
      _balanceamentoSimulado = sim;
      _comparativoSimulado = comp;
    });
  }

  void _resetarSimulacao() {
    setState(() {
      _modoSimulacaoAtivo = false;
      _deltaExecutores = 0;
      _fatorEficienciaSimulado = widget.configuracao.fatorEficiencia;
      _mudancasPrevisaoNotas.clear();
      _mudancasPrevisaoGrupos.clear();
      _balanceamentoSimulado = null;
      _comparativoSimulado = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<TaskFlowThemeExtension>();
    final balancoAtivo = (_modoSimulacaoAtivo && _balanceamentoSimulado != null)
        ? _balanceamentoSimulado!
        : widget.balanceamento;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: ext?.colors.surface ?? theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ext?.colors.borderSubtle ?? Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Cabeçalho do Card com Status, Confiabilidade e Ações
          _buildCabecalho(context, ext, balancoAtivo),

          // 2. Alerta de Confiabilidade quando houver baixa cobertura
          if (!balancoAtivo.isSaldoConfiavel)
            _buildAvisoIncerteza(context, ext, balancoAtivo),

          const Divider(height: 1),

          // 3. Barra de Métricas Principais (Capacidade Bruta, Ajustada, Programada, Demanda e Saldo)
          _buildMetricasGrid(context, ext, balancoAtivo),

          // 4. Barra de Abas Internas (Resumo, Priorização Explicável, Simulação, Executores)
          _buildAbasInternas(context, ext),

          // 5. Conteúdo Dinâmico da Aba Selecionada
          _buildConteudoAba(context, ext, balancoAtivo),
        ],
      ),
    );
  }

  // ===========================================================================
  // 1. CABEÇALHO DO CARD
  // ===========================================================================
  Widget _buildCabecalho(BuildContext context, TaskFlowThemeExtension? ext, BalanceamentoCapacidadeMes bal) {
    final isNaoConfiavel = !bal.isSaldoConfiavel || bal.nivelConfiabilidade == NivelConfiabilidadeCapacidade.baixa;

    final statusColor = switch (bal.status) {
      StatusBalanceamentoMensal.sobrecarga => Colors.red.shade700,
      StatusBalanceamentoMensal.cargaElevada => Colors.orange.shade700,
      StatusBalanceamentoMensal.equilibrado => isNaoConfiavel ? Colors.amber.shade800 : Colors.green.shade700,
      StatusBalanceamentoMensal.ocioso => isNaoConfiavel ? Colors.blueGrey.shade600 : Colors.blue.shade700,
    };

    final statusLabel = switch (bal.status) {
      StatusBalanceamentoMensal.sobrecarga => 'Sobrecarga de Capacidade',
      StatusBalanceamentoMensal.cargaElevada => 'Carga Operacional Elevada',
      StatusBalanceamentoMensal.equilibrado => isNaoConfiavel ? 'Capacidade aparentemente equilibrada' : 'Capacidade Equilibrada',
      StatusBalanceamentoMensal.ocioso => isNaoConfiavel ? 'Capacidade aparentemente disponível' : 'Capacidade Disponível com Folga',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.speed, size: 16, color: statusColor),
                const SizedBox(width: 6),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _buildChipConfiabilidade(bal),
          const Spacer(),
          if (_modoSimulacaoAtivo)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.purple.shade300),
              ),
              child: Text(
                'MODO SIMULAÇÃO ATIVO',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple.shade800),
              ),
            ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.calculate_outlined, size: 16),
            label: const Text('Memória de Cálculo', style: TextStyle(fontSize: 12)),
            onPressed: () => _exibirMemoriaCalculo(context, bal),
          ),
        ],
      ),
    );
  }

  Widget _buildChipConfiabilidade(BalanceamentoCapacidadeMes bal) {
    final (cor, label, icone) = switch (bal.nivelConfiabilidade) {
      NivelConfiabilidadeCapacidade.alta => (
          Colors.green.shade700,
          'Confiabilidade Alta',
          Icons.verified_outlined,
        ),
      NivelConfiabilidadeCapacidade.media => (
          Colors.orange.shade700,
          'Confiabilidade Média',
          Icons.warning_amber_rounded,
        ),
      NivelConfiabilidadeCapacidade.baixa => (
          Colors.red.shade700,
          'Baixa Confiabilidade',
          Icons.gpp_bad_outlined,
        ),
    };

    return Tooltip(
      message: bal.motivoConfiabilidade,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cor.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 14, color: cor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cor),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 2. AVISO DE INCERTEZA / FALSA OCIOSIDADE
  // ===========================================================================
  Widget _buildAvisoIncerteza(BuildContext context, TaskFlowThemeExtension? ext, BalanceamentoCapacidadeMes bal) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.amber.shade900),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Atenção Gerencial: ${bal.demanda.notasSemEstimativa} das ${bal.demanda.totalNotasPrevistas} notas previstas não possuem estimativa técnica informada. O saldo aparente não representa folga comprovada.',
              style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. GRID DE MÉTRICAS PRINCIPAIS
  // ===========================================================================
  Widget _buildMetricasGrid(BuildContext context, TaskFlowThemeExtension? ext, BalanceamentoCapacidadeMes bal) {
    final saldoPositivo = bal.saldoHorasCalculado >= 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 700;

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildKpiCard(
                titulo: 'Capacidade Ajustada',
                valor: '${bal.horasAjustadas.toStringAsFixed(0)}h',
                detalhe: '${bal.totalExecutores} executores (${bal.calendario.diasUteis}d úteis)',
                icone: Icons.engineering_outlined,
                cor: Colors.blue.shade700,
                largura: isCompact ? constraints.maxWidth / 2 - 10 : 180,
              ),
              _buildKpiCard(
                titulo: 'Horas Programadas',
                valor: '${bal.horasComprometidasProgramadas.toStringAsFixed(0)}h',
                detalhe: 'Esforço em tarefas ativas',
                icone: Icons.assignment_turned_in_outlined,
                cor: Colors.indigo.shade700,
                largura: isCompact ? constraints.maxWidth / 2 - 10 : 180,
              ),
              _buildKpiCard(
                titulo: 'Demanda Estimada',
                valor: '${bal.demanda.horasEstimadasNaoProgramadas.toStringAsFixed(0)}h',
                detalhe: '${bal.demanda.notasComEstimativa} notas dimensionadas',
                icone: Icons.list_alt_outlined,
                cor: Colors.orange.shade800,
                largura: isCompact ? constraints.maxWidth / 2 - 10 : 180,
              ),
              _buildKpiCard(
                titulo: 'Saldo de Capacidade',
                valor: '${saldoPositivo ? "+" : ""}${bal.saldoHorasCalculado.toStringAsFixed(0)}h',
                detalhe: bal.isSaldoConfiavel ? 'Saldo Confirmado' : 'Saldo Não Conclusivo',
                icone: saldoPositivo ? Icons.check_circle_outline : Icons.error_outline,
                cor: saldoPositivo
                    ? (bal.isSaldoConfiavel ? Colors.green.shade700 : Colors.grey.shade600)
                    : Colors.red.shade700,
                largura: isCompact ? constraints.maxWidth / 2 - 10 : 180,
              ),
              _buildKpiCard(
                titulo: 'Não Dimensionadas',
                valor: '${bal.demanda.notasSemEstimativa} notas',
                detalhe: '${bal.demanda.percentualCoberturaEstimativa.toStringAsFixed(0)}% cobertura técnica',
                icone: Icons.help_outline,
                cor: bal.demanda.notasSemEstimativa > 0 ? Colors.amber.shade900 : Colors.green.shade700,
                largura: isCompact ? constraints.maxWidth / 2 - 10 : 180,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKpiCard({
    required String titulo,
    required String valor,
    required String detalhe,
    required IconData icone,
    required Color cor,
    required double largura,
  }) {
    return Container(
      width: largura,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 16, color: cor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            valor,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cor),
          ),
          const SizedBox(height: 2),
          Text(
            detalhe,
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. ABAS INTERNAS
  // ===========================================================================
  Widget _buildAbasInternas(BuildContext context, TaskFlowThemeExtension? ext) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: ext?.colors.borderSubtle ?? Colors.grey.shade200),
          bottom: BorderSide(color: ext?.colors.borderSubtle ?? Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          _buildAbaItem('resumo', 'Demandas do Mês (${widget.notasDoMes.length})', Icons.summarize_outlined),
          _buildAbaItem('priorizacao', 'Priorização Explicável', Icons.low_priority_outlined),
          _buildAbaItem('simulacao', 'Simulação (What-If)', Icons.tune_outlined),
          _buildAbaItem('executores', 'Equipe & Horas (${widget.capacidadesExecutores.length})', Icons.groups_outlined),
        ],
      ),
    );
  }

  Widget _buildAbaItem(String id, String label, IconData icone) {
    final ativo = _abaInterna == id;
    final cor = ativo ? Theme.of(context).primaryColor : Colors.grey.shade600;

    return InkWell(
      onTap: () => setState(() => _abaInterna = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: ativo ? cor : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 16, color: cor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: ativo ? FontWeight.bold : FontWeight.w500,
                color: cor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 5. CONTEÚDO DINÂMICO
  // ===========================================================================
  Widget _buildConteudoAba(BuildContext context, TaskFlowThemeExtension? ext, BalanceamentoCapacidadeMes bal) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: switch (_abaInterna) {
        'priorizacao' => _buildAbaPriorizacao(context, ext),
        'simulacao' => _buildAbaSimulacao(context, ext, bal),
        'executores' => _buildAbaExecutores(context, ext, bal),
        _ => _buildAbaResumoDemandas(context, ext, bal),
      },
    );
  }

  Widget _buildAbaResumoDemandas(BuildContext context, TaskFlowThemeExtension? ext, BalanceamentoCapacidadeMes bal) {
    if (bal.demanda.itens.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Nenhuma nota prevista para este mês.', style: TextStyle(fontSize: 13, color: Colors.grey)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Detalhamento de Estimativas da Carteira',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              '${bal.demanda.notasComEstimativa} com estimativa | ${bal.demanda.notasSemEstimativa} sem estimativa',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: bal.demanda.itens.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, idx) {
            final it = bal.demanda.itens[idx];
            final (origemCor, origemLabel) = switch (it.origem) {
              OrigemEstimativaNota.confirmadaMaiorZero => (Colors.green.shade700, '${it.horasEstimadas}h confirmadas'),
              OrigemEstimativaNota.zeroConfirmado => (Colors.blue.shade700, '0h confirmadas (sem campo)'),
              OrigemEstimativaNota.zeroPadrao => (Colors.amber.shade800, '0h padrão (não dimensionada)'),
              OrigemEstimativaNota.ausente => (Colors.red.shade700, 'Sem análise técnica'),
            };

            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                it.jaPossuiTarefaProgramada ? Icons.check_box_outlined : Icons.pending_actions_outlined,
                color: it.jaPossuiTarefaProgramada ? Colors.indigo : Colors.grey,
                size: 20,
              ),
              title: Row(
                children: [
                  Text(
                    'Nota ${it.numeroNota}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  if (it.jaPossuiTarefaProgramada)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.indigo.shade200),
                      ),
                      child: const Text('Já em Tarefa', style: TextStyle(fontSize: 10, color: Colors.indigo)),
                    ),
                ],
              ),
              subtitle: it.descricao != null
                  ? Text(it.descricao!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5))
                  : null,
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: origemCor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  origemLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: origemCor),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAbaPriorizacao(BuildContext context, TaskFlowThemeExtension? ext) {
    final priorizacoes = _capacidadeService.calcularPriorizacaoNotas(
      notas: widget.notasDoMes,
    );

    if (priorizacoes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Nenhuma demanda para priorizar neste mês.', style: TextStyle(fontSize: 13, color: Colors.grey)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Classificação Consultiva de Prioridade (Score Explicável 0-100)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              'Recurso consultivo • Não altera dados no banco',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: priorizacoes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, idx) {
            final p = priorizacoes[idx];
            final catCor = switch (p.categoria) {
              CategoriaPrioridadeNota.critica => Colors.red.shade700,
              CategoriaPrioridadeNota.alta => Colors.orange.shade800,
              CategoriaPrioridadeNota.media => Colors.blue.shade700,
              CategoriaPrioridadeNota.baixa => Colors.grey.shade600,
            };

            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: catCor.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: catCor.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: catCor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${p.scoreTotal.toStringAsFixed(0)} pts • ${p.categoria.label}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Nota ${p.numeroNota}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (p.descricao != null)
                        Expanded(
                          child: Text(
                            p.descricao!,
                            textAlign: TextAlign.end,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ),
                    ],
                  ),
                  if (p.motivosTexto.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: p.motivosTexto.map((m) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(m, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade800)),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAbaSimulacao(BuildContext context, TaskFlowThemeExtension? ext, BalanceamentoCapacidadeMes bal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Simulador What-If Não-Destrutivo (Em Memória)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            if (_modoSimulacaoAtivo)
              TextButton(
                onPressed: _resetarSimulacao,
                child: const Text('Resetar Cenário', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Controle 1: Ajuste de Executores (+/-)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Variação de Executores: ${_deltaExecutores > 0 ? "+$_deltaExecutores" : _deltaExecutores}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                          onPressed: () {
                            setState(() {
                              _modoSimulacaoAtivo = true;
                              _deltaExecutores--;
                              _recalcularSimulacao();
                            });
                          },
                        ),
                        Text('${widget.capacidadesExecutores.length + _deltaExecutores} técnicos',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          onPressed: () {
                            setState(() {
                              _modoSimulacaoAtivo = true;
                              _deltaExecutores++;
                              _recalcularSimulacao();
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Controle 2: Fator de Eficiência
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fator de Eficiência: ${(_fatorEficienciaSimulado * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Slider(
                      value: _fatorEficienciaSimulado,
                      min: 0.60,
                      max: 1.00,
                      divisions: 8,
                      label: '${(_fatorEficienciaSimulado * 100).toStringAsFixed(0)}%',
                      onChanged: (val) {
                        setState(() {
                          _modoSimulacaoAtivo = true;
                          _fatorEficienciaSimulado = val;
                          _recalcularSimulacao();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_modoSimulacaoAtivo && _balanceamentoSimulado != null) ...[
          const SizedBox(height: 16),
          // Painel de Deltas Comparativos
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.purple.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.compare_arrows, size: 16, color: Colors.purple),
                    const SizedBox(width: 6),
                    Text(
                      'Comparativo de Impacto (Original vs. Simulado)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple.shade900),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildDeltaItem('Capacidade', widget.balanceamento.horasAjustadas, _balanceamentoSimulado!.horasAjustadas, 'h'),
                    _buildDeltaItem('Demanda Líquida', widget.balanceamento.demanda.horasEstimadasNaoProgramadas, _balanceamentoSimulado!.demanda.horasEstimadasNaoProgramadas, 'h'),
                    _buildDeltaItem('Saldo Projetado', widget.balanceamento.saldoHorasCalculado, _balanceamentoSimulado!.saldoHorasCalculado, 'h'),
                  ],
                ),
                if (_comparativoSimulado != null && _comparativoSimulado!.impactosPrazos.isNotEmpty) ...[
                  const Divider(height: 18),
                  Row(
                    children: [
                      Icon(
                        _comparativoSimulado!.totalNovosAtrasos > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                        size: 16,
                        color: _comparativoSimulado!.totalNovosAtrasos > 0 ? Colors.red.shade700 : Colors.green.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _comparativoSimulado!.totalNovosAtrasos > 0
                            ? 'ALERTA: ${_comparativoSimulado!.totalNovosAtrasos} nota(s) ultrapassarão a meta SAP neste cenário!'
                            : 'Prazos SAP preservados: nenhum novo atraso regulatório provocado.',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _comparativoSimulado!.totalNovosAtrasos > 0 ? Colors.red.shade800 : Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        // Reprogramação Simulada de Grupos (Antecipar / Postergar Grupo)
        if (widget.gruposDoMes.where((g) => !g.id.startsWith('virtual_')).isNotEmpty) ...[
          const Text(
            'Reprogramação Simulada de Grupos (Em Memória):',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 140),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.gruposDoMes.where((g) => !g.id.startsWith('virtual_')).take(5).length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final gruposReais = widget.gruposDoMes.where((g) => !g.id.startsWith('virtual_')).toList();
                final grupo = gruposReais[idx];
                final mudanca = _mudancasPrevisaoGrupos[grupo.id];
                final mesAlvo = mudanca?.mes ?? widget.balanceamento.mes;
                final anoAlvo = mudanca?.ano ?? widget.balanceamento.ano;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_special_outlined, size: 16, color: Colors.blueGrey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Grupo: ${grupo.nome}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            Text('${grupo.totalNotas} nota(s) • ${grupo.somaEstimativaTotal.toStringAsFixed(1)}h estimadas',
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Antecipar Grupo 1 mês',
                        icon: const Icon(Icons.fast_rewind, size: 16),
                        onPressed: () {
                          setState(() {
                            _modoSimulacaoAtivo = true;
                            final nMes = mesAlvo == 1 ? 12 : mesAlvo - 1;
                            final nAno = mesAlvo == 1 ? anoAlvo - 1 : anoAlvo;
                            _mudancasPrevisaoGrupos[grupo.id] = (ano: nAno, mes: nMes);
                            _recalcularSimulacao();
                          });
                        },
                      ),
                      Text('$mesAlvo/$anoAlvo', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      IconButton(
                        tooltip: 'Postergar Grupo 1 mês',
                        icon: const Icon(Icons.fast_forward, size: 16),
                        onPressed: () {
                          setState(() {
                            _modoSimulacaoAtivo = true;
                            final nMes = mesAlvo == 12 ? 1 : mesAlvo + 1;
                            final nAno = mesAlvo == 12 ? anoAlvo + 1 : anoAlvo;
                            _mudancasPrevisaoGrupos[grupo.id] = (ano: nAno, mes: nMes);
                            _recalcularSimulacao();
                          });
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Reprogramação Simulada de Demandas (Antecipar / Postergar)
        if (widget.notasDoMes.isNotEmpty) ...[
          const Text(
            'Reprogramação Rápida da Carteira em Memória:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.notasDoMes.take(5).length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final nota = widget.notasDoMes[idx];
                final mudanca = _mudancasPrevisaoNotas[nota.notaSapId];
                final mesAlvo = mudanca?.mes ?? widget.balanceamento.mes;
                final anoAlvo = mudanca?.ano ?? widget.balanceamento.ano;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nota ${nota.numeroNota}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            Text(nota.descricao, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Antecipar 1 mês',
                        icon: const Icon(Icons.fast_rewind, size: 16),
                        onPressed: () {
                          setState(() {
                            _modoSimulacaoAtivo = true;
                            final nMes = mesAlvo == 1 ? 12 : mesAlvo - 1;
                            final nAno = mesAlvo == 1 ? anoAlvo - 1 : anoAlvo;
                            _mudancasPrevisaoNotas[nota.notaSapId] = (ano: nAno, mes: nMes);
                            _recalcularSimulacao();
                          });
                        },
                      ),
                      Text('$mesAlvo/$anoAlvo', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      IconButton(
                        tooltip: 'Postergar 1 mês',
                        icon: const Icon(Icons.fast_forward, size: 16),
                        onPressed: () {
                          setState(() {
                            _modoSimulacaoAtivo = true;
                            final nMes = mesAlvo == 12 ? 1 : mesAlvo + 1;
                            final nAno = mesAlvo == 12 ? anoAlvo + 1 : anoAlvo;
                            _mudancasPrevisaoNotas[nota.notaSapId] = (ano: nAno, mes: nMes);
                            _recalcularSimulacao();
                          });
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDeltaItem(String titulo, double base, double simulado, String unidade) {
    final delta = simulado - base;
    final isPositivo = delta > 0;
    final corDelta = isPositivo ? Colors.green.shade700 : (delta < 0 ? Colors.red.shade700 : Colors.grey);

    return Column(
      children: [
        Text(titulo, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${base.toStringAsFixed(0)}$unidade',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.arrow_forward, size: 13, color: Colors.black87),
            ),
            Text('${simulado.toStringAsFixed(0)}$unidade',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
          ],
        ),
        Text(
          '${delta >= 0 ? "+" : ""}${delta.toStringAsFixed(0)} $unidade',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: corDelta),
        ),
      ],
    );
  }

  Widget _buildAbaExecutores(BuildContext context, TaskFlowThemeExtension? ext, BalanceamentoCapacidadeMes bal) {
    if (widget.capacidadesExecutores.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Nenhum executor vinculado no período.', style: TextStyle(fontSize: 13, color: Colors.grey)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Alocação Individual de Horas (${widget.capacidadesExecutores.length} executores)',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              '${bal.totalExecutoresEmEquipes} em equipes | ${bal.totalExecutoresSemEquipe} avulsos',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.capacidadesExecutores.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, idx) {
            final c = widget.capacidadesExecutores[idx];
            final sobrecarregado = c.saldoHoras < 0;

            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: c.temEquipeVinculada ? Colors.blue.shade100 : Colors.grey.shade200,
                child: Text(
                  c.executorNome.isNotEmpty ? c.executorNome[0] : '?',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                ),
              ),
              title: Text(c.executorNome, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              subtitle: Text(
                '${c.equipeNome ?? "Sem equipe"} • ${c.funcao ?? "Executor"} • Indisp: ${c.horasIndisponiveis.toStringAsFixed(0)}h',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Prog: ${c.horasComprometidas.toStringAsFixed(0)}h / Ajust: ${c.horasAjustadas.toStringAsFixed(0)}h',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Saldo: ${c.saldoHoras.toStringAsFixed(0)}h (${c.taxaComprometimento.toStringAsFixed(0)}%)',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: sobrecarregado ? Colors.red.shade700 : Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ===========================================================================
  // MEMÓRIA DE CÁLCULO MODAL
  // ===========================================================================
  void _exibirMemoriaCalculo(BuildContext context, BalanceamentoCapacidadeMes bal) {
    final mem = bal.memoriaCalculo;
    if (mem == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.calculate_outlined, color: Colors.blue),
            const SizedBox(width: 8),
            Text('Memória de Cálculo — ${bal.labelMesAno}'),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPassoMemoria('1. Calendário e Dias Úteis', mem.passo1Calendario),
                _buildPassoMemoria('2. Capacidade Bruta', mem.passo2CapacidadeBruta),
                _buildPassoMemoria('3. Indisponibilidades', mem.passo3Indisponibilidades),
                _buildPassoMemoria('4. Capacidade Ajustada (com Eficiência)', mem.passo4CapacidadeAjustada),
                _buildPassoMemoria('5. Horas Comprometidas na Programação', mem.passo5HorasComprometidas),
                _buildPassoMemoria('6. Demanda Estimada da Carteira', mem.passo6DemandaEstimada),
                _buildPassoMemoria('7. Saldo Final e Grau de Confiabilidade', mem.passo7SaldoEConfiabilidade),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Widget _buildPassoMemoria(String titulo, String detalhe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
          const SizedBox(height: 2),
          Text(detalhe, style: const TextStyle(fontSize: 12, color: Colors.black87)),
        ],
      ),
    );
  }
}
