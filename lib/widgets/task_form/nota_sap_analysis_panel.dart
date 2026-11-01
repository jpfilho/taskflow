import 'package:flutter/material.dart';
import '../../design_system/theme/taskflow_theme_extension.dart';
import '../../design_system/foundations/tf_radius.dart';
import '../../models/nota_sap.dart';
import '../../models/nota_sap_analise.dart';
import '../../services/nota_sap_analise_service.dart';
import '../nota_workspace/nota_analise_badge.dart';
import '../nota_analise_workspace.dart';

/// Painel de integração controlada entre a Análise da Nota SAP e o formulário de tarefa.
///
/// Princípio fundamental:
/// - Visualizar != copiar
/// - Sugerir != obrigar
/// - Análise != tarefa
///
/// Nenhuma informação é copiada para a tarefa sem ação explícita do usuário.
class NotaSapAnalysisPanel extends StatefulWidget {
  final List<NotaSAP> notas;
  final String currentEscopo;
  final String currentObservacoes;
  final ValueChanged<String> onUsarEscopo;
  final ValueChanged<String> onUsarDiagnostico;
  final ValueChanged<double> onUsarEstimativa;
  final Future<void> Function(NotaSAP nota)? onAbrirWorkspace;
  final NotaSapAnaliseService? service;

  const NotaSapAnalysisPanel({
    super.key,
    required this.notas,
    required this.currentEscopo,
    required this.currentObservacoes,
    required this.onUsarEscopo,
    required this.onUsarDiagnostico,
    required this.onUsarEstimativa,
    this.onAbrirWorkspace,
    this.service,
  });

  @override
  State<NotaSapAnalysisPanel> createState() => _NotaSapAnalysisPanelState();
}

class _NotaSapAnalysisPanelState extends State<NotaSapAnalysisPanel> {
  late final NotaSapAnaliseService _service;
  Map<String, NotaSapResumoAnalise> _resumos = {};
  Map<String, NotaSapAnalise?> _analisesDetalhadas = {};
  bool _isLoading = false;
  bool _hasError = false;
  String? _selectedNotaId;
  final Set<String> _expandedNotaIds = {};

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? NotaSapAnaliseService();
    if (widget.notas.isNotEmpty) {
      _selectedNotaId = widget.notas.first.id;
      _carregarDados();
    }
  }

  @override
  void didUpdateWidget(covariant NotaSapAnalysisPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notas.length != widget.notas.length ||
        !_listasIguais(oldWidget.notas, widget.notas)) {
      if (_selectedNotaId == null && widget.notas.isNotEmpty) {
        _selectedNotaId = widget.notas.first.id;
      }
      _carregarDados();
    }
  }

  bool _listasIguais(List<NotaSAP> a, List<NotaSAP> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  Future<void> _carregarDados({bool forceRefresh = false}) async {
    if (widget.notas.isEmpty) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final ids = widget.notas.map((n) => n.id).toList();
      final resumos = await _service.buscarResumoAnalises(
        ids,
        forceRefresh: forceRefresh,
      );

      final analises = <String, NotaSapAnalise?>{};
      final idsComAnalise = widget.notas
          .where((n) => resumos[n.id]?.status != NotaAnaliseStatus.naoIniciada)
          .map((n) => n.id)
          .toList();

      if (idsComAnalise.isNotEmpty) {
        try {
          final analisesBuscadas = await _service.buscarAnalises(idsComAnalise);
          analises.addAll(analisesBuscadas);
        } catch (_) {
          for (final id in idsComAnalise) {
            try {
              analises[id] = await _service.buscarAnalise(id);
            } catch (_) {
              analises[id] = null;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _resumos = resumos;
          _analisesDetalhadas = analises;
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _abrirWorkspaceComAtualizacao(NotaSAP nota) async {
    if (widget.onAbrirWorkspace != null) {
      await widget.onAbrirWorkspace!(nota);
      if (mounted) {
        await _carregarDados(forceRefresh: true);
      }
    }
  }

  void _confirmarECopiarEscopo(String escopoSugerido, String numeroNota) {
    if (escopoSugerido.trim().isEmpty) return;

    final textoAtual = widget.currentEscopo.trim();
    if (textoAtual.isEmpty) {
      widget.onUsarEscopo(escopoSugerido);
      _mostrarSnack('Escopo da Nota $numeroNota aplicado à tarefa.');
      return;
    }

    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Este campo já possui conteúdo.'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Como deseja utilizar o escopo da análise?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(TFRadius.r8),
              ),
              child: Text(
                escopoSugerido,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancelar'),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, 'adicionar'),
            child: const Text('Adicionar ao conteúdo atual'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'substituir'),
            child: const Text('Substituir conteúdo'),
          ),
        ],
      ),
    ).then((acao) {
      if (acao == 'substituir') {
        widget.onUsarEscopo(escopoSugerido);
        _mostrarSnack('Escopo da tarefa substituído pelo da Nota $numeroNota.');
      } else if (acao == 'adicionar') {
        final prefixo = widget.notas.length > 1 ? '\n\n[Nota SAP $numeroNota]:\n' : '\n\n';
        final novoTexto = '$textoAtual$prefixo$escopoSugerido';
        widget.onUsarEscopo(novoTexto);
        _mostrarSnack('Escopo da Nota $numeroNota adicionado ao conteúdo atual.');
      }
    });
  }

  void _confirmarECopiarDiagnostico(String diagnostico, String numeroNota) {
    if (diagnostico.trim().isEmpty) return;

    final textoAtual = widget.currentObservacoes.trim();
    if (textoAtual.isEmpty) {
      widget.onUsarDiagnostico(diagnostico);
      _mostrarSnack('Diagnóstico da Nota $numeroNota aplicado às observações.');
      return;
    }

    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Este campo já possui conteúdo.'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Como deseja utilizar o diagnóstico da análise técnica?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(TFRadius.r8),
              ),
              child: Text(
                diagnostico,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancelar'),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, 'adicionar'),
            child: const Text('Adicionar ao conteúdo atual'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'substituir'),
            child: const Text('Substituir conteúdo'),
          ),
        ],
      ),
    ).then((acao) {
      if (acao == 'substituir') {
        widget.onUsarDiagnostico(diagnostico);
        _mostrarSnack('Observações substituídas pelo diagnóstico da Nota $numeroNota.');
      } else if (acao == 'adicionar') {
        final prefixo = widget.notas.length > 1
            ? '\n\n[Diagnóstico Técnico - Nota $numeroNota]:\n'
            : '\n\n[Diagnóstico Técnico]:\n';
        final novoTexto = '$textoAtual$prefixo$diagnostico';
        widget.onUsarDiagnostico(novoTexto);
        _mostrarSnack('Diagnóstico da Nota $numeroNota adicionado às observações.');
      }
    });
  }

  void _mostrarSnack(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- Diálogos de Lazy Loading ---

  Future<void> _abrirDialogMateriais(NotaSAP nota) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.inventory_2_outlined, size: 20),
            const SizedBox(width: 8),
            Text('Materiais — Nota ${nota.nota}'),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: FutureBuilder<List<NotaSapMaterial>>(
            future: _service.listarMateriais(nota.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ));
              }
              if (snapshot.hasError) {
                return Text('Erro ao carregar materiais: ${snapshot.error}');
              }
              final materiais = snapshot.data ?? [];
              if (materiais.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Nenhum material cadastrado nesta análise.'),
                );
              }
              return SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 16,
                  columns: const [
                    DataColumn(label: Text('Código SAP')),
                    DataColumn(label: Text('Descrição')),
                    DataColumn(label: Text('Qtd')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: materiais.map((m) {
                    return DataRow(
                      cells: [
                        DataCell(Text(m.codigoSap ?? '-')),
                        DataCell(Text(m.descricao, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        DataCell(Text('${m.quantidade} ${m.unidade}')),
                        DataCell(Text(m.statusMaterial.label)),
                      ],
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }


  Future<void> _abrirDialogDiscussao(NotaSAP nota) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.chat_bubble_outline, size: 20),
            const SizedBox(width: 8),
            Text('Discussão Técnica — Nota ${nota.nota}'),
          ],
        ),
        content: SizedBox(
          width: 550,
          height: 350,
          child: FutureBuilder<List<NotaSapComentario>>(
            future: _service.listarComentarios(nota.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ));
              }
              if (snapshot.hasError) {
                return Text('Erro ao carregar discussão: ${snapshot.error}');
              }
              final comentarios = snapshot.data ?? [];
              if (comentarios.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Nenhum comentário técnico registrado.'),
                );
              }
              return ListView.separated(
                itemCount: comentarios.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final c = comentarios[i];
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(TFRadius.r8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              c.usuarioNome ?? 'Técnico/Analista',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            Text(
                              c.tempoFormatado,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(c.mensagem, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  // --- Construção da UI ---

  @override
  Widget build(BuildContext context) {
    if (widget.notas.isEmpty) return const SizedBox.shrink();

    final colors = context.tfColors;
    final typography = context.tfTypography;

    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceSecondary,
          borderRadius: BorderRadius.circular(TFRadius.r8),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
            ),
            const SizedBox(width: 8),
            Text(
              'Consultando análises técnicas das Notas SAP...',
              style: typography.caption.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(TFRadius.r8),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: Colors.amber.shade800),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Não foi possível carregar a análise técnica.',
                style: typography.caption.copyWith(color: Colors.amber.shade900),
              ),
            ),
            TextButton(
              onPressed: () => _carregarDados(forceRefresh: true),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
              child: Text('Tentar novamente', style: TextStyle(fontSize: 12, color: colors.primary)),
            ),
          ],
        ),
      );
    }

    // Se temos mais de uma nota SAP vinculada
    if (widget.notas.length > 1) {
      return _buildPainelMultiNotas(context);
    }

    // Nota única
    return _buildPainelNotaUnica(context, widget.notas.first);
  }

  Widget _buildPainelMultiNotas(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(TFRadius.r12),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_outlined, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'ANÁLISES DAS NOTAS VINCULADAS (${widget.notas.length})',
                style: typography.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Seletor ou lista expansível das notas
          ...widget.notas.map((nota) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: _buildPainelNotaUnica(context, nota, isMulti: true),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPainelNotaUnica(BuildContext context, NotaSAP nota, {bool isMulti = false}) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    final resumo = _resumos[nota.id];
    final analise = _analisesDetalhadas[nota.id];
    final temAnalise = resumo != null && resumo.status != NotaAnaliseStatus.naoIniciada;
    final isExpanded = _expandedNotaIds.contains(nota.id) || (!isMulti && temAnalise);

    // Se NÃO possui análise prévia
    if (!temAnalise) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(TFRadius.r8),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: colors.textSecondary),
            const SizedBox(width: 8),
            Text(
              'Nota SAP ${nota.nota} — Análise técnica: Não iniciada',
              style: typography.caption.copyWith(color: colors.textSecondary),
            ),
            const Spacer(),
            if (widget.onAbrirWorkspace != null)
              TextButton(
                onPressed: () => _abrirWorkspaceComAtualizacao(nota),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                child: Text('Iniciar Análise', style: TextStyle(fontSize: 12, color: colors.primary)),
              ),
          ],
        ),
      );
    }

    // Possui análise técnica
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(TFRadius.r12),
        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header compacto
          InkWell(
            onTap: () {
              setState(() {
                if (_expandedNotaIds.contains(nota.id)) {
                  _expandedNotaIds.remove(nota.id);
                } else {
                  _expandedNotaIds.add(nota.id);
                }
              });
            },
            borderRadius: BorderRadius.circular(TFRadius.r12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  NotaAnaliseBadge(
                    resumo: resumo,
                    compact: true,
                    onTapGlobal: () => _abrirWorkspaceComAtualizacao(nota),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Análise Técnica Disponível — Nota ${nota.nota}',
                      style: typography.labelMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.onAbrirWorkspace != null)
                    OutlinedButton.icon(
                      onPressed: () => _abrirWorkspaceComAtualizacao(nota),
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: const Text('Ver completa', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(color: colors.borderSubtle),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: colors.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          // Conteúdo Expansível
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Diagnóstico Prévio
                  if (analise?.diagnosticoPrevio != null &&
                      analise!.diagnosticoPrevio!.trim().isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Diagnóstico Prévio:',
                          style: typography.labelMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _confirmarECopiarDiagnostico(
                            analise.diagnosticoPrevio!,
                            nota.nota,
                          ),
                          icon: const Icon(Icons.add_comment_outlined, size: 14),
                          label: const Text('Adicionar às observações', style: TextStyle(fontSize: 11)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.surfaceSecondary.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(TFRadius.r8),
                      ),
                      child: Text(
                        analise.diagnosticoPrevio!,
                        style: typography.bodyMedium.copyWith(color: colors.textSecondary, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 2. Escopo Sugerido
                  if (analise?.escopoDetalhado != null &&
                      analise!.escopoDetalhado!.trim().isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Escopo Sugerido pela Análise:',
                          style: typography.labelMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _confirmarECopiarEscopo(
                            analise.escopoDetalhado!,
                            nota.nota,
                          ),
                          icon: const Icon(Icons.content_copy, size: 14),
                          label: const Text('Usar no escopo da tarefa', style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: colors.surface,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.surfaceSecondary.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(TFRadius.r8),
                      ),
                      child: Text(
                        analise.escopoDetalhado!,
                        style: typography.bodyMedium.copyWith(color: colors.textSecondary, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 3. Recomendações e Parâmetros da Análise
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (analise?.quantidadeTecnicos != null && analise!.quantidadeTecnicos! > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(TFRadius.r8),
                            border: Border.all(color: colors.borderSubtle),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people_outline, size: 14, color: colors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                'Equipe sugerida: ${analise.quantidadeTecnicos} técnicos',
                                style: typography.caption.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      if (analise?.estimativaHoras != null && analise!.estimativaHoras! > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(TFRadius.r8),
                            border: Border.all(color: colors.borderSubtle),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.timer_outlined, size: 14, color: colors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                'Estimativa: ${analise.estimativaHoras}h',
                                style: typography.caption.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () {
                                  widget.onUsarEstimativa(analise.estimativaHoras!);
                                  _mostrarSnack('Estimativa de ${analise.estimativaHoras}h aplicada.');
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Text(
                                    'Usar',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: colors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (analise?.necessitaDesligamento == true)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(TFRadius.r8),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.flash_off, size: 14, color: Colors.amber.shade900),
                              const SizedBox(width: 4),
                              Text(
                                'Desligamento indicado: SIM',
                                style: typography.caption.copyWith(
                                  color: Colors.amber.shade900,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (analise?.valorPv != null && (analise?.valorPv ?? 0) > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(TFRadius.r8),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.attach_money, size: 14, color: Colors.red.shade900),
                              const SizedBox(width: 4),
                              Text(
                                'PV: R\$ ${analise!.valorPv!.toStringAsFixed(2)}',
                                style: typography.caption.copyWith(
                                  color: Colors.red.shade900,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  const SizedBox(height: 12),

                  // 4. Card Compacto de Anexos e Evidências SAP
                  _buildCardCompactoAnexos(context, nota, resumo),

                  const SizedBox(height: 8),

                  // 5. Ações Complementares (Materiais e Discussão)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.inventory_2_outlined, size: 16),
                        label: Text('Materiais (${resumo.totalMateriais})'),
                        onPressed: () => _abrirDialogMateriais(nota),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.chat_bubble_outline, size: 16),
                        label: Text('Discussão (${resumo.totalComentarios})'),
                        onPressed: () => _abrirDialogDiscussao(nota),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardCompactoAnexos(
    BuildContext context,
    NotaSAP nota,
    NotaSapResumoAnalise resumo,
  ) {
    final colors = context.tfColors;
    final total = resumo.quantidadeAnexos;

    final partes = <String>[];
    if (resumo.quantidadeImagens > 0) {
      partes.add('${resumo.quantidadeImagens} imag${resumo.quantidadeImagens > 1 ? 'ens' : 'em'}');
    }
    if (resumo.quantidadePdfs > 0) {
      partes.add('${resumo.quantidadePdfs} PDF${resumo.quantidadePdfs > 1 ? 's' : ''}');
    }
    if (resumo.quantidadeVideos > 0) {
      partes.add('${resumo.quantidadeVideos} vídeo${resumo.quantidadeVideos > 1 ? 's' : ''}');
    }
    if (resumo.quantidadePlanilhas > 0) {
      partes.add('${resumo.quantidadePlanilhas} planilha${resumo.quantidadePlanilhas > 1 ? 's' : ''}');
    }
    if (resumo.quantidadeDocumentos > 0) {
      partes.add('${resumo.quantidadeDocumentos} doc${resumo.quantidadeDocumentos > 1 ? 's' : ''}');
    }
    if (resumo.quantidadeAudios > 0) {
      partes.add('${resumo.quantidadeAudios} áudio${resumo.quantidadeAudios > 1 ? 's' : ''}');
    }
    if (resumo.quantidadeOutros > 0) {
      partes.add('${resumo.quantidadeOutros} outro${resumo.quantidadeOutros > 1 ? 's' : ''}');
    }

    final discriminacao = partes.isNotEmpty
        ? partes.join(' · ')
        : (total > 0 ? '$total arquivo(s)' : 'Nenhum anexo');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(TFRadius.r8),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.attach_file, color: colors.primary, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'ANEXOS E EVIDÊNCIAS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: colors.primary,
                      ),
                    ),
                    if (resumo.quantidadeRelevantes > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '★ ${resumo.quantidadeRelevantes} relevante${resumo.quantidadeRelevantes > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$total arquivo${total == 1 ? '' : 's'}${total > 0 ? ' • $discriminacao' : ''}',
                  style: TextStyle(fontSize: 11, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: const Icon(Icons.open_in_new, size: 13),
            label: const Text('Ver anexos', style: TextStyle(fontSize: 11)),
            onPressed: () {
              NotaAnaliseWorkspace.abrir(
                context,
                nota: nota,
                initialTab: 3, // Aba Anexos
              );
            },
          ),
        ],
      ),
    );
  }
}
