import 'package:flutter/material.dart';

import '../../../documents/data/models/document.dart';
import '../../../documents/data/repositories/supabase_documents_repository.dart';
import '../../../documents/data/models/document_status.dart';
import '../widgets/document_card.dart';
import 'document_detail_page.dart';
import 'document_upload_page.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentsPage extends StatefulWidget {
  final SupabaseDocumentsRepository? repository;

  const DocumentsPage({super.key, this.repository});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  late final SupabaseDocumentsRepository _repo;
  bool _loading = true;
  String? _error;
  List<Document> _docs = [];
  int _total = 0;
  String _search = '';
  int _page = 0;
  final int _pageSize = 20;
  String? _selectedStatusId;
  String? _selectedMime;
  List<DocumentStatus> _statuses = [];

  final _searchController = TextEditingController();

  final List<String> _mimeOptions = const [
    'pdf',
    'docx',
    'xlsx',
    'pptx',
    'txt',
    'zip',
    'image', // agrupa jpg/png/webp
  ];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? SupabaseDocumentsRepository();
    _loadStatuses();
    _load();
  }

  Future<void> _loadStatuses() async {
    try {
      final list = await _repo.listStatuses();
      if (mounted) {
        setState(() => _statuses = list);
      }
    } catch (_) {
      // silencioso, não bloqueia
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await _repo.getDocuments(
        page: _page,
        pageSize: _pageSize,
        searchQuery: _search.isEmpty ? null : _search,
        statusDocumentId: _selectedStatusId,
      );
      final docs = (resp['documents'] as List?)?.cast<Document>() ?? [];
      final total = resp['total'] as int? ?? docs.length;
      if (mounted) {
        setState(() {
          _docs = docs;
          _total = total;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _nextPage() {
    _page += 1;
    _load();
  }

  void _prevPage() {
    if (_page == 0) return;
    _page -= 1;
    _load();
  }

  List<Document> get _filteredDocs {
    if (_selectedMime == null) return _docs;
    final mime = _selectedMime!;
    return _docs.where((d) {
      final ext = d.file.extension?.toLowerCase() ?? '';
      final mt = d.file.mimeType.toLowerCase();
      if (mime == 'image') {
        return mt.contains('image/') || ['jpg', 'jpeg', 'png', 'webp'].contains(ext);
      }
      return ext == mime || mt.contains(mime);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          color: Colors.grey.shade100,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                children: [
                  _buildHeader(context),
                  const Divider(height: 1),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildContent(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por título/descrição/tags',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
              onChanged: (v) {
                _search = v;
                _page = 0;
                _load();
              },
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DocumentUploadPage(repository: _repo),
                ),
              );
            },
            icon: const Icon(Icons.add_circle),
            label: const Text('Novo Documento'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Erro ao carregar: $_error'),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _load,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }
    final docs = _filteredDocs;
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nenhum documento encontrado'),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _load,
              child: const Text('Recarregar'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _buildFilters(),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _buildGrid(docs),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildPagination(docs.length),
      ],
    );
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            InputChip(
              selected: _selectedStatusId == null,
              label: const Text('Status: Todos'),
              onSelected: (_) {
                setState(() {
                  _selectedStatusId = null;
                  _page = 0;
                  _load();
                });
              },
            ),
            ..._statuses.map(
              (s) => InputChip(
                selected: _selectedStatusId == s.id,
                label: Text('Status: ${s.nome}'),
                onSelected: (_) {
                  setState(() {
                    _selectedStatusId = s.id;
                    _page = 0;
                    _load();
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              selected: _selectedMime == null,
              label: const Text('Formato: Todos'),
              onSelected: (_) {
                setState(() {
                  _selectedMime = null;
                });
              },
            ),
            ..._mimeOptions.map(
              (m) => ChoiceChip(
                selected: _selectedMime == m,
                label: Text('Formato: ${m.toUpperCase()}'),
                onSelected: (_) {
                  setState(() {
                    _selectedMime = m;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGrid(List<Document> docs) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width > 1200
            ? 3
            : width > 800
                ? 2
                : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: width > 800 ? 2.8 : 1.6,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            return DocumentCard(
              document: doc,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DocumentDetailPage(
                      documentId: doc.id,
                      repository: _repo,
                    ),
                  ),
                );
              },
              onDownload: doc.file.url != null
                  ? () => _openUrl(context, doc.file.url!)
                  : null,
            );
          },
        );
      },
    );
  }

  Widget _buildPagination(int currentCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Total: $_total'),
        Row(
          children: [
            IconButton(
              onPressed: _page > 0 ? _prevPage : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text('Página ${_page + 1}'),
            IconButton(
              onPressed: currentCount == _pageSize ? _nextPage : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }

  void _openUrl(BuildContext context, String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
