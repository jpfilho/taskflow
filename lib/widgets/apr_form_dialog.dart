import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/apr.dart';
import '../services/apr_service.dart';

class APRFormDialog extends StatefulWidget {
  final Task task;
  final APR? apr;

  const APRFormDialog({
    super.key,
    required this.task,
    this.apr,
  });

  @override
  State<APRFormDialog> createState() => _APRFormDialogState();
}

class _APRFormDialogState extends State<APRFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final APRService _aprService = APRService();
  
  late TextEditingController _numeroAprController;
  late TextEditingController _responsavelElaboracaoController;
  late TextEditingController _aprovadorController;
  late TextEditingController _atividadeController;
  late TextEditingController _localExecucaoController;
  late TextEditingController _equipeExecutoraController;
  late TextEditingController _coordenadorAtividadeController;
  late TextEditingController _riscosIdentificadosController;
  late TextEditingController _medidasControleController;
  late TextEditingController _episNecessariosController;
  late TextEditingController _permissoesNecessariasController;
  late TextEditingController _autorizacoesNecessariasController;
  late TextEditingController _procedimentosEmergenciaController;
  late TextEditingController _observacoesController;
  
  DateTime? _dataElaboracao;
  DateTime? _dataAprovacao;
  DateTime? _dataExecucao;
  String _status = 'rascunho';

  @override
  void initState() {
    super.initState();
    final apr = widget.apr;
    
    _numeroAprController = TextEditingController(text: apr?.numeroApr ?? '');
    _responsavelElaboracaoController = TextEditingController(text: apr?.responsavelElaboracao ?? '');
    _aprovadorController = TextEditingController(text: apr?.aprovador ?? '');
    _atividadeController = TextEditingController(text: apr?.atividade ?? widget.task.tarefa);
    _localExecucaoController = TextEditingController(text: apr?.localExecucao ?? widget.task.locais.join(', '));
    _equipeExecutoraController = TextEditingController(text: apr?.equipeExecutora ?? widget.task.executores.join(', '));
    _coordenadorAtividadeController = TextEditingController(text: apr?.coordenadorAtividade ?? widget.task.coordenador);
    _riscosIdentificadosController = TextEditingController(text: apr?.riscosIdentificados ?? '');
    _medidasControleController = TextEditingController(text: apr?.medidasControle ?? '');
    _episNecessariosController = TextEditingController(text: apr?.episNecessarios ?? '');
    _permissoesNecessariasController = TextEditingController(text: apr?.permissoesNecessarias ?? '');
    _autorizacoesNecessariasController = TextEditingController(text: apr?.autorizacoesNecessarias ?? '');
    _procedimentosEmergenciaController = TextEditingController(text: apr?.procedimentosEmergencia ?? '');
    _observacoesController = TextEditingController(text: apr?.observacoes ?? '');
    
    _dataElaboracao = apr?.dataElaboracao ?? DateTime.now();
    _dataAprovacao = apr?.dataAprovacao;
    _dataExecucao = apr?.dataExecucao ?? widget.task.dataInicio;
    _status = apr?.status ?? 'rascunho';
  }

  @override
  void dispose() {
    _numeroAprController.dispose();
    _responsavelElaboracaoController.dispose();
    _aprovadorController.dispose();
    _atividadeController.dispose();
    _localExecucaoController.dispose();
    _equipeExecutoraController.dispose();
    _coordenadorAtividadeController.dispose();
    _riscosIdentificadosController.dispose();
    _medidasControleController.dispose();
    _episNecessariosController.dispose();
    _permissoesNecessariasController.dispose();
    _autorizacoesNecessariasController.dispose();
    _procedimentosEmergenciaController.dispose();
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
      final apr = APR(
        id: widget.apr?.id,
        taskId: widget.task.id,
        numeroApr: _numeroAprController.text.trim().isEmpty ? null : _numeroAprController.text.trim(),
        dataElaboracao: _dataElaboracao,
        responsavelElaboracao: _responsavelElaboracaoController.text.trim().isEmpty ? null : _responsavelElaboracaoController.text.trim(),
        aprovador: _aprovadorController.text.trim().isEmpty ? null : _aprovadorController.text.trim(),
        dataAprovacao: _dataAprovacao,
        atividade: _atividadeController.text.trim().isEmpty ? null : _atividadeController.text.trim(),
        localExecucao: _localExecucaoController.text.trim().isEmpty ? null : _localExecucaoController.text.trim(),
        dataExecucao: _dataExecucao,
        equipeExecutora: _equipeExecutoraController.text.trim().isEmpty ? null : _equipeExecutoraController.text.trim(),
        coordenadorAtividade: _coordenadorAtividadeController.text.trim().isEmpty ? null : _coordenadorAtividadeController.text.trim(),
        riscosIdentificados: _riscosIdentificadosController.text.trim().isEmpty ? null : _riscosIdentificadosController.text.trim(),
        medidasControle: _medidasControleController.text.trim().isEmpty ? null : _medidasControleController.text.trim(),
        episNecessarios: _episNecessariosController.text.trim().isEmpty ? null : _episNecessariosController.text.trim(),
        permissoesNecessarias: _permissoesNecessariasController.text.trim().isEmpty ? null : _permissoesNecessariasController.text.trim(),
        autorizacoesNecessarias: _autorizacoesNecessariasController.text.trim().isEmpty ? null : _autorizacoesNecessariasController.text.trim(),
        procedimentosEmergencia: _procedimentosEmergenciaController.text.trim().isEmpty ? null : _procedimentosEmergenciaController.text.trim(),
        observacoes: _observacoesController.text.trim().isEmpty ? null : _observacoesController.text.trim(),
        status: _status,
      );

      await _aprService.createOrUpdateAPR(apr);
      
      if (mounted) {
        Navigator.of(context).pop(apr);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('APR salva com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar APR: $e'),
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
                    const Icon(Icons.warning, color: Colors.white),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'APR - Análise Preliminar de Risco',
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
                              controller: _numeroAprController,
                              decoration: const InputDecoration(
                                labelText: 'Número APR',
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
                      _buildSectionTitle('Análise de Riscos'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _riscosIdentificadosController,
                        decoration: const InputDecoration(
                          labelText: 'Riscos Identificados',
                          border: OutlineInputBorder(),
                          hintText: 'Descreva os riscos identificados',
                        ),
                        maxLines: 5,
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Medidas de Controle'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _medidasControleController,
                        decoration: const InputDecoration(
                          labelText: 'Medidas de Controle',
                          border: OutlineInputBorder(),
                          hintText: 'Descreva as medidas de controle',
                        ),
                        maxLines: 5,
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('EPIs Necessários'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _episNecessariosController,
                        decoration: const InputDecoration(
                          labelText: 'EPIs Necessários',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Permissões e Autorizações'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _permissoesNecessariasController,
                        decoration: const InputDecoration(
                          labelText: 'Permissões Necessárias',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _autorizacoesNecessariasController,
                        decoration: const InputDecoration(
                          labelText: 'Autorizações Necessárias',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Procedimentos de Emergência'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _procedimentosEmergenciaController,
                        decoration: const InputDecoration(
                          labelText: 'Procedimentos de Emergência',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 4,
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
                        value: _status,
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
