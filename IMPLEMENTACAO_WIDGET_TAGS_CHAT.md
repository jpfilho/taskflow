# Implementação: Widget de Seleção de Tags no Chat

## 📝 Código Completo para Integrar

### 1. Adicionar Variáveis de Estado no `_ChatScreenState`

```dart
class _ChatScreenState extends State<ChatScreen> {
  // ... variáveis existentes ...
  
  // Para tags Nota/Ordem
  String? _selectedRefType;  // 'GERAL' | 'NOTA' | 'ORDEM'
  String? _selectedRefId;     // UUID da nota ou ordem
  String? _selectedRefLabel;  // Label para exibição (ex: "NOTA 12345")
  
  // Listas de opções
  List<Map<String, dynamic>> _notasDisponiveis = [];
  List<Map<String, dynamic>> _ordensDisponiveis = [];
  bool _carregandoNotasOrdens = false;
  String? _taskId;  // ID da tarefa (obtido do grupo)
}
```

### 2. Método para Carregar Notas/Ordens

```dart
Future<void> _carregarNotasEOrdens() async {
  try {
    setState(() {
      _carregandoNotasOrdens = true;
    });
    
    // 1. Obter grupo para pegar tarefa_id
    final grupoResponse = await _supabase
        .from('grupos_chat')
        .select('tarefa_id')
        .eq('id', widget.grupoId)
        .maybeSingle();
    
    if (grupoResponse == null || grupoResponse['tarefa_id'] == null) {
      print('⚠️ [Chat] Grupo sem tarefa_id, não é possível carregar notas/ordens');
      return;
    }
    
    _taskId = grupoResponse['tarefa_id'] as String;
    
    // 2. Carregar notas da tarefa
    try {
      final notasResponse = await _supabase
          .from('tasks_notas_sap')
          .select('nota_sap_id, notas_sap(id, nota, descricao)')
          .eq('task_id', _taskId!);
      
      _notasDisponiveis = (notasResponse as List).map((item) {
        final nota = item['notas_sap'] as Map<String, dynamic>?;
        if (nota == null) return null;
        return {
          'id': item['nota_sap_id'],
          'nota': nota['nota'],
          'label': 'NOTA ${nota['nota']}',
          'descricao': nota['descricao'],
        };
      }).whereType<Map<String, dynamic>>().toList();
      
      print('✅ [Chat] Carregadas ${_notasDisponiveis.length} notas');
    } catch (e) {
      print('⚠️ [Chat] Erro ao carregar notas: $e');
      _notasDisponiveis = [];
    }
    
    // 3. Carregar ordens da tarefa
    try {
      final ordensResponse = await _supabase
          .from('tasks_ordens')
          .select('ordem_id, ordens(id, ordem, texto_breve)')
          .eq('task_id', _taskId!);
      
      _ordensDisponiveis = (ordensResponse as List).map((item) {
        final ordem = item['ordens'] as Map<String, dynamic>?;
        if (ordem == null) return null;
        return {
          'id': item['ordem_id'],
          'ordem': ordem['ordem'],
          'label': 'ORDEM ${ordem['ordem']}',
          'descricao': ordem['texto_breve'],
        };
      }).whereType<Map<String, dynamic>>().toList();
      
      print('✅ [Chat] Carregadas ${_ordensDisponiveis.length} ordens');
    } catch (e) {
      print('⚠️ [Chat] Erro ao carregar ordens: $e');
      _ordensDisponiveis = [];
    }
    
  } catch (e) {
    print('❌ [Chat] Erro ao carregar notas/ordens: $e');
  } finally {
    setState(() {
      _carregandoNotasOrdens = false;
    });
  }
}
```

### 3. Widget Badge de Tag

```dart
Widget _buildTagSelector() {
  // Se não tem task_id, não mostrar seletor
  if (_taskId == null) {
    return SizedBox.shrink();
  }
  
  return GestureDetector(
    onTap: () => _mostrarSeletorTag(),
    child: Container(
      margin: EdgeInsets.only(bottom: 8, left: 8, right: 8),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getTagColor(),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getTagIcon(), size: 16, color: Colors.white),
          SizedBox(width: 6),
          Text(
            _selectedRefLabel ?? 'GERAL',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 4),
          Icon(Icons.arrow_drop_down, size: 16, color: Colors.white),
        ],
      ),
    ),
  );
}

Color _getTagColor() {
  switch (_selectedRefType) {
    case 'NOTA':
      return Colors.blue;
    case 'ORDEM':
      return Colors.green;
    default:
      return Colors.grey;
  }
}

IconData _getTagIcon() {
  switch (_selectedRefType) {
    case 'NOTA':
      return Icons.push_pin;
    case 'ORDEM':
      return Icons.receipt;
    default:
      return Icons.chat_bubble_outline;
  }
}
```

### 4. Dialog de Seleção

```dart
Future<void> _mostrarSeletorTag() async {
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => _TagSelectorDialog(
      notasDisponiveis: _notasDisponiveis,
      ordensDisponiveis: _ordensDisponiveis,
      refTypeAtual: _selectedRefType,
      refIdAtual: _selectedRefId,
    ),
  );
  
  if (result != null) {
    setState(() {
      _selectedRefType = result['ref_type'];
      _selectedRefId = result['ref_id'];
      _selectedRefLabel = result['ref_label'];
    });
  }
}
```

### 5. Atualizar _enviarMensagem

```dart
Future<void> _enviarMensagem() async {
  final texto = _messageController.text.trim();
  if (texto.isEmpty) return;
  
  // ... código existente para obter nomeUsuario, userId, etc ...
  
  // Preparar payload com tags
  final payload = {
    'grupo_id': widget.grupoId,
    'conteudo': texto,
    'tipo': 'texto',
    'usuario_nome': nomeUsuario,
  };
  
  // Adicionar tags se selecionadas
  if (_selectedRefType != null && _selectedRefType != 'GERAL') {
    payload['ref_type'] = _selectedRefType;
    payload['ref_id'] = _selectedRefId;
    if (_selectedRefLabel != null) {
      payload['ref_label'] = _selectedRefLabel;
    }
  }
  
  // Enviar via ChatService (que já salva no Supabase e envia para Telegram)
  try {
    final mensagemEnviada = await _chatService.enviarMensagem(
      widget.grupoId,
      texto,
      usuarioNome: nomeUsuario,
      mensagemRespondidaId: mensagemRespondidaId,
      usuariosMencionados: usuariosMencionados.isNotEmpty ? usuariosMencionados : null,
      // Adicionar tags
      refType: _selectedRefType,
      refId: _selectedRefId,
      refLabel: _selectedRefLabel,
    );
    
    // Limpar campo (mas manter seleção de tag para próxima mensagem)
    _messageController.clear();
    _cancelarResposta();
    
    // ... resto do código existente ...
  } catch (e) {
    // ... tratamento de erro existente ...
  }
}
```

### 6. Integrar no build() - Antes do Campo de Input

```dart
// No método build, dentro do Column do input area:
child: Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    // Seletor de tag (badge) - ADICIONAR AQUI
    _buildTagSelector(),
    
    // Campo de input existente
    Row(
      children: [
        IconButton(...),
        Expanded(child: TextField(...)),
        IconButton(...),
        IconButton(...),
      ],
    ),
    
    // Emoji picker
    if (_mostrarEmojiPicker) ...,
  ],
),
```

### 7. Chamar _carregarNotasEOrdens no initState

```dart
@override
void initState() {
  super.initState();
  _loadMensagens();
  _carregarNotasEOrdens();  // ← ADICIONAR AQUI
}
```

### 8. Dialog Widget Completo (_TagSelectorDialog)

Criar arquivo separado: `lib/widgets/tag_selector_dialog.dart`

```dart
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
    return AlertDialog(
      title: Text('Vincular mensagem a'),
      content: SingleChildScrollView(
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar'),
        ),
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
      children: [
        Text('Selecionar Nota:', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Container(
          constraints: BoxConstraints(maxHeight: 200),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.notasDisponiveis.length,
            itemBuilder: (context, index) {
              final nota = widget.notasDisponiveis[index];
              final isSelected = _selectedId == nota['id'];
              
              return ListTile(
                leading: Icon(Icons.push_pin, color: Colors.blue),
                title: Text(nota['label']),
                subtitle: nota['descricao'] != null 
                    ? Text(nota['descricao'], maxLines: 1, overflow: TextOverflow.ellipsis)
                    : null,
                selected: isSelected,
                selectedTileColor: Colors.blue.withOpacity(0.1),
                onTap: () {
                  setState(() {
                    _selectedId = nota['id'];
                    _selectedLabel = nota['label'];
                  });
                },
              );
            },
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
      children: [
        Text('Selecionar Ordem:', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Container(
          constraints: BoxConstraints(maxHeight: 200),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.ordensDisponiveis.length,
            itemBuilder: (context, index) {
              final ordem = widget.ordensDisponiveis[index];
              final isSelected = _selectedId == ordem['id'];
              
              return ListTile(
                leading: Icon(Icons.receipt, color: Colors.green),
                title: Text(ordem['label']),
                subtitle: ordem['descricao'] != null 
                    ? Text(ordem['descricao'], maxLines: 1, overflow: TextOverflow.ellipsis)
                    : null,
                selected: isSelected,
                selectedTileColor: Colors.green.withOpacity(0.1),
                onTap: () {
                  setState(() {
                    _selectedId = ordem['id'];
                    _selectedLabel = ordem['label'];
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
```

### 9. Atualizar Import no chat_screen.dart

```dart
import 'tag_selector_dialog.dart';  // ← Adicionar
```

### 10. Atualizar _mostrarSeletorTag para usar o widget

```dart
Future<void> _mostrarSeletorTag() async {
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => TagSelectorDialog(  // ← Usar widget importado
      notasDisponiveis: _notasDisponiveis,
      ordensDisponiveis: _ordensDisponiveis,
      refTypeAtual: _selectedRefType,
      refIdAtual: _selectedRefId,
    ),
  );
  
  if (result != null) {
    setState(() {
      _selectedRefType = result['ref_type'];
      _selectedRefId = result['ref_id'];
      _selectedRefLabel = result['ref_label'];
    });
  }
}
```

## ✅ Checklist de Implementação

- [ ] Adicionar variáveis de estado
- [ ] Implementar `_carregarNotasEOrdens()`
- [ ] Criar widget `_buildTagSelector()`
- [ ] Criar arquivo `tag_selector_dialog.dart`
- [ ] Atualizar `_enviarMensagem()` para incluir tags
- [ ] Integrar badge no `build()` antes do campo de input
- [ ] Chamar `_carregarNotasEOrdens()` no `initState()`
- [ ] Testar carregamento de notas/ordens
- [ ] Testar seleção e envio com tag
- [ ] Verificar se aparece no Telegram com prefixo

## 🎯 Resultado Final

Após implementar, o usuário terá:

1. ✅ Badge clicável mostrando tag atual
2. ✅ Dialog intuitivo para selecionar tipo e nota/ordem
3. ✅ Mensagens enviadas com tags corretas
4. ✅ Tags aparecem no Telegram com prefixo bonito
5. ✅ Tags persistem entre mensagens (facilita uso)

Quer que eu implemente isso diretamente no código agora?
