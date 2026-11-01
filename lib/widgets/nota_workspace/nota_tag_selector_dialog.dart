import 'package:flutter/material.dart';
import '../../models/nota_sap_tag.dart';
import '../../services/usuario_service.dart';
import '../../services/auth_service_simples.dart';
import '../../services/nota_sap_tag_service.dart';

/// Diálogo para seleção e criação de Tags para a Nota SAP.
///
/// Permite:
/// 1. Selecionar tags disponíveis no catálogo para o perfil do usuário logado.
/// 2. Criar uma nova tag no catálogo diretamente pela interface e já vinculá-la à nota.
///    - Root: pode criar em qualquer escopo (Global, Segmento, Regional, Divisão).
///    - Usuário comum: pode criar em seus escopos organizacionais (seus Segmentos, Regionais ou Divisões).
class NotaSapTagSelectorDialog extends StatefulWidget {
  final String notaSapId;
  final List<NotaSapTag> tagsAtuaisDaNota;
  final NotaSapTagService? tagService;
  final Usuario? usuario;

  const NotaSapTagSelectorDialog({
    super.key,
    required this.notaSapId,
    required this.tagsAtuaisDaNota,
    this.tagService,
    this.usuario,
  });

  static Future<NotaSapTag?> show(
    BuildContext context, {
    required String notaSapId,
    required List<NotaSapTag> tagsAtuaisDaNota,
    NotaSapTagService? tagService,
    Usuario? usuario,
  }) {
    return showDialog<NotaSapTag>(
      context: context,
      builder: (context) => NotaSapTagSelectorDialog(
        notaSapId: notaSapId,
        tagsAtuaisDaNota: tagsAtuaisDaNota,
        tagService: tagService,
        usuario: usuario,
      ),
    );
  }

  @override
  State<NotaSapTagSelectorDialog> createState() => _NotaSapTagSelectorDialogState();
}

class _NotaSapTagSelectorDialogState extends State<NotaSapTagSelectorDialog> {
  late final NotaSapTagService _tagService;
  final TextEditingController _buscaController = TextEditingController();

  // Estados da lista
  bool _carregando = true;
  String? _erro;
  List<NotaSapTag> _catalogoDisponivel = [];
  List<NotaSapTag> _tagsFiltradas = [];
  String? _categoriaSelecionada;

  // Estados do modo de criação
  bool _modoCriacao = false;
  bool _salvandoNovaTag = false;
  String? _erroCriacao;
  final _formCriacaoKey = GlobalKey<FormState>();
  final TextEditingController _novoNomeController = TextEditingController();
  final TextEditingController _novaDescricaoController = TextEditingController();
  final TextEditingController _novaCategoriaController = TextEditingController();
  String _corSelecionada = '#1E88E5';

  // Escopo selecionado para a nova tag
  NotaSapTagEscopo _novoEscopoTipo = NotaSapTagEscopo.global;
  String? _novoEscopoId;

  static const List<String> _paletaCores = [
    '#1E88E5', // Azul
    '#10B981', // Verde
    '#F59E0B', // Âmbar / Laranja
    '#EF4444', // Vermelho
    '#8B5CF6', // Roxo
    '#EC4899', // Rosa
    '#06B6D4', // Ciano
    '#F97316', // Laranja Escuro
    '#64748B', // Cinza Ardósia
    '#14B8A6', // Teal
  ];

  static const List<String> _categoriasSugeridas = [
    'GERAL',
    'MANUTENÇÃO',
    'SEGURANÇA',
    'OPERAÇÃO',
    'URGÊNCIA',
    'INSPEÇÃO',
    'CIVIL',
    'ELÉTRICA',
  ];

  Usuario? get _currentUser {
    if (widget.usuario != null) return widget.usuario;
    try {
      return AuthServiceSimples().currentUser;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _tagService = widget.tagService ?? NotaSapTagService();
    _carregarCatalogo();
    _buscaController.addListener(_aplicarFiltro);
    _inicializarEscopoPadrao();
  }

  @override
  void dispose() {
    _buscaController.removeListener(_aplicarFiltro);
    _buscaController.dispose();
    _novoNomeController.dispose();
    _novaDescricaoController.dispose();
    _novaCategoriaController.dispose();
    super.dispose();
  }

  void _inicializarEscopoPadrao() {
    final user = _currentUser;
    if (user == null) return;

    if (user.isRoot) {
      _novoEscopoTipo = NotaSapTagEscopo.global;
      _novoEscopoId = null;
    } else if (user.segmentos.isNotEmpty && user.segmentoIds.isNotEmpty) {
      _novoEscopoTipo = NotaSapTagEscopo.segmento;
      _novoEscopoId = user.segmentoIds.first;
    } else if (user.regionais.isNotEmpty && user.regionalIds.isNotEmpty) {
      _novoEscopoTipo = NotaSapTagEscopo.regional;
      _novoEscopoId = user.regionalIds.first;
    } else if (user.divisoes.isNotEmpty && user.divisaoIds.isNotEmpty) {
      _novoEscopoTipo = NotaSapTagEscopo.divisao;
      _novoEscopoId = user.divisaoIds.first;
    } else {
      _novoEscopoTipo = NotaSapTagEscopo.global;
      _novoEscopoId = null;
    }
  }

  Future<void> _carregarCatalogo() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final user = _currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _carregando = false;
          });
        }
        return;
      }

      final tags = await _tagService.listarCatalogoDisponivel(usuario: user);

      // Exclui tags que a nota já possui
      final idsAtuais = widget.tagsAtuaisDaNota.map((t) => t.id).toSet();
      final disponiveisParaAdicionar =
          tags.where((t) => !idsAtuais.contains(t.id)).toList();

      if (mounted) {
        setState(() {
          _catalogoDisponivel = disponiveisParaAdicionar;
          _carregando = false;
          _aplicarFiltro();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = 'Erro ao carregar tags disponíveis: $e';
          _carregando = false;
        });
      }
    }
  }

  void _aplicarFiltro() {
    final query = _buscaController.text.trim().toLowerCase();
    setState(() {
      _tagsFiltradas = _catalogoDisponivel.where((tag) {
        final matchesQuery = query.isEmpty ||
            tag.nome.toLowerCase().contains(query) ||
            (tag.descricao?.toLowerCase().contains(query) ?? false) ||
            (tag.categoria?.toLowerCase().contains(query) ?? false);

        final matchesCategoria = _categoriaSelecionada == null ||
            tag.categoria == _categoriaSelecionada;

        return matchesQuery && matchesCategoria;
      }).toList();
    });
  }

  Color _corDaTag(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.blueGrey;
    try {
      final cleaned = hex.replaceAll('#', '');
      return Color(int.parse('0xFF$cleaned'));
    } catch (_) {
      return Colors.blueGrey;
    }
  }

  void _abrirCriacaoComNome([String? nomeInicial]) {
    setState(() {
      _modoCriacao = true;
      _erroCriacao = null;
      _novoNomeController.text = nomeInicial ?? _buscaController.text.trim();
      if (_novaCategoriaController.text.isEmpty) {
        _novaCategoriaController.text = 'GERAL';
      }
    });
  }

  Future<void> _salvarECriarTag() async {
    if (!_formCriacaoKey.currentState!.validate()) return;

    final user = _currentUser;
    if (user == null) {
      setState(() => _erroCriacao = 'Nenhum usuário logado.');
      return;
    }

    setState(() {
      _salvandoNovaTag = true;
      _erroCriacao = null;
    });

    try {
      final nome = _novoNomeController.text.trim();
      final categoria = _novaCategoriaController.text.trim().isEmpty
          ? 'GERAL'
          : _novaCategoriaController.text.trim().toUpperCase();
      final descricao = _novaDescricaoController.text.trim().isEmpty
          ? null
          : _novaDescricaoController.text.trim();

      String? regionalId;
      String? divisaoId;
      String? segmentoId;

      switch (_novoEscopoTipo) {
        case NotaSapTagEscopo.global:
          break;
        case NotaSapTagEscopo.regional:
          regionalId = _novoEscopoId;
          break;
        case NotaSapTagEscopo.divisao:
          divisaoId = _novoEscopoId;
          break;
        case NotaSapTagEscopo.segmento:
          segmentoId = _novoEscopoId;
          break;
      }

      final novaTag = NotaSapTag(
        nome: nome,
        categoria: categoria,
        descricao: descricao,
        cor: _corSelecionada,
        escopoTipo: _novoEscopoTipo,
        regionalId: regionalId,
        divisaoId: divisaoId,
        segmentoId: segmentoId,
        ativo: true,
      );

      final tagSalva = await _tagService.salvarTagCatalogo(
        tag: novaTag,
        usuario: user,
      );

      if (mounted) {
        // Retorna a tag criada diretamente para ser vinculada à nota
        Navigator.of(context).pop(tagSalva);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _salvandoNovaTag = false;
          _erroCriacao = 'Erro ao criar tag: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      title: Row(
        children: [
          if (_modoCriacao)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Voltar para lista',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                setState(() {
                  _modoCriacao = false;
                  _erroCriacao = null;
                });
              },
            )
          else
            const Icon(Icons.label_outline, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _modoCriacao ? 'Criar Nova Tag' : 'Adicionar Tag à Nota',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          if (!_modoCriacao)
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Nova Tag', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => _abrirCriacaoComNome(),
            ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Fechar',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 520,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _modoCriacao ? _buildModoCriacao() : _buildModoSelecao(),
        ),
      ),
      actions: _modoCriacao
          ? [
              TextButton(
                onPressed: _salvandoNovaTag
                    ? null
                    : () {
                        setState(() {
                          _modoCriacao = false;
                          _erroCriacao = null;
                        });
                      },
                child: const Text('Voltar'),
              ),
              ElevatedButton.icon(
                onPressed: _salvandoNovaTag ? null : _salvarECriarTag,
                icon: _salvandoNovaTag
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check, size: 16),
                label: Text(_salvandoNovaTag ? 'Salvando...' : 'Criar e Vincular'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
            ],
    );
  }

  // ---------------------------------------------------------------------------
  // MODO 1: SELEÇÃO DE TAGS EXISTENTES
  // ---------------------------------------------------------------------------
  Widget _buildModoSelecao() {
    final categorias = _catalogoDisponivel
        .map((t) => t.categoria)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();

    final query = _buscaController.text.trim();

    return Column(
      key: const ValueKey('modo_selecao'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Campo de busca
        TextField(
          controller: _buscaController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Buscar tag por nome, categoria...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _buscaController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => _buscaController.clear(),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        const SizedBox(height: 10),

        // Filtro por categorias se houver
        if (categorias.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Todas', style: TextStyle(fontSize: 12)),
                  selected: _categoriaSelecionada == null,
                  onSelected: (val) {
                    setState(() {
                      _categoriaSelecionada = null;
                      _aplicarFiltro();
                    });
                  },
                ),
                const SizedBox(width: 6),
                ...categorias.map(
                  (cat) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(cat, style: const TextStyle(fontSize: 12)),
                      selected: _categoriaSelecionada == cat,
                      onSelected: (val) {
                        setState(() {
                          _categoriaSelecionada = val ? cat : null;
                          _aplicarFiltro();
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),

        // Lista de Tags disponíveis
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : _erro != null
                  ? Center(
                      child: Text(
                        _erro!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    )
                  : _tagsFiltradas.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.label_off_outlined,
                                  size: 44, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text(
                                _catalogoDisponivel.isEmpty
                                    ? 'Nenhuma tag disponível para seu perfil ou todas já foram atribuídas.'
                                    : 'Nenhuma tag encontrada para "$query".',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add_circle_outline, size: 16),
                                label: Text(
                                  query.isNotEmpty
                                      ? 'Criar tag "$query"'
                                      : 'Criar nova tag no catálogo',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                ),
                                onPressed: () => _abrirCriacaoComNome(
                                  query.isNotEmpty ? query : null,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _tagsFiltradas.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final tag = _tagsFiltradas[index];
                            final cor = _corDaTag(tag.cor);

                            return ListTile(
                              dense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              leading: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: cor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      tag.nome,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      tag.escopoTipo.descricao,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (tag.categoria != null) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        tag.categoria!,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.blueGrey.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: tag.descricao != null && tag.descricao!.isNotEmpty
                                  ? Text(
                                      tag.descricao!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    )
                                  : null,
                              trailing: Tooltip(
                                message: 'Vincular esta tag à nota',
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withAlpha(20),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    size: 18,
                                    color: Colors.blueAccent,
                                  ),
                                ),
                              ),
                              onTap: () => Navigator.of(context).pop(tag),
                            );
                          },
                        ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // MODO 2: FORMULÁRIO DE CRIAÇÃO DE NOVA TAG
  // ---------------------------------------------------------------------------
  Widget _buildModoCriacao() {
    final user = _currentUser;
    final opcoesEscopo = _obterOpcoesEscopo(user);

    return Form(
      key: _formCriacaoKey,
      child: SingleChildScrollView(
        child: Column(
          key: const ValueKey('modo_criacao'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_erroCriacao != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _erroCriacao!,
                        style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Nome da Tag
            TextFormField(
              controller: _novoNomeController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Nome da Tag *',
                hintText: 'Ex: Avaria Crítica, Torre com Corrosão...',
                prefixIcon: const Icon(Icons.label, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Informe o nome da tag';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Categoria com sugestões rápidas
            TextFormField(
              controller: _novaCategoriaController,
              decoration: InputDecoration(
                labelText: 'Categoria',
                hintText: 'Ex: MANUTENÇÃO, SEGURANÇA...',
                prefixIcon: const Icon(Icons.category_outlined, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: _categoriasSugeridas.map((cat) {
                final isSelected =
                    _novaCategoriaController.text.trim().toUpperCase() == cat;
                return ActionChip(
                  label: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.blue.shade900 : Colors.black87,
                    ),
                  ),
                  backgroundColor:
                      isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  onPressed: () {
                    setState(() {
                      _novaCategoriaController.text = cat;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Seletor de Cor
            const Text(
              'Cor da Tag',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _paletaCores.map((corHex) {
                final cor = _corDaTag(corHex);
                final isSelected = _corSelecionada.toUpperCase() == corHex.toUpperCase();
                return GestureDetector(
                  onTap: () => setState(() => _corSelecionada = corHex),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: cor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.black87 : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cor.withAlpha(80),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Descrição Opcional
            TextFormField(
              controller: _novaDescricaoController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Descrição (opcional)',
                hintText: 'Explique a finalidade desta tag...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 14),

            // Escopo Organizacional
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 2,
              children: [
                const Icon(Icons.apartment_outlined, size: 18, color: Colors.blueAccent),
                const Text(
                  'Escopo da Tag',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  user?.isRoot == true
                      ? '(Root: todos os escopos)'
                      : '(Conforme perfil)',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 6),

            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade50,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<_OpcaoEscopo>(
                  isExpanded: true,
                  value: opcoesEscopo.any((op) =>
                          op.tipo == _novoEscopoTipo && op.id == _novoEscopoId)
                      ? opcoesEscopo.firstWhere((op) =>
                          op.tipo == _novoEscopoTipo && op.id == _novoEscopoId)
                      : (opcoesEscopo.isNotEmpty ? opcoesEscopo.first : null),
                  items: opcoesEscopo.map((op) {
                    return DropdownMenuItem<_OpcaoEscopo>(
                      value: op,
                      child: Row(
                        children: [
                          Icon(op.icone, size: 16, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              op.titulo,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (selecionado) {
                    if (selecionado != null) {
                      setState(() {
                        _novoEscopoTipo = selecionado.tipo;
                        _novoEscopoId = selecionado.id;
                      });
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_OpcaoEscopo> _obterOpcoesEscopo(Usuario? user) {
    if (user == null) {
      return [
        const _OpcaoEscopo(
          titulo: 'Global (Geral)',
          tipo: NotaSapTagEscopo.global,
          icone: Icons.public,
        ),
      ];
    }

    final lista = <_OpcaoEscopo>[];

    if (user.isRoot) {
      lista.add(
        const _OpcaoEscopo(
          titulo: 'Global (Toda a Organização)',
          tipo: NotaSapTagEscopo.global,
          icone: Icons.public,
        ),
      );
    }

    // Segmentos do usuário
    for (int i = 0; i < user.segmentoIds.length; i++) {
      final id = user.segmentoIds[i];
      final nome = i < user.segmentos.length ? user.segmentos[i] : id;
      lista.add(
        _OpcaoEscopo(
          titulo: 'Segmento: $nome',
          tipo: NotaSapTagEscopo.segmento,
          id: id,
          icone: Icons.corporate_fare,
        ),
      );
    }

    // Regionais do usuário
    for (int i = 0; i < user.regionalIds.length; i++) {
      final id = user.regionalIds[i];
      final nome = i < user.regionais.length ? user.regionais[i] : id;
      lista.add(
        _OpcaoEscopo(
          titulo: 'Regional: $nome',
          tipo: NotaSapTagEscopo.regional,
          id: id,
          icone: Icons.location_on_outlined,
        ),
      );
    }

    // Divisões do usuário
    for (int i = 0; i < user.divisaoIds.length; i++) {
      final id = user.divisaoIds[i];
      final nome = i < user.divisoes.length ? user.divisoes[i] : id;
      lista.add(
        _OpcaoEscopo(
          titulo: 'Divisão: $nome',
          tipo: NotaSapTagEscopo.divisao,
          id: id,
          icone: Icons.domain,
        ),
      );
    }

    if (lista.isEmpty) {
      lista.add(
        const _OpcaoEscopo(
          titulo: 'Geral',
          tipo: NotaSapTagEscopo.global,
          icone: Icons.public,
        ),
      );
    }

    return lista;
  }
}

class _OpcaoEscopo {
  final String titulo;
  final NotaSapTagEscopo tipo;
  final String? id;
  final IconData icone;

  const _OpcaoEscopo({
    required this.titulo,
    required this.tipo,
    this.id,
    required this.icone,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _OpcaoEscopo &&
          runtimeType == other.runtimeType &&
          titulo == other.titulo &&
          tipo == other.tipo &&
          id == other.id;

  @override
  int get hashCode => titulo.hashCode ^ tipo.hashCode ^ (id?.hashCode ?? 0);
}
