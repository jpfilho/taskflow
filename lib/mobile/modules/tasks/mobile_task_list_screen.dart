import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/task.dart';
import '../../../services/task_service.dart';
import '../../core/theme/tf_mobile_spacing.dart';
import '../../core/theme/tf_mobile_typography.dart';
import '../../core/theme/tf_mobile_colors.dart';
import '../../core/widgets/tf_mobile_filter_sheet.dart';
import '../../core/widgets/tf_mobile_states.dart';
import '../../core/navigation/tf_mobile_navigator.dart';
import 'adapters/mobile_task_adapter.dart';
import 'widgets/mobile_task_card.dart';

/// Tela operacional de lista de atividades para smartphones.
/// Substitui tabelas desktop por cartões verticais ergonômicos, com busca debounced (300ms),
/// chips rápidos de filtro, paginação lazy e atualização in-place de estado.
class MobileTaskListScreen extends StatefulWidget {
  final TFMobileNavigator? navigator;
  final List<Task>? initialTasks;

  const MobileTaskListScreen({
    super.key,
    this.navigator,
    this.initialTasks,
  });

  @override
  State<MobileTaskListScreen> createState() => _MobileTaskListScreenState();
}

class _MobileTaskListScreenState extends State<MobileTaskListScreen> {
  final TaskService _taskService = TaskService();
  final MobileTaskAdapter _adapter = MobileTaskAdapter();

  List<Task> _allTasks = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  Timer? _debounceTimer;

  String _quickFilter = 'todas'; // 'todas', 'hoje', 'execucao', 'pendente', 'concluido'
  final Set<String> _advancedFilters = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialTasks != null) {
      _allTasks = widget.initialTasks!;
      _isLoading = false;
    } else {
      _loadTasks();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tasks = await _taskService.getAllTasks();
      if (!mounted) return;
      setState(() {
        _allTasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Falha ao carregar atividades: $e';
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = query.trim();
        });
      }
    });
  }

  void _setQuickFilter(String filter) {
    HapticFeedback.selectionClick();
    setState(() {
      _quickFilter = filter;
    });
  }

  Future<void> _openDetail(Task task) async {
    final nav = widget.navigator ?? TFMobileNavigator(context: context);
    final updated = await nav.openTaskDetail(
      task.id,
      taskTitle: task.tarefa,
      initialTask: task,
    );

    if (updated is Task && mounted) {
      // Atualização in-place no cache local sem reconstruir a lista do zero
      setState(() {
        final idx = _allTasks.indexWhere((t) => t.id == updated.id);
        if (idx != -1) {
          _allTasks[idx] = updated;
        }
      });
    }
  }

  List<Task> _applyFilters() {
    return _allTasks.where((task) {
      // 1. Filtro de Busca com campos reais
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final title = task.tarefa.toLowerCase();
        final local = task.locais.join(' ').toLowerCase();
        final executor = task.executores.join(' ').toLowerCase();
        final si = task.si.toLowerCase();
        final ordem = task.ordem?.toLowerCase() ?? '';

        final matches = title.contains(q) ||
            local.contains(q) ||
            executor.contains(q) ||
            si.contains(q) ||
            ordem.contains(q);

        if (!matches) return false;
      }

      final s = task.status.toUpperCase().trim();

      // 2. Chips Rápidos
      if (_quickFilter == 'hoje') {
        final now = DateTime.now();
        final isToday = task.dataInicio.year == now.year &&
            task.dataInicio.month == now.month &&
            task.dataInicio.day == now.day;
        if (!isToday) return false;
      } else if (_quickFilter == 'execucao') {
        if (s != 'ANDA') return false;
      } else if (_quickFilter == 'pendente') {
        if (s != 'PROG' && s != 'RPAR' && s != 'RPGR') return false;
      } else if (_quickFilter == 'concluido') {
        if (s != 'CONC') return false;
      }

      // 3. Filtros Avançados
      if (_advancedFilters.isNotEmpty) {
        if (_advancedFilters.contains('alta')) {
          final p = task.prioridade?.toUpperCase() ?? '';
          if (!p.contains('ALTA')) return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: TFMobileColors.background(context),
      body: Column(
        children: [
          // 1. Barra de Busca e Filtro Avançado
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: TFMobileSpacing.lg,
              vertical: TFMobileSpacing.sm,
            ),
            color: TFMobileColors.surface(context),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Buscar por atividade, local ou OS...',
                      hintStyle: TFMobileTypography.bodyMedium.copyWith(color: Colors.grey.shade500),
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: TFMobileSpacing.md,
                        vertical: 10.0,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: TFMobileColors.border(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: TFMobileColors.border(context)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: TFMobileSpacing.sm),
                // Botão de Filtro Avançado
                Container(
                  width: 48.0,
                  height: 48.0,
                  decoration: BoxDecoration(
                    border: Border.all(color: TFMobileColors.border(context)),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.tune_rounded),
                    color: _advancedFilters.isNotEmpty
                        ? TFMobileColors.primaryBlue
                        : TFMobileColors.textSecondary(context),
                    tooltip: 'Filtrar Atividades',
                    onPressed: () {
                      TFMobileFilterSheet.show(
                        context: context,
                        title: 'Filtros Avançados',
                        options: const [
                          TFFilterOption(id: 'alta', label: 'Prioridade Alta'),
                        ],
                        initialSelectedIds: _advancedFilters,
                        onApply: (sel) {
                          setState(() {
                            _advancedFilters.clear();
                            _advancedFilters.addAll(sel);
                          });
                        },
                        onClear: () {
                          setState(() {
                            _advancedFilters.clear();
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: TFMobileSpacing.xs),
                // Botão de Agenda / Programação Diária (Fase 4)
                Container(
                  width: 48.0,
                  height: 48.0,
                  decoration: BoxDecoration(
                    border: Border.all(color: TFMobileColors.border(context)),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.calendar_month_rounded),
                    color: TFMobileColors.primaryBlue,
                    tooltip: 'Ver Agenda Diária',
                    onPressed: () {
                      if (widget.navigator != null) {
                        widget.navigator!.openSchedule();
                      } else {
                        TFMobileNavigator(context: context).openSchedule();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // 2. Chips Rápidos de Filtro
          Container(
            height: 48.0,
            padding: const EdgeInsets.symmetric(horizontal: TFMobileSpacing.lg),
            color: TFMobileColors.surface(context),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildChip('todas', 'Todas'),
                _buildChip('hoje', 'Hoje'),
                _buildChip('execucao', 'Em Execução'),
                _buildChip('pendente', 'Pendentes'),
                _buildChip('concluido', 'Concluídas'),
              ],
            ),
          ),
          const Divider(height: 1.0),

          // 3. Lista de Cards com Lazy Loading
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadTasks,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String id, String label) {
    final isSelected = _quickFilter == id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: TFMobileSpacing.sm, top: 8.0, bottom: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _setQuickFilter(id),
        selectedColor: const Color(0xFF3B82F6),
        checkmarkColor: Colors.white,
        labelStyle: TFMobileTypography.caption.copyWith(
          color: isSelected
              ? Colors.white
              : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const TFLoadingState(message: 'Carregando lista de atividades...');
    }

    if (_errorMessage != null) {
      return TFErrorState(
        title: 'Erro ao carregar atividades',
        description: _errorMessage!,
        onRetry: _loadTasks,
      );
    }

    final filtered = _applyFilters();

    if (filtered.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return TFNoResultsState(
          query: _searchQuery,
          onClear: () {
            setState(() => _searchQuery = '');
          },
        );
      }
      return TFEmptyState(
        title: 'Nenhuma atividade encontrada',
        description: 'Não existem atividades correspondentes aos filtros selecionados.',
        icon: Icons.assignment_turned_in_outlined,
        actionLabel: 'Recarregar',
        onAction: _loadTasks,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(TFMobileSpacing.lg),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final task = filtered[index];
        final vm = _adapter.toViewModel(task);

        return MobileTaskCard(
          task: vm,
          onTap: () => _openDetail(task),
          onPrimaryAction: () => _openDetail(task),
        );
      },
    );
  }
}
