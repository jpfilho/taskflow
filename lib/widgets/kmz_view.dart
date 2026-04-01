import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart' as xml;
import 'package:supabase_flutter/supabase_flutter.dart';

class KmzFeature {
  final String name;
  final String description;
  final List<LatLng> coordinates;
  final bool isLine;

  KmzFeature({
    required this.name,
    required this.description,
    required this.coordinates,
    required this.isLine,
  });
}

class KmzView extends StatefulWidget {
  const KmzView({super.key});

  @override
  State<KmzView> createState() => _KmzViewState();
}

class _KmzViewState extends State<KmzView> {
  bool _isLoading = false;
  String? _fileName;
  int _importados = 0;
  double _progress = 0;
  String _progressLabel = '';
  List<KmzFeature> _features = []; // mantém vazio após salvar
  List<Map<String, dynamic>> _regionais = [];
  List<Map<String, dynamic>> _divisoes = [];
  String? _regionalId;
  String? _divisaoId;

  @override
  void initState() {
    super.initState();
    _carregarRegionais();
  }

  Future<void> _carregarRegionais() async {
    try {
      final resp = await Supabase.instance.client
          .from('regionais')
          .select()
          .order('id', ascending: true)
          .limit(500);
      final list = (resp as List)
          .map<Map<String, dynamic>>((e) => {
                'id': e['id']?.toString(),
                'nome': _bestLabel(e),
              })
          .where((e) => (e['id'] as String?)?.isNotEmpty ?? false)
          .toList();
      setState(() {
        _regionais = list;
      });
      if (list.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhuma regional encontrada.'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      debugPrint('Erro ao carregar regionais: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar regionais: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
    }
  }

  Future<void> _carregarDivisoes(String regionalId) async {
    try {
      final resp = await Supabase.instance.client
          .from('divisoes')
          .select()
          .eq('regional_id', regionalId)
          .order('id', ascending: true)
          .limit(1000);
      final list = (resp as List)
          .map<Map<String, dynamic>>((e) => {
                'id': e['id']?.toString(),
                'nome': _bestLabel(e),
              })
          .where((e) => (e['id'] as String?)?.isNotEmpty ?? false)
          .toList();
      setState(() {
        _divisoes = list;
        _divisaoId = null;
      });
      if (list.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhuma divisão encontrada para a regional.'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      debugPrint('Erro ao carregar divisões: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar divisões: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
    }
  }

  String _bestLabel(Map<String, dynamic> row) {
    // Tenta chaves comuns; se não, usa primeiro valor string não vazio (exceto id/created_at/updated_at).
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

  Future<void> _pickAndParse() async {
    if (_regionalId == null || _divisaoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione a regional e a divisão antes de importar.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() {
      _isLoading = true;
      _progress = 0;
      _progressLabel = 'Lendo arquivo...';
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['kml', 'kmz'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }
      final file = result.files.first;
      Uint8List? bytes = file.bytes;
      if (bytes == null) throw Exception('Não foi possível ler o arquivo.');

      final ext = (file.extension ?? '').toLowerCase();
      await _salvarDireto(bytes, ext, file.name);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar KMZ/KML: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _salvarDireto(Uint8List bytes, String ext, String fileName) async {
    setState(() {
      _progress = 0;
      _progressLabel = 'Preparando arquivo...';
      _importados = 0;
    });

    try {
      if (ext == 'kmz') {
        final archive = ZipDecoder().decodeBytes(bytes);
        final kmlFile = archive.files.firstWhere(
          (f) => f.name.toLowerCase().endsWith('.kml'),
          orElse: () => ArchiveFile('', 0, null),
        );
        if (kmlFile.content == null) {
          throw Exception('KMZ sem KML interno.');
        }
        bytes = Uint8List.fromList(kmlFile.content as List<int>);
      }

      // Upload KMZ/KML
      final client = Supabase.instance.client;
      final bucket = 'kmz';
      final path = 'uploads/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final contentType = (ext == 'kml')
          ? 'application/vnd.google-earth.kml+xml'
          : 'application/vnd.google-earth.kmz';
      await client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );

      // cria kmz_arquivos
      final kmzRow = await client
          .from('kmz_arquivos')
          .insert({
            'nome': fileName,
            'storage_path': path,
            'regional_id': _regionalId,
            'divisao_id': _divisaoId,
          })
          .select('id')
          .single();
      final kmzId = kmzRow['id'] as String;
      // parse e insere em lotes
      final doc = xml.XmlDocument.parse(utf8.decode(bytes));
      final placemarks = doc.findAllElements('Placemark').toList();
      final total = placemarks.length;
      int processed = 0;
      List<Map<String, dynamic>> batch = [];

      Future<void> flushBatch() async {
        if (batch.isEmpty) return;
        await client.from('kmz_features').insert(batch);
        batch.clear();
      }

      for (final pm in placemarks) {
        final name = pm.getElement('name')?.text.trim() ?? 'Sem nome';
        final description = pm.getElement('description')?.text.trim() ?? '';
        final coordsEl = pm.findAllElements('coordinates').firstOrNull;
        if (coordsEl == null) continue;

        final coordText = coordsEl.text.trim();
        final parts = coordText
            .split(RegExp(r'\s+'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        final coords = <LatLng>[];
        for (final p in parts) {
          final c = _parseCoord(p);
          if (c != null) coords.add(c);
        }
        if (coords.isEmpty) continue;

        final isLine = pm.findElements('LineString').isNotEmpty ||
            pm.findElements('Polygon').isNotEmpty ||
            coords.length > 1;

        batch.add({
          'kmz_id': kmzId,
          'nome': name,
          'descricao': description,
          'is_line': isLine,
          'coords': coords.map((c) => {'lat': c.latitude, 'lng': c.longitude}).toList(),
        });

        processed++;
        _importados = processed;
        if (batch.length >= 200) {
          await flushBatch();
        }
        if (mounted && total > 0 && processed % 20 == 0) {
          setState(() {
            _progress = processed / total;
            _progressLabel = 'Processando $processed de $total';
          });
        }
      }
      await flushBatch();

      if (mounted) {
        setState(() {
          _fileName = fileName;
          _features = [];
          _isLoading = false;
          _progress = 1;
          _progressLabel = 'Importação concluída: $processed itens';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Importado e salvo: $processed itens'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao importar/salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  LatLng? _parseCoord(String raw) {
    // formato lon,lat[,alt]
    final parts = raw.split(',');
    if (parts.length < 2) return null;
    final lon = double.tryParse(parts[0]);
    final lat = double.tryParse(parts[1]);
    if (lat == null || lon == null) return null;
    return LatLng(lat, lon);
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];
    final polylines = <Polyline>[];

    for (final f in _features) {
      if (f.isLine && f.coordinates.length >= 2) {
        polylines.add(Polyline(
          points: f.coordinates,
          color: Colors.blue.withOpacity(0.7),
          strokeWidth: 4,
        ));
      } else if (f.coordinates.isNotEmpty) {
        markers.add(Marker(
          point: f.coordinates.first,
          width: 32,
          height: 32,
          child: const Icon(Icons.place, color: Colors.red, size: 28),
        ));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('KMZ / KML - Mapa'),
      ),
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
                    const Text('Dados do cadastro', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _regionalId,
                            decoration: const InputDecoration(
                              labelText: 'Regional',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: _regionais
                                .map((r) => DropdownMenuItem(
                                      value: r['id'] as String?,
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
                            hint: _regionais.isEmpty ? const Text('Carregando...') : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _divisaoId,
                            decoration: const InputDecoration(
                              labelText: 'Divisão',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: _divisoes
                                .map((d) => DropdownMenuItem(
                                      value: d['id'] as String?,
                                      child: Text(d['nome']?.toString() ?? ''),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                _divisaoId = val;
                              });
                            },
                            hint: (_divisoes.isEmpty && _regionalId != null)
                                ? const Text('Carregando...')
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _pickAndParse,
                          icon: const Icon(Icons.cloud_upload),
                          label: const Text('Importar e salvar no Supabase'),
                        ),
                        const SizedBox(width: 12),
                        if (_fileName != null) Text(_fileName!),
                        if (_isLoading)
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 180,
                                  child: LinearProgressIndicator(value: _progress > 0 && _progress <= 1 ? _progress : null),
                                ),
                                const SizedBox(height: 4),
                                Text(_progressLabel, style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        if (_importados > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text('Salvo: $_importados features'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_done),
                title: Text(_fileName == null ? 'Nenhum arquivo importado' : _fileName!),
                subtitle: Text(_importados > 0
                    ? 'Importado e salvo no Supabase ($_importados features)'
                    : 'Aguardando importação'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _XmlFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) return null;
    return first;
  }
}
