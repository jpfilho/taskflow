import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../application/controllers/upload_controller.dart';
import '../../data/repositories/supabase_documents_repository.dart';
import '../../../../services/auth_service_simples.dart';

/// Página simples para upload. Integração com file picker deve ser
/// adicionada conforme plataforma (web/mobile/desktop). Por enquanto,
/// permite injetar um arquivo dummy para testar fluxo end-to-end.
class DocumentUploadPage extends StatefulWidget {
  final SupabaseDocumentsRepository repository;

  const DocumentUploadPage({super.key, required this.repository});

  @override
  State<DocumentUploadPage> createState() => _DocumentUploadPageState();
}

class _DocumentUploadPageState extends State<DocumentUploadPage> {
  late final DocumentUploadController controller;
  final TextEditingController titleController = TextEditingController();
  final TextEditingController tagsController = TextEditingController();
  String? _regionalId;
  String? _divisaoId;
  String? _localId;
  String? _regionalNome;
  String? _divisaoNome;
  String? _localNome;
  bool uploading = false;

  @override
  void initState() {
    super.initState();
    controller = DocumentUploadController(widget.repository);
    final user = AuthServiceSimples().currentUser;
    if (user != null) {
      if (user.regionalIds.isNotEmpty) _regionalId = user.regionalIds.first;
      if (user.divisaoIds.isNotEmpty) _divisaoId = user.divisaoIds.first;
      if (user.regionais.isNotEmpty) _regionalNome = user.regionais.first;
      if (user.divisoes.isNotEmpty) _divisaoNome = user.divisoes.first;
      // local_id não vem do perfil; permanece nulo
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;
    final items = result.files
        .where((f) => f.bytes != null && f.name.isNotEmpty)
        .map(
          (f) => DocumentUploadItem(
            fileName: f.name,
            bytes: f.bytes!,
          ),
        )
        .toList();
    if (items.isEmpty) return;
    controller.addFiles(items);
  }

  Future<void> _upload() async {
    final user = AuthServiceSimples().currentUser;
    if (user == null || user.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para enviar documentos.')),
      );
      return;
    }
    final userId = user.id!;
    setState(() => uploading = true);
    await controller.uploadAll(
      userId: userId,
      regionalId: _regionalId,
      divisaoId: _divisaoId,
      localId: _localId,
      segmentId: user.segmentoIds.isNotEmpty ? user.segmentoIds.first : null,
      titlePrefix: titleController.text.isEmpty ? null : titleController.text,
      tags: tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    );
    setState(() => uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload de Documentos'),
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: titleController,
                            decoration: const InputDecoration(
                              labelText: 'Título (prefixo opcional)',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: tagsController,
                            decoration: const InputDecoration(
                              labelText: 'Tags (separadas por vírgula)',
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildPerfilInfo(),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: uploading ? null : _pickFiles,
                                icon: const Icon(Icons.attach_file),
                                label: const Text('Selecionar arquivos'),
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: uploading ? null : _upload,
                                icon: const Icon(Icons.cloud_upload),
                                label: const Text('Enviar'),
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'IDs herdados do perfil (primeiro da lista). Bucket público.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                    child: SizedBox(
                      height: 280,
                      child: AnimatedBuilder(
                        animation: controller,
                        builder: (context, _) {
                          final items = controller.uploads;
                          if (items.isEmpty) {
                            return const Center(child: Text('Nenhum arquivo na fila'));
                          }
                          return ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return ListTile(
                                title: Text(item.fileName),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    LinearProgressIndicator(
                                      value: item.progress,
                                      minHeight: 6,
                                    ),
                                    if (item.error != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        item.error.toString(),
                                        style: const TextStyle(color: Colors.red, fontSize: 12),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: item.created != null
                                    ? const Icon(Icons.check, color: Colors.green)
                                    : item.error != null
                                        ? const Icon(Icons.error, color: Colors.red)
                                        : null,
                              );
                            },
                          );
                        },
                      ),
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

  Widget _buildPerfilInfo() {
    final chips = <Widget>[];
    if (_regionalId != null) {
      chips.add(Chip(
        label: Text('Regional: ${_regionalNome ?? _regionalId}'),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ));
    }
    if (_divisaoId != null) {
      chips.add(Chip(
        label: Text('Divisão: ${_divisaoNome ?? _divisaoId}'),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ));
    }
    if (_localId != null) {
      chips.add(Chip(
        label: Text('Local: ${_localNome ?? _localId}'),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ));
    }
    if (chips.isEmpty) {
      return const Text(
        'Perfil: sem regional/divisão/local configurados. Configure o perfil do usuário no backend.',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: -6,
      children: chips,
    );
  }
}
