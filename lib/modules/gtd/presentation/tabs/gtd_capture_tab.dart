import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/gtd_models.dart';
import '../../domain/gtd_session.dart';
import '../../domain/usecases/gtd_inbox_usecase.dart';
import '../widgets/gtd_card.dart';
import '../widgets/gtd_empty_state.dart';

/// Aba Capturar: campo único grande + lista de itens recentes.
class GtdCaptureTab extends StatefulWidget {
  const GtdCaptureTab({super.key, this.tabController});

  /// Se informado, a lista é recarregada ao exibir esta aba (índice 1).
  final TabController? tabController;

  @override
  State<GtdCaptureTab> createState() => _GtdCaptureTabState();
}

class _GtdCaptureTabState extends State<GtdCaptureTab> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _searchController = TextEditingController();
  final _inboxUseCase = GtdInboxUseCase();
  List<GtdInboxItem> _items = [];
  String _searchQuery = '';
  bool _loading = false;

  static const int _captureTabIndex = 1;

  @override
  void initState() {
    super.initState();
    widget.tabController?.addListener(_onTabChanged);
    _load();
  }

  @override
  void dispose() {
    widget.tabController?.removeListener(_onTabChanged);
    _controller.dispose();
    _focusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!mounted) return;
    if (widget.tabController?.index == _captureTabIndex) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final list = await _inboxUseCase.getInboxItems();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('GTD Capturar _load: $e\n$st');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar lista: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    try {
      await _inboxUseCase.capture(text);
      _controller.clear();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Salvo na caixa de entrada.')),
        );
      }
    } catch (e, st) {
      debugPrint('GTD Capturar erro: $e\n$st');
      if (mounted) {
        final isAuth = e is StateError && e.message.contains('autenticado');
        final message = isAuth
            ? 'Faça login para usar o GTD.'
            : 'Erro: ${e.toString()}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
            duration: const Duration(seconds: 8),
            action: SnackBarAction(label: 'OK', onPressed: () {}),
          ),
        );
      }
    }
  }

  List<GtdInboxItem> get _filteredItems {
    if (_searchQuery.trim().isEmpty) return _items;
    final q = _searchQuery.trim().toLowerCase();
    return _items.where((i) => i.content.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter &&
            !HardwareKeyboard.instance.isShiftPressed) {
          _save();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (GtdSession.currentUserId == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Sessão não encontrada. Faça login novamente para salvar no GTD.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            GtdCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'O que está na sua cabeça?',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    textInputAction: TextInputAction.newline,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    label: const Text('Salvar'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter para salvar',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pesquisar nas capturas...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? const GtdEmptyState(
                          icon: Icons.inbox,
                          title: 'Nada capturado ainda',
                          subtitle: 'Digite acima e salve para começar.',
                        )
                      : _filteredItems.isEmpty
                          ? GtdEmptyState(
                              icon: Icons.search_off,
                              title: 'Nenhum resultado',
                              subtitle: _searchQuery.trim().isEmpty
                                  ? null
                                  : 'Nada encontrado para "$_searchQuery".',
                            )
                          : ListView.separated(
                              itemCount: _filteredItems.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final item = _filteredItems[i];
                                return GtdCard(
                                  padding: const EdgeInsets.all(12),
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      item.processedAt != null
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      color: item.processedAt != null
                                          ? Colors.green
                                          : null,
                                    ),
                                    title: Text(item.content),
                                    subtitle: item.processedAt != null
                                        ? Text(
                                            'Concluído',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          )
                                        : null,
                                    trailing: PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert),
                                      onSelected: (value) async {
                                        if (value == 'conclude') {
                                          if (item.processedAt != null) return;
                                          await _inboxUseCase.markProcessed(item);
                                          await _load();
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text('Captura concluída.'),
                                              ),
                                            );
                                          }
                                          return;
                                        }
                                        if (value == 'edit') {
                                          final ctrl = TextEditingController(
                                            text: item.content,
                                          );
                                          final newContent =
                                              await showDialog<String>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Editar captura'),
                                              content: TextField(
                                                controller: ctrl,
                                                decoration: const InputDecoration(
                                                  labelText: 'Conteúdo',
                                                  border: OutlineInputBorder(),
                                                ),
                                                maxLines: 4,
                                                autofocus: true,
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx),
                                                  child: const Text('Cancelar'),
                                                ),
                                                FilledButton(
                                                  onPressed: () => Navigator.pop(
                                                    ctx,
                                                    ctrl.text.trim(),
                                                  ),
                                                  child: const Text('Salvar'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (newContent != null &&
                                              newContent.isNotEmpty &&
                                              mounted) {
                                            await _inboxUseCase.updateItem(
                                              item,
                                              newContent,
                                            );
                                            await _load();
                                            if (mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Captura atualizada.'),
                                                ),
                                              );
                                            }
                                          }
                                        } else if (value == 'delete') {
                                          final ok = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Excluir captura?'),
                                              content: const Text(
                                                'Esta captura será removida. Não é possível desfazer.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, false),
                                                  child: const Text('Cancelar'),
                                                ),
                                                FilledButton(
                                                  style: FilledButton.styleFrom(
                                                    backgroundColor:
                                                        Theme.of(ctx)
                                                            .colorScheme
                                                            .error,
                                                  ),
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, true),
                                                  child: const Text('Excluir'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (ok == true && mounted) {
                                            await _inboxUseCase.deleteItem(item);
                                            await _load();
                                            if (mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Captura excluída.'),
                                                ),
                                              );
                                            }
                                          }
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        if (item.processedAt == null)
                                          const PopupMenuItem(
                                            value: 'conclude',
                                            child: Row(
                                              children: [
                                                Icon(Icons.check_circle_outline, size: 20),
                                                SizedBox(width: 12),
                                                Text('Concluir'),
                                              ],
                                            ),
                                          ),
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit, size: 20),
                                              SizedBox(width: 12),
                                              Text('Editar'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_outline, size: 20),
                                              SizedBox(width: 12),
                                              Text('Excluir'),
                                            ],
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
        ),
      ),
    );
  }
}
