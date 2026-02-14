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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_versoes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Nenhuma versão no roadmap',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _openVersaoForm(),
              icon: const Icon(Icons.add),
              label: const Text('Criar primeira versão'),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _versoes.length,
          itemBuilder: (context, index) {
          final v = _versoes[index];
          final itens = _itensPorVersao[v.id] ?? [];
          final total = itens.length;
          final concluidos = itens.where((i) => i.status == 'CONCLUIDO').length;
          final progresso = total > 0 ? (concluidos / total) : 0.0;
          final dataPrev = v.dataPrevistaLancamento != null
              ? DateFormat('dd/MM/yyyy').format(v.dataPrevistaLancamento!)
              : '—';
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => _openVersaoDetail(v),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            v.nome,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _openVersaoForm(v),
                        ),
                      ],
                    ),
                    if (v.descricao != null && v.descricao!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          v.descricao!,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text('Previsto: $dataPrev', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                        const SizedBox(width: 16),
                        Text(
                          '$concluidos / $total itens',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progresso,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openVersaoForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
