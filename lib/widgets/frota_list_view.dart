import 'package:flutter/material.dart';
import '../models/frota.dart';
import '../models/regional.dart';
import '../models/divisao.dart';
import '../models/segmento.dart';
import '../services/frota_service.dart';
import '../services/regional_service.dart';
import '../services/divisao_service.dart';
import '../services/segmento_service.dart';
import 'frota_form_dialog.dart';
import 'multi_select_filter_dialog.dart';
import '../utils/responsive.dart';

class FrotaListView extends StatefulWidget {
  const FrotaListView({super.key});

  @override
  State<FrotaListView> createState() => _FrotaListViewState();
}

class _FrotaListViewState extends State<FrotaListView> {
  final FrotaService _frotaService = FrotaService();
  final RegionalService _regionalService = RegionalService();
  final DivisaoService _divisaoService = DivisaoService();
  final SegmentoService _segmentoService = SegmentoService();

  List<Frota> _frotas = [];
  List<Frota> _filteredFrotas = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isTableView = false; // false = lista (cards), true = tabela
  final ScrollController _horizontalTableScrollController = ScrollController();

  // Filtros (multiseleção com pesquisa)
  List<Regional> _regionais = [];
  List<Divisao> _divisoes = [];
  List<Segmento> _segmentos = [];
  List<String> _regionaisTotais = [];
  List<String> _divisoesTotais = [];
  List<String> _segmentosTotais = [];
  List<String> _tiposTotais = [];
  Set<String> _selectedRegional = {};
  Set<String> _selectedDivisao = {};
  Set<String> _selectedSegmento = {};
  Set<String> _selectedTipo = {};
  bool _isLoadingFilterOptions = true;

  static const List<Map<String, String>> _tiposVeiculos = [
    {'value': 'CARRO_LEVE', 'label': 'Carro Leve'},
    {'value': 'MUNCK', 'label': 'Munck'},
    {'value': 'TRATOR', 'label': 'Trator'},
    {'value': 'CAMINHAO', 'label': 'Caminhão'},
    {'value': 'PICKUP', 'label': 'Pickup'},
    {'value': 'VAN', 'label': 'Van'},
    {'value': 'MOTO', 'label': 'Moto'},
    {'value': 'ONIBUS', 'label': 'Ônibus'},
    {'value': 'OUTRO', 'label': 'Outro'},
  ];

  @override
  void initState() {
    super.initState();
    _tiposTotais = _tiposVeiculos.map((e) => e['label']!).toList();
    _loadFrotas();
    _loadFilterOptions();
    _searchController.addListener(_onSearchChanged);
    // No desktop, tabela é o padrão
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Responsive.isDesktop(context)) {
        setState(() {
          _isTableView = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalTableScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFrotas() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final frotas = await _frotaService.getAllFrotas();
      setState(() {
        _frotas = frotas;
        _filteredFrotas = _applyAllFilters();
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao carregar frota: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar frota: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadFilterOptions() async {
    _tiposTotais = _tiposVeiculos.map((t) => t['label']!).toList();
    try {
      final results = await Future.wait([
        _regionalService.getAllRegionais(),
        _divisaoService.getAllDivisoes(),
        _segmentoService.getAllSegmentos(),
      ]);
      if (!mounted) return;
      setState(() {
        _regionais = results[0] as List<Regional>;
        _divisoes = results[1] as List<Divisao>;
        _segmentos = results[2] as List<Segmento>;
        _regionaisTotais = _regionais.map((r) => r.regional).toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _divisoesTotais = _divisoes.map((d) => d.divisao).toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _segmentosTotais = _segmentos.map((s) => s.segmento).toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _isLoadingFilterOptions = false;
        _filteredFrotas = _applyAllFilters();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFilterOptions = false;
          _filteredFrotas = _applyAllFilters();
        });
      }
    }
  }

  List<Frota> _applyAllFilters() {
    List<Frota> result = _frotas;

    if (_selectedRegional.isNotEmpty) {
      final regionalIds = _regionais.where((r) => _selectedRegional.contains(r.regional)).map((r) => r.id).toSet();
      result = result.where((e) => e.regionalId != null && regionalIds.contains(e.regionalId)).toList();
    }
    if (_selectedDivisao.isNotEmpty) {
      final divisaoIds = _divisoes.where((d) => _selectedDivisao.contains(d.divisao)).map((d) => d.id).toSet();
      result = result.where((e) => e.divisaoId != null && divisaoIds.contains(e.divisaoId)).toList();
    }
    if (_selectedSegmento.isNotEmpty) {
      final segmentoIds = _segmentos.where((s) => _selectedSegmento.contains(s.segmento)).map((s) => s.id).toSet();
      result = result.where((e) => e.segmentoId != null && segmentoIds.contains(e.segmentoId)).toList();
    }
    if (_selectedTipo.isNotEmpty) {
      final tipoValues = _tiposVeiculos.where((t) => _selectedTipo.contains(t['label'])).map((t) => t['value']!).toSet();
      result = result.where((e) => tipoValues.contains(e.tipoVeiculo)).toList();
    }

    final query = _searchController.text.toLowerCase().trim();
    if (query.isNotEmpty) {
      result = result.where((frota) {
        return frota.nome.toLowerCase().contains(query) ||
            (frota.marca?.toLowerCase().contains(query) ?? false) ||
            frota.placa.toLowerCase().contains(query) ||
            frota.tipoVeiculo.toLowerCase().contains(query) ||
            (_getTipoVeiculoLabel(frota.tipoVeiculo).toLowerCase().contains(query)) ||
            (frota.regional?.toLowerCase().contains(query) ?? false) ||
            (frota.divisao?.toLowerCase().contains(query) ?? false) ||
            (frota.segmento?.toLowerCase().contains(query) ?? false);
      }).toList();
    }
    return result;
  }

  void _onSearchChanged() {
    setState(() {
      _filteredFrotas = _applyAllFilters();
    });
  }

  void _onFilterChanged() {
    setState(() {
      _filteredFrotas = _applyAllFilters();
    });
  }

  String _getTipoVeiculoLabel(String tipo) {
    switch (tipo) {
      case 'CARRO_LEVE':
        return 'Carro Leve';
      case 'MUNCK':
        return 'Munck';
      case 'TRATOR':
        return 'Trator';
      case 'CAMINHAO':
        return 'Caminhão';
      case 'PICKUP':
        return 'Pickup';
      case 'VAN':
        return 'Van';
      case 'MOTO':
        return 'Moto';
      case 'ONIBUS':
        return 'Ônibus';
      case 'OUTRO':
        return 'Outro';
      default:
        return tipo;
    }
  }

  Future<void> _createFrota() async {
    final result = await showDialog<Frota>(
      context: context,
      builder: (context) => const FrotaFormDialog(),
    );

    if (result != null) {
      try {
        await _frotaService.createFrota(result);
        await _loadFrotas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Frota criada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao criar frota: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _duplicateFrota(Frota frota) async {
    // Criar cópia com nome e placa modificados
    final duplicated = frota.copyWith(
      id: '',
      nome: '${frota.nome} (Cópia)',
      placa: '${frota.placa}-CP', // Adicionar sufixo à placa
    );

    final result = await showDialog<Frota>(
      context: context,
      builder: (context) => FrotaFormDialog(frota: duplicated),
    );

    if (result != null) {
      try {
        await _frotaService.createFrota(result);
        await _loadFrotas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Frota duplicada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao duplicar frota: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editFrota(Frota frota) async {
    final result = await showDialog<Frota>(
      context: context,
      builder: (context) => FrotaFormDialog(frota: frota),
    );

    if (result != null) {
      try {
        await _frotaService.updateFrota(frota.id, result);
        await _loadFrotas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Frota atualizada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao atualizar frota: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteFrota(Frota frota) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir a frota "${frota.nome}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _frotaService.deleteFrota(frota.id);
        await _loadFrotas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Frota excluída com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir frota: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Frota'),
        actions: [
          // Toggle de visualização
          IconButton(
            icon: Icon(_isTableView ? Icons.view_list : Icons.table_chart),
            onPressed: () {
              setState(() {
                _isTableView = !_isTableView;
              });
            },
            tooltip: _isTableView ? 'Visualização em Lista' : 'Visualização em Tabela',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createFrota,
            tooltip: 'Nova Frota',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de busca
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _onSearchChanged(),
              decoration: InputDecoration(
                labelText: 'Buscar frota',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged();
                        },
                      )
                    : null,
              ),
            ),
          ),
          // Filtros: Regional, Divisão, Segmento, Tipo (multiseleção com pesquisa)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
            child: _buildFiltersRow(),
          ),
          // Lista ou Tabela
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredFrotas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.directions_car_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'Nenhuma frota cadastrada'
                                  : 'Nenhuma frota encontrada',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : _isTableView
                        ? _buildTableView()
                        : _buildListView(),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersRow() {
    final isMobile = Responsive.isMobile(context);
    if (_isLoadingFilterOptions) {
      return const SizedBox(
        height: 48,
        child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (isMobile) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildMultiSelectFilterField('REGIONAL', _regionaisTotais, _selectedRegional, (v) {
                      setState(() { _selectedRegional = v; _onFilterChanged(); });
                    }, isMobile: true),
                    const SizedBox(width: 8),
                    _buildMultiSelectFilterField('DIVISÃO', _divisoesTotais, _selectedDivisao, (v) {
                      setState(() { _selectedDivisao = v; _onFilterChanged(); });
                    }, isMobile: true),
                    const SizedBox(width: 8),
                    _buildMultiSelectFilterField('SEGMENTO', _segmentosTotais, _selectedSegmento, (v) {
                      setState(() { _selectedSegmento = v; _onFilterChanged(); });
                    }, isMobile: true),
                    const SizedBox(width: 8),
                    _buildMultiSelectFilterField('TIPO', _tiposTotais, _selectedTipo, (v) {
                      setState(() { _selectedTipo = v; _onFilterChanged(); });
                    }, isMobile: true),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[350]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildMultiSelectFilterField('REGIONAL', _regionaisTotais, _selectedRegional, (v) {
              setState(() { _selectedRegional = v; _onFilterChanged(); });
            }, isMobile: false),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMultiSelectFilterField('DIVISÃO', _divisoesTotais, _selectedDivisao, (v) {
              setState(() { _selectedDivisao = v; _onFilterChanged(); });
            }, isMobile: false),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMultiSelectFilterField('SEGMENTO', _segmentosTotais, _selectedSegmento, (v) {
              setState(() { _selectedSegmento = v; _onFilterChanged(); });
            }, isMobile: false),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMultiSelectFilterField('TIPO', _tiposTotais, _selectedTipo, (v) {
              setState(() { _selectedTipo = v; _onFilterChanged(); });
            }, isMobile: false),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiSelectFilterField(
    String label,
    List<String> options,
    Set<String> selectedValues,
    ValueChanged<Set<String>> onChanged, {
    bool isMobile = false,
  }) {
    final hasSelection = selectedValues.isNotEmpty;
    final horizontalPad = isMobile ? 8.0 : 12.0;
    final verticalPad = isMobile ? 6.0 : 8.0;
    final fontSize = isMobile ? 11.0 : 12.0;
    final labelSize = isMobile ? 9.0 : 10.0;
    return Container(
      constraints: isMobile ? const BoxConstraints(minWidth: 100) : null,
      padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: verticalPad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: hasSelection ? Colors.blue : Colors.grey[350]!,
          width: isMobile ? 1 : 1.2,
        ),
      ),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (ctx) => MultiSelectFilterDialog(
              title: label,
              options: options,
              selectedValues: selectedValues,
              onSelectionChanged: onChanged,
              searchHint: 'Pesquisar...',
            ),
          );
        },
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: labelSize,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: isMobile ? 2 : 4),
                  Text(
                    selectedValues.isEmpty
                        ? 'Todos'
                        : selectedValues.length == 1
                            ? selectedValues.first
                            : '${selectedValues.length} selecionado(s)',
                    style: TextStyle(
                      fontSize: fontSize,
                      color: selectedValues.isEmpty ? Colors.grey[600]! : Colors.black87,
                      height: 1.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.grey[600], size: isMobile ? 20 : 24),
          ],
        ),
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      itemCount: _filteredFrotas.length,
      itemBuilder: (context, index) {
        final frota = _filteredFrotas[index];
        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 8.0,
          ),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: frota.emManutencao
                  ? Colors.orange
                  : (frota.ativo ? Colors.green : Colors.grey),
              child: Icon(
                _getTipoVeiculoIcon(frota.tipoVeiculo),
                color: Colors.white,
              ),
            ),
            title: Text(
              frota.nome,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: frota.ativo
                    ? null
                    : TextDecoration.lineThrough,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tipo: ${_getTipoVeiculoLabel(frota.tipoVeiculo)}'),
                if (frota.marca != null) Text('Marca: ${frota.marca}'),
                Text('Placa: ${frota.placa}'),
                if (frota.regional != null)
                  Text('Regional: ${frota.regional}'),
                if (frota.divisao != null)
                  Text('Divisão: ${frota.divisao}'),
                if (frota.segmento != null)
                  Text('Segmento: ${frota.segmento}'),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: frota.ativo ? Colors.green[100] : Colors.red[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        frota.ativo ? 'Ativo' : 'Inativo',
                        style: TextStyle(
                          fontSize: 11,
                          color: frota.ativo ? Colors.green[800] : Colors.red[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (frota.emManutencao) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Em Manutenção',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editFrota(frota),
                  tooltip: 'Editar',
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  color: Colors.orange,
                  onPressed: () => _duplicateFrota(frota),
                  tooltip: 'Duplicar',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteFrota(frota),
                  tooltip: 'Excluir',
                  color: Colors.red,
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (frota.observacoes != null && frota.observacoes!.isNotEmpty) ...[
                      const Text(
                        'Observações:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        frota.observacoes!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoItem(
                            icon: Icons.calendar_today,
                            label: 'Cadastrado em',
                            value: frota.createdAt != null
                                ? '${frota.createdAt!.day.toString().padLeft(2, '0')}/${frota.createdAt!.month.toString().padLeft(2, '0')}/${frota.createdAt!.year}'
                                : 'Não informado',
                          ),
                        ),
                        if (frota.updatedAt != null)
                          Expanded(
                            child: _buildInfoItem(
                              icon: Icons.update,
                              label: 'Atualizado em',
                              value: '${frota.updatedAt!.day.toString().padLeft(2, '0')}/${frota.updatedAt!.month.toString().padLeft(2, '0')}/${frota.updatedAt!.year}',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableView() {
    return Scrollbar(
      controller: _horizontalTableScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontalTableScrollController,
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
            columns: const [
              DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Nome', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Marca', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Placa', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Regional', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Divisão', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Segmento', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Manutenção', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _filteredFrotas.map((frota) {
              return DataRow(
                color: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) {
                    if (!frota.ativo) {
                      return Colors.grey[100];
                    }
                    return null;
                  },
                ),
                cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _editFrota(frota),
                          tooltip: 'Editar',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20, color: Colors.orange),
                          onPressed: () => _duplicateFrota(frota),
                          tooltip: 'Duplicar',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                          onPressed: () => _deleteFrota(frota),
                          tooltip: 'Excluir',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      frota.nome,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: frota.ativo ? Colors.black : Colors.grey,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      frota.marca ?? '-',
                      style: TextStyle(
                        color: frota.ativo ? Colors.black : Colors.grey,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      _getTipoVeiculoLabel(frota.tipoVeiculo),
                      style: TextStyle(
                        color: frota.ativo ? Colors.black : Colors.grey,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      frota.placa,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: frota.ativo ? Colors.black : Colors.grey,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      frota.regional ?? '-',
                      style: TextStyle(
                        color: frota.ativo ? Colors.black : Colors.grey,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      frota.divisao ?? '-',
                      style: TextStyle(
                        color: frota.ativo ? Colors.black : Colors.grey,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      frota.segmento ?? '-',
                      style: TextStyle(
                        color: frota.ativo ? Colors.black : Colors.grey,
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: frota.emManutencao ? Colors.orange[100] : Colors.green[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        frota.emManutencao ? 'Sim' : 'Não',
                        style: TextStyle(
                          fontSize: 12,
                          color: frota.emManutencao ? Colors.orange[800] : Colors.green[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: frota.ativo ? Colors.green[100] : Colors.red[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        frota.ativo ? 'Ativo' : 'Inativo',
                        style: TextStyle(
                          fontSize: 12,
                          color: frota.ativo ? Colors.green[800] : Colors.red[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  IconData _getTipoVeiculoIcon(String tipo) {
    switch (tipo) {
      case 'CARRO_LEVE':
      case 'PICKUP':
        return Icons.directions_car;
      case 'MUNCK':
        return Icons.local_shipping;
      case 'TRATOR':
        return Icons.agriculture;
      case 'CAMINHAO':
        return Icons.fire_truck;
      case 'VAN':
        return Icons.airport_shuttle;
      case 'MOTO':
        return Icons.two_wheeler;
      case 'ONIBUS':
        return Icons.directions_bus;
      default:
        return Icons.directions_car;
    }
  }
}
