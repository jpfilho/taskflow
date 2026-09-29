import 'package:flutter/material.dart';
import '../../../../design_system/taskflow_design_system.dart';
import '../../data/models/status_album.dart';
import '../../data/repositories/status_album_repository.dart';
import 'status_album_form_dialog.dart';

class StatusAlbumListView extends StatefulWidget {
  const StatusAlbumListView({super.key});

  @override
  State<StatusAlbumListView> createState() => _StatusAlbumListViewState();
}

class _StatusAlbumListViewState extends State<StatusAlbumListView> {
  final StatusAlbumRepository _repository = StatusAlbumRepository();
  List<StatusAlbum> _statusAlbums = [];
  List<StatusAlbum> _filteredStatusAlbums = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStatusAlbums();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStatusAlbums() async {
    setState(() => _isLoading = true);
    try {
      final status = await _repository.getAllStatusAlbums();
      if (mounted) {
        setState(() {
          _statusAlbums = status;
          _filteredStatusAlbums = status;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _filteredStatusAlbums = _statusAlbums);
    } else {
      setState(() {
        _filteredStatusAlbums = _statusAlbums.where((s) =>
          s.nome.toLowerCase().contains(query.toLowerCase()) ||
          (s.descricao?.toLowerCase().contains(query.toLowerCase()) ?? false)
        ).toList();
      });
    }
  }

  Future<void> _createStatusAlbum() async {
    final result = await showDialog<StatusAlbum>(
      context: context,
      builder: (context) => const StatusAlbumFormDialog(),
    );

    if (result != null) {
      final created = await _repository.createStatusAlbum(result);
      if (created != null) {
        _loadStatusAlbums();
      }
    }
  }

  Future<void> _editStatusAlbum(StatusAlbum statusAlbum) async {
    final result = await showDialog<StatusAlbum>(
      context: context,
      builder: (context) => StatusAlbumFormDialog(statusAlbum: statusAlbum),
    );

    if (result != null) {
      final updated = await _repository.updateStatusAlbum(result.id, result);
      if (updated != null) {
        _loadStatusAlbums();
      }
    }
  }

  Future<void> _deleteStatusAlbum(StatusAlbum statusAlbum) async {
    final confirmed = await TFModalDialog.confirm(
      context: context,
      title: 'Excluir Status de Álbum',
      message: 'Tem certeza que deseja excluir o status "${statusAlbum.nome}"?',
      confirmLabel: 'Excluir',
      isDestructive: true,
    );

    if (confirmed == true) {
      final success = await _repository.deleteStatusAlbum(statusAlbum.id);
      if (success) {
        _loadStatusAlbums();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            TFPageHeader(
              title: 'Status de Álbuns de Mídia',
              subtitle: 'Classificação, badges e regras de conferência para álbuns fotográficos.',
              onBack: () => Navigator.of(context).maybePop(),
              primaryAction: TFButton(
                label: 'Novo Status',
                leadingIcon: TFIcons.add,
                onPressed: _createStatusAlbum,
              ),
              secondaryActions: [
                TFIconButton(
                  icon: TFIcons.refresh,
                  tooltip: 'Atualizar',
                  onPressed: _loadStatusAlbums,
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.xs),
              child: TFTextField(
                controller: _searchController,
                hint: 'Buscar status por nome ou descrição...',
                prefixIcon: Icon(TFIcons.search, size: 18, color: colors.textSecondary),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.md),
                child: _buildContent(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final spacing = context.tfSpacing;

    if (_isLoading) {
      return const Center(child: TFLoading(message: 'Carregando status de álbuns...'));
    }

    if (_filteredStatusAlbums.isEmpty) {
      return Center(
        child: TFEmptyState(
          title: _searchController.text.isNotEmpty ? 'Nenhum status encontrado' : 'Nenhum status cadastrado',
          description: _searchController.text.isNotEmpty
              ? 'Nenhum status corresponde ao termo pesquisado.'
              : 'Cadastre os status para categorizar e conferir fotos de álbuns.',
          icon: Icons.tune_rounded,
          action: TFButton(
            label: 'Novo Status',
            leadingIcon: TFIcons.add,
            onPressed: _createStatusAlbum,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= TFBreakpoints.sm;

        if (!isDesktop) {
          // Lista mobile
          return ListView.separated(
            padding: EdgeInsets.symmetric(vertical: spacing.xs),
            itemCount: _filteredStatusAlbums.length,
            separatorBuilder: (_, __) => SizedBox(height: spacing.xs),
            itemBuilder: (context, index) {
              final s = _filteredStatusAlbums[index];
              return TFCard(
                padding: EdgeInsets.all(spacing.sm),
                child: Row(
                  children: [
                    _colorPreview(s),
                    SizedBox(width: spacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.nome,
                            style: context.tfTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: context.tfColors.textPrimary,
                            ),
                          ),
                          if (s.descricao != null && s.descricao!.isNotEmpty)
                            Text(
                              s.descricao!,
                              style: context.tfTypography.caption.copyWith(color: context.tfColors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                    TFIconButton(
                      icon: TFIcons.edit,
                      tooltip: 'Editar',
                      onPressed: () => _editStatusAlbum(s),
                    ),
                    TFIconButton(
                      icon: TFIcons.delete,
                      tooltip: 'Excluir',
                      onPressed: () => _deleteStatusAlbum(s),
                    ),
                  ],
                ),
              );
            },
          );
        }

        // Tabela Desktop
        return TFDataTable<StatusAlbum>(
          columns: [
            TFDataColumn.text(
              id: 'cor',
              title: 'Cor',
              width: 80,
              cellBuilder: (context, s) => _colorPreview(s),
            ),
            TFDataColumn.text(
              id: 'nome',
              title: 'Nome do Status',
              cellBuilder: (context, s) => Text(
                s.nome,
                style: context.tfTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.tfColors.textPrimary,
                ),
              ),
            ),
            TFDataColumn.text(
              id: 'descricao',
              title: 'Descrição',
              cellBuilder: (context, s) => Text(
                s.descricao ?? '—',
                style: context.tfTypography.bodySmall.copyWith(color: context.tfColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TFDataColumn.text(
              id: 'ativo',
              title: 'Ativo',
              width: 90,
              cellBuilder: (context, s) => Icon(
                s.ativo ? TFIcons.success : Icons.cancel_outlined,
                color: s.ativo ? context.tfColors.success : context.tfColors.textSecondary,
                size: 18,
              ),
            ),
            TFDataColumn.text(
              id: 'acoes',
              title: 'Ações',
              width: 130,
              cellBuilder: (context, s) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TFIconButton(
                    icon: TFIcons.edit,
                    tooltip: 'Editar Status',
                    onPressed: () => _editStatusAlbum(s),
                  ),
                  TFIconButton(
                    icon: TFIcons.delete,
                    tooltip: 'Excluir Status',
                    onPressed: () => _deleteStatusAlbum(s),
                  ),
                ],
              ),
            ),
          ],
          items: _filteredStatusAlbums,
        );
      },
    );
  }

  Widget _colorPreview(StatusAlbum s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: s.backgroundColor,
        borderRadius: TFRadius.borderRadiusFull,
      ),
      child: Text(
        s.nome,
        style: TextStyle(
          color: s.textColor,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}
