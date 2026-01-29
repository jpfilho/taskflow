import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/task.dart';
import '../services/nota_sap_service.dart';
import '../services/ordem_service.dart';
import '../services/at_service.dart';
import '../services/si_service.dart';
import '../services/auth_service_simples.dart';
import '../models/nota_sap.dart';
import '../models/ordem.dart';
import '../models/at.dart';
import '../models/si.dart';
import 'anexos_section.dart';
import 'pex_apr_crc_view.dart';
import 'task_form_dialog.dart';
import '../services/task_service.dart';
import '../services/executor_service.dart';

class TaskViewDialog extends StatefulWidget {
  final Task task;
  final Function(Task)? onEdit;

  const TaskViewDialog({
    super.key,
    required this.task,
    this.onEdit,
  });

  @override
  State<TaskViewDialog> createState() => _TaskViewDialogState();
}

class _TaskViewDialogState extends State<TaskViewDialog> {
  final NotaSAPService _notaSAPService = NotaSAPService();
  final OrdemService _ordemService = OrdemService();
  final ATService _atService = ATService();
  final SIService _siService = SIService();
  final AuthServiceSimples _authService = AuthServiceSimples();
  final TaskService _taskService = TaskService();
  final ExecutorService _executorService = ExecutorService();
  
  List<NotaSAP> _notasSAP = [];
  List<Ordem> _ordens = [];
  List<AT> _ats = [];
  List<SI> _sis = [];
  bool _loadingSAP = true;
  bool _canEdit = false;

  @override
  void initState() {
    super.initState();
    _loadSAPData();
    _checkEditPermission();
  }

  Future<void> _checkEditPermission() async {
    try {
      final usuario = _authService.currentUser;
      if (usuario == null) {
        setState(() {
          _canEdit = false;
        });
        return;
      }

      if (usuario.isRoot) {
        setState(() {
          _canEdit = true;
        });
        return;
      }

      final email = usuario.email;
      if (email.isEmpty) {
        setState(() {
          _canEdit = false;
        });
        return;
      }

      final permitido = await _executorService.isCoordenadorOuGerentePorLogin(email);
      setState(() {
        _canEdit = permitido;
      });
    } catch (e) {
      print('⚠️ Erro ao verificar permissão de edição: $e');
      setState(() {
        _canEdit = false;
      });
    }
  }

  Future<void> _editarTarefa() async {
    if (!_canEdit) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Você não tem permissão para editar tarefas'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      // Se há um callback onEdit, usar ele (permite que o widget pai controle a abertura)
      if (widget.onEdit != null) {
        Navigator.of(context).pop();
        widget.onEdit!(widget.task);
        return;
      }

      // Buscar a tarefa atualizada primeiro
      final taskAtualizada = await _taskService.getTaskById(widget.task.id);
      
      if (taskAtualizada == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tarefa não encontrada'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Fechar o diálogo de visualização primeiro
      Navigator.of(context).pop();
      
      // Aguardar um frame para garantir que o diálogo foi fechado
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Buscar o contexto raiz para abrir o novo diálogo
      // Usar o contexto do widget pai (que chamou este diálogo)
      final rootContext = Navigator.of(context, rootNavigator: true).context;
      await showDialog(
        context: rootContext,
        builder: (context) => TaskFormDialog(
          task: taskAtualizada,
          startDate: taskAtualizada.dataInicio,
          endDate: taskAtualizada.dataFim,
        ),
      );
    } catch (e) {
      print('⚠️ Erro ao abrir edição de tarefa: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir edição: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadSAPData() async {
    try {
      final results = await Future.wait([
        _notaSAPService.getNotasPorTarefa(widget.task.id),
        _ordemService.getOrdensPorTarefa(widget.task.id),
        _atService.getATsPorTarefa(widget.task.id),
        _siService.getSIsPorTarefa(widget.task.id),
      ]);
      
      if (mounted) {
        setState(() {
          _notasSAP = results[0] as List<NotaSAP>;
          _ordens = results[1] as List<Ordem>;
          _ats = results[2] as List<AT>;
          _sis = results[3] as List<SI>;
          _loadingSAP = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingSAP = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: isMobile ? double.infinity : 900,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          maxWidth: MediaQuery.of(context).size.width * 0.95,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header modernizado
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[700]!, Colors.blue[500]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.task_alt, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.task.tarefa,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${widget.task.id.substring(0, 8)}...',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Fechar',
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
                      _buildDetailRow('Status', widget.task.status),
                      _buildDetailRow('Tipo', widget.task.tipo),
                      _buildDetailRow('Ordem', widget.task.ordem ?? '-'),
                      _buildDetailRow('Regional', widget.task.regional),
                      _buildDetailRow('Divisão', widget.task.divisao),
                      if (widget.task.segmento.isNotEmpty)
                        _buildDetailRow('Segmento', widget.task.segmento),
                    ], icon: Icons.info_outline),
                    const SizedBox(height: 20),
                    _buildSection('Localização', [
                      _buildDetailRow('Locais', widget.task.locais.isNotEmpty 
                          ? widget.task.locais.join(', ') 
                          : '-'),
                    ], icon: Icons.location_on),
                    const SizedBox(height: 20),
                    _buildSection('Responsáveis', [
                      if (widget.task.executores.isNotEmpty)
                        _buildDetailRow('Executores', widget.task.executores.join(', ')),
                      if (widget.task.equipes.isNotEmpty)
                        _buildDetailRow('Equipes', widget.task.equipes.join(', ')),
                      _buildDetailRow('Coordenador', widget.task.coordenador.isNotEmpty ? widget.task.coordenador : '-'),
                      _buildDetailRow('Frota', widget.task.frota.isNotEmpty ? widget.task.frota : '-'),
                      _buildDetailRow('SI', widget.task.si.isNotEmpty ? widget.task.si : '-'),
                    ], icon: Icons.people),
                    const SizedBox(height: 20),
                    _buildSection('Datas e Horas', [
                      _buildDetailRow('Data Início', 
                          '${widget.task.dataInicio.day.toString().padLeft(2, '0')}/${widget.task.dataInicio.month.toString().padLeft(2, '0')}/${widget.task.dataInicio.year}'),
                      _buildDetailRow('Data Fim', 
                          '${widget.task.dataFim.day.toString().padLeft(2, '0')}/${widget.task.dataFim.month.toString().padLeft(2, '0')}/${widget.task.dataFim.year}'),
                      if (widget.task.horasPrevistas != null)
                        _buildDetailRow('Horas Previstas', widget.task.horasPrevistas.toString()),
                      if (widget.task.horasExecutadas != null)
                        _buildDetailRow('Horas Executadas', widget.task.horasExecutadas.toString()),
                      _buildDetailRow('Prioridade', widget.task.prioridade ?? '-'),
                    ], icon: Icons.calendar_today),
                    if (widget.task.observacoes != null && widget.task.observacoes!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildSection('Observações', [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Text(
                            widget.task.observacoes!,
                            style: const TextStyle(fontSize: 14, height: 1.5),
                          ),
                        ),
                      ], icon: Icons.note),
                    ],
                    const SizedBox(height: 20),
                    _buildSection('Anexos', [
                      AnexosSection(
                        taskId: widget.task.id,
                        isEditing: true,
                      ),
                    ], icon: Icons.attach_file),
                    // Seção PEX/APR/CRC apenas para usuários root
                    if (_authService.currentUser?.isRoot == true) ...[
                      const SizedBox(height: 20),
                      _buildSection('Documentos (PEX, APR, CRC)', [
                        PEXAPRCRCView(task: widget.task),
                      ], icon: Icons.description),
                    ],
                    if (!_loadingSAP && (_notasSAP.isNotEmpty || _ordens.isNotEmpty || _ats.isNotEmpty || _sis.isNotEmpty)) ...[
                      const SizedBox(height: 20),
                      _buildSAPSection(),
                    ],
                  ],
                ),
              ),
            ),
            // Footer modernizado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_canEdit) ...[
                    ElevatedButton.icon(
                      onPressed: _editarTarefa,
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Editar Tarefa'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Fechar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.grey[800],
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSAPSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Itens SAP Vinculados',
          style: TextStyle(
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
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (_notasSAP.isNotEmpty)
                _buildSAPItem(
                  icon: Icons.description,
                  label: 'Notas SAP',
                  count: _notasSAP.length,
                  color: Colors.blue,
                  onTap: () => _mostrarDialogNotasSAP(_notasSAP, widget.task),
                ),
              if (_ordens.isNotEmpty)
                _buildSAPItem(
                  icon: Icons.receipt_long,
                  label: 'Ordens',
                  count: _ordens.length,
                  color: Colors.orange,
                  onTap: () => _mostrarDialogOrdens(_ordens, widget.task),
                ),
              if (_ats.isNotEmpty)
                _buildSAPItem(
                  icon: Icons.assignment,
                  label: 'ATs',
                  count: _ats.length,
                  color: Colors.purple,
                  onTap: () => _mostrarDialogATs(_ats, widget.task),
                ),
              if (_sis.isNotEmpty)
                _buildSAPItem(
                  icon: Icons.info,
                  label: 'SIs',
                  count: _sis.length,
                  color: Colors.teal,
                  onTap: () => _mostrarDialogSIs(_sis, widget.task),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSAPItem({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children, {IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: Colors.blue[700]),
              const SizedBox(width: 8),
            ],
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogNotasSAP(List<NotaSAP> notas, Task task) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[600]!, Colors.blue[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.description, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Notas SAP Vinculadas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Tarefa: ${task.tarefa}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notas.length,
                  itemBuilder: (context, index) {
                    final nota = notas[index];
                    return _buildNotaSAPCard(nota, index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copiarParaAreaTransferencia(String texto, String mensagemSucesso) async {
    try {
      await Clipboard.setData(ClipboardData(text: texto));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagemSucesso), duration: const Duration(seconds: 1)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível copiar: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildNotaSAPCard(NotaSAP nota, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.description, color: Colors.blue, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Nota: ${nota.nota}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _copiarParaAreaTransferencia(nota.nota, 'Nota copiada!'),
              tooltip: 'Copiar nota',
            ),
          ],
        ),
        subtitle: nota.tipo != null ? Text('Tipo: ${nota.tipo}') : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRowModern('Tipo', nota.tipo),
                _buildInfoRowModern('Status Sistema', nota.statusSistema),
                _buildInfoRowModern('Status Usuário', nota.statusUsuario),
                _buildInfoRowModern('Descrição', nota.descricao),
                _buildInfoRowModern('Detalhes', nota.detalhes),
                _buildInfoRowModern('Local Instalação', nota.localInstalacao),
                _buildInfoRowModern('Ordem', nota.ordem),
                _buildInfoRowModern('GPM', nota.gpm),
                _buildInfoRowModern('Centro Trabalho', nota.centroTrabalhoResponsavel),
                if (nota.inicioDesejado != null)
                  _buildInfoRowModern('Início Desejado', _formatDate(nota.inicioDesejado!)),
                if (nota.conclusaoDesejada != null)
                  _buildInfoRowModern('Conclusão Desejada', _formatDate(nota.conclusaoDesejada!)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogOrdens(List<Ordem> ordens, Task task) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange[600]!, Colors.orange[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.receipt_long, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ordens Vinculadas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Tarefa: ${task.tarefa}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: ordens.length,
                  itemBuilder: (context, index) {
                    final ordem = ordens[index];
                    return _buildOrdemCard(ordem, index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrdemCard(Ordem ordem, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.receipt_long, color: Colors.orange, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Ordem: ${ordem.ordem}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _copiarParaAreaTransferencia(ordem.ordem, 'Ordem copiada!'),
              tooltip: 'Copiar ordem',
            ),
          ],
        ),
        subtitle: ordem.tipo != null ? Text('Tipo: ${ordem.tipo}') : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRowModern('Tipo', ordem.tipo),
                _buildInfoRowModern('Status Sistema', ordem.statusSistema),
                _buildInfoRowModern('Status Usuário', ordem.statusUsuario),
                _buildInfoRowModern('Texto Breve', ordem.textoBreve),
                _buildInfoRowModern('Denominação Local', ordem.denominacaoLocalInstalacao),
                _buildInfoRowModern('Denominação Objeto', ordem.denominacaoObjeto),
                _buildInfoRowModern('Local Instalação', ordem.localInstalacao),
                _buildInfoRowModern('Código SI', ordem.codigoSI),
                _buildInfoRowModern('GPM', ordem.gpm),
                if (ordem.inicioBase != null)
                  _buildInfoRowModern('Início Base', _formatDate(ordem.inicioBase!)),
                if (ordem.fimBase != null)
                  _buildInfoRowModern('Fim Base', _formatDate(ordem.fimBase!)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogATs(List<AT> ats, Task task) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple[600]!, Colors.purple[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.assignment, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ATs Vinculadas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Tarefa: ${task.tarefa}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: ats.length,
                  itemBuilder: (context, index) {
                    final at = ats[index];
                    return _buildATCard(at, index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildATCard(AT at, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.purple.withOpacity(0.2)),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.assignment, color: Colors.purple, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'AT: ${at.autorzTrab}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _copiarParaAreaTransferencia(at.autorzTrab, 'AT copiada!'),
              tooltip: 'Copiar AT',
            ),
          ],
        ),
        subtitle: at.statusSistema != null ? Text('Status: ${at.statusSistema}') : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRowModern('Edificação', at.edificacao),
                _buildInfoRowModern('Status Sistema', at.statusSistema),
                _buildInfoRowModern('Status Usuário', at.statusUsuario),
                _buildInfoRowModern('Texto Breve', at.textoBreve),
                _buildInfoRowModern('Local Instalação', at.localInstalacao),
                _buildInfoRowModern('Centro Trabalho', at.cntrTrab),
                _buildInfoRowModern('Cen', at.cen),
                _buildInfoRowModern('SI', at.si),
                if (at.dataInicio != null)
                  _buildInfoRowModern('Data Início', _formatDate(at.dataInicio!)),
                if (at.dataFim != null)
                  _buildInfoRowModern('Data Fim', _formatDate(at.dataFim!)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogSIs(List<SI> sis, Task task) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal[600]!, Colors.teal[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.info, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SIs Vinculadas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Tarefa: ${task.tarefa}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sis.length,
                  itemBuilder: (context, index) {
                    final si = sis[index];
                    return _buildSICard(si, index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSICard(SI si, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.teal.withOpacity(0.2)),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.info, color: Colors.teal, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'SI: ${si.solicitacao}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _copiarParaAreaTransferencia(si.solicitacao, 'SI copiada!'),
              tooltip: 'Copiar SI',
            ),
          ],
        ),
        subtitle: si.tipo != null ? Text('Tipo: ${si.tipo}') : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRowModern('Tipo', si.tipo),
                _buildInfoRowModern('Status Sistema', si.statusSistema),
                _buildInfoRowModern('Status Usuário', si.statusUsuario),
                _buildInfoRowModern('Texto Breve', si.textoBreve),
                _buildInfoRowModern('Local Instalação', si.localInstalacao),
                _buildInfoRowModern('Criado Por', si.criadoPor),
                _buildInfoRowModern('Centro Trabalho', si.cntrTrab),
                _buildInfoRowModern('Cen', si.cen),
                _buildInfoRowModern('Atrib AT', si.atribAT),
                if (si.dataInicio != null)
                  _buildInfoRowModern('Data Início', _formatDate(si.dataInicio!)),
                if (si.dataFim != null)
                  _buildInfoRowModern('Data Fim', _formatDate(si.dataFim!)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRowModern(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                height: 1.4,
              ),
              maxLines: label == 'Detalhes' ? null : 3,
              overflow: label == 'Detalhes' ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

