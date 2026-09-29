import 'package:flutter/material.dart';
import '../../components/sync/tf_sync_indicator.dart';
import '../../theme/taskflow_theme_extension.dart';
import '../gallery_section.dart';

class SyncSection extends StatelessWidget {
  const SyncSection({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.tfSpacing;

    final states = [
      (TFSyncState.online, 'Online'),
      (TFSyncState.offline, 'Offline'),
      (TFSyncState.syncing, 'Sincronizando...'),
      (TFSyncState.pending, 'Pendente de envio'),
      (TFSyncState.synced, 'Totalmente sincronizado'),
      (TFSyncState.error, 'Erro de conexão'),
      (TFSyncState.conflict, 'Conflito detectado'),
    ];

    return GallerySection(
      title: 'TFSyncIndicator — Sincronização Offline-First',
      description: 'Componente visual para indicar conectividade, pendências na fila local e status com o Supabase.',
      children: [
        GalleryPreviewCard(
          title: 'Todos os Estados Visuais (Modo Pílula)',
          description: 'Apresentação com ícone, cor e rótulo textual',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final (state, label) in states) ...[
                TFSyncIndicator(state: state, label: label),
              ],
            ],
          ),
        ),
        GalleryPreviewCard(
          title: 'Modo Compacto (AppBars e Toolbars)',
          description: 'compact: true com tooltip acessível e clique opcional',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final (state, label) in states) ...[
                    TFSyncIndicator(
                      state: state,
                      label: label,
                      compact: true,
                      onTap: () {},
                    ),
                  ],
                ],
              ),
              SizedBox(height: spacing.sm),
              const Text(
                'Passe o mouse para visualizar o tooltip de acessibilidade em cada indicador compacto.',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
