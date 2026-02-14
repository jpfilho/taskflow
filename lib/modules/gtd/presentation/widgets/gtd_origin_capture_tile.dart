import 'package:flutter/material.dart';

import '../../data/models/gtd_models.dart';
import '../../domain/usecases/gtd_inbox_usecase.dart';

/// Exibe a origem (captura do inbox) de uma ação e, ao toque, abre diálogo com o conteúdo completo.
class GtdOriginCaptureTile extends StatelessWidget {
  final String sourceInboxId;
  final GtdInboxUseCase inboxUseCase;

  const GtdOriginCaptureTile({
    super.key,
    required this.sourceInboxId,
    required this.inboxUseCase,
  });

  Future<void> _showCaptureDialog(BuildContext context, GtdInboxItem item) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Captura de origem'),
        content: SingleChildScrollView(
          child: SelectableText(
            item.content,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FutureBuilder<GtdInboxItem?>(
      future: inboxUseCase.getInboxItem(sourceInboxId),
      builder: (context, snap) {
        if (!snap.hasData || snap.data == null) {
          return const SizedBox.shrink();
        }
        final item = snap.data!;
        final content = item.content;

        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: InkWell(
            onTap: () => _showCaptureDialog(context, item),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.inbox_rounded,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Origem (toque para ver a captura):',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          content,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.open_in_new,
                    size: 14,
                    color: colorScheme.primary.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
