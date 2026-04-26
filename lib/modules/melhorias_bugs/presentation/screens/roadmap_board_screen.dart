import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
          SnackBar(content: Text('Erro ao carregar: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Roadmap do Sistema'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _versoes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_outlined, size: 64, color: theme.colorScheme.onSurface.withOpacity(0.2)),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhuma versão no roadmap',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => _openVersaoForm(),
                        icon: const Icon(Icons.add),
                        label: const Text('Criar primeira versão'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _versoes.length,
                    itemBuilder: (context, index) {
                      final v = _versoes[index];
                      final itens = _itensPorVersao[v.id] ?? [];
                      final total = itens.length;
                      final concluidos = itens.where((i) => i.status == 'CONCLUIDO').length;
                      final progresso = total > 0 ? (concluidos / total) : 0.0;
                      final dataPrev = v.dataPrevistaLancamento != null
                          ? DateFormat('dd MMM yyyy').format(v.dataPrevistaLancamento!)
                          : 'A definir';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: InkWell(
                          onTap: () => _openVersaoDetail(v),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
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
                                            style: theme.textTheme.titleLarge?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.event_outlined, size: 14, color: theme.colorScheme.primary),
                                              const SizedBox(width: 4),
                                              Text(
                                                dataPrev,
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: theme.colorScheme.primary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.edit_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
                                      onPressed: () => _openVersaoForm(v),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                                if (v.descricao != null && v.descricao!.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    v.descricao!,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Progresso',
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      '${(progresso * 100).toInt()}%',
                                      style: theme.textTheme.labelLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Stack(
                                  children: [
                                    Container(
                                      height: 10,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: progresso,
                                      child: Container(
                                        height: 10,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              theme.colorScheme.primary,
                                              theme.colorScheme.primary.withOpacity(0.7),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(5),
                                          boxShadow: [
                                            BoxShadow(
                                              color: theme.colorScheme.primary.withOpacity(0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    _buildMiniStat(Icons.check_circle_outline, '$concluidos concluídos', Colors.green),
                                    const SizedBox(width: 16),
                                    _buildMiniStat(Icons.pending_actions, '${total - concluidos} pendentes', Colors.orange),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openVersaoForm(),
        label: const Text('Nova Versão'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
