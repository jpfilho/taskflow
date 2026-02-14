import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../features/documents/presentation/pages/documents_page.dart';

class DocumentsView extends StatefulWidget {
  const DocumentsView({super.key});

  @override
  State<DocumentsView> createState() => _DocumentsViewState();
}

class _DocumentsViewState extends State<DocumentsView> {
  String _selectedCategory = 'Todos';
  final List<String> _categories = ['Todos', 'Manutenção', 'Treinamento', 'Relatórios', 'Frotas', 'Equipes'];
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Column(
      children: [
        _buildHeader(isMobile),
        _buildFilters(isMobile),
        Expanded(
          child: _buildDocumentsList(isMobile),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.description, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Gestão de Documentos',
              style: TextStyle(
                fontSize: isMobile ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E3A5F),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, color: Color(0xFF1E3A5F)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DocumentsPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      color: Colors.grey[50],
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar documentos...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    backgroundColor: Colors.white,
                    selectedColor: const Color(0xFF1E3A5F).withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xFF1E3A5F) : Colors.grey[700],
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsList(bool isMobile) {
    // Mock documents - em produção viria do service
    final documents = _getMockDocuments();

    if (documents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nenhum documento encontrado',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final doc = documents[index];
        return _buildDocumentCard(doc, isMobile);
      },
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> doc, bool isMobile) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Abrindo: ${doc['name']}')),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getCategoryColor(doc['category'] as String).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getDocumentIcon(doc['type'] as String),
                  color: _getCategoryColor(doc['category'] as String),
                  size: isMobile ? 24 : 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc['name'] as String,
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.folder, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          doc['category'] as String,
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          doc['date'] as String,
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () {
                  _showDocumentMenu(context, doc);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDocumentMenu(BuildContext context, Map<String, dynamic> doc) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Download'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Download iniciado')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Compartilhar'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Compartilhando...')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Excluir', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Documento excluído')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _getDocumentIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'word':
        return Icons.description;
      case 'excel':
        return Icons.table_chart;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Manutenção':
        return Colors.blue;
      case 'Treinamento':
        return Colors.green;
      case 'Relatórios':
        return Colors.orange;
      case 'Frotas':
        return Colors.purple;
      case 'Equipes':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  List<Map<String, dynamic>> _getMockDocuments() {
    return [
      {
        'name': 'Relatório Mensal - Dezembro 2025',
        'category': 'Relatórios',
        'type': 'PDF',
        'date': '15/12/2025',
      },
      {
        'name': 'Manual de Manutenção Preventiva',
        'category': 'Manutenção',
        'type': 'PDF',
        'date': '10/12/2025',
      },
      {
        'name': 'Planejamento de Treinamentos 2026',
        'category': 'Treinamento',
        'type': 'Word',
        'date': '08/12/2025',
      },
      {
        'name': 'Controle de Frota - Q4 2025',
        'category': 'Frotas',
        'type': 'Excel',
        'date': '05/12/2025',
      },
      {
        'name': 'Distribuição de Equipes',
        'category': 'Equipes',
        'type': 'PDF',
        'date': '01/12/2025',
      },
    ];
  }
}












