import 'package:flutter/material.dart';
import '../models/task.dart';
import '../utils/responsive.dart';
import '../design_system/taskflow_design_system.dart';

class MaintenanceChecklistView extends StatefulWidget {
  final Task? task;

  const MaintenanceChecklistView({
    super.key,
    this.task,
  });

  @override
  State<MaintenanceChecklistView> createState() => _MaintenanceChecklistViewState();
}

class _MaintenanceChecklistViewState extends State<MaintenanceChecklistView> {
  final Map<String, List<ChecklistItem>> _checklists = {};

  @override
  void initState() {
    super.initState();
    _loadChecklists();
  }

  void _loadChecklists() {
    _checklists['PMP'] = [
      ChecklistItem('Verificar estado geral do equipamento', false),
      ChecklistItem('Inspecionar conexões elétricas', false),
      ChecklistItem('Verificar níveis de óleo e fluidos', false),
      ChecklistItem('Testar sistemas de proteção', false),
      ChecklistItem('Limpeza geral do equipamento', false),
      ChecklistItem('Verificar documentação técnica', false),
      ChecklistItem('Registrar medições e parâmetros', false),
      ChecklistItem('Assinatura do responsável', false),
    ];

    _checklists['CORRECAO'] = [
      ChecklistItem('Identificar causa raiz do problema', false),
      ChecklistItem('Isolar área de trabalho', false),
      ChecklistItem('Verificar segurança elétrica', false),
      ChecklistItem('Executar correção', false),
      ChecklistItem('Testar funcionamento', false),
      ChecklistItem('Documentar correção realizada', false),
      ChecklistItem('Assinatura do responsável', false),
    ];

    _checklists['TREINAMENTO'] = [
      ChecklistItem('Preparar material didático', false),
      ChecklistItem('Confirmar presença dos participantes', false),
      ChecklistItem('Realizar treinamento teórico', false),
      ChecklistItem('Realizar treinamento prático', false),
      ChecklistItem('Avaliar conhecimento adquirido', false),
      ChecklistItem('Registrar certificados', false),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final taskType = widget.task?.tipo ?? 'PMP';
    final checklist = _checklists[taskType] ?? _checklists['PMP']!;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, isMobile),
          const SizedBox(height: 20),
          if (widget.task != null) _buildTaskInfo(context, widget.task!, isMobile),
          const SizedBox(height: 24),
          _buildSectionTitle(context, 'Checklist de Manutenção', isMobile),
          const SizedBox(height: 12),
          _buildChecklist(context, checklist, isMobile),
          const SizedBox(height: 24),
          _buildProgressCard(context, checklist, isMobile),
          const SizedBox(height: 24),
          _buildActionButtons(context, isMobile),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(TFRadius.r12),
          ),
          child: const Icon(Icons.checklist, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            'Checklist de Manutenção',
            style: isMobile ? typography.sectionTitle : typography.pageTitle,
          ),
        ),
      ],
    );
  }

  Widget _buildTaskInfo(BuildContext context, Task task, bool isMobile) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return TFCard(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.tarefa,
              style: typography.cardTitle.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TFStatusBadge(
                  label: task.status,
                  severity: _mapStatusToSeverity(task.status),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${task.tipo} • ${task.locais.isNotEmpty ? task.locais.join(', ') : ''}',
                    style: typography.caption.copyWith(color: colors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TFStatusSeverity _mapStatusToSeverity(String status) {
    switch (status.toUpperCase()) {
      case 'CONC':
      case 'CONCLUIDA':
        return TFStatusSeverity.success;
      case 'ANDA':
      case 'EM_ANDAMENTO':
        return TFStatusSeverity.warning;
      case 'CANC':
      case 'CANCELADA':
        return TFStatusSeverity.danger;
      default:
        return TFStatusSeverity.info;
    }
  }

  Widget _buildSectionTitle(BuildContext context, String title, bool isMobile) {
    final typography = context.tfTypography;

    return Text(
      title,
      style: isMobile ? typography.cardTitle : typography.sectionTitle,
    );
  }

  Widget _buildChecklist(BuildContext context, List<ChecklistItem> checklist, bool isMobile) {
    return TFCard(
      child: Column(
        children: checklist.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return _buildChecklistItem(context, item, index, isMobile);
        }).toList(),
      ),
    );
  }

  Widget _buildChecklistItem(BuildContext context, ChecklistItem item, int index, bool isMobile) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return InkWell(
      onTap: () {
        setState(() {
          item.completed = !item.completed;
        });
      },
      child: Container(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: colors.borderSubtle, width: 1),
          ),
          color: item.completed ? colors.success.withValues(alpha: 0.04) : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: item.completed ? colors.success : Colors.transparent,
                border: Border.all(
                  color: item.completed ? colors.success : colors.borderSubtle,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(TFRadius.r4),
              ),
              child: item.completed
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                item.description,
                style: typography.bodyMedium.copyWith(
                  decoration: item.completed ? TextDecoration.lineThrough : null,
                  color: item.completed ? colors.textSecondary : colors.textPrimary,
                ),
              ),
            ),
            if (item.completed)
              Icon(Icons.check_circle, color: colors.success, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context, List<ChecklistItem> checklist, bool isMobile) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    final completed = checklist.where((item) => item.completed).length;
    final total = checklist.length;
    final percentage = total > 0 ? (completed / total * 100) : 0.0;

    return TFCard(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          children: [
            Text(
              'Progresso do Checklist',
              style: typography.cardTitle.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: isMobile ? 110 : 130,
                  height: isMobile ? 110 : 130,
                  child: CircularProgressIndicator(
                    value: percentage / 100,
                    strokeWidth: 10,
                    backgroundColor: colors.borderSubtle,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      percentage == 100 ? colors.success : colors.primary,
                    ),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '${percentage.toStringAsFixed(0)}%',
                      style: (isMobile ? typography.sectionTitle : typography.display).copyWith(
                        color: percentage == 100 ? colors.success : colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$completed de $total',
                      style: typography.caption.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: TFButton(
            label: 'Salvar Checklist',
            leadingIcon: Icons.save,
            variant: TFButtonVariant.primary,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Checklist salvo com sucesso!')),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TFButton(
            label: 'Imprimir',
            leadingIcon: Icons.print,
            variant: TFButtonVariant.secondary,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Preparando para impressão...')),
              );
            },
          ),
        ),
      ],
    );
  }
}

class ChecklistItem {
  final String description;
  bool completed;

  ChecklistItem(this.description, this.completed);
}
