import 'package:flutter/material.dart';
import '../services/auth_service_simples.dart';
import '../services/usuario_service.dart';
import '../services/regional_service.dart';
import '../services/divisao_service.dart';
import '../services/segmento_service.dart';
import '../models/regional.dart';
import '../models/divisao.dart';
import '../models/segmento.dart';

class PerfilUsuarioView extends StatefulWidget {
  const PerfilUsuarioView({super.key});

  @override
  State<PerfilUsuarioView> createState() => _PerfilUsuarioViewState();
}

class _PerfilUsuarioViewState extends State<PerfilUsuarioView> {
  final AuthServiceSimples _authService = AuthServiceSimples();
  final UsuarioService _usuarioService = UsuarioService();
  final RegionalService _regionalService = RegionalService();
  final DivisaoService _divisaoService = DivisaoService();
  final SegmentoService _segmentoService = SegmentoService();

  bool _isLoading = true;
  bool _isSaving = false;
  
  Usuario? _usuario;
  List<Regional> _todasRegionais = [];
  List<Divisao> _todasDivisoes = [];
  List<Segmento> _todosSegmentos = [];
  
  Set<String> _selectedRegionalIds = {};
  Set<String> _selectedDivisaoIds = {};
  Set<String> _selectedSegmentoIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Carregar usuário atual
      final usuario = _authService.currentUser;
      if (usuario == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Usuário não autenticado')),
          );
          Navigator.pop(context);
        }
        return;
      }

      // Recarregar usuário com perfil completo
      final usuarioCompleto = await _usuarioService.obterUsuarioPorId(usuario.id!);
      if (usuarioCompleto == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao carregar perfil do usuário')),
          );
        }
        return;
      }

      // Carregar todas as opções disponíveis
      final regionais = await _regionalService.getAllRegionais();
      final divisoes = await _divisaoService.getAllDivisoes();
      final segmentos = await _segmentoService.getAllSegmentos();

      setState(() {
        _usuario = usuarioCompleto;
        _todasRegionais = regionais;
        _todasDivisoes = divisoes;
        _todosSegmentos = segmentos;
        
        // Inicializar seleções com o perfil atual
        _selectedRegionalIds = Set.from(usuarioCompleto.regionalIds);
        _selectedDivisaoIds = Set.from(usuarioCompleto.divisaoIds);
        _selectedSegmentoIds = Set.from(usuarioCompleto.segmentoIds);
        
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao carregar dados: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _salvarPerfil() async {
    if (_usuario == null || _usuario!.id == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Remover todas as associações antigas
      await _usuarioService.removerPerfilCompleto(_usuario!.id!);

      // Adicionar novas associações
      await _usuarioService.atualizarPerfil(
        usuarioId: _usuario!.id!,
        regionalIds: _selectedRegionalIds.toList(),
        divisaoIds: _selectedDivisaoIds.toList(),
        segmentoIds: _selectedSegmentoIds.toList(),
      );

      // Recarregar usuário atualizado
      final usuarioAtualizado = await _usuarioService.obterUsuarioPorId(_usuario!.id!);
      if (usuarioAtualizado != null) {
        print('✅ Perfil atualizado carregado:');
        print('   Regional IDs: ${usuarioAtualizado.regionalIds}');
        print('   Divisão IDs: ${usuarioAtualizado.divisaoIds}');
        print('   Segmento IDs: ${usuarioAtualizado.segmentoIds}');
        
        // Atualizar no AuthService e no cache (para não perder perfil ao voltar para atividades)
        await _authService.atualizarUsuarioAtual(usuarioAtualizado);
        print('✅ Usuário atualizado no AuthService e no cache');
      } else {
        print('❌ Erro: Não foi possível recarregar o usuário atualizado');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil salvo com sucesso! Recarregue a tela para ver as tarefas.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Recarregar dados do perfil
        await _loadData();
        
        // Navegar de volta e passar resultado para recarregar tarefas
        if (context.mounted) {
          Navigator.pop(context, true); // true indica que o perfil foi atualizado
        }
      }
    } catch (e) {
      print('Erro ao salvar perfil: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar perfil: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Meu Perfil'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Perfil'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _salvarPerfil,
              tooltip: 'Salvar perfil',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informações do usuário
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _usuario?.nome ?? 'Sem nome',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _usuario?.email ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Configure seu perfil para ver apenas as tarefas relacionadas às suas regionais, divisões e segmentos.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    if (!_usuario!.temPerfilConfigurado())
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.red[300]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning, size: 16, color: Colors.red[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '⚠️ ATENÇÃO: Sem perfil configurado, você NÃO verá nenhuma tarefa. Configure seu perfil abaixo.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Regionais
            _buildSection(
              title: 'Regionais',
              icon: Icons.location_city,
              color: Colors.blue,
              items: _todasRegionais.map((r) => r.regional).toList(),
              selectedIds: _selectedRegionalIds,
              allItems: _todasRegionais,
              onSelectionChanged: (selectedIds) {
                setState(() {
                  _selectedRegionalIds = selectedIds;

                  // Atualizar divisões válidas pelas novas regionais selecionadas
                  final validDivisaoIds = _todasDivisoes
                      .where((d) =>
                          d.regionalIds.any((rId) => selectedIds.contains(rId)) ||
                          selectedIds.contains(d.regionalId))
                      .map((d) => d.id)
                      .toSet();

                  // Desmarcar divisões que não pertencem mais a nenhuma regional selecionada
                  _selectedDivisaoIds = _selectedDivisaoIds.intersection(validDivisaoIds);

                  // Atualizar segmentos válidos pelas divisões restantes
                  final validSegmentoIds = _todasDivisoes
                      .where((d) => _selectedDivisaoIds.contains(d.id))
                      .expand((d) => d.segmentoIds)
                      .toSet();

                  // Desmarcar segmentos que não pertencem mais a nenhuma divisão selecionada
                  _selectedSegmentoIds = _selectedSegmentoIds.intersection(validSegmentoIds);
                });
              },
            ),
            
            const SizedBox(height: 24),
            
            // Divisões (habilitadas apenas as cadastradas para as regionais selecionadas)
            _buildSection(
              title: 'Divisões',
              icon: Icons.business,
              color: Colors.orange,
              items: _todasDivisoes.map((d) => d.divisao).toList(),
              selectedIds: _selectedDivisaoIds,
              allItems: _todasDivisoes,
              isItemEnabled: (Divisao d) {
                if (_selectedRegionalIds.isEmpty) return false;
                return d.regionalIds.any((rId) => _selectedRegionalIds.contains(rId)) ||
                    _selectedRegionalIds.contains(d.regionalId);
              },
              disabledTooltip: _selectedRegionalIds.isEmpty
                  ? 'Selecione uma Regional primeiro'
                  : 'Divisão não cadastrada para a(s) regional(is) selecionada(s)',
              emptyParentMessage: _selectedRegionalIds.isEmpty
                  ? 'Selecione ao menos uma Regional acima para habilitar as divisões correspondentes.'
                  : null,
              onSelectionChanged: (selectedIds) {
                setState(() {
                  _selectedDivisaoIds = selectedIds;

                  // Atualizar segmentos válidos pelas novas divisões selecionadas
                  final validSegmentoIds = _todasDivisoes
                      .where((d) => selectedIds.contains(d.id))
                      .expand((d) => d.segmentoIds)
                      .toSet();

                  // Desmarcar segmentos que não pertencem mais a nenhuma divisão selecionada
                  _selectedSegmentoIds = _selectedSegmentoIds.intersection(validSegmentoIds);
                });
              },
            ),
            
            const SizedBox(height: 24),
            
            // Segmentos (habilitados apenas os cadastrados para as divisões selecionadas)
            _buildSection(
              title: 'Segmentos',
              icon: Icons.category,
              color: Colors.purple,
              items: _todosSegmentos.map((s) => s.segmento).toList(),
              selectedIds: _selectedSegmentoIds,
              allItems: _todosSegmentos,
              isItemEnabled: (Segmento s) {
                if (_selectedDivisaoIds.isEmpty) return false;
                return _todasDivisoes
                    .where((d) => _selectedDivisaoIds.contains(d.id))
                    .any((d) => d.segmentoIds.contains(s.id));
              },
              disabledTooltip: _selectedDivisaoIds.isEmpty
                  ? 'Selecione uma Divisão primeiro'
                  : 'Segmento não cadastrado para a(s) divisão(ões) selecionada(s)',
              emptyParentMessage: _selectedDivisaoIds.isEmpty
                  ? (_selectedRegionalIds.isEmpty
                      ? 'Selecione uma Regional e uma Divisão para habilitar os segmentos.'
                      : 'Selecione ao menos uma Divisão acima para habilitar os segmentos correspondentes.')
                  : null,
              onSelectionChanged: (selectedIds) {
                setState(() {
                  _selectedSegmentoIds = selectedIds;
                });
              },
            ),
            
            const SizedBox(height: 32),
            
            // Botão salvar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _salvarPerfil,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Salvando...' : 'Salvar Perfil'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection<T>({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> items,
    required Set<String> selectedIds,
    required List<T> allItems,
    required Function(Set<String>) onSelectionChanged,
    bool Function(T item)? isItemEnabled,
    String? disabledTooltip,
    String? emptyParentMessage,
  }) {
    final availableCount = isItemEnabled != null
        ? allItems.where((item) => isItemEnabled(item)).length
        : allItems.length;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  isItemEnabled != null
                      ? '${selectedIds.length} selecionado(s) • $availableCount disponível(is)'
                      : '${selectedIds.length} selecionado(s)',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            if (emptyParentMessage != null && availableCount == 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 15, color: Colors.amber[800]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        emptyParentMessage,
                        style: TextStyle(fontSize: 12, color: Colors.amber[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Nenhum item disponível',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final itemLabel = entry.value;
                  final rawItem = allItems[index];
                  final itemId = _getItemId(rawItem);
                  final isSelected = selectedIds.contains(itemId);
                  final isEnabled = isItemEnabled == null || isItemEnabled(rawItem);

                  Widget chip = FilterChip(
                    label: Text(itemLabel),
                    selected: isSelected,
                    onSelected: isEnabled
                        ? (selected) {
                            final newSelection = Set<String>.from(selectedIds);
                            if (selected) {
                              newSelection.add(itemId);
                            } else {
                              newSelection.remove(itemId);
                            }
                            onSelectionChanged(newSelection);
                          }
                        : null,
                    selectedColor: color.withValues(alpha: 0.18),
                    checkmarkColor: color,
                    backgroundColor: isEnabled ? Colors.white : Colors.grey[100],
                    disabledColor: Colors.grey[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected
                            ? color
                            : (isEnabled ? Colors.grey[300]! : Colors.grey[200]!),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? color
                          : (isEnabled ? Colors.black87 : Colors.grey[400]),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );

                  if (!isEnabled) {
                    return Opacity(
                      opacity: 0.38,
                      child: Tooltip(
                        message: disabledTooltip ?? 'Não disponível para a seleção atual',
                        child: chip,
                      ),
                    );
                  }

                  return chip;
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  String _getItemId(dynamic item) {
    if (item is Regional) return item.id;
    if (item is Divisao) return item.id;
    if (item is Segmento) return item.id;
    return '';
  }
}

