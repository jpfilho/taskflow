import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/demand.dart';
import '../services/demand_service.dart';
import '../utils/responsive.dart';
import '../services/executor_service.dart';
import '../services/demand_attachment_service.dart';
import '../models/executor.dart';
import '../models/demand_attachment.dart';

class DemandasView extends StatefulWidget {
  const DemandasView({super.key});

  @override
  State<DemandasView> createState() => _DemandasViewState();
}

class _DemandasViewState extends State<DemandasView> with TickerProviderStateMixin {
  final DemandService _service = DemandService();
  final ExecutorService _executorService = ExecutorService();
  final DemandAttachmentService _attachmentService = DemandAttachmentService();
  late TabController _tabs;

  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _descricaoController = TextEditingController();
  String _formStatus = 'pendente';
  String _formPrioridade = 'media';
  DateTime? _formVencimento;
  String? _formResponsavel; // atribuída_para (executor.id)
  String? _formResponsavelNome;
  bool _creating = false;
  bool _editing = false;
  Demand? _editingDemand;
  // Filtros de perfil (preencha a partir do usuário logado)
  String? _regionalId;
  String? _divisaoId;
  String? _segmentoId;
  List<Executor> _executores = [];
  final Map<String, String> _executorNomeById = {};

  final Set<String> _filtroStatus = {};
  final Set<String> _filtroPrioridade = {};
  final Set<String> _filtroCategoria = {};
  String _busca = '';
  DateTime? _venceDe;
  DateTime? _venceAte;
  String _orderBy = 'data_vencimento';
  bool _asc = true;

  int _page = 0;
  bool _loading = false;
  bool _hasMore = true;
  final List<Demand> _items = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _loadExecutores();
    _load(reset: true);
    _service.subscribe(
      onUpsert: (d) {
        setState(() {
          final i = _items.indexWhere((x) => x.id == d.id);
          if (i >= 0) {
            _items[i] = d;
          } else {
            _items.insert(0, d);
          }
        });
      },
      onDelete: (id) {
        setState(() {
          _items.removeWhere((x) => x.id == id);
        });
      },
    );
  }

  void _openAttachmentsSheet(Demand d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        List<DemandAttachment> anexos = [];
        bool loading = true;
        bool uploading = false;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              Future<void> refresh() async {
                setModalState(() => loading = true);
                try {
                  final res = await _attachmentService.listByDemand(d.id);
                  setModalState(() {
                    anexos = res;
                    loading = false;
                  });
                } catch (e) {
                  setModalState(() => loading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao carregar anexos: $e')),
                  );
                }
              }

              Future<void> upload() async {
                try {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.any,
                    allowMultiple: true,
                  );
                  if (result == null || result.files.isEmpty) return;
                  setModalState(() => uploading = true);
                  for (final f in result.files) {
                    try {
                      if (kIsWeb && f.bytes != null) {
                        await _attachmentService.uploadBytes(
                          demandaId: d.id,
                          bytes: f.bytes!,
                          nomeArquivo: f.name,
                        );
                      } else if (f.path != null) {
                        await _attachmentService.uploadFile(
                          demandaId: d.id,
                          file: File(f.path!),
                          nomeCustomizado: f.name,
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Falha ao enviar ${f.name}: $e')),
                      );
                    }
                  }
                  await refresh();
                } finally {
                  setModalState(() => uploading = false);
                }
              }

              Future<void> deleteAttachment(DemandAttachment a) async {
                final confirmar = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    title: const Text('Excluir anexo'),
                    content: Text('Remover "${a.nome ?? a.url}"?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: const Text('Cancelar')),
                      TextButton(
                        onPressed: () => Navigator.of(dCtx).pop(true),
                        child: const Text('Excluir', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirmar == true) {
                  try {
                    await _attachmentService.deleteAttachment(a);
                    await refresh();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro ao excluir: $e')),
                    );
                  }
                }
              }

              Future<void> openAttachment(DemandAttachment a) async {
                try {
                  final url = await _attachmentService.getDownloadUrl(a);
                  if (await canLaunchUrl(Uri.parse(url))) {
                    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Não foi possível abrir o arquivo')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao abrir: $e')),
                  );
                }
              }

              if (loading) {
                // Carrega na primeira build
                Future.microtask(refresh);
              }

              return SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Anexos de "${d.titulo}"',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              onPressed: uploading ? null : upload,
                              icon: uploading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.upload_file),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (loading)
                      const Expanded(child: Center(child: CircularProgressIndicator()))
                    else if (anexos.isEmpty)
                      const Expanded(child: Center(child: Text('Nenhum anexo')))
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: anexos.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final a = anexos[i];
                            return ListTile(
                              leading: const Icon(Icons.attachment),
                              title: Text(a.nome ?? a.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                  '${a.contentType ?? '-'} • ${(a.tamanhoBytes ?? 0) ~/ 1024} KB • ${a.criadoEm != null ? DateFormat('dd/MM/yyyy HH:mm').format(a.criadoEm!) : '-'}'),
                              trailing: Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    tooltip: 'Abrir',
                                    icon: const Icon(Icons.open_in_new),
                                    onPressed: () => openAttachment(a),
                                  ),
                                  IconButton(
                                    tooltip: 'Excluir',
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => deleteAttachment(a),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    if (reset) {
      _page = 0;
      _hasMore = true;
      _items.clear();
    }
    final data = await _service.list(
      page: _page,
      status: _filtroStatus,
      prioridade: _filtroPrioridade,
      categorias: _filtroCategoria,
      busca: _busca,
      venceDe: _venceDe,
      venceAte: _venceAte,
      orderBy: _orderBy,
      asc: _asc,
    );
    setState(() {
      _items.addAll(data);
      _hasMore = data.length == _service.pageSize;
      _page++;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _tituloController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  // TODO: Ajustar para buscar os filtros (regional/divisão/segmento) do usuário logado.
  // Aqui vamos filtrar por divisão/segmentos se disponíveis no Executor.
  Future<void> _loadExecutores() async {
    try {
      // Usa o mesmo serviço/assinatura do formulário de tarefas
      List<Executor> list = await _executorService.getExecutoresFiltrados(
        regionalId: _regionalId,
        divisaoId: _divisaoId,
        segmentoId: _segmentoId,
      );

      setState(() {
        _executores = list;
        _executorNomeById
          ..clear()
          ..addEntries(list.map((e) => MapEntry(e.id, e.nomeCompleto ?? e.nome)));
      });
    } catch (e) {
      debugPrint('Erro ao carregar executores: $e');
    }
  }

  Future<Executor?> _openResponsavelSelector(BuildContext context) async {
    final TextEditingController searchCtrl = TextEditingController();
    List<Executor> current = List.of(_executores);

    return showModalBottomSheet<Executor>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            void doSearch(String q) {
              final term = q.trim().toLowerCase();
              setModalState(() {
                if (term.isEmpty) {
                  current = List.of(_executores);
                } else {
                  current = _executores.where((e) {
                    final n = (e.nomeCompleto ?? e.nome).toLowerCase();
                    final login = (e.login ?? '').toLowerCase();
                    return n.contains(term) || login.contains(term);
                  }).toList();
                }
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 12,
                right: 12,
                top: 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchCtrl,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Pesquisar executor',
                    ),
                    onChanged: doSearch,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: MediaQuery.of(ctx).size.height * 0.5,
                    child: ListView.builder(
                      itemCount: current.length,
                      itemBuilder: (c, i) {
                        final e = current[i];
                        return ListTile(
                          title: Text(e.nomeCompleto ?? e.nome),
                          subtitle: e.login != null ? Text(e.login!) : null,
                          onTap: () => Navigator.of(ctx).pop(e),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demandas'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Lista'),
            Tab(text: 'Cards'),
            Tab(text: 'Calendário'),
            Tab(text: 'Planner'),
            Tab(text: 'Kanban'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _openFilterSheet(context),
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtros',
          ),
          IconButton(
            onPressed: () => _load(reset: true),
            icon: const Icon(Icons.refresh),
            tooltip: 'Recarregar',
          ),
        ],
      ),
      body: Column(
        children: [
          if (!isMobile) _buildFiltersInline(context),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _buildLista(),
                _buildCards(),
                _buildCalendario(),
                _buildPlanner(),
                _buildKanban(),
              ],
            ),
          ),
          if (_hasMore)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: _loading ? null : () => _load(),
                child: _loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Carregar mais'),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateForm,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFiltersInline(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _chipDropdown(
            label: 'Status',
            options: const ['pendente', 'em_progresso', 'concluido', 'cancelado'],
            selected: _filtroStatus,
          ),
          _chipDropdown(
            label: 'Prioridade',
            options: const ['baixa', 'media', 'alta', 'urgente'],
            selected: _filtroPrioridade,
          ),
          _chipDropdown(
            label: 'Ordenar por',
            options: const ['data_vencimento', 'prioridade', 'data_criacao'],
            selectedSingle: _orderBy,
            onSelectedSingle: (v) {
              setState(() => _orderBy = v);
              _load(reset: true);
            },
          ),
          FilterChip(
            label: Text(_asc ? 'ASC' : 'DESC'),
            selected: _asc,
            onSelected: (_) {
              setState(() => _asc = !_asc);
              _load(reset: true);
            },
          ),
          SizedBox(
            width: 200,
            child: TextField(
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar título/descrição',
              ),
              onSubmitted: (v) {
                _busca = v;
                _load(reset: true);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openCreateForm({bool reset = true}) {
    if (reset) {
      _tituloController.clear();
      _descricaoController.clear();
      _formStatus = 'pendente';
      _formPrioridade = 'media';
      _formVencimento = null;
      _formResponsavel = null;
      _formResponsavelNome = null;
      _editing = false;
      _editingDemand = null;
      _creating = false;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              Future<void> pickDate() async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _formVencimento ?? now,
                  firstDate: now.subtract(const Duration(days: 365)),
                  lastDate: now.add(const Duration(days: 365 * 5)),
                );
                if (picked != null) {
                  setModalState(() => _formVencimento = picked);
                }
              }

              Future<void> submit() async {
                if (_tituloController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Informe um título')),
                  );
                  return;
                }
                // validar responsável como UUID, senão ignorar
                String? responsavel = _formResponsavel;
                final uuidRegex = RegExp(r'^[0-9a-fA-F-]{36}$');
                if (responsavel != null && responsavel.isNotEmpty && !uuidRegex.hasMatch(responsavel)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Responsável inválido: informe um UUID válido')),
                  );
                  return;
                }
                setModalState(() => _creating = true);
                try {
                  final d = Demand(
                    id: _editing ? _editingDemand!.id : '',
                    titulo: _tituloController.text.trim(),
                    descricao: _descricaoController.text.trim().isEmpty ? null : _descricaoController.text.trim(),
                    status: _formStatus,
                    prioridade: _formPrioridade,
                    categoriaId: null,
                    criadoPor: _editing ? _editingDemand!.criadoPor : null,
                    atribuidaPara: (responsavel != null && responsavel.isNotEmpty) ? responsavel : null,
                    dataCriacao: _editing ? _editingDemand!.dataCriacao : DateTime.now(),
                    dataVencimento: _formVencimento,
                    dataInicio: null,
                    dataConclusao: null,
                    tags: const [],
                    metadata: const {},
                    atualizadoEm: null,
                  );
                  Demand saved;
                  if (_editing) {
                    saved = await _service.update(d);
                    if (mounted) {
                      setState(() {
                        final idx = _items.indexWhere((x) => x.id == saved.id);
                        if (idx >= 0) _items[idx] = saved;
                      });
                    }
                  } else {
                    saved = await _service.create(d);
                    if (mounted) {
                      setState(() {
                        _items.insert(0, saved);
                      });
                    }
                  }
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_editing ? 'Demanda atualizada' : 'Demanda criada')),
                    );
                  }
                } catch (e) {
                  setModalState(() => _creating = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao criar: $e')),
                  );
                }
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_editing ? 'Editar demanda' : 'Nova demanda',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _tituloController,
                    decoration: const InputDecoration(labelText: 'Título'),
                  ),
                  TextField(
                    controller: _descricaoController,
                    decoration: const InputDecoration(labelText: 'Descrição'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _formStatus,
                          decoration: const InputDecoration(labelText: 'Status'),
                          items: const [
                            DropdownMenuItem(value: 'pendente', child: Text('Pendente')),
                            DropdownMenuItem(value: 'em_progresso', child: Text('Em progresso')),
                            DropdownMenuItem(value: 'concluido', child: Text('Concluído')),
                            DropdownMenuItem(value: 'cancelado', child: Text('Cancelado')),
                          ],
                          onChanged: (v) => setModalState(() => _formStatus = v ?? 'pendente'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _formPrioridade,
                          decoration: const InputDecoration(labelText: 'Prioridade'),
                          items: const [
                            DropdownMenuItem(value: 'baixa', child: Text('Baixa')),
                            DropdownMenuItem(value: 'media', child: Text('Média')),
                            DropdownMenuItem(value: 'alta', child: Text('Alta')),
                            DropdownMenuItem(value: 'urgente', child: Text('Urgente')),
                          ],
                          onChanged: (v) => setModalState(() => _formPrioridade = v ?? 'media'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formVencimento != null
                              ? 'Vencimento: ${DateFormat('dd/MM/yyyy').format(_formVencimento!)}'
                              : 'Sem vencimento',
                        ),
                      ),
                      TextButton.icon(
                        onPressed: pickDate,
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: const Text('Escolher data'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    readOnly: true,
                    controller: TextEditingController(text: _formResponsavelNome ?? ''),
                    decoration: const InputDecoration(
                      labelText: 'Responsável (executor)',
                      suffixIcon: Icon(Icons.search),
                    ),
                    onTap: () async {
                      final sel = await _openResponsavelSelector(context);
                      if (sel != null) {
                        setModalState(() {
                          _formResponsavel = sel.id;
                          _formResponsavelNome = sel.nomeCompleto ?? sel.nome;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (_editingDemand != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: OutlinedButton.icon(
                            onPressed: _creating
                                ? null
                                : () {
                                    _openAttachmentsSheet(_editingDemand!);
                                  },
                            icon: const Icon(Icons.attach_file),
                            label: const Text('Anexos'),
                          ),
                        ),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _creating ? null : submit,
                          icon: _creating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check),
                          label: Text(_creating ? 'Salvando...' : 'Salvar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _duplicateDemand(Demand d) {
    setState(() {
      _tituloController.text = '${d.titulo} (cópia)';
      _descricaoController.text = d.descricao ?? '';
      _formStatus = d.status;
      _formPrioridade = d.prioridade;
      _formVencimento = d.dataVencimento;
      _formResponsavel = d.atribuidaPara;
      _formResponsavelNome = d.atribuidaPara != null ? _executorNomeById[d.atribuidaPara] : null;
      _editing = false;
      _editingDemand = null;
      _creating = false;
    });
    _openCreateForm(reset: false);
  }

  void _openEditForm(Demand d) {
    _tituloController.text = d.titulo;
    _descricaoController.text = d.descricao ?? '';
    _formStatus = d.status;
    _formPrioridade = d.prioridade;
    _formVencimento = d.dataVencimento;
    _formResponsavel = d.atribuidaPara;
    _formResponsavelNome = d.atribuidaPara != null ? _executorNomeById[d.atribuidaPara] : null;
    _editing = true;
    _editingDemand = d;
    _creating = false;
    _openCreateForm(reset: false);
  }

  void _openView(Demand d) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(d.titulo),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Status: ${d.status}'),
                Text('Prioridade: ${d.prioridade}'),
                const SizedBox(height: 6),
                Text('Responsável: ${_executorNomeById[d.atribuidaPara] ?? d.atribuidaPara ?? '—'}'),
                const SizedBox(height: 6),
                Text('Vencimento: ${d.dataVencimento != null ? DateFormat('dd/MM/yyyy').format(d.dataVencimento!) : '-'}'),
                const SizedBox(height: 6),
                Text('Criado em: ${d.dataCriacao != null ? fmt.format(d.dataCriacao!) : '-'}'),
                const SizedBox(height: 12),
                Text(d.descricao ?? 'Sem descrição'),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fechar')),
          ],
        );
      },
    );
  }

  void _confirmDelete(Demand d) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir demanda'),
        content: const Text('Tem certeza que deseja excluir esta demanda?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await _service.delete(d.id);
                if (mounted) {
                  setState(() {
                    _items.removeWhere((x) => x.id == d.id);
                  });
                }
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demanda excluída')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
              }
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _chipDropdown({
    required String label,
    required List<String> options,
    Set<String>? selected,
    String? selectedSingle,
    void Function(String value)? onSelectedSingle,
  }) {
    return PopupMenuButton<String>(
      tooltip: label,
      onSelected: (value) {
        setState(() {
          if (selected != null) {
            if (selected.contains(value)) {
              selected.remove(value);
            } else {
              selected.add(value);
            }
            _load(reset: true);
          } else if (onSelectedSingle != null) {
            onSelectedSingle(value);
          }
        });
      },
      itemBuilder: (context) => options
          .map(
            (o) => CheckedPopupMenuItem<String>(
              value: o,
              checked: selected != null ? selected.contains(o) : selectedSingle == o,
              child: Text(o),
            ),
          )
          .toList(),
      child: Chip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Widget _buildLista() {
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return const Center(child: Text('Nenhuma demanda'));
    }

    final fmt = DateFormat('dd/MM/yyyy');
    final orderedStatuses = ['pendente', 'em_progresso', 'concluido', 'cancelado'];
    final grouped = <String, List<Demand>>{};
    for (final s in orderedStatuses) {
      grouped[s] = [];
    }
    for (final d in _items) {
      grouped.putIfAbsent(d.status, () => []).add(d);
    }

    String fmtDateTime(DateTime? dt) =>
        dt != null ? DateFormat('dd/MM/yyyy HH:mm').format(dt) : '-';

    Widget buildRow(Demand d) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.15))),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Checkbox(value: false, onChanged: (_) {}),
            ),
            Expanded(
              flex: 2,
              child: Text(
                d.titulo,
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  d.descricao ?? '-',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.event, size: 16),
                      const SizedBox(width: 4),
                      Text(d.dataVencimento != null ? fmt.format(d.dataVencimento!) : '-'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Criado por: ${_executorNomeById[d.criadoPor] ?? d.criadoPor ?? '—'} • ${fmtDateTime(d.dataCriacao)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text(d.prioridade),
                  backgroundColor: _priorityColor(d.prioridade).withOpacity(0.12),
                  labelStyle: TextStyle(color: _priorityColor(d.prioridade)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  const Icon(Icons.person, size: 16),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      d.atribuidaPara != null && _executorNomeById.containsKey(d.atribuidaPara)
                          ? _executorNomeById[d.atribuidaPara]!
                          : d.atribuidaPara ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 2,
                  runSpacing: 2,
                  children: [
                    _statusChip(d.status, compact: true),
                    IconButton(
                      tooltip: 'Anexos',
                      icon: const Icon(Icons.attach_file, size: 18),
                      onPressed: () => _openAttachmentsSheet(d),
                    ),
                    IconButton(
                      tooltip: 'Duplicar',
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      onPressed: () => _duplicateDemand(d),
                    ),
                    IconButton(
                      tooltip: 'Ver',
                      icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                      onPressed: () => _openView(d),
                    ),
                    IconButton(
                      tooltip: 'Editar',
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () => _openEditForm(d),
                    ),
                    IconButton(
                      tooltip: 'Excluir',
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      onPressed: () => _confirmDelete(d),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: orderedStatuses.where((s) => grouped[s]?.isNotEmpty ?? false).map((status) {
        final list = grouped[status]!;
        final title = switch (status) {
          'pendente' => 'To-do',
          'em_progresso' => 'In Progress',
          'concluido' => 'Done',
          'cancelado' => 'Cancelled',
          _ => status,
        };
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Row(
                  children: [
                    _statusChip(status, compact: true),
                    const SizedBox(width: 8),
                    Text('$title  •  ${list.length}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: _openCreateForm,
                      tooltip: 'Nova demanda',
                    ),
                  ],
                ),
              ),
              ...list.map(buildRow),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCards() {
    if (_items.isEmpty && _loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return const Center(child: Text('Nenhuma demanda'));
    final isMobile = Responsive.isMobile(context);
    final cross = isMobile ? 1 : 2;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: _items.length,
      itemBuilder: (context, i) {
        final d = _items[i];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _statusChip(d.status),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(d.prioridade),
                      backgroundColor: _priorityColor(d.prioridade).withOpacity(0.15),
                      labelStyle: TextStyle(color: _priorityColor(d.prioridade)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  d.titulo,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    d.descricao ?? '-',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Vencimento: ${d.dataVencimento != null ? DateFormat('dd/MM/yyyy').format(d.dataVencimento!) : '-'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 2,
                  runSpacing: 2,
                  children: [
                    IconButton(
                      tooltip: 'Anexos',
                      icon: const Icon(Icons.attach_file, size: 18),
                      onPressed: () => _openAttachmentsSheet(d),
                    ),
                    IconButton(
                      tooltip: 'Duplicar',
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      onPressed: () => _duplicateDemand(d),
                    ),
                    IconButton(
                      tooltip: 'Ver',
                      icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                      onPressed: () => _openView(d),
                    ),
                    IconButton(
                      tooltip: 'Editar',
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () => _openEditForm(d),
                    ),
                    IconButton(
                      tooltip: 'Excluir',
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      onPressed: () => _confirmDelete(d),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalendario() {
    if (_items.isEmpty && _loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return const Center(child: Text('Nenhuma demanda'));
    final Map<DateTime, List<Demand>> byDay = {};
    for (final d in _items) {
      final day = DateTime(
        d.dataVencimento?.year ?? d.dataCriacao?.year ?? DateTime.now().year,
        d.dataVencimento?.month ?? d.dataCriacao?.month ?? DateTime.now().month,
        d.dataVencimento?.day ?? d.dataCriacao?.day ?? DateTime.now().day,
      );
      byDay.putIfAbsent(day, () => []).add(d);
    }
    final days = byDay.keys.toList()..sort();
    return ListView.builder(
      itemCount: days.length,
      itemBuilder: (context, i) {
        final day = days[i];
        final list = byDay[day]!;
        return ExpansionTile(
          title: Text(DateFormat('dd/MM/yyyy').format(day)),
          children: list
              .map(
                (d) => ListTile(
                  leading: _statusChip(d.status, compact: true),
                  title: Text(d.titulo),
                  subtitle: Text(d.prioridade),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildPlanner() {
    if (_items.isEmpty && _loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return const Center(child: Text('Nenhuma demanda'));
    final Map<int, List<Demand>> byWeekday = {};
    for (final d in _items) {
      final date = d.dataVencimento ?? d.dataCriacao ?? DateTime.now();
      final wd = date.weekday; // 1=Mon
      byWeekday.putIfAbsent(wd, () => []).add(d);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(7, (idx) {
          final wd = idx + 1;
          final list = byWeekday[wd] ?? [];
          return Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_weekdayLabel(wd), style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...list.map((d) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              _statusChip(d.status, compact: true),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  d.titulo,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )),
                    if (list.isEmpty) const Text('—'),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildKanban() {
    if (_items.isEmpty && _loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return const Center(child: Text('Nenhuma demanda'));
    final fmtDt = DateFormat('dd/MM/yyyy HH:mm');
    final cols = <String, List<Demand>>{
      'pendente': [],
      'em_progresso': [],
      'concluido': [],
      'cancelado': [],
    };
    for (final d in _items) {
      cols[d.status]?.add(d);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: cols.entries.map((e) {
          return Container(
            width: 260,
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...e.value.map(
                  (d) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.titulo,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            d.descricao ?? '-',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                  Text(
                    'Criado por: ${_executorNomeById[d.criadoPor] ?? d.criadoPor ?? '—'}',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Criado em: ${d.dataCriacao != null ? fmtDt.format(d.dataCriacao!) : '-'}',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                          Text(
                            'Prioridade: ${d.prioridade}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 2,
                            runSpacing: 2,
                            children: [
                              IconButton(
                                tooltip: 'Anexos',
                                icon: const Icon(Icons.attach_file, size: 18),
                                onPressed: () => _openAttachmentsSheet(d),
                              ),
                              IconButton(
                                tooltip: 'Duplicar',
                                icon: const Icon(Icons.copy_outlined, size: 18),
                                onPressed: () => _duplicateDemand(d),
                              ),
                              IconButton(
                                tooltip: 'Ver',
                                icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                                onPressed: () => _openView(d),
                              ),
                              IconButton(
                                tooltip: 'Editar',
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () => _openEditForm(d),
                              ),
                              IconButton(
                                tooltip: 'Excluir',
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                onPressed: () => _confirmDelete(d),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (e.value.isEmpty) const Text('—'),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _openFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Wrap(
            runSpacing: 12,
            children: [
              const Text('Filtros', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              _chipDropdown(
                label: 'Status',
                options: const ['pendente', 'em_progresso', 'concluido', 'cancelado'],
                selected: _filtroStatus,
              ),
              _chipDropdown(
                label: 'Prioridade',
                options: const ['baixa', 'media', 'alta', 'urgente'],
                selected: _filtroPrioridade,
              ),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Busca',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => _busca = v,
                onSubmitted: (_) => _load(reset: true),
              ),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _load(reset: true);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Aplicar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _statusChip(String status, {bool compact = false}) {
    Color c;
    switch (status) {
      case 'pendente':
        c = Colors.orange;
        break;
      case 'em_progresso':
        c = Colors.blue;
        break;
      case 'concluido':
        c = Colors.green;
        break;
      case 'cancelado':
        c = Colors.red;
        break;
      default:
        c = Colors.grey;
    }
    return Chip(
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      label: Text(status),
      backgroundColor: c.withOpacity(0.15),
      labelStyle: TextStyle(color: c, fontSize: compact ? 11 : null),
    );
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'baixa':
        return Colors.green;
      case 'media':
        return Colors.blue;
      case 'alta':
        return Colors.orange;
      case 'urgente':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _weekdayLabel(int wd) {
    switch (wd) {
      case 1:
        return 'Seg';
      case 2:
        return 'Ter';
      case 3:
        return 'Qua';
      case 4:
        return 'Qui';
      case 5:
        return 'Sex';
      case 6:
        return 'Sáb';
      case 7:
        return 'Dom';
      default:
        return '';
    }
  }
}
