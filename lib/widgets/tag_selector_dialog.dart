import 'package:flutter/material.dart';

class TagSelectorDialog extends StatefulWidget {
  final List<Map<String, dynamic>> notasDisponiveis;
  final List<Map<String, dynamic>> ordensDisponiveis;
  final String? refTypeAtual;
  final String? refIdAtual;
  
  const TagSelectorDialog({
    super.key,
    required this.notasDisponiveis,
    required this.ordensDisponiveis,
    this.refTypeAtual,
    this.refIdAtual,
  });
  
  @override
  State<TagSelectorDialog> createState() => _TagSelectorDialogState();
}

class _TagSelectorDialogState extends State<TagSelectorDialog> {
  String? _selectedType;
  String? _selectedId;
  String? _selectedLabel;
  bool? _selectedExecutado;
  
  @override
  void initState() {
    super.initState();
    _selectedType = widget.refTypeAtual ?? 'GERAL';
    _selectedId = widget.refIdAtual;
    
    if (_selectedType == 'NOTA' && _selectedId != null) {
      final nota = widget.notasDisponiveis.firstWhere(
        (n) => n['id'] == _selectedId,
        orElse: () => {},
      );
      if (nota.isNotEmpty) {
        _selectedLabel = nota['label'];
      }
    } else if (_selectedType == 'ORDEM' && _selectedId != null) {
      final ordem = widget.ordensDisponiveis.firstWhere(
        (o) => o['id'] == _selectedId,
        orElse: () => {},
      );
      if (ordem.isNotEmpty) {
        _selectedLabel = ordem['label'];
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Definimos max width maior para suportar a tabela
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isMobile ? screenWidth * 0.95 : 800,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Vincular mensagem a',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Seleção de tipo
                    _buildTypeSelector(),
                    
                    if (_selectedType != 'GERAL') ...[
                      SizedBox(height: 24),
                      // Seleção do Status Executado
                      _buildExecutadoSelector(),
                      SizedBox(height: 24),
                      // Seleção de nota/ordem
                      if (_selectedType == 'NOTA') _buildNotaTable(),
                      if (_selectedType == 'ORDEM') _buildOrdemTable(),
                    ],
                  ],
                ),
              ),
            ),
            Divider(height: 1),
            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancelar'),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, {
                        'ref_type': _selectedType ?? 'GERAL',
                        'ref_id': _selectedType == 'GERAL' ? null : _selectedId,
                        'ref_label': _selectedType == 'GERAL' ? null : _selectedLabel,
                        'ref_executado': _selectedType == 'GERAL' ? null : _selectedExecutado,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text('Confirmar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tipo:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTypeChip('GERAL', Icons.chat_bubble_outline, Colors.grey),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _buildTypeChip('NOTA', Icons.push_pin, Colors.blue),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _buildTypeChip('ORDEM', Icons.receipt, Colors.green),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildTypeChip(String type, IconData icon, Color color) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
          _selectedId = null;
          _selectedLabel = null;
          if (type == 'GERAL') {
            _selectedExecutado = null;
          }
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.grey[100],
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 28),
            SizedBox(height: 8),
            Text(
              type,
              style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutadoSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Status: Executado?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        SizedBox(height: 12),
        Row(
          children: [
            _buildRadioOption('Sim', true, Colors.green),
            SizedBox(width: 16),
            _buildRadioOption('Não', false, Colors.red),
            SizedBox(width: 16),
            _buildRadioOption('Não aplicável', null, Colors.grey),
          ],
        )
      ],
    );
  }

  Widget _buildRadioOption(String label, bool? value, Color activeColor) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedExecutado = value;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<bool?>(
            value: value,
            groupValue: _selectedExecutado,
            activeColor: activeColor,
            onChanged: (val) {
              setState(() {
                _selectedExecutado = val;
              });
            },
          ),
          Text(label, style: TextStyle(fontSize: 14)),
          SizedBox(width: 8),
        ],
      ),
    );
  }
  
  Widget _buildNotaTable() {
    if (widget.notasDisponiveis.isEmpty) {
      return _buildEmptyState('Nenhuma nota vinculada a esta tarefa');
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Selecionar Nota:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        SizedBox(height: 12),
        _buildResponsiveTable(
          items: widget.notasDisponiveis,
          columns: ['Sala', 'Nota', 'Descrição', 'Selecionar'],
          color: Colors.blue,
        ),
      ],
    );
  }
  
  Widget _buildOrdemTable() {
    if (widget.ordensDisponiveis.isEmpty) {
      return _buildEmptyState('Nenhuma ordem vinculada a esta tarefa');
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Selecionar Ordem:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        SizedBox(height: 12),
        _buildResponsiveTable(
          items: widget.ordensDisponiveis,
          columns: ['Sala', 'Ordem', 'Descrição', 'Selecionar'],
          color: Colors.green,
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildResponsiveTable({
    required List<Map<String, dynamic>> items,
    required List<String> columns,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.resolveWith((states) => Colors.grey[100]),
            dataRowMaxHeight: 60,
            dataRowMinHeight: 48,
            columns: columns.map((col) => DataColumn(
              label: Text(col, style: TextStyle(fontWeight: FontWeight.bold)),
            )).toList(),
            rows: items.map((item) {
              final isSelected = _selectedId == item['id'];
              
              return DataRow(
                color: WidgetStateProperty.resolveWith(
                  (states) => isSelected ? color.withOpacity(0.15) : Colors.transparent
                ),
                cells: [
                  DataCell(Text(item['sala']?.toString() ?? '-')),
                  DataCell(Text(item['label'] ?? '-')),
                  DataCell(
                    Container(
                      constraints: BoxConstraints(maxWidth: 300),
                      child: Text(
                        item['descricao']?.toString() ?? '-',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected ? color : Colors.white,
                        foregroundColor: isSelected ? Colors.white : Colors.black87,
                        side: BorderSide(color: isSelected ? color : Colors.grey[400]!),
                        elevation: 0,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedId = item['id'];
                          _selectedLabel = item['label'];
                        });
                      },
                      child: Text(isSelected ? 'Selecionado' : 'Selecionar'),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
