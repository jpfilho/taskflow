import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/crc.dart';
import '../services/crc_service.dart';

class CRCFormDialog extends StatefulWidget {
  final Task task;
  final CRC? crc;

  const CRCFormDialog({
    super.key,
    required this.task,
    this.crc,
  });

  @override
  State<CRCFormDialog> createState() => _CRCFormDialogState();
}

class _CRCFormDialogState extends State<CRCFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final CRCService _crcService = CRCService();
  
  late TextEditingController _numeroCrcController;
  late TextEditingController _responsavelElaboracaoController;
  late TextEditingController _aprovadorController;
  late TextEditingController _atividadeController;
  late TextEditingController _localExecucaoController;
  late TextEditingController _equipeExecutoraController;
  late TextEditingController _coordenadorAtividadeController;
  late TextEditingController _pontosCriticosController;
  late TextEditingController _controlesController;
  late TextEditingController _verificacoesController;
  late TextEditingController _responsaveisVerificacaoController;
  late TextEditingController _observacoesController;
  
  DateTime? _dataElaboracao;
  DateTime? _dataAprovacao;
  DateTime? _dataExecucao;
  String _status = 'rascunho';

  @override
  void initState() {
    super.initState();
    final crc = widget.crc;
    
    _numeroCrcController = TextEditingController(text: crc?.numeroCrc ?? '');
    _responsavelElaboracaoController = TextEditingController(text: crc?.responsavelElaboracao ?? '');
    _aprovadorController = TextEditingController(text: crc?.aprovador ?? '');
    _atividadeController = TextEditingController(text: crc?.atividade ?? widget.task.tarefa);
    _localExecucaoController = TextEditingController(text: crc?.localExecucao ?? widget.task.locais.join(', '));
    _equipeExecutoraController = TextEditingController(text: crc?.equipeExecutora ?? widget.task.executores.join(', '));
    _coordenadorAtividadeController = TextEditingController(text: crc?.coordenadorAtividade ?? widget.task.coordenador);
    _pontosCriticosController = TextEditingController(text: crc?.pontosCriticos ?? '');
    _controlesController = TextEditingController(text: crc?.controles ?? '');
    _verificacoesController = TextEditingController(text: crc?.verificacoes ?? '');
    _responsaveisVerificacaoController = TextEditingController(text: crc?.responsaveisVerificacao ?? '');
    _observacoesController = TextEditingController(text: crc?.observacoes ?? '');
    
    _dataElaboracao = crc?.dataElaboracao ?? DateTime.now();
    _dataAprovacao = crc?.dataAprovacao;
    _dataExecucao = crc?.dataExecucao ?? widget.task.dataInicio;
    _status = crc?.status ?? 'rascunho';
  }

  @override
  void dispose() {
    _numeroCrcController.dispose();
    _responsavelElaboracaoController.dispose();
    _aprovadorController.dispose();
    _atividadeController.dispose();
    _localExecucaoController.dispose();
    _equipeExecutoraController.dispose();
    _coordenadorAtividadeController.dispose();
    _pontosCriticosController.dispose();
    _controlesController.dispose();
    _verificacoesController.dispose();
    _responsaveisVerificacaoController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, Function(DateTime) onDateSelected) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onDateSelected(picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final crc = CRC(
        id: widget.crc?.id,
        taskId: widget.task.id,
        numeroCrc: _numeroCrcController.text.trim().isEmpty ? null : _numeroCrcController.text.trim(),
        dataElaboracao: _dataElaboracao,
        responsavelElaboracao: _responsavelElaboracaoController.text.trim().isEmpty ? null : _responsavelElaboracaoController.text.trim(),
        aprovador: _aprovadorController.text.trim().isEmpty ? null : _aprovadorController.text.trim(),
        dataAprovacao: _dataAprovacao,
        atividade: _atividadeController.text.trim().isEmpty ? null : _atividadeController.text.trim(),
        localExecucao: _localExecucaoController.text.trim().isEmpty ? null : _localExecucaoController.text.trim(),
        dataExecucao: _dataExecucao,
        equipeExecutora: _equipeExecutoraController.text.trim().isEmpty ? null : _equipeExecutoraController.text.trim(),
        coordenadorAtividade: _coordenadorAtividadeController.text.trim().isEmpty ? null : _coordenadorAtividadeController.text.trim(),
        pontosCriticos: _pontosCriticosController.text.trim().isEmpty ? null : _pontosCriticosController.text.trim(),
        controles: _controlesController.text.trim().isEmpty ? null : _controlesController.text.trim(),
        verificacoes: _verificacoesController.text.trim().isEmpty ? null : _verificacoesController.text.trim(),
        responsaveisVerificacao: _responsaveisVerificacaoController.text.trim().isEmpty ? null : _responsaveisVerificacaoController.text.trim(),
        observacoes: _observacoesController.text.trim().isEmpty ? null : _observacoesController.text.trim(),
        status: _status,
      );

      await _crcService.createOrUpdateCRC(crc);
      
      if (mounted) {
        Navigator.of(context).pop(crc);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CRC salvo com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar CRC: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Dialog(
      child: Container(
        width: isMobile ? double.infinity : 900,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'CRC - Controle de Pontos Críticos',
                        style: TextStyle(
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
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Informações Gerais'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _numeroCrcController,
                              decoration: const InputDecoration(
                                labelText: 'Número CRC',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(context, (date) {
                                setState(() => _dataElaboracao = date);
                              }),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Data de Elaboração',
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(
                                  _dataElaboracao != null
                                      ? DateFormat('dd/MM/yyyy').format(_dataElaboracao!)
                                      : 'Selecione a data',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _responsavelElaboracaoController,
                              decoration: const InputDecoration(
                                labelText: 'Responsável pela Elaboração',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _aprovadorController,
                              decoration: const InputDecoration(
                                labelText: 'Aprovador',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Dados da Atividade'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _atividadeController,
                        decoration: const InputDecoration(
                          labelText: 'Atividade',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _localExecucaoController,
                              decoration: const InputDecoration(
                                labelText: 'Local de Execução',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(context, (date) {
                                setState(() => _dataExecucao = date);
                              }),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Data de Execução',
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(
                                  _dataExecucao != null
                                      ? DateFormat('dd/MM/yyyy').format(_dataExecucao!)
                                      : 'Selecione a data',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _equipeExecutoraController,
                              decoration: const InputDecoration(
                                labelText: 'Equipe Executora',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _coordenadorAtividadeController,
                              decoration: const InputDecoration(
                                labelText: 'Coordenador da Atividade',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Pontos Críticos'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _pontosCriticosController,
                        decoration: const InputDecoration(
                          labelText: 'Pontos Críticos',
                          border: OutlineInputBorder(),
                          hintText: 'Descreva os pontos críticos',
                        ),
                        maxLines: 5,
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Controles'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _controlesController,
                        decoration: const InputDecoration(
                          labelText: 'Controles',
                          border: OutlineInputBorder(),
                          hintText: 'Descreva os controles',
                        ),
                        maxLines: 5,
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Verificações'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _verificacoesController,
                        decoration: const InputDecoration(
                          labelText: 'Verificações',
                          border: OutlineInputBorder(),
                          hintText: 'Descreva as verificações',
                        ),
                        maxLines: 5,
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Responsáveis'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _responsaveisVerificacaoController,
                        decoration: const InputDecoration(
                          labelText: 'Responsáveis pela Verificação',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Observações'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _observacoesController,
                        decoration: const InputDecoration(
                          labelText: 'Observações',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Status'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'rascunho', child: Text('Rascunho')),
                          DropdownMenuItem(value: 'aprovado', child: Text('Aprovado')),
                          DropdownMenuItem(value: 'em_execucao', child: Text('Em Execução')),
                          DropdownMenuItem(value: 'concluido', child: Text('Concluído')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _status = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
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
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _save,
                      child: const Text('Salvar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1E3A5F),
      ),
    );
  }
}
