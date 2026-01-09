import 'package:flutter/material.dart';
import '../models/comunidade.dart';
import '../services/chat_service.dart';
import '../services/task_service.dart';
import 'chat_comunidades_list.dart';
import 'chat_grupos_list.dart';
import 'chat_screen.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final ChatService _chatService = ChatService();
  final TaskService _taskService = TaskService();
  
  List<Comunidade> _comunidades = [];
  bool _isLoading = true;
  String? _selectedComunidadeId;
  String? _selectedGrupoId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Carregar todas as tarefas para obter combinações únicas de divisão + segmento
      final todasTarefas = await _taskService.getAllTasks();
      
      // Criar um mapa de combinações únicas de divisão + segmento
      final combinacoes = <String, Map<String, String>>{};
      
      for (var tarefa in todasTarefas) {
        if (tarefa.divisaoId != null && tarefa.segmentoId != null) {
          final key = '${tarefa.divisaoId}_${tarefa.segmentoId}';
          if (!combinacoes.containsKey(key)) {
            combinacoes[key] = {
              'divisaoId': tarefa.divisaoId!,
              'divisaoNome': tarefa.divisao,
              'segmentoId': tarefa.segmentoId!,
              'segmentoNome': tarefa.segmento,
            };
          }
        }
      }
      
      // Criar comunidades para cada combinação única
      for (var combinacao in combinacoes.values) {
        try {
          await _chatService.criarOuObterComunidade(
            combinacao['divisaoId']!,
            combinacao['divisaoNome']!,
            combinacao['segmentoId']!,
            combinacao['segmentoNome']!,
          );
        } catch (e) {
          print('Erro ao criar comunidade para ${combinacao['divisaoNome']} - ${combinacao['segmentoNome']}: $e');
        }
      }

      // Carregar comunidades
      final comunidades = await _chatService.listarComunidades();
      
      setState(() {
        _comunidades = comunidades;
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao carregar dados do chat: $e');
      setState(() => _isLoading = false);
    }
  }

  void _onComunidadeSelected(String? comunidadeId) {
    setState(() {
      _selectedComunidadeId = comunidadeId;
      _selectedGrupoId = null; // Resetar grupo selecionado
    });
  }

  void _onGrupoSelected(String grupoId) {
    setState(() {
      _selectedGrupoId = grupoId;
    });
  }

  void _onBack() {
    if (_selectedGrupoId != null) {
      setState(() {
        _selectedGrupoId = null;
      });
    } else if (_selectedComunidadeId != null) {
      setState(() {
        _selectedComunidadeId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Se um grupo está selecionado, mostrar tela de chat
    if (_selectedGrupoId != null) {
      return ChatScreen(
        grupoId: _selectedGrupoId!,
        onBack: _onBack,
      );
    }

    // Se uma comunidade está selecionada, mostrar lista de grupos
    if (_selectedComunidadeId != null) {
      return ChatGruposList(
        comunidadeId: _selectedComunidadeId!,
        onGrupoSelected: _onGrupoSelected,
        onBack: _onBack,
      );
    }

    // Mostrar lista de comunidades
    return ChatComunidadesList(
      comunidades: _comunidades,
      onComunidadeSelected: _onComunidadeSelected,
      onRefresh: _loadData,
    );
  }
}

