import 'package:flutter/material.dart';

import '../../data/models/gtd_models.dart';
import '../../domain/usecases/gtd_actions_usecase.dart';
import '../../domain/usecases/gtd_inbox_usecase.dart';
import '../../domain/usecases/gtd_projects_usecase.dart';
import '../widgets/gtd_card.dart';

/// Painel visual de acompanhamento GTD: contagens, projetos e progresso.
class GtdPanelTab extends StatefulWidget {
  /// Índice das abas: 0=Painel, 1=Capturar, 2=Processar, 3=Agora, 4=Algum dia, 5=Em andamento, 6=Projetos, 7=Revisão.
  final void Function(int tabIndex)? onGoToTab;
  /// Controller das abas: usado para recarregar quando esta aba fica visível.
  final TabController? tabController;

  const GtdPanelTab({super.key, this.onGoToTab, this.tabController});

  @override
  State<GtdPanelTab> createState() => _GtdPanelTabState();
}

class _GtdPanelTabState extends State<GtdPanelTab> {
  final _inboxUseCase = GtdInboxUseCase();
  final _actionsUseCase = GtdActionsUseCase();
  final _projectsUseCase = GtdProjectsUseCase();

  int _inboxCount = 0;
  int _agoraCount = 0;
  int _aguardandoCount = 0;
  int _somedayCount = 0;
  int _andamentoCount = 0;
  List<GtdProject> _projects = [];
  Map<String, ({int done, int total})> _progress = {};
  bool _loading = true;

  static const int _panelTabIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.tabController?.addListener(_onTabChanged);
    // Carregar após o primeiro frame e um breve delay para o DB local estar pronto após o sync.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      if (widget.tabController == null || widget.tabController!.index == _panelTabIndex) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    widget.tabController?.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (!mounted) return;
    if (widget.tabController?.index == _panelTabIndex) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final unprocessed = await _inboxUseCase.getInboxItems(unprocessedOnly: true);
      final next = await _actionsUseCase.getNextActions();
      final waiting = await _actionsUseCase.getWaitingActions();
      final someday = await _actionsUseCase.getSomedayActions();
      final withAndamento = await _actionsUseCase.getActionsWithAndamento();
      final projects = await _projectsUseCase.getProjects();
      final progress = await _projectsUseCase.getProjectProgress();
      if (!mounted) return;
      setState(() {
        _inboxCount = unprocessed.length;
        _agoraCount = next.length;
        _aguardandoCount = waiting.length;
        _somedayCount = someday.length;
        _andamentoCount = withAndamento.length;
        _projects = projects;
        _progress = progress;
        _loading = false;
      });
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _loading = false);
      debugPrint('GtdPanelTab _load error: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Acompanhamento GTD',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            // Cards de contagem (linha compacta)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatCard(
                  icon: Icons.inbox_rounded,
                  label: 'Inbox',
                  count: _inboxCount,
                  color: Colors.orange,
                  onTap: widget.onGoToTab != null
                      ? () => widget.onGoToTab!(1)
                      : null,
                ),
                _StatCard(
                  icon: Icons.play_circle_fill_rounded,
                  label: 'Agora',
                  count: _agoraCount,
                  color: Colors.blue,
                  onTap: widget.onGoToTab != null
                      ? () => widget.onGoToTab!(3)
                      : null,
                ),
                _StatCard(
                  icon: Icons.person_outline_rounded,
                  label: 'Aguardando',
                  count: _aguardandoCount,
                  color: Colors.purple,
                  onTap: widget.onGoToTab != null
                      ? () => widget.onGoToTab!(3)
                      : null,
                ),
                _StatCard(
                  icon: Icons.schedule_rounded,
                  label: 'Algum dia',
                  count: _somedayCount,
                  color: Colors.teal,
                  onTap: widget.onGoToTab != null
                      ? () => widget.onGoToTab!(4)
                      : null,
                ),
                _StatCard(
                  icon: Icons.note_alt_outlined,
                  label: 'Em andamento',
                  count: _andamentoCount,
                  color: Colors.amber,
                  onTap: widget.onGoToTab != null
                      ? () => widget.onGoToTab!(5)
                      : null,
                ),
              ],
            ),
            if (_inboxCount == 0 &&
                _agoraCount == 0 &&
                _aguardandoCount == 0 &&
                _somedayCount == 0 &&
                _andamentoCount == 0 &&
                _projects.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Puxe para baixo para atualizar os números.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            // Projetos e progresso
            Text(
              'Projetos',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            if (_projects.isEmpty)
              GtdCard(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_open_rounded,
                          size: 48,
                          color: colorScheme.outline,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nenhum projeto ainda',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (widget.onGoToTab != null) ...[
                          const SizedBox(height: 12),
                          FilledButton.tonalIcon(
                            onPressed: () => widget.onGoToTab!(6),
                            icon: const Icon(Icons.add, size: 20),
                            label: const Text('Ir para Projetos'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )
            else
              ..._projects.map((p) {
                final prog = _progress[p.id];
                final done = prog?.done ?? 0;
                final total = prog?.total ?? 0;
                final pct = total > 0 ? (done / total).clamp(0.0, 1.0) : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GtdCard(
                    onTap: widget.onGoToTab != null
                        ? () => widget.onGoToTab!(6)
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.folder_rounded,
                              size: 20,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                p.name,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '$done / $total',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 6,
                            backgroundColor: colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              pct >= 1.0
                                  ? Colors.green
                                  : colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 24),
            // Atalhos rápidos
            if (widget.onGoToTab != null) ...[
              Text(
                'Atalhos',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ChipAction(
                    icon: Icons.add_circle_outline,
                    label: 'Capturar',
                    onTap: () => widget.onGoToTab!(1),
                  ),
                  _ChipAction(
                    icon: Icons.tune,
                    label: 'Processar',
                    onTap: () => widget.onGoToTab!(2),
                  ),
                  _ChipAction(
                    icon: Icons.calendar_view_week,
                    label: 'Revisão semanal',
                    onTap: () => widget.onGoToTab!(7),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withValues(alpha: 0.25),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, size: 14, color: color.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ChipAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ActionChip(
      avatar: Icon(icon, size: 18, color: theme.colorScheme.primary),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
