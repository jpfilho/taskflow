import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/apr.dart';
import '../services/apr_service.dart';
import '../design_system/taskflow_design_system.dart';

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
  bool _isSaving = false;

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

    setState(() => _isSaving = true);

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
        setState(() => _isSaving = false);
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
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TFRadius.r16)),
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
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(TFRadius.r16),
                    topRight: Radius.circular(TFRadius.r16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: Colors.white),
                    const SizedBox(width: 12),
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
                      tooltip: 'Fechar',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(context, 'Informações Gerais'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TFTextField(
                              controller: _numeroAprController,
                              label: 'Número APR',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(context, (date) {
                                setState(() => _dataElaboracao = date);
                              }),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Data de Elaboração',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(TFRadius.r12),
                                  ),
                                ),
                                child: Text(
                                  _dataElaboracao != null
                                      ? DateFormat('dd/MM/yyyy').format(_dataElaboracao!)
                                      : 'Selecione a data',
                                  style: typography.bodyMedium,
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
                            child: TFTextField(
                              controller: _responsavelElaboracaoController,
                              label: 'Responsável pela Elaboração',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TFTextField(
                              controller: _aprovadorController,
                              label: 'Aprovador',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle(context, 'Dados da Atividade'),
                      const SizedBox(height: 12),
                      TFTextField(
                        controller: _atividadeController,
                        label: 'Atividade',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TFTextField(
                              controller: _localExecucaoController,
                              label: 'Local de Execução',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(context, (date) {
                                setState(() => _dataExecucao = date);
                              }),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Data de Execução',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(TFRadius.r12),
                                  ),
                                ),
                                child: Text(
                                  _dataExecucao != null
                                      ? DateFormat('dd/MM/yyyy').format(_dataExecucao!)
                                      : 'Selecione a data',
                                  style: typography.bodyMedium,
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
                            child: TFTextField(
                              controller: _equipeExecutoraController,
                              label: 'Equipe Executora',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TFTextField(
                              controller: _coordenadorAtividadeController,
                              label: 'Coordenador da Atividade',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle(context, 'Análise de Riscos & Medidas'),
                      const SizedBox(height: 12),
                      TFTextField(
                        controller: _riscosIdentificadosController,
                        label: 'Riscos Identificados',
                        hint: 'Descreva os riscos identificados',
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),
                      TFTextField(
                        controller: _medidasControleController,
                        label: 'Medidas de Controle',
                        hint: 'Descreva as medidas de controle',
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),
                      TFTextField(
                        controller: _episNecessariosController,
                        label: 'EPIs Necessários',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle(context, 'Permissões & Emergência'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TFTextField(
                              controller: _permissoesNecessariasController,
                              label: 'Permissões Necessárias',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TFTextField(
                              controller: _autorizacoesNecessariasController,
                              label: 'Autorizações Necessárias',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TFTextField(
                        controller: _procedimentosEmergenciaController,
                        label: 'Procedimentos de Emergência',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      TFTextField(
                        controller: _observacoesController,
                        label: 'Observações',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      TFDropdown<String>(
                        label: 'Status',
                        value: _status,
                        items: const ['rascunho', 'aprovado', 'em_execucao', 'concluido'],
                        displayText: (status) {
                          switch (status) {
                            case 'rascunho':
                              return 'Rascunho';
                            case 'aprovado':
                              return 'Aprovado';
                            case 'em_execucao':
                              return 'Em Execução';
                            case 'concluido':
                              return 'Concluído';
                            default:
                              return status;
                          }
                        },
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
              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceSecondary,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(TFRadius.r16),
                    topRight: Radius.zero,
                    topLeft: Radius.zero,
                    bottomRight: Radius.circular(TFRadius.r16),
                  ),
                  border: Border(top: BorderSide(color: colors.borderSubtle)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TFButton(
                      label: 'Cancelar',
                      variant: TFButtonVariant.secondary,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    TFButton(
                      label: 'Salvar',
                      variant: TFButtonVariant.primary,
                      loading: _isSaving,
                      onPressed: _save,
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

  Widget _buildSectionTitle(BuildContext context, String title) {
    final typography = context.tfTypography;
    final colors = context.tfColors;

    return Text(
      title,
      style: typography.sectionTitle.copyWith(
        fontWeight: FontWeight.bold,
        color: colors.primary,
      ),
    );
  }
}
