import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../design_system/theme/taskflow_theme_extension.dart';
import '../../design_system/foundations/tf_radius.dart';
import '../../models/nota_sap.dart';
import '../../models/nota_sap_tag.dart';
import '../../services/auth_service_simples.dart';
import '../../services/nota_sap_tag_service.dart';
import 'nota_tag_selector_dialog.dart';

class NotaWorkspaceOverviewTab extends StatefulWidget {
  final NotaSAP nota;
  final NotaSapTagService? tagService;
  final VoidCallback? onTagsChanged;

  const NotaWorkspaceOverviewTab({
    super.key,
    required this.nota,
    this.tagService,
    this.onTagsChanged,
  });

  @override
  State<NotaWorkspaceOverviewTab> createState() => _NotaWorkspaceOverviewTabState();
}

class _NotaWorkspaceOverviewTabState extends State<NotaWorkspaceOverviewTab> {
  late final NotaSapTagService _tagService;
  List<NotaSapTag> _tagsDaNota = [];
  bool _carregandoTags = true;
  String? _erroTags;

  @override
  void initState() {
    super.initState();
    _tagService = widget.tagService ?? NotaSapTagService();
    _carregarTags();
  }

  @override
  void didUpdateWidget(covariant NotaWorkspaceOverviewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nota.id != widget.nota.id) {
      _carregarTags();
    }
  }

  Future<void> _carregarTags() async {
    setState(() {
      _carregandoTags = true;
      _erroTags = null;
    });

    try {
      final tags = await _tagService.listarTagsDaNota(widget.nota.id);
      if (mounted) {
        setState(() {
          _tagsDaNota = tags;
          _carregandoTags = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erroTags = 'Erro ao carregar tags: $e';
          _carregandoTags = false;
        });
      }
    }
  }

  Future<void> _adicionarTag() async {
    final tagEscolhida = await NotaSapTagSelectorDialog.show(
      context,
      notaSapId: widget.nota.id,
      tagsAtuaisDaNota: _tagsDaNota,
      tagService: _tagService,
    );

    if (!mounted) return;
    if (tagEscolhida == null || tagEscolhida.id == null) return;

    final user = AuthServiceSimples().currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum usuário logado para vincular a tag.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await _tagService.vincularTag(
        notaSapId: widget.nota.id,
        tagId: tagEscolhida.id!,
        usuario: user,
      );

      await _carregarTags();
      widget.onTagsChanged?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tag "${tagEscolhida.nome}" vinculada à nota.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao vincular tag: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _removerTag(NotaSapTag tag) async {
    if (tag.id == null) return;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover Tag da Nota'),
        content: Text('Deseja desvincular a tag "${tag.nome}" desta nota?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmou != true) return;

    try {
      await _tagService.desvincularTag(
        notaSapId: widget.nota.id,
        tagId: tag.id!,
      );

      await _carregarTags();
      widget.onTagsChanged?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tag "${tag.nome}" desvinculada.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao desvincular tag: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Color _corDaTag(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.blueGrey;
    try {
      final cleaned = hex.replaceAll('#', '');
      return Color(int.parse('0xFF$cleaned'));
    } catch (_) {
      return Colors.blueGrey;
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    if (dt.hour == 0 && dt.minute == 0) {
      return '$d/$m/$y';
    }
    return '$d/$m/$y $h:$min';
  }

  void _copiarTexto(BuildContext context, String rotulo, String valor) {
    Clipboard.setData(ClipboardData(text: valor));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$rotulo copiado para a área de transferência'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
          // Banner de prazo / vencimento se existir
          if (widget.nota.dataVencimento != null || widget.nota.diasRestantes != null)
            _buildPrazoBanner(context, colors, typography, spacing),

          SizedBox(height: spacing.md),

          // Seção TAGS (Requisitos 49 e 50)
          _buildTagsCard(context),

          SizedBox(height: spacing.md),

          // Seção 1: Identificação e Localização (em 2 colunas se wide)
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildCard(
                    context,
                    title: 'Identificação SAP',
                    icon: Icons.assignment_outlined,
                    children: [
                      _buildInfoRow(context, 'Número da Nota', widget.nota.nota,
                          isCopyable: true),
                      _buildInfoRow(context, 'Ordem Vinculada', widget.nota.ordem ?? '-',
                          isCopyable: widget.nota.ordem != null && widget.nota.ordem!.isNotEmpty),
                      _buildInfoRow(context, 'Tipo de Nota', widget.nota.tipo ?? '-'),
                      _buildInfoRow(context, 'Prioridade', widget.nota.textPrioridade ?? '-'),
                      _buildInfoRow(context, 'Descrição', widget.nota.descricao ?? '-'),
                    ],
                  ),
                ),
                SizedBox(width: spacing.md),
                Expanded(
                  child: _buildCard(
                    context,
                    title: 'Localização e Ativo',
                    icon: Icons.location_on_outlined,
                    children: [
                      _buildInfoRow(context, 'Local de Instalação',
                          widget.nota.localInstalacao ?? '-'),
                      _buildInfoRow(context, 'Local', widget.nota.local ?? '-'),
                      _buildInfoRow(context, 'Sala', widget.nota.sala ?? '-'),
                      _buildInfoRow(context, 'Equipamento', widget.nota.equipamento ?? '-'),
                      _buildInfoRow(context, 'Centro de Trabalho',
                          widget.nota.centroTrabalhoResponsavel ?? '-'),
                      _buildInfoRow(context, 'Executor',
                          widget.nota.denominacaoExecutor ?? '-'),
                      _buildInfoRow(context, 'GPM', widget.nota.gpm ?? '-'),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            _buildCard(
              context,
              title: 'Identificação SAP',
              icon: Icons.assignment_outlined,
              children: [
                _buildInfoRow(context, 'Número da Nota', widget.nota.nota,
                    isCopyable: true),
                _buildInfoRow(context, 'Ordem Vinculada', widget.nota.ordem ?? '-',
                    isCopyable: widget.nota.ordem != null && widget.nota.ordem!.isNotEmpty),
                _buildInfoRow(context, 'Tipo de Nota', widget.nota.tipo ?? '-'),
                _buildInfoRow(context, 'Prioridade', widget.nota.textPrioridade ?? '-'),
                _buildInfoRow(context, 'Descrição', widget.nota.descricao ?? '-'),
              ],
            ),
            SizedBox(height: spacing.md),
            _buildCard(
              context,
              title: 'Localização e Ativo',
              icon: Icons.location_on_outlined,
              children: [
                _buildInfoRow(context, 'Local de Instalação',
                    widget.nota.localInstalacao ?? '-'),
                _buildInfoRow(context, 'Local', widget.nota.local ?? '-'),
                _buildInfoRow(context, 'Sala', widget.nota.sala ?? '-'),
                _buildInfoRow(context, 'Equipamento', widget.nota.equipamento ?? '-'),
                _buildInfoRow(context, 'Centro de Trabalho',
                    widget.nota.centroTrabalhoResponsavel ?? '-'),
                _buildInfoRow(context, 'Executor',
                    widget.nota.denominacaoExecutor ?? '-'),
                _buildInfoRow(context, 'GPM', widget.nota.gpm ?? '-'),
              ],
            ),
          ],

          SizedBox(height: spacing.md),

          // Seção 2: Status e Datas (em 2 colunas se wide)
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildCard(
                    context,
                    title: 'Status do Sistema e Usuário',
                    icon: Icons.info_outline,
                    children: [
                      _buildInfoRow(context, 'Status do Sistema',
                          widget.nota.statusSistema ?? '-'),
                      _buildInfoRow(context, 'Status do Usuário',
                          widget.nota.statusUsuario ?? '-'),
                      _buildInfoRow(context, 'Centro', widget.nota.centro ?? '-'),
                      if (widget.nota.tarefaId != null)
                        _buildInfoRow(context, 'Tarefa Vinculada',
                            widget.nota.tarefaNome ?? widget.nota.tarefaId!),
                      if (widget.nota.tarefaStatus != null)
                        _buildInfoRow(
                            context, 'Status Tarefa', widget.nota.tarefaStatus!),
                    ],
                  ),
                ),
                SizedBox(width: spacing.md),
                Expanded(
                  child: _buildCard(
                    context,
                    title: 'Datas e Prazos',
                    icon: Icons.calendar_today_outlined,
                    children: [
                      _buildInfoRow(
                          context, 'Data de Criação', _formatDate(widget.nota.criadoEm)),
                      _buildInfoRow(context, 'Início Desejado',
                          _formatDate(widget.nota.inicioDesejado)),
                      _buildInfoRow(context, 'Conclusão Desejada',
                          _formatDate(widget.nota.conclusaoDesejada)),
                      _buildInfoRow(context, 'Data de Vencimento',
                          _formatDate(widget.nota.dataVencimento)),
                      if (widget.nota.inicioAvaria != null)
                        _buildInfoRow(context, 'Início da Avaria',
                            _formatDate(widget.nota.inicioAvaria)),
                      if (widget.nota.fimAvaria != null)
                        _buildInfoRow(context, 'Fim da Avaria',
                            _formatDate(widget.nota.fimAvaria)),
                      if (widget.nota.encerramento != null)
                        _buildInfoRow(context, 'Encerramento',
                            _formatDate(widget.nota.encerramento)),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            _buildCard(
              context,
              title: 'Status do Sistema e Usuário',
              icon: Icons.info_outline,
              children: [
                _buildInfoRow(
                    context, 'Status do Sistema', widget.nota.statusSistema ?? '-'),
                _buildInfoRow(
                    context, 'Status do Usuário', widget.nota.statusUsuario ?? '-'),
                _buildInfoRow(context, 'Centro', widget.nota.centro ?? '-'),
                if (widget.nota.tarefaId != null)
                  _buildInfoRow(context, 'Tarefa Vinculada',
                      widget.nota.tarefaNome ?? widget.nota.tarefaId!),
                if (widget.nota.tarefaStatus != null)
                  _buildInfoRow(context, 'Status Tarefa', widget.nota.tarefaStatus!),
              ],
            ),
            SizedBox(height: spacing.md),
            _buildCard(
              context,
              title: 'Datas e Prazos',
              icon: Icons.calendar_today_outlined,
              children: [
                _buildInfoRow(
                    context, 'Data de Criação', _formatDate(widget.nota.criadoEm)),
                _buildInfoRow(context, 'Início Desejado',
                    _formatDate(widget.nota.inicioDesejado)),
                _buildInfoRow(context, 'Conclusão Desejada',
                    _formatDate(widget.nota.conclusaoDesejada)),
                _buildInfoRow(context, 'Data de Vencimento',
                    _formatDate(widget.nota.dataVencimento)),
                if (widget.nota.inicioAvaria != null)
                  _buildInfoRow(context, 'Início da Avaria',
                      _formatDate(widget.nota.inicioAvaria)),
                if (widget.nota.fimAvaria != null)
                  _buildInfoRow(
                      context, 'Fim da Avaria', _formatDate(widget.nota.fimAvaria)),
                if (widget.nota.encerramento != null)
                  _buildInfoRow(
                      context, 'Encerramento', _formatDate(widget.nota.encerramento)),
              ],
            ),
          ],

          // Seção 3: Detalhes / Texto Longo (se houver)
          if (widget.nota.detalhes != null && widget.nota.detalhes!.trim().isNotEmpty) ...[
            SizedBox(height: spacing.md),
            _buildCard(
              context,
              title: 'Descrição Detalhada / Observações SAP',
              icon: Icons.notes_outlined,
              children: [
                SelectableText(
                  widget.nota.detalhes!,
                  style: typography.bodyMedium
                      .copyWith(color: colors.textPrimary, height: 1.4),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTagsCard(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(TFRadius.r12),
        border: Border.all(color: colors.borderSubtle),
      ),
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sell_outlined, size: 18, color: colors.primary),
              SizedBox(width: spacing.xs),
              Expanded(
                child: Text(
                  'Tags da Nota',
                  style: typography.sectionTitle.copyWith(
                    color: colors.textPrimary,
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _adicionarTag,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Adicionar Tag', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
              ),
            ],
          ),
          Divider(height: spacing.lg, color: colors.borderSubtle),
          if (_carregandoTags)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_erroTags != null)
            Text(
              _erroTags!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            )
          else if (_tagsDaNota.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Nenhuma tag vinculada a esta nota. Utilize o botão acima para adicionar classificações (ex: Vegetação, SF6, Prioritária).',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tagsDaNota.map((tag) {
                final cor = _corDaTag(tag.cor);
                return Chip(
                  avatar: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: cor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  label: Text(
                    tag.ativo ? tag.nome : '${tag.nome} (inativa)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: tag.ativo ? Colors.black87 : Colors.grey.shade600,
                      fontStyle: tag.ativo ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => _removerTag(tag),
                  backgroundColor: cor.withAlpha(25),
                  side: BorderSide(
                    color: cor.withAlpha(80),
                    width: 1,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPrazoBanner(
    BuildContext context,
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    final dias = widget.nota.diasRestantes;
    final isVencido = dias != null && dias < 0;
    final isUrgente = dias != null && dias >= 0 && dias <= 3;

    Color bg;
    Color border;
    Color textCol;
    IconData icon;
    String statusTexto;

    if (isVencido) {
      bg = Colors.red.withAlpha(20);
      border = Colors.red.withAlpha(80);
      textCol = Colors.red.shade700;
      icon = Icons.warning_amber_rounded;
      statusTexto = 'Vencida há ${dias.abs()} dia(s)';
    } else if (isUrgente) {
      bg = Colors.amber.withAlpha(30);
      border = Colors.amber.withAlpha(120);
      textCol = Colors.amber.shade900;
      icon = Icons.access_time_filled;
      statusTexto = dias == 0 ? 'Vence hoje' : 'Vence em $dias dia(s)';
    } else {
      bg = Colors.blue.withAlpha(15);
      border = Colors.blue.withAlpha(60);
      textCol = Colors.blue.shade700;
      icon = Icons.calendar_month;
      statusTexto = dias != null ? 'Prazo: $dias dia(s) restantes' : 'Com prazo definido';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.sm,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(TFRadius.r8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: textCol),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Text(
              statusTexto,
              style: typography.bodyMedium.copyWith(
                color: textCol,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (widget.nota.dataVencimento != null)
            Text(
              'Vencimento: ${_formatDate(widget.nota.dataVencimento)}',
              style: typography.caption.copyWith(
                color: textCol,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(TFRadius.r12),
        border: Border.all(color: colors.borderSubtle),
      ),
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colors.primary),
              SizedBox(width: spacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: typography.sectionTitle.copyWith(
                    color: colors.textPrimary,
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Divider(height: spacing.lg, color: colors.borderSubtle),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value, {
    bool isCopyable = false,
  }) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.xs * 0.7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: typography.caption.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    value,
                    style: typography.bodyMedium.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (isCopyable && value.isNotEmpty && value != '-') ...[
                  SizedBox(width: spacing.xs),
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => _copiarTexto(context, label, value),
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Icon(
                        Icons.copy,
                        size: 14,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
