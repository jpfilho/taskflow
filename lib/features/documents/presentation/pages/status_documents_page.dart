import 'package:flutter/material.dart';

import '../../data/models/document_status.dart';
import '../../data/repositories/supabase_documents_repository.dart';
import '../widgets/document_status_badge.dart';

class StatusDocumentsPage extends StatefulWidget {
  final SupabaseDocumentsRepository repository;

  const StatusDocumentsPage({
    super.key,
    required this.repository,
  });

  @override
  State<StatusDocumentsPage> createState() => _StatusDocumentsPageState();
}

class _StatusDocumentsPageState extends State<StatusDocumentsPage> {
  Future<List<DocumentStatus>>? _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.listStatuses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Status de Documentos'),
      ),
      body: FutureBuilder<List<DocumentStatus>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return const Center(child: Text('Nenhum status cadastrado.'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final status = list[index];
              return ListTile(
                title: Text(status.nome),
                subtitle: Text(status.descricao ?? ''),
                trailing: DocumentStatusBadge(status: status),
              );
            },
          );
        },
      ),
    );
  }
}
