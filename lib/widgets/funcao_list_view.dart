import 'package:flutter/material.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/funcao.dart';
import '../services/funcao_service.dart';
import 'funcao_form_dialog.dart';

class FuncaoListView extends StatefulWidget {
  const FuncaoListView({super.key});

  @override
  State<FuncaoListView> createState() => _FuncaoListViewState();
}

class _FuncaoListViewState extends State<FuncaoListView> {
  final FuncaoService _funcaoService = FuncaoService();
  List<Funcao> _funcoes = [];
  List<Funcao> _filteredFuncoes = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isTableView = false; // false = lista (cards), true = tabela

  @override
  void initState() {
    super.initState();
    _loadFuncoes();
    _searchController.addListener(_onSearchChanged);
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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFuncoes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final funcoes = await _funcaoService.getAllFuncoes();
      setState(() {
        _funcoes = funcoes;
        _filteredFuncoes = funcoes;
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao carregar funções: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar funções: $e'),
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
        _filteredFuncoes = _funcoes;
      });
    } else {
      _searchFuncoes(query);
    }
  }

  Future<void> _searchFuncoes(String query) async {
    try {
      final results = await _funcaoService.searchFuncoes(query);
      setState(() {
        _filteredFuncoes = results;
      });
    } catch (e) {
      print('Erro ao buscar funções: $e');
    }
  }

  Future<void> _createFuncao() async {
    final result = await showDialog<Funcao>(
      context: context,
      builder: (context) => const FuncaoFormDialog(),
    );

    if (result != null) {
      final created = await _funcaoService.createFuncao(result);
      if (created != null) {
        await _loadFuncoes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Função criada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao criar função.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _duplicateFuncao(Funcao funcao) async {
    final duplicated = funcao.copyWith(
      id: '',
      funcao: '${funcao.funcao} (Cópia)',
    );

    final result = await showDialog<Funcao>(
      context: context,
      builder: (context) => FuncaoFormDialog(funcao: duplicated),
    );

    if (result != null) {
      final created = await _funcaoService.createFuncao(result);
      if (created != null) {
        await _loadFuncoes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Função duplicada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao duplicar função'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editFuncao(Funcao funcao) async {
    final result = await showDialog<Funcao>(
      context: context,
      builder: (context) => FuncaoFormDialog(funcao: funcao),
    );

    if (result != null) {
      final updated = await _funcaoService.updateFuncao(funcao.id, result);
      if (updated != null) {
        await _loadFuncoes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Função atualizada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao atualizar função.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteFuncao(Funcao funcao) async {
    final confirm = await TFModalDialog.confirm(
      context: context,
      title: 'Confirmar exclusão',
      message: 'Deseja realmente excluir a função "${funcao.funcao}"?',
      confirmLabel: 'Excluir',
      cancelLabel: 'Cancelar',
      isDestructive: true,
    );

    if (confirm == true) {
      final deleted = await _funcaoService.deleteFuncao(funcao.id);
      if (deleted) {
        await _loadFuncoes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Função excluída com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao excluir função.'),
              backgroundColor: Colors.red,
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

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(spacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho Oficial TFPageHeader
              TFPageHeader(
                title: 'Cadastro de Funções',
                subtitle: 'Gestão de cargos, especialidades técnicas e permissões de executores',
                onBack: () => Navigator.of(context).maybePop(),
                primaryAction: TFButton(
                  label: 'Nova Função',
                  leadingIcon: TFIcons.add,
                  onPressed: _createFuncao,
                ),
                secondaryActions: [
                  TFIconButton(
                    icon: _isTableView ? Icons.view_list_rounded : Icons.table_chart_rounded,
                    tooltip: _isTableView ? 'Alternar para visualização em Lista' : 'Alternar para visualização em Tabela',
                    variant: TFIconButtonVariant.subtle,
                    onPressed: () {
                      setState(() {
                        _isTableView = !_isTableView;
                      });
                    },
                  ),
                  TFIconButton(
                    icon: TFIcons.refresh,
                    tooltip: 'Recarregar funções',
                    variant: TFIconButtonVariant.subtle,
                    onPressed: _loadFuncoes,
                  ),
                ],
              ),

              // Campo de Busca Padronizado TFTextField
              Padding(
                padding: EdgeInsets.only(bottom: spacing.base),
                child: TFTextField(
                  controller: _searchController,
                  hint: 'Buscar funções por nome ou descrição...',
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

              // Conteúdo da Lista ou Tabela
              Expanded(
                child: _isLoading
                    ? const TFLoading(
                        mode: TFLoadingMode.section,
                        message: 'Carregando funções cadastradas...',
                      )
                    : _filteredFuncoes.isEmpty
                        ? TFEmptyState(
                            icon: TFIcons.search,
                            title: 'Nenhuma função encontrada',
                            description: _searchController.text.isNotEmpty
                                ? 'Não foram encontradas funções correspondentes ao termo "${_searchController.text}".'
                                : 'Não existem funções cadastradas no sistema.',
                            action: _searchController.text.isNotEmpty
                                ? TFButton(
                                    label: 'Limpar Busca',
                                    variant: TFButtonVariant.secondary,
                                    onPressed: () => _searchController.clear(),
                                  )
                                : TFButton(
                                    label: 'Cadastrar Primeira Função',
                                    leadingIcon: TFIcons.add,
                                    variant: TFButtonVariant.primary,
                                    onPressed: _createFuncao,
                                  ),
                          )
                        : _isTableView
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
      itemCount: _filteredFuncoes.length,
      itemBuilder: (context, index) {
        final funcao = _filteredFuncoes[index];
        return Padding(
          padding: EdgeInsets.only(bottom: spacing.sm),
          child: TFCard(
            variant: TFCardVariant.defaultCard,
            padding: EdgeInsets.symmetric(horizontal: spacing.base, vertical: spacing.sm),
            child: Row(
              children: [
                // Status visual acessível (cor + texto + ícone)
                TFStatusBadge(
                  label: funcao.ativo ? 'Ativo' : 'Inativo',
                  severity: funcao.ativo ? TFStatusSeverity.success : TFStatusSeverity.neutral,
                  icon: funcao.ativo ? TFIcons.success : TFIcons.warning,
                  compact: true,
                ),
                SizedBox(width: spacing.md),
                // Textos descritivos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        funcao.funcao,
                        style: typography.cardTitle.copyWith(color: colors.textPrimary),
                      ),
                      if (funcao.descricao != null && funcao.descricao!.isNotEmpty) ...[
                        SizedBox(height: spacing.xxs),
                        Text(
                          funcao.descricao!,
                          style: typography.bodySmall.copyWith(color: colors.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // Ações padronizadas com TFIconButton
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TFIconButton(
                      icon: TFIcons.edit,
                      tooltip: 'Editar função "${funcao.funcao}"',
                      variant: TFIconButtonVariant.standard,
                      onPressed: () => _editFuncao(funcao),
                    ),
                    TFIconButton(
                      icon: Icons.copy_rounded,
                      tooltip: 'Duplicar função "${funcao.funcao}"',
                      variant: TFIconButtonVariant.subtle,
                      onPressed: () => _duplicateFuncao(funcao),
                    ),
                    TFIconButton(
                      icon: TFIcons.delete,
                      tooltip: 'Excluir função "${funcao.funcao}"',
                      variant: TFIconButtonVariant.danger,
                      onPressed: () => _deleteFuncao(funcao),
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

    return TFDataTable<Funcao>(
      items: _filteredFuncoes,
      zebra: true,
      columns: [
        TFDataColumn<Funcao>.text(
          id: 'funcao',
          title: 'Função',
          cellBuilder: (context, funcao) => Text(
            funcao.funcao,
            style: typography.bodyMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        TFDataColumn<Funcao>.text(
          id: 'descricao',
          title: 'Descrição',
          cellBuilder: (context, funcao) => Text(
            funcao.descricao != null && funcao.descricao!.isNotEmpty
                ? funcao.descricao!
                : '-',
            style: typography.bodySmall.copyWith(color: colors.textSecondary),
          ),
        ),
        TFDataColumn<Funcao>(
          id: 'status',
          label: const Text('Status'),
          width: 130,
          cellBuilder: (context, funcao) => Align(
            alignment: Alignment.centerLeft,
            child: TFStatusBadge(
              label: funcao.ativo ? 'Ativo' : 'Inativo',
              severity: funcao.ativo ? TFStatusSeverity.success : TFStatusSeverity.neutral,
              icon: funcao.ativo ? TFIcons.success : TFIcons.warning,
              compact: true,
            ),
          ),
        ),
        TFDataColumn<Funcao>(
          id: 'acoes',
          label: const Text('Ações'),
          width: 160,
          alignment: Alignment.centerRight,
          cellBuilder: (context, funcao) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TFIconButton(
                icon: TFIcons.edit,
                tooltip: 'Editar função "${funcao.funcao}"',
                variant: TFIconButtonVariant.standard,
                iconSize: 18,
                onPressed: () => _editFuncao(funcao),
              ),
              TFIconButton(
                icon: Icons.copy_rounded,
                tooltip: 'Duplicar função "${funcao.funcao}"',
                variant: TFIconButtonVariant.subtle,
                iconSize: 18,
                onPressed: () => _duplicateFuncao(funcao),
              ),
              TFIconButton(
                icon: TFIcons.delete,
                tooltip: 'Excluir função "${funcao.funcao}"',
                variant: TFIconButtonVariant.danger,
                iconSize: 18,
                onPressed: () => _deleteFuncao(funcao),
              ),
            ],
          ),
        ),
      ],
    );
  }

}
