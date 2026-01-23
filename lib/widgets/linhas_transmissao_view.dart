import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LinhasTransmissaoView extends StatefulWidget {
  const LinhasTransmissaoView({super.key});

  @override
  State<LinhasTransmissaoView> createState() => _LinhasTransmissaoViewState();
}

class _LinhasTransmissaoViewState extends State<LinhasTransmissaoView> {
  bool _loading = false;
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _regionais = [];
  List<Map<String, dynamic>> _divisoes = [];
  String? _regionalId;
  String? _divisaoId;
  List<Map<String, dynamic>> _arquivos = [];
  List<Map<String, dynamic>> _features = [];
  String _baseMap = 'satellite';

  LatLng get _center {
    if (_features.isNotEmpty && _features.first['coords'] is List && (_features.first['coords'] as List).isNotEmpty) {
      final c = (_features.first['coords'] as List).first as LatLng;
      return c;
    }
    return const LatLng(-15.793889, -47.882778);
  }

  @override
  void initState() {
    super.initState();
    _carregarRegionais();
  }

  Future<void> _carregarRegionais() async {
    setState(() => _loading = true);
    try {
      final resp = await Supabase.instance.client.from('regionais').select().order('id');
      final list = (resp as List)
          .map<Map<String, dynamic>>((e) => {
                'id': e['id']?.toString(),
                'nome': _bestLabel(e),
              })
          .where((e) => (e['id'] as String?)?.isNotEmpty ?? false)
          .toList();
      String? firstId = list.isNotEmpty ? list.first['id']?.toString() : null;
      setState(() {
        _regionais = list;
        _regionalId = firstId;
      });
      if (firstId != null) {
        await _carregarDivisoes(firstId);
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar regionais: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _carregarDivisoes(String regionalId) async {
    setState(() => _loading = true);
    try {
      final resp = await Supabase.instance.client.from('divisoes').select().eq('regional_id', regionalId).order('id');
      final list = (resp as List)
          .map<Map<String, dynamic>>((e) => {
                'id': e['id']?.toString(),
                'nome': _bestLabel(e),
              })
          .where((e) => (e['id'] as String?)?.isNotEmpty ?? false)
          .toList();
      String? firstId = list.isNotEmpty ? list.first['id']?.toString() : null;
      setState(() {
        _divisoes = list;
        _divisaoId = firstId;
      });
      await _carregarArquivos();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar divisões: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _carregarArquivos() async {
    if (_regionalId == null || _divisaoId == null) return;
    setState(() => _loading = true);
    try {
      final resp = await Supabase.instance.client
          .from('kmz_arquivos')
          .select('id, nome')
          .eq('regional_id', _regionalId as Object)
          .eq('divisao_id', _divisaoId as Object)
          .order('id', ascending: false);
      final list = List<Map<String, dynamic>>.from(resp as List);
      final firstId = list.isNotEmpty ? list.first['id']?.toString() : null;
      setState(() {
        _arquivos = list;
      });
      if (firstId != null) {
        await _carregarFeatures(firstId);
      } else {
        setState(() {
          _features = [];
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar arquivos: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _carregarFeatures(String kmzId) async {
    setState(() => _loading = true);
    try {
      final resp = await Supabase.instance.client
          .from('kmz_features')
          .select('nome, descricao, is_line, coords')
          .eq('kmz_id', kmzId);
      final list = (resp as List)
          .map<Map<String, dynamic>>((e) {
            final coordsRaw = e['coords'] as List? ?? [];
            final coords = coordsRaw
                .map((c) => LatLng(
                      (c['lat'] as num).toDouble(),
                      (c['lng'] as num).toDouble(),
                    ))
                .toList();
            return {
              'nome': e['nome'] ?? '',
              'descricao': e['descricao'] ?? '',
              'is_line': e['is_line'] == true,
              'coords': coords,
            };
          })
          .where((m) => (m['coords'] as List).isNotEmpty)
          .toList();
      setState(() {
        _features = list;
        _loading = false;
      });
      _fitToFeatures();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar features: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _bestLabel(Map<String, dynamic> row) {
    const prefer = ['nome', 'regional', 'divisao', 'sigla', 'descricao', 'label', 'title'];
    for (final key in prefer) {
      if (row.containsKey(key)) {
        final v = row[key];
        if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
      }
    }
    for (final entry in row.entries) {
      final key = entry.key.toLowerCase();
      if (key == 'id' || key.contains('created') || key.contains('updated')) continue;
      final v = entry.value;
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    }
    return 'Sem nome';
  }

  void _fitToFeatures() {
    if (_features.isEmpty) return;
    final points = <LatLng>[];
    for (final f in _features) {
      points.addAll(f['coords'] as List<LatLng>);
    }
    if (points.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bounds = LatLngBounds.fromPoints(points);
      try {
        _mapController.fitBounds(
          bounds,
          options: const FitBoundsOptions(padding: EdgeInsets.all(32), maxZoom: 16),
        );
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];
    final polylines = <Polyline>[];
    final tileUrl = _baseMap == 'satellite'
        ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    final tileAttribution = _baseMap == 'satellite'
        ? 'Tiles © Esri — Source: Esri, Garmin, GEBCO, NOAA NGDC, and other contributors'
        : '© OpenStreetMap contributors';

    for (final f in _features) {
      final coords = f['coords'] as List<LatLng>;
      final isLine = f['is_line'] == true;
      if (isLine && coords.length >= 2) {
        polylines.add(Polyline(
          points: coords,
          color: Colors.blue.withOpacity(0.7),
          strokeWidth: 4,
        ));
      } else if (coords.isNotEmpty) {
        markers.add(Marker(
          point: coords.first,
          width: 32,
          height: 32,
          child: const Icon(Icons.place, color: Colors.red, size: 28),
        ));
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Linhas de Transmissão')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mapa dos arquivos KMZ/KML', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _regionalId,
                            decoration: const InputDecoration(
                              labelText: 'Regional',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: _regionais
                                .map((r) => DropdownMenuItem(
                                      value: r['id']?.toString(),
                                      child: Text(r['nome']?.toString() ?? ''),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                _regionalId = val;
                                _divisaoId = null;
                                _divisoes = [];
                              });
                              if (val != null) _carregarDivisoes(val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _divisaoId,
                            decoration: const InputDecoration(
                              labelText: 'Divisão',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: _divisoes
                                .map((d) => DropdownMenuItem(
                                      value: d['id']?.toString(),
                                      child: Text(d['nome']?.toString() ?? ''),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                _divisaoId = val;
                              });
                              _carregarArquivos();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _carregarArquivos,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Atualizar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Arquivos: ${_arquivos.length} • Features carregadas: ${_features.length}'),
                        const Spacer(),
                        DropdownButton<String>(
                          value: _baseMap,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: 'satellite', child: Text('Satélite')),
                            DropdownMenuItem(value: 'streets', child: Text('Mapa de ruas')),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _baseMap = v);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: 420,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : FlutterMap(
                        options: MapOptions(
                          initialCenter: _center,
                          initialZoom: 10,
                          interactionOptions: const InteractionOptions(flags: ~InteractiveFlag.rotate),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: tileUrl,
                            userAgentPackageName: 'com.taskflow.app',
                            tileProvider: CancellableNetworkTileProvider(),
                            maxZoom: 19,
                            minZoom: 2,
                            // attributionBuilder está disponível apenas em versões mais novas;
                            // exibimos a atribuição abaixo do mapa.
                          ),
                          if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
                          if (markers.isNotEmpty) MarkerLayer(markers: markers),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tileAttribution,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
