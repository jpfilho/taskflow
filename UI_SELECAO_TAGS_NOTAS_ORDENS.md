# UI/UX: Seleção de Tags Nota/Ordem

## 🎨 Proposta de Interface

### Layout Visual

```
┌─────────────────────────────────────────┐
│  [Chat Messages]                        │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │ 💬 GERAL                          │ │ ← Badge da tag selecionada
│  │ [Botão para mudar tag]            │ │
│  └───────────────────────────────────┘ │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │ [📎] [Campo de texto...] [😀] [📤]│ │
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

### Fluxo do Usuário

1. **Usuário abre o chat** → Sistema carrega notas/ordens da tarefa automaticamente
2. **Usuário clica no badge/tag** → Abre seletor
3. **Usuário seleciona tipo** (Geral/Nota/Ordem)
4. **Se selecionar Nota/Ordem** → Mostra dropdown com opções
5. **Usuário seleciona nota/ordem específica** → Badge atualiza
6. **Usuário digita e envia** → Mensagem vai com tag

## 💻 Implementação Flutter

### 1. Adicionar Variáveis de Estado

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

### 2. Carregar Notas/Ordens ao Abrir Chat

```dart
Future<void> _carregarNotasEOrdens() async {
  try {
    setState(() {
      _carregandoNotasOrdens = true;
    });
    
    // 1. Obter task_id do grupo
    final grupo = await _chatService.obterGrupo(widget.grupoId);
    if (grupo?.tarefaId == null) {
      print('⚠️ [Chat] Grupo sem tarefa_id, não é possível carregar notas/ordens');
      return;
    }
    
    _taskId = grupo!.tarefaId;
    
    // 2. Carregar notas da tarefa
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
    
    // 3. Carregar ordens da tarefa
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
    
    print('✅ [Chat] Carregadas ${_notasDisponiveis.length} notas e ${_ordensDisponiveis.length} ordens');
    
  } catch (e) {
    print('❌ [Chat] Erro ao carregar notas/ordens: $e');
  } finally {
    setState(() {
      _carregandoNotasOrdens = false;
    });
  }
}
```

### 3. Widget Seletor de Tag (Badge + Dialog)

```dart
Widget _buildTagSelector() {
  // Se não tem task_id, não mostrar seletor
  if (_taskId == null) {
    return SizedBox.shrink();
  }
  
  return GestureDetector(
    onTap: () => _mostrarSeletorTag(),
    child: Container(
      margin: EdgeInsets.only(bottom: 8),
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

### 5. Dialog Widget Completo

```dart
class _TagSelectorDialog extends StatefulWidget {
  final List<Map<String, dynamic>> notasDisponiveis;
  final List<Map<String, dynamic>> ordensDisponiveis;
  final String? refTypeAtual;
  final String? refIdAtual;
  
  const _TagSelectorDialog({
    required this.notasDisponiveis,
    required this.ordensDisponiveis,
    this.refTypeAtual,
    this.refIdAtual,
  });
  
  @override
  State<_TagSelectorDialog> createState() => _TagSelectorDialogState();
}

class _TagSelectorDialogState extends State<_TagSelectorDialog> {
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
      _selectedLabel = nota['label'];
    } else if (_selectedType == 'ORDEM' && _selectedId != null) {
      final ordem = widget.ordensDisponiveis.firstWhere(
        (o) => o['id'] == _selectedId,
        orElse: () => {},
      );
      _selectedLabel = ordem['label'];
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

### 6. Integrar no Chat Screen

```dart
// No método build, antes do campo de input:
child: Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    // Seletor de tag (badge)
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

### 7. Atualizar _enviarMensagem

```dart
Future<void> _enviarMensagem() async {
  final texto = _messageController.text.trim();
  if (texto.isEmpty) return;
  
  // ... código existente ...
  
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
  
  // Enviar via Node.js (atualizar telegram_service.dart)
  await _telegramService.sendMessage(payload);
  
  // Limpar campo e resetar tag (opcional - manter seleção)
  _messageController.clear();
  // setState(() {
  //   _selectedRefType = null;
  //   _selectedRefId = null;
  //   _selectedRefLabel = null;
  // });
}
```

### 8. Chamar _carregarNotasEOrdens no initState

```dart
@override
void initState() {
  super.initState();
  _loadMensagens();
  _carregarNotasEOrdens();  // ← Adicionar aqui
}
```

## 🎨 Alternativa: UI Mais Compacta

Se preferir uma UI mais compacta, pode usar um **DropdownButton** diretamente:

```dart
Widget _buildTagSelectorCompacto() {
  if (_taskId == null) return SizedBox.shrink();
  
  return Container(
    margin: EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        // Dropdown de tipo
        Expanded(
          child: DropdownButton<String>(
            value: _selectedRefType ?? 'GERAL',
            isExpanded: true,
            items: [
              DropdownMenuItem(value: 'GERAL', child: Text('💬 Geral')),
              DropdownMenuItem(value: 'NOTA', child: Text('📌 Nota')),
              DropdownMenuItem(value: 'ORDEM', child: Text('🧾 Ordem')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedRefType = value;
                _selectedRefId = null;
                _selectedLabel = null;
              });
            },
          ),
        ),
        
        // Dropdown de nota/ordem (se aplicável)
        if (_selectedRefType == 'NOTA' && _notasDisponiveis.isNotEmpty)
          Expanded(
            child: DropdownButton<String>(
              value: _selectedId,
              isExpanded: true,
              hint: Text('Selecionar Nota'),
              items: _notasDisponiveis.map((nota) {
                return DropdownMenuItem(
                  value: nota['id'],
                  child: Text(nota['label']),
                );
              }).toList(),
              onChanged: (value) {
                final nota = _notasDisponiveis.firstWhere((n) => n['id'] == value);
                setState(() {
                  _selectedId = value;
                  _selectedLabel = nota['label'];
                });
              },
            ),
          ),
        
        if (_selectedRefType == 'ORDEM' && _ordensDisponiveis.isNotEmpty)
          Expanded(
            child: DropdownButton<String>(
              value: _selectedId,
              isExpanded: true,
              hint: Text('Selecionar Ordem'),
              items: _ordensDisponiveis.map((ordem) {
                return DropdownMenuItem(
                  value: ordem['id'],
                  child: Text(ordem['label']),
                );
              }).toList(),
              onChanged: (value) {
                final ordem = _ordensDisponiveis.firstWhere((o) => o['id'] == value);
                setState(() {
                  _selectedId = value;
                  _selectedLabel = ordem['label'];
                });
              },
            ),
          ),
      ],
    ),
  );
}
```

## 📱 Exibição da Tag nas Mensagens

```dart
Widget _buildMensagemWidget(Mensagem mensagem) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Badge da tag (se houver)
      if (mensagem.refType != null && mensagem.refType != 'GERAL')
        Container(
          margin: EdgeInsets.only(bottom: 4),
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: mensagem.refType == 'NOTA' ? Colors.blue : Colors.green,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            mensagem.refLabel ?? mensagem.refType!,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      
      // Mensagem normal
      _buildMensagemContent(mensagem),
    ],
  );
}
```

## ✅ Vantagens desta Abordagem

1. **Intuitivo:** Badge clicável mostra claramente a tag selecionada
2. **Não ocupa espaço:** Badge aparece apenas quando necessário
3. **Feedback visual:** Cores diferentes para cada tipo (azul=Nota, verde=Ordem, cinza=Geral)
4. **Carregamento automático:** Notas/ordens carregam ao abrir o chat
5. **Compatível:** Se não houver notas/ordens, não mostra opções

## 🎯 Próximos Passos

1. Adicionar variáveis de estado no `_ChatScreenState`
2. Implementar `_carregarNotasEOrdens()`
3. Criar widget `_buildTagSelector()`
4. Criar dialog `_TagSelectorDialog`
5. Atualizar `_enviarMensagem()` para incluir tags
6. Atualizar `telegram_service.dart` para enviar tags
7. Atualizar modelo `Mensagem` para incluir campos de tag
8. Exibir badge nas mensagens enviadas

Quer que eu implemente isso diretamente no código do `chat_screen.dart`?
