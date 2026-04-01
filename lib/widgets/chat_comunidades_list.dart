import 'package:flutter/material.dart';
import '../models/comunidade.dart';

class ChatComunidadesList extends StatelessWidget {
  final List<Comunidade> comunidades;
  final Map<String, int> unreadPerCommunity;
  final Function(String?) onComunidadeSelected;
  final VoidCallback onRefresh;

  const ChatComunidadesList({
    super.key,
    required this.comunidades,
    this.unreadPerCommunity = const {},
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
                final unread = unreadPerCommunity[comunidade.id] ?? 0;
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (unread > 0)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF25D366),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : unread.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => onComunidadeSelected(comunidade.id),
                );
              },
            ),
    );
  }
}
