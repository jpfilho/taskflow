import 'package:flutter/material.dart';
import '../../models/nota_sap.dart';
import '../../models/nota_sap_similaridade.dart';
import '../../models/nota_sap_grupo.dart';
import '../../services/nota_sap_similaridade_service.dart';
import '../../services/nota_sap_grupo_service.dart';
import '../../services/auth_service_simples.dart';
import '../nota_analise_workspace.dart';
import 'nota_workspace_historico_tecnico_section.dart';

/// Painel da Aba "Similaridade & Histórico" do Workspace Visual da Nota SAP.
///
/// Apresenta de forma integrada:
/// 1. Histórico Técnico do Ativo (Notas Anteriores por Equipamento, Estrutura e Local com Anexos e Tasks)
/// 2. Motor Determinístico de Similaridade (Ocorrências Semelhantes, Mediana de Horas e Demandas Abertas)
class NotaSapSimilaridadePanel extends StatefulWidget {
  final NotaSAP nota;
  final NotaSapSimilaridadeService? service;
  final NotaSapGrupoService? grupoService;
  final VoidCallback? onAtualizacao;
  final ResultadoSimilaridadeNotaSap? dadosIniciais;
  final void Function(NotaSAP notaHistorica)? onAbrirNotaHistorica;

  const NotaSapSimilaridadePanel({
    super.key,
    required this.nota,
    this.service,
    this.grupoService,
    this.onAtualizacao,
    this.dadosIniciais,
    this.onAbrirNotaHistorica,
  });

  @override
  State<NotaSapSimilaridadePanel> createState() =>
      _NotaSapSimilaridadePanelState();
}

/// Modos de visão no topo da aba: Histórico do Ativo vs Similaridade & Demandas
enum ModoVisaoPainelPrincipal {
  historicoTecnico,
  similaridadeDemandas,
}

/// Modos de visualização para evitar mistura entre notas abertas e histórico concluído.
enum FiltroVisaoSimilaridade {
  abertas,
  concluidas,
  todas,
}

class _NotaSapSimilaridadePanelState extends State<NotaSapSimilaridadePanel> {
  late final NotaSapSimilaridadeService _service;
  late final NotaSapGrupoService _grupoService;
  ResultadoSimilaridadeNotaSap? _resultado;
  bool _isLoading = true;
  String? _erro;
  bool _mostrarTodasOcorrencias = false;
  FiltroVisaoSimilaridade _filtroVisao = FiltroVisaoSimilaridade.todas;

  NotaSapGrupo? _grupoNotaAtual;
  final Map<String, NotaSapGrupo?> _gruposPorNotaId = {};
  bool _carregandoGrupos = false;

  static const Color _primaryColor = Color(0xFF0F766E);
  static const Color _surfaceBg = Color(0xFFF8FAFC);
  static const Color _cardBorder = Color(0xFFE2E8F0);
  static const Color _textMain = Color(0xFF1E293B);
  static const Color _textMuted = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? NotaSapSimilaridadeService();
    _grupoService = widget.grupoService ?? NotaSapGrupoService();
    if (widget.dadosIniciais != null) {
      _resultado = widget.dadosIniciais;
      _isLoading = false;
      _carregarGruposVinculados();
    } else {
      _carregarSimilaridades();
    }
  }

  @override
  void didUpdateWidget(covariant NotaSapSimilaridadePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nota.id != widget.nota.id) {
      _carregarSimilaridades();
    }
  }

  Future<void> _carregarSimilaridades({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _erro = null;
    });

    try {
      final res = await _service.buscarSimilaridades(
        notaReferencia: widget.nota,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _resultado = res;
          _isLoading = false;
        });
        _carregarGruposVinculados();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = 'Não foi possível carregar as ocorrências semelhantes: $e';
          _isLoading = false;
        });
      }
    }
  }

  ModoVisaoPainelPrincipal _modoPrincipal =
      ModoVisaoPainelPrincipal.historicoTecnico;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Seletor Superior: Histórico do Ativo (Notas Anteriores) vs Similaridade & Demandas
        _buildSeletorPrincipal(),

        // Conteúdo da Visão Selecionada
        Expanded(
          child: _modoPrincipal == ModoVisaoPainelPrincipal.historicoTecnico
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: NotaWorkspaceHistoricoTecnicoSection(
                    nota: widget.nota,
                    onAbrirNotaHistorica: widget.onAbrirNotaHistorica,
                  ),
                )
              : _buildConteudoSimilaridadeEDemandas(),
        ),
      ],
    );
  }

  Widget _buildSeletorPrincipal() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _cardBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildBotaoModoPrincipal(
                modo: ModoVisaoPainelPrincipal.historicoTecnico,
                icone: Icons.history_edu_rounded,
                titulo: 'Histórico do Ativo (Notas Anteriores)',
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildBotaoModoPrincipal(
                modo: ModoVisaoPainelPrincipal.similaridadeDemandas,
                icone: Icons.auto_awesome_outlined,
                titulo: 'Similaridade & Demandas Abertas',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotaoModoPrincipal({
    required ModoVisaoPainelPrincipal modo,
    required IconData icone,
    required String titulo,
  }) {
    final isSelected = _modoPrincipal == modo;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _modoPrincipal = modo;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icone,
                size: 16,
                color: isSelected ? _primaryColor : _textMuted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? _textMain : _textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConteudoSimilaridadeEDemandas() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2.5, color: _primaryColor),
            SizedBox(height: 16),
            Text(
              'Buscando ocorrências históricas e demandas relacionadas...',
              style: TextStyle(fontSize: 13, color: _textMuted),
            ),
          ],
        ),
      );
    }

    if (_erro != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _cardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.orange, size: 40),
              const SizedBox(height: 12),
              Text(
                _erro!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: _textMain),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _carregarSimilaridades(forceRefresh: true),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Tentar Novamente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final res = _resultado;
    if (res == null || !res.temDados) {
      return _buildEstadoVazio();
    }

    final ocorrenciasAbertasExibir = _mostrarTodasOcorrencias
        ? res.todasOcorrenciasAbertas
        : res.ocorrenciasAbertas;

    final ocorrenciasConcluidasExibir = _mostrarTodasOcorrencias
        ? res.todasOcorrenciasConcluidas
        : res.ocorrenciasConcluidas;

    final listaOcorrencias = _mostrarTodasOcorrencias
        ? res.todasOcorrencias
        : res.ocorrenciasSemelhantes;

    final ocorrenciasConcluidas = _filtroVisao == FiltroVisaoSimilaridade.todas
        ? listaOcorrencias.where((o) => o.estaConcluida || !o.estaAberta).toList()
        : ocorrenciasConcluidasExibir;

    return RefreshIndicator(
      onRefresh: () => _carregarSimilaridades(forceRefresh: true),
      color: _primaryColor,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Banner informativo com tooltip auditável
          _buildCabecalhoExplicativo(),

          const SizedBox(height: 16),

          // Seletor de Visão (Notas Abertas x Concluídas/Histórico x Todas)
          _buildSeletorFiltroVisao(res),

          const SizedBox(height: 20),

          // ===================================================================
          // 1. PRIORIDADE OPERACIONAL: NOTAS ABERTAS (Modo Todas ou Abertas)
          // ===================================================================
          if (_filtroVisao == FiltroVisaoSimilaridade.abertas ||
              _filtroVisao == FiltroVisaoSimilaridade.todas) ...[
            // 1.1 Ocorrências Semelhantes Abertas (com score determinístico e card de similaridade)
            if (ocorrenciasAbertasExibir.isNotEmpty) ...[
              _buildSecaoTitulo(
                titulo: 'Ocorrências Semelhantes Abertas',
                subtitulo:
                    'Notas SAP abertas com correspondência técnica de vão, equipamento ou avaria.',
                icone: Icons.verified_outlined,
                contador: res.todasOcorrenciasAbertas.length,
              ),
              const SizedBox(height: 12),
              ...ocorrenciasAbertasExibir.map((oc) => _buildCardOcorrencia(oc)),
              const SizedBox(height: 20),
            ],

            // 1.2 Outras Demandas Abertas no Mesmo Vão / Ativo
            if (res.outrasDemandasAbertas.isNotEmpty) ...[
              _buildSecaoTitulo(
                titulo: 'Possíveis Demandas Relacionadas (Notas Abertas)',
                subtitulo:
                    'Notas SAP abertas no mesmo vão operativo ou equipamento. Prioridade para agrupamento operacional e programação de desligamento.',
                icone: Icons.pending_actions_rounded,
                contador: res.outrasDemandasAbertas.length,
              ),
              const SizedBox(height: 12),
              ...res.outrasDemandasAbertas
                  .map((d) => _buildCardDemandaAberta(d)),
              const SizedBox(height: 24),
            ] else if (ocorrenciasAbertasExibir.isEmpty &&
                _filtroVisao == FiltroVisaoSimilaridade.abertas) ...[
              _buildSecaoTitulo(
                titulo: 'Possíveis Demandas Relacionadas (Notas Abertas)',
                subtitulo:
                    'Busca de outras pendências abertas no mesmo vão ou equipamento',
                icone: Icons.pending_actions_rounded,
                contador: 0,
              ),
              const SizedBox(height: 12),
              _buildAvisoVazio(
                'Nenhuma outra nota SAP aberta encontrada no mesmo vão, equipamento ou subestação no momento.\nSelecione "Concluídas / Histórico" para consultar os serviços anteriores semelhantes.',
              ),
              const SizedBox(height: 24),
            ],
          ],

          // ===================================================================
          // 2. CONCLUÍDAS / HISTÓRICO (Modo Todas ou Concluídas)
          // ===================================================================
          if (_filtroVisao == FiltroVisaoSimilaridade.concluidas ||
              _filtroVisao == FiltroVisaoSimilaridade.todas) ...[
            // Métricas de Tempo e Equipe
            if (res.estatisticas.temDadosHoras || res.estatisticas.temDadosEquipe) ...[
              _buildCardEstatisticas(res.estatisticas),
              const SizedBox(height: 24),
            ],

            // Ocorrências Semelhantes (Concluídas / Histórico)
            _buildSecaoTitulo(
              titulo: 'Ocorrências Históricas Semelhantes',
              subtitulo:
                  'Falha ou serviço análogo registrado anteriormente no ativo ou local',
              icone: Icons.history_edu_rounded,
              contador: _filtroVisao == FiltroVisaoSimilaridade.todas
                  ? res.todasOcorrencias.where((o) => o.estaConcluida || !o.estaAberta).length
                  : res.todasOcorrenciasConcluidas.length,
            ),
            const SizedBox(height: 12),

            if (ocorrenciasConcluidas.isEmpty)
              _buildAvisoVazio(
                'Nenhuma ocorrência anterior com a mesma natureza de defeito encontrada.',
              )
            else ...[
              ...ocorrenciasConcluidas.map((oc) => _buildCardOcorrencia(oc)),
              if (res.todasOcorrencias.length > 5 && !_mostrarTodasOcorrencias)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          setState(() => _mostrarTodasOcorrencias = true),
                      icon: const Icon(Icons.expand_more, size: 18),
                      label: Text(
                        'Ver todas as ${res.todasOcorrencias.length} ocorrências semelhantes',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primaryColor,
                        side: const BorderSide(color: _primaryColor),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                    ),
                  ),
                ),
              if (_mostrarTodasOcorrencias && res.todasOcorrencias.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => _mostrarTodasOcorrencias = false),
                      icon: const Icon(Icons.expand_less, size: 18),
                      label: const Text('Mostrar apenas as 5 mais semelhantes'),
                    ),
                  ),
                ),
            ],

            const SizedBox(height: 24),

            // Histórico do Mesmo Ativo (intervenção tecnicamente distinta)
            if (res.historicoMesmoAtivo.isNotEmpty) ...[
              _buildSecaoTitulo(
                titulo: 'Histórico do Mesmo Ativo (Outras Intervenções)',
                subtitulo:
                    'Serviços anteriores no mesmo equipamento com natureza de falha diferente',
                icone: Icons.precision_manufacturing_outlined,
                contador: res.historicoMesmoAtivo.length,
              ),
              const SizedBox(height: 12),
              ...res.historicoMesmoAtivo.map((oc) => _buildCardOcorrencia(oc)),
              const SizedBox(height: 24),
            ],

            // Materiais Levantados em Análises Semelhantes
            if (res.materiaisFrequentes.isNotEmpty) ...[
              _buildSecaoTitulo(
                titulo: 'Materiais Levantados em Ocorrências Semelhantes',
                subtitulo:
                    'Peças e insumos planejados em análises técnicas prévias correspondentes',
                icone: Icons.inventory_2_outlined,
                contador: res.materiaisFrequentes.length,
              ),
              const SizedBox(height: 12),
              _buildTabelaMateriais(res.materiaisFrequentes),
              const SizedBox(height: 24),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSeletorFiltroVisao(ResultadoSimilaridadeNotaSap res) {
    final int qtdAbertas =
        res.todasOcorrenciasAbertas.length + res.outrasDemandasAbertas.length;
    final int qtdConcluidas =
        res.todasOcorrenciasConcluidas.length + res.historicoMesmoAtivo.length;
    final int qtdTotal = qtdAbertas + qtdConcluidas;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildItemAbaFiltro(
              filtro: FiltroVisaoSimilaridade.abertas,
              icone: Icons.pending_actions_rounded,
              titulo: 'Notas Abertas',
              contador: qtdAbertas,
              corAtiva: const Color(0xFFC2410C),
              corBadge: const Color(0xFFFFF7ED),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildItemAbaFiltro(
              filtro: FiltroVisaoSimilaridade.concluidas,
              icone: Icons.task_alt_rounded,
              titulo: 'Concluídas / Histórico',
              contador: qtdConcluidas,
              corAtiva: const Color(0xFF15803D),
              corBadge: const Color(0xFFF0FDF4),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildItemAbaFiltro(
              filtro: FiltroVisaoSimilaridade.todas,
              icone: Icons.list_alt_rounded,
              titulo: 'Todas',
              contador: qtdTotal,
              corAtiva: _primaryColor,
              corBadge: const Color(0xFFF0FDFA),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemAbaFiltro({
    required FiltroVisaoSimilaridade filtro,
    required IconData icone,
    required String titulo,
    required int contador,
    required Color corAtiva,
    required Color corBadge,
  }) {
    final isSelected = _filtroVisao == filtro;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _filtroVisao = filtro;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x0F000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icone,
                size: 16,
                color: isSelected ? corAtiva : _textMuted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? corAtiva : _textMain,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? corBadge : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$contador',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? corAtiva : _textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // WIDGETS AUXILIARES E COMPONENTES VISUAIS
  // ===========================================================================

  Widget _buildCabecalhoExplicativo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCCFBF1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: _primaryColor, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'O motor determinístico localiza serviços anteriores similares no mesmo ativo ou instalação para apoiar seu diagnóstico e dimensionamento.',
              style: TextStyle(fontSize: 13, color: Color(0xFF134E4A)),
            ),
          ),
          Tooltip(
            message:
                'Índice determinístico baseado em regras técnicas do TaskFlow.\nNão representa probabilidade estatística.',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF99F6E4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.help_outline, size: 14, color: _primaryColor),
                  SizedBox(width: 4),
                  Text(
                    'Score Auditável',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _primaryColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecaoTitulo({
    required String titulo,
    required String subtitulo,
    required IconData icone,
    required int contador,
  }) {
    return Row(
      children: [
        Icon(icone, color: _primaryColor, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _textMain,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$contador',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _textMain,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                subtitulo,
                style: const TextStyle(fontSize: 12, color: _textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardEstatisticas(EstatisticasTempoEquipe est) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics_outlined, color: _primaryColor, size: 18),
              SizedBox(width: 8),
              Text(
                'Métricas Históricas Consolidadas (Base: Ocorrências Semelhantes)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _textMain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              if (est.temDadosHoras)
                _buildMetricaItem(
                  titulo: 'Duração Mediana',
                  valor: '${est.duracaoMedianaHoras!.toStringAsFixed(1)} h',
                  detalhe:
                      'Faixa: ${est.duracaoMinimaHoras!.toStringAsFixed(1)}h a ${est.duracaoMaximaHoras!.toStringAsFixed(1)}h (${est.totalAmostrasHoras} ${est.totalAmostrasHoras == 1 ? "amostra" : "amostras"})',
                  subdetalhe: 'Fonte: ${est.fonteHoras}',
                  icone: Icons.access_time_rounded,
                ),
              if (est.temDadosEquipe)
                _buildMetricaItem(
                  titulo: 'Equipe Típica',
                  valor: est.equipeMinimaTecnicos == est.equipeMaximaTecnicos
                      ? '${est.equipeMedianaTecnicos} técnicos'
                      : '${est.equipeMinimaTecnicos} a ${est.equipeMaximaTecnicos} técnicos',
                  detalhe:
                      'Mediana: ${est.equipeMedianaTecnicos} técnicos (${est.totalAmostrasEquipe} ${est.totalAmostrasEquipe == 1 ? "tarefa" : "tarefas"})',
                  subdetalhe: 'Baseado na equipe de campo executante',
                  icone: Icons.group_outlined,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricaItem({
    required String titulo,
    required String valor,
    required String detalhe,
    required String subdetalhe,
    required IconData icone,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icone, size: 20, color: _primaryColor),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(fontSize: 11, color: _textMuted),
            ),
            Text(
              valor,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _textMain,
              ),
            ),
            Text(
              detalhe,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155)),
            ),
            Text(
              subdetalhe,
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCardOcorrencia(NotaSapSimilar oc) {
    final isSemelhante = oc.classificacao ==
        TipoClassificacaoSimilaridade.ocorrenciaSemelhante;

    final badgeCor = isSemelhante
        ? (oc.scoreTotal >= 80.0
            ? const Color(0xFF0F766E)
            : const Color(0xFF0369A1))
        : const Color(0xFFB45309);

    final badgeBg = isSemelhante
        ? (oc.scoreTotal >= 80.0
            ? const Color(0xFFCCFBF1)
            : const Color(0xFFE0F2FE))
        : const Color(0xFFFEF3C7);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSemelhante && oc.scoreTotal >= 80.0
              ? const Color(0xFF99F6E4)
              : _cardBorder,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha superior: Score e Identificação da Nota
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge de Score Auditável com Tooltip
              Tooltip(
                message:
                    'Score Determinístico: ${oc.scoreTotal.toStringAsFixed(0)}% de correspondência técnica.',
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: badgeCor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${oc.scoreTotal.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: badgeCor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        isSemelhante
                            ? Icons.verified_outlined
                            : Icons.build_circle_outlined,
                        size: 16,
                        color: badgeCor,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Nota SAP ${oc.nota.nota}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _textMain,
                          ),
                        ),
                        if (oc.nota.tipo != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              oc.nota.tipo!,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _textMuted),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: oc.estaAberta
                                ? const Color(0xFFFFF7ED)
                                : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: oc.estaAberta
                                  ? const Color(0xFFFDBA74)
                                  : const Color(0xFF86EFAC),
                            ),
                          ),
                          child: Text(
                            oc.estaAberta
                                ? 'ABERTA (${oc.nota.statusSistema ?? "MSPR"})'
                                : 'CONCLUÍDA (${oc.nota.statusSistema ?? "MSEN"})',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: oc.estaAberta
                                  ? const Color(0xFFC2410C)
                                  : const Color(0xFF15803D),
                            ),
                          ),
                        ),
                        if (oc.nota.statusUsuario != null &&
                            oc.nota.statusUsuario!.trim().isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F3FF),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFDDD6FE)),
                            ),
                            child: Text(
                              'Usu: ${oc.nota.statusUsuario!.trim()}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6D28D9),
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (oc.estaAberta) ...[
                          if (oc.nota.criadoEm != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today_outlined,
                                    size: 11, color: _textMuted),
                                const SizedBox(width: 4),
                                Text(
                                  'Criada em: ${_formatarData(oc.nota.criadoEm!)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                        ] else ...[
                          Builder(
                            builder: (context) {
                              final dtConclusao = oc.dataConclusao;
                              if (dtConclusao != null) {
                                final msgTooltip = oc.nota.criadoEm != null
                                    ? 'Criada em: ${_formatarData(oc.nota.criadoEm!)}\nConcluída em: ${_formatarData(dtConclusao)}'
                                    : 'Concluída em: ${_formatarData(dtConclusao)}';
                                return Tooltip(
                                  message: msgTooltip,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.check_circle_outline,
                                          size: 12, color: Color(0xFF15803D)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Concluída em: ${_formatarData(dtConclusao)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF15803D),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              } else if (oc.nota.criadoEm != null) {
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_today_outlined,
                                        size: 11, color: _textMuted),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Criada em: ${_formatarData(oc.nota.criadoEm!)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      oc.nota.descricao ?? 'Sem descrição cadastrada',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Evidências do Score (Explicabilidade obrigatória)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: oc.evidencias.explicacoes.map((exp) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  exp,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569)),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          // Linha de contexto: Equipamento, Local e Horas registradas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _surfaceBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                if (oc.nota.equipamento != null) ...[
                  const Icon(Icons.precision_manufacturing,
                      size: 14, color: _textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'Ativo: ${oc.nota.equipamento}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _textMain),
                  ),
                  const SizedBox(width: 16),
                ],
                if (oc.nota.localInstalacao != null) ...[
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: _textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      oc.nota.localInstalacao!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: _textMuted),
                    ),
                  ),
                ],
                if (oc.horasSapConfirmadas != null) ...[
                  const Icon(Icons.check_circle_outline,
                      size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    'HH SAP: ${oc.horasSapConfirmadas!.toStringAsFixed(1)}h',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.green),
                  ),
                ] else if (oc.tarefasVinculadas.isNotEmpty &&
                    oc.tarefasVinculadas.first.horasExecutadas != null) ...[
                  const Icon(Icons.timer_outlined, size: 14, color: _primaryColor),
                  const SizedBox(width: 4),
                  Text(
                    'TaskFlow: ${oc.tarefasVinculadas.first.horasExecutadas!.toStringAsFixed(1)}h',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _primaryColor),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Botões de Ação Rápida: [Ver Nota], [Ver Análise], [Ver Tarefa]
          Row(
            children: [
              if (oc.temDiagnostico) ...[
                const Icon(Icons.assignment_turned_in_outlined,
                    size: 14, color: _primaryColor),
                const SizedBox(width: 4),
                const Text(
                  'Diagnóstico prévio disponível',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _primaryColor),
                ),
                const SizedBox(width: 12),
              ],
              if (oc.temFotosAnexos) ...[
                const Icon(Icons.photo_library_outlined,
                    size: 14, color: _textMuted),
                const SizedBox(width: 4),
                Text(
                  '${oc.totalAnexos} anexos',
                  style: const TextStyle(fontSize: 11, color: _textMuted),
                ),
              ],
              const Spacer(),
              _buildGrupoInfoOuAcao(oc.nota),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _abrirWorkspaceNota(oc.nota, initialTab: 0),
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text('Ver Nota'),
                style: TextButton.styleFrom(
                  foregroundColor: _primaryColor,
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              if (oc.temAnalise)
                TextButton.icon(
                  onPressed: () => _abrirWorkspaceNota(oc.nota, initialTab: 1),
                  icon: const Icon(Icons.assignment_outlined, size: 14),
                  label: const Text('Ver Análise'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0369A1),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabelaMateriais(List<MaterialFrequencia> materiais) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: materiais.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: _cardBorder),
        itemBuilder: (context, index) {
          final m = materiais[index];
          return ListTile(
            dense: true,
            leading: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.build_outlined,
                  size: 16, color: _primaryColor),
            ),
            title: Text(
              m.descricao,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _textMain),
            ),
            subtitle: m.codigoSap != null
                ? Text('Código SAP: ${m.codigoSap}',
                    style: const TextStyle(fontSize: 11, color: _textMuted))
                : null,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Text(
                m.frequenciaTexto,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF15803D),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCardDemandaAberta(DemandaAbertaRelacionada dem) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.pending_actions, color: Color(0xFFD97706), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Nota ${dem.nota.nota}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        dem.nota.statusSistema ?? 'ABERTA',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB45309)),
                      ),
                    ),
                    if (dem.nota.criadoEm != null) ...[
                      const SizedBox(width: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 11, color: Color(0xFFB45309)),
                          const SizedBox(width: 4),
                          Text(
                            'Criada em: ${_formatarData(dem.nota.criadoEm!)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                Text(
                  dem.nota.descricao ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF78350F)),
                ),
                const SizedBox(height: 2),
                Text(
                  dem.motivo,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB45309)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildGrupoInfoOuAcao(dem.nota),
          TextButton(
            onPressed: () => _abrirWorkspaceNota(dem.nota),
            child: const Text(
              'Ver Detalhes',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFB45309)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoVazio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.manage_search_outlined,
                  size: 40, color: _textMuted),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhuma ocorrência semelhante encontrada',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _textMain),
            ),
            const SizedBox(height: 8),
            const Text(
              'Não há histórico registrado para este ativo ou local com falha similar.\nEsta pode ser uma intervenção inédita ou o ativo foi cadastrado recentemente.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _textMuted),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => _carregarSimilaridades(forceRefresh: true),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Atualizar Busca'),
              style: OutlinedButton.styleFrom(foregroundColor: _primaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvisoVazio(String texto) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: _textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(fontSize: 12, color: _textMuted),
            ),
          ),
        ],
      ),
    );
  }

  void _abrirWorkspaceNota(NotaSAP nota, {int initialTab = 0}) {
    NotaAnaliseWorkspace.abrir(
      context,
      nota: nota,
      initialTab: initialTab,
    ).then((_) {
      _carregarGruposVinculados();
      widget.onAtualizacao?.call();
    });
  }

  String _formatarData(DateTime dt) {
    final dia = dt.day.toString().padLeft(2, '0');
    final mes = dt.month.toString().padLeft(2, '0');
    final ano = dt.year.toString();
    return '$dia/$mes/$ano';
  }

  // ===========================================================================
  // INTEGRAÇÃO COM GRUPOS DE NOTAS SAP (SEÇÃO 24 E 25)
  // ===========================================================================

  Future<void> _carregarGruposVinculados() async {
    if (_carregandoGrupos) return;
    _carregandoGrupos = true;

    try {
      final grupoAtual = await _grupoService.buscarGrupoAtivoDaNota(widget.nota.id);
      if (mounted) {
        setState(() {
          _grupoNotaAtual = grupoAtual;
        });
      }

      final res = _resultado;
      if (res != null) {
        final notasParaBuscar = <NotaSAP>[];
        for (final oc in res.todasOcorrencias) {
          if (!_gruposPorNotaId.containsKey(oc.nota.id)) {
            notasParaBuscar.add(oc.nota);
          }
        }
        for (final oc in res.historicoMesmoAtivo) {
          if (!_gruposPorNotaId.containsKey(oc.nota.id)) {
            notasParaBuscar.add(oc.nota);
          }
        }
        for (final dem in res.demandasAbertasRelacionadas) {
          if (!_gruposPorNotaId.containsKey(dem.nota.id)) {
            notasParaBuscar.add(dem.nota);
          }
        }

        for (final n in notasParaBuscar) {
          final g = await _grupoService.buscarGrupoAtivoDaNota(n.id);
          _gruposPorNotaId[n.id] = g;
        }

        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('ℹ️ [NotaSapSimilaridadePanel] Erro ao carregar grupos vinculados: $e');
    } finally {
      _carregandoGrupos = false;
    }
  }

  Widget _buildGrupoInfoOuAcao(NotaSAP notaCandidata) {
    final grupoExistente = _gruposPorNotaId[notaCandidata.id];

    if (grupoExistente != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF86EFAC)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hub_outlined, size: 13, color: Color(0xFF15803D)),
            const SizedBox(width: 4),
            Text(
              'Pertence ao grupo: ${grupoExistente.nome}${grupoExistente.previsaoFormatada.isNotEmpty ? " • Prev.: ${grupoExistente.previsaoFormatada}" : ""}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF166534),
              ),
            ),
          ],
        ),
      );
    }

    // Seção 25: NUNCA vincular automaticamente. Exige ação explícita do usuário.
    return OutlinedButton.icon(
      onPressed: () => _iniciarVinculoNotaAoGrupo(notaCandidata),
      icon: const Icon(Icons.hub_outlined, size: 13),
      label: const Text('Vincular ao grupo'),
      style: OutlinedButton.styleFrom(
        foregroundColor: _primaryColor,
        side: const BorderSide(color: _primaryColor),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Future<void> _iniciarVinculoNotaAoGrupo(NotaSAP candidata) async {
    final grupoAtual = _grupoNotaAtual;

    if (grupoAtual != null) {
      final motivoCtrl = TextEditingController(
        text: 'Identificada como similar no Módulo H para programação conjunta',
      );

      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.hub_outlined, color: _primaryColor),
              const SizedBox(width: 8),
              Text('Vincular Nota ${candidata.nota}'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Deseja incluir a Nota ${candidata.nota} no grupo ativo "${grupoAtual.nome}"?',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (grupoAtual.previsaoFormatada.isNotEmpty)
                Text(
                  'Previsão do grupo: ${grupoAtual.previsaoFormatada}',
                  style: const TextStyle(fontSize: 12, color: _primaryColor, fontWeight: FontWeight.bold),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: motivoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Motivo do vínculo',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirmar Vínculo'),
            ),
          ],
        ),
      );

      if (confirmar == true && mounted) {
        try {
          String? userId;
          String userName = 'Analista';
          try {
            final auth = AuthServiceSimples();
            final user = auth.currentUser;
            userId = user?.id;
            userName = auth.getUserName() ?? user?.email ?? 'Analista';
          } catch (_) {}

          await _grupoService.adicionarNotaAoGrupo(
            grupoId: grupoAtual.id,
            notaSapId: candidata.id,
            motivoVinculo: motivoCtrl.text.trim().isNotEmpty ? motivoCtrl.text.trim() : null,
            usuarioId: userId,
            usuarioNome: userName,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Nota ${candidata.nota} vinculada ao grupo "${grupoAtual.nome}"!'),
                backgroundColor: _primaryColor,
              ),
            );
            _carregarGruposVinculados();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao vincular nota: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } else {
      // Nota de referência não possui grupo ainda
      final criarGrupo = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: _primaryColor),
              SizedBox(width: 8),
              Text('Sem Grupo Ativo'),
            ],
          ),
          content: Text(
            'A Nota principal ${widget.nota.nota} ainda não pertence a nenhum grupo de programação.\n\n'
            'Abra a aba "Vínculo & Previsão" para criar o grupo principal e então vincular as Notas relacionadas.',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
      if (criarGrupo == true) {}
    }
  }
}
