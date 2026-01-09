import 'package:flutter/material.dart';
import '../models/comunidade.dart';

class ChatComunidadesList extends StatelessWidget {
  final List<Comunidade> comunidades;
  final Function(String?) onComunidadeSelected;
  final VoidCallback onRefresh;

  const ChatComunidadesList({
    super.key,
    required this.comunidades,
    required this.onComunidadeSelected,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comunidades'),
        backgroundColor: const Color(0xFF075E54), // Cor verde do WhatsApp
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: onRefresh,
          ),
        ],
      ),
      body: comunidades.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.groups,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma comunidade encontrada',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: comunidades.length,
              itemBuilder: (context, index) {
                final comunidade = comunidades[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF075E54),
                    child: Text(
                      comunidade.divisaoNome.isNotEmpty
                          ? comunidade.divisaoNome[0].toUpperCase()
                          : 'C',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    '${comunidade.divisaoNome} - ${comunidade.segmentoNome}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: comunidade.descricao != null
                      ? Text(comunidade.descricao!)
                      : Text(
                          '${comunidade.divisaoNome} • ${comunidade.segmentoNome}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onComunidadeSelected(comunidade.id),
                );
              },
            ),
    );
  }
}

