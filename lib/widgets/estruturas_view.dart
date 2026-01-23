import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/estrutura_service.dart';

class EstruturasView extends StatefulWidget {
  const EstruturasView({super.key});

  @override
  State<EstruturasView> createState() => _EstruturasViewState();
}

class _EstruturasViewState extends State<EstruturasView> {
  final _service = EstruturaService();
  bool _isImporting = false;
  String? _lastResult;
  List<String> _avisos = [];
  List<String> _erros = [];
  bool _isLoading = false;
  List<Map<String, dynamic>> _items = [];
  final _filtroLtController = TextEditingController();
  final _filtroEstruturaController = TextEditingController();
  final _filtroFamiliaController = TextEditingController();
  final _filtroTipoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _filtroLtController.dispose();
    _filtroEstruturaController.dispose();
    _filtroFamiliaController.dispose();
    _filtroTipoController.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final res = await _service.listarEstruturas(
        lt: _filtroLtController.text.trim(),
        estrutura: _filtroEstruturaController.text.trim(),
        familia: _filtroFamiliaController.text.trim(),
        tipo: _filtroTipoController.text.trim(),
      );
      setState(() {
        _items = res;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _importar() async {
    try {
      setState(() {
        _isImporting = true;
        _lastResult = null;
        _avisos = [];
        _erros = [];
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _isImporting = false);
        return;
      }
      final file = result.files.single;
      Uint8List? bytes;
      if (kIsWeb) {
        bytes = file.bytes;
      } else {
        if (file.path == null) throw Exception('Caminho do arquivo não disponível.');
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) throw Exception('Arquivo vazio.');

      final res = await _service.importarXlsx(bytes, file.name);
      setState(() {
        _isImporting = false;
        _lastResult =
            'Processadas: ${res.linhasProcessadas}, Upsertadas: ${res.registrosUpsertados}';
        _avisos = res.avisos;
        _erros = res.erros;
      });
      await _carregar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_lastResult ?? 'Importação concluída'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
        _erros = [e.toString()];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro na importação: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro de Estruturas')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _isImporting ? null : _importar,
                  icon: const Icon(Icons.cloud_upload),
                  label: Text(_isImporting ? 'Importando...' : 'Importar XLSX'),
                ),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _carregar,
                  icon: const Icon(Icons.refresh),
                  label: Text(_isLoading ? 'Carregando...' : 'Atualizar'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Filtros', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: _filtroLtController,
                            decoration: const InputDecoration(
                              labelText: 'LT',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _carregar(),
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: TextField(
                            controller: _filtroEstruturaController,
                            decoration: const InputDecoration(
                              labelText: 'Estrutura',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _carregar(),
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: TextField(
                            controller: _filtroFamiliaController,
                            decoration: const InputDecoration(
                              labelText: 'Família',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _carregar(),
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: TextField(
                            controller: _filtroTipoController,
                            decoration: const InputDecoration(
                              labelText: 'Tipo',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _carregar(),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _carregar,
                          icon: const Icon(Icons.search),
                          label: const Text('Aplicar filtros'),
                        ),
                        TextButton(
                          onPressed: () {
                            _filtroLtController.clear();
                            _filtroEstruturaController.clear();
                            _filtroFamiliaController.clear();
                            _filtroTipoController.clear();
                            _carregar();
                          },
                          child: const Text('Limpar'),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_lastResult != null)
              Text(
                _lastResult!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            if (_avisos.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Text('Avisos:', style: TextStyle(fontWeight: FontWeight.bold)),
              ..._avisos.map((a) => Text('- $a')),
            ],
            if (_erros.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Text('Erros:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              ..._erros.map((e) => Text('- $e', style: const TextStyle(color: Colors.red))),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _EstruturasTable(
                      items: _items,
                      onEdit: (item) async {
                        final updated = await showDialog<Map<String, dynamic>>(
                          context: context,
                          builder: (context) => _EditarEstruturaDialog(estrutura: item),
                        );
                        if (updated != null && updated.isNotEmpty) {
                          try {
                            await _service.atualizarEstrutura(item['id'] as String, updated);
                            await _carregar();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Estrutura atualizada'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erro ao salvar: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstruturasTable extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final Future<void> Function(Map<String, dynamic> item) onEdit;
  const _EstruturasTable({required this.items, required this.onEdit});

  String _fmt(dynamic v) => v == null ? '' : v.toString();
  String _fmtNum(dynamic v) {
    if (v == null) return '';
    if (v is num) return v.toStringAsFixed(2);
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('Nenhuma estrutura encontrada.');
    final cols = <Map<String, String>>[
      {'k': 'lt', 'l': 'LT'},
      {'k': 'estrutura', 'l': 'Estrutura'},
      {'k': 'familia', 'l': 'Família'},
      {'k': 'tipo', 'l': 'Tipo'},
      {'k': 'progressiva', 'l': 'Progressiva'},
      {'k': 'vao_m', 'l': 'Vão (m)'},
      {'k': 'altura_util_m', 'l': 'Altura Útil (m)'},
      {'k': 'deflexao', 'l': 'Deflexão'},
      {'k': 'equipe', 'l': 'Equipe'},
      {'k': 'geo_lat', 'l': 'Geo Lat'},
      {'k': 'geo_lon', 'l': 'Geo Lon'},
      {'k': 'numeracao_antiga', 'l': 'Numeração Antiga'},
    ];
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 12,
            headingRowHeight: 42,
            dataRowHeight: 42,
            columns: [
              const DataColumn(label: Text('Ações')),
              ...cols.map((c) => DataColumn(label: Text(c['l']!))),
            ],
            rows: items.map((row) {
              return DataRow(cells: cols.map((c) {
                final key = c['k']!;
                final val = row[key];
                if (key.endsWith('_m')) {
                  return DataCell(Text(_fmtNum(val)));
                }
                return DataCell(Text(_fmt(val)));
              }).toList()
                ..insert(
                  0,
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Editar',
                      onPressed: () => onEdit(row),
                    ),
                  ),
                ));
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _EditarEstruturaDialog extends StatefulWidget {
  final Map<String, dynamic> estrutura;
  const _EditarEstruturaDialog({required this.estrutura});

  @override
  State<_EditarEstruturaDialog> createState() => _EditarEstruturaDialogState();
}

class _EditarEstruturaDialogState extends State<_EditarEstruturaDialog> {
  late TextEditingController _lt;
  late TextEditingController _estrutura;
  late TextEditingController _familia;
  late TextEditingController _tipo;
  late TextEditingController _progressiva;
  late TextEditingController _vao;
  late TextEditingController _altura;
  late TextEditingController _deflexao;
  late TextEditingController _equipe;
  late TextEditingController _geoLat;
  late TextEditingController _geoLon;
  late TextEditingController _numAntiga;

  @override
  void initState() {
    super.initState();
    final e = widget.estrutura;
    _lt = TextEditingController(text: e['lt']?.toString() ?? '');
    _estrutura = TextEditingController(text: e['estrutura']?.toString() ?? '');
    _familia = TextEditingController(text: e['familia']?.toString() ?? '');
    _tipo = TextEditingController(text: e['tipo']?.toString() ?? '');
    _progressiva = TextEditingController(text: e['progressiva']?.toString() ?? '');
    _vao = TextEditingController(text: _numStr(e['vao_m']));
    _altura = TextEditingController(text: _numStr(e['altura_util_m']));
    _deflexao = TextEditingController(text: e['deflexao']?.toString() ?? '');
    _equipe = TextEditingController(text: e['equipe']?.toString() ?? '');
    _geoLat = TextEditingController(text: e['geo_lat']?.toString() ?? '');
    _geoLon = TextEditingController(text: e['geo_lon']?.toString() ?? '');
    _numAntiga = TextEditingController(text: e['numeracao_antiga']?.toString() ?? '');
  }

  String _numStr(dynamic v) {
    if (v == null) return '';
    if (v is num) return v.toString();
    return v.toString();
  }

  double? _toDouble(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  @override
  void dispose() {
    _lt.dispose();
    _estrutura.dispose();
    _familia.dispose();
    _tipo.dispose();
    _progressiva.dispose();
    _vao.dispose();
    _altura.dispose();
    _deflexao.dispose();
    _equipe.dispose();
    _geoLat.dispose();
    _geoLon.dispose();
    _numAntiga.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Estrutura'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_lt, 'LT'),
              _field(_estrutura, 'Estrutura'),
              _field(_familia, 'Família'),
              _field(_tipo, 'Tipo'),
              _field(_progressiva, 'Progressiva'),
              _field(_vao, 'Vão (m)', isNumber: true),
              _field(_altura, 'Altura Útil (m)', isNumber: true),
              _field(_deflexao, 'Deflexão'),
              _field(_equipe, 'Equipe'),
              _field(_geoLat, 'Geo Lat'),
              _field(_geoLon, 'Geo Lon'),
              _field(_numAntiga, 'Numeração Antiga'),
            ].map((w) => Padding(padding: const EdgeInsets.only(bottom: 8), child: w)).toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop({
              'lt': _lt.text.trim(),
              'estrutura': _estrutura.text.trim(),
              'familia': _familia.text.trim(),
              'tipo': _tipo.text.trim(),
              'progressiva': _progressiva.text.trim(),
              'vao_m': _toDouble(_vao.text),
              'altura_util_m': _toDouble(_altura.text),
              'deflexao': _deflexao.text.trim(),
              'equipe': _equipe.text.trim(),
              'geo_lat': _geoLat.text.trim(),
              'geo_lon': _geoLon.text.trim(),
              'numeracao_antiga': _numAntiga.text.trim(),
            });
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController c, String label, {bool isNumber = false}) {
    return TextField(
      controller: c,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
