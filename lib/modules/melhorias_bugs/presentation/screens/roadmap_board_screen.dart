import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../design_system/taskflow_design_system.dart';
import '../../../../models/versao.dart';
import '../../../../models/melhoria_bug.dart';
import '../../../../services/melhorias_bugs_service.dart';
import 'versao_detail_screen.dart';
import '../widgets/versao_form_dialog.dart';

class RoadmapBoardScreen extends StatefulWidget {
  const RoadmapBoardScreen({super.key});

  @override
  State<RoadmapBoardScreen> createState() => _RoadmapBoardScreenState();
}

class _RoadmapBoardScreenState extends State<RoadmapBoardScreen> {
  final MelhoriasBugsService _service = MelhoriasBugsService();
  final ScrollController _scrollController = ScrollController();
  List<Versao> _versoes = [];
  Map<String, List<MelhoriaBug>> _itensPorVersao = {};
  bool _loading = true;

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
      final map = <String, List<MelhoriaBug>>{};
      for (final v in versoes) {
        final itens = await _service.getMelhoriasBugs(versaoId: v.id, ativosApenas: false);
        map[v.id] = itens;
      }
      if (mounted) {
        setState(() {
          _versoes = versoes;
          _itensPorVersao = map;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar roadmap: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _openVersaoForm([Versao? v]) async {
    final result = await showDialog<Versao>(
      context: context,
      builder: (ctx) => VersaoFormDialog(
        initial: v,
        onSave: (versao) => _service.saveVersao(versao),
      ),
    );
    if (result != null) _load();
  }

  void _openVersaoDetail(Versao v) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => VersaoDetailScreen(versao: v, onChanged: _load),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final isMobile = TFBreakpoints.isMobile(context);

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Roadmap de Lançamentos',
                        style: typography.pageTitle.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Acompanhe o cronograma de releases e entregas do TaskFlow.',
                        style: typography.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isMobile)
                  TFButton(
                    label: 'Nova Versão',
                    leadingIcon: Icons.add_rounded,
                    onPressed: () => _openVersaoForm(),
                  ),
              ],
            ),
          ),

          // Conteúdo
          Expanded(
            child: _loading
                ? const Center(child: TFLoading(message: 'Carregando roadmap do sistema...'))
                : _versoes.isEmpty
                    ? Center(
                        child: TFEmptyState(
                          icon: Icons.map_outlined,
                          title: 'Nenhuma versão no roadmap',
                          description: 'Cadastre a primeira versão para organizar o plano de releases do sistema.',
                          action: TFButton(
                            label: 'Criar Versão',
                            leadingIcon: Icons.add_rounded,
                            onPressed: () => _openVersaoForm(),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: _versoes.length,
                          itemBuilder: (context, index) {
                            final v = _versoes[index];
                            final itens = _itensPorVersao[v.id] ?? [];
                            final total = itens.length;
                            final concluidos = itens.where((i) => i.status == 'CONCLUIDO').length;
                            final progresso = total > 0 ? (concluidos / total) : 0.0;
                            final dataPrev = v.dataPrevistaLancamento != null
                                ? DateFormat('dd/MM/yyyy').format(v.dataPrevistaLancamento!)
                                : 'A definir';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TFCard(
                                variant: TFCardVariant.interactive,
                                onTap: () => _openVersaoDetail(v),
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                v.nome,
                                                style: typography.sectionTitle.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: colors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.calendar_today_outlined,
                                                    size: 14,
                                                    color: colors.primary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Previsão: $dataPrev',
                                                    style: typography.bodySmall.copyWith(
                                                      color: colors.primary,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.edit_outlined,
                                            size: 20,
                                            color: colors.textSecondary,
                                          ),
                                          tooltip: 'Editar Versão',
                                          onPressed: () => _openVersaoForm(v),
                                        ),
                                      ],
                                    ),
                                    if (v.descricao != null && v.descricao!.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        v.descricao!,
                                        style: typography.bodyMedium.copyWith(
                                          color: colors.textSecondary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Progresso de Conclusão',
                                          style: typography.labelMedium.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: colors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          '${(progresso * 100).toInt()}%',
                                          style: typography.labelLarge.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: colors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
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
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: isMobile
          ? FloatingActionButton.extended(
              onPressed: () => _openVersaoForm(),
              backgroundColor: colors.primary,
              foregroundColor: colors.primaryForeground,
              label: const Text('Nova Versão'),
              icon: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }
}
