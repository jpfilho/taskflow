import 'package:flutter/material.dart';
import '../models/nota_sap.dart';
import '../models/ordem.dart';
import '../models/task.dart';
import '../services/cluster_service.dart';
import '../services/task_service.dart';
import '../services/nota_sap_service.dart';
import '../services/ordem_service.dart';
import '../services/auth_service_simples.dart';
import '../services/executor_service.dart';
import '../utils/responsive.dart';
import 'task_form_dialog.dart';
import 'multi_select_filter_dialog.dart';
import 'cluster_visualizador_grafico.dart';


class ClusterAtivosView extends StatefulWidget {
  const ClusterAtivosView({super.key});

  @override
  State<ClusterAtivosView> createState() => _ClusterAtivosViewState();
}

class _ClusterAtivosViewState extends State<ClusterAtivosView> {
  final ClusterService _clusterService = ClusterService();
  final TaskService _taskService = TaskService();
  final NotaSAPService _notaSapService = NotaSAPService();
  final OrdemService _ordemService = OrdemService();
  final AuthServiceSimples _authService = AuthServiceSimples();
  final ExecutorService _executorService = ExecutorService();

  List<AtivoCluster> _clusters = [];
  List<AtivoCluster> _filteredClusters = [];
  bool _isLoading = true;
  bool _apenasNaoProgramados = true;
  String _searchQuery = '';
  String _ordenacao = 'prazo'; // 'prazo' ou 'volume'
  bool _canEditTasks = false;
  bool _isCheckingPermission = true;
  bool _isGraphView = false;


  final Set<String> _selectedFiltroLocal = {};
  final Set<String> _selectedFiltroSala = {};
  List<String> _locaisDisponiveis = [];
  List<String> _salasDisponiveis = [];

  // Mapa para guardar seleção de Notas SAP por chave do cluster (id da nota)
  final Map<String, Set<String>> _selectedNotasIds = {};
  // Mapa para guardar seleção de Ordens por chave do cluster (id da ordem)
  final Map<String, Set<String>> _selectedOrdensIds = {};

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadClusters();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        _canEditTasks = false;
      } else if (user.isRoot) {
        _canEditTasks = true;
      } else {
        _canEditTasks = await _executorService.isCoordenadorOuGerentePorLogin(user.email);
      }
    } catch (e) {
      debugPrint('Erro ao checar permissões na tela de clusters: $e');
      _canEditTasks = false;
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingPermission = false;
        });
      }
    }
  }

  Future<void> _loadClusters() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final clusters = await _clusterService.getClustersAtivos(
        apenasNaoProgramados: _apenasNaoProgramados,
      );

      setState(() {
        _clusters = clusters;
        
        // Obter locais e salas únicos ordenados
        _locaisDisponiveis = clusters
            .map((c) => c.local)
            .where((l) => l.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

        _salasDisponiveis = clusters
            .map((c) => c.sala)
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

        _applyFiltersAndSort();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar clusters: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar clusters: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFiltersAndSort() {
    List<AtivoCluster> filtrados = _clusters;

    // 1. Filtro de pesquisa
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtrados = filtrados.where((cluster) {
        final matchLocal = cluster.local.toLowerCase().contains(query);
        final matchSala = cluster.sala.toLowerCase().contains(query);
        final matchNotas = cluster.notas.any((n) => 
          n.nota.toLowerCase().contains(query) || (n.descricao?.toLowerCase().contains(query) ?? false)
        );
        final matchOrdens = cluster.ordens.any((o) => 
          o.ordem.toLowerCase().contains(query) || (o.textoBreve?.toLowerCase().contains(query) ?? false)
        );
        return matchLocal || matchSala || matchNotas || matchOrdens;
      }).toList();
    }

    // 1.1. Filtro de Local selecionado
    if (_selectedFiltroLocal.isNotEmpty) {
      filtrados = filtrados.where((c) => _selectedFiltroLocal.contains(c.local)).toList();
    }

    // 1.2. Filtro de Sala selecionada
    if (_selectedFiltroSala.isNotEmpty) {
      filtrados = filtrados.where((c) => _selectedFiltroSala.contains(c.sala)).toList();
    }

    // 2. Ordenação
    if (_ordenacao == 'prazo') {
      filtrados.sort((a, b) {
        if (a.prazoCritico == null && b.prazoCritico == null) return 0;
        if (a.prazoCritico == null) return 1;
        if (b.prazoCritico == null) return -1;
        return a.prazoCritico!.compareTo(b.prazoCritico!);
      });
    } else if (_ordenacao == 'volume') {
      filtrados.sort((a, b) => b.totalDemandas.compareTo(a.totalDemandas));
    }

    // 3. Inicializar estruturas de seleção (marcar por padrão apenas as não programadas)
    for (final cluster in filtrados) {
      if (!_selectedNotasIds.containsKey(cluster.localKey)) {
        _selectedNotasIds[cluster.localKey] = cluster.notas
            .where((n) => !cluster.tarefasNotas.containsKey(n.id))
            .map((n) => n.id)
            .toSet();
      }
      if (!_selectedOrdensIds.containsKey(cluster.localKey)) {
        _selectedOrdensIds[cluster.localKey] = cluster.ordens
            .where((o) => !cluster.tarefasOrdens.containsKey(o.id))
            .map((o) => o.id)
            .toSet();
      }
    }

    _filteredClusters = filtrados;
  }

  void _toggleSelectAll(AtivoCluster cluster, bool select) {
    setState(() {
      if (select) {
        _selectedNotasIds[cluster.localKey] = cluster.notas.map((n) => n.id).toSet();
        _selectedOrdensIds[cluster.localKey] = cluster.ordens.map((o) => o.id).toSet();
      } else {
        _selectedNotasIds[cluster.localKey] = {};
        _selectedOrdensIds[cluster.localKey] = {};
      }
    });
  }

  Future<void> _programarCluster(AtivoCluster cluster) async {
    if (!_canEditTasks) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permissão negada. Apenas coordenadores ou gerentes podem programar tarefas.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final selecionadasNotas = cluster.notas
        .where((n) => _selectedNotasIds[cluster.localKey]?.contains(n.id) ?? false)
        .toList();

    final selecionadasOrdens = cluster.ordens
        .where((o) => _selectedOrdensIds[cluster.localKey]?.contains(o.id) ?? false)
        .toList();

    if (selecionadasNotas.isEmpty && selecionadasOrdens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione pelo menos uma demanda para programar.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Encontrar demanda principal para pré-preenchimento
    NotaSAP? notaPrincipal;
    Ordem? ordemPrincipal;
    DateTime dataInicio = DateTime.now();
    DateTime dataFim = DateTime.now().add(const Duration(days: 1));

    if (selecionadasNotas.isNotEmpty) {
      notaPrincipal = selecionadasNotas.first;
      dataInicio = notaPrincipal.inicioDesejado ?? dataInicio;
      dataFim = notaPrincipal.conclusaoDesejada ?? dataInicio.add(const Duration(days: 1));
    } else if (selecionadasOrdens.isNotEmpty) {
      ordemPrincipal = selecionadasOrdens.first;
      dataInicio = ordemPrincipal.inicioBase ?? dataInicio;
      dataFim = ordemPrincipal.fimBase ?? dataInicio.add(const Duration(days: 1));
    }

    // Abrir o diálogo de tarefas
    final taskCriada = await showDialog<Task>(
      context: context,
      builder: (context) => TaskFormDialog(
        startDate: dataInicio,
        endDate: dataFim,
        notaSAP: notaPrincipal,
        ordem: ordemPrincipal,
      ),
    );

    if (taskCriada == null || !mounted) return;

    // Mostrar diálogo de progresso
    int totalItens = 1 + selecionadasNotas.length + selecionadasOrdens.length;
    int itensProcessados = 0;
    String statusMsg = 'Criando tarefa...';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            Future.microtask(() async {
              try {
                if (itensProcessados == 0) {
                  // 1. Criar a tarefa no banco de dados
                  final createdTask = await _taskService.createTask(taskCriada);
                  itensProcessados++;
                  setDialogState(() {
                    statusMsg = 'Vinculando demandas... ($itensProcessados/$totalItens)';
                  });

                  // 2. Vincular todas as Notas SAP selecionadas
                  for (final nota in selecionadasNotas) {
                    await _notaSapService.vincularNotaATarefa(createdTask.id, nota.id);
                    itensProcessados++;
                    setDialogState(() {
                      statusMsg = 'Vinculando Notas SAP... ($itensProcessados/$totalItens)';
                    });
                  }

                  // 3. Vincular todas as Ordens selecionadas
                  for (final ordem in selecionadasOrdens) {
                    await _ordemService.vincularOrdemATarefa(createdTask.id, ordem.id);
                    itensProcessados++;
                    setDialogState(() {
                      statusMsg = 'Vinculando Ordens... ($itensProcessados/$totalItens)';
                    });
                  }

                  // Fechar diálogo de progresso
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                  }
                  
                  // Recarregar clusters
                  _loadClusters();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tarefa programada e vinculações efetuadas com sucesso!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erro ao salvar programação: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            });

            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    'Programando Ativo',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    statusMsg,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: itensProcessados / totalItens,
                    backgroundColor: Colors.grey[200],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getPrazoColor(int? dias) {
    if (dias == null) return Colors.grey;
    if (dias <= 0) return Colors.red[700]!;
    if (dias <= 7) return Colors.orange[700]!;
    return Colors.green[700]!;
  }

  Widget _buildMultiSelectFilterField(
    String label,
    Set<String> selectedValues,
    List<String> options,
    Function(Set<String>) onChanged, {
    String? searchHint,
  }) {
    return InkWell(
      onTap: () {
        showDialog<Set<String>>(
          context: context,
          builder: (context) => MultiSelectFilterDialog(
            title: label,
            options: options,
            selectedValues: selectedValues,
            onSelectionChanged: onChanged,
            searchHint: searchHint,
          ),
        );
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
          suffixIcon: const Icon(Icons.arrow_drop_down),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        child: Text(
          selectedValues.isEmpty
              ? 'Todos'
              : selectedValues.length == 1
                  ? selectedValues.first
                  : '${selectedValues.length} selecionado(s)',
          style: TextStyle(
            color: selectedValues.isEmpty ? Colors.grey[600] : Colors.black,
            fontSize: 14,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clusterização de Ativos'),
        actions: [
          IconButton(
            icon: Icon(_isGraphView ? Icons.list : Icons.hub_outlined),
            onPressed: () {
              setState(() {
                _isGraphView = !_isGraphView;
              });
            },
            tooltip: _isGraphView ? 'Visualizar Lista' : 'Visualizar Grafo/Relações',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadClusters,
            tooltip: 'Recarregar dados',
          ),
        ],

      ),
      body: _isCheckingPermission
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Painel de Filtros e Busca (Design Premium)
                Card(
                  margin: const EdgeInsets.all(16.0),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  labelText: 'Buscar por local, sala, nota ou ordem',
                                  prefixIcon: Icon(Icons.search),
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _searchQuery = value.trim();
                                    _applyFiltersAndSort();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final useRow = constraints.maxWidth > 600;
                            if (useRow) {
                              return Row(
                                children: [
                                  Expanded(
                                    child: _buildMultiSelectFilterField(
                                      'Local',
                                      _selectedFiltroLocal,
                                      _locaisDisponiveis,
                                      (val) {
                                        setState(() {
                                          _selectedFiltroLocal.clear();
                                          _selectedFiltroLocal.addAll(val);
                                          _applyFiltersAndSort();
                                        });
                                      },
                                      searchHint: 'Pesquisar local...',
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildMultiSelectFilterField(
                                      'Sala',
                                      _selectedFiltroSala,
                                      _salasDisponiveis,
                                      (val) {
                                        setState(() {
                                          _selectedFiltroSala.clear();
                                          _selectedFiltroSala.addAll(val);
                                          _applyFiltersAndSort();
                                        });
                                      },
                                      searchHint: 'Pesquisar sala...',
                                    ),
                                  ),
                                ],
                              );
                            } else {
                              return Column(
                                children: [
                                  _buildMultiSelectFilterField(
                                    'Local',
                                    _selectedFiltroLocal,
                                    _locaisDisponiveis,
                                    (val) {
                                      setState(() {
                                        _selectedFiltroLocal.clear();
                                        _selectedFiltroLocal.addAll(val);
                                        _applyFiltersAndSort();
                                      });
                                    },
                                    searchHint: 'Pesquisar local...',
                                  ),
                                  const SizedBox(height: 16),
                                  _buildMultiSelectFilterField(
                                    'Sala',
                                    _selectedFiltroSala,
                                    _salasDisponiveis,
                                    (val) {
                                      setState(() {
                                        _selectedFiltroSala.clear();
                                        _selectedFiltroSala.addAll(val);
                                        _applyFiltersAndSort();
                                      });
                                    },
                                    searchHint: 'Pesquisar sala...',
                                  ),
                                ],
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Ordenação
                            Row(
                              children: [
                                const Text('Ordenar por: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('Prazo Crítico'),
                                  selected: _ordenacao == 'prazo',
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _ordenacao = 'prazo';
                                        _applyFiltersAndSort();
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('Volume de Demandas'),
                                  selected: _ordenacao == 'volume',
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _ordenacao = 'volume';
                                        _applyFiltersAndSort();
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                            // Filtro de Programados
                            Row(
                              children: [
                                const Text('Apenas Não Programados: '),
                                Switch(
                                  value: _apenasNaoProgramados,
                                  onChanged: (value) {
                                    setState(() {
                                      _apenasNaoProgramados = value;
                                    });
                                    _loadClusters();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Grid/Lista ou Grafo de Clusters
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredClusters.isEmpty
                          ? const Center(
                              child: Text('Nenhum ativo com demandas pendentes encontrado.'),
                            )
                          : _isGraphView
                              ? ClusterVisualizadorGrafico(
                                  clusters: _filteredClusters,
                                  canEditTasks: _canEditTasks,
                                  onProgramar: (cluster, notas, ordens) {
                                    setState(() {
                                      _selectedNotasIds[cluster.localKey] = notas.map((n) => n.id).toSet();
                                      _selectedOrdensIds[cluster.localKey] = ordens.map((o) => o.id).toSet();
                                    });
                                    _programarCluster(cluster);
                                  },
                                )
                              : GridView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: isMobile ? 1 : (isTablet ? 2 : 3),
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 1.15,
                                  ),
                                  itemCount: _filteredClusters.length,
                                  itemBuilder: (context, index) {
                                    final cluster = _filteredClusters[index];
                                    final hasSelection = 
                                        (_selectedNotasIds[cluster.localKey]?.isNotEmpty ?? false) ||
                                        (_selectedOrdensIds[cluster.localKey]?.isNotEmpty ?? false);

                                    return _buildClusterCard(cluster, hasSelection);
                                  },
                                ),
                ),

              ],
            ),
    );
  }

  Widget _buildClusterCard(AtivoCluster cluster, bool hasSelection) {
    final prazoText = cluster.diasRestantes == null 
        ? 'Sem prazo definido' 
        : (cluster.diasRestantes! < 0 
            ? 'Vencida há ${cluster.diasRestantes!.abs()} dias' 
            : 'Vence em ${cluster.diasRestantes} dias');
            
    final colorPrazo = _getPrazoColor(cluster.diasRestantes);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasSelection ? Colors.blue[300]! : Colors.grey[200]!,
          width: hasSelection ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header do Card
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.place, color: Colors.blue[800], size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cluster.local,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Sala: ${cluster.sala}',
                        style: TextStyle(color: Colors.grey[700], fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Corpo com Badges e Informações de Prazo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorPrazo.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: colorPrazo),
                      const SizedBox(width: 4),
                      Text(
                        prazoText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colorPrazo,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${cluster.totalDemandas} Demanda(s)',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Listagem de demandas
          Expanded(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              children: [
                if (cluster.notas.isNotEmpty) ...[
                  ...cluster.notas.map((n) {
                    final isSelected = _selectedNotasIds[cluster.localKey]?.contains(n.id) ?? false;
                    return CheckboxListTile(
                      value: isSelected,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: Builder(
                        builder: (context) {
                          final statusParts = <String>[];
                          if (n.statusSistema != null && n.statusSistema!.isNotEmpty) {
                            statusParts.add(n.statusSistema!);
                          }
                          if (n.statusUsuario != null && n.statusUsuario!.isNotEmpty) {
                            statusParts.add(n.statusUsuario!);
                          }
                          final statusString = statusParts.isNotEmpty ? ' [${statusParts.join(' / ')}]' : '';
                          return Text(
                            'Nota ${n.nota}$statusString',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                          );
                        }
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n.descricao ?? '', 
                            style: const TextStyle(fontSize: 10), 
                            maxLines: 1, 
                            overflow: TextOverflow.ellipsis
                          ),
                          if (cluster.tarefasNotas.containsKey(n.id)) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                border: Border.all(color: Colors.blue[100]!),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '📅 Programada: ${cluster.tarefasNotas[n.id]?['tarefa']} (${cluster.tarefasNotas[n.id]?['status']})',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  color: Colors.blue[800],
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      secondary: const Icon(Icons.push_pin, color: Colors.blue, size: 16),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedNotasIds[cluster.localKey]?.add(n.id);
                          } else {
                            _selectedNotasIds[cluster.localKey]?.remove(n.id);
                          }
                        });
                      },
                    );
                  }),
                ],
                if (cluster.ordens.isNotEmpty) ...[
                  ...cluster.ordens.map((o) {
                    final isSelected = _selectedOrdensIds[cluster.localKey]?.contains(o.id) ?? false;
                    return CheckboxListTile(
                      value: isSelected,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: Builder(
                        builder: (context) {
                          final statusParts = <String>[];
                          if (o.statusSistema != null && o.statusSistema!.isNotEmpty) {
                            statusParts.add(o.statusSistema!);
                          }
                          if (o.statusUsuario != null && o.statusUsuario!.isNotEmpty) {
                            statusParts.add(o.statusUsuario!);
                          }
                          final statusString = statusParts.isNotEmpty ? ' [${statusParts.join(' / ')}]' : '';
                          return Text(
                            'Ordem ${o.ordem}$statusString',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                          );
                        }
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.textoBreve ?? '', 
                            style: const TextStyle(fontSize: 10), 
                            maxLines: 1, 
                            overflow: TextOverflow.ellipsis
                          ),
                          if (cluster.tarefasOrdens.containsKey(o.id)) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                border: Border.all(color: Colors.green[100]!),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '📅 Programada: ${cluster.tarefasOrdens[o.id]?['tarefa']} (${cluster.tarefasOrdens[o.id]?['status']})',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      secondary: const Icon(Icons.receipt, color: Colors.green, size: 16),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedOrdensIds[cluster.localKey]?.add(o.id);
                          } else {
                            _selectedOrdensIds[cluster.localKey]?.remove(o.id);
                          }
                        });
                      },
                    );
                  }),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          // Footer com Ações
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: (_selectedNotasIds[cluster.localKey]?.length == cluster.notas.length) &&
                             (_selectedOrdensIds[cluster.localKey]?.length == cluster.ordens.length),
                      onChanged: (val) {
                        _toggleSelectAll(cluster, val ?? false);
                      },
                    ),
                    const Text('Todas', style: TextStyle(fontSize: 11)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: hasSelection ? () => _programarCluster(cluster) : null,
                  icon: const Icon(Icons.flash_on, size: 16),
                  label: const Text('Programar', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
