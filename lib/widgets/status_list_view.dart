import 'package:flutter/material.dart';
import 'dart:async';
import '../design_system/taskflow_design_system.dart';
import '../models/status.dart';
import '../services/status_service.dart';
import 'status_form_dialog.dart';

class StatusListView extends StatefulWidget {
  const StatusListView({super.key});

  @override
  State<StatusListView> createState() => _StatusListViewState();
}

class _StatusListViewState extends State<StatusListView> {
  final StatusService _statusService = StatusService();
  List<Status> _statusList = [];
  List<Status> _filteredStatusList = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isTableView = false; // false = lista (cards), true = tabela

  StreamSubscription<String>? _statusChangeSubscription;

  @override
  void initState() {
    super.initState();
    _loadStatus();
    _searchController.addListener(_onSearchChanged);
    // Escutar mudanças nos status
    _statusChangeSubscription = _statusService.statusChangeStream.listen((_) {
      _loadStatus(); // Recarregar quando houver mudança
    });
    // No desktop, tabela é o padrão
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && TFBreakpoints.isDesktop(context)) {
        setState(() {
          _isTableView = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _statusChangeSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final statusList = await _statusService.getAllStatus();
      setState(() {
        _statusList = statusList;
        _filteredStatusList = statusList;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar status: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        final colors = context.tfColors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar status: $e'),
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
        _filteredStatusList = _statusList;
      });
    } else {
      _searchStatus(query);
    }
  }

  Future<void> _searchStatus(String query) async {
    try {
      final results = await _statusService.searchStatus(query);
      setState(() {
        _filteredStatusList = results;
      });
    } catch (e) {
      debugPrint('Erro ao buscar status: $e');
    }
  }

  Future<void> _createStatus() async {
    final result = await showDialog<Status>(
      context: context,
      builder: (context) => const StatusFormDialog(),
    );

    if (result != null) {
      final created = await _statusService.createStatus(result);
      if (created != null) {
        await _loadStatus();
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Status criado com sucesso!'),
              backgroundColor: colors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Erro ao criar status'),
              backgroundColor: colors.danger,
            ),
          );
        }
      }
    }
  }

  Future<void> _editStatus(Status status) async {
    final result = await showDialog<Status>(
      context: context,
      builder: (context) => StatusFormDialog(status: status),
    );

    if (result != null) {
      final updated = await _statusService.updateStatus(status.id, result);
      if (updated != null) {
        await _loadStatus();
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Status atualizado com sucesso! Cor: ${updated.cor}'),
              backgroundColor: colors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Erro ao atualizar status'),
              backgroundColor: colors.danger,
            ),
          );
        }
      }
    }
  }

  Future<void> _duplicateStatus(Status status) async {
    final duplicated = status.copyWith(
      id: '',
      codigo: '${status.codigo}CP',
      status: '${status.status} (Cópia)',
    );

    final result = await showDialog<Status>(
      context: context,
      builder: (context) => StatusFormDialog(status: duplicated),
    );

    if (result != null) {
      final created = await _statusService.createStatus(result);
      if (created != null) {
        await _loadStatus();
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Status duplicado com sucesso!'),
              backgroundColor: colors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Erro ao duplicar status'),
              backgroundColor: colors.danger,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteStatus(Status status) async {
    final confirm = await TFModalDialog.confirm(
      context: context,
      title: 'Confirmar Exclusão',
      message: 'Deseja realmente excluir o status "${status.status}" (${status.codigo})?',
      confirmLabel: 'Excluir',
      cancelLabel: 'Cancelar',
      isDestructive: true,
    );

    if (confirm == true) {
      final deleted = await _statusService.deleteStatus(status.id);
      if (deleted) {
        await _loadStatus();
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Status excluído com sucesso!'),
              backgroundColor: colors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Erro ao excluir status'),
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
              // 1. Page Header oficial TFDS
              TFPageHeader(
                title: 'Cadastro de Status',
                subtitle: 'Gestão de códigos, cores indicativas e estados operacionais do sistema',
                onBack: () => Navigator.of(context).maybePop(),
                primaryAction: TFButton(
                  label: 'Novo Status',
                  leadingIcon: TFIcons.add,
                  variant: TFButtonVariant.primary,
                  onPressed: _createStatus,
                ),
                secondaryActions: [
                  TFButton(
                    label: 'Atualizar',
                    leadingIcon: TFIcons.refresh,
                    variant: TFButtonVariant.secondary,
                    onPressed: _loadStatus,
                  ),
                ],
              ),

              SizedBox(height: spacing.md),

              // 2. Barra de Busca e Alternância de Visualização
              Row(
                children: [
                  Expanded(
                    child: TFTextField(
                      controller: _searchController,
                      hint: 'Buscar status por código ou nome...',
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
                          message: 'Carregando status cadastrados...',
                        ),
                      )
                    : _filteredStatusList.isEmpty
                        ? Center(
                            child: TFEmptyState(
                              icon: TFIcons.task,
                              title: _statusList.isEmpty
                                  ? 'Nenhum status cadastrado'
                                  : 'Nenhum status encontrado',
                              description: _statusList.isEmpty
                                  ? 'Comece cadastrando o primeiro status operacional do TaskFlow.'
                                  : 'Nenhum status corresponde aos termos pesquisados.',
                              action: _statusList.isEmpty
                                  ? TFButton(
                                      label: 'Cadastrar Primeiro Status',
                                      leadingIcon: TFIcons.add,
                                      variant: TFButtonVariant.primary,
                                      onPressed: _createStatus,
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

  Widget _buildListView() {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    return ListView.builder(
      itemCount: _filteredStatusList.length,
      itemBuilder: (context, index) {
        final status = _filteredStatusList[index];
        return Padding(
          padding: EdgeInsets.only(bottom: spacing.sm),
          child: TFCard(
            variant: TFCardVariant.defaultCard,
            padding: EdgeInsets.symmetric(horizontal: spacing.base, vertical: spacing.sm),
            child: Row(
              children: [
                // Identificador visual de cor e código
                Container(
                  padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xxs),
                  decoration: BoxDecoration(
                    color: status.color,
                    borderRadius: TFRadius.borderRadiusSm,
                  ),
                  child: Text(
                    status.codigo,
                    style: typography.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: spacing.md),
                // Nome e cor
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        status.status,
                        style: typography.cardTitle.copyWith(color: colors.textPrimary),
                      ),
                      SizedBox(height: spacing.xxs),
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: status.color,
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.borderSubtle, width: 1),
                            ),
                          ),
                          SizedBox(width: spacing.xxs),
                          Text(
                            status.cor,
                            style: typography.bodySmall.copyWith(color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Ações
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TFIconButton(
                      icon: TFIcons.edit,
                      tooltip: 'Editar status "${status.status}"',
                      variant: TFIconButtonVariant.standard,
                      onPressed: () => _editStatus(status),
                    ),
                    TFIconButton(
                      icon: Icons.copy_rounded,
                      tooltip: 'Duplicar status "${status.status}"',
                      variant: TFIconButtonVariant.subtle,
                      onPressed: () => _duplicateStatus(status),
                    ),
                    TFIconButton(
                      icon: TFIcons.delete,
                      tooltip: 'Excluir status "${status.status}"',
                      variant: TFIconButtonVariant.danger,
                      onPressed: () => _deleteStatus(status),
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

  Widget _buildTableView() {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    return TFDataTable<Status>(
      items: _filteredStatusList,
      zebra: true,
      columns: [
        TFDataColumn<Status>(
          id: 'codigo',
          label: const Text('Código'),
          width: 110,
          cellBuilder: (context, status) => Container(
            padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xxs),
            decoration: BoxDecoration(
              color: status.color,
              borderRadius: TFRadius.borderRadiusSm,
            ),
            child: Text(
              status.codigo,
              style: typography.labelSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        TFDataColumn<Status>.text(
          id: 'status',
          title: 'Status',
          cellBuilder: (context, status) => Text(
            status.status,
            style: typography.bodyMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        TFDataColumn<Status>(
          id: 'cor',
          label: const Text('Cor Indicativa'),
          width: 160,
          cellBuilder: (context, status) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: status.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.borderSubtle, width: 1),
                ),
              ),
              SizedBox(width: spacing.xs),
              Text(
                status.cor,
                style: typography.bodySmall.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
        TFDataColumn<Status>(
          id: 'acoes',
          label: const Text('Ações'),
          width: 160,
          alignment: Alignment.centerRight,
          cellBuilder: (context, status) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TFIconButton(
                icon: TFIcons.edit,
                tooltip: 'Editar status "${status.status}"',
                variant: TFIconButtonVariant.standard,
                iconSize: 18,
                onPressed: () => _editStatus(status),
              ),
              TFIconButton(
                icon: Icons.copy_rounded,
                tooltip: 'Duplicar status "${status.status}"',
                variant: TFIconButtonVariant.subtle,
                iconSize: 18,
                onPressed: () => _duplicateStatus(status),
              ),
              TFIconButton(
                icon: TFIcons.delete,
                tooltip: 'Excluir status "${status.status}"',
                variant: TFIconButtonVariant.danger,
                iconSize: 18,
                onPressed: () => _deleteStatus(status),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
