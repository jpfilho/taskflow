import 'package:flutter/material.dart';
import '../../design_system/foundations/tf_radius.dart';
import '../../models/nota_sap.dart';
import '../../models/nota_sap_analise.dart';
import '../../models/nota_sap_similaridade.dart';
import '../../models/nota_historico_tecnico.dart';
import '../../services/nota_historico_tecnico_service.dart';
import '../../services/nota_sap_analise_service.dart';
import 'nota_anexo_viewer_dialog.dart';

/// Filtros de escopo de correspondência para o Histórico Técnico.
enum FiltroHistoricoTecnico {
  todos,
  mesmoEquipamento,
  mesmaEstrutura,
  similares,
  mesmoLocal,
}

/// Seção Visual de Histórico Técnico de Notas SAP Anteriores (Read-Only).
///
/// Apresenta o histórico do ativo (Equipamento, Estrutura, Local) e Similaridade Técnica
/// com carga inicial leve e expansão sob demanda (Lazy Loading).
class NotaWorkspaceHistoricoTecnicoSection extends StatefulWidget {
  final NotaSAP nota;
  final NotaHistoricoTecnicoService? service;
  final NotaSapAnaliseService? analiseService;
  final void Function(NotaSAP notaHistorica)? onAbrirNotaHistorica;

  const NotaWorkspaceHistoricoTecnicoSection({
    super.key,
    required this.nota,
    this.service,
    this.analiseService,
    this.onAbrirNotaHistorica,
  });

  @override
  State<NotaWorkspaceHistoricoTecnicoSection> createState() =>
      _NotaWorkspaceHistoricoTecnicoSectionState();
}

class _NotaWorkspaceHistoricoTecnicoSectionState
    extends State<NotaWorkspaceHistoricoTecnicoSection> {
  late final NotaHistoricoTecnicoService _service;
  late final NotaSapAnaliseService _analiseService;

  NotaHistoricoTecnicoResultado? _resultado;
  bool _isLoading = true;
  String? _erro;

  FiltroHistoricoTecnico _filtroSelecionado = FiltroHistoricoTecnico.todos;
  int _filtroAnos = 0; // 0 = Todos os anos

  // Controle de cards expandidos e itens lazy carregados
  final Set<String> _expandidosIds = {};
  final Map<String, NotaHistoricoTecnicoItem> _itensDetalhados = {};
  final Set<String> _carregandoDetalhes = {};

  static const Color _primaryColor = Color(0xFF0F766E);
  static const Color _cardBorder = Color(0xFFE2E8F0);
  static const Color _textMain = Color(0xFF1E293B);
  static const Color _textMuted = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? NotaHistoricoTecnicoService();
    _analiseService = widget.analiseService ?? NotaSapAnaliseService();
    _carregarHistorico();
  }

  @override
  void didUpdateWidget(covariant NotaWorkspaceHistoricoTecnicoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nota.id != widget.nota.id) {
      _expandidosIds.clear();
      _itensDetalhados.clear();
      _carregarHistorico();
    }
  }

  Future<void> _carregarHistorico({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _erro = null;
    });

    try {
      // 1. Carga Rápida Útil: Critérios A e B com inventário batch em ~400ms (Time to Useful History)
      final resUtil = await _service.carregarHistoricoAtivoUtil(
        notaReferencia: widget.nota,
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _resultado = resUtil;
          _isLoading = false; // A TELA FICA UTILIZÁVEL DE IMEDIATO!
        });
      }

      // Se já estava completo do cache, não há necessidade de reconsultar
      if (!resUtil.carregandoSimilares && !resUtil.carregandoLocalAmplo) {
        return;
      }

      // 2. Carrega Similaridade Técnica (Critério D) sem travar a UI
      final resComSim = await _service.carregarSimilaresAssincrono(resUtil);
      if (mounted) {
        setState(() {
          _resultado = resComSim;
        });
      }

      // 3. Carrega Contexto Amplo (Critério C) de forma progressiva
      final resFinal = await _service.carregarLocalAmploAssincrono(resComSim);
      if (mounted) {
        setState(() {
          _resultado = resFinal;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = 'Não foi possível carregar o histórico técnico: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _alternarExpansao(NotaHistoricoTecnicoItem item) async {
    final id = item.notaSap.id;
    if (_expandidosIds.contains(id)) {
      setState(() => _expandidosIds.remove(id));
      return;
    }

    setState(() => _expandidosIds.add(id));

    // Se ainda não carregou os detalhes completos lazy
    if (!_itensDetalhados.containsKey(id) && !item.detalhesCarregados) {
      setState(() => _carregandoDetalhes.add(id));
      try {
        final itemCompleto = await _service.carregarDetalhesLazy(item);
        if (mounted) {
          setState(() {
            _itensDetalhados[id] = itemCompleto;
            _carregandoDetalhes.remove(id);
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => _carregandoDetalhes.remove(id));
        }
      }
    }
  }

  List<NotaHistoricoTecnicoItem> _aplicarFiltros(NotaHistoricoTecnicoResultado res) {
    List<NotaHistoricoTecnicoItem> listaBase;

    switch (_filtroSelecionado) {
      case FiltroHistoricoTecnico.todos:
        listaBase = res.todosItensDeduplicados;
        break;
      case FiltroHistoricoTecnico.mesmoEquipamento:
        listaBase = res.itensEquipamento;
        break;
      case FiltroHistoricoTecnico.mesmaEstrutura:
        listaBase = res.itensEstrutura;
        break;
      case FiltroHistoricoTecnico.similares:
        listaBase = res.todosItensDeduplicados.where((i) => i.ehSimilar).toList();
        break;
      case FiltroHistoricoTecnico.mesmoLocal:
        listaBase = res.itensLocal;
        break;
    }

    if (_filtroAnos > 0) {
      final limiteData = DateTime.now().subtract(Duration(days: 365 * _filtroAnos));
      listaBase = listaBase.where((i) {
        final dt = i.notaSap.criadoEm ?? i.notaSap.data;
        if (dt == null) return false;
        return dt.isAfter(limiteData);
      }).toList();
    }

    return listaBase;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 2.5, color: _primaryColor),
              SizedBox(height: 16),
              Text(
                'Consultando histórico de notas anteriores no mesmo ativo...',
                style: TextStyle(fontSize: 13, color: _textMuted),
              ),
            ],
          ),
        ),
      );
    }

    if (_erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.orange, size: 36),
              const SizedBox(height: 12),
              Text(_erro!, style: const TextStyle(fontSize: 13, color: _textMain)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _carregarHistorico(forceRefresh: true),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    final res = _resultado!;
    if (res.estaVazio) {
      return _buildEstadoVazio();
    }

    final itensFiltrados = _aplicarFiltros(res);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Barra Superior de Filtros Rápidos
        _buildBarraFiltros(res),
        const SizedBox(height: 12),

        // Lista de Cards de Notas Históricas
        if (itensFiltrados.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'Nenhuma nota encontrada com o filtro selecionado.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: itensFiltrados.length,
            itemBuilder: (context, index) {
              final item = itensFiltrados[index];
              final itemAtual = _itensDetalhados[item.notaSap.id] ?? item;
              return _buildCardNotaHistorica(itemAtual);
            },
          ),
      ],
    );
  }

  Widget _buildBarraFiltros(NotaHistoricoTecnicoResultado res) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(TFRadius.r12),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_edu, size: 20, color: _primaryColor),
              const SizedBox(width: 8),
              const Text(
                'Histórico Técnico de Notas Anteriores',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _textMain),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.refresh, size: 18, color: _textMuted),
                tooltip: 'Atualizar histórico',
                onPressed: () => _carregarHistorico(forceRefresh: true),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _primaryColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(TFRadius.r8),
                  border: Border.all(color: _primaryColor.withAlpha(60)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 12, color: _primaryColor),
                    const SizedBox(width: 4),
                    Text(
                      widget.nota.local ?? widget.nota.localInstalacao ?? 'Local',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.nota.sala != null && widget.nota.sala!.trim().isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withAlpha(20),
                    borderRadius: BorderRadius.circular(TFRadius.r8),
                    border: Border.all(color: const Color(0xFF1565C0).withAlpha(60)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.meeting_room_outlined, size: 12, color: Color(0xFF1565C0)),
                      const SizedBox(width: 4),
                      Text(
                        'Sala: ${widget.nota.sala}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'Todos (${res.totalItens})',
                  selected: _filtroSelecionado == FiltroHistoricoTecnico.todos,
                  onSelected: () => setState(() => _filtroSelecionado = FiltroHistoricoTecnico.todos),
                ),
                if (res.totalEquipamento > 0) ...[
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    label: 'Mesmo Equipamento (${res.totalEquipamento})',
                    selected: _filtroSelecionado == FiltroHistoricoTecnico.mesmoEquipamento,
                    onSelected: () => setState(
                        () => _filtroSelecionado = FiltroHistoricoTecnico.mesmoEquipamento),
                  ),
                ],
                if (res.totalEstrutura > 0) ...[
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    label: 'Mesma Estrutura (${res.totalEstrutura})',
                    selected: _filtroSelecionado == FiltroHistoricoTecnico.mesmaEstrutura,
                    onSelected: () =>
                        setState(() => _filtroSelecionado = FiltroHistoricoTecnico.mesmaEstrutura),
                  ),
                ],
                if (res.totalApenasSimilaridade > 0 ||
                    res.todosItensDeduplicados.any((i) => i.ehSimilar)) ...[
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    label: 'Similares',
                    selected: _filtroSelecionado == FiltroHistoricoTecnico.similares,
                    onSelected: () =>
                        setState(() => _filtroSelecionado = FiltroHistoricoTecnico.similares),
                  ),
                ] else if (res.carregandoSimilares) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(TFRadius.r12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: _primaryColor),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Buscando similares...',
                          style: TextStyle(fontSize: 11, color: _textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
                if (res.totalLocal > 0) ...[
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    label: 'Mesmo Local (${res.totalLocal})',
                    selected: _filtroSelecionado == FiltroHistoricoTecnico.mesmoLocal,
                    onSelected: () =>
                        setState(() => _filtroSelecionado = FiltroHistoricoTecnico.mesmoLocal),
                  ),
                ],
                const SizedBox(width: 12),
                Container(width: 1, height: 20, color: Colors.grey.shade300),
                const SizedBox(width: 12),
                _buildTimeFilterChip('1 ano', 1),
                const SizedBox(width: 4),
                _buildTimeFilterChip('2 anos', 2),
                const SizedBox(width: 4),
                _buildTimeFilterChip('5 anos', 5),
                const SizedBox(width: 4),
                _buildTimeFilterChip('Tudo', 0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      selected: selected,
      showCheckmark: false,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
        color: selected ? Colors.white : _textMain,
      ),
      backgroundColor: const Color(0xFFF1F5F9),
      selectedColor: _primaryColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TFRadius.r8)),
      onSelected: (_) => onSelected(),
    );
  }

  Widget _buildTimeFilterChip(String label, int anos) {
    final selected = _filtroAnos == anos;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 11.0,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        color: selected ? _primaryColor : _textMuted,
      ),
      backgroundColor: Colors.transparent,
      selectedColor: const Color(0xFFCCFBF1),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      onSelected: (_) => setState(() => _filtroAnos = anos),
    );
  }

  Widget _buildCardNotaHistorica(NotaHistoricoTecnicoItem item) {
    final id = item.notaSap.id;
    final isExpandido = _expandidosIds.contains(id);
    final isCarregandoDetalhes = _carregandoDetalhes.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(TFRadius.r12),
        border: Border.all(
          color: item.ehMesmoEquipamento ? const Color(0xFF99F6E4) : _cardBorder,
          width: item.ehMesmoEquipamento ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho do Card
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge do Critério Físico
                    _buildBadgeCriterio(item),
                    const SizedBox(width: 8),

                    // Badge de Similaridade Determinística (se houver)
                    if (item.ehSimilar && item.scoreSimilaridade != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(TFRadius.r8),
                          border: Border.all(color: const Color(0xFF7DD3FC)),
                        ),
                        child: Text(
                          'Similar: ${item.scoreSimilaridade!.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0369A1),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            'Nota SAP ${item.notaSap.nota}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _textMain,
                            ),
                          ),
                          if (item.dataFormatada.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              item.dataFormatada,
                              style: const TextStyle(fontSize: 11.5, color: _textMuted),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Status Sistema
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.estaAberta ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: item.estaAberta ? const Color(0xFFFDBA74) : const Color(0xFF86EFAC),
                        ),
                      ),
                      child: Text(
                        item.estaAberta
                            ? 'ABERTA (${item.notaSap.statusSistema ?? "MSPR"})'
                            : 'CONCLUÍDA (${item.notaSap.statusSistema ?? "MSEN"})',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: item.estaAberta ? const Color(0xFFC2410C) : const Color(0xFF15803D),
                        ),
                      ),
                    ),
                    if (item.notaSap.statusUsuario != null &&
                        item.notaSap.statusUsuario!.trim().isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFDDD6FE)),
                        ),
                        child: Text(
                          'Usu: ${item.notaSap.statusUsuario!.trim()}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6D28D9),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // Motivos Coincidentes
                if (item.motivosFisicos.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.motivosFisicos.join(' • '),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: item.ehMesmoEquipamento ? _primaryColor : Colors.indigo.shade700,
                    ),
                  ),
                ],

                // Descrição da Nota
                if (item.notaSap.descricao != null && item.notaSap.descricao!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.notaSap.descricao!,
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155)),
                    maxLines: isExpandido ? null : 2,
                    overflow: isExpandido ? null : TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 10),

                // Rodapé do Card com Inventário e Ações
                Row(
                  children: [
                    // Pílulas de Inventário
                    if (item.totalAnexos > 0) ...[
                      _buildInventarioPill(
                        icon: Icons.attach_file,
                        label: '${item.totalAnexos} anexos',
                        color: Colors.blue.shade700,
                        bgColor: Colors.blue.shade50,
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (item.temAnalise) ...[
                      _buildInventarioPill(
                        icon: Icons.assignment_outlined,
                        label: 'Análise técnica',
                        color: Colors.teal.shade700,
                        bgColor: Colors.teal.shade50,
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (item.totalTasks > 0) ...[
                      _buildInventarioPill(
                        icon: Icons.task_alt,
                        label: '${item.totalTasks} tarefas',
                        color: Colors.purple.shade700,
                        bgColor: Colors.purple.shade50,
                      ),
                      const SizedBox(width: 6),
                    ],

                    const Spacer(),

                    // Ação [Abrir Nota] em modo consulta
                    if (widget.onAbrirNotaHistorica != null) ...[
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        icon: const Icon(Icons.open_in_new, size: 14),
                        label: const Text('Abrir Nota', style: TextStyle(fontSize: 11.5)),
                        onPressed: () => widget.onAbrirNotaHistorica!(item.notaSap),
                      ),
                      const SizedBox(width: 6),
                    ],

                    // Botão Expandir / Recolher
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(TFRadius.r8),
                        ),
                      ),
                      icon: Icon(
                        isExpandido ? Icons.expand_less : Icons.expand_more,
                        size: 16,
                      ),
                      label: Text(
                        isExpandido ? 'Recolher' : 'Ver Detalhes',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () => _alternarExpansao(item),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Seção Expandida (Lazy Loading de Análise, Anexos e Tasks)
          if (isExpandido) ...[
            const Divider(height: 1, color: _cardBorder),
            if (isCarregandoDetalhes)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _primaryColor),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Carregando anexos, análise e tarefas da nota histórica...',
                        style: TextStyle(fontSize: 12, color: _textMuted),
                      ),
                    ],
                  ),
                ),
              )
            else
              _buildConteudoExpandido(item),
          ],
        ],
      ),
    );
  }

  Widget _buildBadgeCriterio(NotaHistoricoTecnicoItem item) {
    final String label;
    final Color cor;
    final Color bg;

    switch (item.criterioFisicoPrincipal) {
      case NotaHistoricoCriterioFisico.mesmoEquipamento:
        label = 'Mesmo Equipamento';
        cor = const Color(0xFF0F766E);
        bg = const Color(0xFFCCFBF1);
        break;
      case NotaHistoricoCriterioFisico.mesmaEstrutura:
        label = 'Mesma Estrutura';
        cor = const Color(0xFF4338CA);
        bg = const Color(0xFFEEF2FF);
        break;
      case NotaHistoricoCriterioFisico.mesmoLocal:
        label = 'Mesmo Local';
        cor = const Color(0xFFB45309);
        bg = const Color(0xFFFEF3C7);
        break;
      case NotaHistoricoCriterioFisico.apenasSimilaridade:
        label = 'Similar';
        cor = const Color(0xFF0369A1);
        bg = const Color(0xFFE0F2FE);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(TFRadius.r8),
        border: Border.all(color: cor.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cor),
      ),
    );
  }

  Widget _buildInventarioPill({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildConteudoExpandido(NotaHistoricoTecnicoItem item) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Análise Técnica Anterior (apenas se existir dados)
          if (item.analise != null) ...[
            _buildSecaoAnaliseAnterior(item.analise!),
            const SizedBox(height: 14),
          ],

          // 2. Anexos Históricos
          _buildSecaoAnexosHistoricos(item),

          // 3. Tarefas Vinculadas Anteriores
          if (item.tasks.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildSecaoTasksAnteriores(item.tasks),
          ],
        ],
      ),
    );
  }

  Widget _buildSecaoAnaliseAnterior(NotaSapAnalise analise) {
    final diag = analise.diagnosticoPrevio?.trim();
    final escopo = analise.escopoDetalhado?.trim();
    final seg = analise.requisitosSeguranca?.trim();

    final temConteudo = (diag != null && diag.isNotEmpty) ||
        (escopo != null && escopo.isNotEmpty) ||
        (seg != null && seg.isNotEmpty);

    if (!temConteudo) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(TFRadius.r8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.assignment, size: 16, color: _primaryColor),
              SizedBox(width: 6),
              Text(
                'Análise Técnica Registrada na Nota Anterior',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _textMain),
              ),
            ],
          ),
          if (diag != null && diag.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Diagnóstico Técnico:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textMuted),
            ),
            const SizedBox(height: 2),
            Text(diag, style: const TextStyle(fontSize: 12, color: _textMain)),
          ],
          if (escopo != null && escopo.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Escopo Planejado:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textMuted),
            ),
            const SizedBox(height: 2),
            Text(escopo, style: const TextStyle(fontSize: 12, color: _textMain)),
          ],
          if (seg != null && seg.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Requisitos de Segurança:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textMuted),
            ),
            const SizedBox(height: 2),
            Text(seg, style: const TextStyle(fontSize: 12, color: _textMain)),
          ],
        ],
      ),
    );
  }

  Widget _buildSecaoAnexosHistoricos(NotaHistoricoTecnicoItem item) {
    if (item.anexos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(TFRadius.r8),
        ),
        child: const Row(
          children: [
            Icon(Icons.attachment, size: 16, color: _textMuted),
            SizedBox(width: 8),
            Text(
              'Esta nota anterior não possui anexos cadastrados.',
              style: TextStyle(fontSize: 12, color: _textMuted),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.collections, size: 16, color: _primaryColor),
            const SizedBox(width: 6),
            Text(
              'Anexos Históricos (${item.anexos.length})',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _textMain),
            ),
            const SizedBox(width: 8),
            Text(
              '• Somente leitura',
              style: TextStyle(fontSize: 11, color: Colors.amber.shade800),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: item.anexos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final anexo = item.anexos[idx];
              final ehImagem = anexo.tipoArquivo == NotaAnexoTipo.imagem;

              return InkWell(
                borderRadius: BorderRadius.circular(TFRadius.r8),
                onTap: () {
                  NotaAnexoViewerDialog.abrir(
                    context: context,
                    anexos: item.anexos,
                    indiceInicial: idx,
                    contextoFiltro: 'Nota SAP ${item.notaSap.nota}',
                    service: _analiseService,
                    isHistoricoReadOnly: true,
                    notaHistoricaNumero: item.notaSap.nota,
                    notaHistoricaData: item.dataFormatada,
                  );
                },
                child: Container(
                  width: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(TFRadius.r8),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: ehImagem
                            ? const Icon(Icons.image, size: 32, color: Colors.blueGrey)
                            : const Icon(Icons.picture_as_pdf, size: 32, color: Colors.redAccent),
                      ),
                      if (anexo.possuiAnotacao)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade800,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'v${anexo.versaoAnotacao}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(160),
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                          ),
                          child: Text(
                            anexo.nomeExibicao,
                            style: const TextStyle(color: Colors.white, fontSize: 9.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSecaoTasksAnteriores(List<TarefaHistoricaResumo> tasks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.task_alt, size: 16, color: _primaryColor),
            SizedBox(width: 6),
            Text(
              'Tarefas Operacionais Associadas',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _textMain),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...tasks.map(
          (t) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _cardBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.tarefaNome ?? 'Tarefa sem título',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: t.status.toUpperCase() == 'CONC'
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    t.status,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: t.status.toUpperCase() == 'CONC'
                          ? const Color(0xFF15803D)
                          : const Color(0xFFC2410C),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEstadoVazio() {
    final nomeLocal = widget.nota.local ?? widget.nota.localInstalacao ?? 'este local';
    final nomeSala = widget.nota.sala;
    final temSala = nomeSala != null && nomeSala.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(TFRadius.r12),
        border: Border.all(color: _cardBorder),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_toggle_off, size: 44, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              temSala
                  ? 'Nenhum histórico de notas anteriores para o local "$nomeLocal" e sala "$nomeSala".'
                  : 'Nenhum histórico técnico de notas anteriores encontrado para "$nomeLocal".',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _textMain),
            ),
            const SizedBox(height: 4),
            Text(
              temSala
                  ? 'Esta Nota pode representar a primeira intervenção registrada nesta sala ou não há outras ocorrências cadastradas para este ponto.'
                  : 'Esta Nota pode representar a primeira intervenção registrada no ponto ou não há ocorrências no mesmo vão/equipamento.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: _textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
