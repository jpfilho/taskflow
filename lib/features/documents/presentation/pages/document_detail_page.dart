import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../design_system/components/buttons/tf_button.dart';
import '../../../../design_system/components/buttons/tf_icon_button.dart';
import '../../../../design_system/components/cards/tf_card.dart';
import '../../../../design_system/components/feedback/tf_empty_state.dart';
import '../../../../design_system/components/feedback/tf_loading.dart';
import '../../../../design_system/components/layout/tf_page_header.dart';
import '../../../../design_system/foundations/tf_icons.dart';
import '../../../../design_system/foundations/tf_radius.dart';
import '../../../../design_system/theme/taskflow_theme_extension.dart';
import '../../data/models/document.dart';
import '../../data/models/document_version.dart';
import '../../data/repositories/supabase_documents_repository.dart';
import '../widgets/document_status_badge.dart';

class DocumentDetailPage extends StatefulWidget {
  final String documentId;
  final SupabaseDocumentsRepository repository;

  const DocumentDetailPage({
    super.key,
    required this.documentId,
    required this.repository,
  });

  @override
  State<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends State<DocumentDetailPage> {
  Future<Document>? _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.getDocumentById(widget.documentId);
  }

  void _openUrl(BuildContext context, String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
              title: 'Detalhes do Documento',
              subtitle: 'Ficha técnica, metadados de arquivo e histórico de revisões.',
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
              child: FutureBuilder<Document>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: TFLoading(message: 'Carregando detalhes do documento...'));
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: TFEmptyState(
                        title: 'Erro ao carregar documento',
                        description: snapshot.error.toString(),
                        icon: TFIcons.warning,
                        action: TFButton(
                          label: 'Voltar',
                          leadingIcon: Icons.arrow_back_rounded,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    );
                  }
                  final doc = snapshot.data;
                  if (doc == null) {
                    return Center(
                      child: TFEmptyState(
                        title: 'Documento não encontrado',
                        description: 'O documento solicitado pode ter sido removido ou não existe.',
                        icon: Icons.search_off_rounded,
                        action: TFButton(
                          label: 'Voltar',
                          leadingIcon: Icons.arrow_back_rounded,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    padding: EdgeInsets.all(spacing.md),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TFCard(
                              padding: EdgeInsets.all(spacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          doc.title,
                                          style: typography.pageTitle.copyWith(color: colors.textPrimary),
                                        ),
                                      ),
                                      if (doc.statusDocument != null)
                                        DocumentStatusBadge(status: doc.statusDocument),
                                    ],
                                  ),
                                  if (doc.description != null && doc.description!.isNotEmpty) ...[
                                    SizedBox(height: spacing.sm),
                                    Text(
                                      doc.description!,
                                      style: typography.bodyMedium.copyWith(color: colors.textSecondary),
                                    ),
                                  ],
                                  SizedBox(height: spacing.md),
                                  Divider(color: colors.borderSubtle, height: 1),
                                  SizedBox(height: spacing.md),
                                  Text(
                                    'Metadados do Arquivo',
                                    style: typography.sectionTitle.copyWith(color: colors.textPrimary),
                                  ),
                                  SizedBox(height: spacing.xs),
                                  _infoRow(context, 'MIME Type:', doc.file.mimeType),
                                  if (doc.file.extension != null)
                                    _infoRow(context, 'Extensão:', doc.file.extension!.toUpperCase()),
                                  if (doc.file.size != null)
                                    _infoRow(context, 'Tamanho:', _formatBytes(doc.file.size!)),
                                  if (doc.hierarchyPath.isNotEmpty)
                                    _infoRow(context, 'Hierarquia Organizacional:', doc.hierarchyPath),
                                  if (doc.creatorName != null)
                                    _infoRow(context, 'Criado por:', doc.creatorName!),

                                  if (doc.tags.isNotEmpty) ...[
                                    SizedBox(height: spacing.sm),
                                    Wrap(
                                      spacing: spacing.xs,
                                      runSpacing: spacing.xxs,
                                      children: doc.tags.map((t) => Container(
                                        padding: EdgeInsets.symmetric(horizontal: spacing.xs, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: colors.surfaceSecondary,
                                          borderRadius: TFRadius.borderRadiusSm,
                                          border: Border.all(color: colors.borderSubtle),
                                        ),
                                        child: Text('#$t', style: typography.caption.copyWith(color: colors.textSecondary)),
                                      )).toList(),
                                    ),
                                  ],

                                  if (doc.file.url != null) ...[
                                    SizedBox(height: spacing.lg),
                                    TFButton(
                                      label: 'Baixar Documento Original',
                                      leadingIcon: TFIcons.download,
                                      onPressed: () => _openUrl(context, doc.file.url!),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            SizedBox(height: spacing.md),
                            TFCard(
                              padding: EdgeInsets.all(spacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Histórico de Versões',
                                    style: typography.sectionTitle.copyWith(color: colors.textPrimary),
                                  ),
                                  SizedBox(height: spacing.xs),
                                  if (doc.versions == null || doc.versions!.isEmpty)
                                    Padding(
                                      padding: EdgeInsets.symmetric(vertical: spacing.sm),
                                      child: Text(
                                        'Nenhuma versão anterior registrada para este documento.',
                                        style: typography.bodySmall.copyWith(color: colors.textSecondary),
                                      ),
                                    )
                                  else
                                    ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: doc.versions!.length,
                                      separatorBuilder: (_, __) => Divider(color: colors.borderSubtle, height: 1),
                                      itemBuilder: (context, index) {
                                        final v = doc.versions![index];
                                        return _buildVersionItem(context, v);
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
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

  Widget _infoRow(BuildContext context, String label, String value) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: typography.bodySmall.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: typography.bodySmall.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionItem(BuildContext context, DocumentVersion version) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.xs),
      child: Row(
        children: [
          Icon(Icons.history_rounded, color: colors.primary, size: 20),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Versão ${version.version}',
                  style: typography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  'MIME: ${version.mimeType} • ${_formatBytes(version.fileSize ?? 0)} • ${version.createdAt.toLocal().toString().split('.').first}',
                  style: typography.caption.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          if (version.fileUrl != null)
            TFIconButton(
              icon: TFIcons.download,
              tooltip: 'Baixar Versão ${version.version}',
              onPressed: () => _openUrl(context, version.fileUrl!),
            ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
