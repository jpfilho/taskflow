import 'package:flutter/material.dart';
import '../../../../design_system/components/buttons/tf_button.dart';
import '../../../../design_system/components/cards/tf_card.dart';
import '../../../../design_system/components/feedback/tf_empty_state.dart';
import '../../../../design_system/components/feedback/tf_loading.dart';
import '../../../../design_system/components/layout/tf_page_header.dart';
import '../../../../design_system/foundations/tf_icons.dart';
import '../../../../design_system/theme/taskflow_theme_extension.dart';
import '../../data/models/document_status.dart';
import '../../data/repositories/supabase_documents_repository.dart';
import '../widgets/document_status_badge.dart';

class StatusDocumentsPage extends StatefulWidget {
  final SupabaseDocumentsRepository repository;

  const StatusDocumentsPage({
    super.key,
    required this.repository,
  });

  @override
  State<StatusDocumentsPage> createState() => _StatusDocumentsPageState();
}

class _StatusDocumentsPageState extends State<StatusDocumentsPage> {
  Future<List<DocumentStatus>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = widget.repository.listStatuses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            TFPageHeader(
              title: 'Status de Documentos',
              subtitle: 'Classificações e etapas do ciclo de vida documental.',
              secondaryActions: [
                TFButton(
                  label: 'Voltar',
                  variant: TFButtonVariant.secondary,
                  leadingIcon: Icons.arrow_back_rounded,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Expanded(
              child: FutureBuilder<List<DocumentStatus>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: TFLoading(message: 'Carregando status cadastrados...'));
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: TFEmptyState(
                        title: 'Erro ao carregar status',
                        description: snapshot.error.toString(),
                        icon: TFIcons.warning,
                        action: TFButton(
                          label: 'Tentar Novamente',
                          leadingIcon: TFIcons.refresh,
                          onPressed: _load,
                        ),
                      ),
                    );
                  }
                  final list = snapshot.data ?? [];
                  if (list.isEmpty) {
                    return Center(
                      child: TFEmptyState(
                        title: 'Nenhum status cadastrado',
                        description: 'Configure os status operacionais no Supabase.',
                        icon: Icons.tune_rounded,
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: EdgeInsets.all(spacing.md),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => SizedBox(height: spacing.xs),
                    itemBuilder: (context, index) {
                      final status = list[index];
                      return TFCard(
                        padding: EdgeInsets.all(spacing.sm),
                        child: Row(
                          children: [
                            DocumentStatusBadge(status: status),
                            SizedBox(width: spacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    status.nome,
                                    style: typography.bodyMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  if (status.descricao != null && status.descricao!.isNotEmpty)
                                    Text(
                                      status.descricao!,
                                      style: typography.caption.copyWith(color: colors.textSecondary),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
