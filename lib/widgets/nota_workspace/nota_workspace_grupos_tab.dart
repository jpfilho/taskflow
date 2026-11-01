import 'package:flutter/material.dart';
import '../../design_system/foundations/tf_radius.dart';
import '../../models/nota_sap.dart';
import '../../models/nota_sap_grupo.dart';
import '../../services/auth_service_simples.dart';
import '../../services/nota_sap_grupo_service.dart';
import '../../services/nota_sap_service.dart';
import '../../services/nota_sap_similaridade_service.dart';
import '../nota_analise_workspace.dart';
import '../nota_sap_selection_dialog.dart';

/// Aba "Notas Vinculadas / Grupo" do Workspace Visual da Nota SAP.
///
/// Apresenta e gerencia:
/// - Associação de Notas SAP para futura intervenção conjunta.
/// - Previsão macro de programação (Mês/Ano numéricos, não bloqueante).
/// - Histórico auditável de postergações e alterações de previsão.
/// - Situação de programação derivada dinamicamente de `tasks_notas_sap`.
class NotaWorkspaceGruposTab extends StatefulWidget {
  final NotaSAP nota;
  final NotaSapGrupoService? service;
  final NotaSAPService? notaSapService;
  final VoidCallback? onAtualizacao;

  const NotaWorkspaceGruposTab({
    super.key,
    required this.nota,
    this.service,
    this.notaSapService,
    this.onAtualizacao,
  });

  @override
  State<NotaWorkspaceGruposTab> createState() => _NotaWorkspaceGruposTabState();
}

class _NotaWorkspaceGruposTabState extends State<NotaWorkspaceGruposTab> {
  late final NotaSapGrupoService _service;
  NotaSAPService? _notaSAPServiceInstance;
  NotaSAPService get _notaSAPService => widget.notaSapService ?? (_notaSAPServiceInstance ??= NotaSAPService());
  NotaSapGrupo? _grupoAtivo;
  List<NotaSapGrupoItem> _itens = [];
  GrupoStatusProgramacao? _statusProgramacao;
  bool _isLoading = true;
  bool _buscandoNotas = false;
  String? _erro;

  static const Color _primaryColor = Color(0xFF0F766E);
  static const Color _warningColor = Color(0xFFD97706);
  static const Color _cardBorder = Color(0xFFE2E8F0);
  static const Color _surfaceBg = Color(0xFFF8FAFC);
  static const Color _textMain = Color(0xFF1E293B);
  static const Color _textMuted = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? NotaSapGrupoService();
    _carregarDados();
  }

  @override
  void didUpdateWidget(covariant NotaWorkspaceGruposTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nota.id != widget.nota.id) {
      _carregarDados();
    }
  }

  Future<void> _carregarDados() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _erro = null;
    });

    try {
      final grupo = await _service.buscarGrupoAtivoDaNota(widget.nota.id);
      if (grupo != null) {
        final itens = await _service.buscarNotasDoGrupo(grupo.id);
        final statusProg = GrupoStatusProgramacao.calcular(itens);
        if (mounted) {
          setState(() {
            _grupoAtivo = grupo;
            _itens = itens;
            _statusProgramacao = statusProg;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _grupoAtivo = null;
            _itens = [];
            _statusProgramacao = null;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = 'Erro ao carregar dados do grupo: $e';
          _isLoading = false;
        });
      }
    }
  }

  // ===========================================================================
  // AÇÕES DO GRUPO
  // ===========================================================================

  Future<void> _abrirDialogCriarGrupo() async {
    final nomeController = TextEditingController(
      text: widget.nota.equipamento != null
          ? 'Intervenção ${widget.nota.equipamento}'
          : 'Grupo Nota ${widget.nota.nota}',
    );
    final motivoController = TextEditingController();
    int? mesSelecionado;
    int? anoSelecionado = DateTime.now().year;

    final criou = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.hub_outlined, color: _primaryColor),
                  SizedBox(width: 8),
                  Text('Criar Grupo de Programação Conjunta'),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Agrupe esta Nota com outras para planejamento de intervenção conjunta.',
                        style: TextStyle(fontSize: 13, color: _textMuted),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nomeController,
                        decoration: const InputDecoration(
                          labelText: 'Nome do Grupo *',
                          hintText: 'Ex: Intervenção Disjuntor 12T2',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: motivoController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Motivo do Agrupamento',
                          hintText: 'Ex: Aproveitar mesmo desligamento do barramento',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Previsão Macro de Programação (Opcional):',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textMain),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              initialValue: mesSelecionado,
                              decoration: const InputDecoration(
                                labelText: 'Mês',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Sem previsão')),
                                ...List.generate(12, (i) {
                                  const meses = [
                                    '01 - Janeiro', '02 - Fevereiro', '03 - Março',
                                    '04 - Abril', '05 - Maio', '06 - Junho',
                                    '07 - Julho', '08 - Agosto', '09 - Setembro',
                                    '10 - Outubro', '11 - Novembro', '12 - Dezembro'
                                  ];
                                  return DropdownMenuItem(value: i + 1, child: Text(meses[i]));
                                }),
                              ],
                              onChanged: (val) {
                                setDialogState(() {
                                  mesSelecionado = val;
                                  if (mesSelecionado != null && anoSelecionado == null) {
                                    anoSelecionado = DateTime.now().year;
                                  } else if (mesSelecionado == null) {
                                    anoSelecionado = null;
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              initialValue: anoSelecionado,
                              decoration: const InputDecoration(
                                labelText: 'Ano',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('—')),
                                ...List.generate(6, (i) {
                                  final ano = DateTime.now().year + i;
                                  return DropdownMenuItem(value: ano, child: Text(ano.toString()));
                                }),
                              ],
                              onChanged: mesSelecionado == null
                                  ? null
                                  : (val) => setDialogState(() => anoSelecionado = val),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nomeController.text.trim().isEmpty) return;
                    Navigator.of(ctx).pop(true);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
                  child: const Text('Criar Grupo'),
                ),
              ],
            );
          },
        );
      },
    );

    if (criou == true) {
      try {
        final user = AuthServiceSimples().currentUser;
        final novo = await _service.criarGrupo(
          nome: nomeController.text.trim(),
          motivo: motivoController.text.trim().isEmpty ? null : motivoController.text.trim(),
          localInstalacao: widget.nota.localInstalacao,
          equipamento: widget.nota.equipamento,
          centroTrabalhoResponsavel: widget.nota.centroTrabalhoResponsavel,
          mesProgramacaoPrevisto: mesSelecionado,
          anoProgramacaoPrevisto: anoSelecionado,
          motivoPrevisao: motivoController.text.trim().isEmpty ? null : motivoController.text.trim(),
          usuarioId: user?.id,
          usuarioNome: user?.nome ?? user?.email,
        );

        // Adicionar a nota atual ao grupo criado
        await _service.adicionarNotaAoGrupo(
          grupoId: novo.id,
          notaSapId: widget.nota.id,
          motivoVinculo: 'Nota de abertura do grupo',
          usuarioId: user?.id,
          usuarioNome: user?.nome ?? user?.email,
        );

        await _carregarDados();
        widget.onAtualizacao?.call();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao criar grupo: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _abrirDialogVincularGrupoExistente() async {
    final grupos = await _service.listarGruposAtivos();
    if (!mounted) return;

    if (grupos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum grupo ativo disponível. Crie um novo grupo.')),
      );
      return;
    }

    String? grupoEscolhidoId;

    final vinculou = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Vincular a Grupo Existente'),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Selecione o grupo ativo ao qual deseja associar esta Nota SAP:',
                      style: TextStyle(fontSize: 13, color: _textMuted),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Grupo de Destino',
                        border: OutlineInputBorder(),
                      ),
                      items: grupos.map((g) {
                        return DropdownMenuItem(
                          value: g.id,
                          child: Text('${g.nome} (${g.previsaoCompacta})'),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => grupoEscolhidoId = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: grupoEscolhidoId != null
                      ? () => Navigator.of(ctx).pop(true)
                      : null,
                  style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
                  child: const Text('Vincular Nota'),
                ),
              ],
            );
          },
        );
      },
    );

    if (vinculou == true && grupoEscolhidoId != null) {
      try {
        final user = AuthServiceSimples().currentUser;
        await _service.adicionarNotaAoGrupo(
          grupoId: grupoEscolhidoId!,
          notaSapId: widget.nota.id,
          motivoVinculo: 'Vinculada via workspace da Nota',
          usuarioId: user?.id,
          usuarioNome: user?.nome ?? user?.email,
        );
        await _carregarDados();
        widget.onAtualizacao?.call();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao vincular: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Set<String> _obterLocaisFiltro() {
    final locais = <String>{};
    if (widget.nota.local != null && widget.nota.local!.trim().isNotEmpty) {
      locais.add(widget.nota.local!.trim().toLowerCase());
    }
    final prefixo8 = NotaSapSimilaridadeService.extrairPrefixoInstalacao8(widget.nota.localInstalacao);
    if (prefixo8 != null && prefixo8.trim().isNotEmpty) {
      locais.add(prefixo8.trim().toLowerCase());
    }
    if (widget.nota.localInstalacao != null && widget.nota.localInstalacao!.trim().isNotEmpty) {
      final partes = widget.nota.localInstalacao!.trim().split('-');
      if (partes.length >= 3) {
        locais.add(partes[2].trim().toLowerCase());
      }
      locais.add(widget.nota.localInstalacao!.trim().toLowerCase());
    }
    return locais;
  }

  Future<void> _abrirDialogAdicionarNotaAoGrupo() async {
    if (_grupoAtivo == null) return;

    setState(() {
      _buscandoNotas = true;
    });

    try {
      // 1. Buscar todas as notas abertas disponíveis
      final todasNotas = await _notaSAPService.getAllNotas(
        filtroTipoNota: 'abertas',
        limit: 1000,
      );

      // 2. Filtrar notas que já estão no grupo ou são a nota em análise
      final idsExcluir = <String>{
        widget.nota.id,
        widget.nota.nota,
        ..._itens.map((i) => i.notaSapId),
        ..._itens.where((i) => i.nota != null).map((i) => i.nota!.id),
        ..._itens.where((i) => i.nota != null).map((i) => i.nota!.nota),
      };

      var notasDisponiveis = todasNotas.where((n) {
        if (idsExcluir.contains(n.id) || idsExcluir.contains(n.nota)) {
          return false;
        }
        final status = n.statusSistema?.toUpperCase() ?? '';
        if (status.contains('MSEN') ||
            status.contains('CONC') ||
            status.contains('ENCE') ||
            status.contains('CANC')) {
          return false;
        }
        return true;
      }).toList();

      // 3. Restringir ao mesmo local da nota, seguindo o padrão de vincular nota à tarefa
      final locaisFiltro = _obterLocaisFiltro();
      if (locaisFiltro.isNotEmpty) {
        final notasDoMesmoLocal = notasDisponiveis.where((n) {
          final nLocalRaw = (n.local ?? '').trim().toLowerCase();
          final nInstalacaoRaw = (n.localInstalacao ?? '').trim().toLowerCase();
          final nPrefixo8 = NotaSapSimilaridadeService.extrairPrefixoInstalacao8(n.localInstalacao)?.toLowerCase();

          return locaisFiltro.any((loc) =>
              (nPrefixo8 != null && (nPrefixo8 == loc || nPrefixo8.contains(loc) || loc.contains(nPrefixo8))) ||
              (nLocalRaw.isNotEmpty && (nLocalRaw.contains(loc) || loc.contains(nLocalRaw))) ||
              (nInstalacaoRaw.isNotEmpty && (nInstalacaoRaw.contains(loc) || loc.contains(nInstalacaoRaw))));
        }).toList();

        if (notasDoMesmoLocal.isNotEmpty) {
          notasDisponiveis = notasDoMesmoLocal;
        } else {
          notasDisponiveis = [];
        }
      }

      if (mounted) {
        setState(() {
          _buscandoNotas = false;
        });
      }

      if (notasDisponiveis.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Todas as notas já estão vinculadas ou não há notas disponíveis para este local',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      // 4. Mostrar o diálogo com opções filtradas de notas
      final notasSelecionadas = await showDialog<List<NotaSAP>>(
        context: context,
        builder: (context) => NotaSAPSelectionDialog(
          notas: notasDisponiveis,
          title: 'Adicionar Nota ao Grupo',
          taskTarefa: 'Nota ${widget.nota.nota}${widget.nota.local != null ? ' - ${widget.nota.local}' : ''}',
        ),
      );

      if (notasSelecionadas != null && notasSelecionadas.isNotEmpty) {
        final user = AuthServiceSimples().currentUser;
        int sucesso = 0;
        final erros = <String>[];

        for (final notaSel in notasSelecionadas) {
          try {
            await _service.adicionarNotaAoGrupo(
              grupoId: _grupoAtivo!.id,
              notaSapId: notaSel.id,
              motivoVinculo: 'Intervenção conjunta programada',
              usuarioId: user?.id,
              usuarioNome: user?.nome ?? user?.email,
            );
            sucesso++;
          } catch (e) {
            erros.add('Nota ${notaSel.nota}: $e');
          }
        }

        await _carregarDados();
        widget.onAtualizacao?.call();

        if (mounted) {
          if (sucesso > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  sucesso == 1
                      ? 'Nota ${notasSelecionadas.first.nota} vinculada com sucesso'
                      : '$sucesso notas vinculadas com sucesso',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
          if (erros.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Atenção: ${erros.join("; ")}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _buscandoNotas = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao buscar notas disponíveis: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _abrirDialogAlterarPrevisao() async {
    if (_grupoAtivo == null) return;
    int? mes = _grupoAtivo!.mesProgramacaoPrevisto;
    int? ano = _grupoAtivo!.anoProgramacaoPrevisto ?? DateTime.now().year;
    final motivoController = TextEditingController(text: _grupoAtivo!.motivoPrevisao ?? '');

    final alterou = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.calendar_month_outlined, color: _primaryColor),
                  SizedBox(width: 8),
                  Text('Alterar Previsão de Programação'),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'A previsão é um planejamento macro (Mês/Ano) e não afeta a criação de tarefas.',
                      style: TextStyle(fontSize: 12, color: _textMuted),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            initialValue: mes,
                            decoration: const InputDecoration(
                              labelText: 'Mês Previsto',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('Sem previsão')),
                              ...List.generate(12, (i) {
                                const meses = [
                                  '01 - Jan', '02 - Fev', '03 - Mar', '04 - Abr',
                                  '05 - Mai', '06 - Jun', '07 - Jul', '08 - Ago',
                                  '09 - Set', '10 - Out', '11 - Nov', '12 - Dez'
                                ];
                                return DropdownMenuItem(value: i + 1, child: Text(meses[i]));
                              }),
                            ],
                            onChanged: (val) {
                              setDialogState(() {
                                mes = val;
                                if (mes != null && ano == null) {
                                  ano = DateTime.now().year;
                                } else if (mes == null) {
                                  ano = null;
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            initialValue: ano,
                            decoration: const InputDecoration(
                              labelText: 'Ano',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('—')),
                              ...List.generate(6, (i) {
                                final a = DateTime.now().year + i;
                                return DropdownMenuItem(value: a, child: Text(a.toString()));
                              }),
                            ],
                            onChanged: mes == null
                                ? null
                                : (val) => setDialogState(() => ano = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: motivoController,
                      decoration: const InputDecoration(
                        labelText: 'Motivo da Previsão / Alteração',
                        hintText: 'Ex: Janela operacional em desligamento',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
                  child: const Text('Salvar Previsão'),
                ),
              ],
            );
          },
        );
      },
    );

    if (alterou == true) {
      try {
        final user = AuthServiceSimples().currentUser;
        await _service.alterarPrevisao(
          grupoId: _grupoAtivo!.id,
          mes: mes,
          ano: ano,
          motivo: motivoController.text.trim().isEmpty ? null : motivoController.text.trim(),
          usuarioId: user?.id,
          usuarioNome: user?.nome ?? user?.email,
        );
        await _carregarDados();
        widget.onAtualizacao?.call();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao alterar previsão: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _abrirDialogHistoricoPrevisoes() async {
    if (_grupoAtivo == null) return;
    final hist = await _service.buscarHistoricoPrevisao(_grupoAtivo!.id);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.history_outlined, color: _primaryColor),
              SizedBox(width: 8),
              Text('Histórico de Previsões'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: hist.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text('Nenhuma reprogramação registrada.', textAlign: TextAlign.center),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: hist.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final h = hist[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.change_circle_outlined, size: 20, color: _primaryColor),
                        title: Text(
                          h.transicaoTexto,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (h.motivo != null)
                              Text('Motivo: ${h.motivo}', style: const TextStyle(fontSize: 11)),
                            if (h.alteradoEm != null)
                              Text(
                                '${h.alteradoEm!.day.toString().padLeft(2, '0')}/${h.alteradoEm!.month.toString().padLeft(2, '0')}/${h.alteradoEm!.year}',
                                style: const TextStyle(fontSize: 10, color: _textMuted),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removerNota(NotaSapGrupoItem item) async {
    final conf = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover Nota do Grupo'),
        content: Text('Deseja desvincular a Nota ${item.nota?.nota ?? item.notaSapId} deste grupo?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (conf == true && _grupoAtivo != null) {
      try {
        await _service.removerNotaDoGrupo(
          grupoId: _grupoAtivo!.id,
          notaSapId: item.notaSapId,
        );
        await _carregarDados();
        widget.onAtualizacao?.call();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao remover nota: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _encerrarGrupo() async {
    if (_grupoAtivo == null) return;
    final conf = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encerrar Grupo'),
        content: const Text(
          'Deseja marcar este grupo como encerrado? Ele deixará de ser ativo e suas notas poderão ser associadas a outros grupos futuros.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            child: const Text('Encerrar'),
          ),
        ],
      ),
    );

    if (conf == true) {
      try {
        await _service.encerrarGrupo(_grupoAtivo!.id);
        await _carregarDados();
        widget.onAtualizacao?.call();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao encerrar grupo: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // ===========================================================================
  // CONSTRUÇÃO VISUAL
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _primaryColor));
    }

    if (_erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 36, color: Colors.orange),
              const SizedBox(height: 12),
              Text(_erro!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _carregarDados, child: const Text('Tentar Novamente')),
            ],
          ),
        ),
      );
    }

    if (_grupoAtivo == null) {
      return _buildEstadoSemGrupo();
    }

    return _buildEstadoComGrupo();
  }

  Widget _buildEstadoSemGrupo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 640),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(TFRadius.r12),
            border: Border.all(color: _cardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hub_outlined, size: 40, color: _primaryColor),
              ),
              const SizedBox(height: 16),
              const Text(
                'Nota Sem Vínculo de Programação Conjunta',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textMain),
              ),
              const SizedBox(height: 8),
              const Text(
                'O vínculo agrupa Notas SAP de um mesmo ativo ou local para intervenção unificada, permitindo registrar a previsão macro de programação (Mês/Ano).',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: _textMuted),
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: _abrirDialogCriarGrupo,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Criar Novo Grupo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _abrirDialogVincularGrupoExistente,
                    icon: const Icon(Icons.link, size: 16),
                    label: const Text('Vincular a Grupo Existente'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEstadoComGrupo() {
    final g = _grupoAtivo!;
    final isAtrasada = g.isPrevisaoUltrapassada();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho Principal: Grupo
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(TFRadius.r12),
                  border: Border.all(color: _cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.hub_outlined, color: _primaryColor, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'GRUPO: ${g.nome.toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _textMain,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text(
                            g.statusGrupo.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (g.descricao != null && g.descricao!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(g.descricao!, style: const TextStyle(fontSize: 13, color: _textMuted)),
                    ],
                    if (g.motivo != null && g.motivo!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(g.motivo!, style: const TextStyle(fontSize: 12, color: _textMuted)),
                    ],
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Bloco Previsão de Programação
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 240),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PREVISÃO DE PROGRAMAÇÃO',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _textMuted),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    g.previsaoFormatada.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: g.temPrevisao ? _primaryColor : _textMuted,
                                    ),
                                  ),
                                  if (isAtrasada)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _warningColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: _warningColor.withValues(alpha: 0.4)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.warning_amber_rounded, size: 12, color: _warningColor),
                                          SizedBox(width: 4),
                                          Text(
                                            'Previsão ultrapassada',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _warningColor),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              if (isAtrasada) ...[
                                const SizedBox(height: 2),
                                const Text(
                                  'Mês previsto já decorrido sem programação completa',
                                  style: TextStyle(fontSize: 11, color: _warningColor, fontWeight: FontWeight.w500),
                                ),
                              ],
                              if (g.motivoPrevisao != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Motivo: ${g.motivoPrevisao}',
                                  style: const TextStyle(fontSize: 12, color: _textMuted, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _abrirDialogAlterarPrevisao,
                              icon: const Icon(Icons.edit_calendar_outlined, size: 14),
                              label: Text(g.temPrevisao ? 'Alterar Previsão' : 'Definir Previsão'),
                            ),
                            IconButton(
                              onPressed: _abrirDialogHistoricoPrevisoes,
                              icon: const Icon(Icons.history, size: 18),
                              tooltip: 'Histórico de Previsões',
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Situação Derivada de Programação
                    if (_statusProgramacao != null)
                      Row(
                        children: [
                          const Icon(Icons.checklist_rtl_outlined, size: 18, color: _primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            _statusProgramacao!.resumoFormatado,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textMain),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _encerrarGrupo,
                            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
                            child: const Text('Encerrar Grupo'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Seção: NOTAS VINCULADAS PARA PROGRAMAÇÃO
              Row(
                children: [
                  const Text(
                    'NOTAS VINCULADAS PARA PROGRAMAÇÃO',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textMain),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _surfaceBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _cardBorder),
                    ),
                    child: Text(
                      '${_itens.length}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textMain),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _buscandoNotas ? null : _abrirDialogAdicionarNotaAoGrupo,
                    icon: _buscandoNotas
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.add, size: 14),
                    label: Text(_buscandoNotas ? 'Buscando...' : 'Adicionar Nota'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Lista de Cards das Notas Vinculadas
              ..._itens.map((item) => _buildCardNotaItem(item)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardNotaItem(NotaSapGrupoItem item) {
    final nota = item.nota;
    final isAtual = item.notaSapId == widget.nota.id;
    final isProg = item.isProgramada;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isAtual ? const Color(0xFFF0FDFA) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAtual ? _primaryColor.withValues(alpha: 0.5) : _cardBorder,
          width: isAtual ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isProg ? Colors.green.shade50 : _surfaceBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isProg ? Icons.task_alt : Icons.description_outlined,
              size: 20,
              color: isProg ? Colors.green : _primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Nota ${nota?.nota ?? item.notaSapId}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _textMain),
                    ),
                    if (isAtual) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Nota Atual',
                          style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (isProg && item.tarefasVinculadas.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          'Tarefa #${item.tarefasVinculadas.first.id}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isProg ? Colors.green.shade50 : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isProg ? Colors.green.shade200 : Colors.amber.shade200,
                        ),
                      ),
                      child: Text(
                        isProg ? 'Programada' : 'Ainda não programada',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isProg ? Colors.green.shade800 : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  nota?.descricao ?? 'Carregando descrição...',
                  style: const TextStyle(fontSize: 12, color: _textMain),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (nota?.equipamento != null) ...[
                      Text(
                        'Ativo: ${nota!.equipamento}',
                        style: const TextStyle(fontSize: 11, color: _textMuted),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (nota?.localInstalacao != null)
                      Expanded(
                        child: Text(
                          nota!.localInstalacao!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: _textMuted),
                        ),
                      ),
                    if (!isAtual && nota != null) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _abrirDetalhesNota(nota),
                        icon: const Icon(Icons.open_in_new, size: 12),
                        label: const Text('Abrir Nota'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => _removerNota(item),
            icon: const Icon(Icons.link_off, size: 18, color: Colors.redAccent),
            tooltip: 'Remover esta Nota do grupo',
          ),
        ],
      ),
    );
  }

  void _abrirDetalhesNota(NotaSAP nota) {
    NotaAnaliseWorkspace.abrir(
      context,
      nota: nota,
    ).then((_) {
      _carregarDados();
      widget.onAtualizacao?.call();
    });
  }
}
