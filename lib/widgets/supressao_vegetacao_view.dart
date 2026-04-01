// Não importar dart:io aqui: quebra Flutter Web. Leitura de arquivo via platform_file_io.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/supressao_vegetacao_service.dart';
import '../utils/platform_file_io.dart';
import '../utils/web_download.dart';

class SupressaoVegetacaoView extends StatefulWidget {
  const SupressaoVegetacaoView({super.key});

  @override
  State<SupressaoVegetacaoView> createState() => _SupressaoVegetacaoViewState();
}

class _SupressaoVegetacaoViewState extends State<SupressaoVegetacaoView> {
  final _formKey = GlobalKey<FormState>();
  final _linhaController = TextEditingController();
  final _tensaoController = TextEditingController();
  final _ufController = TextEditingController();
  final _concessionariaController = TextEditingController();
  String _selectedLinhaId = '';
  String? _selectedLinhaNome;

  final _service = SupressaoVegetacaoService();
  bool _isImporting = false;
  String? _lastResult;
  List<String> _avisos = [];
  List<String> _erros = [];
  bool _isLoadingTabela = false;
  List<Map<String, dynamic>> _vaos = [];
  List<Map<String, dynamic>> _linhas = [];
  List<String> _ltEstruturas = [];
  bool _loadingLinhas = true;
  int _selectedSection = 0; // 0 = Importar, 1 = Tabela
  String _selectedLinhaNomeTabela = '';
  int _currentPage = 0;
  final int _pageSize = 20;
  final ScrollController _tableVController = ScrollController();

  @override
  void dispose() {
    _tableVController.dispose();
    _linhaController.dispose();
    _tensaoController.dispose();
    _ufController.dispose();
    _concessionariaController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _carregarLinhas();
  }

  Future<void> _carregarLinhas() async {
    try {
      final linhas = await _service.listarLinhasTransmissao();
      final lts = await _service.listarLtEstruturasDistinct();
      setState(() {
        _linhas = linhas;
        _ltEstruturas = lts;
        _selectedLinhaId = '';
        _loadingLinhas = false;
      });
    } catch (e) {
      setState(() {
        _loadingLinhas = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar linhas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _carregarVaos() async {
    setState(() {
      _isLoadingTabela = true;
    });
    try {
      final dados = await _service.listarMapeamentoCompleto(
        ltNome: _selectedLinhaNomeTabela,
        limit: null, // sem limite para trazer todos da LT
      );
      setState(() {
        _vaos = dados;
        _isLoadingTabela = false;
        _currentPage = 0;
      });
    } catch (e) {
      setState(() {
        _isLoadingTabela = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar vãos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String? _nomeDaLinhaPorId(String? id) {
    if (id == null || id.isEmpty) return null;
    final match = _linhas.where((l) => l['id'] == id);
    if (match.isEmpty) return null;
    return match.first['nome'] as String?;
  }

  /// Exporta vãos para XLSX. Web: download via Blob URL (Safari/iOS compatível).
  /// Mobile/desktop: compartilha via share_plus (Salvar em arquivos / enviar).
  Future<void> _exportarXlsx() async {
    if (_vaos.isEmpty) return;
    const mime =
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    try {
      final bytes = await _service.exportarXlsx(_vaos);
      final linhaLabel = _selectedLinhaNomeTabela.trim().isEmpty
          ? 'todas'
          : _selectedLinhaNomeTabela
                .replaceAll(RegExp(r'[^\w\s-]'), '_')
                .replaceAll(RegExp(r'\s+'), '_');
      final filename =
          'supressao_vegetacao_${linhaLabel}_${DateTime.now().millisecondsSinceEpoch}.xlsx';

      if (kDebugMode) {
        // ignore: avoid_print
        print('Exportar XLSX: $filename, ${bytes.length} bytes');
      }

      if (kIsWeb) {
        try {
          downloadBytesWeb(bytes, filename, mime);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Exportado: $filename (${bytes.length} bytes)'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (kDebugMode) {
            // ignore: avoid_print
            print('downloadBytesWeb falhou: $e');
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Falha no download. Tente outro navegador ou salve pelo menu do navegador.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        try {
          final xFile = XFile.fromData(bytes, name: filename, mimeType: mime);
          await Share.shareXFiles([
            xFile,
          ], text: 'Supressão de vegetação - $linhaLabel');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Compartilhar: $filename (${bytes.length} bytes)',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Exportação indisponível neste dispositivo. Use a versão web para baixar o arquivo.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Erro ao exportar XLSX: $e\n$st');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erro ao exportar: ${e.toString().length > 80 ? 'falha ao gerar planilha.' : e}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importarDaTabela() async {
    try {
      setState(() {
        _isLoadingTabela = true;
      });

      // withData: true para Web / desktop funcionar perfeitamente
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _isLoadingTabela = false;
        });
        return;
      }

      final file = result.files.single;
      final bytes = await readFileBytes(file);
      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _isLoadingTabela = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Arquivo vazio ou não foi possível ler. Tente novamente.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final res = await _service.importarXlsx(
        bytes: bytes,
        filename: file.name,
        linhaNome:
            _selectedLinhaNomeTabela, // Pode ser vazio se for 'Todas as linhas', o DB agora pega do Excel
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Importação concluída: ${res.linhasProcessadas} linhas lidas, ${res.registrosUpsertados} registros atualizados.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Recarrega a view
      await _carregarLinhas();
      await _carregarVaos();
    } catch (e) {
      setState(() {
        _isLoadingTabela = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro na importação: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importar() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() {
        _isImporting = true;
        _lastResult = null;
        _avisos = [];
        _erros = [];
      });

      // withData: true para ter PlatformFile.bytes em todas as plataformas (evita dart:io na view).
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _isImporting = false;
        });
        return;
      }

      final file = result.files.single;
      final bytes = await readFileBytes(file);
      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _isImporting = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Arquivo vazio ou não foi possível ler. Tente novamente com withData.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final res = await _service.importarXlsx(
        bytes: bytes,
        filename: file.name,
        linhaNome: _selectedLinhaNome ?? _linhaController.text.trim(),
        tensaoKv: _tensaoController.text.trim().isEmpty
            ? null
            : _tensaoController.text.trim(),
        uf: _ufController.text.trim().isEmpty
            ? null
            : _ufController.text.trim(),
        concessionaria: _concessionariaController.text.trim().isEmpty
            ? null
            : _concessionariaController.text.trim(),
      );

      setState(() {
        _isImporting = false;
        _lastResult =
            'Processadas: ${res.linhasProcessadas}, Upsertadas: ${res.registrosUpsertados}';
        _avisos = res.avisos;
        _erros = res.erros;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_lastResult ?? 'Importação finalizada.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
        _erros = [e.toString()];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro na importação: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Supressão de Vegetação')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Importar'),
                    selected: _selectedSection == 0,
                    onSelected: (_) => setState(() => _selectedSection = 0),
                  ),
                  ChoiceChip(
                    label: const Text('Tabela'),
                    selected: _selectedSection == 1,
                    onSelected: (_) => setState(() => _selectedSection = 1),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_selectedSection == 0)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.upload_file, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Importar mapeamento (XLSX)',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _loadingLinhas
                            ? const LinearProgressIndicator()
                            : DropdownButtonFormField<String>(
                                initialValue: _selectedLinhaId.isEmpty
                                    ? null
                                    : _selectedLinhaId,
                                decoration: const InputDecoration(
                                  labelText: 'Linha de Transmissão *',
                                  border: OutlineInputBorder(),
                                ),
                                items: _linhas
                                    .map(
                                      (linha) => DropdownMenuItem<String>(
                                        value: linha['id'] as String,
                                        child: Text(
                                          linha['nome'] as String? ?? '',
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedLinhaId = val ?? '';
                                    _selectedLinhaNome = _nomeDaLinhaPorId(val);
                                  });
                                },
                                validator: (v) {
                                  if ((_selectedLinhaId.isEmpty) &&
                                      (_linhaController.text.trim().isEmpty)) {
                                    return 'Selecione ou informe o nome da linha';
                                  }
                                  return null;
                                },
                              ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _linhaController,
                          decoration: const InputDecoration(
                            labelText: 'Nome da Linha (customizar, opcional)',
                            border: OutlineInputBorder(),
                          ),
                          validator: (_) {
                            if ((_selectedLinhaId.isEmpty) &&
                                (_linhaController.text.trim().isEmpty)) {
                              return 'Selecione ou informe o nome da linha';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _tensaoController,
                                decoration: const InputDecoration(
                                  labelText: 'Tensão (kV) opcional',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _ufController,
                                decoration: const InputDecoration(
                                  labelText: 'UF (opcional)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _concessionariaController,
                                decoration: const InputDecoration(
                                  labelText: 'Concessionária (opcional)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _isImporting ? null : _importar,
                          icon: const Icon(Icons.cloud_upload),
                          label: Text(
                            _isImporting
                                ? 'Importando...'
                                : 'Selecionar e importar XLSX',
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_lastResult != null) ...[
                          Text(
                            _lastResult!,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                        if (_avisos.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Avisos:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          ..._avisos.map((a) => Text('- $a')),
                        ],
                        if (_erros.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Erros:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          ..._erros.map(
                            (e) => Text(
                              '- $e',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.table_chart, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Vãos importados (todos da linha)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed: _isLoadingTabela
                                      ? null
                                      : _carregarVaos,
                                  icon: const Icon(Icons.refresh),
                                  label: Text(
                                    _isLoadingTabela
                                        ? 'Carregando...'
                                        : 'Atualizar',
                                  ),
                                ),
                                FilledButton.icon(
                                  onPressed: _isLoadingTabela
                                      ? null
                                      : _importarDaTabela,
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text('Importar XLSX'),
                                ),
                                FilledButton.icon(
                                  onPressed: (_vaos.isEmpty || _isLoadingTabela)
                                      ? null
                                      : _exportarXlsx,
                                  icon: const Icon(Icons.download),
                                  label: const Text('Exportar XLSX'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _loadingLinhas
                            ? const LinearProgressIndicator()
                            : Builder(
                                builder: (context) {
                                  final Set<String> opts = {
                                    '',
                                    ..._linhas.map(
                                      (l) =>
                                          (l['nome'] as String?)?.trim() ?? '',
                                    ),
                                    ..._ltEstruturas.map((lt) => lt.trim()),
                                  };
                                  final linhaOptions =
                                      opts
                                          .where((e) => e.isNotEmpty || e == '')
                                          .toList()
                                        ..sort();
                                  final dropdownValue =
                                      linhaOptions.contains(
                                        _selectedLinhaNomeTabela,
                                      )
                                      ? _selectedLinhaNomeTabela
                                      : '';
                                  return DropdownButtonFormField<String>(
                                    initialValue: dropdownValue,
                                    decoration: const InputDecoration(
                                      labelText: 'Filtrar por linha',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    items: linhaOptions
                                        .map(
                                          (opt) => DropdownMenuItem<String>(
                                            value: opt,
                                            child: Text(
                                              opt.isEmpty
                                                  ? 'Todas as linhas'
                                                  : opt,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedLinhaNomeTabela = val ?? '';
                                      });
                                      _carregarVaos();
                                    },
                                  );
                                },
                              ),
                        const SizedBox(height: 12),
                        if (_isLoadingTabela)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else
                          _VaosTable(
                            vaos: _vaos,
                            pageSize: _pageSize,
                            currentPage: _currentPage,
                            onPageChanged: (p) =>
                                setState(() => _currentPage = p),
                            vController: _tableVController,
                            onEdit: (vao) async {
                              final updated =
                                  await showDialog<Map<String, dynamic>>(
                                    context: context,
                                    builder: (context) =>
                                        _EditarVaoDialog(vao: vao),
                                  );
                              if (updated != null && updated.isNotEmpty) {
                                try {
                                  final vaoId = vao['vao_id'] as String?;
                                  if (vaoId != null) {
                                    await _service.atualizarVao(vaoId, updated);
                                  } else {
                                    final ltNome =
                                        ((vao['lt'] as String?) ??
                                                _selectedLinhaNomeTabela)
                                            .trim();
                                    final est =
                                        (((updated['est_codigo'] as String?) ??
                                                (vao['est_codigo']
                                                    as String?) ??
                                                ''))
                                            .trim();
                                    if (ltNome.isEmpty || est.isEmpty) {
                                      throw Exception(
                                        'Não foi possível localizar linha ou est_codigo para criar o mapeamento.',
                                      );
                                    }
                                    final linhaId = await _service
                                        .obterOuCriarLinhaPorNome(nome: ltNome);
                                    await _service.upsertVaoComLinha(
                                      linhaId: linhaId,
                                      estCodigo: est,
                                      dados: updated,
                                    );
                                  }
                                  await _carregarVaos();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Vão atualizado com sucesso',
                                        ),
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
                            onQuickEdit: (vao, field, value) async {
                              final vaoId = vao['vao_id'] as String?;
                              final ltNome =
                                  ((vao['linhas_transmissao']?['nome']
                                              as String?) ??
                                          (vao['lt'] as String?) ??
                                          _selectedLinhaNomeTabela)
                                      .trim();
                              final est =
                                  (vao['est_codigo'] as String?)?.trim() ?? '';
                              if (ltNome.isEmpty || est.isEmpty) return;
                              try {
                                if (vaoId != null) {
                                  await _service.atualizarVao(vaoId, {
                                    field: value,
                                  });
                                } else {
                                  final linhaId = await _service
                                      .obterOuCriarLinhaPorNome(nome: ltNome);
                                  await _service.upsertVaoComLinha(
                                    linhaId: linhaId,
                                    estCodigo: est,
                                    dados: {field: value},
                                  );
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Campo atualizado'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Erro ao atualizar: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            onView: (vao) {
                              showDialog(
                                context: context,
                                builder: (context) => _VerVaoDialog(vao: vao),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VaosTable extends StatefulWidget {
  final List<Map<String, dynamic>> vaos;
  final int pageSize;
  final int currentPage;
  final void Function(int page) onPageChanged;
  final ScrollController vController;
  final Future<void> Function(Map<String, dynamic> vao) onEdit;
  final void Function(Map<String, dynamic> vao) onView;
  final Future<void> Function(
    Map<String, dynamic> vao,
    String field,
    dynamic value,
  )?
  onQuickEdit;
  const _VaosTable({
    required this.vaos,
    required this.pageSize,
    required this.currentPage,
    required this.onPageChanged,
    required this.vController,
    required this.onEdit,
    required this.onView,
    this.onQuickEdit,
  });

  @override
  State<_VaosTable> createState() => _VaosTableState();
}

class _VaosTableState extends State<_VaosTable> {
  final ScrollController _leftV = ScrollController();
  final ScrollController _rightV = ScrollController();
  final ScrollController _horizontalScroll = ScrollController();
  final TextEditingController _inlineController = TextEditingController();
  // Visibilidade dos grupos de colunas (cabeçalho único com 2+ colunas)
  bool _mapMecVisible = true;
  bool _mapManVisible = true;
  bool _execMecVisible = true;
  bool _execManVisible = true;
  bool _execucaoMecVisible = true;
  bool _execucaoManVisible = true;

  /// Bloco fixo (VÃO): 110/140/80/90/90; área rolável 60% (90 por coluna).
  static const double _widthRight = 90.0;
  static final Map<String, double> _colWidths = {
    '__actions__': 110.0,
    'linhas_transmissao.nome': 140.0,
    'est_codigo': 80.0,
    'vao_frente_m': 90.0,
    'vao_largura_m': 90.0,
  };
  double _colWidth(String key) => _colWidths[key] ?? _widthRight;

  /// Fonte menor nas células de data para caber na coluna
  static const double _dateCellFontSize = 10.0;

  /// Altura fixa das linhas do body para evitar células com tamanhos diferentes
  static const double bodyRowHeight = 52.0;

  final Set<String> _editableKeys = {
    'est_codigo',
    'vao_frente_m',
    'vao_largura_m',
    'map_mec_extensao_m',
    'map_mec_largura_m',
    'map_data',
    'map_man_extensao_m',
    'map_man_largura_m',
    'exec_mec_extensao_m',
    'exec_mec_largura_m',
    'exec_mec_data',
    'execucao_mec_data_inicio',
    'execucao_mec_data_fim',
    'execucao_man_data_inicio',
    'execucao_man_data_fim',
    'exec_man_extensao_m',
    'exec_man_largura_m',
    'exec_man_data',
    'vao_data_conclusao',
    'numeracao_ggt',
    'mapeamento_ggt',
    'codigo_ggt_execucao',
    'descricao_servicos',
    'prioridade',
    'conferencia_vao',
    'pend_manual',
    'pend_mecanizado',
    'pend_seletivo',
    'pend_manual_extra',
    'pend_mecanizado_extra',
    'pend_seletivo_extra',
    'pendencias_execucao',
  };
  String? _editingRowKey;
  String? _editingField;

  String _rowKey(Map<String, dynamic> row) {
    final id = row['vao_id']?.toString();
    if (id != null && id.isNotEmpty) return id;
    final lt = (row['linhas_transmissao']?['nome'] ?? row['lt'] ?? '')
        .toString();
    final est = (row['est_codigo'] ?? '').toString();
    return '$lt::$est';
  }

  @override
  void initState() {
    super.initState();
    _leftV.addListener(_syncRight);
    _rightV.addListener(_syncLeft);
  }

  void _syncRight() {
    if (_rightV.hasClients && _rightV.offset != _leftV.offset) {
      _rightV.jumpTo(_leftV.offset);
    }
  }

  void _syncLeft() {
    if (_leftV.hasClients && _leftV.offset != _rightV.offset) {
      _leftV.jumpTo(_rightV.offset);
    }
  }

  @override
  void dispose() {
    _leftV.removeListener(_syncRight);
    _rightV.removeListener(_syncLeft);
    _leftV.dispose();
    _rightV.dispose();
    _horizontalScroll.dispose();
    _inlineController.dispose();
    super.dispose();
  }

  Widget _buildCellForColumn(
    Map<String, String> c,
    Map<String, dynamic> row,
    String linhaNome,
  ) {
    final key = c['key']!;
    final w = _colWidth(key);
    dynamic val = key == 'linhas_transmissao.nome' ? linhaNome : row[key];
    final label = c['label'] ?? key;
    final isDate = key.contains('_data') || key.contains('conclusao');
    final isNumber = key.contains('_m');

    final bool isMapeamentoField = [
      'map_mec_extensao_m',
      'map_mec_largura_m',
      'map_man_extensao_m',
      'map_man_largura_m',
      'map_data',
    ].contains(key);

    // Regra adicional: se é coluna de Execução Mecanizada, esmaecer caso não tenha Mapeamento Mecanizado
    final bool isExecucaoMecField = [
      'execucao_mec_data_inicio',
      'execucao_mec_data_fim',
      'exec_mec_extensao_m',
      'exec_mec_largura_m',
      'exec_mec_data',
    ].contains(key);
    final bool hasMapMec =
        row['map_mec_extensao_m'] != null &&
        row['map_mec_extensao_m'].toString().trim().isNotEmpty;

    // Regra adicional: se é coluna de Execução Manual, esmaecer caso não tenha Mapeamento Manual
    final bool isExecucaoManField = [
      'execucao_man_data_inicio',
      'execucao_man_data_fim',
      'exec_man_extensao_m',
      'exec_man_largura_m',
      'exec_man_data',
    ].contains(key);
    final bool hasMapMan =
        row['map_man_extensao_m'] != null &&
        row['map_man_extensao_m'].toString().trim().isNotEmpty;

    final bool appliesEsmaecerSeVazio = isMapeamentoField;
    final bool appliesEsmaecerSempre =
        (isExecucaoMecField && !hasMapMec) ||
        (isExecucaoManField && !hasMapMan);

    if (key == 'roco_concluido') {
      return _cell(val == true ? 'Sim' : 'Não', w, height: bodyRowHeight);
    }
    if (widget.onQuickEdit != null && _editableKeys.contains(key)) {
      return _editableCell(
        row: row,
        key: key,
        label: label,
        width: w,
        isNumber: isNumber,
        isDate: isDate,
        esmaecerSeVazio: appliesEsmaecerSeVazio,
        esmaecerSempre: appliesEsmaecerSempre,
      );
    }
    if (isDate) {
      return _cell(
        _fmtDate(val),
        w,
        height: bodyRowHeight,
        fontSize: _dateCellFontSize,
        esmaecerSeVazio: appliesEsmaecerSeVazio,
        esmaecerSempre: appliesEsmaecerSempre,
      );
    }
    if (isNumber) {
      return _cell(
        _fmtNum(val),
        w,
        height: bodyRowHeight,
        esmaecerSeVazio: appliesEsmaecerSeVazio,
        esmaecerSempre: appliesEsmaecerSempre,
      );
    }
    return _cell(
      _fmt(val),
      w,
      height: bodyRowHeight,
      esmaecerSeVazio: appliesEsmaecerSeVazio,
      esmaecerSempre: appliesEsmaecerSempre,
    );
  }

  void _startInlineEdit(
    Map<String, dynamic> row,
    String key,
    String displayValue,
  ) {
    if (widget.onQuickEdit == null) return;
    setState(() {
      _editingRowKey = _rowKey(row);
      _editingField = key;
      _inlineController.text = displayValue;
    });
  }

  Future<void> _startDateEdit(Map<String, dynamic> row, String key) async {
    if (widget.onQuickEdit == null) return;
    final current = row[key];
    DateTime? initial = current is DateTime
        ? current
        : DateTime.tryParse(current?.toString() ?? '');
    initial ??= DateTime.now();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) {
      await _submitInlineEditWithValue(
        row,
        key,
        picked.toIso8601String().split('T').first,
      );
    }
  }

  Future<void> _submitInlineEditWithValue(
    Map<String, dynamic> row,
    String key,
    dynamic newValue,
  ) async {
    if (widget.onQuickEdit == null) return;
    try {
      row[key] = newValue;
      await widget.onQuickEdit!(row, key, newValue);
    } finally {
      if (mounted) {
        setState(() {
          _editingRowKey = null;
          _editingField = null;
          _inlineController.clear();
        });
      }
    }
  }

  Future<void> _submitInlineEdit(Map<String, dynamic> row, String key) async {
    if (widget.onQuickEdit == null) return;
    final original = row[key];
    var input = _inlineController.text.trim();
    dynamic newValue = input;
    if (original is num) {
      final parsed = double.tryParse(input.replaceAll(',', '.'));
      if (parsed != null) newValue = parsed;
    }
    try {
      row[key] = newValue;
      await widget.onQuickEdit!(row, key, newValue);
    } finally {
      if (mounted) {
        setState(() {
          _editingRowKey = null;
          _editingField = null;
          _inlineController.clear();
        });
      }
    }
  }

  String _fmt(dynamic v) => v == null ? '' : v.toString();
  String _fmtNum(dynamic v) {
    if (v == null) return '';
    if (v is num) return v.round().toString();
    return v.toString();
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '';
    final dt = v is DateTime ? v : DateTime.tryParse(v.toString());
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Widget _cell(
    String text,
    double width, {
    FontWeight? fontWeight,
    bool isHeader = false,
    Color? background,
    double? height,
    double? fontSize,
    bool esmaecerSeVazio = false,
    bool esmaecerSempre = false,
  }) {
    final bool isEmpty = text.trim().isEmpty;
    final bg =
        background ??
        (isHeader || esmaecerSempre || (isEmpty && esmaecerSeVazio)
            ? Colors.grey.shade100
            : Colors.white);
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: fontWeight, fontSize: fontSize),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _editableCell({
    required Map<String, dynamic> row,
    required String key,
    required String label,
    required double width,
    bool isNumber = false,
    bool isDate = false,
    bool esmaecerSeVazio = false,
    bool esmaecerSempre = false,
  }) {
    final rowKey = _rowKey(row);
    final isEditing = _editingRowKey == rowKey && _editingField == key;
    final displayText = isDate
        ? _fmtDate(row[key])
        : isNumber
        ? _fmtNum(row[key])
        : _fmt(row[key]);

    if (isDate) {
      return GestureDetector(
        onTap: (widget.onQuickEdit != null && _editableKeys.contains(key))
            ? () => _startDateEdit(row, key)
            : null,
        child: _cell(
          displayText,
          width,
          height: bodyRowHeight,
          fontSize: _dateCellFontSize,
          esmaecerSeVazio: esmaecerSeVazio,
          esmaecerSempre: esmaecerSempre,
        ),
      );
    }

    if (!isEditing) {
      return GestureDetector(
        onTap: (widget.onQuickEdit != null && _editableKeys.contains(key))
            ? () => _startInlineEdit(row, key, displayText)
            : null,
        child: _cell(
          displayText,
          width,
          height: bodyRowHeight,
          esmaecerSeVazio: esmaecerSeVazio,
          esmaecerSempre: esmaecerSempre,
        ),
      );
    }

    return Container(
      width: width,
      height: bodyRowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.blue.shade200, width: 1.5),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: _inlineController,
        autofocus: true,
        textAlign: TextAlign.center,
        onSubmitted: (_) => _submitInlineEdit(row, key),
        onEditingComplete: () => _submitInlineEdit(row, key),
        decoration: InputDecoration(
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double headerGroupHeight = 36;
    const double headerCellHeight = 44;
    const double headerRow3FontSize = 11;
    if (widget.vaos.isEmpty) {
      return const Text('Nenhum vão encontrado.');
    }
    final start = widget.currentPage * widget.pageSize;
    final end = (start + widget.pageSize) > widget.vaos.length
        ? widget.vaos.length
        : (start + widget.pageSize);
    final pageItems = widget.vaos.sublist(start, end);
    final double bodyHeight = pageItems.length * bodyRowHeight;

    final cols = <Map<String, String>>[
      {'key': 'linhas_transmissao.nome', 'label': 'Linha'},
      {'key': 'est_codigo', 'label': 'EST.'},
      {'key': 'vao_frente_m', 'label': 'Extensão'},
      {'key': 'vao_largura_m', 'label': 'Largura'},
      {'key': 'map_mec_extensao_m', 'label': 'Extensão'},
      {'key': 'map_mec_largura_m', 'label': 'Largura'},
      {'key': 'map_man_extensao_m', 'label': 'Extensão'},
      {'key': 'map_man_largura_m', 'label': 'Largura'},
      {'key': 'map_data', 'label': 'Data'},
      {'key': 'execucao_mec_data_inicio', 'label': 'Data Início'},
      {'key': 'execucao_mec_data_fim', 'label': 'Data Fim'},
      {'key': 'execucao_man_data_inicio', 'label': 'Data Início'},
      {'key': 'execucao_man_data_fim', 'label': 'Data Fim'},
      {'key': 'exec_mec_extensao_m', 'label': 'Extensão'},
      {'key': 'exec_mec_largura_m', 'label': 'Largura'},
      {'key': 'exec_mec_data', 'label': 'Data'},
      {'key': 'exec_man_extensao_m', 'label': 'Extensão'},
      {'key': 'exec_man_largura_m', 'label': 'Largura'},
      {'key': 'exec_man_data', 'label': 'Data'},
      {'key': 'vao_data_conclusao', 'label': 'Conclusão Vão'},
      {'key': 'roco_concluido', 'label': 'Roço Concluído'},
      {'key': 'numeracao_ggt', 'label': 'Numeração GGT'},
      {'key': 'mapeamento_ggt', 'label': 'Mapeamento GGT'},
      {'key': 'codigo_ggt_execucao', 'label': 'Código GGT Execução'},
      {'key': 'descricao_servicos', 'label': 'Descrição Serviços'},
      {'key': 'prioridade', 'label': 'Prioridade'},
      {'key': 'conferencia_vao', 'label': 'Conf. Vão'},
      {'key': 'pend_manual', 'label': 'Pend. Manual'},
      {'key': 'pend_mecanizado', 'label': 'Pend. Mecanizado'},
      {'key': 'pend_seletivo', 'label': 'Pend. Seletivo'},
      {'key': 'pend_manual_extra', 'label': 'Pend. Manual Extra'},
      {'key': 'pend_mecanizado_extra', 'label': 'Pend. Mecanizado Extra'},
      {'key': 'pend_seletivo_extra', 'label': 'Pend. Seletivo Extra'},
      {'key': 'pendencias_execucao', 'label': 'Pendências Execução'},
    ];

    final dynamicCols = cols
        .where(
          (c) => ![
            'linhas_transmissao.nome',
            'est_codigo',
            'vao_frente_m',
            'vao_largura_m',
          ].contains(c['key']),
        )
        .toList();

    final fixedCols = <Map<String, dynamic>>[
      {
        'key': '__actions__',
        'label': 'Ações',
        'width': _colWidth('__actions__'),
      },
      {
        'key': 'linhas_transmissao.nome',
        'label': 'Linha',
        'width': _colWidth('linhas_transmissao.nome'),
      },
      {'key': 'est_codigo', 'label': 'EST.', 'width': _colWidth('est_codigo')},
      {
        'key': 'vao_frente_m',
        'label': 'Extensão',
        'width': _colWidth('vao_frente_m'),
      },
      {
        'key': 'vao_largura_m',
        'label': 'Largura',
        'width': _colWidth('vao_largura_m'),
      },
    ];

    // Colunas visíveis conforme toggles dos grupos (Mapeamento Mec/Man, Execução Mec/Man)
    final mapMecKeys = ['map_mec_extensao_m', 'map_mec_largura_m'];
    final mapManKeys = ['map_man_extensao_m', 'map_man_largura_m'];
    const mapDataKey = 'map_data';
    final execucaoMecKeys = [
      'execucao_mec_data_inicio',
      'execucao_mec_data_fim',
    ];
    final execucaoManKeys = [
      'execucao_man_data_inicio',
      'execucao_man_data_fim',
    ];
    final execMecKeys = [
      'exec_mec_extensao_m',
      'exec_mec_largura_m',
      'exec_mec_data',
    ];
    final execManKeys = [
      'exec_man_extensao_m',
      'exec_man_largura_m',
      'exec_man_data',
    ];
    const double iconGroupWidth = 31.0;
    final totalMapeamentoW =
        (_mapMecVisible
            ? mapMecKeys.fold<double>(0, (s, k) => s + _colWidth(k))
            : iconGroupWidth) +
        (_mapManVisible
            ? mapManKeys.fold<double>(0, (s, k) => s + _colWidth(k))
            : iconGroupWidth) +
        _colWidth(mapDataKey);
    final totalExecucaoMidW =
        (_execucaoMecVisible
            ? execucaoMecKeys.fold<double>(0, (s, k) => s + _colWidth(k))
            : iconGroupWidth) +
        (_execucaoManVisible
            ? execucaoManKeys.fold<double>(0, (s, k) => s + _colWidth(k))
            : iconGroupWidth);

    Widget buildFixedHeader() {
      final totalWidth = fixedCols.fold<double>(
        0,
        (sum, c) => sum + (c['width'] as double),
      );
      final rowLabels = Row(
        children: fixedCols
            .map(
              (c) => _cell(
                c['label'] as String,
                c['width'] as double,
                fontWeight: FontWeight.bold,
                isHeader: true,
                height: headerCellHeight,
                fontSize: headerRow3FontSize,
              ),
            )
            .toList(),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha 1: mesclado "Lista de Estruturas"
          Container(
            width: totalWidth,
            alignment: Alignment.center,
            height: headerGroupHeight,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: const Text(
              'Lista de Estruturas',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          // Linha 2: mesclado "VÃO"
          Container(
            width: totalWidth,
            alignment: Alignment.center,
            height: headerGroupHeight,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: const Text(
              'VÃO',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          rowLabels,
        ],
      );
    }

    Widget buildRightHeader() {
      // Cabeçalhos agrupados com ícone de visibilidade (mostrar/ocultar as colunas do grupo)
      const double iconGroupWidth = 31.0;

      final headerRow0 =
          <
            Widget
          >[]; // Nova linha acima: mesmos mesclados, mesmo conteúdo (só texto)
      final headerRow1 = <Widget>[];
      final headerRow2 = <Widget>[];

      Widget simpleGroupCell(String label, double width) {
        return Container(
          width: width,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          height: headerGroupHeight,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        );
      }

      Widget groupHeaderCell({
        required String label,
        required bool visible,
        required VoidCallback onToggle,
        required double totalWidth,
      }) {
        return Container(
          width: visible ? totalWidth : iconGroupWidth,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          height: headerGroupHeight,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (visible)
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Icon(
                  visible ? Icons.visibility : Icons.visibility_off,
                  size: 20,
                ),
                tooltip: visible ? 'Ocultar colunas' : 'Mostrar colunas',
                onPressed: onToggle,
              ),
            ],
          ),
        );
      }

      final totalExecucaoW =
          (_execMecVisible
              ? execMecKeys.fold<double>(0, (s, k) => s + _colWidth(k))
              : iconGroupWidth) +
          (_execManVisible
              ? execManKeys.fold<double>(0, (s, k) => s + _colWidth(k))
              : iconGroupWidth);
      var headerRow0MapeamentoAdded = false;
      var headerRow0ExecucaoMidAdded = false;
      var headerRow0ExecucaoAdded = false;

      for (final c in dynamicCols) {
        final key = c['key']!;
        if (mapMecKeys.contains(key)) {
          if (!headerRow1.any(
            (w) => (w.key as ValueKey?)?.value == 'map-mec-span',
          )) {
            final totalW = mapMecKeys.fold<double>(
              0,
              (s, k) => s + _colWidth(k),
            );
            if (!headerRow0MapeamentoAdded) {
              headerRow0.add(simpleGroupCell('Mapeamento', totalMapeamentoW));
              headerRow0MapeamentoAdded = true;
            }
            headerRow1.add(
              KeyedSubtree(
                key: const ValueKey('map-mec-span'),
                child: groupHeaderCell(
                  label: 'Mecanizado',
                  visible: _mapMecVisible,
                  onToggle: () =>
                      setState(() => _mapMecVisible = !_mapMecVisible),
                  totalWidth: totalW,
                ),
              ),
            );
          }
          if (_mapMecVisible) {
            headerRow2.add(
              _cell(
                c['label']!,
                _colWidth(key),
                fontWeight: FontWeight.bold,
                isHeader: true,
                height: headerCellHeight,
                fontSize: headerRow3FontSize,
              ),
            );
          } else if (key == mapMecKeys.first) {
            headerRow2.add(
              _cell(
                '',
                iconGroupWidth,
                isHeader: true,
                height: headerCellHeight,
                fontSize: headerRow3FontSize,
              ),
            );
          }
        } else if (mapManKeys.contains(key)) {
          if (!headerRow1.any(
            (w) => (w.key as ValueKey?)?.value == 'map-man-span',
          )) {
            final totalW = mapManKeys.fold<double>(
              0,
              (s, k) => s + _colWidth(k),
            );
            headerRow1.add(
              KeyedSubtree(
                key: const ValueKey('map-man-span'),
                child: groupHeaderCell(
                  label: 'Manual',
                  visible: _mapManVisible,
                  onToggle: () =>
                      setState(() => _mapManVisible = !_mapManVisible),
                  totalWidth: totalW,
                ),
              ),
            );
          }
          if (_mapManVisible) {
            headerRow2.add(
              _cell(
                c['label']!,
                _colWidth(key),
                fontWeight: FontWeight.bold,
                isHeader: true,
                height: headerCellHeight,
                fontSize: headerRow3FontSize,
              ),
            );
          } else if (key == mapManKeys.first) {
            headerRow2.add(
              _cell(
                '',
                iconGroupWidth,
                isHeader: true,
                height: headerCellHeight,
                fontSize: headerRow3FontSize,
              ),
            );
          }
        } else if (key == mapDataKey) {
          // Coluna Data após Manual, com ícone de calendário acima
          final w = _colWidth(mapDataKey);
          headerRow1.add(
            Container(
              width: w,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              height: headerGroupHeight,
              alignment: Alignment.center,
              child: Icon(
                Icons.calendar_today,
                size: 20,
                color: Colors.grey.shade700,
              ),
            ),
          );
          headerRow2.add(
            _cell(
              'Data',
              w,
              fontWeight: FontWeight.bold,
              isHeader: true,
              height: headerCellHeight,
              fontSize: headerRow3FontSize,
            ),
          );
        } else if (execucaoMecKeys.contains(key)) {
          if (!headerRow1.any(
            (w) => (w.key as ValueKey?)?.value == 'execucao-mec-span',
          )) {
            final totalW = execucaoMecKeys.fold<double>(
              0,
              (s, k) => s + _colWidth(k),
            );
            if (!headerRow0ExecucaoMidAdded) {
              headerRow0.add(simpleGroupCell('Execução', totalExecucaoMidW));
              headerRow0ExecucaoMidAdded = true;
            }
            headerRow1.add(
              KeyedSubtree(
                key: const ValueKey('execucao-mec-span'),
                child: groupHeaderCell(
                  label: 'Mecanizado',
                  visible: _execucaoMecVisible,
                  onToggle: () => setState(
                    () => _execucaoMecVisible = !_execucaoMecVisible,
                  ),
                  totalWidth: totalW,
                ),
              ),
            );
          }
          if (_execucaoMecVisible) {
            headerRow2.add(
              _cell(
                c['label']!,
                _colWidth(key),
                fontWeight: FontWeight.bold,
                isHeader: true,
                height: headerCellHeight,
                fontSize: headerRow3FontSize,
              ),
            );
          } else if (key == execucaoMecKeys.first) {
            headerRow2.add(
              _cell(
                '',
                iconGroupWidth,
                isHeader: true,
                height: headerCellHeight,
                fontSize: headerRow3FontSize,
              ),
            );
          }
        } else if (execucaoManKeys.contains(key)) {
          if (!headerRow1.any(
            (w) => (w.key as ValueKey?)?.value == 'execucao-man-span',
          )) {
            final totalW = execucaoManKeys.fold<double>(
              0,
              (s, k) => s + _colWidth(k),
            );
            headerRow1.add(
              KeyedSubtree(
                key: const ValueKey('execucao-man-span'),
                child: groupHeaderCell(
                  label: 'Manual',
                  visible: _execucaoManVisible,
                  onToggle: () => setState(
                    () => _execucaoManVisible = !_execucaoManVisible,
                  ),
                  totalWidth: totalW,
                ),
              ),
            );
          }
          if (_execucaoManVisible) {
            headerRow2.add(
              _cell(
                c['label']!,
                _colWidth(key),
                fontWeight: FontWeight.bold,
                isHeader: true,
                height: headerCellHeight,
                fontSize: headerRow3FontSize,
              ),
            );
          } else if (key == execucaoManKeys.first) {
            headerRow2.add(
              _cell(
                '',
                iconGroupWidth,
                isHeader: true,
                height: headerCellHeight,
                fontSize: headerRow3FontSize,
              ),
            );
          }
        } else if (execMecKeys.contains(key)) {
          if (!headerRow1.any(
            (w) => (w.key as ValueKey?)?.value == 'exec-mec-span',
          )) {
            final totalW = execMecKeys.fold<double>(
              0,
              (s, k) => s + _colWidth(k),
            );
            if (!headerRow0ExecucaoAdded) {
              headerRow0.add(
                simpleGroupCell('Fiscalização da Execução', totalExecucaoW),
              );
              headerRow0ExecucaoAdded = true;
            }
            headerRow1.add(
              KeyedSubtree(
                key: const ValueKey('exec-mec-span'),
                child: groupHeaderCell(
                  label: 'Mecanizado',
                  visible: _execMecVisible,
                  onToggle: () =>
                      setState(() => _execMecVisible = !_execMecVisible),
                  totalWidth: totalW,
                ),
              ),
            );
          }
          if (_execMecVisible) {
            headerRow2.add(
              _cell(
                c['label']!,
                _colWidth(key),
                fontWeight: FontWeight.bold,
                isHeader: true,
                height: headerCellHeight,
                fontSize: headerRow3FontSize,
              ),
            );
          } else if (key == execMecKeys.first) {
            headerRow2.add(
              _cell(
                '',
                iconGroupWidth,
                isHeader: true,
                height: headerCellHeight,
                fontSize: headerRow3FontSize,
              ),
            );
          }
        } else if (execManKeys.contains(key)) {
          if (!headerRow1.any(
            (w) => (w.key as ValueKey?)?.value == 'exec-man-span',
          )) {
            final totalW = execManKeys.fold<double>(
              0,
              (s, k) => s + _colWidth(k),
            );
            headerRow1.add(
              KeyedSubtree(
                key: const ValueKey('exec-man-span'),
                child: groupHeaderCell(
                  label: 'Manual',
                  visible: _execManVisible,
                  onToggle: () =>
                      setState(() => _execManVisible = !_execManVisible),
                  totalWidth: totalW,
                ),
              ),
            );
          }
          if (_execManVisible) {
            headerRow2.add(
              _cell(
                c['label']!,
                _colWidth(key),
                fontWeight: FontWeight.bold,
                isHeader: true,
                height: headerCellHeight,
                fontSize: headerRow3FontSize,
              ),
            );
          } else if (key == execManKeys.first) {
            headerRow2.add(
              _cell(
                '',
                iconGroupWidth,
                isHeader: true,
                height: headerCellHeight,
                fontSize: headerRow3FontSize,
              ),
            );
          }
        } else {
          final w = _colWidth(key);
          headerRow0.add(
            _cell('', w, isHeader: true, height: headerGroupHeight),
          );
          headerRow1.add(
            _cell('', w, isHeader: true, height: headerGroupHeight),
          );
          headerRow2.add(
            _cell(
              c['label']!,
              w,
              fontWeight: FontWeight.bold,
              isHeader: true,
              height: headerCellHeight,
              fontSize: headerRow3FontSize,
            ),
          );
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: headerRow0),
          Row(children: headerRow1),
          Row(children: headerRow2),
        ],
      );
    }

    List<Widget> buildFixedRows() {
      return pageItems.map((row) {
        final linhaNome = row['linhas_transmissao']?['nome'] ?? row['lt'] ?? '';
        return Row(
          children: [
            Container(
              width: fixedCols.first['width'] as double,
              height: bodyRowHeight,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility),
                    tooltip: 'Visualizar',
                    onPressed: () => widget.onView(row),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => widget.onEdit(row),
                    tooltip: 'Editar / Mapear',
                  ),
                ],
              ),
            ),
            _cell(
              linhaNome.toString(),
              fixedCols[1]['width'] as double,
              height: bodyRowHeight,
            ),
            _editableCell(
              row: row,
              key: 'est_codigo',
              label: 'EST.',
              width: fixedCols[2]['width'] as double,
            ),
            _editableCell(
              row: row,
              key: 'vao_frente_m',
              label: 'Extensão',
              width: fixedCols[3]['width'] as double,
              isNumber: true,
            ),
            _editableCell(
              row: row,
              key: 'vao_largura_m',
              label: 'Largura',
              width: fixedCols[4]['width'] as double,
              isNumber: true,
            ),
          ],
        );
      }).toList();
    }

    List<Widget> buildRightRows() {
      const double iconGroupWidth = 31.0;
      return pageItems.map((row) {
        final linhaNome = row['linhas_transmissao']?['nome'] ?? row['lt'] ?? '';
        final cells = <Widget>[];
        for (final c in dynamicCols) {
          final key = c['key']!;
          if (mapMecKeys.contains(key)) {
            if (!_mapMecVisible) {
              if (key == mapMecKeys.first) {
                cells.add(_cell('', iconGroupWidth, height: bodyRowHeight));
              }
            } else {
              cells.add(_buildCellForColumn(c, row, linhaNome));
            }
          } else if (mapManKeys.contains(key)) {
            if (!_mapManVisible) {
              if (key == mapManKeys.first) {
                cells.add(_cell('', iconGroupWidth, height: bodyRowHeight));
              }
            } else {
              cells.add(_buildCellForColumn(c, row, linhaNome));
            }
          } else if (execucaoMecKeys.contains(key)) {
            if (!_execucaoMecVisible) {
              if (key == execucaoMecKeys.first) {
                cells.add(_cell('', iconGroupWidth, height: bodyRowHeight));
              }
            } else {
              cells.add(_buildCellForColumn(c, row, linhaNome));
            }
          } else if (execucaoManKeys.contains(key)) {
            if (!_execucaoManVisible) {
              if (key == execucaoManKeys.first) {
                cells.add(_cell('', iconGroupWidth, height: bodyRowHeight));
              }
            } else {
              cells.add(_buildCellForColumn(c, row, linhaNome));
            }
          } else if (execMecKeys.contains(key)) {
            if (!_execMecVisible) {
              if (key == execMecKeys.first) {
                cells.add(_cell('', iconGroupWidth, height: bodyRowHeight));
              }
            } else {
              cells.add(_buildCellForColumn(c, row, linhaNome));
            }
          } else if (execManKeys.contains(key)) {
            if (!_execManVisible) {
              if (key == execManKeys.first) {
                cells.add(_cell('', iconGroupWidth, height: bodyRowHeight));
              }
            } else {
              cells.add(_buildCellForColumn(c, row, linhaNome));
            }
          } else {
            cells.add(_buildCellForColumn(c, row, linhaNome));
          }
        }
        return Row(children: cells);
      }).toList();
    }

    final totalPages = (widget.vaos.length / widget.pageSize).ceil();
    final fixedWidth = fixedCols.fold<double>(
      0,
      (sum, c) => sum + (c['width'] as double),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final horizontalScrollWidth = (availableWidth - fixedWidth - 8).clamp(
          200.0,
          double.infinity,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildFixedHeader(),
                    SizedBox(
                      height: bodyHeight,
                      child: Scrollbar(
                        controller: _leftV,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _leftV,
                          scrollDirection: Axis.vertical,
                          child: Column(children: buildFixedRows()),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: horizontalScrollWidth,
                  child: Scrollbar(
                    controller: _horizontalScroll,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _horizontalScroll,
                      scrollDirection: Axis.horizontal,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              buildRightHeader(),
                              SizedBox(
                                height: bodyHeight,
                                child: Scrollbar(
                                  controller: _rightV,
                                  thumbVisibility: true,
                                  child: SingleChildScrollView(
                                    controller: _rightV,
                                    scrollDirection: Axis.vertical,
                                    child: Column(children: buildRightRows()),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Positioned(
                            left: totalMapeamentoW - 1,
                            top: 0,
                            bottom: 0,
                            width: 2,
                            child: Container(color: Colors.grey.shade700),
                          ),
                          Positioned(
                            left: totalMapeamentoW + totalExecucaoMidW - 1,
                            top: 0,
                            bottom: 0,
                            width: 2,
                            child: Container(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Página ${widget.currentPage + 1} de $totalPages'),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: widget.currentPage > 0
                      ? () => widget.onPageChanged(widget.currentPage - 1)
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: (widget.currentPage + 1) < totalPages
                      ? () => widget.onPageChanged(widget.currentPage + 1)
                      : null,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _EditarVaoDialog extends StatefulWidget {
  final Map<String, dynamic> vao;
  const _EditarVaoDialog({required this.vao});

  @override
  State<_EditarVaoDialog> createState() => _EditarVaoDialogState();
}

class _EditarVaoDialogState extends State<_EditarVaoDialog> {
  late TextEditingController _prioridadeController;
  late TextEditingController _pendenciasController;
  late TextEditingController _estController;
  late TextEditingController _vaoFrenteController;
  late TextEditingController _vaoLarguraController;
  late TextEditingController _mapMecExtController;
  late TextEditingController _mapMecLargController;
  late TextEditingController _mapManExtController;
  late TextEditingController _mapManLargController;
  late TextEditingController _execMecExtController;
  late TextEditingController _execMecLargController;
  late TextEditingController _execManExtController;
  late TextEditingController _execManLargController;
  late TextEditingController _numeracaoGgtController;
  late TextEditingController _mapeamentoGgtController;
  late TextEditingController _codigoGgtController;
  late TextEditingController _descricaoServicosController;
  late TextEditingController _conferenciaController;
  late TextEditingController _pendManualController;
  late TextEditingController _pendMecanizadoController;
  late TextEditingController _pendSeletivoController;
  late TextEditingController _pendManualExtraController;
  late TextEditingController _pendMecanizadoExtraController;
  late TextEditingController _pendSeletivoExtraController;
  DateTime? _mapData;
  DateTime? _execucaoMecDataInicio;
  DateTime? _execucaoMecDataFim;
  DateTime? _execucaoManDataInicio;
  DateTime? _execucaoManDataFim;
  DateTime? _execMecData;
  DateTime? _execManData;
  DateTime? _vaoConclusao;
  bool _rocoConcluido = false;

  @override
  void initState() {
    super.initState();
    _prioridadeController = TextEditingController(
      text: widget.vao['prioridade']?.toString() ?? '',
    );
    _pendenciasController = TextEditingController(
      text: widget.vao['pendencias_execucao']?.toString() ?? '',
    );
    _estController = TextEditingController(
      text: widget.vao['est_codigo']?.toString() ?? '',
    );
    _vaoFrenteController = TextEditingController(
      text: _numStr(widget.vao['vao_frente_m']),
    );
    _vaoLarguraController = TextEditingController(
      text: _numStr(widget.vao['vao_largura_m']),
    );
    _mapMecExtController = TextEditingController(
      text: _numStr(widget.vao['map_mec_extensao_m']),
    );
    _mapMecLargController = TextEditingController(
      text: _numStr(widget.vao['map_mec_largura_m']),
    );
    _mapManExtController = TextEditingController(
      text: _numStr(widget.vao['map_man_extensao_m']),
    );
    _mapManLargController = TextEditingController(
      text: _numStr(widget.vao['map_man_largura_m']),
    );
    _execMecExtController = TextEditingController(
      text: _numStr(widget.vao['exec_mec_extensao_m']),
    );
    _execMecLargController = TextEditingController(
      text: _numStr(widget.vao['exec_mec_largura_m']),
    );
    _execManExtController = TextEditingController(
      text: _numStr(widget.vao['exec_man_extensao_m']),
    );
    _execManLargController = TextEditingController(
      text: _numStr(widget.vao['exec_man_largura_m']),
    );
    _numeracaoGgtController = TextEditingController(
      text: widget.vao['numeracao_ggt']?.toString() ?? '',
    );
    _mapeamentoGgtController = TextEditingController(
      text: widget.vao['mapeamento_ggt']?.toString() ?? '',
    );
    _codigoGgtController = TextEditingController(
      text: widget.vao['codigo_ggt_execucao']?.toString() ?? '',
    );
    _descricaoServicosController = TextEditingController(
      text: widget.vao['descricao_servicos']?.toString() ?? '',
    );
    _conferenciaController = TextEditingController(
      text: widget.vao['conferencia_vao']?.toString() ?? '',
    );
    _pendManualController = TextEditingController(
      text: widget.vao['pend_manual']?.toString() ?? '',
    );
    _pendMecanizadoController = TextEditingController(
      text: widget.vao['pend_mecanizado']?.toString() ?? '',
    );
    _pendSeletivoController = TextEditingController(
      text: widget.vao['pend_seletivo']?.toString() ?? '',
    );
    _pendManualExtraController = TextEditingController(
      text: widget.vao['pend_manual_extra']?.toString() ?? '',
    );
    _pendMecanizadoExtraController = TextEditingController(
      text: widget.vao['pend_mecanizado_extra']?.toString() ?? '',
    );
    _pendSeletivoExtraController = TextEditingController(
      text: widget.vao['pend_seletivo_extra']?.toString() ?? '',
    );
    _rocoConcluido = (widget.vao['roco_concluido'] == true);
    _mapData = _parseDate(widget.vao['map_data']);
    _execucaoMecDataInicio = _parseDate(widget.vao['execucao_mec_data_inicio']);
    _execucaoMecDataFim = _parseDate(widget.vao['execucao_mec_data_fim']);
    _execucaoManDataInicio = _parseDate(widget.vao['execucao_man_data_inicio']);
    _execucaoManDataFim = _parseDate(widget.vao['execucao_man_data_fim']);
    _execMecData = _parseDate(widget.vao['exec_mec_data']);
    _execManData = _parseDate(widget.vao['exec_man_data']);
    _vaoConclusao = _parseDate(widget.vao['vao_data_conclusao']);
  }

  String _numStr(dynamic v) {
    if (v == null) return '';
    if (v is num) return v.toString();
    return v.toString();
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  Future<void> _pickDate(
    DateTime? current,
    void Function(DateTime?) setVal,
  ) async {
    final now = DateTime.now();
    final first = DateTime(now.year - 5);
    final last = DateTime(now.year + 5);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      setState(() => setVal(picked));
    }
  }

  @override
  void dispose() {
    _prioridadeController.dispose();
    _pendenciasController.dispose();
    _estController.dispose();
    _vaoFrenteController.dispose();
    _vaoLarguraController.dispose();
    _mapMecExtController.dispose();
    _mapMecLargController.dispose();
    _mapManExtController.dispose();
    _mapManLargController.dispose();
    _execMecExtController.dispose();
    _execMecLargController.dispose();
    _execManExtController.dispose();
    _execManLargController.dispose();
    _numeracaoGgtController.dispose();
    _mapeamentoGgtController.dispose();
    _codigoGgtController.dispose();
    _descricaoServicosController.dispose();
    _conferenciaController.dispose();
    _pendManualController.dispose();
    _pendMecanizadoController.dispose();
    _pendSeletivoController.dispose();
    _pendManualExtraController.dispose();
    _pendMecanizadoExtraController.dispose();
    _pendSeletivoExtraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Vão'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children:
              [
                    SwitchListTile(
                      title: const Text('Roço concluído'),
                      value: _rocoConcluido,
                      onChanged: (v) => setState(() => _rocoConcluido = v),
                    ),
                    _txt(_estController, 'EST.'),
                    _txt(_vaoFrenteController, 'Extensão', isNumber: true),
                    _txt(_vaoLarguraController, 'Largura', isNumber: true),
                    _txt(
                      _mapMecExtController,
                      'Map. Mec Extensão (m)',
                      isNumber: true,
                    ),
                    _txt(
                      _mapMecLargController,
                      'Map. Mec Largura (m)',
                      isNumber: true,
                    ),
                    _txt(
                      _mapManExtController,
                      'Map. Man Extensão (m)',
                      isNumber: true,
                    ),
                    _txt(
                      _mapManLargController,
                      'Map. Man Largura (m)',
                      isNumber: true,
                    ),
                    _DateField(
                      label: 'Data do mapeamento',
                      value: _mapData,
                      onPick: () => _pickDate(_mapData, (v) => _mapData = v),
                    ),
                    _DateField(
                      label: 'Execução Mec. Data Início',
                      value: _execucaoMecDataInicio,
                      onPick: () => _pickDate(
                        _execucaoMecDataInicio,
                        (v) => _execucaoMecDataInicio = v,
                      ),
                    ),
                    _DateField(
                      label: 'Execução Mec. Data Fim',
                      value: _execucaoMecDataFim,
                      onPick: () => _pickDate(
                        _execucaoMecDataFim,
                        (v) => _execucaoMecDataFim = v,
                      ),
                    ),
                    _DateField(
                      label: 'Execução Man. Data Início',
                      value: _execucaoManDataInicio,
                      onPick: () => _pickDate(
                        _execucaoManDataInicio,
                        (v) => _execucaoManDataInicio = v,
                      ),
                    ),
                    _DateField(
                      label: 'Execução Man. Data Fim',
                      value: _execucaoManDataFim,
                      onPick: () => _pickDate(
                        _execucaoManDataFim,
                        (v) => _execucaoManDataFim = v,
                      ),
                    ),
                    _txt(
                      _execMecExtController,
                      'Exec. Mec Extensão (m)',
                      isNumber: true,
                    ),
                    _txt(
                      _execMecLargController,
                      'Exec. Mec Largura (m)',
                      isNumber: true,
                    ),
                    _txt(
                      _execManExtController,
                      'Exec. Man Extensão (m)',
                      isNumber: true,
                    ),
                    _txt(
                      _execManLargController,
                      'Exec. Man Largura (m)',
                      isNumber: true,
                    ),
                    _DateField(
                      label: 'Execução Mecânica',
                      value: _execMecData,
                      onPick: () =>
                          _pickDate(_execMecData, (v) => _execMecData = v),
                    ),
                    _DateField(
                      label: 'Execução Manual',
                      value: _execManData,
                      onPick: () =>
                          _pickDate(_execManData, (v) => _execManData = v),
                    ),
                    _DateField(
                      label: 'Conclusão do Vão',
                      value: _vaoConclusao,
                      onPick: () =>
                          _pickDate(_vaoConclusao, (v) => _vaoConclusao = v),
                    ),
                    _txt(_numeracaoGgtController, 'Numeração GGT'),
                    _txt(_mapeamentoGgtController, 'Mapeamento GGT'),
                    _txt(_codigoGgtController, 'Código GGT Execução'),
                    _txt(
                      _descricaoServicosController,
                      'Descrição dos Serviços',
                      maxLines: 2,
                    ),
                    _txt(_prioridadeController, 'Prioridade'),
                    _txt(_conferenciaController, 'Conferência do Vão'),
                    _txt(_pendManualController, 'Pend. Manual'),
                    _txt(_pendMecanizadoController, 'Pend. Mecanizado'),
                    _txt(_pendSeletivoController, 'Pend. Seletivo'),
                    _txt(_pendManualExtraController, 'Pend. Manual Extra'),
                    _txt(
                      _pendMecanizadoExtraController,
                      'Pend. Mecanizado Extra',
                    ),
                    _txt(_pendSeletivoExtraController, 'Pend. Seletivo Extra'),
                    _txt(
                      _pendenciasController,
                      'Pendências na execução',
                      maxLines: 3,
                    ),
                  ]
                  .map(
                    (w) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: w,
                    ),
                  )
                  .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final payload = <String, dynamic>{
              'est_codigo': _estController.text.trim(),
              'vao_frente_m': _toDouble(_vaoFrenteController.text),
              'vao_largura_m': _toDouble(_vaoLarguraController.text),
              'map_mec_extensao_m': _toDouble(_mapMecExtController.text),
              'map_mec_largura_m': _toDouble(_mapMecLargController.text),
              'map_man_extensao_m': _toDouble(_mapManExtController.text),
              'map_man_largura_m': _toDouble(_mapManLargController.text),
              'map_data': _mapData?.toIso8601String(),
              'execucao_mec_data_inicio': _execucaoMecDataInicio?.toIso8601String(),
              'execucao_mec_data_fim': _execucaoMecDataFim?.toIso8601String(),
              'execucao_man_data_inicio': _execucaoManDataInicio?.toIso8601String(),
              'execucao_man_data_fim': _execucaoManDataFim?.toIso8601String(),
              'exec_mec_extensao_m': _toDouble(_execMecExtController.text),
              'exec_mec_largura_m': _toDouble(_execMecLargController.text),
              'exec_man_extensao_m': _toDouble(_execManExtController.text),
              'exec_man_largura_m': _toDouble(_execManLargController.text),
              'roco_concluido': _rocoConcluido,
              'prioridade': _prioridadeController.text.trim(),
              'pendencias_execucao': _pendenciasController.text.trim(),
              'numeracao_ggt': _numeracaoGgtController.text.trim(),
              'mapeamento_ggt': _mapeamentoGgtController.text.trim(),
              'codigo_ggt_execucao': _codigoGgtController.text.trim(),
              'descricao_servicos': _descricaoServicosController.text.trim(),
              'conferencia_vao': _conferenciaController.text.trim(),
              'pend_manual': _pendManualController.text.trim(),
              'pend_mecanizado': _pendMecanizadoController.text.trim(),
              'pend_seletivo': _pendSeletivoController.text.trim(),
              'pend_manual_extra': _pendManualExtraController.text.trim(),
              'pend_mecanizado_extra': _pendMecanizadoExtraController.text
                  .trim(),
              'pend_seletivo_extra': _pendSeletivoExtraController.text.trim(),
              'exec_mec_data': _execMecData?.toIso8601String(),
              'exec_man_data': _execManData?.toIso8601String(),
              'vao_data_conclusao': _vaoConclusao?.toIso8601String(),
            };
            Navigator.of(context).pop(payload);
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }

  Widget _txt(
    TextEditingController c,
    String label, {
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return TextField(
      controller: c,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      maxLines: maxLines,
    );
  }

  double? _toDouble(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? 'Selecione'
        : '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}';
    return Row(
      children: [
        Expanded(child: Text(label)),
        TextButton(onPressed: onPick, child: Text(text)),
      ],
    );
  }
}

class _VerVaoDialog extends StatelessWidget {
  final Map<String, dynamic> vao;
  const _VerVaoDialog({required this.vao});

  String _fmt(dynamic v) => v == null ? '' : v.toString();
  String _fmtNum(dynamic v) {
    if (v == null) return '';
    if (v is num) return v.round().toString();
    return v.toString();
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '';
    final dt = v is DateTime ? v : DateTime.tryParse(v.toString());
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final linhaNome = vao['linhas_transmissao']?['nome'] ?? _fmt(vao['lt']);
    final est = _fmt(vao['est_codigo']);

    Map<String, String> labels = {
      'lt': 'LT',
      'est_codigo': 'Estrutura',
      'familia': 'Família',
      'tipo': 'Tipo',
      'progressiva': 'Progressiva',
      'vao_m': 'Vão (m)',
      'altura_util_m': 'Altura útil (m)',
      'deflexao': 'Deflexão',
      'equipe': 'Equipe',
      'geo_lat': 'Geo Lat',
      'geo_lon': 'Geo Lon',
      'numeracao_antiga': 'Numeração antiga',
      'vao_frente_m': 'Extensão',
      'vao_largura_m': 'Largura',
      'map_mec_extensao_m': 'Map. Mec Ext (m)',
      'map_mec_largura_m': 'Map. Mec Larg (m)',
      'map_data': 'Data do mapeamento',
      'execucao_mec_data_inicio': 'Exec. Mec. Data Início',
      'execucao_mec_data_fim': 'Exec. Mec. Data Fim',
      'execucao_man_data_inicio': 'Exec. Man. Data Início',
      'execucao_man_data_fim': 'Exec. Man. Data Fim',
      'map_man_extensao_m': 'Map. Man Ext (m)',
      'map_man_largura_m': 'Map. Man Larg (m)',
      'exec_mec_extensao_m': 'Exec. Mec Ext (m)',
      'exec_mec_largura_m': 'Exec. Mec Larg (m)',
      'exec_mec_data': 'Exec. Mec Data',
      'exec_man_extensao_m': 'Exec. Man Ext (m)',
      'exec_man_largura_m': 'Exec. Man Larg (m)',
      'exec_man_data': 'Exec. Man Data',
      'vao_data_conclusao': 'Conclusão do Vão',
      'roco_concluido': 'Roço concluído',
      'numeracao_ggt': 'Numeração GGT',
      'mapeamento_ggt': 'Mapeamento GGT',
      'codigo_ggt_execucao': 'Código GGT Execução',
      'descricao_servicos': 'Descrição Serviços',
      'prioridade': 'Prioridade',
      'conferencia_vao': 'Conf. Vão',
      'pend_manual': 'Pend. Manual',
      'pend_mecanizado': 'Pend. Mecanizado',
      'pend_seletivo': 'Pend. Seletivo',
      'pend_manual_extra': 'Pend. Manual Extra',
      'pend_mecanizado_extra': 'Pend. Mecanizado Extra',
      'pend_seletivo_extra': 'Pend. Seletivo Extra',
      'pendencias_execucao': 'Pendências Execução',
    };

    List<Widget> buildSection(String title, List<String> keys) {
      final rows = <Widget>[];
      for (final k in keys) {
        final val = vao[k];
        if (val == null || val.toString().trim().isEmpty) continue;
        String display;
        if (k.contains('_m')) {
          display = _fmtNum(val);
        } else if (k.contains('data')) {
          display = _fmtDate(val);
        } else if (k == 'roco_concluido') {
          display = val == true ? 'Sim' : 'Não';
        } else {
          display = _fmt(val);
        }
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 160,
                  child: Text(
                    labels[k] ?? k,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(child: Text(display)),
              ],
            ),
          ),
        );
      }
      if (rows.isEmpty) return [];
      return [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
        ...rows,
      ];
    }

    return AlertDialog(
      title: Text('Vão $est'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (linhaNome.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Linha: $linhaNome',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ...buildSection('Estrutura', [
                'lt',
                'est_codigo',
                'familia',
                'tipo',
                'progressiva',
                'vao_m',
                'altura_util_m',
                'deflexao',
                'equipe',
                'geo_lat',
                'geo_lon',
                'numeracao_antiga',
              ]),
              ...buildSection('Mapeamento', [
                'vao_frente_m',
                'vao_largura_m',
                'map_mec_extensao_m',
                'map_mec_largura_m',
                'map_data',
                'execucao_mec_data_inicio',
                'execucao_mec_data_fim',
                'execucao_man_data_inicio',
                'execucao_man_data_fim',
                'map_man_extensao_m',
                'map_man_largura_m',
                'exec_mec_extensao_m',
                'exec_mec_largura_m',
                'exec_mec_data',
                'exec_man_extensao_m',
                'exec_man_largura_m',
                'exec_man_data',
                'vao_data_conclusao',
                'roco_concluido',
                'numeracao_ggt',
                'mapeamento_ggt',
                'codigo_ggt_execucao',
                'descricao_servicos',
                'prioridade',
                'conferencia_vao',
                'pend_manual',
                'pend_mecanizado',
                'pend_seletivo',
                'pend_manual_extra',
                'pend_mecanizado_extra',
                'pend_seletivo_extra',
                'pendencias_execucao',
              ]),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
