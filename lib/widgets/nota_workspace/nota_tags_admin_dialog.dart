import 'package:flutter/material.dart';
import '../../models/nota_sap_tag.dart';
import '../../models/regional.dart';
import '../../models/divisao.dart';
import '../../models/segmento.dart';
import '../../services/auth_service_simples.dart';
import '../../services/nota_sap_tag_service.dart';
import '../../services/regional_service.dart';
import '../../services/divisao_service.dart';
import '../../services/segmento_service.dart';

/// Diálogo de Administração do Catálogo de Tags das Notas SAP.
///
/// Restrito a usuários com `isRoot == true`.
class NotaSapTagsAdminDialog extends StatefulWidget {
  final NotaSapTagService? tagService;

  const NotaSapTagsAdminDialog({super.key, this.tagService});

  static Future<void> show(BuildContext context, {NotaSapTagService? tagService}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => NotaSapTagsAdminDialog(tagService: tagService),
    );
  }

  @override
  State<NotaSapTagsAdminDialog> createState() => _NotaSapTagsAdminDialogState();
}

class _NotaSapTagsAdminDialogState extends State<NotaSapTagsAdminDialog> {
  late final NotaSapTagService _tagService;
  final RegionalService _regionalService = RegionalService();
  final DivisaoService _divisaoService = DivisaoService();
  final SegmentoService _segmentoService = SegmentoService();

  bool _carregando = true;
  String? _erro;
  List<NotaSapTag> _todasTags = [];
  Map<String, int> _contagemNotas = {};

  List<Regional> _regionais = [];
  List<Divisao> _divisoes = [];
  List<Segmento> _segmentos = [];

  String _filtroTexto = '';
  NotaSapTagEscopo? _filtroEscopo;

  @override
  void initState() {
    super.initState();
    _tagService = widget.tagService ?? NotaSapTagService();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    final user = AuthServiceSimples().currentUser;
    if (user == null || !user.isRoot) {
      setState(() {
        _erro = 'Acesso restrito: apenas administradores (root) podem gerenciar o catálogo de tags.';
        _carregando = false;
      });
      return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final tags = await _tagService.listarCatalogoCompletoAdmin(usuario: user);
      
      // Carrega listas organizacionais em paralelo para os nomes e seletores
      final results = await Future.wait([
        _regionalService.getAllRegionais(),
        _divisaoService.getAllDivisoes(),
        _segmentoService.getAllSegmentos(),
      ]);

      _regionais = results[0] as List<Regional>;
      _divisoes = results[1] as List<Divisao>;
      _segmentos = results[2] as List<Segmento>;

      // Contagem de notas por tag
      final Map<String, int> counts = {};
      for (final t in tags) {
        if (t.id != null) {
          counts[t.id!] = await _tagService.contarNotasComTag(t.id!);
        }
      }

      if (mounted) {
        setState(() {
          _todasTags = tags;
          _contagemNotas = counts;
          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = 'Erro ao carregar dados do catálogo: $e';
          _carregando = false;
        });
      }
    }
  }

  String _nomeAlvoEscopo(NotaSapTag tag) {
    switch (tag.escopoTipo) {
      case NotaSapTagEscopo.global:
        return 'Corporativo';
      case NotaSapTagEscopo.regional:
        final reg = _regionais.where((r) => r.id == tag.regionalId).firstOrNull;
        return reg != null ? reg.regional : (tag.regionalId ?? '-');
      case NotaSapTagEscopo.divisao:
        final div = _divisoes.where((d) => d.id == tag.divisaoId).firstOrNull;
        return div != null ? div.divisao : (tag.divisaoId ?? '-');
      case NotaSapTagEscopo.segmento:
        final seg = _segmentos.where((s) => s.id == tag.segmentoId).firstOrNull;
        return seg != null ? seg.segmento : (tag.segmentoId ?? '-');
    }
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

  Future<void> _abrirFormularioTag([NotaSapTag? tagExistente]) async {
    final user = AuthServiceSimples().currentUser;
    if (user == null || !user.isRoot) return;

    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _TagFormDialog(
        tagExistente: tagExistente,
        tagService: _tagService,
        regionais: _regionais,
        divisoes: _divisoes,
        segmentos: _segmentos,
      ),
    );

    if (resultado == true) {
      _carregarDados();
    }
  }

  Future<void> _toggleAtivo(NotaSapTag tag) async {
    final user = AuthServiceSimples().currentUser;
    if (user == null || tag.id == null) return;

    try {
      if (tag.ativo) {
        await _tagService.desativarTagCatalogo(tagId: tag.id!, usuario: user);
      } else {
        await _tagService.reativarTagCatalogo(tagId: tag.id!, usuario: user);
      }
      _carregarDados();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao alterar status da tag: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthServiceSimples().currentUser;
    final isRoot = user?.isRoot ?? false;

    final tagsFiltradas = _todasTags.where((t) {
      final matchesTexto = _filtroTexto.isEmpty ||
          t.nome.toLowerCase().contains(_filtroTexto.toLowerCase()) ||
          (t.categoria?.toLowerCase().contains(_filtroTexto.toLowerCase()) ?? false);
      final matchesEscopo = _filtroEscopo == null || t.escopoTipo == _filtroEscopo;
      return matchesTexto && matchesEscopo;
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 950,
        height: 650,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho
            Row(
              children: [
                const Icon(Icons.sell_outlined, color: Colors.indigo, size: 28),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Catálogo de Tags das Notas SAP',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Gestão hierárquica por perfil organizacional (Apenas Root)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const Spacer(),
                if (isRoot)
                  ElevatedButton.icon(
                    onPressed: () => _abrirFormularioTag(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nova Tag'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),

            if (!isRoot || _erro != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 54, color: Colors.orange),
                      const SizedBox(height: 12),
                      Text(
                        _erro ?? 'Acesso restrito.',
                        style: const TextStyle(fontSize: 14, color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              // Barra de Filtros
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Filtrar por nome ou categoria...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) => setState(() => _filtroTexto = val),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<NotaSapTagEscopo?>(
                    value: _filtroEscopo,
                    hint: const Text('Todos os Escopos'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todos os Escopos')),
                      ...NotaSapTagEscopo.values.map(
                        (e) => DropdownMenuItem(value: e, child: Text(e.descricao)),
                      ),
                    ],
                    onChanged: (val) => setState(() => _filtroEscopo = val),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Recarregar Catálogo',
                    onPressed: _carregarDados,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Tabela de Tags
              Expanded(
                child: _carregando
                    ? const Center(child: CircularProgressIndicator())
                    : tagsFiltradas.isEmpty
                        ? Center(
                            child: Text(
                              _todasTags.isEmpty
                                  ? 'Nenhuma tag cadastrada no catálogo.'
                                  : 'Nenhuma tag corresponde aos filtros.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          )
                        : SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                              columns: const [
                                DataColumn(label: Text('Tag')),
                                DataColumn(label: Text('Categoria')),
                                DataColumn(label: Text('Escopo')),
                                DataColumn(label: Text('Alvo Organizacional')),
                                DataColumn(label: Text('Notas')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Ações')),
                              ],
                              rows: tagsFiltradas.map((tag) {
                                final count = _contagemNotas[tag.id] ?? 0;
                                final cor = _corDaTag(tag.cor);

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: cor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            tag.nome,
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(Text(tag.categoria ?? '-')),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.indigo.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          tag.escopoTipo.descricao,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.indigo.shade800,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(_nomeAlvoEscopo(tag))),
                                    DataCell(Text('$count')),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Switch(
                                            value: tag.ativo,
                                            onChanged: (val) => _toggleAtivo(tag),
                                          ),
                                          Text(
                                            tag.ativo ? 'Ativa' : 'Inativa',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: tag.ativo ? Colors.green.shade700 : Colors.redAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 18),
                                        tooltip: 'Editar Tag',
                                        onPressed: () => _abrirFormularioTag(tag),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Formulário modal para Criar / Editar Tag com validação estrita de escopo
class _TagFormDialog extends StatefulWidget {
  final NotaSapTag? tagExistente;
  final NotaSapTagService tagService;
  final List<Regional> regionais;
  final List<Divisao> divisoes;
  final List<Segmento> segmentos;

  const _TagFormDialog({
    this.tagExistente,
    required this.tagService,
    required this.regionais,
    required this.divisoes,
    required this.segmentos,
  });

  @override
  State<_TagFormDialog> createState() => _TagFormDialogState();
}

class _TagFormDialogState extends State<_TagFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nomeController;
  late final TextEditingController _descricaoController;
  late final TextEditingController _categoriaController;
  late String _corHex;
  late NotaSapTagEscopo _escopo;

  String? _regionalId;
  String? _divisaoId;
  String? _segmentoId;

  bool _salvando = false;
  String? _erroSalvar;

  final List<String> _paletaCores = [
    '#E53935', // Vermelho
    '#FB8C00', // Laranja
    '#FDD835', // Amarelo
    '#43A047', // Verde
    '#00ACC1', // Ciano
    '#1E88E5', // Azul
    '#5E35B1', // Roxo
    '#8E24AA', // Magenta
    '#6D4C41', // Marrom
    '#546E7A', // Cinza Azulado
  ];

  @override
  void initState() {
    super.initState();
    final tag = widget.tagExistente;
    _nomeController = TextEditingController(text: tag?.nome ?? '');
    _descricaoController = TextEditingController(text: tag?.descricao ?? '');
    _categoriaController = TextEditingController(text: tag?.categoria ?? '');
    _corHex = tag?.cor ?? '#1E88E5';
    _escopo = tag?.escopoTipo ?? NotaSapTagEscopo.global;
    _regionalId = tag?.regionalId;
    _divisaoId = tag?.divisaoId;
    _segmentoId = tag?.segmentoId;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _categoriaController.dispose();
    super.dispose();
  }

  void _onEscopoChanged(NotaSapTagEscopo novoEscopo) {
    setState(() {
      _escopo = novoEscopo;
      // Regra 53: Ao mudar de escopo, limpar IDs que não pertencem ao novo escopo
      if (novoEscopo != NotaSapTagEscopo.regional) _regionalId = null;
      if (novoEscopo != NotaSapTagEscopo.divisao) _divisaoId = null;
      if (novoEscopo != NotaSapTagEscopo.segmento) _segmentoId = null;
    });
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    // Validação estrita do alvo
    if (_escopo == NotaSapTagEscopo.regional && _regionalId == null) {
      setState(() => _erroSalvar = 'Selecione uma Regional para o escopo Regional.');
      return;
    }
    if (_escopo == NotaSapTagEscopo.divisao && _divisaoId == null) {
      setState(() => _erroSalvar = 'Selecione uma Divisão para o escopo Divisão.');
      return;
    }
    if (_escopo == NotaSapTagEscopo.segmento && _segmentoId == null) {
      setState(() => _erroSalvar = 'Selecione um Segmento para o escopo Segmento.');
      return;
    }

    setState(() {
      _salvando = true;
      _erroSalvar = null;
    });

    try {
      final user = AuthServiceSimples().currentUser;
      if (user == null) throw Exception('Nenhum usuário logado');

      final tagParaSalvar = NotaSapTag(
        id: widget.tagExistente?.id,
        nome: _nomeController.text.trim(),
        descricao: _descricaoController.text.trim().isEmpty ? null : _descricaoController.text.trim(),
        categoria: _categoriaController.text.trim().isEmpty ? null : _categoriaController.text.trim(),
        cor: _corHex,
        escopoTipo: _escopo,
        regionalId: _escopo == NotaSapTagEscopo.regional ? _regionalId : null,
        divisaoId: _escopo == NotaSapTagEscopo.divisao ? _divisaoId : null,
        segmentoId: _escopo == NotaSapTagEscopo.segmento ? _segmentoId : null,
        ativo: widget.tagExistente?.ativo ?? true,
      );

      await widget.tagService.salvarTagCatalogo(
        tag: tagParaSalvar,
        usuario: user,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erroSalvar = 'Erro ao salvar tag: $e';
          _salvando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.tagExistente == null ? 'Nova Tag do Catálogo' : 'Editar Tag'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_erroSalvar != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _erroSalvar!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  ),

                // Nome da Tag
                TextFormField(
                  controller: _nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da Tag *',
                    hintText: 'Ex: Vegetação, SF6, Prioritária',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'O nome da tag é obrigatório.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Categoria e Descrição
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _categoriaController,
                        decoration: const InputDecoration(
                          labelText: 'Categoria',
                          hintText: 'Ex: Técnica, Planejamento',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _descricaoController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descrição / Finalidade',
                    hintText: 'Para que serve esta classificação...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Seletor de Escopo Estrito
                const Text('Escopo Organizacional:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<NotaSapTagEscopo>(
                  initialValue: _escopo,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: NotaSapTagEscopo.values.map((e) {
                    return DropdownMenuItem(value: e, child: Text(e.descricao));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) _onEscopoChanged(val);
                  },
                ),
                const SizedBox(height: 12),

                // Seletores dependentes do escopo
                if (_escopo == NotaSapTagEscopo.regional) ...[
                  const Text('Regional Alvo: *', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: _regionalId,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    hint: const Text('Selecione a Regional'),
                    items: widget.regionais.map((r) {
                      return DropdownMenuItem(value: r.id, child: Text(r.regional));
                    }).toList(),
                    onChanged: (val) => setState(() => _regionalId = val),
                  ),
                  const SizedBox(height: 12),
                ],

                if (_escopo == NotaSapTagEscopo.divisao) ...[
                  const Text('Divisão Alvo: *', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: _divisaoId,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    hint: const Text('Selecione a Divisão'),
                    items: widget.divisoes.map((d) {
                      return DropdownMenuItem(value: d.id, child: Text(d.divisao));
                    }).toList(),
                    onChanged: (val) => setState(() => _divisaoId = val),
                  ),
                  const SizedBox(height: 12),
                ],

                if (_escopo == NotaSapTagEscopo.segmento) ...[
                  const Text('Segmento Corporativo Alvo: *', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: _segmentoId,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    hint: const Text('Selecione o Segmento (ex: LT, SE)'),
                    items: widget.segmentos.map((s) {
                      return DropdownMenuItem(value: s.id, child: Text(s.segmento));
                    }).toList(),
                    onChanged: (val) => setState(() => _segmentoId = val),
                  ),
                  const SizedBox(height: 12),
                ],

                // Seleção de Cor
                const Text('Cor da Tag:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _paletaCores.map((hex) {
                    final isSelected = _corHex.toUpperCase() == hex.toUpperCase();
                    final color = Color(int.parse('0xFF${hex.replaceAll('#', '')}'));
                    return InkWell(
                      onTap: () => setState(() => _corHex = hex),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.black : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _salvando ? null : _salvar,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
          ),
          child: _salvando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
