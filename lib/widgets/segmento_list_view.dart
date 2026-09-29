import 'package:flutter/material.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/segmento.dart';
import '../services/segmento_service.dart';
import 'segmento_form_dialog.dart';

class SegmentoListView extends StatefulWidget {
  const SegmentoListView({super.key});

  @override
  State<SegmentoListView> createState() => _SegmentoListViewState();
}

class _SegmentoListViewState extends State<SegmentoListView> {
  final SegmentoService _segmentoService = SegmentoService();
  List<Segmento> _segmentos = [];
  List<Segmento> _filteredSegmentos = [];
  bool _isLoading = true;
  bool _isTableView = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSegmentos();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSegmentos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final segmentos = await _segmentoService.getAllSegmentos();
      if (mounted) {
        setState(() {
          _segmentos = segmentos;
          _filteredSegmentos = segmentos;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar segmentos: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final colors = context.tfColors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar segmentos: $e'),
            backgroundColor: colors.danger,
          ),
        );
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _filteredSegmentos = _segmentos;
      });
    } else {
      _searchSegmentos(query);
    }
  }

  Future<void> _searchSegmentos(String query) async {
    try {
      final results = await _segmentoService.searchSegmentos(query);
      if (mounted) {
        setState(() {
          _filteredSegmentos = results;
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar segmentos: $e');
    }
  }

  Future<void> _createSegmento() async {
    final result = await showDialog<Segmento>(
      context: context,
      builder: (context) => const SegmentoFormDialog(),
    );

    if (result != null) {
      final created = await _segmentoService.createSegmento(result);
      if (created != null) {
        await _loadSegmentos();
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Segmento criado com sucesso!'),
              backgroundColor: colors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Erro ao criar segmento'),
              backgroundColor: colors.danger,
            ),
          );
        }
      }
    }
  }

  Future<void> _editSegmento(Segmento segmento) async {
    final result = await showDialog<Segmento>(
      context: context,
      builder: (context) => SegmentoFormDialog(segmento: segmento),
    );

    if (result != null) {
      final updated = await _segmentoService.updateSegmento(segmento.id, result);
      if (updated != null) {
        await _loadSegmentos();
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Segmento atualizado com sucesso!'),
              backgroundColor: colors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Erro ao atualizar segmento'),
              backgroundColor: colors.danger,
            ),
          );
        }
      }
    }
  }

  Future<void> _duplicateSegmento(Segmento segmento) async {
    final duplicated = segmento.copyWith(
      id: '',
      segmento: '${segmento.segmento} (Cópia)',
    );

    final result = await showDialog<Segmento>(
      context: context,
      builder: (context) => SegmentoFormDialog(segmento: duplicated),
    );

    if (result != null) {
      final created = await _segmentoService.createSegmento(result);
      if (created != null) {
        await _loadSegmentos();
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Segmento duplicado com sucesso!'),
              backgroundColor: colors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Erro ao duplicar segmento'),
              backgroundColor: colors.danger,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteSegmento(Segmento segmento) async {
    final confirm = await TFModalDialog.confirm(
      context: context,
      title: 'Confirmar Exclusão',
      message: 'Deseja realmente excluir o segmento "${segmento.segmento}"?\nEsta ação não poderá ser desfeita.',
      confirmLabel: 'Excluir',
      cancelLabel: 'Cancelar',
      isDestructive: true,
    );

    if (confirm == true) {
      final deleted = await _segmentoService.deleteSegmento(segmento.id);
      if (deleted) {
        await _loadSegmentos();
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Segmento excluído com sucesso!'),
              backgroundColor: colors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Erro ao excluir segmento'),
              backgroundColor: colors.danger,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final isDesktop = TFBreakpoints.isDesktop(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header Oficial do TFDS
              TFPageHeader(
                title: 'Cadastro de Segmentos',
                subtitle: 'Categorias e especialidades de atuação operacional',
                onBack: () => Navigator.of(context).maybePop(),
                primaryAction: TFButton(
                  label: 'Novo Segmento',
                  leadingIcon: TFIcons.add,
                  variant: TFButtonVariant.primary,
                  onPressed: _createSegmento,
                ),
                secondaryActions: [
                  TFButton(
                    label: 'Atualizar',
                    leadingIcon: TFIcons.refresh,
                    variant: TFButtonVariant.secondary,
                    onPressed: _loadSegmentos,
                  ),
                ],
              ),

              SizedBox(height: spacing.md),

              // 2. Barra de Busca e Alternância Tabela/Card
              Row(
                children: [
                  Expanded(
                    child: TFTextField(
                      controller: _searchController,
                      hint: 'Pesquisar segmentos por nome ou descrição...',
                      prefixIcon: const Icon(TFIcons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(TFIcons.close, size: 16),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                    ),
                  ),
                  SizedBox(width: spacing.sm),
                  TFIconButton(
                    icon: _isTableView ? Icons.view_list_rounded : Icons.table_chart_rounded,
                    tooltip: _isTableView ? 'Visualizar em Cards' : 'Visualizar em Tabela',
                    variant: TFIconButtonVariant.subtle,
                    onPressed: () {
                      setState(() {
                        _isTableView = !_isTableView;
                      });
                    },
                  ),
                ],
              ),

              SizedBox(height: spacing.md),

              // 3. Conteúdo Principal
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: TFLoading(
                          mode: TFLoadingMode.section,
                          message: 'Carregando segmentos...',
                        ),
                      )
                    : _filteredSegmentos.isEmpty
                        ? Center(
                            child: TFEmptyState(
                              icon: Icons.category_outlined,
                              title: _segmentos.isEmpty
                                  ? 'Nenhum segmento cadastrado'
                                  : 'Nenhum segmento encontrado',
                              description: _segmentos.isEmpty
                                  ? 'Comece cadastrando o primeiro segmento da empresa.'
                                  : 'Não existem segmentos compatíveis com os filtros atuais.',
                              action: _segmentos.isEmpty
                                  ? TFButton(
                                      label: 'Cadastrar Primeiro Segmento',
                                      leadingIcon: TFIcons.add,
                                      variant: TFButtonVariant.primary,
                                      onPressed: _createSegmento,
                                    )
                                  : TFButton(
                                      label: 'Limpar Busca',
                                      leadingIcon: TFIcons.clear,
                                      variant: TFButtonVariant.secondary,
                                      onPressed: () => _searchController.clear(),
                                    ),
                            ),
                          )
                        : _isTableView || isDesktop
                            ? _buildTableView()
                            : _buildListView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableView() {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    return TFDataTable<Segmento>(
      items: _filteredSegmentos,
      zebra: true,
      columns: [
        TFDataColumn<Segmento>.text(
          id: 'segmento',
          title: 'Segmento',
          cellBuilder: (context, item) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: item.backgroundColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.borderSubtle,
                    width: 1,
                  ),
                ),
              ),
              SizedBox(width: spacing.xs),
              Text(
                item.segmento,
                style: typography.bodyMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        TFDataColumn<Segmento>.text(
          id: 'descricao',
          title: 'Descrição',
          cellBuilder: (context, item) => Text(
            item.descricao != null && item.descricao!.isNotEmpty
                ? item.descricao!
                : 'Sem descrição',
            style: typography.bodySmall.copyWith(
              color: item.descricao != null && item.descricao!.isNotEmpty
                  ? colors.textSecondary
                  : colors.textMuted,
              fontStyle: item.descricao != null && item.descricao!.isNotEmpty
                  ? FontStyle.normal
                  : FontStyle.italic,
            ),
          ),
        ),
        TFDataColumn<Segmento>.text(
          id: 'cor',
          title: 'Identificador Visual',
          width: 160,
          cellBuilder: (context, item) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: spacing.xs, vertical: 2),
                decoration: BoxDecoration(
                  color: item.backgroundColor,
                  borderRadius: TFRadius.borderRadiusSm,
                ),
                child: Text(
                  item.cor != null && item.cor!.isNotEmpty ? item.cor! : '#PADRÃO',
                  style: typography.micro.copyWith(
                    color: item.textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        TFDataColumn<Segmento>(
          id: 'acoes',
          label: const Text('Ações'),
          width: 160,
          alignment: Alignment.centerRight,
          cellBuilder: (context, item) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TFIconButton(
                icon: TFIcons.edit,
                tooltip: 'Editar "${item.segmento}"',
                variant: TFIconButtonVariant.standard,
                iconSize: 18,
                onPressed: () => _editSegmento(item),
              ),
              TFIconButton(
                icon: Icons.copy_rounded,
                tooltip: 'Duplicar "${item.segmento}"',
                variant: TFIconButtonVariant.subtle,
                iconSize: 18,
                onPressed: () => _duplicateSegmento(item),
              ),
              TFIconButton(
                icon: TFIcons.delete,
                tooltip: 'Excluir "${item.segmento}"',
                variant: TFIconButtonVariant.danger,
                iconSize: 18,
                onPressed: () => _deleteSegmento(item),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListView() {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    return ListView.builder(
      itemCount: _filteredSegmentos.length,
      itemBuilder: (context, index) {
        final item = _filteredSegmentos[index];
        return Padding(
          padding: EdgeInsets.only(bottom: spacing.sm),
          child: TFCard(
            variant: TFCardVariant.defaultCard,
            padding: EdgeInsets.symmetric(horizontal: spacing.base, vertical: spacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: item.backgroundColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.borderSubtle),
                            ),
                          ),
                          SizedBox(width: spacing.xs),
                          Expanded(
                            child: Text(
                              item.segmento,
                              style: typography.cardTitle.copyWith(color: colors.textPrimary),
                            ),
                          ),
                          if (item.cor != null && item.cor!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: item.backgroundColor,
                                borderRadius: TFRadius.borderRadiusSm,
                              ),
                              child: Text(
                                item.cor!,
                                style: typography.micro.copyWith(color: item.textColor, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      if (item.descricao != null && item.descricao!.isNotEmpty) ...[
                        SizedBox(height: spacing.xxs),
                        Text(
                          item.descricao!,
                          style: typography.bodySmall.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TFIconButton(
                      icon: TFIcons.edit,
                      tooltip: 'Editar "${item.segmento}"',
                      variant: TFIconButtonVariant.standard,
                      onPressed: () => _editSegmento(item),
                    ),
                    TFIconButton(
                      icon: Icons.copy_rounded,
                      tooltip: 'Duplicar "${item.segmento}"',
                      variant: TFIconButtonVariant.subtle,
                      onPressed: () => _duplicateSegmento(item),
                    ),
                    TFIconButton(
                      icon: TFIcons.delete,
                      tooltip: 'Excluir "${item.segmento}"',
                      variant: TFIconButtonVariant.danger,
                      onPressed: () => _deleteSegmento(item),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
