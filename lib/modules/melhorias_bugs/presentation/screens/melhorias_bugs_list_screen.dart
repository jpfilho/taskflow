import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../design_system/taskflow_design_system.dart';
import '../../../../models/melhoria_bug.dart';
import '../../../../models/versao.dart';
import '../../../../services/auth_service_simples.dart';
import '../../../../services/melhorias_bugs_service.dart';
import '../widgets/melhoria_bug_card.dart';
import '../widgets/melhoria_bug_form_dialog.dart';

class MelhoriasBugsListScreen extends StatefulWidget {
  const MelhoriasBugsListScreen({super.key});

  @override
  State<MelhoriasBugsListScreen> createState() => _MelhoriasBugsListScreenState();
}

class _MelhoriasBugsListScreenState extends State<MelhoriasBugsListScreen> {
  final MelhoriasBugsService _service = MelhoriasBugsService();
  final AuthServiceSimples _authService = AuthServiceSimples();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<MelhoriaBug> _items = [];
  List<Versao> _versoes = [];
  bool _loading = true;
  String? _filtroStatus;
  String? _filtroTipo;
  String? _filtroPrazo; // null | 'sem_prazo' | 'vencidos' | 'proximos'
  bool _apenasAtivos = true;
  String _searchTerm = '';

  // Controles de layout
  bool _mostrarMetricas = false; // Recolhido por padrão para dar foco total às solicitações
  bool _alertaProgramadorFechado = false;
  String _modoVisualizacao = 'tabela'; // 'tabela' ou 'cards'

  bool get _isProgramador {
    final user = _authService.currentUser;
    if (user == null) return false;
    final email = user.email.toLowerCase().trim();
    return email == 'jpfilho@axia.com.br' || user.isRoot;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No mobile, forçar modo cards
    if (TFBreakpoints.isMobile(context) && _modoVisualizacao == 'tabela') {
      _modoVisualizacao = 'cards';
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final versoes = await _service.getVersoes();
      final items = await _service.getMelhoriasBugs(
        status: _filtroStatus,
        tipo: _filtroTipo,
        ativosApenas: _apenasAtivos,
      );
      if (mounted) {
        setState(() {
          _versoes = versoes;
          _items = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar itens: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  List<MelhoriaBug> get _filteredItems {
    var list = _items;

    // Filtro por prazo
    if (_filtroPrazo == 'sem_prazo') {
      list = list.where((i) => i.prazo == null && i.isAberta).toList();
    } else if (_filtroPrazo == 'vencidos') {
      list = list.where((i) => i.isPrazoVencido).toList();
    } else if (_filtroPrazo == 'proximos') {
      list = list.where((i) => i.isPrazoProximo).toList();
    }

    final term = _searchTerm.trim().toLowerCase();
    if (term.isEmpty) return list;

    return list.where((item) {
      final matchTitle = item.titulo.toLowerCase().contains(term);
      final matchDesc = item.descricao?.toLowerCase().contains(term) ?? false;
      return matchTitle || matchDesc;
    }).toList();
  }

  void _openForm([MelhoriaBug? item]) async {
    final result = await showDialog<MelhoriaBug>(
      context: context,
      builder: (ctx) => MelhoriaBugFormDialog(
        initial: item,
        versoes: _versoes,
        onSave: (mb) => _service.saveMelhoriaBug(mb),
      ),
    );
    if (result != null) _load();
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    bool isCompact = false,
  }) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return TFCard(
      variant: onTap != null ? TFCardVariant.interactive : TFCardVariant.defaultCard,
      onTap: onTap,
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 16,
        vertical: isCompact ? 8 : 10,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(TFRadius.r8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: typography.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              Text(
                label,
                style: typography.caption.copyWith(
                  color: colors.textSecondary,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgramadorAlertBanner(BuildContext context) {
    if (!_isProgramador || _alertaProgramadorFechado) return const SizedBox.shrink();

    final colors = context.tfColors;
    final typography = context.tfTypography;
    final isMobile = TFBreakpoints.isMobile(context);

    final itensAguardando = _items.where((i) => i.status == 'BACKLOG').length;
    final itensSemPrazo = _items.where((i) => i.prazo == null && i.isAberta).length;
    final itensVencidos = _items.where((i) => i.isPrazoVencido).length;
    final itensProximos = _items.where((i) => i.isPrazoProximo).length;

    final totalPendencias = itensAguardando + itensSemPrazo + itensVencidos;
    if (totalPendencias == 0 && itensProximos == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surfaceSecondary,
          borderRadius: BorderRadius.circular(TFRadius.r8),
          border: Border.all(
            color: itensVencidos > 0
                ? colors.danger.withValues(alpha: 0.35)
                : colors.primary.withValues(alpha: 0.25),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.notifications_active_rounded,
              color: itensVencidos > 0 ? colors.danger : colors.primary,
              size: 18,
            ),
            const SizedBox(width: 8),
            if (!isMobile) ...[
              Text(
                'Pendências:',
                style: typography.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (itensVencidos > 0) ...[
                      _buildAlertChip(
                        label: '$itensVencidos vencidos',
                        color: colors.danger,
                        icon: Icons.error_outline_rounded,
                        selected: _filtroPrazo == 'vencidos',
                        onTap: () {
                          setState(() {
                            _filtroPrazo = _filtroPrazo == 'vencidos' ? null : 'vencidos';
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (itensSemPrazo > 0) ...[
                      _buildAlertChip(
                        label: '$itensSemPrazo sem prazo',
                        color: colors.warning,
                        icon: Icons.calendar_today_outlined,
                        selected: _filtroPrazo == 'sem_prazo',
                        onTap: () {
                          setState(() {
                            _filtroPrazo = _filtroPrazo == 'sem_prazo' ? null : 'sem_prazo';
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (itensProximos > 0) ...[
                      _buildAlertChip(
                        label: '$itensProximos vencendo logo',
                        color: colors.info,
                        icon: Icons.access_time_rounded,
                        selected: _filtroPrazo == 'proximos',
                        onTap: () {
                          setState(() {
                            _filtroPrazo = _filtroPrazo == 'proximos' ? null : 'proximos';
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (itensAguardando > 0) ...[
                      _buildAlertChip(
                        label: '$itensAguardando em análise',
                        color: colors.primary,
                        icon: Icons.pending_actions_rounded,
                        selected: _filtroStatus == 'BACKLOG',
                        onTap: () {
                          setState(() {
                            _filtroStatus = _filtroStatus == 'BACKLOG' ? null : 'BACKLOG';
                          });
                          _load();
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 16, color: colors.textSecondary),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Ocultar avisos',
              onPressed: () {
                setState(() => _alertaProgramadorFechado = true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertChip({
    required String label,
    required Color color,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final typography = context.tfTypography;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(TFRadius.r8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.25) : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(TFRadius.r8),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: typography.caption.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricasPanel(BuildContext context) {
    final colors = context.tfColors;
    final isMobile = TFBreakpoints.isMobile(context);

    final totalItems = _items.length;
    final bugsCriticos = _items.where((i) => i.tipo == kTipoBug && i.prioridade == 'CRITICA').length;
    final sugestoes = _items.where((i) => i.tipo == kTipoMelhoria).length;
    final roadmapCount = _versoes.length;

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildStatCard(
                label: 'Total Listado',
                value: totalItems.toString(),
                icon: Icons.analytics_outlined,
                color: colors.primary,
                isCompact: true,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                label: 'Bugs Críticos',
                value: bugsCriticos.toString(),
                icon: Icons.bug_report_outlined,
                color: colors.danger,
                isCompact: true,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                label: 'Sugestões',
                value: sugestoes.toString(),
                icon: Icons.lightbulb_outline,
                color: colors.warning,
                isCompact: true,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                label: 'Roadmap',
                value: roadmapCount.toString(),
                icon: Icons.map_outlined,
                color: colors.info,
                isCompact: true,
              ),
            ],
          ),
        ),
      );
    }

    // No desktop: 1 única linha horizontal compacta
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              label: 'Total Listado',
              value: totalItems.toString(),
              icon: Icons.analytics_outlined,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard(
              label: 'Bugs Críticos',
              value: bugsCriticos.toString(),
              icon: Icons.bug_report_outlined,
              color: colors.danger,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard(
              label: 'Sugestões',
              value: sugestoes.toString(),
              icon: Icons.lightbulb_outline,
              color: colors.warning,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard(
              label: 'Versões Roadmap',
              value: roadmapCount.toString(),
              icon: Icons.map_outlined,
              color: colors.info,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final isMobile = TFBreakpoints.isMobile(context);
    final count = _filteredItems.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Text(
            'Central de Evolução',
            style: (isMobile ? typography.sectionTitle : typography.pageTitle).copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(TFRadius.r8),
            ),
            child: Text(
              '$count',
              style: typography.caption.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),

          // Botão de expandir/recolher métricas
          IconButton(
            icon: Icon(
              _mostrarMetricas ? Icons.dashboard_rounded : Icons.dashboard_outlined,
              size: 20,
              color: _mostrarMetricas ? colors.primary : colors.textSecondary,
            ),
            tooltip: _mostrarMetricas ? 'Ocultar indicadores' : 'Exibir indicadores',
            onPressed: () {
              setState(() => _mostrarMetricas = !_mostrarMetricas);
            },
          ),

          // Seletor de visualização (Tabela vs Cards) no Desktop
          if (!isMobile) ...[
            const SizedBox(width: 4),
            Container(
              decoration: BoxDecoration(
                color: colors.surfaceSecondary,
                borderRadius: BorderRadius.circular(TFRadius.r8),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.table_rows_rounded,
                      size: 18,
                      color: _modoVisualizacao == 'tabela' ? colors.primary : colors.textSecondary,
                    ),
                    tooltip: 'Visualização em Tabela',
                    onPressed: () => setState(() => _modoVisualizacao = 'tabela'),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.grid_view_rounded,
                      size: 18,
                      color: _modoVisualizacao == 'cards' ? colors.primary : colors.textSecondary,
                    ),
                    tooltip: 'Visualização em Cards',
                    onPressed: () => setState(() => _modoVisualizacao = 'cards'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            TFButton(
              label: 'Reportar Item',
              leadingIcon: Icons.add_rounded,
              onPressed: () => _openForm(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFiltrosBar(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final isMobile = TFBreakpoints.isMobile(context);

    if (!isMobile) {
      // Desktop: busca flexível e dropdowns compactos na mesma linha
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TFTextField(
                    controller: _searchController,
                    hint: 'Buscar por título ou descrição...',
                    prefixIcon: Icon(Icons.search, color: colors.textSecondary, size: 20),
                    suffixIcon: _searchTerm.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: colors.textSecondary, size: 18),
                            tooltip: 'Limpar busca',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchTerm = '');
                            },
                          )
                        : null,
                    onChanged: (val) => setState(() => _searchTerm = val),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 160,
                  child: TFDropdown<String?>(
                    label: 'Tipo',
                    value: _filtroTipo,
                    items: const [null, kTipoBug, kTipoMelhoria],
                    displayText: (v) {
                      if (v == null) return 'Todos os Tipos';
                      return v == kTipoBug ? 'Bugs' : 'Melhorias';
                    },
                    onChanged: (v) {
                      setState(() => _filtroTipo = v);
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 180,
                  child: TFDropdown<String?>(
                    label: 'Status',
                    value: _filtroStatus,
                    items: [null, ...kMelhoriasBugsStatusCodes],
                    displayText: (v) {
                      if (v == null) return 'Todos os Status';
                      return melhoriaBugStatusLabel(v);
                    },
                    onChanged: (v) {
                      setState(() => _filtroStatus = v);
                      _load();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    label: 'Apenas Ativos',
                    selected: _apenasAtivos,
                    selectedColor: colors.primary,
                    onSelected: (v) {
                      setState(() => _apenasAtivos = v);
                      _load();
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    label: 'Sem Prazo',
                    selected: _filtroPrazo == 'sem_prazo',
                    selectedColor: colors.warning,
                    onSelected: (v) => setState(() => _filtroPrazo = v ? 'sem_prazo' : null),
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    label: 'Vencidos',
                    selected: _filtroPrazo == 'vencidos',
                    selectedColor: colors.danger,
                    onSelected: (v) => setState(() => _filtroPrazo = v ? 'vencidos' : null),
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    label: 'Vencendo em breve',
                    selected: _filtroPrazo == 'proximos',
                    selectedColor: colors.info,
                    onSelected: (v) => setState(() => _filtroPrazo = v ? 'proximos' : null),
                  ),
                  if (_searchTerm.isNotEmpty ||
                      _filtroTipo != null ||
                      _filtroStatus != null ||
                      _filtroPrazo != null) ...[
                    const SizedBox(width: 12),
                    TextButton.icon(
                      icon: const Icon(Icons.filter_alt_off_outlined, size: 15),
                      label: const Text('Limpar Filtros'),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.textSecondary,
                        textStyle: typography.caption.copyWith(fontWeight: FontWeight.bold),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchTerm = '';
                          _filtroTipo = null;
                          _filtroStatus = null;
                          _filtroPrazo = null;
                          _apenasAtivos = true;
                        });
                        _load();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Mobile: vertical e organizado com scroll horizontal para chips
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TFTextField(
            controller: _searchController,
            hint: 'Buscar por título ou descrição...',
            prefixIcon: Icon(Icons.search, color: colors.textSecondary, size: 20),
            suffixIcon: _searchTerm.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: colors.textSecondary, size: 18),
                    tooltip: 'Limpar busca',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchTerm = '');
                    },
                  )
                : null,
            onChanged: (val) => setState(() => _searchTerm = val),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TFDropdown<String?>(
                  label: 'Tipo',
                  value: _filtroTipo,
                  items: const [null, kTipoBug, kTipoMelhoria],
                  displayText: (v) {
                    if (v == null) return 'Todos os Tipos';
                    return v == kTipoBug ? 'Bugs' : 'Melhorias';
                  },
                  onChanged: (v) {
                    setState(() => _filtroTipo = v);
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TFDropdown<String?>(
                  label: 'Status',
                  value: _filtroStatus,
                  items: [null, ...kMelhoriasBugsStatusCodes],
                  displayText: (v) {
                    if (v == null) return 'Todos os Status';
                    return melhoriaBugStatusLabel(v);
                  },
                  onChanged: (v) {
                    setState(() => _filtroStatus = v);
                    _load();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'Apenas Ativos',
                  selected: _apenasAtivos,
                  selectedColor: colors.primary,
                  onSelected: (v) {
                    setState(() => _apenasAtivos = v);
                    _load();
                  },
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  label: 'Sem Prazo',
                  selected: _filtroPrazo == 'sem_prazo',
                  selectedColor: colors.warning,
                  onSelected: (v) => setState(() => _filtroPrazo = v ? 'sem_prazo' : null),
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  label: 'Vencidos',
                  selected: _filtroPrazo == 'vencidos',
                  selectedColor: colors.danger,
                  onSelected: (v) => setState(() => _filtroPrazo = v ? 'vencidos' : null),
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  label: 'Vencendo logo',
                  selected: _filtroPrazo == 'proximos',
                  selectedColor: colors.info,
                  onSelected: (v) => setState(() => _filtroPrazo = v ? 'proximos' : null),
                ),
                if (_searchTerm.isNotEmpty ||
                    _filtroTipo != null ||
                    _filtroStatus != null ||
                    _filtroPrazo != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: colors.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchTerm = '';
                        _filtroTipo = null;
                        _filtroStatus = null;
                        _filtroPrazo = null;
                        _apenasAtivos = true;
                      });
                      _load();
                    },
                    child: const Text('Limpar', style: TextStyle(fontSize: 12)),
                  ),
                ],
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
    required Color selectedColor,
    required ValueChanged<bool> onSelected,
  }) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return FilterChip(
      label: Text(label),
      selected: selected,
      selectedColor: selectedColor.withValues(alpha: 0.15),
      checkmarkColor: selectedColor,
      visualDensity: VisualDensity.compact,
      labelStyle: typography.caption.copyWith(
        color: selected ? selectedColor : colors.textSecondary,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      onSelected: onSelected,
    );
  }

  List<TFDataColumn<MelhoriaBug>> _buildTableColumns(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return [
      TFDataColumn<MelhoriaBug>(
        id: 'tipo',
        label: const Text('Tipo'),
        width: 100,
        cellBuilder: (ctx, item) {
          final isBug = item.tipo == kTipoBug;
          return TFStatusBadge(
            label: isBug ? 'BUG' : 'MELHORIA',
            severity: isBug ? TFStatusSeverity.danger : TFStatusSeverity.info,
            icon: isBug ? Icons.bug_report_outlined : Icons.lightbulb_outline,
            compact: true,
          );
        },
      ),
      TFDataColumn<MelhoriaBug>(
        id: 'prioridade',
        label: const Text('Prioridade'),
        width: 100,
        cellBuilder: (ctx, item) {
          if (item.prioridade == null || item.prioridade!.isEmpty) {
            return Text('—', style: typography.caption.copyWith(color: colors.textMuted));
          }
          final p = item.prioridade!;
          final severity = p == 'CRITICA'
              ? TFStatusSeverity.danger
              : p == 'ALTA'
                  ? TFStatusSeverity.warning
                  : p == 'MEDIA'
                      ? TFStatusSeverity.info
                      : TFStatusSeverity.neutral;
          final label = p == 'CRITICA'
              ? 'Crítica'
              : p == 'ALTA'
                  ? 'Alta'
                  : p == 'MEDIA'
                      ? 'Média'
                      : 'Baixa';
          return TFStatusBadge(label: label, severity: severity, compact: true);
        },
      ),
      TFDataColumn<MelhoriaBug>(
        id: 'titulo',
        label: const Text('Solicitação'),
        cellBuilder: (ctx, item) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.titulo,
                style: typography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (item.descricao != null && item.descricao!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  item.descricao!,
                  style: typography.caption.copyWith(color: colors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          );
        },
      ),
      TFDataColumn<MelhoriaBug>(
        id: 'status',
        label: const Text('Status'),
        width: 130,
        cellBuilder: (ctx, item) {
          TFStatusSeverity sev;
          switch (item.status) {
            case 'BACKLOG':
              sev = TFStatusSeverity.neutral;
              break;
            case 'ANALISE':
              sev = TFStatusSeverity.info;
              break;
            case 'DESENVOLVIMENTO':
            case 'VALIDACAO':
              sev = TFStatusSeverity.warning;
              break;
            case 'CONCLUIDO':
              sev = TFStatusSeverity.success;
              break;
            case 'REABERTO':
            case 'REJEITADO':
              sev = TFStatusSeverity.danger;
              break;
            default:
              sev = TFStatusSeverity.neutral;
          }
          return TFStatusBadge(
            label: item.statusLabel,
            severity: sev,
            compact: true,
          );
        },
      ),
      TFDataColumn<MelhoriaBug>(
        id: 'prazo',
        label: const Text('Prazo'),
        width: 130,
        cellBuilder: (ctx, item) {
          if (item.prazo == null) {
            if (item.isAberta) {
              return const TFStatusBadge(
                label: 'Sem prazo',
                severity: TFStatusSeverity.neutral,
                icon: Icons.calendar_today_outlined,
                compact: true,
              );
            }
            return Text('—', style: typography.caption.copyWith(color: colors.textMuted));
          }
          if (item.isPrazoVencido) {
            final dias = item.diasRestantesPrazo?.abs() ?? 0;
            return TFStatusBadge(
              label: dias == 0 ? 'Hoje' : '${dias}d atrás',
              severity: TFStatusSeverity.danger,
              icon: Icons.error_outline_rounded,
              compact: true,
            );
          }
          if (item.isPrazoProximo) {
            final dias = item.diasRestantesPrazo ?? 0;
            final txt = dias == 0 ? 'Hoje' : dias == 1 ? 'Amanhã' : 'Em ${dias}d';
            return TFStatusBadge(
              label: txt,
              severity: TFStatusSeverity.warning,
              icon: Icons.access_time_rounded,
              compact: true,
            );
          }
          return Text(
            DateFormat('dd/MM/yyyy').format(item.prazo!),
            style: typography.bodySmall.copyWith(color: colors.textSecondary),
          );
        },
      ),
      TFDataColumn<MelhoriaBug>(
        id: 'autor',
        label: const Text('Criado por'),
        width: 130,
        cellBuilder: (ctx, item) {
          if (item.createdBy == null || item.createdBy!.isEmpty) {
            return Text('—', style: typography.caption.copyWith(color: colors.textMuted));
          }
          return Text(
            item.createdBy!,
            style: typography.caption.copyWith(color: colors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        },
      ),
      TFDataColumn<MelhoriaBug>(
        id: 'acoes',
        label: const Text('Ações'),
        width: 70,
        alignment: Alignment.center,
        cellBuilder: (ctx, item) {
          return IconButton(
            icon: Icon(Icons.edit_outlined, size: 18, color: colors.primary),
            tooltip: 'Visualizar / Editar',
            onPressed: () => _openForm(item),
          );
        },
      ),
    ];
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: TFEmptyState(
        icon: _searchTerm.isNotEmpty ? Icons.search_off_rounded : Icons.inbox_outlined,
        title: _searchTerm.isNotEmpty
            ? 'Nenhum resultado encontrado'
            : 'Nenhum item registrado',
        description: _searchTerm.isNotEmpty
            ? 'Nenhum item corresponde ao termo "$_searchTerm".'
            : 'Não há solicitações ou bugs para os filtros selecionados.',
        action: TFButton(
          label: _searchTerm.isNotEmpty ? 'Limpar Busca' : 'Reportar Item',
          variant: TFButtonVariant.secondary,
          onPressed: _searchTerm.isNotEmpty
              ? () {
                  _searchController.clear();
                  setState(() => _searchTerm = '');
                }
              : () => _openForm(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final isMobile = TFBreakpoints.isMobile(context);
    final displayItems = _filteredItems;

    return Scaffold(
      backgroundColor: colors.background,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. Cabeçalho Principal Compacto
            SliverToBoxAdapter(
              child: _buildHeader(context),
            ),

            // 2. Banner de Alertas do Programador (discreto e minimizável)
            SliverToBoxAdapter(
              child: _buildProgramadorAlertBanner(context),
            ),

            // 3. Indicadores / Métricas (colapsáveis)
            if (_mostrarMetricas)
              SliverToBoxAdapter(
                child: _buildMetricasPanel(context),
              ),

            // 4. Barra de Busca e Filtros
            SliverToBoxAdapter(
              child: _buildFiltrosBar(context),
            ),

            // 5. Lista de Solicitações (O Conteúdo Mais Importante!)
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: TFLoading(message: 'Carregando melhorias e bugs...')),
              )
            else if (displayItems.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(context),
              )
            else if (_modoVisualizacao == 'tabela' && !isMobile)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  child: TFDataTable<MelhoriaBug>(
                    columns: _buildTableColumns(context),
                    items: displayItems,
                    zebra: true,
                    densityMode: TFDensityMode.compact,
                    onRowTap: (item) => _openForm(item),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, idx) {
                      final item = displayItems[idx];
                      return MelhoriaBugCard(
                        item: item,
                        onTap: () => _openForm(item),
                        onEdit: () => _openForm(item),
                      );
                    },
                    childCount: displayItems.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: isMobile
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              backgroundColor: colors.primary,
              foregroundColor: colors.primaryForeground,
              label: const Text('Reportar'),
              icon: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }
}
