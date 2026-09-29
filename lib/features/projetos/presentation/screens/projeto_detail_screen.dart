import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../design_system/components/buttons/tf_button.dart';
import '../../../../design_system/components/buttons/tf_icon_button.dart';
import '../../../../design_system/components/cards/tf_card.dart';
import '../../../../design_system/components/layout/tf_page_header.dart';
import '../../../../design_system/components/status/tf_status_badge.dart';
import '../../../../design_system/foundations/tf_icons.dart';
import '../../../../design_system/foundations/tf_radius.dart';
import '../../../../design_system/theme/taskflow_theme_extension.dart';
import '../../models/projeto.dart';
import '../../services/projeto_service.dart';
import '../widgets/cronograma_tab.dart';
import '../widgets/equipe_tab.dart';
import '../widgets/marcos_riscos_tab.dart';
import '../widgets/projeto_form_dialog.dart';
import '../widgets/projeto_status_mapper.dart';

class ProjetoDetailScreen extends StatefulWidget {
  final Projeto projeto;

  const ProjetoDetailScreen({super.key, required this.projeto});

  @override
  State<ProjetoDetailScreen> createState() => _ProjetoDetailScreenState();
}

class _ProjetoDetailScreenState extends State<ProjetoDetailScreen> {
  final ProjetoService _service = ProjetoService();
  late Projeto _projetoAtual;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _projetoAtual = widget.projeto;
  }

  void _editarProjeto() async {
    final res = await showDialog<Projeto>(
      context: context,
      builder: (_) => ProjetoFormDialog(projeto: _projetoAtual),
    );
    if (res != null) {
      await _service.updateProjeto(res);
      setState(() {
        _projetoAtual = res;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Column(
            children: [
              // 1. Page Header oficial TFDS com ação de voltar e editar
              TFPageHeader(
                title: _projetoAtual.nome,
                subtitle: _projetoAtual.codigo != null
                    ? 'Código: ${_projetoAtual.codigo} • Status: ${_projetoAtual.status}'
                    : 'Status: ${_projetoAtual.status}',
                leading: TFIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Voltar',
                  onPressed: () => Navigator.of(context).pop(true),
                ),
                primaryAction: TFButton(
                  label: 'Editar Projeto',
                  leadingIcon: TFIcons.edit,
                  onPressed: _editarProjeto,
                ),
              ),

              // 2. TabBar com as abas do projeto
              Container(
                color: colors.surface,
                child: TabBar(
                  labelColor: colors.primary,
                  unselectedLabelColor: colors.textSecondary,
                  indicatorColor: colors.primary,
                  indicatorWeight: 3,
                  labelStyle: typography.labelMedium.copyWith(fontWeight: FontWeight.bold),
                  unselectedLabelStyle: typography.labelMedium,
                  tabs: const [
                    Tab(text: 'Visão Geral', icon: Icon(Icons.dashboard_rounded, size: 18)),
                    Tab(text: 'Cronograma & WBS', icon: Icon(TFIcons.task, size: 18)),
                    Tab(text: 'Equipe', icon: Icon(TFIcons.team, size: 18)),
                    Tab(text: 'Marcos & Riscos', icon: Icon(TFIcons.warning, size: 18)),
                  ],
                ),
              ),

              // 3. TabBarView com as abas de detalhe
              Expanded(
                child: TabBarView(
                  children: [
                    _buildVisaoGeral(context),
                    CronogramaTab(projeto: _projetoAtual, service: _service),
                    EquipeTab(projeto: _projetoAtual, service: _service),
                    MarcosRiscosTab(projeto: _projetoAtual, service: _service),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisaoGeral(BuildContext context) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;

    Widget infoRow(String label, String value, {Widget? trailing}) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: spacing.xxs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 160,
              child: Text(
                label,
                style: typography.bodySmall.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: trailing ??
                  Text(
                    value,
                    style: typography.bodyMedium.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TFCard(
            padding: EdgeInsets.all(spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ficha Técnica do Projeto',
                      style: typography.sectionTitle.copyWith(color: colors.textPrimary),
                    ),
                    TFStatusBadge(
                      label: _projetoAtual.status,
                      severity: ProjetoStatusMapper.mapProjetoStatus(_projetoAtual.status),
                      icon: ProjetoStatusMapper.getStatusIcon(_projetoAtual.status),
                    ),
                  ],
                ),
                SizedBox(height: spacing.sm),
                Divider(color: colors.borderSubtle),
                SizedBox(height: spacing.sm),

                if (_projetoAtual.codigo != null && _projetoAtual.codigo!.isNotEmpty)
                  infoRow('Código / Sigla:', _projetoAtual.codigo!),

                if (_projetoAtual.descricao != null && _projetoAtual.descricao!.isNotEmpty)
                  infoRow('Descrição:', _projetoAtual.descricao!),

                infoRow(
                  'Prioridade:',
                  '',
                  trailing: Align(
                    alignment: Alignment.centerLeft,
                    child: TFStatusBadge(
                      label: _projetoAtual.prioridade,
                      severity: ProjetoStatusMapper.mapPrioridade(_projetoAtual.prioridade),
                    ),
                  ),
                ),

                infoRow(
                  'Início Previsto:',
                  _projetoAtual.dataInicioPrevista != null
                      ? _dateFormat.format(_projetoAtual.dataInicioPrevista!)
                      : 'Não definido',
                ),

                infoRow(
                  'Fim Previsto:',
                  _projetoAtual.dataFimPrevista != null
                      ? _dateFormat.format(_projetoAtual.dataFimPrevista!)
                      : 'Não definido',
                ),

                if (_projetoAtual.orcamentoPrevisto != null)
                  infoRow(
                    'Orçamento Previsto:',
                    'R\$ ${_projetoAtual.orcamentoPrevisto!.toStringAsFixed(2).replaceAll('.', ',')}',
                  ),

                SizedBox(height: spacing.md),
                Text(
                  'Progresso Físico Global',
                  style: typography.bodySmall.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: spacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: TFRadius.borderRadiusFull,
                        child: LinearProgressIndicator(
                          value: (_projetoAtual.progresso / 100).clamp(0.0, 1.0),
                          minHeight: 10,
                          backgroundColor: colors.borderSubtle,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _projetoAtual.progresso >= 100
                                ? colors.success
                                : _projetoAtual.progresso > 0
                                    ? colors.primary
                                    : colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: spacing.sm),
                    Text(
                      '${_projetoAtual.progresso.toStringAsFixed(1)}%',
                      style: typography.labelLarge.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
