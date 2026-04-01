import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:dropdown_search/dropdown_search.dart';
import '../models/task.dart';
import '../models/pex.dart';
import '../models/si.dart';
import '../models/equipe.dart';
import '../models/equipe_executor.dart';
import '../models/executor.dart';
import '../services/pex_service.dart';
import '../services/si_service.dart';
import '../services/equipe_service.dart';
import '../services/executor_service.dart';
import '../services/auth_service_simples.dart';
import '../services/local_service.dart';
import '../models/local.dart';
import '../utils/responsive.dart';
import 'si_selection_dialog.dart';

class PEXFormDialog extends StatefulWidget {
  final Task task;
  final PEX? pex;

  const PEXFormDialog({
    super.key,
    required this.task,
    this.pex,
  });

  @override
  State<PEXFormDialog> createState() => _PEXFormDialogState();
}

class _PEXFormDialogState extends State<PEXFormDialog> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final PEXService _pexService = PEXService();
  final SIService _siService = SIService();
  final EquipeService _equipeService = EquipeService();
  final ExecutorService _executorService = ExecutorService();
  final AuthServiceSimples _authService = AuthServiceSimples();
  final LocalService _localService = LocalService();
  late TabController _tabController;
  
  // SIs vinculadas à tarefa
  List<SI> _sisVinculadas = [];
  
  // Equipes e executores
  List<Equipe> _equipesTarefa = [];
  List<Executor> _executoresFiltrados = []; // Executores filtrados pelo perfil do usuário
  bool _isLoadingExecutores = false; // Flag para indicar carregamento de executores
  
  // Locais para Instalação
  List<Local> _locaisList = [];
  Set<String> _selectedInstalacaoIds = {}; // IDs dos locais selecionados para instalação
  List<Local?> _instalacoesSelecionadas = []; // Lista de locais selecionados (um por dropdown)
  
  // Controllers
  late TextEditingController _numeroPexController;
  late TextEditingController _siController;
  late TextEditingController _revisaoPexController;
  
  // Identificação
  late TextEditingController _responsavelNomeController;
  late TextEditingController _responsavelIdSapController;
  late TextEditingController _responsavelContatoController;
  late TextEditingController _substitutoNomeController;
  late TextEditingController _substitutoIdSapController;
  late TextEditingController _substitutoContatoController;
  late TextEditingController _fiscalTecnicoNomeController;
  late TextEditingController _fiscalTecnicoIdSapController;
  late TextEditingController _fiscalTecnicoContatoController;
  late TextEditingController _coordenadorNomeController;
  late TextEditingController _coordenadorIdSapController;
  late TextEditingController _coordenadorContatoController;
  late TextEditingController _tecnicoSegNomeController;
  late TextEditingController _tecnicoSegIdSapController;
  late TextEditingController _tecnicoSegContatoController;
  
  late TextEditingController _instalacaoController;
  late TextEditingController _equipamentosController;
  late TextEditingController _resumoAtividadeController;
  late TextEditingController _configuracaoRecebimentoController;
  late TextEditingController _configuracaoDuranteController;
  late TextEditingController _configuracaoDevolucaoController;
  late TextEditingController _aterramentoDescricaoController;
  late TextEditingController _aterramentoTotalUnidadesController;
  late TextEditingController _informacoesAdicionaisController;
  late TextEditingController _nivelRiscoController;
  late TextEditingController _aprovadorController;
  
  // Datas e Horas
  DateTime? _dataElaboracao;
  DateTime? _dataInicio;
  String _horaInicio = '08:00';
  DateTime? _dataFim;
  String _horaFim = '17:00';
  bool _periodicidade = false;
  bool _continuo = false;
  DateTime? _dataAprovacao;
  
  // Recursos (JSON)
  List<Map<String, dynamic>> _recursosEpi = [];
  List<Map<String, dynamic>> _recursosEpc = [];
  List<Map<String, dynamic>> _recursosTransporte = [];
  List<Map<String, dynamic>> _recursosMaterialConsumo = [];
  List<Map<String, dynamic>> _recursosFerramentas = [];
  List<Map<String, dynamic>> _recursosComunicacao = [];
  List<Map<String, dynamic>> _recursosDocumentacao = [];
  List<Map<String, dynamic>> _recursosInstrumentos = [];
  
  // Detalhamento da Intervenção
  List<Map<String, dynamic>> _detalhamentoIntervencao = [];
  
  // Recursos Humanos
  List<Map<String, dynamic>> _recursosHumanos = [];
  
  // Dados de Planejamento (JSON)
  String? _dadosPlanejamento;
  
  // Distâncias de Segurança
  List<Map<String, dynamic>> _distanciasSeguranca = [];
  
  String _status = 'rascunho';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    
    final pex = widget.pex;
    
    // Inicializar controllers
    _numeroPexController = TextEditingController(text: pex?.numeroPex ?? '');
    _siController = TextEditingController(text: pex?.si ?? widget.task.si);
    _revisaoPexController = TextEditingController(text: pex?.revisaoPex?.toString() ?? '1');
    
    _responsavelNomeController = TextEditingController(text: pex?.responsavelNome ?? '');
    _responsavelIdSapController = TextEditingController(text: pex?.responsavelIdSap ?? '');
    _responsavelContatoController = TextEditingController(text: pex?.responsavelContato ?? '');
    _substitutoNomeController = TextEditingController(text: pex?.substitutoNome ?? '');
    _substitutoIdSapController = TextEditingController(text: pex?.substitutoIdSap ?? '');
    _substitutoContatoController = TextEditingController(text: pex?.substitutoContato ?? '');
    _fiscalTecnicoNomeController = TextEditingController(text: pex?.fiscalTecnicoNome ?? '');
    _fiscalTecnicoIdSapController = TextEditingController(text: pex?.fiscalTecnicoIdSap ?? '');
    _fiscalTecnicoContatoController = TextEditingController(text: pex?.fiscalTecnicoContato ?? '');
    _coordenadorNomeController = TextEditingController(text: pex?.coordenadorNome ?? widget.task.coordenador);
    _coordenadorIdSapController = TextEditingController(text: pex?.coordenadorIdSap ?? '');
    _coordenadorContatoController = TextEditingController(text: pex?.coordenadorContato ?? '');
    _tecnicoSegNomeController = TextEditingController(text: pex?.tecnicoSegNome ?? '');
    _tecnicoSegIdSapController = TextEditingController(text: pex?.tecnicoSegIdSap ?? '');
    _tecnicoSegContatoController = TextEditingController(text: pex?.tecnicoSegContato ?? '');
    
    _instalacaoController = TextEditingController(text: pex?.instalacao ?? '');
    _equipamentosController = TextEditingController(text: pex?.equipamentos ?? '');
    _resumoAtividadeController = TextEditingController(text: pex?.resumoAtividade ?? widget.task.tarefa);
    _configuracaoRecebimentoController = TextEditingController(text: pex?.configuracaoRecebimento ?? '');
    _configuracaoDuranteController = TextEditingController(text: pex?.configuracaoDurante ?? '');
    _configuracaoDevolucaoController = TextEditingController(text: pex?.configuracaoDevolucao ?? '');
    _aterramentoDescricaoController = TextEditingController(text: pex?.aterramentoDescricao ?? '');
    _aterramentoTotalUnidadesController = TextEditingController(text: pex?.aterramentoTotalUnidades?.toString() ?? '');
    _informacoesAdicionaisController = TextEditingController(text: pex?.informacoesAdicionais ?? '');
    _nivelRiscoController = TextEditingController(text: pex?.nivelRisco ?? 'Moderado (Médio)');
    _aprovadorController = TextEditingController(text: pex?.aprovador ?? '');
    
    _dataElaboracao = pex?.dataElaboracao ?? DateTime.now();
    _dataInicio = pex?.dataInicio ?? widget.task.dataInicio;
    _horaInicio = pex?.horaInicio ?? '08:00';
    _dataFim = pex?.dataFim ?? widget.task.dataFim;
    _horaFim = pex?.horaFim ?? '17:00';
    _periodicidade = pex?.periodicidade ?? false;
    _continuo = pex?.continuo ?? false;
    _dataAprovacao = pex?.dataAprovacao;
    _status = pex?.status ?? 'rascunho';
    
    // Carregar dados JSON
    _loadJsonData(pex);
    
    // Carregar dados assíncronos
    _loadData();
    
    // Inicializar distâncias de segurança padrão
    if (_distanciasSeguranca.isEmpty) {
      _distanciasSeguranca = [
        {'nivel': '2,1 a 15,0', 'd1': '0.65', 'd2': '1.65', 'D': '2.3'},
        {'nivel': '46,1 a 72,5', 'd1': '0.95', 'd2': '1.65', 'D': '2.6'},
        {'nivel': '230,0 a 242,0', 'd1': '1.55', 'd2': '1.65', 'D': '3.2'},
        {'nivel': '500,0 a 552,0', 'd1': '3.4', 'd2': '1.65', 'D': '5.05'},
      ];
    }
  }

  void _loadJsonData(PEX? pex) {
    if (pex == null) return;
    
    try {
      if (pex.recursosEpi != null && pex.recursosEpi!.isNotEmpty) {
        _recursosEpi = List<Map<String, dynamic>>.from(jsonDecode(pex.recursosEpi!));
      }
      if (pex.recursosEpc != null && pex.recursosEpc!.isNotEmpty) {
        _recursosEpc = List<Map<String, dynamic>>.from(jsonDecode(pex.recursosEpc!));
      }
      if (pex.recursosTransporte != null && pex.recursosTransporte!.isNotEmpty) {
        _recursosTransporte = List<Map<String, dynamic>>.from(jsonDecode(pex.recursosTransporte!));
      }
      if (pex.recursosMaterialConsumo != null && pex.recursosMaterialConsumo!.isNotEmpty) {
        _recursosMaterialConsumo = List<Map<String, dynamic>>.from(jsonDecode(pex.recursosMaterialConsumo!));
      }
      if (pex.recursosFerramentas != null && pex.recursosFerramentas!.isNotEmpty) {
        _recursosFerramentas = List<Map<String, dynamic>>.from(jsonDecode(pex.recursosFerramentas!));
      }
      if (pex.recursosComunicacao != null && pex.recursosComunicacao!.isNotEmpty) {
        _recursosComunicacao = List<Map<String, dynamic>>.from(jsonDecode(pex.recursosComunicacao!));
      }
      if (pex.recursosDocumentacao != null && pex.recursosDocumentacao!.isNotEmpty) {
        _recursosDocumentacao = List<Map<String, dynamic>>.from(jsonDecode(pex.recursosDocumentacao!));
      }
      if (pex.recursosInstrumentos != null && pex.recursosInstrumentos!.isNotEmpty) {
        _recursosInstrumentos = List<Map<String, dynamic>>.from(jsonDecode(pex.recursosInstrumentos!));
      }
      if (pex.detalhamentoIntervencao != null && pex.detalhamentoIntervencao!.isNotEmpty) {
        _detalhamentoIntervencao = List<Map<String, dynamic>>.from(jsonDecode(pex.detalhamentoIntervencao!));
      }
      if (pex.recursosHumanos != null && pex.recursosHumanos!.isNotEmpty) {
        _recursosHumanos = List<Map<String, dynamic>>.from(jsonDecode(pex.recursosHumanos!));
      }
      if (pex.distanciasSeguranca != null && pex.distanciasSeguranca!.isNotEmpty) {
        _distanciasSeguranca = List<Map<String, dynamic>>.from(jsonDecode(pex.distanciasSeguranca!));
      }
    } catch (e) {
      print('Erro ao carregar dados JSON: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _numeroPexController.dispose();
    _siController.dispose();
    _revisaoPexController.dispose();
    _responsavelNomeController.dispose();
    _responsavelIdSapController.dispose();
    _responsavelContatoController.dispose();
    _substitutoNomeController.dispose();
    _substitutoIdSapController.dispose();
    _substitutoContatoController.dispose();
    _fiscalTecnicoNomeController.dispose();
    _fiscalTecnicoIdSapController.dispose();
    _fiscalTecnicoContatoController.dispose();
    _coordenadorNomeController.dispose();
    _coordenadorIdSapController.dispose();
    _coordenadorContatoController.dispose();
    _tecnicoSegNomeController.dispose();
    _tecnicoSegIdSapController.dispose();
    _tecnicoSegContatoController.dispose();
    _instalacaoController.dispose();
    _equipamentosController.dispose();
    _resumoAtividadeController.dispose();
    _configuracaoRecebimentoController.dispose();
    _configuracaoDuranteController.dispose();
    _configuracaoDevolucaoController.dispose();
    _aterramentoDescricaoController.dispose();
    _aterramentoTotalUnidadesController.dispose();
    _informacoesAdicionaisController.dispose();
    _nivelRiscoController.dispose();
    _aprovadorController.dispose();
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

  Future<void> _selectTime(BuildContext context, Function(String) onTimeSelected) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      final formattedTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      onTimeSelected(formattedTime);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // Garantir que o campo de instalação está atualizado com os locais selecionados
      final locaisNomes = _locaisList
          .where((l) => _selectedInstalacaoIds.contains(l.id))
          .map((l) => l.local)
          .join(', ');
      _instalacaoController.text = locaisNomes;
      
      final pex = PEX(
        id: widget.pex?.id,
        taskId: widget.task.id,
        numeroPex: _numeroPexController.text.trim().isEmpty ? null : _numeroPexController.text.trim(),
        si: _siController.text.trim().isEmpty ? null : _siController.text.trim(),
        revisaoPex: int.tryParse(_revisaoPexController.text.trim()) ?? 1,
        dataElaboracao: _dataElaboracao,
        responsavelNome: _responsavelNomeController.text.trim().isEmpty ? null : _responsavelNomeController.text.trim(),
        responsavelIdSap: _responsavelIdSapController.text.trim().isEmpty ? null : _responsavelIdSapController.text.trim(),
        responsavelContato: _responsavelContatoController.text.trim().isEmpty ? null : _responsavelContatoController.text.trim(),
        substitutoNome: _substitutoNomeController.text.trim().isEmpty ? null : _substitutoNomeController.text.trim(),
        substitutoIdSap: _substitutoIdSapController.text.trim().isEmpty ? null : _substitutoIdSapController.text.trim(),
        substitutoContato: _substitutoContatoController.text.trim().isEmpty ? null : _substitutoContatoController.text.trim(),
        fiscalTecnicoNome: _fiscalTecnicoNomeController.text.trim().isEmpty ? null : _fiscalTecnicoNomeController.text.trim(),
        fiscalTecnicoIdSap: _fiscalTecnicoIdSapController.text.trim().isEmpty ? null : _fiscalTecnicoIdSapController.text.trim(),
        fiscalTecnicoContato: _fiscalTecnicoContatoController.text.trim().isEmpty ? null : _fiscalTecnicoContatoController.text.trim(),
        coordenadorNome: _coordenadorNomeController.text.trim().isEmpty ? null : _coordenadorNomeController.text.trim(),
        coordenadorIdSap: _coordenadorIdSapController.text.trim().isEmpty ? null : _coordenadorIdSapController.text.trim(),
        coordenadorContato: _coordenadorContatoController.text.trim().isEmpty ? null : _coordenadorContatoController.text.trim(),
        tecnicoSegNome: _tecnicoSegNomeController.text.trim().isEmpty ? null : _tecnicoSegNomeController.text.trim(),
        tecnicoSegIdSap: _tecnicoSegIdSapController.text.trim().isEmpty ? null : _tecnicoSegIdSapController.text.trim(),
        tecnicoSegContato: _tecnicoSegContatoController.text.trim().isEmpty ? null : _tecnicoSegContatoController.text.trim(),
        dataInicio: _dataInicio,
        horaInicio: _horaInicio,
        dataFim: _dataFim,
        horaFim: _horaFim,
        periodicidade: _periodicidade,
        continuo: _continuo,
        instalacao: _instalacaoController.text.trim().isEmpty ? null : _instalacaoController.text.trim(),
        equipamentos: _equipamentosController.text.trim().isEmpty ? null : _equipamentosController.text.trim(),
        resumoAtividade: _resumoAtividadeController.text.trim().isEmpty ? null : _resumoAtividadeController.text.trim(),
        configuracaoRecebimento: _configuracaoRecebimentoController.text.trim().isEmpty ? null : _configuracaoRecebimentoController.text.trim(),
        configuracaoDurante: _configuracaoDuranteController.text.trim().isEmpty ? null : _configuracaoDuranteController.text.trim(),
        configuracaoDevolucao: _configuracaoDevolucaoController.text.trim().isEmpty ? null : _configuracaoDevolucaoController.text.trim(),
        aterramentoDescricao: _aterramentoDescricaoController.text.trim().isEmpty ? null : _aterramentoDescricaoController.text.trim(),
        aterramentoTotalUnidades: int.tryParse(_aterramentoTotalUnidadesController.text.trim()),
        informacoesAdicionais: _informacoesAdicionaisController.text.trim().isEmpty ? null : _informacoesAdicionaisController.text.trim(),
        distanciasSeguranca: _distanciasSeguranca.isEmpty ? null : jsonEncode(_distanciasSeguranca),
        dadosPlanejamento: _dadosPlanejamento,
        recursosEpi: _recursosEpi.isEmpty ? null : jsonEncode(_recursosEpi),
        recursosEpc: _recursosEpc.isEmpty ? null : jsonEncode(_recursosEpc),
        recursosTransporte: _recursosTransporte.isEmpty ? null : jsonEncode(_recursosTransporte),
        recursosMaterialConsumo: _recursosMaterialConsumo.isEmpty ? null : jsonEncode(_recursosMaterialConsumo),
        recursosFerramentas: _recursosFerramentas.isEmpty ? null : jsonEncode(_recursosFerramentas),
        recursosComunicacao: _recursosComunicacao.isEmpty ? null : jsonEncode(_recursosComunicacao),
        recursosDocumentacao: _recursosDocumentacao.isEmpty ? null : jsonEncode(_recursosDocumentacao),
        recursosInstrumentos: _recursosInstrumentos.isEmpty ? null : jsonEncode(_recursosInstrumentos),
        detalhamentoIntervencao: _detalhamentoIntervencao.isEmpty ? null : jsonEncode(_detalhamentoIntervencao),
        recursosHumanos: _recursosHumanos.isEmpty ? null : jsonEncode(_recursosHumanos),
        nivelRisco: _nivelRiscoController.text.trim().isEmpty ? null : _nivelRiscoController.text.trim(),
        aprovador: _aprovadorController.text.trim().isEmpty ? null : _aprovadorController.text.trim(),
        dataAprovacao: _dataAprovacao,
        status: _status,
      );

      await _pexService.createOrUpdatePEX(pex);
      
      if (mounted) {
        Navigator.of(context).pop(pex);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PEX salvo com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar PEX: $e'),
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
        width: isMobile ? double.infinity : 1200,
        height: MediaQuery.of(context).size.height * 0.9,
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
                    const Icon(Icons.description, color: Colors.white),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'PEX - Planejamento Executivo',
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
              // Tabs
              Container(
                color: Colors.grey[200],
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: const Color(0xFF1E3A5F),
                  unselectedLabelColor: Colors.grey[600],
                  tabs: const [
                    Tab(text: 'Cabeçalho'),
                    Tab(text: 'Identificação'),
                    Tab(text: 'Planejamento'),
                    Tab(text: 'Recursos'),
                    Tab(text: 'Detalhamento'),
                    Tab(text: 'Recursos Humanos'),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCabecalhoTab(),
                    _buildIdentificacaoTab(),
                    _buildPlanejamentoTab(),
                    _buildRecursosTab(),
                    _buildDetalhamentoTab(),
                    _buildRecursosHumanosTab(),
                  ],
                ),
              ),
              // Actions
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DropdownButton<String>(
                      value: _status,
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
                    Row(
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCabecalhoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Cabeçalho'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _numeroPexController,
                  decoration: const InputDecoration(
                    labelText: 'Número PEX',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _siController,
                        decoration: const InputDecoration(
                          labelText: 'SI',
                          border: OutlineInputBorder(),
                        ),
                        readOnly: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.search),
                      tooltip: 'Selecionar SI',
                      onPressed: () => _selecionarSI(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue[50],
                        foregroundColor: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _revisaoPexController,
                  decoration: const InputDecoration(
                    labelText: 'Rev. PEX',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
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
        ],
      ),
    );
  }

  Widget _buildIdentificacaoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('1. IDENTIFICAÇÃO DA INTERVENÇÃO'),
          const SizedBox(height: 16),
          
          // Responsável
          _buildPessoaSection(
            'Responsável',
            _responsavelNomeController,
            _responsavelIdSapController,
            _responsavelContatoController,
          ),
          const SizedBox(height: 16),
          
          // Substituto
          _buildPessoaSection(
            'Substituto',
            _substitutoNomeController,
            _substitutoIdSapController,
            _substitutoContatoController,
          ),
          const SizedBox(height: 16),
          
          // Fiscal Técnico
          _buildPessoaSection(
            'Fiscal Técnico',
            _fiscalTecnicoNomeController,
            _fiscalTecnicoIdSapController,
            _fiscalTecnicoContatoController,
          ),
          const SizedBox(height: 16),
          
          // Coordenador
          _buildPessoaSection(
            'Coordenador',
            _coordenadorNomeController,
            _coordenadorIdSapController,
            _coordenadorContatoController,
          ),
          const SizedBox(height: 16),
          
          // Técnico Seg.
          _buildPessoaSection(
            'Técnico Seg.',
            _tecnicoSegNomeController,
            _tecnicoSegIdSapController,
            _tecnicoSegContatoController,
          ),
          const SizedBox(height: 24),
          
          // Período
          _buildSectionTitle('Período'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, (date) {
                    setState(() => _dataInicio = date);
                  }),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data Início',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      _dataInicio != null
                          ? DateFormat('dd/MM/yyyy').format(_dataInicio!)
                          : 'Selecione a data',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _selectTime(context, (time) {
                    setState(() => _horaInicio = time);
                  }),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Hora Início',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(_horaInicio),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('a'),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, (date) {
                    setState(() => _dataFim = date);
                  }),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data Fim',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      _dataFim != null
                          ? DateFormat('dd/MM/yyyy').format(_dataFim!)
                          : 'Selecione a data',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _selectTime(context, (time) {
                    setState(() => _horaFim = time);
                  }),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Hora Fim',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(_horaFim),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _periodicidade,
                onChanged: (value) => setState(() => _periodicidade = value ?? false),
              ),
              const Text('Periodicidade'),
              const SizedBox(width: 24),
              Checkbox(
                value: _continuo,
                onChanged: (value) => setState(() => _continuo = value ?? false),
              ),
              const Text('Contínuo'),
            ],
          ),
          const SizedBox(height: 24),
          
          // Instalação e Equipamentos
          _buildSectionTitle('Instalação e Equipamentos'),
          const SizedBox(height: 8),
          // Campo de Instalação (múltiplos locais)
          _buildInstalacaoDropdown(),
          const SizedBox(height: 16),
          // Campo de Equipamentos
          TextFormField(
            controller: _equipamentosController,
            decoration: const InputDecoration(
              labelText: 'Equipamentos',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          
          // Resumo da Atividade
          _buildSectionTitle('Resumo da Atividade'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _resumoAtividadeController,
            decoration: const InputDecoration(
              labelText: 'Resumo da Atividade',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          
          // Configuração
          _buildSectionTitle('Configuração'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _configuracaoRecebimentoController,
            decoration: const InputDecoration(
              labelText: 'Recebimento',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _configuracaoDuranteController,
            decoration: const InputDecoration(
              labelText: 'Durante',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _configuracaoDevolucaoController,
            decoration: const InputDecoration(
              labelText: 'Devolução',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          
          // Aterramento
          _buildSectionTitle('Aterramento'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _aterramentoDescricaoController,
            decoration: const InputDecoration(
              labelText: 'Descrição do Aterramento',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _aterramentoTotalUnidadesController,
            decoration: const InputDecoration(
              labelText: 'Total de Unidades',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          
          // Informações Adicionais
          _buildSectionTitle('Informações Adicionais'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _informacoesAdicionaisController,
            decoration: const InputDecoration(
              labelText: 'Informações adicionais / Outras atividades previstas',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          
          // Distâncias de Segurança
          _buildSectionTitle('Distâncias de Segurança'),
          const SizedBox(height: 8),
          _buildDistanciasSegurancaTable(),
          const SizedBox(height: 24),
          
          // Nível de Risco
          _buildSectionTitle('Nível de Risco'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nivelRiscoController,
            decoration: const InputDecoration(
              labelText: 'Nível de risco de acidente pessoal',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPessoaSection(String title, TextEditingController nomeController, TextEditingController idSapController, TextEditingController contatoController) {
    // Encontrar o executor selecionado baseado no nome
    Executor? executorSelecionado;
    if (nomeController.text.isNotEmpty && _executoresFiltrados.isNotEmpty) {
      try {
        executorSelecionado = _executoresFiltrados.firstWhere(
          (e) => e.nomeCompleto == nomeController.text || 
                 e.nome == nomeController.text ||
                 (e.nomeCompleto != null && nomeController.text.contains(e.nomeCompleto!)) ||
                 nomeController.text.contains(e.nome),
        );
      } catch (e) {
        executorSelecionado = null;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _isLoadingExecutores
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _buildSearchableDropdown<Executor>(
                      label: '$title - Nome',
                      value: executorSelecionado,
                      items: _executoresFiltrados,
                      getDisplayText: (executor) => executor.nomeCompleto ?? executor.nome,
                      onChanged: (Executor? value) {
                        setState(() {
                          if (value != null) {
                            nomeController.text = value.nomeCompleto ?? value.nome;
                            idSapController.text = value.matricula ?? value.login ?? '';
                            contatoController.text = value.telefone ?? value.ramal ?? '';
                          } else {
                            nomeController.text = '';
                            idSapController.text = '';
                            contatoController.text = '';
                          }
                        });
                      },
                      hintText: _executoresFiltrados.isEmpty 
                          ? 'Nenhum executor disponível' 
                          : 'Digite para buscar executor...',
                      compareFn: (Executor item1, Executor item2) {
                        return item1.id == item2.id;
                      },
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: idSapController,
                decoration: InputDecoration(
                  labelText: 'ID SAP (ou CPF)',
                  border: const OutlineInputBorder(),
                ),
                readOnly: true, // Somente leitura, preenchido automaticamente
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: contatoController,
                decoration: const InputDecoration(
                  labelText: 'Contato',
                  border: OutlineInputBorder(),
                ),
                readOnly: true, // Somente leitura, preenchido automaticamente
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Widget genérico de dropdown com busca (similar ao task_form_dialog)
  Widget _buildSearchableDropdown<T extends Object>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) getDisplayText,
    required void Function(T?) onChanged,
    String? Function(T?)? validator,
    String? hintText,
    bool isRequired = false,
    bool Function(T, T)? compareFn,
  }) {
    final itemsList = List<T>.from(items);
    
    return DropdownSearch<T>(
      popupProps: PopupProps.menu(
        showSearchBox: true,
        searchFieldProps: TextFieldProps(
          decoration: InputDecoration(
            hintText: hintText ?? 'Digite para buscar...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
        menuProps: const MenuProps(
          elevation: 4,
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
          minHeight: 200,
        ),
      ),
      items: (String filter, LoadProps? loadProps) async {
        return List<T>.from(itemsList);
      },
      selectedItem: value,
      onChanged: onChanged,
      itemAsString: getDisplayText,
      compareFn: compareFn ?? (T item1, T item2) {
        return getDisplayText(item1) == getDisplayText(item2);
      },
      filterFn: (T item, String filter) {
        if (filter.isEmpty || filter.trim().isEmpty) {
          return true;
        }
        final lowerFilter = filter.toLowerCase().trim();
        final displayText = getDisplayText(item).toLowerCase();
        return displayText.contains(lowerFilter);
      },
      validator: validator,
      decoratorProps: DropDownDecoratorProps(
        baseStyle: const TextStyle(),
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          labelStyle: TextStyle(
            color: Colors.grey[700],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          hintText: hintText ?? 'Digite para buscar...',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          suffixIcon: Icon(
            Icons.arrow_drop_down,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }

  // Carregar todos os dados assíncronos
  Future<void> _loadData() async {
    setState(() {
      _isLoadingExecutores = true;
    });
    
    try {
      // Carregar em paralelo
      await Future.wait([
        _loadSIs(),
        _loadExecutoresFiltrados(),
        _loadLocais(),
        _loadEquipesEPreencherCampos(),
      ]);
    } catch (e) {
      print('❌ Erro ao carregar dados: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingExecutores = false;
        });
      }
    }
  }

  // Carregar executores filtrados pelo perfil do usuário
  Future<void> _loadExecutoresFiltrados() async {
    try {
      final usuario = _authService.currentUser;
      
      if (usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
        // Buscar executores para cada segmento e combinar
        Set<Executor> executoresUnicos = {};
        
        if (usuario.segmentoIds.isNotEmpty) {
          // Buscar por segmento (mais específico)
          for (final segmentoId in usuario.segmentoIds) {
            final executoresSegmento = await _executorService.getExecutoresPorSegmento(segmentoId);
            executoresUnicos.addAll(executoresSegmento);
          }
        } else if (usuario.divisaoIds.isNotEmpty) {
          // Buscar por divisão
          for (final divisaoId in usuario.divisaoIds) {
            final executoresDivisao = await _executorService.getExecutoresPorDivisao(divisaoId);
            executoresUnicos.addAll(executoresDivisao);
          }
        } else {
          // Buscar todos os ativos
          executoresUnicos.addAll(await _executorService.getExecutoresAtivos());
        }
        
        // Filtrar apenas os ativos e converter para lista
        _executoresFiltrados = executoresUnicos.where((e) => e.ativo).toList();
      } else {
        // Usuário root ou sem perfil: buscar todos os executores ativos
        _executoresFiltrados = await _executorService.getExecutoresAtivos();
      }
      
      print('✅ Carregados ${_executoresFiltrados.length} executores filtrados para campos de pessoas');
      
      // Atualizar o estado após carregar
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('❌ Erro ao carregar executores filtrados: $e');
      // Fallback: buscar todos os ativos
      try {
        _executoresFiltrados = await _executorService.getExecutoresAtivos();
      } catch (e2) {
        print('❌ Erro ao buscar executores ativos: $e2');
        _executoresFiltrados = [];
      }
      if (mounted) {
        setState(() {});
      }
    }
  }

  Widget _buildDistanciasSegurancaTable() {
    return Table(
      border: TableBorder.all(color: Colors.grey),
      children: [
        const TableRow(
          decoration: BoxDecoration(color: Colors.grey),
          children: [
            TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('Níveis de tensão fase-fase (kV)', style: TextStyle(fontWeight: FontWeight.bold)))),
            TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('d1 (m)', style: TextStyle(fontWeight: FontWeight.bold)))),
            TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('d2+50% (m)', style: TextStyle(fontWeight: FontWeight.bold)))),
            TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('D (m)', style: TextStyle(fontWeight: FontWeight.bold)))),
          ],
        ),
        ..._distanciasSeguranca.map((dist) => TableRow(
          children: [
            TableCell(child: Padding(padding: const EdgeInsets.all(8), child: Text(dist['nivel'] ?? ''))),
            TableCell(child: Padding(padding: const EdgeInsets.all(8), child: Text(dist['d1'] ?? ''))),
            TableCell(child: Padding(padding: const EdgeInsets.all(8), child: Text(dist['d2'] ?? ''))),
            TableCell(child: Padding(padding: const EdgeInsets.all(8), child: Text(dist['D'] ?? ''))),
          ],
        )),
      ],
    );
  }

  Widget _buildPlanejamentoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('2. DADOS PARA PLANEJAMENTO DA INTERVENÇÃO'),
          const SizedBox(height: 16),
          const Text(
            'Esta seção será preenchida com categorias e instruções detalhadas.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          // Aqui pode ser adicionado um editor mais complexo para categorias e instruções
          // Por enquanto, deixamos como texto simples ou JSON
        ],
      ),
    );
  }

  Widget _buildRecursosTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('3. RECURSOS / FERRAMENTAS / MATERIAIS'),
          const SizedBox(height: 16),
          _buildRecursosSection('EPI', _recursosEpi, (list) => _recursosEpi = list),
          const SizedBox(height: 24),
          _buildRecursosSection('EPC', _recursosEpc, (list) => _recursosEpc = list),
          const SizedBox(height: 24),
          _buildRecursosSection('Transporte/Máquinas', _recursosTransporte, (list) => _recursosTransporte = list),
          const SizedBox(height: 24),
          _buildRecursosSection('Material de Consumo', _recursosMaterialConsumo, (list) => _recursosMaterialConsumo = list),
          const SizedBox(height: 24),
          _buildRecursosSection('Ferramentas', _recursosFerramentas, (list) => _recursosFerramentas = list),
          const SizedBox(height: 24),
          _buildRecursosSection('Comunicação', _recursosComunicacao, (list) => _recursosComunicacao = list),
          const SizedBox(height: 24),
          _buildRecursosSection('Documentação', _recursosDocumentacao, (list) => _recursosDocumentacao = list),
          const SizedBox(height: 24),
          _buildRecursosSection('Instrumentos', _recursosInstrumentos, (list) => _recursosInstrumentos = list),
        ],
      ),
    );
  }

  Widget _buildRecursosSection(String title, List<Map<String, dynamic>> recursos, Function(List<Map<String, dynamic>>) onUpdate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                setState(() {
                  recursos.add({'qtde': '', 'recurso': ''});
                  onUpdate(recursos);
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Table(
          border: TableBorder.all(color: Colors.grey),
          children: [
            const TableRow(
              decoration: BoxDecoration(color: Colors.grey),
              children: [
                TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('Qtde', style: TextStyle(fontWeight: FontWeight.bold)))),
                TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('Recurso', style: TextStyle(fontWeight: FontWeight.bold)))),
                TableCell(child: SizedBox()),
              ],
            ),
            ...recursos.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return TableRow(
                children: [
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: TextFormField(
                        initialValue: item['qtde']?.toString() ?? '',
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          recursos[index]['qtde'] = value;
                          onUpdate(recursos);
                        },
                      ),
                    ),
                  ),
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: TextFormField(
                        initialValue: item['recurso']?.toString() ?? '',
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          recursos[index]['recurso'] = value;
                          onUpdate(recursos);
                        },
                      ),
                    ),
                  ),
                  TableCell(
                    child: IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: () {
                        setState(() {
                          recursos.removeAt(index);
                          onUpdate(recursos);
                        });
                      },
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildDetalhamentoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('4. DETALHAMENTO DA INTERVENÇÃO'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  setState(() {
                    _detalhamentoIntervencao.add({
                      'item': (_detalhamentoIntervencao.length + 1).toString(),
                      'atividade': '',
                      'detalhamento': '',
                      'responsavel': '',
                    });
                  });
                },
              ),
            ],
          ),
          Table(
            border: TableBorder.all(color: Colors.grey),
            children: [
              const TableRow(
                decoration: BoxDecoration(color: Colors.grey),
                children: [
                  TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold)))),
                  TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('Atividade', style: TextStyle(fontWeight: FontWeight.bold)))),
                  TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('Detalhamento', style: TextStyle(fontWeight: FontWeight.bold)))),
                  TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('Responsável', style: TextStyle(fontWeight: FontWeight.bold)))),
                  TableCell(child: SizedBox()),
                ],
              ),
              ..._detalhamentoIntervencao.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return TableRow(
                  children: [
                    TableCell(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: TextFormField(
                          initialValue: item['item']?.toString() ?? '',
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (value) {
                            _detalhamentoIntervencao[index]['item'] = value;
                          },
                        ),
                      ),
                    ),
                    TableCell(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: TextFormField(
                          initialValue: item['atividade']?.toString() ?? '',
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (value) {
                            _detalhamentoIntervencao[index]['atividade'] = value;
                          },
                        ),
                      ),
                    ),
                    TableCell(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: TextFormField(
                          initialValue: item['detalhamento']?.toString() ?? '',
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          maxLines: 2,
                          onChanged: (value) {
                            _detalhamentoIntervencao[index]['detalhamento'] = value;
                          },
                        ),
                      ),
                    ),
                    TableCell(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: TextFormField(
                          initialValue: item['responsavel']?.toString() ?? '',
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (value) {
                            _detalhamentoIntervencao[index]['responsavel'] = value;
                          },
                        ),
                      ),
                    ),
                    TableCell(
                      child: IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        onPressed: () {
                          setState(() {
                            _detalhamentoIntervencao.removeAt(index);
                          });
                        },
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecursosHumanosTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('5. RECURSOS HUMANOS E CIÊNCIA DOS RISCOS'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  setState(() {
                    _recursosHumanos.add({
                      'nome': '',
                      'empresa_equipe': '',
                      'documento_matricula': '',
                      'estado_fisico_emocional': false,
                      'ciencia_atividades_riscos': false,
                    });
                  });
                },
              ),
            ],
          ),
          Table(
            border: TableBorder.all(color: Colors.grey),
            children: [
              const TableRow(
                decoration: BoxDecoration(color: Colors.grey),
                children: [
                  TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('Nome', style: TextStyle(fontWeight: FontWeight.bold)))),
                  TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('Empresa/Equipe', style: TextStyle(fontWeight: FontWeight.bold)))),
                  TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('Documento/Matrícula', style: TextStyle(fontWeight: FontWeight.bold)))),
                  TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('Estado Físico/Emocional', style: TextStyle(fontWeight: FontWeight.bold)))),
                  TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('Ciência das Atividades e Riscos', style: TextStyle(fontWeight: FontWeight.bold)))),
                  TableCell(child: SizedBox()),
                ],
              ),
              ..._recursosHumanos.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return TableRow(
                  children: [
                    TableCell(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: TextFormField(
                          initialValue: item['nome']?.toString() ?? '',
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (value) {
                            _recursosHumanos[index]['nome'] = value;
                          },
                        ),
                      ),
                    ),
                    TableCell(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: TextFormField(
                          initialValue: item['empresa_equipe']?.toString() ?? '',
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (value) {
                            _recursosHumanos[index]['empresa_equipe'] = value;
                          },
                        ),
                      ),
                    ),
                    TableCell(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: TextFormField(
                          initialValue: item['documento_matricula']?.toString() ?? '',
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (value) {
                            _recursosHumanos[index]['documento_matricula'] = value;
                          },
                        ),
                      ),
                    ),
                    TableCell(
                      child: Checkbox(
                        value: item['estado_fisico_emocional'] == true,
                        onChanged: (value) {
                          setState(() {
                            _recursosHumanos[index]['estado_fisico_emocional'] = value ?? false;
                          });
                        },
                      ),
                    ),
                    TableCell(
                      child: Checkbox(
                        value: item['ciencia_atividades_riscos'] == true,
                        onChanged: (value) {
                          setState(() {
                            _recursosHumanos[index]['ciencia_atividades_riscos'] = value ?? false;
                          });
                        },
                      ),
                    ),
                    TableCell(
                      child: IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        onPressed: () {
                          setState(() {
                            _recursosHumanos.removeAt(index);
                          });
                        },
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Aprovação'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _aprovadorController,
                  decoration: const InputDecoration(
                    labelText: 'Aprovador',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, (date) {
                    setState(() => _dataAprovacao = date);
                  }),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data de Aprovação',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      _dataAprovacao != null
                          ? DateFormat('dd/MM/yyyy').format(_dataAprovacao!)
                          : 'Selecione a data',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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

  // Carregar SIs vinculadas à tarefa
  Future<void> _loadSIs() async {
    try {
      final sis = await _siService.getSIsPorTarefa(widget.task.id);
      print('📋 Carregadas ${sis.length} SIs vinculadas à tarefa');
      
      setState(() {
        _sisVinculadas = sis;
        
        // Preencher o campo SI automaticamente se houver SIs vinculadas
        if (sis.isNotEmpty && (_siController.text.isEmpty || _siController.text == '-N/A-' || _siController.text == widget.task.si)) {
          // Se houver apenas um SI, usar ele; se houver vários, concatenar
          if (sis.length == 1) {
            _siController.text = sis.first.solicitacao;
          } else {
            _siController.text = sis.map((si) => si.solicitacao).join(', ');
          }
        }
      });
    } catch (e) {
      print('❌ Erro ao carregar SIs: $e');
    }
  }

  // Selecionar/atribuir SIs
  Future<void> _selecionarSI() async {
    try {
      // Carregar todas as SIs disponíveis
      final todasSIs = await _siService.getAllSIs(limit: 1000);
      
      // Filtrar SIs já vinculadas (opcional - pode permitir selecionar mesmo as já vinculadas)
      final sisDisponiveis = todasSIs;
      
      if (sisDisponiveis.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não há SIs disponíveis'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // Usar o diálogo de seleção de SIs
      if (!mounted) return;
      final sisSelecionadas = await showDialog<List<SI>>(
        context: context,
        builder: (context) => SISelectionDialog(
          sis: sisDisponiveis,
          title: 'Selecionar SI',
          taskTarefa: widget.task.tarefa,
        ),
      );
      
      if (!mounted) return;
      if (sisSelecionadas != null && sisSelecionadas.isNotEmpty) {
        // Atualizar o campo SI com a(s) SI(s) selecionada(s)
        if (sisSelecionadas.length == 1) {
          _siController.text = sisSelecionadas.first.solicitacao;
        } else {
          _siController.text = sisSelecionadas.map((si) => si.solicitacao).join(', ');
        }
        
        // Vincular SIs à tarefa se ainda não estiverem vinculadas
        for (final si in sisSelecionadas) {
          if (!_sisVinculadas.any((v) => v.id == si.id)) {
            try {
              await _siService.vincularSITarefa(widget.task.id, si.id);
            } catch (e) {
              print('⚠️ Erro ao vincular SI ${si.solicitacao}: $e');
            }
          }
        }
        
        // Recarregar SIs vinculadas
        await _loadSIs();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${sisSelecionadas.length} SI(s) selecionada(s)'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Erro ao selecionar SI: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao selecionar SI: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Carregar equipes e preencher campos automaticamente
  Future<void> _loadEquipesEPreencherCampos() async {
    try {
      // Se os campos já estão preenchidos (edição), não preencher automaticamente
      if (widget.pex != null && 
          (widget.pex!.responsavelNome != null && widget.pex!.responsavelNome!.isNotEmpty ||
           widget.pex!.fiscalTecnicoNome != null && widget.pex!.fiscalTecnicoNome!.isNotEmpty)) {
        return;
      }

      // Buscar equipes relacionadas à tarefa
      List<String> equipeIds = [];
      if (widget.task.equipeIds.isNotEmpty) {
        equipeIds = widget.task.equipeIds;
      } else if (widget.task.equipeId != null && widget.task.equipeId!.isNotEmpty) {
        equipeIds = [widget.task.equipeId!];
      }

      if (equipeIds.isEmpty) {
        // Se não houver equipe específica, buscar equipes baseadas no perfil do usuário
        final usuario = _authService.currentUser;
        if (usuario != null && !usuario.isRoot) {
          // Buscar equipes filtradas pelo perfil do usuário
          final todasEquipes = await _equipeService.getAllEquipes();
          _equipesTarefa = todasEquipes.where((equipe) {
            // Filtrar por regional, divisão ou segmento do usuário
            if (usuario.regionalIds.isNotEmpty && equipe.regionalId != null) {
              if (!usuario.regionalIds.contains(equipe.regionalId)) return false;
            }
            if (usuario.divisaoIds.isNotEmpty && equipe.divisaoId != null) {
              if (!usuario.divisaoIds.contains(equipe.divisaoId)) return false;
            }
            if (usuario.segmentoIds.isNotEmpty && equipe.segmentoId != null) {
              if (!usuario.segmentoIds.contains(equipe.segmentoId)) return false;
            }
            return equipe.ativo;
          }).toList();
        } else {
          // Usuário root: buscar todas as equipes ativas
          _equipesTarefa = await _equipeService.getEquipesAtivas();
        }
      } else {
        // Buscar equipes específicas da tarefa
        _equipesTarefa = [];
        for (final equipeId in equipeIds) {
          final equipe = await _equipeService.getEquipeById(equipeId);
          if (equipe != null && equipe.ativo) {
            _equipesTarefa.add(equipe);
          }
        }
      }

      if (_equipesTarefa.isEmpty) {
        print('⚠️ Nenhuma equipe encontrada para preencher campos do PEX');
        return;
      }

      // Coletar todos os executores das equipes com seus papéis
      Map<String, Executor> executoresMap = {}; // Map<executorId, Executor>
      List<EquipeExecutor> encarregados = <EquipeExecutor>[];
      List<EquipeExecutor> fiscais = <EquipeExecutor>[];
      List<EquipeExecutor> outrosExecutores = <EquipeExecutor>[];

      for (final equipe in _equipesTarefa) {
        for (final equipeExecutor in equipe.executores) {
          // Buscar dados completos do executor
          final todosExecutores = await _executorService.getAllExecutores();
          final executor = todosExecutores.firstWhere(
            (e) => e.id == equipeExecutor.executorId,
            orElse: () => Executor(
              id: equipeExecutor.executorId,
              nome: equipeExecutor.executorNome,
            ),
          );

          executoresMap[executor.id] = executor;

          // Classificar por papel
          if (equipeExecutor.papel == 'ENCARREGADO') {
            encarregados.add(equipeExecutor);
          } else if (equipeExecutor.papel == 'FISCAL') {
            fiscais.add(equipeExecutor);
          } else {
            outrosExecutores.add(equipeExecutor);
          }
        }
      }

      // Preencher Responsável (ENCARREGADO ou primeiro executor)
      if (encarregados.isNotEmpty && _responsavelNomeController.text.isEmpty) {
        final encarregado = encarregados.first;
        final executor = executoresMap[encarregado.executorId];
        if (executor != null) {
          _responsavelNomeController.text = executor.nomeCompleto ?? executor.nome;
          _responsavelIdSapController.text = executor.matricula ?? executor.login ?? '';
          _responsavelContatoController.text = executor.telefone ?? executor.ramal ?? '';
        }
      } else if (outrosExecutores.isNotEmpty && _responsavelNomeController.text.isEmpty) {
        final primeiro = outrosExecutores.first;
        final executor = executoresMap[primeiro.executorId];
        if (executor != null) {
          _responsavelNomeController.text = executor.nomeCompleto ?? executor.nome;
          _responsavelIdSapController.text = executor.matricula ?? executor.login ?? '';
          _responsavelContatoController.text = executor.telefone ?? executor.ramal ?? '';
        }
      }

      // Preencher Fiscal Técnico (executor com papel FISCAL)
      if (fiscais.isNotEmpty && _fiscalTecnicoNomeController.text.isEmpty) {
        final fiscal = fiscais.first;
        final executor = executoresMap[fiscal.executorId];
        if (executor != null) {
          _fiscalTecnicoNomeController.text = executor.nomeCompleto ?? executor.nome;
          _fiscalTecnicoIdSapController.text = executor.matricula ?? executor.login ?? '';
          _fiscalTecnicoContatoController.text = executor.telefone ?? executor.ramal ?? '';
        }
      }

      // Preencher Substituto (segundo executor disponível, se houver)
      if (_substitutoNomeController.text.isEmpty) {
        // Priorizar executores que não sejam o responsável
        List<EquipeExecutor> candidatos = [];
        candidatos.addAll(outrosExecutores);
        if (encarregados.length > 1) {
          candidatos.addAll(encarregados.skip(1));
        }

        // Remover o responsável se já foi preenchido
        if (_responsavelNomeController.text.isNotEmpty) {
          candidatos.removeWhere((e) {
            final executor = executoresMap[e.executorId];
            if (executor == null) return false;
            return executor.nome == _responsavelNomeController.text ||
                   executor.nomeCompleto == _responsavelNomeController.text;
          });
        }

        if (candidatos.isNotEmpty) {
          final substituto = candidatos.first;
          final executor = executoresMap[substituto.executorId];
          if (executor != null) {
            _substitutoNomeController.text = executor.nomeCompleto ?? executor.nome;
            _substitutoIdSapController.text = executor.matricula ?? executor.login ?? '';
            _substitutoContatoController.text = executor.telefone ?? executor.ramal ?? '';
          }
        }
      }

      print('✅ Campos do PEX preenchidos automaticamente com base nas equipes');
    } catch (e) {
      print('❌ Erro ao carregar equipes e preencher campos: $e');
    }
  }

  // Carregar locais para instalação
  Future<void> _loadLocais() async {
    try {
      final usuario = _authService.currentUser;
      
      if (usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
        // Filtrar locais baseado no perfil do usuário
        List<Local> todosLocais = await _localService.getAllLocais();
        
        _locaisList = todosLocais.where((local) {
          // Filtrar por divisão
          if (usuario.divisaoIds.isNotEmpty) {
            if (local.divisaoId != null && !usuario.divisaoIds.contains(local.divisaoId)) {
              return false;
            }
          }
          
          // Filtrar por segmento
          if (usuario.segmentoIds.isNotEmpty && local.segmentoId != null) {
            if (!usuario.segmentoIds.contains(local.segmentoId)) {
              return false;
            }
          }
          
          return true; // Incluir todos os locais que passaram pelos filtros
        }).toList();
      } else {
        // Usuário root ou sem perfil: buscar todos os locais ativos
        _locaisList = await _localService.getAllLocais();
      }
      
      // Inicializar lista de instalações selecionadas
      if (_instalacoesSelecionadas.isEmpty) {
        _instalacoesSelecionadas = <Local?>[null];
      }
      
      // Se há instalação já preenchida, tentar encontrar os locais
      if (widget.pex?.instalacao != null && widget.pex!.instalacao!.isNotEmpty) {
        final instalacaoText = widget.pex!.instalacao!;
        // Dividir por vírgula e tentar encontrar cada local
        final partes = instalacaoText.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
        final locaisEncontrados = <Local>[];
        
        for (final parte in partes) {
          try {
            final local = _locaisList.firstWhere(
              (l) => l.local.trim() == parte || 
                     (l.descricao != null && l.descricao!.trim() == parte) ||
                     parte.contains(l.local.trim()) ||
                     (l.descricao != null && parte.contains(l.descricao!.trim())),
            );
            if (!locaisEncontrados.any((l) => l.id == local.id)) {
              locaisEncontrados.add(local);
            }
          } catch (e) {
            // Local não encontrado, continuar
          }
        }
        
        if (locaisEncontrados.isNotEmpty) {
          _instalacoesSelecionadas = locaisEncontrados.map<Local?>((l) => l).toList();
          _selectedInstalacaoIds = locaisEncontrados.map((l) => l.id).toSet();
          // Garantir que há pelo menos um dropdown
          if (_instalacoesSelecionadas.isEmpty) {
            _instalacoesSelecionadas = <Local?>[null];
          }
        }
      }
      
      print('✅ Carregados ${_locaisList.length} locais para instalação');
    } catch (e) {
      print('❌ Erro ao carregar locais: $e');
      _locaisList = [];
    }
  }

  // Widget para dropdown de instalação (múltiplos locais)
  Widget _buildInstalacaoDropdown() {
    if (_instalacoesSelecionadas.isEmpty) {
      _instalacoesSelecionadas = <Local?>[null];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Instalação *',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            // Botão para adicionar mais dropdowns
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _instalacoesSelecionadas.add(null);
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.add_circle, size: 24, color: Colors.blue),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Lista de dropdowns lado a lado
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_instalacoesSelecionadas.length, (index) {
            return _buildSingleInstalacaoDropdown(index);
          }),
        ),
      ],
    );
  }

  Widget _buildSingleInstalacaoDropdown(int index) {
    if (index >= _instalacoesSelecionadas.length) {
      return const SizedBox.shrink();
    }
    
    final localSelecionado = _instalacoesSelecionadas[index];
    final localSelecionadoId = localSelecionado?.id;
    
    // Criar lista de IDs já selecionados em OUTROS dropdowns (não este)
    final outrosLocalIds = <String>{};
    for (int i = 0; i < _instalacoesSelecionadas.length; i++) {
      if (i != index && _instalacoesSelecionadas[i] != null) {
        outrosLocalIds.add(_instalacoesSelecionadas[i]!.id);
      }
    }
    
    final locaisDisponiveis = _locaisList.where((local) {
      // Sempre incluir o local selecionado neste dropdown específico
      if (localSelecionadoId != null && local.id == localSelecionadoId) {
        return true;
      }
      // Excluir apenas locais selecionados em OUTROS dropdowns
      return !outrosLocalIds.contains(local.id);
    }).toList();
    
    // Verificar se o valor selecionado está na lista de disponíveis
    Local? valorValido;
    if (localSelecionado != null && localSelecionadoId != null) {
      try {
        valorValido = locaisDisponiveis.firstWhere((l) => l.id == localSelecionadoId);
      } catch (e) {
        valorValido = null;
      }
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: Responsive.isMobile(context) ? double.infinity : 450,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildSearchableDropdown<Local>(
                label: 'Instalação ${index + 1}',
                value: valorValido,
                items: locaisDisponiveis,
                getDisplayText: (local) => local.descricao != null && local.descricao!.isNotEmpty
                    ? '${local.local} - ${local.descricao}'
                    : local.local,
                onChanged: (Local? value) {
                  setState(() {
                    final localAnterior = _instalacoesSelecionadas[index];
                    if (localAnterior != null) {
                      _selectedInstalacaoIds.remove(localAnterior.id);
                    }
                    
                    if (value != null) {
                      _instalacoesSelecionadas[index] = value;
                      _selectedInstalacaoIds.add(value.id);
                    } else {
                      _instalacoesSelecionadas[index] = null;
                    }
                    
                    // Atualizar o controller de instalação com os nomes dos locais selecionados
                    final locaisNomes = _locaisList
                        .where((l) => _selectedInstalacaoIds.contains(l.id))
                        .map((l) => l.local)
                        .join(', ');
                    _instalacaoController.text = locaisNomes;
                  });
                },
                hintText: 'Digite para buscar local...',
                compareFn: (Local item1, Local item2) {
                  return item1.id == item2.id;
                },
              ),
            ),
            // Botão para remover este dropdown (apenas se houver mais de um)
            if (_instalacoesSelecionadas.length > 1)
              IconButton(
                icon: const Icon(Icons.remove_circle, color: Colors.red),
                onPressed: () {
                  setState(() {
                    final localParaRemover = _instalacoesSelecionadas[index];
                    if (localParaRemover != null) {
                      _selectedInstalacaoIds.remove(localParaRemover.id);
                    }
                    _instalacoesSelecionadas.removeAt(index);
                    
                    if (_instalacoesSelecionadas.isEmpty) {
                      _instalacoesSelecionadas = <Local?>[null];
                    }
                    
                    // Atualizar o controller de instalação
                    final locaisNomes = _locaisList
                        .where((l) => _selectedInstalacaoIds.contains(l.id))
                        .map((l) => l.local)
                        .join(', ');
                    _instalacaoController.text = locaisNomes;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }
}
