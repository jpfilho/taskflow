import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import '../models/nota_sap.dart';
import '../models/ordem.dart';
import '../services/cluster_service.dart';

// Identificadores de nós para o GraphView
class LocalNodeData {
  final String name;
  final int totalDemandas;
  LocalNodeData(this.name, this.totalDemandas);

  @override
  bool operator ==(Object other) => other is LocalNodeData && name == other.name;

  @override
  int get hashCode => name.hashCode;
}

class SalaNodeData {
  final AtivoCluster cluster;
  SalaNodeData(this.cluster);

  @override
  bool operator ==(Object other) => other is SalaNodeData && cluster.localKey == other.cluster.localKey;

  @override
  int get hashCode => cluster.localKey.hashCode;
}

class DemandaNodeData {
  final String id;
  final dynamic data; // NotaSAP ou Ordem
  final bool isNota;
  DemandaNodeData(this.id, this.data, this.isNota);

  @override
  bool operator ==(Object other) => other is DemandaNodeData && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class ClusterVisualizadorGrafico extends StatefulWidget {
  final List<AtivoCluster> clusters;
  final bool canEditTasks;
  final Function(AtivoCluster, List<NotaSAP>, List<Ordem>) onProgramar;

  const ClusterVisualizadorGrafico({
    super.key,
    required this.clusters,
    required this.canEditTasks,
    required this.onProgramar,
  });

  @override
  State<ClusterVisualizadorGrafico> createState() => _ClusterVisualizadorGraficoState();
}

class _ClusterVisualizadorGraficoState extends State<ClusterVisualizadorGrafico> {
  // Estado de desdobramento e seleção
  String? _selectedLocalName;
  AtivoCluster? _selectedCluster;
  final Set<String> _selectedNotasIds = {};
  final Set<String> _selectedOrdensIds = {};

  // Estado dos filtros e busca
  String _searchQuery = '';
  String _filtroDemanda = 'TODOS'; // 'TODOS', 'NOTAS', 'ORDENS'
  String _filtroCriticidade = 'TODOS'; // 'TODOS', 'CRITICOS', 'NORMAL'
  bool _isVertical = false; // Alterna a orientação do grafo
  List<AtivoCluster> _filteredClusters = [];

  Graph graph = Graph()..isTree = true;
  final BuchheimWalkerConfiguration builder = BuchheimWalkerConfiguration();
  late Algorithm _algorithm;

  // Caches persistentes para garantir que a mesma referência de Node seja reutilizada e o layout fique estável
  final Map<String, Node> _localNodesCache = {};
  final Map<String, Node> _salaNodesCache = {};
  final Map<String, Node> _demandaNodesCache = {};

  @override
  void initState() {
    super.initState();
    _updateLayoutOrientation();
    _buildGraphStructure();
  }

  void _updateLayoutOrientation() {
    builder
      ..siblingSeparation = 25
      ..levelSeparation = 120
      ..subtreeSeparation = 30
      ..orientation = _isVertical
          ? BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM
          : BuchheimWalkerConfiguration.ORIENTATION_LEFT_RIGHT;
    _algorithm = BuchheimWalkerAlgorithm(builder, TreeEdgeRenderer(builder));
  }

  @override
  void didUpdateWidget(ClusterVisualizadorGrafico oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clusters != oldWidget.clusters) {
      _buildGraphStructure();
    }
  }

  bool _isOrdemCritica(Ordem o) {
    final limite = o.tolerancia ?? o.fimBase;
    if (limite == null) return false;
    final diff = limite.difference(DateTime.now()).inDays;
    return diff <= 7;
  }

  // Constrói dinamicamente a estrutura de árvore do grafo baseada nos estados de expansão/clique e filtros ativos
  void _buildGraphStructure() {
    _localNodesCache.clear();
    _salaNodesCache.clear();
    _demandaNodesCache.clear();
    graph = Graph()..isTree = true; // Instanciar um grafo limpo

    if (widget.clusters.isEmpty) return;

    final query = _searchQuery.trim().toLowerCase();

    // 1. Filtrar e Agrupar clusters por Local
    final Map<String, List<AtivoCluster>> grupos = {};
    for (final rawCluster in widget.clusters) {
      // Aplicar filtro de busca por texto (Local ou Sala)
      if (query.isNotEmpty) {
        final matchesLocal = rawCluster.local.toLowerCase().contains(query);
        final matchesSala = rawCluster.sala.toLowerCase().contains(query);
        if (!matchesLocal && !matchesSala) continue;
      }

      // Filtrar Notas e Ordens do cluster conforme filtros de Demanda e Criticidade
      final filtradasNotas = rawCluster.notas.where((n) {
        if (_filtroDemanda == 'ORDENS') return false;
        if (_filtroCriticidade == 'CRITICOS') {
          return n.diasRestantes != null && n.diasRestantes! <= 7;
        }
        if (_filtroCriticidade == 'NORMAL') {
          return n.diasRestantes == null || n.diasRestantes! > 7;
        }
        return true;
      }).toList();

      final filtradasOrdens = rawCluster.ordens.where((o) {
        if (_filtroDemanda == 'NOTAS') return false;
        final critica = _isOrdemCritica(o);
        if (_filtroCriticidade == 'CRITICOS') return critica;
        if (_filtroCriticidade == 'NORMAL') return !critica;
        return true;
      }).toList();

      // Se após a filtragem o cluster não possuir nenhuma demanda correspondente, ignoramos
      if (filtradasNotas.isEmpty && filtradasOrdens.isEmpty) continue;

      // Criar uma instância de AtivoCluster "filtrada" para manter consistência nos nós filhos
      final cluster = AtivoCluster(
        localKey: rawCluster.localKey,
        local: rawCluster.local,
        sala: rawCluster.sala,
        notas: filtradasNotas,
        ordens: filtradasOrdens,
        prazoCritico: rawCluster.prazoCritico,
        diasRestantes: rawCluster.diasRestantes,
        prioridadeCritica: rawCluster.prioridadeCritica,
        estaProgramado: rawCluster.estaProgramado,
        tarefasNotas: rawCluster.tarefasNotas,
        tarefasOrdens: rawCluster.tarefasOrdens,
      );

      final String prefixo = cluster.local.trim().toUpperCase();
      if (!grupos.containsKey(prefixo)) {
        grupos[prefixo] = [];
      }
      grupos[prefixo]!.add(cluster);
    }

    // 2. Adicionar nós raiz de Locais usando cache de instâncias de Node
    grupos.forEach((localName, clusterList) {
      final int totalDemandasLocal = clusterList.fold(0, (sum, c) => sum + c.totalDemandas);
      final localData = LocalNodeData(localName, totalDemandasLocal);
      final nodeLocal = _localNodesCache.putIfAbsent(localName, () => Node.Id(localData));
      graph.addNode(nodeLocal);

      // 3. Se este Local foi expandido (clicado), renderizar suas respectivas salas ordenadas por total de demandas
      if (_selectedLocalName == localName) {
        final sortedClusters = List<AtivoCluster>.from(clusterList)
          ..sort((a, b) => b.totalDemandas.compareTo(a.totalDemandas));

        for (final cluster in sortedClusters) {
          final salaData = SalaNodeData(cluster);
          final nodeSala = _salaNodesCache.putIfAbsent(cluster.localKey, () => Node.Id(salaData));

          graph.addNode(nodeSala);
          graph.addEdge(nodeLocal, nodeSala);

          // 4. Se esta Sala foi selecionada, abrir demandas filhas
          if (_selectedCluster?.localKey == cluster.localKey) {
            // Adicionar Notas
            for (final nota in cluster.notas) {
              final notaData = DemandaNodeData(nota.id, nota, true);
              final nodeNota = _demandaNodesCache.putIfAbsent(nota.id, () => Node.Id(notaData));
              graph.addNode(nodeNota);
              graph.addEdge(nodeSala, nodeNota);
            }
            // Adicionar Ordens (apenas se não vinculadas a nenhuma nota mostrada)
            final notasOrdemNumeros = cluster.notas.map((n) => n.ordem).whereType<String>().toSet();
            final ordensNaoVinculadas = cluster.ordens.where((o) => !notasOrdemNumeros.contains(o.ordem)).toList();

            for (final ordem in ordensNaoVinculadas) {
              final ordemData = DemandaNodeData(ordem.id, ordem, false);
              final nodeOrdem = _demandaNodesCache.putIfAbsent(ordem.id, () => Node.Id(ordemData));
              graph.addNode(nodeOrdem);
              graph.addEdge(nodeSala, nodeOrdem);
            }
          }
        }
      }
    });

    // Atualizar os clusters filtrados disponíveis para consolidação de Local
    _filteredClusters = grupos.values.expand((list) => list).toList();
  }

  Color _getPrazoColor(int? dias) {
    if (dias == null) return Colors.grey;
    if (dias <= 0) return Colors.red[600]!;
    if (dias <= 7) return Colors.orange[600]!;
    return Colors.green[600]!;
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Campo de Busca
          Expanded(
            flex: 3,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: TextField(
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                    _buildGraphStructure();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Buscar local ou sala...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Filtro por Tipo de Demanda
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filtroDemanda,
                style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.bold),
                items: const [
                  DropdownMenuItem(value: 'TODOS', child: Text('Todas Demandas')),
                  DropdownMenuItem(value: 'NOTAS', child: Text('Apenas Notas SAP')),
                  DropdownMenuItem(value: 'ORDENS', child: Text('Apenas Ordens')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _filtroDemanda = val;
                      _buildGraphStructure();
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Filtro por Criticidade
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filtroCriticidade,
                style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.bold),
                items: const [
                  DropdownMenuItem(value: 'TODOS', child: Text('Todos os Prazos')),
                  DropdownMenuItem(value: 'CRITICOS', child: Text('Críticos (≤ 7 dias)')),
                  DropdownMenuItem(value: 'NORMAL', child: Text('Fora de Risco')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _filtroCriticidade = val;
                      _buildGraphStructure();
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Orientação do Grafo
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Layout Horizontal',
                  icon: Icon(Icons.settings_ethernet, 
                    color: !_isVertical ? Colors.blue[800] : Colors.grey[500],
                    size: 18,
                  ),
                  onPressed: () {
                    if (_isVertical) {
                      setState(() {
                        _isVertical = false;
                        _updateLayoutOrientation();
                        _buildGraphStructure();
                      });
                    }
                  },
                ),
                Container(width: 1, height: 24, color: Colors.grey[200]),
                IconButton(
                  tooltip: 'Layout Vertical',
                  icon: Icon(Icons.schema_outlined, 
                    color: _isVertical ? Colors.blue[800] : Colors.grey[500],
                    size: 18,
                  ),
                  onPressed: () {
                    if (!_isVertical) {
                      setState(() {
                        _isVertical = true;
                        _updateLayoutOrientation();
                        _buildGraphStructure();
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Canvas do Grafo utilizando o GraphView integrado ao InteractiveViewer nativo (Lado Esquerdo)
              Expanded(
                child: Container(
                  color: Colors.grey[50], // Fundo técnico premium
                  child: InteractiveViewer(
                    key: ValueKey('${_selectedCluster?.localKey}_${_selectedLocalName}_${_isVertical}'),
                    constrained: false, // Permite navegação infinita e pan irrestrito
                    boundaryMargin: const EdgeInsets.all(800),
                    minScale: 0.1,
                    maxScale: 2.0,
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: GraphView(
                        graph: graph,
                        algorithm: _algorithm,
                        paint: Paint()
                          ..color = Colors.blueGrey[200]!
                          ..strokeWidth = 2.0
                          ..style = PaintingStyle.stroke,
                        builder: (Node node) {
                          final value = node.key!.value;
                          if (value is LocalNodeData) {
                            return _buildLocalNode(value);
                          } else if (value is SalaNodeData) {
                            return _buildSalaNode(value);
                          } else if (value is DemandaNodeData) {
                            return _buildDemandaNode(value);
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                ),
              ),
              // Painel Lateral Direito de Detalhes ao selecionar um Cluster (Sala) ou Local Consolidado
              if (_selectedCluster != null || _selectedLocalName != null)
                Container(
                  width: 760,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      left: BorderSide(color: Colors.grey[200]!, width: 1.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  child: () {
                    if (_selectedCluster != null) {
                      return _buildDetailsPanel(_selectedCluster!);
                    } else {
                      // Consolidar todas as salas do local selecionado
                      final localClusters = _filteredClusters
                          .where((c) => c.local.trim().toUpperCase() == _selectedLocalName!.toUpperCase())
                          .toList();
                      final todasNotas = localClusters.expand((c) => c.notas).toList();
                      final todasOrdens = localClusters.expand((c) => c.ordens).toList();
                      
                      final Map<String, Map<String, dynamic>> consolidatedTarefasNotas = {};
                      final Map<String, Map<String, dynamic>> consolidatedTarefasOrdens = {};
                      for (final c in localClusters) {
                        consolidatedTarefasNotas.addAll(c.tarefasNotas);
                        consolidatedTarefasOrdens.addAll(c.tarefasOrdens);
                      }

                      final consolidatedCluster = AtivoCluster(
                        localKey: _selectedLocalName!.toUpperCase(),
                        local: _selectedLocalName!,
                        sala: 'Todas as salas',
                        notas: todasNotas,
                        ordens: todasOrdens,
                        tarefasNotas: consolidatedTarefasNotas,
                        tarefasOrdens: consolidatedTarefasOrdens,
                        prioridadeCritica: '',
                        estaProgramado: false,
                      );
                      return _buildDetailsPanel(consolidatedCluster, isConsolidated: true);
                    }
                  }(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // 1. Renderiza o Hub do Local (Bola Azul com Contador de demandas gerais e gradiente)
  Widget _buildLocalNode(LocalNodeData data) {
    final isSelected = _selectedLocalName == data.name;
    
    // Identificar se este Local possui alguma demanda crítica ou atrasada
    final temCriticos = widget.clusters.any((c) =>
      c.local.trim().toUpperCase() == data.name.toUpperCase() &&
      ((c.diasRestantes != null && c.diasRestantes! <= 7) || c.ordens.any((o) => _isOrdemCritica(o)))
    );

    final gradientePadrao = LinearGradient(
      colors: temCriticos 
          ? [Colors.red[900]!, Colors.red[700]!]
          : [Colors.blue[900]!, Colors.blue[700]!],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final gradienteSelecionado = LinearGradient(
      colors: temCriticos
          ? [Colors.red[700]!, Colors.red[500]!]
          : [Colors.blue[700]!, Colors.blue[500]!],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedLocalName = null;
            _selectedCluster = null;
            _selectedNotasIds.clear();
            _selectedOrdensIds.clear();
          } else {
            _selectedLocalName = data.name;
            _selectedCluster = null; // Fechar sala anterior ao trocar de local

            // Inicializar seleção consolidada de todas as salas deste local
            _selectedNotasIds.clear();
            _selectedOrdensIds.clear();
            final localClusters = _filteredClusters
                .where((c) => c.local.trim().toUpperCase() == data.name.toUpperCase())
                .toList();
            for (final cluster in localClusters) {
              _selectedNotasIds.addAll(
                cluster.notas
                    .where((n) => !cluster.tarefasNotas.containsKey(n.id))
                    .map((n) => n.id),
              );
              final notasOrdemNumeros = cluster.notas.map((n) => n.ordem).whereType<String>().toSet();
              final ordensNaoVinculadas = cluster.ordens.where((o) => !notasOrdemNumeros.contains(o.ordem)).toList();
              _selectedOrdensIds.addAll(
                ordensNaoVinculadas
                    .where((o) => !cluster.tarefasOrdens.containsKey(o.id))
                    .map((o) => o.id),
              );
            }
          }
          _buildGraphStructure();
        });
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: 95,
          height: 95,
          decoration: BoxDecoration(
            gradient: isSelected ? gradienteSelecionado : gradientePadrao,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (temCriticos ? Colors.red : Colors.blue).withValues(alpha: isSelected ? 0.6 : 0.3),
                blurRadius: isSelected ? 16 : 8,
                spreadRadius: isSelected ? 4 : 1,
                offset: const Offset(0, 4),
              )
            ],
            border: Border.all(
              color: isSelected 
                  ? (temCriticos ? Colors.red[300]! : Colors.blue[300]!) 
                  : (temCriticos ? Colors.red[400]! : Colors.blue[400]!),
              width: isSelected ? 3.0 : 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  data.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (temCriticos)
                      const Padding(
                        padding: EdgeInsets.only(right: 3.0),
                        child: Icon(Icons.warning_amber_rounded, color: Colors.white, size: 9),
                      ),
                    Text(
                      '${data.totalDemandas}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // 2. Renderiza a Sala (Capsula com gradiente de prazo e contadores separados)
  Widget _buildSalaNode(SalaNodeData data) {
    final cluster = data.cluster;
    final isSelected = _selectedCluster?.localKey == cluster.localKey;
    final colorPrazo = _getPrazoColor(cluster.diasRestantes);
    final countNotas = cluster.notas.length;
    final countOrdens = cluster.ordens.length;

    // Verificar se há itens atrasados na sala
    final temAtrasados = cluster.diasRestantes != null && cluster.diasRestantes! <= 0;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedCluster = null;
          } else {
            _selectedCluster = cluster;
            // Inicializar seleção do painel lateral
            _selectedNotasIds.clear();
            _selectedOrdensIds.clear();
            _selectedNotasIds.addAll(
              cluster.notas
                  .where((n) => !cluster.tarefasNotas.containsKey(n.id))
                  .map((n) => n.id),
            );
            final notasOrdemNumeros = cluster.notas.map((n) => n.ordem).whereType<String>().toSet();
            final ordensNaoVinculadas = cluster.ordens.where((o) => !notasOrdemNumeros.contains(o.ordem)).toList();
            _selectedOrdensIds.addAll(
              ordensNaoVinculadas
                  .where((o) => !cluster.tarefasOrdens.containsKey(o.id))
                  .map((o) => o.id),
            );
          }
          _buildGraphStructure();
        });
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue[50] : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? Colors.blue[700]! : colorPrazo.withValues(alpha: 0.8),
              width: isSelected ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected 
                    ? Colors.blue.withValues(alpha: 0.15) 
                    : Colors.black.withValues(alpha: 0.06),
                blurRadius: isSelected ? 8 : 4,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                temAtrasados ? Icons.error_outline : Icons.room_outlined,
                size: 15,
                color: isSelected ? Colors.blue[800] : colorPrazo,
              ),
              const SizedBox(width: 6),
              Text(
                'Sala: ${cluster.sala}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 10),
              // Contadores Separados de Notas e Ordens
              if (countNotas > 0)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.push_pin, size: 8, color: Colors.blue[850]),
                      const SizedBox(width: 2),
                      Text(
                        '$countNotas',
                        style: TextStyle(
                          color: Colors.blue[900],
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              if (countOrdens > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.receipt, size: 8, color: Colors.green[850]),
                      const SizedBox(width: 2),
                      Text(
                        '$countOrdens',
                        style: TextStyle(
                          color: Colors.green[900],
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
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

  // 3. Renderiza as Notas SAP (Capsula com Tags de Prioridade) e Ordens (Capsula com Tipo e Tolerância)
  Widget _buildDemandaNode(DemandaNodeData data) {
    if (data.isNota) {
      final n = data.data as NotaSAP;
      final bool isProgramado = _selectedCluster?.tarefasNotas.containsKey(n.id) ?? false;
      final bool isSelected = _selectedNotasIds.contains(n.id);

      // Definir cores baseadas na prioridade
      Color priorityColor;
      Color priorityBg;
      final prioText = (n.textPrioridade ?? '').toUpperCase();
      if (prioText.contains('ALTA')) {
        priorityColor = Colors.red[900]!;
        priorityBg = Colors.red[50]!;
      } else if (prioText.contains('MÉD') || prioText.contains('MED')) {
        priorityColor = Colors.orange[900]!;
        priorityBg = Colors.orange[50]!;
      } else {
        priorityColor = Colors.blueGrey[800]!;
        priorityBg = Colors.blueGrey[50]!;
      }

      // Definir status de vencimento
      Widget? prazoWidget;
      if (n.diasRestantes != null) {
        final dias = n.diasRestantes!;
        if (dias < 0) {
          prazoWidget = Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(color: Colors.red[600], borderRadius: BorderRadius.circular(4)),
            child: Text('ATRASADA ${dias.abs()}d', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
          );
        } else if (dias <= 7) {
          prazoWidget = Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(color: Colors.orange[600], borderRadius: BorderRadius.circular(4)),
            child: Text('${dias}d rest.', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
          );
        }
      }

      return GestureDetector(
        onTap: () {
          if (isProgramado) return;
          setState(() {
            if (_selectedNotasIds.contains(n.id)) {
              _selectedNotasIds.remove(n.id);
            } else {
              _selectedNotasIds.add(n.id);
            }
          });
        },
        child: MouseRegion(
          cursor: isProgramado ? SystemMouseCursors.basic : SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isProgramado
                  ? Colors.grey[100]
                  : (isSelected ? Colors.blue[600] : Colors.blue[50]),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isProgramado ? Colors.grey[400]! : Colors.blue[700]!,
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.push_pin,
                  size: 12,
                  color: isProgramado
                      ? Colors.grey[600]
                      : (isSelected ? Colors.white : Colors.blue[800]),
                ),
                const SizedBox(width: 4),
                Text(
                  'Nota ${n.nota}${n.statusUsuario != null && n.statusUsuario!.isNotEmpty ? " [${n.statusUsuario}]" : ""}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isProgramado
                        ? Colors.grey[600]
                        : (isSelected ? Colors.white : Colors.blue[900]),
                  ),
                ),
                if (!isProgramado && n.textPrioridade != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withValues(alpha: 0.2) : priorityBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      n.textPrioridade!,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: isSelected ? Colors.white : priorityColor,
                      ),
                    ),
                  ),
                ],
                if (!isProgramado && prazoWidget != null) prazoWidget,
              ],
            ),
          ),
        ),
      );
    } else {
      final o = data.data as Ordem;
      final bool isProgramado = _selectedCluster?.tarefasOrdens.containsKey(o.id) ?? false;
      final bool isSelected = _selectedOrdensIds.contains(o.id);

      // Calcular prazo da Ordem
      Widget? prazoWidget;
      final limite = o.tolerancia ?? o.fimBase;
      if (limite != null) {
        final diff = limite.difference(DateTime.now()).inDays;
        if (diff < 0) {
          prazoWidget = Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(color: Colors.red[600], borderRadius: BorderRadius.circular(4)),
            child: Text('ATRASADA ${diff.abs()}d', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
          );
        } else if (diff <= 7) {
          prazoWidget = Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(color: Colors.orange[600], borderRadius: BorderRadius.circular(4)),
            child: Text('${diff}d rest.', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
          );
        }
      }

      return GestureDetector(
        onTap: () {
          if (isProgramado) return;
          setState(() {
            if (_selectedOrdensIds.contains(o.id)) {
              _selectedOrdensIds.remove(o.id);
            } else {
              _selectedOrdensIds.add(o.id);
            }
          });
        },
        child: MouseRegion(
          cursor: isProgramado ? SystemMouseCursors.basic : SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isProgramado
                  ? Colors.grey[100]
                  : (isSelected ? Colors.green[600] : Colors.green[50]),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isProgramado ? Colors.grey[400]! : Colors.green[700]!,
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.receipt,
                  size: 12,
                  color: isProgramado
                      ? Colors.grey[600]
                      : (isSelected ? Colors.white : Colors.green[800]),
                ),
                const SizedBox(width: 4),
                Text(
                  'Ordem ${o.ordem}${o.statusUsuario != null && o.statusUsuario!.isNotEmpty ? " [${o.statusUsuario}]" : ""}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isProgramado
                        ? Colors.grey[600]
                        : (isSelected ? Colors.white : Colors.green[900]),
                  ),
                ),
                if (!isProgramado && o.tipo != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.green[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      o.tipo!,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: isSelected ? Colors.white : Colors.green[900],
                      ),
                    ),
                  ),
                ],
                if (!isProgramado && prazoWidget != null) prazoWidget,
              ],
            ),
          ),
        ),
      );
    }
  }

  // 4. Painel de Detalhes Lateral Direito (Altura Total)
  Widget _buildDetailsPanel(AtivoCluster cluster, {bool isConsolidated = false}) {
    final colorPrazo = _getPrazoColor(cluster.diasRestantes);
    final hasSelection = _selectedNotasIds.isNotEmpty || _selectedOrdensIds.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place, color: colorPrazo, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConsolidated ? 'Consolidado - Local: ${cluster.local}' : cluster.local,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      isConsolidated 
                          ? 'Todas as salas  |  ${cluster.totalDemandas} Demanda(s)'
                          : 'Sala: ${cluster.sala}  |  ${cluster.totalDemandas} Demanda(s)',
                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedCluster = null;
                    _selectedLocalName = null;
                    _buildGraphStructure();
                  });
                },
              )
            ],
          ),
          const Divider(),
          Expanded(
            child: ListView(
              children: [
                ...cluster.notas.map((n) {
                  final isProgramado = cluster.tarefasNotas.containsKey(n.id);
                  final isSelected = _selectedNotasIds.contains(n.id);
                  return InkWell(
                    onTap: isProgramado ? null : () {
                      setState(() {
                        if (isSelected) {
                          _selectedNotasIds.remove(n.id);
                        } else {
                          _selectedNotasIds.add(n.id);
                        }
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? Colors.indigo.shade50.withOpacity(0.4) 
                            : Colors.white,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.015),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                width: 4.0,
                                color: isProgramado ? Colors.grey : Colors.indigo.shade600,
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Checkbox(
                                        value: isSelected,
                                        onChanged: isProgramado ? null : (val) {
                                          setState(() {
                                            if (val == true) {
                                              _selectedNotasIds.add(n.id);
                                            } else {
                                              _selectedNotasIds.remove(n.id);
                                            }
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: isProgramado 
                                                        ? Colors.grey.shade200 
                                                        : Colors.indigo.shade50,
                                                    borderRadius: BorderRadius.circular(4.0),
                                                  ),
                                                  child: Text(
                                                    'NOTA',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                      color: isProgramado ? Colors.grey : Colors.indigo.shade700,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    '${n.nota}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: isProgramado ? Colors.grey : Colors.black87,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              n.descricao ?? '',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isProgramado ? Colors.grey : Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              isProgramado
                                                  ? '📅 Programada: ${cluster.tarefasNotas[n.id]?['tarefa']}${isConsolidated ? ' | Sala: ${n.sala ?? "N/A"}' : ''} | Status: ${n.statusUsuario ?? "N/A"} | Vencimento: ${_formatDate(n.dataVencimento)}'
                                                  : '📅 Vencimento: ${_formatDate(n.dataVencimento)}${isConsolidated ? ' | Sala: ${n.sala ?? "N/A"}' : ''} | Status: ${n.statusUsuario ?? "N/A"}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: isProgramado ? Colors.grey : Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                ...(() {
                  final notasOrdemNumeros = cluster.notas.map((n) => n.ordem).whereType<String>().toSet();
                  final ordensNaoVinculadas = cluster.ordens.where((o) => !notasOrdemNumeros.contains(o.ordem)).toList();
                  return ordensNaoVinculadas.map((o) {
                    final isProgramado = cluster.tarefasOrdens.containsKey(o.id);
                    final isSelected = _selectedOrdensIds.contains(o.id);
                    return InkWell(
                      onTap: isProgramado ? null : () {
                        setState(() {
                          if (isSelected) {
                            _selectedOrdensIds.remove(o.id);
                          } else {
                            _selectedOrdensIds.add(o.id);
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? Colors.teal.shade50.withOpacity(0.4) 
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.015),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  width: 4.0,
                                  color: isProgramado ? Colors.grey : Colors.teal.shade600,
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Checkbox(
                                          value: isSelected,
                                          onChanged: isProgramado ? null : (val) {
                                            setState(() {
                                              if (val == true) {
                                                _selectedOrdensIds.add(o.id);
                                              } else {
                                                _selectedOrdensIds.remove(o.id);
                                              }
                                            });
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: isProgramado 
                                                          ? Colors.grey.shade200 
                                                          : Colors.teal.shade50,
                                                      borderRadius: BorderRadius.circular(4.0),
                                                    ),
                                                    child: Text(
                                                      'ORDEM',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                        color: isProgramado ? Colors.grey : Colors.teal.shade700,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      '${o.ordem}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                        color: isProgramado ? Colors.grey : Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                o.textoBreve ?? '',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isProgramado ? Colors.grey : Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                isProgramado
                                                    ? '📅 Programada: ${cluster.tarefasOrdens[o.id]?['tarefa']}${isConsolidated ? ' | Sala: ${o.sala ?? "N/A"}' : ''} | Status: ${o.statusUsuario ?? "N/A"} | Tolerância: ${_formatDate(o.tolerancia ?? o.fimBase)}'
                                                    : '📅 Tolerância: ${_formatDate(o.tolerancia ?? o.fimBase)}${isConsolidated ? ' | Sala: ${o.sala ?? "N/A"}' : ''} | Status: ${o.statusUsuario ?? "N/A"}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: isProgramado ? Colors.grey : Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  });
                }()),
              ],
            ),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedNotasIds.addAll(
                      cluster.notas
                          .where((n) => !cluster.tarefasNotas.containsKey(n.id))
                          .map((n) => n.id),
                    );
                    final notasOrdemNumeros = cluster.notas.map((n) => n.ordem).whereType<String>().toSet();
                    final ordensNaoVinculadas = cluster.ordens.where((o) => !notasOrdemNumeros.contains(o.ordem)).toList();
                    _selectedOrdensIds.addAll(
                      ordensNaoVinculadas
                          .where((o) => !cluster.tarefasOrdens.containsKey(o.id))
                          .map((o) => o.id),
                    );
                  });
                },
                child: const Text('Selecionar Todas', style: TextStyle(fontSize: 12)),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedNotasIds.clear();
                    _selectedOrdensIds.clear();
                  });
                },
                child: const Text('Limpar', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (hasSelection && widget.canEditTasks)
                  ? () {
                      final selecionadasNotas = cluster.notas
                          .where((n) => _selectedNotasIds.contains(n.id))
                          .toList();
                      final notasOrdemNumeros = cluster.notas.map((n) => n.ordem).whereType<String>().toSet();
                      final ordensNaoVinculadas = cluster.ordens.where((o) => !notasOrdemNumeros.contains(o.ordem)).toList();
                      final selecionadasOrdens = ordensNaoVinculadas
                          .where((o) => _selectedOrdensIds.contains(o.id))
                          .toList();
                      widget.onProgramar(cluster, selecionadasNotas, selecionadasOrdens);
                    }
                  : null,
              icon: const Icon(Icons.flash_on, size: 16),
              label: const Text('Programar Selecionados'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'N/A';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    return '$d/$m/$y';
  }
}
