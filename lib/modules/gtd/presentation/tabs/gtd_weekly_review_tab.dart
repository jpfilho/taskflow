import 'package:flutter/material.dart';

import '../../domain/usecases/gtd_weekly_review_usecase.dart';
import '../../domain/usecases/gtd_inbox_usecase.dart';
import '../../domain/usecases/gtd_projects_usecase.dart';
import '../widgets/gtd_card.dart';

/// Aba Revisão semanal: checklist + notas + Concluir revisão.
class GtdWeeklyReviewTab extends StatefulWidget {
  const GtdWeeklyReviewTab({super.key});

  @override
  State<GtdWeeklyReviewTab> createState() => _GtdWeeklyReviewTabState();
}

class _GtdWeeklyReviewTabState extends State<GtdWeeklyReviewTab> {
  final _reviewUseCase = GtdWeeklyReviewUseCase();
  final _inboxUseCase = GtdInboxUseCase();
  final _projectsUseCase = GtdProjectsUseCase();

  final _notesController = TextEditingController();
  final _checklist = <String, bool>{
    'Inbox zerado': false,
    'Projetos revisados': false,
    'Aguardando revisado': false,
    'Algum dia revisado': false,
  };

  @override
  void initState() {
    super.initState();
    _loadChecklist();
  }

  Future<void> _loadChecklist() async {
    final unprocessed = await _inboxUseCase.getInboxItems(
      unprocessedOnly: true,
    );
    final projects = await _projectsUseCase.getProjects();
    setState(() {
      _checklist['Inbox zerado'] = unprocessed.isEmpty;
      _checklist['Projetos revisados'] = projects.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _completeReview() async {
    try {
      await _reviewUseCase.completeReview(notes: _notesController.text);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Revisão registrada.')));
        _notesController.clear();
        setState(() {
          _checklist.updateAll((_, __) => false);
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao salvar revisão.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GtdCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Checklist',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ..._checklist.entries.map(
                  (e) => CheckboxListTile(
                    value: e.value,
                    onChanged: (v) =>
                        setState(() => _checklist[e.key] = v ?? false),
                    title: Text(e.key),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GtdCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Notas da revisão',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Observações desta revisão...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _completeReview,
            icon: const Icon(Icons.check_circle),
            label: const Text('Concluir revisão'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
