import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/confirmacao.dart';
import '../models/confirmacao_sap.dart';
import '../services/confirmacao_service.dart';
import '../services/confirmacao_sap_service.dart';
import '../utils/responsive.dart';

class ConfirmacaoFormDialog extends StatefulWidget {
  final Confirmacao? confirmacao;
  final ConfirmacaoSap? sapData;
  final String? initialOrdem;
  final String? initialNPessoal;
  final String? initialNomes;

  const ConfirmacaoFormDialog({
    super.key,
    this.confirmacao,
    this.sapData,
    this.initialOrdem,
    this.initialNPessoal,
    this.initialNomes,
  });

  @override
  State<ConfirmacaoFormDialog> createState() => _ConfirmacaoFormDialogState();
}

class _ConfirmacaoFormDialogState extends State<ConfirmacaoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final ConfirmacaoService _service = ConfirmacaoService();
  final ConfirmacaoSapService _sapService = ConfirmacaoSapService();

  bool _isSaving = false;

  // controllers
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
  static const List<String> _tipoAtividadeOptions = [
    'HCOOM',
    'HHE050',
    'HHE100',
  ];
  static const List<String> _simNaoOptions = ['SIM', 'NAO'];
  final _textoBreveOperacaoController = TextEditingController();

  Timer? _ordemDebounce;

  DateTime? _datInicioExec;
  TimeOfDay? _horaInicio;
  DateTime? _datFimExec;
  TimeOfDay? _horaFim;
  DateTime? _dataLancamento;

  // Operações carregadas da ordem (confirmacao_sap)
  List<ConfirmacaoSap> _operacoesDaOrdem = [];
  String? _operacaoKeySelecionada; // chave única: operacao|sub_operacao

  String _opKey(ConfirmacaoSap it) =>
      '${it.operacao ?? ''}|${it.subOperacao ?? ''}';

  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      return TimeOfDay(hour: h, minute: m);
    }
    return null;
  }

  void _aplicarSelecaoSap(ConfirmacaoSap chosen) {
    setState(() {
      _operacaoKeySelecionada = _opKey(chosen);
      _operacao2Controller.text = chosen.operacao ?? '';
      _subOperController.text = chosen.subOperacao ?? '';
      _centroDeTrabalhoController.text = chosen.centroTrabalho ?? '';
      _centroController.text = chosen.centroCusto ?? '';
      _textoBreveOperacaoController.text = chosen.textoBreveOperacao ?? '';
      if ((_nomesController.text).trim().isEmpty) {
        _nomesController.text = chosen.criadoPor ?? '';
      }
      if (chosen.trabalhoReal != null) {
        _trabRealController.text = chosen.trabalhoReal!.toStringAsFixed(2);
      }
      if (_dataLancamento == null && chosen.dataConfirmacao != null) {
        _dataLancamento = chosen.dataConfirmacao;
      }
      // Datas/horas do formulário a partir da tabela SAP
      if (chosen.restricaoInicio != null) {
        _datInicioExec = chosen.restricaoInicio;
      }
      final ti = _parseTime(chosen.resHorIn);
      if (ti != null) _horaInicio = ti;
      if (chosen.fimRestricao != null) {
        _datFimExec = chosen.fimRestricao;
      }
      final tf = _parseTime(chosen.resHoraF);
      if (tf != null) _horaFim = tf;
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.confirmacao != null) _loadConfirmacao(widget.confirmacao!);
    _dataLancamento ??= DateTime.now();

    _ordemController.addListener(() {
      _ordemDebounce?.cancel();
      _ordemDebounce = Timer(const Duration(milliseconds: 700), () {
        final ordem = _ordemController.text.trim();
        if (ordem.isNotEmpty) _populateFromSap(ordem);
      });
    });

    // Se veio uma seleção do passo anterior (SAP), pré-carrega a ordem e apresenta as operações disponíveis
    if (widget.sapData != null && (widget.sapData!.ordem ?? '').isNotEmpty) {
      _ordemController.text = widget.sapData!.ordem!;
      // Executa após o primeiro frame para garantir contexto pronto
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _populateFromSap(widget.sapData!.ordem!);
      });
    }

    // Ou, se vier apenas a ordem inicial
    if ((widget.sapData == null) &&
        (widget.initialOrdem != null) &&
        widget.initialOrdem!.isNotEmpty) {
      _ordemController.text = widget.initialOrdem!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _populateFromSap(widget.initialOrdem!);
      });
    }

    // Pré-preencher matrícula caso tenha sido informada pela origem
    if ((widget.initialNPessoal ?? '').isNotEmpty &&
        _nPessoalController.text.isEmpty) {
      _nPessoalController.text = widget.initialNPessoal!;
    }

    if ((widget.initialNomes ?? '').isNotEmpty &&
        _nomesController.text.isEmpty) {
      _nomesController.text = widget.initialNomes!;
    }

    // Valor padrão para Tipo de Atividade, se não vier preenchido
    if (_tipoAtividadeController.text.trim().isEmpty) {
      _tipoAtividadeController.text = 'HCOOM';
    }

    // Ao editar (ou abrir sem initialOrdem), se já existe ordem no campo, carregar operações
    if (_ordemController.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _populateFromSap(_ordemController.text.trim());
      });
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
    _dataLancamento = conf.dataLancamento ?? _dataLancamento;

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
    _ordemDebounce?.cancel();
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
    _textoBreveOperacaoController.dispose();
    super.dispose();
  }

  Future<void> _populateFromSap(String ordem) async {
    try {
      var results = await _sapService.list(
        filters: {'ordem': ordem},
        pageSize: 200,
      );
      if (results.isEmpty) {
        results = await _sapService.list(search: ordem, pageSize: 200);
      }
      if (!mounted) return;
      setState(() {
        _operacoesDaOrdem = results;
      });
      if (results.isEmpty) return;

      // Preferir operação já preenchida (edição) senão a primeira opção
      ConfirmacaoSap? chosen;
      if (_operacao2Controller.text.trim().isNotEmpty) {
        chosen = results.firstWhere(
          (e) =>
              (e.operacao ?? '') == _operacao2Controller.text.trim() &&
              (e.subOperacao ?? '') == _subOperController.text.trim(),
          orElse: () => results.first,
        );
      } else {
        chosen = results.first;
      }
      _aplicarSelecaoSap(chosen);
    } catch (e) {
      if (kDebugMode) print('Erro ao buscar SAP: $e');
    }
  }

  Future<ConfirmacaoSap?> _showSapOptionsDialog(
    List<ConfirmacaoSap> items,
  ) async {
    return showDialog<ConfirmacaoSap>(
      context: context,
      builder: (context) {
        return Dialog(
          child: SizedBox(
            width: 700,
            height: 420,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    'Selecione a opção SAP',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, idx) {
                      final it = items[idx];
                      return ListTile(
                        title: Text(
                          '${it.operacao ?? ''} ${it.textoBreveOperacao ?? ''}'
                              .trim(),
                        ),
                        subtitle: Text(
                          '${it.centroTrabalho ?? ''} • ${it.criadoPor ?? ''}',
                        ),
                        onTap: () => Navigator.of(context).pop(it),
                      );
                    },
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('Cancelar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectDate(
    BuildContext context,
    DateTime? initial,
    ValueChanged<DateTime> onSelected,
  ) async {
    final d = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );
    if (d != null) onSelected(d);
  }

  Future<void> _selectTime(
    BuildContext context,
    TimeOfDay? initial,
    ValueChanged<TimeOfDay> onSelected,
  ) async {
    final t = await showTimePicker(
      context: context,
      initialTime: initial ?? TimeOfDay.now(),
    );
    if (t != null) onSelected(t);
  }

  String _formatDate(DateTime? date) =>
      date == null ? 'Selecionar' : DateFormat('dd/MM/yyyy').format(date);
  String _formatTime(TimeOfDay? time) => time == null
      ? 'Selecionar'
      : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  String _timeToString(TimeOfDay? time) => time == null
      ? ''
      : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final payload = {
        'ordem': _ordemController.text.trim(),
        'operacao_2': _operacao2Controller.text.trim().isEmpty
            ? null
            : _operacao2Controller.text.trim(),
        'sub_oper': _subOperController.text.trim().isEmpty
            ? null
            : _subOperController.text.trim(),
        'centro_de_trab': _centroDeTrabalhoController.text.trim().isEmpty
            ? null
            : _centroDeTrabalhoController.text.trim(),
        'centro': _centroController.text.trim().isEmpty
            ? null
            : _centroController.text.trim(),
        'nomes': _nomesController.text.trim().isEmpty
            ? null
            : _nomesController.text.trim(),
        'n_pessoal': _nPessoalController.text.trim(),
        'trab_real': double.tryParse(_trabRealController.text.trim()),
        'unid': _unidController.text.trim(),
        'dat_inicio_exec': _datInicioExec != null
            ? '${_datInicioExec!.year.toString().padLeft(4, '0')}-${_datInicioExec!.month.toString().padLeft(2, '0')}-${_datInicioExec!.day.toString().padLeft(2, '0')}'
            : null,
        'hora_inicio': _timeToString(_horaInicio).isEmpty
            ? null
            : _timeToString(_horaInicio),
        'dat_fim_exec': _datFimExec != null
            ? '${_datFimExec!.year.toString().padLeft(4, '0')}-${_datFimExec!.month.toString().padLeft(2, '0')}-${_datFimExec!.day.toString().padLeft(2, '0')}'
            : null,
        'hora_fim': _timeToString(_horaFim).isEmpty
            ? null
            : _timeToString(_horaFim),
        'data_lancamento': _dataLancamento != null
            ? '${_dataLancamento!.year.toString().padLeft(4, '0')}-${_dataLancamento!.month.toString().padLeft(2, '0')}-${_dataLancamento!.day.toString().padLeft(2, '0')}'
            : null,
        'texto_confirmacao': _textoConfirmacaoController.text.trim().isEmpty
            ? null
            : _textoConfirmacaoController.text.trim(),
        'confirmacao_final': _confirmacaoFinalController.text.trim().isEmpty
            ? null
            : _confirmacaoFinalController.text.trim(),
        's_trab_restante': _sTrabRestanteController.text.trim().isEmpty
            ? null
            : _sTrabRestanteController.text.trim(),
        'tipo_atividade': _tipoAtividadeController.text.trim().isEmpty
            ? null
            : _tipoAtividadeController.text.trim(),
      };

      final isNew =
          widget.confirmacao == null ||
          (widget.confirmacao!.id.isNotEmpty &&
              widget.confirmacao!.id.startsWith('new-'));

      if (isNew) {
        await _service.create(payload);
      } else {
        await _service.update(widget.confirmacao!.id, payload);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isNew
                  ? 'Confirmação criada com sucesso'
                  : 'Confirmação atualizada com sucesso',
            ),
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
      return;
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
            widget.confirmacao == null
                ? 'Nova Confirmação'
                : 'Editar Confirmação',
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
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Campo obrigatório' : null,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _nPessoalController,
            decoration: const InputDecoration(
              labelText: 'Nº Pessoal (Matrícula) *',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Campo obrigatório' : null,
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}'),
                    ),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Campo obrigatório';
                    }
                    final n = double.tryParse(v.trim());
                    if (n == null || n < 0) return 'Valor inválido';
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
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Obrigatório' : null,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          OutlinedButton.icon(
            onPressed: () => _selectDate(
              context,
              _dataLancamento,
              (d) => setState(() => _dataLancamento = d),
            ),
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
              child: Text(
                'Campo obrigatório',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          const SizedBox(height: 24),

          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'Informações Adicionais',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            initialValue: _operacaoKeySelecionada,
            items: _operacoesDaOrdem
                .map(
                  (it) => DropdownMenuItem<String>(
                    value: _opKey(it),
                    child: Text(
                      '${it.operacao ?? ''} — ${it.textoBreveOperacao ?? ''}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _operacoesDaOrdem.isEmpty
                ? null
                : (v) {
                    if (v == null) return;
                    final sel = _operacoesDaOrdem.firstWhere(
                      (e) => _opKey(e) == v,
                      orElse: () => _operacoesDaOrdem.first,
                    );
                    _aplicarSelecaoSap(sel);
                  },
            decoration: const InputDecoration(
              labelText: 'Operação',
              border: OutlineInputBorder(),
            ),
            hint: const Text('Selecione uma operação'),
            disabledHint: const Text('Informe a ordem para carregar operações'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _textoBreveOperacaoController,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Texto Breve da Operação',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          // Campo "Sub Operação" oculto (preenchido internamente quando a Operação é escolhida)
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
          DropdownButtonFormField<String>(
            initialValue: _tipoAtividadeOptions.contains(_tipoAtividadeController.text)
                ? _tipoAtividadeController.text
                : null,
            items: _tipoAtividadeOptions
                .map(
                  (opt) =>
                      DropdownMenuItem<String>(value: opt, child: Text(opt)),
                )
                .toList(),
            onChanged: (v) {
              setState(() {
                _tipoAtividadeController.text = v ?? '';
              });
            },
            validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null,
            decoration: const InputDecoration(
              labelText: 'Tipo de Atividade',
              border: OutlineInputBorder(),
            ),
            hint: const Text('Selecione'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _simNaoOptions.contains(_confirmacaoFinalController.text)
                ? _confirmacaoFinalController.text
                : null,
            items: _simNaoOptions
                .map(
                  (opt) =>
                      DropdownMenuItem<String>(value: opt, child: Text(opt)),
                )
                .toList(),
            onChanged: (v) {
              setState(() {
                _confirmacaoFinalController.text = v ?? '';
              });
            },
            validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null,
            decoration: const InputDecoration(
              labelText: 'Confirmação Final (S/N)',
              border: OutlineInputBorder(),
            ),
            hint: const Text('Selecione'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _simNaoOptions.contains(_sTrabRestanteController.text)
                ? _sTrabRestanteController.text
                : null,
            items: _simNaoOptions
                .map(
                  (opt) =>
                      DropdownMenuItem<String>(value: opt, child: Text(opt)),
                )
                .toList(),
            onChanged: (v) {
              setState(() {
                _sTrabRestanteController.text = v ?? '';
              });
            },
            validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null,
            decoration: const InputDecoration(
              labelText: 'S Trab Restante',
              border: OutlineInputBorder(),
            ),
            hint: const Text('Selecione'),
          ),
          const SizedBox(height: 24),

          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'Datas e Horários',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectDate(
                    context,
                    _datInicioExec,
                    (d) => setState(() => _datInicioExec = d),
                  ),
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
                  onPressed: () => _selectTime(
                    context,
                    _horaInicio,
                    (t) => setState(() => _horaInicio = t),
                  ),
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
                  onPressed: () => _selectDate(
                    context,
                    _datFimExec,
                    (d) => setState(() => _datFimExec = d),
                  ),
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
                  onPressed: () => _selectTime(
                    context,
                    _horaFim,
                    (t) => setState(() => _horaFim = t),
                  ),
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
          title: Text(
            widget.confirmacao == null
                ? 'Nova Confirmação'
                : 'Editar Confirmação',
          ),
        ),
        body: formContent,
      );
    }

    return Dialog(
      child: SizedBox(
        width: 600,
        height: MediaQuery.of(context).size.height * 0.9,
        child: formContent,
      ),
    );
  }
}
