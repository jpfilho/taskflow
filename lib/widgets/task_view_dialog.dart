import 'package:flutter/material.dart';
import '../models/task.dart';
import 'anexos_section.dart';

class TaskViewDialog extends StatelessWidget {
  final Task task;

  const TaskViewDialog({
    super.key,
    required this.task,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Dialog(
      child: Container(
        width: isMobile ? double.infinity : 800,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          maxWidth: MediaQuery.of(context).size.width * 0.95,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF1E3A5F),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      task.tarefa,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Conteúdo
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection('Informações Básicas', [
                      _buildDetailRow('Status', task.status),
                      _buildDetailRow('Tipo', task.tipo),
                      _buildDetailRow('Ordem', task.ordem ?? '-'),
                      _buildDetailRow('Regional', task.regional),
                      _buildDetailRow('Divisão', task.divisao),
                      if (task.segmento.isNotEmpty)
                        _buildDetailRow('Segmento', task.segmento),
                    ]),
                    const SizedBox(height: 16),
                    _buildSection('Localização', [
                      _buildDetailRow('Locais', task.locais.isNotEmpty 
                          ? task.locais.join(', ') 
                          : '-'),
                    ]),
                    const SizedBox(height: 16),
                    _buildSection('Responsáveis', [
                      if (task.executores.isNotEmpty)
                        _buildDetailRow('Executores', task.executores.join(', ')),
                      if (task.equipes.isNotEmpty)
                        _buildDetailRow('Equipes', task.equipes.join(', ')),
                      _buildDetailRow('Coordenador', task.coordenador.isNotEmpty ? task.coordenador : '-'),
                      _buildDetailRow('Frota', task.frota.isNotEmpty ? task.frota : '-'),
                      _buildDetailRow('SI', task.si.isNotEmpty ? task.si : '-'),
                    ]),
                    const SizedBox(height: 16),
                    _buildSection('Datas e Horas', [
                      _buildDetailRow('Data Início', 
                          '${task.dataInicio.day}/${task.dataInicio.month}/${task.dataInicio.year}'),
                      _buildDetailRow('Data Fim', 
                          '${task.dataFim.day}/${task.dataFim.month}/${task.dataFim.year}'),
                      if (task.horasPrevistas != null)
                        _buildDetailRow('Horas Previstas', task.horasPrevistas.toString()),
                      if (task.horasExecutadas != null)
                        _buildDetailRow('Horas Executadas', task.horasExecutadas.toString()),
                      _buildDetailRow('Prioridade', task.prioridade ?? '-'),
                    ]),
                    if (task.observacoes != null && task.observacoes!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSection('Observações', [
                        Text(
                          task.observacoes!,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ]),
                    ],
                    const SizedBox(height: 16),
                    _buildSection('Anexos', [
                      AnexosSection(
                        taskId: task.id,
                        isEditing: true,
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            // Footer com botões
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fechar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A5F),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

