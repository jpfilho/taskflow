import 'package:flutter/material.dart';
import '../models/task.dart';
import '../utils/responsive.dart';

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
    // Checklists por tipo de manutenção
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
          _buildHeader(isMobile),
          const SizedBox(height: 20),
          if (widget.task != null) _buildTaskInfo(widget.task!, isMobile),
          const SizedBox(height: 24),
          _buildSectionTitle('Checklist de Manutenção', isMobile),
          const SizedBox(height: 12),
          _buildChecklist(checklist, isMobile),
          const SizedBox(height: 24),
          _buildProgressCard(checklist, isMobile),
          const SizedBox(height: 24),
          _buildActionButtons(isMobile),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A5F),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.checklist, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            'Checklist de Manutenção',
            style: TextStyle(
              fontSize: isMobile ? 22 : 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E3A5F),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskInfo(Task task, bool isMobile) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.tarefa,
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(task.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    task.status,
                    style: TextStyle(
                      color: _getStatusColor(task.status),
                      fontWeight: FontWeight.w600,
                      fontSize: isMobile ? 11 : 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${task.tipo} • ${task.locais.isNotEmpty ? task.locais.join(', ') : ''}',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isMobile) {
    return Text(
      title,
      style: TextStyle(
        fontSize: isMobile ? 18 : 22,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1E3A5F),
      ),
    );
  }

  Widget _buildChecklist(List<ChecklistItem> checklist, bool isMobile) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: checklist.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return _buildChecklistItem(item, index, isMobile);
        }).toList(),
      ),
    );
  }

  Widget _buildChecklistItem(ChecklistItem item, int index, bool isMobile) {
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
            bottom: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
          color: item.completed ? Colors.green.withOpacity(0.05) : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: item.completed ? Colors.green : Colors.white,
                border: Border.all(
                  color: item.completed ? Colors.green : Colors.grey[400]!,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: item.completed
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                item.description,
                style: TextStyle(
                  fontSize: isMobile ? 13 : 15,
                  decoration: item.completed ? TextDecoration.lineThrough : null,
                  color: item.completed ? Colors.grey[600] : Colors.grey[800],
                ),
              ),
            ),
            if (item.completed)
              Icon(Icons.check_circle, color: Colors.green, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(List<ChecklistItem> checklist, bool isMobile) {
    final completed = checklist.where((item) => item.completed).length;
    final total = checklist.length;
    final percentage = total > 0 ? (completed / total * 100) : 0.0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.withOpacity(0.1),
              Colors.green.withOpacity(0.05),
            ],
          ),
        ),
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          children: [
            Text(
              'Progresso do Checklist',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E3A5F),
              ),
            ),
            const SizedBox(height: 16),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: isMobile ? 120 : 150,
                  height: isMobile ? 120 : 150,
                  child: CircularProgressIndicator(
                    value: percentage / 100,
                    strokeWidth: 12,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      percentage == 100 ? Colors.green : Colors.blue,
                    ),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '${percentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: isMobile ? 28 : 36,
                        fontWeight: FontWeight.bold,
                        color: percentage == 100 ? Colors.green : Colors.blue,
                      ),
                    ),
                    Text(
                      '$completed de $total',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 14,
                        color: Colors.grey[600],
                      ),
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

  Widget _buildActionButtons(bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              // Salvar checklist
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Checklist salvo com sucesso!')),
              );
            },
            icon: const Icon(Icons.save),
            label: const Text('Salvar Checklist'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              // Imprimir checklist
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Preparando para impressão...')),
              );
            },
            icon: const Icon(Icons.print),
            label: const Text('Imprimir'),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 16),
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ANDA':
        return Colors.orange;
      case 'CONC':
        return Colors.green;
      case 'PROG':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

class ChecklistItem {
  final String description;
  bool completed;

  ChecklistItem(this.description, this.completed);
}






