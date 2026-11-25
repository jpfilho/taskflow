import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../design_system/taskflow_design_system.dart';
import '../../domain/enums/task_apoio_enums.dart';
import '../../domain/models/task_apoio_periodo.dart';
import '../../domain/models/task_apoio_requisito_recurso.dart';
import '../../domain/models/task_apoio_solicitacao.dart';
import '../../domain/models/task_apoio_tipo.dart';
import '../../domain/validators/task_apoio_validator.dart';
import '../utils/task_apoio_formatters.dart';

/// Item organizacional genérico para o seletor hierárquico Regional -> Divisão -> Segmento.
class TaskApoioUnidadeOpcao {
  final String id;
  final String nome;
  final String? parentId;
  final List<String> parentIds;

  const TaskApoioUnidadeOpcao({
    required this.id,
    required this.nome,
    this.parentId,
    this.parentIds = const [],
  });
}

/// Diálogo simplificado de solicitação de apoio operacional (Itens 9, 10 e 11).
/// Exibe 7 campos essenciais pré-preenchidos + seção recolhível "Opções adicionais".
class TaskApoioSolicitarDialog extends StatefulWidget {
  final String? taskSolicitanteId;
  final String taskSolicitanteTitulo;
  final String? taskSolicitanteOrdem;
  final String regionalSolicitanteId;
  final String divisaoSolicitanteId;
  final String? segmentoSolicitanteId;
  final String usuarioSolicitanteId;
  final DateTime dataInicioSugerida;
  final DateTime dataFimSugerida;
  final String? localSugerido;
  final List<TaskApoioTipo> tiposApoio;
  final List<TaskApoioUnidadeOpcao> regionais;
  final List<TaskApoioUnidadeOpcao> divisoes;
  final List<TaskApoioUnidadeOpcao> segmentos;
  final Future<List<TaskApoioUnidadeOpcao>> Function(String divisaoId)?
      onCarregarSegmentosPorDivisao;
  final TaskApoioSolicitacao? solicitacaoParaEditar;
  final bool isRascunhoPreSalvamento;

  const TaskApoioSolicitarDialog({
    super.key,
    this.taskSolicitanteId,
    required this.taskSolicitanteTitulo,
    this.taskSolicitanteOrdem,
    required this.regionalSolicitanteId,
    required this.divisaoSolicitanteId,
    this.segmentoSolicitanteId,
    required this.usuarioSolicitanteId,
    required this.dataInicioSugerida,
    required this.dataFimSugerida,
    this.localSugerido,
    required this.tiposApoio,
    required this.regionais,
    required this.divisoes,
    this.segmentos = const [],
    this.onCarregarSegmentosPorDivisao,
    this.solicitacaoParaEditar,
    this.isRascunhoPreSalvamento = false,
  });

  @override
  State<TaskApoioSolicitarDialog> createState() =>
      _TaskApoioSolicitarDialogState();
}

class _TaskApoioSolicitarDialogState extends State<TaskApoioSolicitarDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fmt = DateFormat('dd/MM/yyyy HH:mm');

  late String? _regionalDestinoId;
  late String? _divisaoDestinoId;
  String? _segmentoDestinoId;
  late String? _tipoApoioId;
  late TaskApoioCriticidade _criticidade;
  late TaskApoioPrioridade _prioridade;
  late DateTime _dataInicio;
  late DateTime _dataFim;
  DateTime? _prazoResposta;

  late final TextEditingController _descricaoCtrl;
  late final TextEditingController _localCtrl;
  late final TextEditingController _observacoesCtrl;
  late final TextEditingController _tipoVeiculoCtrl;
  late final TextEditingController _capacidadeCtrl;
  late final TextEditingController _qtdVeiculosCtrl;

  bool _exigeOperador = false;
  bool _mostrarOpcoesAdicionais = false;
  final List<TaskApoioPeriodo> _periodosDescontinuos = [];
  String? _erroValidacao;
  List<TaskApoioUnidadeOpcao> _segmentosDinamicos = const [];
  bool _carregandoSegmentos = false;

  @override
  void initState() {
    super.initState();
    final edit = widget.solicitacaoParaEditar;
    _regionalDestinoId = edit?.regionalDestinoId ??
        (widget.regionais.any((r) => r.id == widget.regionalSolicitanteId)
            ? widget.regionalSolicitanteId
            : (widget.regionais.isNotEmpty ? widget.regionais.first.id : null));

    final divsDisponiveis = _divisoesFiltradas(_regionalDestinoId);
    _divisaoDestinoId = edit?.divisaoDestinoId ??
        (divsDisponiveis.isNotEmpty ? divsDisponiveis.first.id : null);
    _segmentoDestinoId = edit?.segmentoDestinoId;

    _tipoApoioId = edit?.tipoApoioId ??
        (widget.tiposApoio.isNotEmpty ? widget.tiposApoio.first.id : null);
    _criticidade = edit?.criticidade ?? TaskApoioCriticidade.essencial;
    _prioridade = edit?.prioridade ?? TaskApoioPrioridade.media;
    _dataInicio = edit?.dataInicioSolicitada ?? widget.dataInicioSugerida;
    _dataFim = edit?.dataFimSolicitada ?? widget.dataFimSugerida;
    _prazoResposta = edit?.prazoResposta;

    _descricaoCtrl = TextEditingController(text: edit?.descricao ?? '');
    _localCtrl = TextEditingController(
      text: TaskApoioFormatters.formatarLocaisAtendimento(
        edit?.locaisAtendimento ?? widget.localSugerido,
      ),
    );
    _observacoesCtrl = TextEditingController(text: edit?.observacoes ?? '');
    _tipoVeiculoCtrl = TextEditingController(
      text: edit?.requisitosRecursos?.tipoVeiculo ?? '',
    );
    _capacidadeCtrl = TextEditingController(
      text: edit?.requisitosRecursos?.capacidadeMinima ?? '',
    );
    _qtdVeiculosCtrl = TextEditingController(
      text: edit?.requisitosRecursos?.quantidadeVeiculos?.toString() ?? '',
    );
    _exigeOperador = edit?.requisitosRecursos?.exigeOperador ?? false;
    if (edit != null) {
      _periodosDescontinuos.addAll(
        edit.periodos
            .where((p) => p.origemPeriodo == TaskApoioOrigemPeriodo.solicitacao),
      );
    }
    _carregarSegmentosParaDivisao(_divisaoDestinoId);
  }

  Future<void> _carregarSegmentosParaDivisao(String? divisaoId) async {
    final loader = widget.onCarregarSegmentosPorDivisao;
    if (loader == null || divisaoId == null || divisaoId.isEmpty) return;
    setState(() => _carregandoSegmentos = true);
    try {
      final carregados = await loader(divisaoId);
      if (!mounted || _divisaoDestinoId != divisaoId) return;
      setState(() {
        _segmentosDinamicos = carregados;
        if (_segmentoDestinoId != null &&
            !carregados.any((s) => s.id == _segmentoDestinoId)) {
          _segmentoDestinoId = null;
        }
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _carregandoSegmentos = false);
    }
  }

  @override
  void dispose() {
    _descricaoCtrl.dispose();
    _localCtrl.dispose();
    _observacoesCtrl.dispose();
    _tipoVeiculoCtrl.dispose();
    _capacidadeCtrl.dispose();
    _qtdVeiculosCtrl.dispose();
    super.dispose();
  }

  List<TaskApoioUnidadeOpcao> _divisoesFiltradas(String? regionalId) {
    if (regionalId == null) return const [];
    final filhas = widget.divisoes.where((d) {
      if (d.parentIds.isNotEmpty) return d.parentIds.contains(regionalId);
      return d.parentId == null || d.parentId == regionalId;
    }).toList();
    return filhas;
  }

  List<TaskApoioUnidadeOpcao> _segmentosFiltrados(String? divisaoId) {
    if (divisaoId == null) return const [];
    if (widget.onCarregarSegmentosPorDivisao != null) {
      return _segmentosDinamicos;
    }
    return widget.segmentos
        .where((s) => s.parentId == null || s.parentId == divisaoId)
        .toList();
  }

  Future<void> _selecionarDataHora(bool isInicio) async {
    final base = isInicio ? _dataInicio : _dataFim;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2024),
      lastDate: DateTime(2032),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (!mounted) return;
    final hora = pickedTime?.hour ?? base.hour;
    final min = pickedTime?.minute ?? base.minute;
    final novo = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      hora,
      min,
    );
    setState(() {
      if (isInicio) {
        _dataInicio = novo;
      } else {
        _dataFim = novo;
      }
    });
  }

  void _confirmar() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_segmentoDestinoId == null || _segmentoDestinoId!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O segmento de destino é obrigatório.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final qtdV = int.tryParse(_qtdVeiculosCtrl.text.trim());
    final reqRecurso = (_tipoVeiculoCtrl.text.trim().isNotEmpty ||
            _capacidadeCtrl.text.trim().isNotEmpty ||
            (qtdV != null && qtdV > 0) ||
            _exigeOperador)
        ? TaskApoioRequisitoRecurso(
            tipoVeiculo: _tipoVeiculoCtrl.text.trim().isEmpty
                ? null
                : _tipoVeiculoCtrl.text.trim(),
            capacidadeMinima: _capacidadeCtrl.text.trim().isEmpty
                ? null
                : _capacidadeCtrl.text.trim(),
            quantidadeVeiculos: qtdV,
            exigeVeiculo:
                _tipoVeiculoCtrl.text.trim().isNotEmpty || (qtdV ?? 0) > 0,
            exigeOperador: _exigeOperador,
            localAtendimento: _localCtrl.text.trim().isEmpty
                ? null
                : _localCtrl.text.trim(),
            especificacaoEstruturada: true,
          )
        : null;

    final edit = widget.solicitacaoParaEditar;
    final id = edit?.id ?? 'sol-${DateTime.now().microsecondsSinceEpoch}';
    final sol = TaskApoioSolicitacao(
      id: id,
      idempotencyKey: edit?.idempotencyKey ?? 'idem-$id',
      taskSolicitanteId: widget.taskSolicitanteId,
      taskSolicitanteTituloSnapshot: widget.taskSolicitanteTitulo,
      taskSolicitanteOrdemSnapshot: widget.taskSolicitanteOrdem,
      regionalSolicitanteId: widget.regionalSolicitanteId,
      divisaoSolicitanteId: widget.divisaoSolicitanteId,
      segmentoSolicitanteId: widget.segmentoSolicitanteId,
      regionalDestinoId: _regionalDestinoId ?? '',
      divisaoDestinoId: _divisaoDestinoId ?? '',
      segmentoDestinoId: _segmentoDestinoId,
      tipoApoioId: _tipoApoioId ?? '',
      criticidade: _criticidade,
      prioridade: _prioridade,
      descricao: _descricaoCtrl.text.trim(),
      locaisAtendimento:
          _localCtrl.text.trim().isEmpty ? null : _localCtrl.text.trim(),
      dataInicioSolicitada: _dataInicio.toUtc(),
      dataFimSolicitada: _dataFim.toUtc(),
      prazoResposta: _prazoResposta?.toUtc(),
      observacoes: _observacoesCtrl.text.trim().isEmpty
          ? null
          : _observacoesCtrl.text.trim(),
      solicitanteUsuarioId: widget.usuarioSolicitanteId,
      versao: edit?.versao ?? 1,
      status: edit?.status ?? TaskApoioStatus.pendente,
      periodos: _periodosDescontinuos,
      requisitosRecursos: reqRecurso,
      syncStatus: widget.isRascunhoPreSalvamento
          ? TaskApoioSyncStatus.pendenteSync
          : (edit?.syncStatus ?? TaskApoioSyncStatus.confirmadoServidor),
    );

    final erros = TaskApoioValidator.validarSolicitacao(sol);
    if (erros.isNotEmpty) {
      setState(() => _erroValidacao = erros.first);
      return;
    }

    Navigator.of(context).pop(sol);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typo = context.tfTypography;
    final divisoes = _divisoesFiltradas(_regionalDestinoId);
    final segmentos = _segmentosFiltrados(_divisaoDestinoId);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Row(
        children: [
          Icon(Icons.handshake_outlined, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.solicitacaoParaEditar != null
                  ? 'Editar Solicitação de Apoio'
                  : 'Solicitar Apoio Operacional',
              style: typo.sectionTitle,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isRascunhoPreSalvamento)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: colors.infoBackground,
                      borderRadius: TFRadius.borderRadiusSm,
                      border: Border.all(color: colors.info.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.edit_note_rounded, size: 16, color: colors.info),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Rascunho: será enviado após salvar a atividade principal',
                            style: typo.bodySmall.copyWith(color: colors.info),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_erroValidacao != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: colors.dangerBackground,
                      borderRadius: TFRadius.borderRadiusSm,
                      border: Border.all(color: colors.danger.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, size: 16, color: colors.danger),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _erroValidacao!,
                            style: typo.bodySmall.copyWith(color: colors.danger),
                          ),
                        ),
                      ],
                    ),
                  ),

                // 1. Regional de destino
                DropdownButtonFormField<String>(
                  initialValue: _regionalDestinoId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Regional de destino *',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.regionais
                      .map((r) => DropdownMenuItem(value: r.id, child: Text(r.nome)))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _regionalDestinoId = val;
                      final novasDivs = _divisoesFiltradas(val);
                      _divisaoDestinoId =
                          novasDivs.isNotEmpty ? novasDivs.first.id : null;
                      _segmentoDestinoId = null;
                      _segmentosDinamicos = const [];
                    });
                    _carregarSegmentosParaDivisao(_divisaoDestinoId);
                  },
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Selecione a regional' : null,
                ),
                const SizedBox(height: 12),

                // 2. Divisão de destino
                DropdownButtonFormField<String>(
                  key: ValueKey('div-${_regionalDestinoId ?? ''}-${_divisaoDestinoId ?? ''}'),
                  initialValue: divisoes.any((d) => d.id == _divisaoDestinoId)
                      ? _divisaoDestinoId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Divisão de destino *',
                    border: OutlineInputBorder(),
                  ),
                  items: divisoes
                      .map((d) => DropdownMenuItem(value: d.id, child: Text(d.nome)))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _divisaoDestinoId = val;
                      _segmentoDestinoId = null;
                      _segmentosDinamicos = const [];
                    });
                    _carregarSegmentosParaDivisao(val);
                  },
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Selecione a divisão' : null,
                ),
                const SizedBox(height: 12),

                // 3. Segmento de destino (obrigatório)
                DropdownButtonFormField<String>(
                  key: ValueKey('seg-${_divisaoDestinoId ?? ''}-${_segmentoDestinoId ?? ''}-${segmentos.length}'),
                  initialValue: segmentos.any((s) => s.id == _segmentoDestinoId)
                      ? _segmentoDestinoId
                      : null,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: _carregandoSegmentos
                        ? 'Segmento de destino * (carregando...)'
                        : 'Segmento de destino *',
                    border: const OutlineInputBorder(),
                  ),
                  items: segmentos
                      .map(
                        (s) => DropdownMenuItem(value: s.id, child: Text(s.nome)),
                      )
                      .toList(),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Selecione o segmento de destino'
                      : null,
                  onChanged: (val) => setState(() => _segmentoDestinoId = val),
                ),
                const SizedBox(height: 12),

                // 4. Tipo de apoio
                DropdownButtonFormField<String>(
                  initialValue: widget.tiposApoio.any((t) => t.id == _tipoApoioId)
                      ? _tipoApoioId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de apoio *',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.tiposApoio
                      .map((t) => DropdownMenuItem(value: t.id, child: Text(t.nome)))
                      .toList(),
                  onChanged: (val) => setState(() => _tipoApoioId = val),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Selecione o tipo' : null,
                ),
                const SizedBox(height: 12),

                // 5. Descrição da necessidade
                TextFormField(
                  controller: _descricaoCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descrição da necessidade *',
                    hintText:
                        'Ex.: Caminhão Munck com operador para içamento na SE',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe o que é necessário'
                      : null,
                ),
                const SizedBox(height: 12),

                // 6. Período necessário
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => _selecionarDataHora(true),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today, size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Início: ${_fmt.format(_dataInicio.toLocal())}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => _selecionarDataHora(false),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.event, size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Fim: ${_fmt.format(_dataFim.toLocal())}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 7. Classificação essencial ou complementar (responsivo sem overflow)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Essencial'),
                      avatar: const Icon(Icons.priority_high_rounded, size: 16),
                      selected: _criticidade == TaskApoioCriticidade.essencial,
                      onSelected: (_) => setState(
                        () => _criticidade = TaskApoioCriticidade.essencial,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('Complementar'),
                      avatar: const Icon(Icons.add_circle_outline, size: 16),
                      selected:
                          _criticidade == TaskApoioCriticidade.complementar,
                      onSelected: (_) => setState(
                        () => _criticidade = TaskApoioCriticidade.complementar,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                // Seção recolhível "Opções adicionais" (Item 10)
                InkWell(
                  onTap: () => setState(
                    () => _mostrarOpcoesAdicionais = !_mostrarOpcoesAdicionais,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          _mostrarOpcoesAdicionais
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Opções adicionais (opcional)',
                            style: typo.labelMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_mostrarOpcoesAdicionais) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<TaskApoioPrioridade>(
                    initialValue: _prioridade,
                    decoration: const InputDecoration(
                      labelText: 'Prioridade',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: TaskApoioPrioridade.urgente,
                        child: Text('Urgente'),
                      ),
                      DropdownMenuItem(
                        value: TaskApoioPrioridade.alta,
                        child: Text('Alta'),
                      ),
                      DropdownMenuItem(
                        value: TaskApoioPrioridade.media,
                        child: Text('Média'),
                      ),
                      DropdownMenuItem(
                        value: TaskApoioPrioridade.baixa,
                        child: Text('Baixa'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _prioridade = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _localCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Local de atendimento (se diferente)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _tipoVeiculoCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de veículo / equipamento',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 100,
                        child: TextFormField(
                          controller: _qtdVeiculosCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Qtd.',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _capacidadeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Capacidade necessária (ex.: 12t)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Necessita operador alocado'),
                    value: _exigeOperador,
                    onChanged: (v) => setState(() => _exigeOperador = v),
                  ),
                  TextFormField(
                    controller: _observacoesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Observações complementares',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            TFButton(
              label: 'Cancelar',
              size: TFButtonSize.small,
              variant: TFButtonVariant.tertiary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            TFButton(
              label: widget.isRascunhoPreSalvamento
                  ? 'Adicionar rascunho'
                  : 'Enviar solicitação',
              size: TFButtonSize.small,
              variant: TFButtonVariant.primary,
              leadingIcon: Icons.send_rounded,
              onPressed: _confirmar,
            ),
          ],
        ),
      ],
    );
  }
}
