import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../design_system/components/buttons/tf_button.dart';
import '../../../../design_system/components/buttons/tf_icon_button.dart';
import '../../../../design_system/components/feedback/tf_empty_state.dart';
import '../../../../design_system/components/feedback/tf_loading.dart';
import '../../../../design_system/components/inputs/tf_text_field.dart';
import '../../../../design_system/components/layout/tf_page_header.dart';
import '../../../../design_system/foundations/tf_breakpoints.dart';
import '../../../../design_system/foundations/tf_icons.dart';
import '../../../../design_system/foundations/tf_radius.dart';
import '../../../../design_system/theme/taskflow_theme_extension.dart';
import '../../data/models/document.dart';
import '../../data/models/document_status.dart';
import '../../data/repositories/supabase_documents_repository.dart';
import '../widgets/document_card.dart';
import 'document_detail_page.dart';
import 'document_upload_page.dart';
import 'status_documents_page.dart';

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
    final colors = context.tfColors;
    final spacing = context.tfSpacing;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            TFPageHeader(
              title: 'Gestão de Documentos',
              subtitle: 'Consulte, filtre e gerencie os documentos técnicos e operacionais.',
              primaryAction: TFButton(
                label: 'Upload de Documento',
                leadingIcon: TFIcons.add,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DocumentUploadPage(repository: _repo),
                    ),
                  ).then((_) => _load());
                },
              ),
              secondaryActions: [
                TFButton(
                  label: 'Status',
                  variant: TFButtonVariant.secondary,
                  leadingIcon: Icons.tune_rounded,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StatusDocumentsPage(repository: _repo),
                      ),
                    );
                  },
                ),
                TFIconButton(
                  icon: TFIcons.refresh,
                  tooltip: 'Atualizar Lista',
                  onPressed: _load,
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.xs),
              child: _buildSearchAndFilters(context),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.md),
                child: _buildContent(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(BuildContext context) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TFTextField(
                controller: _searchController,
                hint: 'Buscar por título, descrição ou autor...',
                prefixIcon: const Icon(TFIcons.search),
                onChanged: (val) {
                  setState(() {
                    _search = val;
                    _page = 0;
                  });
                  _load();
                },
              ),
            ),
            if (_statuses.isNotEmpty) ...[
              SizedBox(width: spacing.sm),
              PopupMenuButton<String?>(
                tooltip: 'Filtrar por Status',
                initialValue: _selectedStatusId,
                color: colors.surface,
                icon: Container(
                  padding: EdgeInsets.all(spacing.xs),
                  decoration: BoxDecoration(
                    color: _selectedStatusId != null ? colors.primary.withValues(alpha: 0.12) : colors.surface,
                    borderRadius: TFRadius.borderRadiusMd,
                    border: Border.all(
                      color: _selectedStatusId != null ? colors.primary : colors.borderSubtle,
                    ),
                  ),
                  child: Icon(
                    Icons.filter_list_rounded,
                    color: _selectedStatusId != null ? colors.primary : colors.textSecondary,
                    size: 20,
                  ),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem<String?>(
                    value: null,
                    child: Text('Todos os Status', style: typography.bodyMedium),
                  ),
                  ..._statuses.map(
                    (s) => PopupMenuItem<String?>(
                      value: s.id,
                      child: Text(s.nome, style: typography.bodyMedium),
                    ),
                  ),
                ],
                onSelected: (val) {
                  setState(() {
                    _selectedStatusId = val;
                    _page = 0;
                  });
                  _load();
                },
              ),
            ],
          ],
        ),
        SizedBox(height: spacing.xs),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _formatChip(context, 'Todos os Formatos', null),
              ..._mimeOptions.map((m) => _formatChip(context, m.toUpperCase(), m)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _formatChip(BuildContext context, String label, String? mime) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;
    final isSelected = _selectedMime == mime;

    return Padding(
      padding: EdgeInsets.only(right: spacing.xs),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMime = mime;
          });
        },
        borderRadius: TFRadius.borderRadiusFull,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xxs),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary.withValues(alpha: 0.15) : colors.surface,
            borderRadius: TFRadius.borderRadiusFull,
            border: Border.all(
              color: isSelected ? colors.primary : colors.borderSubtle,
            ),
          ),
          child: Text(
            label,
            style: typography.caption.copyWith(
              color: isSelected ? colors.primary : colors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading) {
      return const Center(child: TFLoading(message: 'Carregando documentos...'));
    }
    if (_error != null) {
      return Center(
        child: TFEmptyState(
          title: 'Erro ao carregar documentos',
          description: _error!,
          icon: TFIcons.warning,
          action: TFButton(
            label: 'Tentar Novamente',
            leadingIcon: TFIcons.refresh,
            onPressed: _load,
          ),
        ),
      );
    }
    final docs = _filteredDocs;
    if (docs.isEmpty) {
      return Center(
        child: TFEmptyState(
          title: _search.isNotEmpty || _selectedStatusId != null || _selectedMime != null
              ? 'Nenhum documento encontrado'
              : 'Nenhum documento cadastrado',
          description: _search.isNotEmpty || _selectedStatusId != null || _selectedMime != null
              ? 'Tente ajustar os filtros ou termos de pesquisa aplicados.'
              : 'Envie manuais, relatórios ou procedimentos para a biblioteca digital.',
          icon: Icons.folder_open_rounded,
          action: TFButton(
            label: 'Upload de Documento',
            leadingIcon: TFIcons.add,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DocumentUploadPage(repository: _repo),
                ),
              ).then((_) => _load());
            },
          ),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= TFBreakpoints.md;
              final isTablet = constraints.maxWidth >= TFBreakpoints.sm && !isDesktop;
              final crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 1);

              return GridView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: isDesktop ? 2.4 : (isTablet ? 2.2 : 1.8),
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
                      ).then((_) => _load());
                    },
                    onDownload: doc.file.url != null
                        ? () => _openUrl(context, doc.file.url!)
                        : null,
                  );
                },
              );
            },
          ),
        ),
        _buildPagination(context, docs.length),
      ],
    );
  }

  Widget _buildPagination(BuildContext context, int currentCount) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total: $_total documentos',
            style: typography.caption.copyWith(color: colors.textSecondary),
          ),
          Row(
            children: [
              TFIconButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Página Anterior',
                onPressed: _page > 0 ? _prevPage : null,
              ),
              SizedBox(width: spacing.xs),
              Text(
                'Página ${_page + 1}',
                style: typography.caption.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: spacing.xs),
              TFIconButton(
                icon: Icons.chevron_right_rounded,
                tooltip: 'Próxima Página',
                onPressed: currentCount == _pageSize ? _nextPage : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openUrl(BuildContext context, String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
