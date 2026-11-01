import 'package:flutter/material.dart';
import '../../design_system/theme/taskflow_theme_extension.dart';
import '../../design_system/foundations/tf_radius.dart';
import '../../models/nota_sap_analise.dart';
import '../../services/nota_sap_analise_service.dart';

class NotaWorkspaceMaterialsTab extends StatefulWidget {
  final String notaSapId;
  final String? analiseId;
  final NotaSapAnaliseService service;

  const NotaWorkspaceMaterialsTab({
    super.key,
    required this.notaSapId,
    this.analiseId,
    required this.service,
  });

  @override
  State<NotaWorkspaceMaterialsTab> createState() =>
      _NotaWorkspaceMaterialsTabState();
}

class _NotaWorkspaceMaterialsTabState extends State<NotaWorkspaceMaterialsTab> {
  List<NotaSapMaterial> _materiais = [];
  bool _isLoading = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarMateriais();
  }

  Future<void> _carregarMateriais() async {
    setState(() {
      _isLoading = true;
      _erro = null;
    });

    try {
      final list = await widget.service.listarMateriais(widget.notaSapId);
      if (mounted) {
        setState(() {
          _materiais = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = 'Não foi possível carregar os materiais: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _abrirDialogFormulario([NotaSapMaterial? materialExistente]) async {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    final isEdicao = materialExistente != null;
    final formKey = GlobalKey<FormState>();

    final codigoController =
        TextEditingController(text: materialExistente?.codigoSap ?? '');
    final descricaoController =
        TextEditingController(text: materialExistente?.descricao ?? '');
    final quantidadeController = TextEditingController(
        text: (materialExistente?.quantidade ?? 1.0).toString());
    final unidadeController =
        TextEditingController(text: materialExistente?.unidade ?? 'UN');
    final observacaoController =
        TextEditingController(text: materialExistente?.observacao ?? '');
    var status =
        materialExistente?.statusMaterial ?? NotaMaterialStatus.naoVerificado;

    final salvou = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(TFRadius.r12),
                side: BorderSide(color: colors.borderSubtle),
              ),
              title: Text(
                isEdicao ? 'Editar Material' : 'Adicionar Material',
                style: typography.sectionTitle
                    .copyWith(color: colors.textPrimary),
              ),
              content: SizedBox(
                width: 480,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: codigoController,
                                decoration: InputDecoration(
                                  labelText: 'Código SAP',
                                  hintText: 'Ex: 104256',
                                  filled: true,
                                  fillColor: colors.surfaceSecondary,
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(TFRadius.r8),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: spacing.md),
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<NotaMaterialStatus>(
                                isExpanded: true,
                                initialValue: status,
                                decoration: InputDecoration(
                                  labelText: 'Status do Material',
                                  filled: true,
                                  fillColor: colors.surfaceSecondary,
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(TFRadius.r8),
                                  ),
                                ),
                                items: NotaMaterialStatus.values.map((s) {
                                  return DropdownMenuItem(
                                    value: s,
                                    child: Text(
                                      s.label,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _getMaterialStatusColor(s),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() => status = val);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: spacing.md),
                        TextFormField(
                          controller: descricaoController,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Informe a descrição do material';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: 'Descrição *',
                            hintText: 'Ex: Disjuntor Tripolar 200A 69kV...',
                            filled: true,
                            fillColor: colors.surfaceSecondary,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(TFRadius.r8),
                            ),
                          ),
                        ),
                        SizedBox(height: spacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: quantidadeController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Obrigatório';
                                  }
                                  final n = double.tryParse(
                                      val.replaceAll(',', '.'));
                                  if (n == null || n <= 0) {
                                    return 'Qtd inválida';
                                  }
                                  return null;
                                },
                                decoration: InputDecoration(
                                  labelText: 'Quantidade *',
                                  filled: true,
                                  fillColor: colors.surfaceSecondary,
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(TFRadius.r8),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: spacing.md),
                            Expanded(
                              child: TextFormField(
                                controller: unidadeController,
                                decoration: InputDecoration(
                                  labelText: 'Unidade',
                                  hintText: 'UN, M, KG, PC...',
                                  filled: true,
                                  fillColor: colors.surfaceSecondary,
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(TFRadius.r8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: spacing.md),
                        TextFormField(
                          controller: observacaoController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Observação / Reserva',
                            hintText: 'Ex: Material localizado no almoxarifado central...',
                            filled: true,
                            fillColor: colors.surfaceSecondary,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(TFRadius.r8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text('Cancelar',
                      style: TextStyle(color: colors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.primaryForeground,
                  ),
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      final qtd = double.parse(
                          quantidadeController.text.replaceAll(',', '.'));
                      final novoMaterial = NotaSapMaterial(
                        id: materialExistente?.id,
                        notaSapId: widget.notaSapId,
                        analiseId: widget.analiseId,
                        codigoSap: codigoController.text.trim().isEmpty
                            ? null
                            : codigoController.text.trim(),
                        descricao: descricaoController.text.trim(),
                        quantidade: qtd,
                        unidade: unidadeController.text.trim().isEmpty
                            ? 'UN'
                            : unidadeController.text.trim().toUpperCase(),
                        statusMaterial: status,
                        observacao: observacaoController.text.trim().isEmpty
                            ? null
                            : observacaoController.text.trim(),
                        createdAt: materialExistente?.createdAt ?? DateTime.now(),
                        updatedAt: DateTime.now(),
                      );

                      try {
                        if (isEdicao) {
                          await widget.service.atualizarMaterial(novoMaterial);
                        } else {
                          await widget.service.adicionarMaterial(novoMaterial);
                        }
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop(true);
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('Erro ao salvar material: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: Text(isEdicao ? 'Salvar' : 'Adicionar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (salvou == true) {
      _carregarMateriais();
    }
  }

  Future<void> _confirmarExclusao(NotaSapMaterial mat) async {
    if (mat.id == null) return;
    final colors = context.tfColors;
    final typography = context.tfTypography;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Excluir Material',
            style: typography.sectionTitle.copyWith(color: colors.textPrimary)),
        content: Text(
          'Deseja realmente remover o material "${mat.descricao}" da lista?',
          style: typography.bodyMedium.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar',
                style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmou == true) {
      try {
        await widget.service.excluirMaterial(mat.id!);
        _carregarMateriais();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Material removido com sucesso'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir material: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Color _getMaterialStatusColor(NotaMaterialStatus s) {
    switch (s) {
      case NotaMaterialStatus.naoVerificado:
        return Colors.grey.shade600;
      case NotaMaterialStatus.disponivel:
        return Colors.green.shade700;
      case NotaMaterialStatus.reservado:
        return Colors.blue.shade700;
      case NotaMaterialStatus.aguardandoMaterial:
        return Colors.orange.shade800;
      case NotaMaterialStatus.aguardandoCompra:
        return Colors.amber.shade900;
      case NotaMaterialStatus.substituido:
        return Colors.purple.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    final isWide = MediaQuery.of(context).size.width >= 800;

    return SingleChildScrollView(
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.md,
              vertical: spacing.sm,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceSecondary,
              borderRadius: BorderRadius.circular(TFRadius.r8),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined,
                    color: colors.primary, size: 20),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: Text(
                    'Materiais previstos ou reservados para a intervenção. Esta lista é puramente de apoio e NÃO bloqueia a programação da Nota SAP.',
                    style: typography.caption.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(width: spacing.sm),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.primaryForeground,
                    padding: EdgeInsets.symmetric(
                      horizontal: spacing.md,
                      vertical: spacing.sm,
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Adicionar Material'),
                  onPressed: () => _abrirDialogFormulario(),
                ),
              ],
            ),
          ),

          SizedBox(height: spacing.md),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_erro != null)
            Container(
              padding: EdgeInsets.all(spacing.lg),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(20),
                borderRadius: BorderRadius.circular(TFRadius.r8),
                border: Border.all(color: Colors.red.withAlpha(80)),
              ),
              child: Column(
                children: [
                  Text(_erro!,
                      style: TextStyle(color: Colors.red.shade800),
                      textAlign: TextAlign.center),
                  SizedBox(height: spacing.md),
                  OutlinedButton(
                    onPressed: _carregarMateriais,
                    child: const Text('Tentar Novamente'),
                  ),
                ],
              ),
            )
          else if (_materiais.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(TFRadius.r12),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category_outlined,
                      size: 48, color: colors.textSecondary.withAlpha(120)),
                  SizedBox(height: spacing.md),
                  Text(
                    'Nenhum material cadastrado para esta Nota SAP',
                    style: typography.bodyMedium.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    'Clique em "Adicionar Material" para registrar peças, cabos ou insumos necessários.',
                    style: typography.caption
                        .copyWith(color: colors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else if (isWide)
            _buildTabelaDesktop(colors, typography, spacing)
          else
            _buildCardsMobile(colors, typography, spacing),
        ],
      ),
    );
  }

  Widget _buildTabelaDesktop(
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(TFRadius.r12),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TFRadius.r12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor:
                WidgetStateProperty.all(colors.surfaceSecondary),
            columns: const [
              DataColumn(label: Text('Código SAP')),
              DataColumn(label: Text('Descrição')),
              DataColumn(label: Text('Qtd.')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Observação')),
              DataColumn(label: Text('Ações')),
            ],
            rows: _materiais.map((mat) {
              final statusColor = _getMaterialStatusColor(mat.statusMaterial);

              return DataRow(
                cells: [
                  DataCell(
                    Text(mat.codigoSap ?? '-',
                        style: typography.bodyMedium
                            .copyWith(fontWeight: FontWeight.w600)),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: Text(
                        mat.descricao,
                        style: typography.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      '${mat.quantidade.toString().replaceAll('.0', '')} ${mat.unidade}',
                      style: typography.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: statusColor.withAlpha(100)),
                      ),
                      child: Text(
                        mat.statusMaterial.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        mat.observacao ?? '-',
                        style: typography.caption
                            .copyWith(color: colors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          color: colors.primary,
                          tooltip: 'Editar',
                          onPressed: () => _abrirDialogFormulario(mat),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          color: Colors.red.shade600,
                          tooltip: 'Excluir',
                          onPressed: () => _confirmarExclusao(mat),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildCardsMobile(
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _materiais.length,
      separatorBuilder: (_, __) => SizedBox(height: spacing.sm),
      itemBuilder: (context, index) {
        final mat = _materiais[index];
        final statusColor = _getMaterialStatusColor(mat.statusMaterial);

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TFRadius.r8),
            side: BorderSide(color: colors.borderSubtle),
          ),
          color: colors.surface,
          child: Padding(
            padding: EdgeInsets.all(spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (mat.codigoSap != null &&
                              mat.codigoSap!.isNotEmpty)
                            Text(
                              'SAP: ${mat.codigoSap}',
                              style: typography.caption.copyWith(
                                color: colors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          Text(
                            mat.descricao,
                            style: typography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: statusColor.withAlpha(100)),
                      ),
                      child: Text(
                        mat.statusMaterial.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: spacing.sm),
                Row(
                  children: [
                    Text(
                      'Quantidade: ${mat.quantidade.toString().replaceAll('.0', '')} ${mat.unidade}',
                      style: typography.caption.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      color: colors.primary,
                      onPressed: () => _abrirDialogFormulario(mat),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: Colors.red.shade600,
                      onPressed: () => _confirmarExclusao(mat),
                    ),
                  ],
                ),
                if (mat.observacao != null && mat.observacao!.isNotEmpty) ...[
                  Divider(height: spacing.md, color: colors.borderSubtle),
                  Text(
                    'Obs: ${mat.observacao}',
                    style: typography.caption
                        .copyWith(color: colors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
