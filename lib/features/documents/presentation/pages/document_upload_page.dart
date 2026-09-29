import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../design_system/components/buttons/tf_button.dart';
import '../../../../design_system/components/cards/tf_card.dart';
import '../../../../design_system/components/inputs/tf_text_field.dart';
import '../../../../design_system/components/layout/tf_page_header.dart';
import '../../../../design_system/foundations/tf_icons.dart';
import '../../../../design_system/foundations/tf_radius.dart';
import '../../../../design_system/theme/taskflow_theme_extension.dart';
import '../../application/controllers/upload_controller.dart';
import '../../data/repositories/supabase_documents_repository.dart';
import '../../../../services/auth_service_simples.dart';

class DocumentUploadPage extends StatefulWidget {
  final SupabaseDocumentsRepository repository;

  const DocumentUploadPage({super.key, required this.repository});

  @override
  State<DocumentUploadPage> createState() => _DocumentUploadPageState();
}

class _DocumentUploadPageState extends State<DocumentUploadPage> {
  late final DocumentUploadController controller;
  final TextEditingController titleController = TextEditingController();
  final TextEditingController tagsController = TextEditingController();
  String? _regionalId;
  String? _divisaoId;
  String? _localId;
  String? _regionalNome;
  String? _divisaoNome;
  String? _localNome;
  bool uploading = false;

  @override
  void initState() {
    super.initState();
    controller = DocumentUploadController(widget.repository);
    final user = AuthServiceSimples().currentUser;
    if (user != null) {
      if (user.regionalIds.isNotEmpty) _regionalId = user.regionalIds.first;
      if (user.divisaoIds.isNotEmpty) _divisaoId = user.divisaoIds.first;
      if (user.regionais.isNotEmpty) _regionalNome = user.regionais.first;
      if (user.divisoes.isNotEmpty) _divisaoNome = user.divisoes.first;
      // local_id não vem do perfil; permanece nulo
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;
    final items = result.files
        .where((f) => f.bytes != null && f.name.isNotEmpty)
        .map(
          (f) => DocumentUploadItem(
            fileName: f.name,
            bytes: f.bytes!,
          ),
        )
        .toList();
    if (items.isEmpty) return;
    controller.addFiles(items);
  }

  Future<void> _upload() async {
    final user = AuthServiceSimples().currentUser;
    if (user == null || user.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para enviar documentos.')),
      );
      return;
    }
    final userId = user.id!;
    setState(() => uploading = true);
    await controller.uploadAll(
      userId: userId,
      regionalId: _regionalId,
      divisaoId: _divisaoId,
      localId: _localId,
      segmentId: user.segmentoIds.isNotEmpty ? user.segmentoIds.first : null,
      titlePrefix: titleController.text.isEmpty ? null : titleController.text,
      tags: tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    );
    setState(() => uploading = false);
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
              title: 'Upload de Documentos',
              subtitle: 'Envie novos arquivos técnicos com metadados automáticos e tags organizacionais.',
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
              child: SingleChildScrollView(
                padding: EdgeInsets.all(spacing.md),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TFCard(
                          padding: EdgeInsets.all(spacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Parâmetros do Documento',
                                style: typography.sectionTitle.copyWith(color: colors.textPrimary),
                              ),
                              SizedBox(height: spacing.sm),
                              TFTextField(
                                controller: titleController,
                                label: 'Título / Prefixo (opcional)',
                                hint: 'Ex: Manual Operacional SE Alpha',
                              ),
                              SizedBox(height: spacing.sm),
                              TFTextField(
                                controller: tagsController,
                                label: 'Tags (separadas por vírgula)',
                                hint: 'Ex: Manutenção, 2026, Procedimento',
                              ),
                              SizedBox(height: spacing.md),
                              Text(
                                'Contexto Organizacional Herdado',
                                style: typography.bodySmall.copyWith(
                                  color: colors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: spacing.xs),
                              _buildPerfilInfo(context),
                              SizedBox(height: spacing.md),
                              Row(
                                children: [
                                  TFButton(
                                    label: 'Selecionar Arquivos',
                                    leadingIcon: TFIcons.add,
                                    variant: TFButtonVariant.secondary,
                                    onPressed: uploading ? null : _pickFiles,
                                  ),
                                  SizedBox(width: spacing.sm),
                                  TFButton(
                                    label: uploading ? 'Enviando...' : 'Iniciar Envio',
                                    leadingIcon: Icons.cloud_upload_rounded,
                                    onPressed: uploading ? null : _upload,
                                  ),
                                ],
                              ),
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
                                'Fila de Upload',
                                style: typography.sectionTitle.copyWith(color: colors.textPrimary),
                              ),
                              SizedBox(height: spacing.sm),
                              SizedBox(
                                height: 260,
                                child: AnimatedBuilder(
                                  animation: controller,
                                  builder: (context, _) {
                                    final items = controller.uploads;
                                    if (items.isEmpty) {
                                      return Center(
                                        child: Text(
                                          'Nenhum arquivo adicionado à fila.',
                                          style: typography.bodySmall.copyWith(color: colors.textSecondary),
                                        ),
                                      );
                                    }
                                    return ListView.separated(
                                      itemCount: items.length,
                                      separatorBuilder: (_, __) => Divider(color: colors.borderSubtle, height: 1),
                                      itemBuilder: (context, index) {
                                        final item = items[index];
                                        return Padding(
                                          padding: EdgeInsets.symmetric(vertical: spacing.xs),
                                          child: Row(
                                            children: [
                                              Icon(Icons.insert_drive_file_rounded, color: colors.primary, size: 24),
                                              SizedBox(width: spacing.sm),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item.fileName,
                                                      style: typography.bodyMedium.copyWith(
                                                        color: colors.textPrimary,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    SizedBox(height: spacing.xxs),
                                                    ClipRRect(
                                                      borderRadius: TFRadius.borderRadiusFull,
                                                      child: LinearProgressIndicator(
                                                        value: item.progress,
                                                        minHeight: 6,
                                                        backgroundColor: colors.borderSubtle,
                                                        valueColor: AlwaysStoppedAnimation<Color>(
                                                          item.error != null ? colors.danger : colors.primary,
                                                        ),
                                                      ),
                                                    ),
                                                    if (item.error != null) ...[
                                                      SizedBox(height: spacing.xxs),
                                                      Text(
                                                        item.error.toString(),
                                                        style: typography.caption.copyWith(color: colors.danger),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              SizedBox(width: spacing.sm),
                                              if (item.created != null)
                                                Icon(TFIcons.success, color: colors.success, size: 22)
                                              else if (item.error != null)
                                                Icon(TFIcons.warning, color: colors.danger, size: 22),
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
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerfilInfo(BuildContext context) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;

    final chips = <Widget>[];
    if (_regionalId != null) {
      chips.add(_badgeChip(context, 'Regional: ${_regionalNome ?? _regionalId}'));
    }
    if (_divisaoId != null) {
      chips.add(_badgeChip(context, 'Divisão: ${_divisaoNome ?? _divisaoId}'));
    }
    if (_localId != null) {
      chips.add(_badgeChip(context, 'Local: ${_localNome ?? _localId}'));
    }
    if (chips.isEmpty) {
      return Text(
        'Perfil: sem regional/divisão/local configurados.',
        style: typography.caption.copyWith(color: colors.textSecondary),
      );
    }
    return Wrap(
      spacing: spacing.xs,
      runSpacing: spacing.xxs,
      children: chips,
    );
  }

  Widget _badgeChip(BuildContext context, String label) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xxs),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: TFRadius.borderRadiusSm,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Text(
        label,
        style: typography.caption.copyWith(color: colors.textSecondary),
      ),
    );
  }
}
