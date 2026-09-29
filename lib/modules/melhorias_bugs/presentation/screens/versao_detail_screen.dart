import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../design_system/taskflow_design_system.dart';
import '../../../../models/versao.dart';
import '../../../../models/melhoria_bug.dart';
import '../../../../services/melhorias_bugs_service.dart';
import '../widgets/melhoria_bug_card.dart';
import '../widgets/melhoria_bug_form_dialog.dart';

class VersaoDetailScreen extends StatefulWidget {
  final Versao versao;
  final VoidCallback? onChanged;

  const VersaoDetailScreen({
    super.key,
    required this.versao,
    this.onChanged,
  });

  @override
  State<VersaoDetailScreen> createState() => _VersaoDetailScreenState();
}

class _VersaoDetailScreenState extends State<VersaoDetailScreen> {
  final MelhoriasBugsService _service = MelhoriasBugsService();
  final ScrollController _scrollController = ScrollController();
  List<MelhoriaBug> _items = [];
  List<Versao> _versoes = [];
  bool _loading = true;

  Versao get versao => widget.versao;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final versoes = await _service.getVersoes();
      final items = await _service.getMelhoriasBugs(
        versaoId: versao.id,
        ativosApenas: false,
      );
      if (mounted) {
        setState(() {
          _versoes = versoes;
          _items = items;
          _loading = false;
        });
        widget.onChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar itens da versão: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _openForm([MelhoriaBug? item]) async {
    final result = await showDialog<MelhoriaBug>(
      context: context,
      builder: (ctx) => MelhoriaBugFormDialog(
        initial: item ??
            MelhoriaBug(
              id: '',
              tipo: kTipoMelhoria,
              titulo: '',
              status: 'BACKLOG',
              versaoId: versao.id,
            ),
        versoes: _versoes,
        onSave: (mb) => _service.saveMelhoriaBug(mb),
      ),
    );
    if (result != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final isMobile = TFBreakpoints.isMobile(context);

    final total = _items.length;
    final concluidos = _items.where((i) => i.status == 'CONCLUIDO').length;
    final progresso = total > 0 ? (concluidos / total) : 0.0;
    final dataPrev = versao.dataPrevistaLancamento != null
        ? DateFormat('dd/MM/yyyy').format(versao.dataPrevistaLancamento!)
        : 'Não definida';

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
                  tooltip: 'Voltar',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        versao.nome,
                        style: typography.pageTitle.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Detalhes da versão e itens vinculados',
                        style: typography.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isMobile)
                  TFButton(
                    label: 'Novo Item',
                    leadingIcon: Icons.add_rounded,
                    onPressed: () => _openForm(),
                  ),
              ],
            ),
          ),

          // Conteúdo
          Expanded(
            child: _loading
                ? const Center(child: TFLoading(message: 'Carregando detalhes da versão...'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        // Card de Resumo da Versão
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            child: TFCard(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (versao.descricao != null &&
                                      versao.descricao!.isNotEmpty) ...[
                                    Text(
                                      versao.descricao!,
                                      style: typography.bodyLarge.copyWith(
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Progresso Geral',
                                            style: typography.labelMedium.copyWith(
                                              color: colors.textSecondary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${(progresso * 100).toInt()}% Concluído',
                                            style: typography.sectionTitle.copyWith(
                                              color: colors.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Previsão de Entrega',
                                            style: typography.labelMedium.copyWith(
                                              color: colors.textSecondary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            dataPrev,
                                            style: typography.sectionTitle.copyWith(
                                              color: colors.textPrimary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  ClipRRect(
                                    borderRadius: TFRadius.borderRadiusSm,
                                    child: LinearProgressIndicator(
                                      value: progresso,
                                      minHeight: 8,
                                      backgroundColor: colors.borderSubtle,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        progresso == 1.0 ? colors.success : colors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      TFStatusBadge(
                                        label: '$concluidos concluídos',
                                        severity: TFStatusSeverity.success,
                                        icon: Icons.check_circle_outline,
                                        compact: true,
                                      ),
                                      const SizedBox(width: 8),
                                      TFStatusBadge(
                                        label: '${total - concluidos} pendentes',
                                        severity: TFStatusSeverity.warning,
                                        icon: Icons.pending_actions_outlined,
                                        compact: true,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Título da Seção
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                Text(
                                  'ITENS DESTA VERSÃO',
                                  style: typography.labelSmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    color: colors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceSecondary,
                                    borderRadius: TFRadius.borderRadiusFull,
                                    border: Border.all(color: colors.borderSubtle),
                                  ),
                                  child: Text(
                                    total.toString(),
                                    style: typography.micro.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Lista de Itens
                        if (_items.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: TFEmptyState(
                                icon: Icons.assignment_outlined,
                                title: 'Nenhum item vinculado',
                                description:
                                    'Esta versão ainda não possui solicitações ou correções associadas.',
                                action: TFButton(
                                  label: 'Adicionar Item',
                                  leadingIcon: Icons.add_rounded,
                                  onPressed: () => _openForm(),
                                ),
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final item = _items[index];
                                  return MelhoriaBugCard(
                                    item: item,
                                    onTap: () => _openForm(item),
                                    onEdit: () => _openForm(item),
                                  );
                                },
                                childCount: _items.length,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: isMobile
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              backgroundColor: colors.primary,
              foregroundColor: colors.primaryForeground,
              label: const Text('Novo Item'),
              icon: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }
}
