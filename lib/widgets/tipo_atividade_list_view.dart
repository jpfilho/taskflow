import 'package:flutter/material.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/tipo_atividade.dart';
import '../services/tipo_atividade_service.dart';
import 'tipo_atividade_form_dialog.dart';

class TipoAtividadeListView extends StatefulWidget {
  const TipoAtividadeListView({super.key});

  @override
  State<TipoAtividadeListView> createState() => _TipoAtividadeListViewState();
}

class _TipoAtividadeListViewState extends State<TipoAtividadeListView> {
  final TipoAtividadeService _tipoAtividadeService = TipoAtividadeService();
  List<TipoAtividade> _tiposAtividade = [];
  List<TipoAtividade> _filteredTiposAtividade = [];
  bool _isLoading = true;
  bool _isTableView = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTiposAtividade();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTiposAtividade() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final tipos = await _tipoAtividadeService.getAllTiposAtividade();
      setState(() {
        _tiposAtividade = tipos;
        _filteredTiposAtividade = tipos;
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao carregar tipos de atividade: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar tipos de atividade: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _filteredTiposAtividade = _tiposAtividade;
      });
    } else {
      _searchTiposAtividade(query);
    }
  }

  Future<void> _searchTiposAtividade(String query) async {
    try {
      final results = await _tipoAtividadeService.searchTiposAtividade(query);
      setState(() {
        _filteredTiposAtividade = results;
      });
    } catch (e) {
      print('Erro ao buscar tipos de atividade: $e');
    }
  }

  Future<void> _createTipoAtividade() async {
    final result = await showDialog<TipoAtividade>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const TipoAtividadeFormDialog(),
    );

    if (result != null) {
      final created = await _tipoAtividadeService.createTipoAtividade(result);
      if (created != null) {
        await _loadTiposAtividade();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tipo de atividade criado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao criar tipo de atividade.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _duplicateTipoAtividade(TipoAtividade tipoAtividade) async {
    final tipoAtualizado = await _tipoAtividadeService.getTipoAtividadeById(tipoAtividade.id);
    if (tipoAtualizado == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao carregar dados do tipo de atividade'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    final duplicated = tipoAtualizado.copyWith(
      id: '',
      codigo: '${tipoAtualizado.codigo}CP',
      descricao: '${tipoAtualizado.descricao} (Cópia)',
    );

    final result = await showDialog<TipoAtividade>(
      context: context,
      barrierDismissible: true,
      builder: (context) => TipoAtividadeFormDialog(tipoAtividade: duplicated),
    );

    if (result != null) {
      final created = await _tipoAtividadeService.createTipoAtividade(result);
      if (created != null) {
        await _loadTiposAtividade();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tipo de atividade duplicado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao duplicar tipo de atividade.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editTipoAtividade(TipoAtividade tipoAtividade) async {
    final tipoAtualizado = await _tipoAtividadeService.getTipoAtividadeById(tipoAtividade.id);
    if (tipoAtualizado == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao carregar dados do tipo de atividade'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    final result = await showDialog<TipoAtividade>(
      context: context,
      barrierDismissible: true,
      builder: (context) => TipoAtividadeFormDialog(tipoAtividade: tipoAtualizado),
    );

    if (result != null) {
      final updated = await _tipoAtividadeService.updateTipoAtividade(tipoAtividade.id, result);
      if (updated != null) {
        await _loadTiposAtividade();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tipo de atividade atualizado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao atualizar tipo de atividade.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteTipoAtividade(TipoAtividade tipoAtividade) async {
    final confirm = await TFModalDialog.confirm(
      context: context,
      title: 'Confirmar exclusão',
      message: 'Deseja realmente excluir o tipo de atividade "${tipoAtividade.descricao}" (${tipoAtividade.codigo})?',
      confirmLabel: 'Excluir',
      cancelLabel: 'Cancelar',
      isDestructive: true,
    );

    if (confirm == true) {
      final deleted = await _tipoAtividadeService.deleteTipoAtividade(tipoAtividade.id);
      if (deleted) {
        await _loadTiposAtividade();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tipo de atividade excluído com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao excluir tipo de atividade.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = TFBreakpoints.isMobile(context);
    final spacing = context.tfSpacing;
    final colors = context.tfColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? spacing.sm : spacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TFPageHeader(
                title: 'Tipos de Atividade',
                subtitle: 'Configuração de categorias, cores do Gantt e segmentos operacionais',
                onBack: () => Navigator.of(context).pop(),
                primaryAction: TFButton(
                  label: 'Novo Tipo',
                  leadingIcon: TFIcons.add,
                  onPressed: _createTipoAtividade,
                ),
                secondaryActions: [
                  TFIconButton(
                    icon: _isTableView ? Icons.view_list_rounded : Icons.table_chart_rounded,
                    tooltip: _isTableView ? 'Visualizar em Lista' : 'Visualizar em Tabela',
                    variant: TFIconButtonVariant.subtle,
                    onPressed: () {
                      setState(() {
                        _isTableView = !_isTableView;
                      });
                    },
                  ),
                  TFIconButton(
                    icon: TFIcons.refresh,
                    tooltip: 'Recarregar tipos',
                    variant: TFIconButtonVariant.subtle,
                    onPressed: _loadTiposAtividade,
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.only(bottom: spacing.base),
                child: TFTextField(
                  controller: _searchController,
                  hint: 'Buscar por código ou descrição...',
                  prefixIcon: Icon(TFIcons.search, size: 18, color: colors.textSecondary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(TFIcons.close, size: 16, color: colors.textMuted),
                          onPressed: () => _searchController.clear(),
                          tooltip: 'Limpar busca',
                        )
                      : null,
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const TFLoading(
                        mode: TFLoadingMode.section,
                        message: 'Carregando tipos de atividade...',
                      )
                    : _filteredTiposAtividade.isEmpty
                        ? TFEmptyState(
                            icon: TFIcons.search,
                            title: _tiposAtividade.isEmpty
                                ? 'Nenhum tipo cadastrado'
                                : 'Nenhum tipo de atividade encontrado',
                            description: _tiposAtividade.isEmpty
                                ? 'Cadastre o primeiro tipo de atividade para parametrizar tarefas.'
                                : 'Tente buscar por outro termo ou limpe o campo de busca.',
                            action: _tiposAtividade.isEmpty
                                ? TFButton(
                                    label: 'Cadastrar Primeiro Tipo',
                                    leadingIcon: TFIcons.add,
                                    onPressed: _createTipoAtividade,
                                  )
                                : TFButton(
                                    label: 'Limpar Busca',
                                    variant: TFButtonVariant.secondary,
                                    onPressed: () => _searchController.clear(),
                                  ),
                          )
                        : (isMobile || !_isTableView)
                            ? _buildMobileList()
                            : _buildDesktopTable(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTable() {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return TFDataTable<TipoAtividade>(
      items: _filteredTiposAtividade,
      zebra: true,
      columns: [
        TFDataColumn<TipoAtividade>.text(
          id: 'codigo',
          title: 'Código',
          width: 120,
          cellBuilder: (context, tipo) => Text(
            tipo.codigo,
            style: typography.bodyMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TFDataColumn<TipoAtividade>.text(
          id: 'descricao',
          title: 'Descrição',
          cellBuilder: (context, tipo) => Text(
            tipo.descricao,
            style: typography.bodyMedium.copyWith(color: colors.textPrimary),
          ),
        ),
        TFDataColumn<TipoAtividade>(
          id: 'cor',
          label: const Text('Cor'),
          width: 80,
          cellBuilder: (context, tipo) => Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: tipo.cor != null && tipo.cor!.isNotEmpty
                  ? Color(int.parse(tipo.cor!.replaceFirst('#', '0xFF')))
                  : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(color: colors.borderSubtle),
            ),
          ),
        ),
        TFDataColumn<TipoAtividade>(
          id: 'status',
          label: const Text('Status'),
          width: 110,
          cellBuilder: (context, tipo) => TFStatusBadge(
            label: tipo.ativo ? 'Ativo' : 'Inativo',
            severity: tipo.ativo ? TFStatusSeverity.success : TFStatusSeverity.neutral,
            compact: true,
          ),
        ),
        TFDataColumn<TipoAtividade>(
          id: 'acoes',
          label: const Text('Ações'),
          width: 160,
          alignment: Alignment.centerRight,
          cellBuilder: (context, tipo) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TFIconButton(
                icon: TFIcons.edit,
                tooltip: 'Editar tipo',
                variant: TFIconButtonVariant.standard,
                onPressed: () => _editTipoAtividade(tipo),
              ),
              TFIconButton(
                icon: Icons.copy_rounded,
                tooltip: 'Duplicar tipo',
                variant: TFIconButtonVariant.subtle,
                onPressed: () => _duplicateTipoAtividade(tipo),
              ),
              TFIconButton(
                icon: TFIcons.delete,
                tooltip: 'Excluir tipo',
                variant: TFIconButtonVariant.danger,
                onPressed: () => _deleteTipoAtividade(tipo),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileList() {
    final spacing = context.tfSpacing;
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return ListView.separated(
      itemCount: _filteredTiposAtividade.length,
      separatorBuilder: (_, __) => SizedBox(height: spacing.sm),
      itemBuilder: (context, index) {
        final tipo = _filteredTiposAtividade[index];
        return TFCard(
          variant: TFCardVariant.defaultCard,
          padding: EdgeInsets.symmetric(horizontal: spacing.base, vertical: spacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: tipo.cor != null && tipo.cor!.isNotEmpty
                              ? Color(int.parse(tipo.cor!.replaceFirst('#', '0xFF')))
                              : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: spacing.xs),
                      Text(
                        tipo.codigo,
                        style: typography.cardTitle.copyWith(color: colors.textPrimary),
                      ),
                    ],
                  ),
                  TFStatusBadge(
                    label: tipo.ativo ? 'Ativo' : 'Inativo',
                    severity: tipo.ativo ? TFStatusSeverity.success : TFStatusSeverity.neutral,
                    compact: true,
                  ),
                ],
              ),
              SizedBox(height: spacing.xs),
              Text(
                tipo.descricao,
                style: typography.bodyMedium.copyWith(color: colors.textSecondary),
              ),
              SizedBox(height: spacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TFButton(
                    label: 'Editar',
                    leadingIcon: TFIcons.edit,
                    variant: TFButtonVariant.secondary,
                    onPressed: () => _editTipoAtividade(tipo),
                  ),
                  SizedBox(width: spacing.xs),
                  TFIconButton(
                    icon: Icons.copy_rounded,
                    tooltip: 'Duplicar',
                    variant: TFIconButtonVariant.subtle,
                    onPressed: () => _duplicateTipoAtividade(tipo),
                  ),
                  TFIconButton(
                    icon: TFIcons.delete,
                    tooltip: 'Excluir',
                    variant: TFIconButtonVariant.danger,
                    onPressed: () => _deleteTipoAtividade(tipo),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
