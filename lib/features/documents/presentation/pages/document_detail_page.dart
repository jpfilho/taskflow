import 'package:flutter/material.dart';

import '../../data/models/document.dart';
import '../../data/models/document_version.dart';
import '../../data/repositories/supabase_documents_repository.dart';
import '../widgets/document_status_badge.dart';

class DocumentDetailPage extends StatefulWidget {
  final String documentId;
  final SupabaseDocumentsRepository repository;

  const DocumentDetailPage({
    super.key,
    required this.documentId,
    required this.repository,
  });

  @override
  State<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends State<DocumentDetailPage> {
  Future<Document>? _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.getDocumentById(widget.documentId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhe do Documento'),
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: FutureBuilder<Document>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erro: ${snapshot.error}'));
                }
                final doc = snapshot.data;
                if (doc == null) {
                  return const Center(child: Text('Documento não encontrado'));
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  doc.title,
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                              ),
                              DocumentStatusBadge(status: doc.statusDocument),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (doc.description != null && doc.description!.isNotEmpty)
                            Text(doc.description!),
                          const SizedBox(height: 8),
                          Text('MIME: ${doc.file.mimeType}'),
                          if (doc.file.extension != null) Text('Extensão: ${doc.file.extension}'),
                          if (doc.file.size != null) Text('Tamanho: ${doc.file.size} bytes'),
                          if (doc.hierarchyPath.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('Hierarquia: ${doc.hierarchyPath}'),
                          ],
                          const SizedBox(height: 8),
                          if (doc.tags.isNotEmpty)
                            Wrap(
                              spacing: 6,
                              runSpacing: -6,
                              children: doc.tags
                                  .map((t) => Chip(
                                        label: Text(t),
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ))
                                  .toList(),
                            ),
                          const SizedBox(height: 16),
                          Text(
                            'Versões',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (doc.versions == null || doc.versions!.isEmpty)
                            const Text('Nenhuma versão registrada')
                          else
                            Column(
                              children: doc.versions!
                                  .map((v) => _VersionTile(
                                        version: v,
                                        onDownload: v.fileUrl != null
                                            ? () => _openUrl(context, v.fileUrl!)
                                            : null,
                                      ))
                                  .toList(),
                            ),
                          const SizedBox(height: 16),
                          if (doc.file.url != null)
                            ElevatedButton.icon(
                              onPressed: () => _openUrl(context, doc.file.url!),
                              icon: const Icon(Icons.download),
                              label: const Text('Baixar versão atual'),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _openUrl(BuildContext context, String url) {
    // Placeholder: usar url_launcher em apps finais.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Abrir/baixar: $url')),
    );
  }
}

class _VersionTile extends StatelessWidget {
  final DocumentVersion version;
  final VoidCallback? onDownload;

  const _VersionTile({
    required this.version,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.description),
      title: Text('Versão ${version.version}'),
      subtitle: Text(
          'MIME: ${version.mimeType} • Tamanho: ${version.fileSize ?? 0} • ${version.createdAt.toLocal()}'),
      trailing: onDownload != null
          ? IconButton(
              icon: const Icon(Icons.download),
              onPressed: onDownload,
            )
          : null,
    );
  }
}
