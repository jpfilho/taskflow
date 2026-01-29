import 'package:flutter/material.dart';

class TagSelectorDialog extends StatefulWidget {
  final List<Map<String, dynamic>> notasDisponiveis;
  final List<Map<String, dynamic>> ordensDisponiveis;
  final String? refTypeAtual;
  final String? refIdAtual;
  
  const TagSelectorDialog({
    Key? key,
    required this.notasDisponiveis,
    required this.ordensDisponiveis,
    this.refTypeAtual,
    this.refIdAtual,
  }) : super(key: key);
  
  @override
  State<TagSelectorDialog> createState() => _TagSelectorDialogState();
}

class _TagSelectorDialogState extends State<TagSelectorDialog> {
  String? _selectedType;
  String? _selectedId;
  String? _selectedLabel;
  
  @override
  void initState() {
    super.initState();
    _selectedType = widget.refTypeAtual ?? 'GERAL';
    _selectedId = widget.refIdAtual;
    
    // Se já tinha seleção, buscar label
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
    return Dialog(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
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
                    
                    SizedBox(height: 16),
                    
                    // Seleção de nota/ordem (se aplicável)
                    if (_selectedType == 'NOTA') _buildNotaSelector(),
                    if (_selectedType == 'ORDEM') _buildOrdemSelector(),
                  ],
                ),
              ),
            ),
            Divider(height: 1),
            // Actions
            Padding(
              padding: const EdgeInsets.all(8),
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
                        'ref_label': _selectedLabel,
                      });
                    },
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
        Text('Tipo:', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
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
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.grey[100],
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 24),
            SizedBox(height: 4),
            Text(
              type,
              style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNotaSelector() {
    if (widget.notasDisponiveis.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Nenhuma nota vinculada a esta tarefa',
          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Selecionar Nota:', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        // Usar Column com SingleChildScrollView ao invés de ListView para evitar problemas de layout
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 200),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: widget.notasDisponiveis.map((nota) {
                final isSelected = _selectedId == nota['id'];
                
                return Material(
                  color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                  child: ListTile(
                    leading: Icon(Icons.push_pin, color: Colors.blue),
                    title: Text(nota['label']),
                    subtitle: nota['descricao'] != null 
                        ? Text(nota['descricao'], maxLines: 1, overflow: TextOverflow.ellipsis)
                        : null,
                    trailing: isSelected ? Icon(Icons.check, color: Colors.blue) : null,
                    selected: isSelected,
                    onTap: () {
                      print('🔵 [TagDialog] Nota clicada: ${nota['label']}');
                      setState(() {
                        _selectedId = nota['id'];
                        _selectedLabel = nota['label'];
                        print('🔵 [TagDialog] Estado atualizado: _selectedId=${_selectedId}, _selectedLabel=${_selectedLabel}');
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildOrdemSelector() {
    if (widget.ordensDisponiveis.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Nenhuma ordem vinculada a esta tarefa',
          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Selecionar Ordem:', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        // Usar Column com SingleChildScrollView ao invés de ListView para evitar problemas de layout
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 200),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: widget.ordensDisponiveis.map((ordem) {
                final isSelected = _selectedId == ordem['id'];
                
                return Material(
                  color: isSelected ? Colors.green.withOpacity(0.1) : Colors.transparent,
                  child: ListTile(
                    leading: Icon(Icons.receipt, color: Colors.green),
                    title: Text(ordem['label']),
                    subtitle: ordem['descricao'] != null 
                        ? Text(ordem['descricao'], maxLines: 1, overflow: TextOverflow.ellipsis)
                        : null,
                    trailing: isSelected ? Icon(Icons.check, color: Colors.green) : null,
                    selected: isSelected,
                    onTap: () {
                      print('🟢 [TagDialog] Ordem clicada: ${ordem['label']}');
                      setState(() {
                        _selectedId = ordem['id'];
                        _selectedLabel = ordem['label'];
                        print('🟢 [TagDialog] Estado atualizado: _selectedId=${_selectedId}, _selectedLabel=${_selectedLabel}');
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
