import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/confirmacao.dart';
import '../services/confirmacao_service.dart';
import '../utils/responsive.dart';

class ConfirmacaoFormDialog extends StatefulWidget {
  final Confirmacao? confirmacao;

  const ConfirmacaoFormDialog({super.key, this.confirmacao});

  @override
  State<ConfirmacaoFormDialog> createState() => _ConfirmacaoFormDialogState();
}

class _ConfirmacaoFormDialogState extends State<ConfirmacaoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final ConfirmacaoService _service = ConfirmacaoService();
  bool _isSaving = false;

  // Controllers
  final _ordemController = TextEditingController();
  final _operacao2Controller = TextEditingController();
  final _subOperController = TextEditingController();
  final _centroDeTrabalhoController = TextEditingController();
  final _centroController = TextEditingController();
  final _nomesController = TextEditingController();
  final _nPessoalController = TextEditingController();
  final _trabRealController = TextEditingController();
  final _unidController = TextEditingController(text: 'H');
  final _textoConfirmacaoController = TextEditingController();
  final _confirmacaoFinalController = TextEditingController();
  final _sTrabRestanteController = TextEditingController();
  final _tipoAtividadeController = TextEditingController();

  // Dates and times
  DateTime? _datInicioExec;
  TimeOfDay? _horaInicio;
  DateTime? _datFimExec;
  TimeOfDay? _horaFim;
  DateTime? _dataLancamento;

  @override
  void initState() {
    super.initState();
    if (widget.confirmacao != null) {
      _loadConfirmacao(widget.confirmacao!);
    } else {
      // Default para nova confirmação
      _dataLancamento = DateTime.now();
    }
  }

  void _loadConfirmacao(Confirmacao conf) {
    _ordemController.text = conf.ordem ?? '';
    _operacao2Controller.text = conf.operacao2 ?? '';
    _subOperController.text = conf.subOper ?? '';
    _centroDeTrabalhoController.text = conf.centroDeTrabalho ?? '';
    _centroController.text = conf.centro ?? '';
    _nomesController.text = conf.nomes ?? '';
    _nPessoalController.text = conf.nPessoal ?? '';
    _trabRealController.text = conf.trabReal?.toStringAsFixed(2) ?? '';
    _unidController.text = conf.unid ?? 'H';
    _textoConfirmacaoController.text = conf.textoConfirmacao ?? '';
    _confirmacaoFinalController.text = conf.confirmacaoFinal ?? '';
    _sTrabRestanteController.text = conf.sTrabRestante ?? '';
    _tipoAtividadeController.text = conf.tipoAtividade ?? '';

    _datInicioExec = conf.datInicioExec;
    _datFimExec = conf.datFimExec;
    _dataLancamento = conf.dataLancamento;

    // Parse time strings
    if (conf.horaInicio != null && conf.horaInicio!.isNotEmpty) {
      final parts = conf.horaInicio!.split(':');
      if (parts.length >= 2) {
        _horaInicio = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
    if (conf.horaFim != null && conf.horaFim!.isNotEmpty) {
      final parts = conf.horaFim!.split(':');
      if (parts.length >= 2) {
        _horaFim = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
  }

  @override
  void dispose() {
    _ordemController.dispose();
    _operacao2Controller.dispose();
    _subOperController.dispose();
    _centroDeTrabalhoController.dispose();
    _centroController.dispose();
    _nomesController.dispose();
    _nPessoalController.dispose();
    _trabRealController.dispose();
    _unidController.dispose();
    _textoConfirmacaoController.dispose();
    _confirmacaoFinalController.dispose();
    _sTrabRestanteController.dispose();
    _tipoAtividadeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, DateTime? initialDate, Function(DateTime) onSelected) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );
    if (date != null) {
      onSelected(date);
    }
  }

  Future<void> _selectTime(BuildContext context, TimeOfDay? initialTime, Function(TimeOfDay) onSelected) async {
    final time = await showTimePicker(
      context: context,
      initialTime: initialTime ?? TimeOfDay.now(),
    );
    if (time != null) {
      onSelected(time);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Selecionar';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return 'Selecionar';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _timeToString(TimeOfDay? time) {
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final payload = {
        'ordem': _ordemController.text.trim(),
        'operacao_2': _operacao2Controller.text.trim().isEmpty ? null : _operacao2Controller.text.trim(),
        'sub_oper': _subOperController.text.trim().isEmpty ? null : _subOperController.text.trim(),
        'centro_de_trab': _centroDeTrabalhoController.text.trim().isEmpty ? null : _centroDeTrabalhoController.text.trim(),
        'centro': _centroController.text.trim().isEmpty ? null : _centroController.text.trim(),
        'nomes': _nomesController.text.trim().isEmpty ? null : _nomesController.text.trim(),
        'n_pessoal': _nPessoalController.text.trim(),
        'trab_real': double.tryParse(_trabRealController.text.trim()),
        'unid': _unidController.text.trim(),
        'dat_inicio_exec': _datInicioExec != null
            ? '${_datInicioExec!.year.toString().padLeft(4, '0')}-${_datInicioExec!.month.toString().padLeft(2, '0')}-${_datInicioExec!.day.toString().padLeft(2, '0')}'
            : null,
        'hora_inicio': _timeToString(_horaInicio).isEmpty ? null : _timeToString(_horaInicio),
        'dat_fim_exec': _datFimExec != null
            ? '${_datFimExec!.year.toString().padLeft(4, '0')}-${_datFimExec!.month.toString().padLeft(2, '0')}-${_datFimExec!.day.toString().padLeft(2, '0')}'
            : null,
        'hora_fim': _timeToString(_horaFim).isEmpty ? null : _timeToString(_horaFim),
        'data_lancamento': _dataLancamento != null
            ? '${_dataLancamento!.year.toString().padLeft(4, '0')}-${_dataLancamento!.month.toString().padLeft(2, '0')}-${_dataLancamento!.day.toString().padLeft(2, '0')}'
            : null,
        'texto_confirmacao': _textoConfirmacaoController.text.trim().isEmpty ? null : _textoConfirmacaoController.text.trim(),
        'confirmacao_final': _confirmacaoFinalController.text.trim().isEmpty ? null : _confirmacaoFinalController.text.trim(),
        's_trab_restante': _sTrabRestanteController.text.trim().isEmpty ? null : _sTrabRestanteController.text.trim(),
        'tipo_atividade': _tipoAtividadeController.text.trim().isEmpty ? null : _tipoAtividadeController.text.trim(),
      };

      if (widget.confirmacao == null) {
        await _service.create(payload);
      } else {
        await _service.update(widget.confirmacao!.id, payload);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.confirmacao == null ? 'Confirmação criada com sucesso' : 'Confirmação atualizada com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    final formContent = Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            widget.confirmacao == null ? 'Nova Confirmação' : 'Editar Confirmação',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Campos obrigatórios
          TextFormField(
            controller: _ordemController,
            decoration: const InputDecoration(
              labelText: 'Ordem *',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Campo obrigatório';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _nPessoalController,
            decoration: const InputDecoration(
              labelText: 'Nº Pessoal (Matrícula) *',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Campo obrigatório';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _trabRealController,
                  decoration: const InputDecoration(
                    labelText: 'Trabalho Real *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Campo obrigatório';
                    }
                    final num = double.tryParse(value.trim());
                    if (num == null || num < 0) {
                      return 'Valor inválido';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _unidController,
                  decoration: const InputDecoration(
                    labelText: 'Unidade *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Obrigatório';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          OutlinedButton.icon(
            onPressed: () => _selectDate(context, _dataLancamento, (date) {
              setState(() => _dataLancamento = date);
            }),
            icon: const Icon(Icons.calendar_today),
            label: Text('Data Lançamento *: ${_formatDate(_dataLancamento)}'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.centerLeft,
            ),
          ),
          if (_dataLancamento == null)
            const Padding(
              padding: EdgeInsets.only(left: 12, top: 4),
              child: Text('Campo obrigatório', style: TextStyle(color: Colors.red, fontSize: 12)),
            ),
          const SizedBox(height: 24),

          const Divider(),
          const SizedBox(height: 16),
          const Text('Informações Adicionais', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          TextFormField(
            controller: _operacao2Controller,
            decoration: const InputDecoration(
              labelText: 'Operação 2',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _subOperController,
            decoration: const InputDecoration(
              labelText: 'Sub Operação',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _centroDeTrabalhoController,
            decoration: const InputDecoration(
              labelText: 'Centro de Trabalho',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _centroController,
            decoration: const InputDecoration(
              labelText: 'Centro',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _nomesController,
            decoration: const InputDecoration(
              labelText: 'Nomes',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _tipoAtividadeController,
            decoration: const InputDecoration(
              labelText: 'Tipo de Atividade',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _confirmacaoFinalController,
            decoration: const InputDecoration(
              labelText: 'Confirmação Final (S/N)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _sTrabRestanteController,
            decoration: const InputDecoration(
              labelText: 'S Trab Restante',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          const Divider(),
          const SizedBox(height: 16),
          const Text('Datas e Horários', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectDate(context, _datInicioExec, (date) {
                    setState(() => _datInicioExec = date);
                  }),
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text('Início: ${_formatDate(_datInicioExec)}'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(12),
                    alignment: Alignment.centerLeft,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectTime(context, _horaInicio, (time) {
                    setState(() => _horaInicio = time);
                  }),
                  icon: const Icon(Icons.access_time, size: 18),
                  label: Text(_formatTime(_horaInicio)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(12),
                    alignment: Alignment.centerLeft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectDate(context, _datFimExec, (date) {
                    setState(() => _datFimExec = date);
                  }),
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text('Fim: ${_formatDate(_datFimExec)}'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(12),
                    alignment: Alignment.centerLeft,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectTime(context, _horaFim, (time) {
                    setState(() => _horaFim = time);
                  }),
                  icon: const Icon(Icons.access_time, size: 18),
                  label: Text(_formatTime(_horaFim)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(12),
                    alignment: Alignment.centerLeft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          const Divider(),
          const SizedBox(height: 16),

          TextFormField(
            controller: _textoConfirmacaoController,
            decoration: const InputDecoration(
              labelText: 'Texto Confirmação',
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salvar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.confirmacao == null ? 'Nova Confirmação' : 'Editar Confirmação'),
        ),
        body: formContent,
      );
    }

    return Dialog(
      child: Container(
        width: 600,
        height: MediaQuery.of(context).size.height * 0.9,
        child: formContent,
      ),
    );
  }
}
