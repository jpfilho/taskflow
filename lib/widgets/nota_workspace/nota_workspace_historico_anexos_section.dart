import 'package:flutter/material.dart';
import '../../design_system/theme/taskflow_theme_extension.dart';
import '../../design_system/foundations/tf_radius.dart';
import '../../models/nota_sap.dart';
import '../../models/nota_sap_analise.dart';
import '../../models/nota_sap_analise_evidencia.dart';
import '../../models/nota_historico_tecnico.dart';
import '../../models/nota_historico_visual.dart';
import '../../services/nota_historico_tecnico_service.dart';
import '../../services/nota_historico_visual_service.dart';
import '../../services/nota_sap_analise_service.dart';
import 'nota_anexo_viewer_dialog.dart';
import 'nota_comparador_visual_dialog.dart';
import 'nota_workspace_historico_visual_section.dart';

/// Fonte de histórico selecionada no painel integrado
enum FonteHistoricoAnexo {
  notasAnteriores,
  albunsCampo,
}

/// Orquestrador do Histórico de Anexos Integrado na Aba de Anexos da Nota SAP.
///
/// Unifica em um único painel lateral direito:
/// 1. Anexos de Notas SAP Anteriores (Critérios A: Mesmo Equipamento e B: Mesma Estrutura)
/// 2. Fotografias de Campo dos Álbuns (reutilizando NotaWorkspaceHistoricoVisualSection)
class NotaWorkspaceHistoricoAnexosSection extends StatefulWidget {
  final NotaSAP nota;
  final List<NotaSapAnexo>? anexosAtuais;
  final NotaHistoricoTecnicoService? historicoTecnicoService;
  final NotaHistoricoVisualService? historicoVisualService;
  final NotaSapAnaliseService? analiseService;
  final void Function(NotaSAP notaHistorica)? onAbrirNotaHistorica;
  final VoidCallback? onEvidenciasAlteradas;
  final EdgeInsetsGeometry? customMargin;

  const NotaWorkspaceHistoricoAnexosSection({
    super.key,
    required this.nota,
    this.anexosAtuais,
    this.historicoTecnicoService,
    this.historicoVisualService,
    this.analiseService,
    this.onAbrirNotaHistorica,
    this.onEvidenciasAlteradas,
    this.customMargin,
  });

  @override
  State<NotaWorkspaceHistoricoAnexosSection> createState() =>
      _NotaWorkspaceHistoricoAnexosSectionState();
}

class _NotaWorkspaceHistoricoAnexosSectionState
    extends State<NotaWorkspaceHistoricoAnexosSection> {
  late final NotaHistoricoTecnicoService _historicoTecnicoService;
  late final NotaHistoricoVisualService _historicoVisualService;
  late final NotaSapAnaliseService _analiseService;

  // Fonte selecionada
  FonteHistoricoAnexo _fonteSelecionada = FonteHistoricoAnexo.notasAnteriores;
  bool _usuarioAlterouFonteManualmente = false;

  // Estados de Notas Anteriores
  bool _carregandoNotas = true;
  String? _erroNotas;
  List<NotaHistoricoTecnicoItem> _notasComAnexos = [];
  int _totalAnexosHistoricos = 0;
  final Map<String, NotaHistoricoTecnicoItem> _detalhesLazyPorNotaId = {};
  final Set<String> _carregandoDetalhesIds = {};

  // Estados de Álbuns de Campo
  bool _carregandoAlbuns = true;
  HistoricoVisualResultado? _resultadoAlbuns;

  // Mapeamento de anexoId histórico -> Lista de tipos de vínculo (seções) já em uso na Nota atual
  Map<String, List<NotaTipoVinculoEvidencia>> _usosAnexosHistoricos = {};

  @override
  void initState() {
    super.initState();
    _historicoTecnicoService =
        widget.historicoTecnicoService ?? NotaHistoricoTecnicoService();
    _historicoVisualService =
        widget.historicoVisualService ?? NotaHistoricoVisualService();
    _analiseService = widget.analiseService ?? NotaSapAnaliseService();

    _carregarDados();
  }

  @override
  void didUpdateWidget(covariant NotaWorkspaceHistoricoAnexosSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nota.id != widget.nota.id ||
        oldWidget.nota.equipamento != widget.nota.equipamento ||
        oldWidget.nota.sala != widget.nota.sala ||
        oldWidget.nota.localInstalacao != widget.nota.localInstalacao) {
      _usuarioAlterouFonteManualmente = false;
      _detalhesLazyPorNotaId.clear();
      _carregandoDetalhesIds.clear();
      _usosAnexosHistoricos.clear();
      _carregarDados();
    }
  }

  Future<void> _carregarUsosAnexosHistoricos() async {
    try {
      final usos = await _analiseService.buscarUsoDosAnexosHistoricos(widget.nota.id);
      if (mounted) {
        setState(() {
          _usosAnexosHistoricos = usos;
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar usos de anexos historicos: $e');
    }
  }

  Future<void> _carregarDados({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _carregandoNotas = true;
      _carregandoAlbuns = true;
      _erroNotas = null;
    });

    // 1. Disparo concorrente: Notas Anteriores (A/B), Álbuns de Campo e Usos de Anexos Históricos
    final futureNotas = _carregarNotasHistoricasAB(forceRefresh: forceRefresh);
    final futureAlbuns = _carregarAlbunsCampo();
    final futureUsos = _carregarUsosAnexosHistoricos();

    await Future.wait([futureNotas, futureAlbuns, futureUsos]);

    if (!mounted) return;

    // Regra de Seleção Padrão (Itens 18, 19, 34):
    // Se o usuário já interagiu manualmente, preservar sua escolha!
    if (!_usuarioAlterouFonteManualmente) {
      if (_notasComAnexos.isNotEmpty) {
        _fonteSelecionada = FonteHistoricoAnexo.notasAnteriores;
      } else if ((_resultadoAlbuns?.totalGlobal ?? 0) > 0) {
        _fonteSelecionada = FonteHistoricoAnexo.albunsCampo;
      } else {
        _fonteSelecionada = FonteHistoricoAnexo.notasAnteriores;
      }
      setState(() {});
    }
  }

  /// FASE 2: Carrega Notas Anteriores com Critérios A (Equipamento) e B (Estrutura)
  /// e inventário em lote para identificar totalAnexos > 0 sem N+1.
  Future<void> _carregarNotasHistoricasAB({bool forceRefresh = false}) async {
    try {
      final resAB = await _historicoTecnicoService.carregarHistoricoAtivoUtil(
        notaReferencia: widget.nota,
        forceRefresh: forceRefresh,
      );

      // Regra 12 & 13: Filtrar estritamente notas com totalAnexos > 0
      final filtradas = resAB.todosItensDeduplicados
          .where((item) => item.totalAnexos > 0)
          .toList();

      final totalAnexos = filtradas.fold<int>(
        0,
        (acc, item) => acc + item.totalAnexos,
      );

      if (!mounted) return;
      setState(() {
        _carregandoNotas = false;
        _notasComAnexos = filtradas;
        _totalAnexosHistoricos = totalAnexos;
      });

      // Lazy Loading progressivo dos primeiros itens visíveis (sem N+1 discriminado)
      _preCarregarPrimeirosDetalhes(filtradas.take(5).toList());

      // FASE 4 (Progressivo): Carregar Similaridade D em segundo plano sem bloquear a tela
      _carregarSimilaresProgressivo(resAB);
    } catch (e) {
      debugPrint('❌ [NotaWorkspaceHistoricoAnexosSection] Erro ao carregar notas A/B: $e');
      if (mounted) {
        setState(() {
          _carregandoNotas = false;
          _erroNotas = 'Erro ao consultar notas anteriores: $e';
        });
      }
    }
  }

  /// FASE 3: Carrega Álbuns de Campo em paralelo
  Future<void> _carregarAlbunsCampo() async {
    try {
      final res = await _historicoVisualService.buscarHistoricoVisual(widget.nota);
      if (!mounted) return;
      setState(() {
        _carregandoAlbuns = false;
        _resultadoAlbuns = res;
      });
    } catch (e) {
      debugPrint('❌ [NotaWorkspaceHistoricoAnexosSection] Erro ao consultar álbuns: $e');
      if (mounted) {
        setState(() {
          _carregandoAlbuns = false;
        });
      }
    }
  }

  /// FASE 4: Carregamento progressivo de similares (Critério D) sem bloquear primeira pintura
  Future<void> _carregarSimilaresProgressivo(
    NotaHistoricoTecnicoResultado resAB,
  ) async {
    try {
      final resComSim =
          await _historicoTecnicoService.carregarSimilaresAssincrono(resAB);

      // Adiciona novos itens de D apenas se possuírem anexos e ainda não estiverem na lista
      final novosItens = <NotaHistoricoTecnicoItem>[];
      final idsExistentes = _notasComAnexos.map((i) => i.notaSap.id).toSet();

      for (final item in resComSim.todosItensDeduplicados) {
        if (!idsExistentes.contains(item.notaSap.id) && item.totalAnexos > 0) {
          novosItens.add(item);
        }
      }

      if (novosItens.isNotEmpty && mounted) {
        setState(() {
          _notasComAnexos = [..._notasComAnexos, ...novosItens];
          _totalAnexosHistoricos = _notasComAnexos.fold<int>(
            0,
            (acc, item) => acc + item.totalAnexos,
          );
        });
        _preCarregarPrimeirosDetalhes(novosItens.take(3).toList());
      }
    } catch (e) {
      debugPrint('⚠️ [NotaWorkspaceHistoricoAnexosSection] Erro em similares progressivos: $e');
    }
  }

  /// Lazy loading dos detalhes de anexos para os primeiros cards visíveis
  Future<void> _preCarregarPrimeirosDetalhes(
    List<NotaHistoricoTecnicoItem> itens,
  ) async {
    for (final item in itens) {
      final id = item.notaSap.id;
      if (_detalhesLazyPorNotaId.containsKey(id) ||
          _carregandoDetalhesIds.contains(id)) {
        continue;
      }

      _carregandoDetalhesIds.add(id);
      try {
        final atualizado =
            await _historicoTecnicoService.carregarDetalhesLazy(item);
        if (mounted) {
          setState(() {
            _detalhesLazyPorNotaId[id] = atualizado;
            _carregandoDetalhesIds.remove(id);
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => _carregandoDetalhesIds.remove(id));
        }
      }
    }
  }

  Future<void> _carregarDetalhesDeNota(NotaHistoricoTecnicoItem item) async {
    final id = item.notaSap.id;
    if (_detalhesLazyPorNotaId.containsKey(id) ||
        _carregandoDetalhesIds.contains(id)) {
      return;
    }

    setState(() => _carregandoDetalhesIds.add(id));
    try {
      final atualizado =
          await _historicoTecnicoService.carregarDetalhesLazy(item);
      if (mounted) {
        setState(() {
          _detalhesLazyPorNotaId[id] = atualizado;
          _carregandoDetalhesIds.remove(id);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _carregandoDetalhesIds.remove(id));
      }
    }
  }

  void _selecionarFonte(FonteHistoricoAnexo fonte) {
    setState(() {
      _fonteSelecionada = fonte;
      _usuarioAlterouFonteManualmente = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    return Container(
      margin: widget.customMargin ?? EdgeInsets.only(top: spacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(TFRadius.r12),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Cabeçalho com Título, Contadores e Seletor de Fontes
          _buildCabecalho(colors, typography, spacing),

          const Divider(height: 1),

          // 2. Conteúdo da Fonte Selecionada
          Padding(
            padding: EdgeInsets.all(spacing.md),
            child: _buildConteudoPrincipal(colors, typography, spacing),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CABEÇALHO DO ORQUESTRADOR
  // ---------------------------------------------------------------------------
  Widget _buildCabecalho(
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    final qtdNotas = _notasComAnexos.length;
    final qtdFotosAlbuns = _resultadoAlbuns?.totalGlobal ?? 0;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.history_edu, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Histórico de Anexos',
                      style: typography.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Subtítulo com contadores discriminados (Itens 32 e 33)
                    Text(
                      _fonteSelecionada == FonteHistoricoAnexo.notasAnteriores
                          ? (_carregandoNotas
                              ? 'Consultando notas anteriores com anexos...'
                              : '$qtdNotas Notas • $_totalAnexosHistoricos anexos encontrados')
                          : (_carregandoAlbuns
                              ? 'Consultando álbuns de campo...'
                              : '$qtdFotosAlbuns fotografias registradas nos álbuns'),
                      style: typography.caption.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Recarregar histórico de anexos',
                onPressed: () => _carregarDados(forceRefresh: true),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Seletor de Fontes: [Notas Anteriores (X)] [Álbuns de Campo (Y)]
          Row(
            children: [
              Expanded(
                child: _buildAbaSeletor(
                  label: 'Notas Anteriores',
                  contador: _carregandoNotas ? null : qtdNotas,
                  icon: Icons.history,
                  selecionado:
                      _fonteSelecionada == FonteHistoricoAnexo.notasAnteriores,
                  colors: colors,
                  onTap: () => _selecionarFonte(FonteHistoricoAnexo.notasAnteriores),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAbaSeletor(
                  label: 'Álbuns de Campo',
                  contador: _carregandoAlbuns ? null : qtdFotosAlbuns,
                  icon: Icons.photo_library_outlined,
                  selecionado:
                      _fonteSelecionada == FonteHistoricoAnexo.albunsCampo,
                  colors: colors,
                  onTap: () => _selecionarFonte(FonteHistoricoAnexo.albunsCampo),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAbaSeletor({
    required String label,
    required int? contador,
    required IconData icon,
    required bool selecionado,
    required dynamic colors,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(TFRadius.r8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selecionado
              ? colors.primary.withAlpha(25)
              : colors.surfaceSecondary,
          borderRadius: BorderRadius.circular(TFRadius.r8),
          border: Border.all(
            color: selecionado ? colors.primary : colors.borderSubtle,
            width: selecionado ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selecionado ? colors.primary : colors.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: selecionado ? FontWeight.bold : FontWeight.w500,
                  color: selecionado ? colors.primary : colors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (contador != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selecionado ? colors.primary : colors.borderSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  contador.toString(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: selecionado ? Colors.white : colors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CONTEÚDO PRINCIPAL
  // ---------------------------------------------------------------------------
  Widget _buildConteudoPrincipal(
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    if (_fonteSelecionada == FonteHistoricoAnexo.albunsCampo) {
      return _buildVisaoAlbuns(colors, typography, spacing);
    }
    return _buildVisaoNotasAnteriores(colors, typography, spacing);
  }

  // ---------------------------------------------------------------------------
  // VISÃO 1: NOTAS ANTERIORES
  // ---------------------------------------------------------------------------
  Widget _buildVisaoNotasAnteriores(
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    if (_carregandoNotas && _notasComAnexos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 2),
              SizedBox(height: 12),
              Text(
                'Buscando notas anteriores no mesmo equipamento/estrutura...',
                style: TextStyle(fontSize: 12.0, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_erroNotas != null && _notasComAnexos.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Text(
            _erroNotas!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 12.0),
          ),
        ),
      );
    }

    // Estado Vazio Integrado (Itens 34, 35 e 36)
    if (_notasComAnexos.isEmpty) {
      final temAlbuns = (_resultadoAlbuns?.totalGlobal ?? 0) > 0;
      final nomeLocal = widget.nota.local ?? widget.nota.localInstalacao ?? 'este local';
      final nomeSala = widget.nota.sala;
      final temSala = nomeSala != null && nomeSala.trim().isNotEmpty;

      return Container(
        padding: EdgeInsets.all(spacing.lg),
        decoration: BoxDecoration(
          color: colors.surfaceSecondary,
          borderRadius: BorderRadius.circular(TFRadius.r8),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Column(
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 40,
              color: colors.textSecondary.withAlpha(140),
            ),
            const SizedBox(height: 8),
            Text(
              temSala
                  ? (temAlbuns
                      ? 'Nenhuma Nota anterior com anexos para o local "$nomeLocal" e sala "$nomeSala".'
                      : 'Nenhum anexo histórico encontrado para o local "$nomeLocal" e sala "$nomeSala".')
                  : (temAlbuns
                      ? 'Nenhuma Nota anterior com anexos para este ativo/local.'
                      : 'Nenhum anexo histórico encontrado para este ativo/local.'),
              style: typography.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              temAlbuns
                  ? 'Entretanto, existem fotografias registradas nos Álbuns de Campo deste local e sala.'
                  : 'Não foram localizadas notas anteriores com evidências anexadas nem fotos de campo para este local e sala.',
              style: typography.caption.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (temAlbuns) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.photo_library, size: 16),
                label: const Text('Ver Álbuns de Campo'),
                onPressed: () =>
                    _selecionarFonte(FonteHistoricoAnexo.albunsCampo),
              ),
            ],
          ],
        ),
      );
    }

    // Lista de Notas Anteriores Agrupadas (Regra 14: NOTA HISTÓRICA -> ANEXOS)
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _notasComAnexos.length,
      separatorBuilder: (_, __) => SizedBox(height: spacing.md),
      itemBuilder: (context, index) {
        final item = _notasComAnexos[index];
        return _buildCardNotaHistorica(item, colors, typography, spacing);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // CARD DA NOTA HISTÓRICA COM ANEXOS (Item 14, 15, 16, 17, 37)
  // ---------------------------------------------------------------------------
  Widget _buildCardNotaHistorica(
    NotaHistoricoTecnicoItem item,
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    final itemDetalhado = _detalhesLazyPorNotaId[item.notaSap.id] ?? item;
    final isCarregandoDetalhes =
        _carregandoDetalhesIds.contains(item.notaSap.id);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(TFRadius.r8),
        border: Border.all(
          color: item.ehMesmoEquipamento
              ? Colors.teal.shade300
              : colors.borderSubtle,
          width: item.ehMesmoEquipamento ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho do Card
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Linha 1: Número da Nota SAP + Data Absoluta (Item 16 e 17)
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Nota SAP ${item.notaSap.nota.isNotEmpty ? item.notaSap.nota : item.notaSap.id}',
                        style: typography.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (item.dataFormatada.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: colors.borderSubtle),
                        ),
                        child: Text(
                          item.dataFormatada,
                          style: typography.caption.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11.0,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),

                // Linha 2: Badges de Critério Físico e Ativo
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildBadgeCriterio(item),
                    if (item.notaSap.sala != null &&
                        item.notaSap.sala!.trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.indigo.shade200),
                        ),
                        child: Text(
                          'Torre / Vão ${item.notaSap.sala}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade800,
                          ),
                        ),
                      ),
                    if (item.ehSimilar && item.scoreSimilaridade != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.lightBlue.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.lightBlue.shade200),
                        ),
                        child: Text(
                          'Similar (${item.scoreSimilaridade!.toStringAsFixed(0)}%)',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.lightBlue.shade900,
                          ),
                        ),
                      ),
                    if (item.notaSap.statusSistema != null &&
                        item.notaSap.statusSistema!.trim().isNotEmpty)
                      Builder(builder: (context) {
                        final sis = item.notaSap.statusSistema!.toUpperCase();
                        final isConcluida = sis.contains('ENCE') ||
                            sis.contains('ENTE') ||
                            sis.contains('MSEN');
                        final bg = isConcluida
                            ? const Color(0xFFF0FDF4)
                            : const Color(0xFFFFF7ED);
                        final border = isConcluida
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFFFDBA74);
                        final textCol = isConcluida
                            ? const Color(0xFF15803D)
                            : const Color(0xFFC2410C);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: border),
                          ),
                          child: Text(
                            isConcluida
                                ? 'CONCLUÍDA (${item.notaSap.statusSistema!.trim()})'
                                : 'ABERTA (${item.notaSap.statusSistema!.trim()})',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: textCol,
                            ),
                          ),
                        );
                      }),
                    if (item.notaSap.statusUsuario != null &&
                        item.notaSap.statusUsuario!.trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFDDD6FE)),
                        ),
                        child: Text(
                          'Usu: ${item.notaSap.statusUsuario!.trim()}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6D28D9),
                          ),
                        ),
                      ),
                  ],
                ),

                // Linha 3: Descrição da Falha Técnica
                if (item.notaSap.descricao != null &&
                    item.notaSap.descricao!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.notaSap.descricao!,
                    style: typography.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          const Divider(height: 1),

          // Seção de Anexos da Nota (Grade / Carrossel Horizontal)
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.attachment, size: 14, color: colors.primary),
                    const SizedBox(width: 4),
                    Text(
                      '${item.totalAnexos} ${item.totalAnexos == 1 ? "anexo" : "anexos"}',
                      style: typography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• Consulta',
                      style: TextStyle(
                        fontSize: 11.0,
                        color: Colors.amber.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    // Ação [Ver Nota] (Item 44 e 45)
                    if (widget.onAbrirNotaHistorica != null)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                        ),
                        icon: const Icon(Icons.open_in_new, size: 13),
                        label: const Text(
                          'Ver Nota',
                          style: TextStyle(fontSize: 11.0),
                        ),
                        onPressed: () =>
                            widget.onAbrirNotaHistorica!(item.notaSap),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Miniaturas Carregadas Sob Demanda
                if (isCarregandoDetalhes && itemDetalhado.anexos.isEmpty)
                  Container(
                    height: 84,
                    decoration: BoxDecoration(
                      color: colors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(TFRadius.r8),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (itemDetalhado.anexos.isEmpty)
                  // Se ainda não carregou os detalhes lazy, oferece botão para expandir
                  InkWell(
                    onTap: () => _carregarDetalhesDeNota(item),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: colors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(TFRadius.r8),
                        border: Border.all(color: colors.borderSubtle),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.visibility,
                                size: 16, color: colors.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Visualizar ${item.totalAnexos} anexos desta nota',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  // Lista de Miniaturas dos Anexos
                  SizedBox(
                    height: 88,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: itemDetalhado.anexos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, idx) {
                        final anexo = itemDetalhado.anexos[idx];
                        return _buildMiniaturaAnexo(
                          anexo: anexo,
                          item: item,
                          anexosDaNota: itemDetalhado.anexos,
                          indice: idx,
                          colors: colors,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MINIATURA INDIVIDUAL DE ANEXO (FOTO / PDF / DOC)
  // ---------------------------------------------------------------------------
  Widget _buildMiniaturaAnexo({
    required NotaSapAnexo anexo,
    required NotaHistoricoTecnicoItem item,
    required List<NotaSapAnexo> anexosDaNota,
    required int indice,
    required dynamic colors,
  }) {
    final ehImagem = anexo.tipoArquivo == NotaAnexoTipo.imagem;
    final ehPdf = anexo.tipoArquivo == NotaAnexoTipo.pdf;

    return Tooltip(
      message: anexo.nomeOriginal ?? anexo.nomeArquivo,
      child: InkWell(
        borderRadius: BorderRadius.circular(TFRadius.r8),
        onTap: () {
          // Abertura do Viewer em modo Somente Leitura Histórico (Itens 26 a 29)
          NotaAnexoViewerDialog.abrir(
            context: context,
            anexos: anexosDaNota,
            indiceInicial: indice,
            service: _analiseService,
            isHistoricoReadOnly: true,
            notaHistoricaNumero: item.notaSap.nota.isNotEmpty
                ? item.notaSap.nota
                : item.notaSap.id,
            notaHistoricaData: item.dataFormatada,
            notaAtual: widget.nota,
            anexosAtuais: widget.anexosAtuais,
            contextoFiltro:
                'Histórico - Nota SAP ${item.notaSap.nota.isNotEmpty ? item.notaSap.nota : item.notaSap.id}',
          ).then((_) {
            _carregarUsosAnexosHistoricos();
            widget.onEvidenciasAlteradas?.call();
          });
        },
        child: Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: colors.surfaceSecondary,
            borderRadius: BorderRadius.circular(TFRadius.r8),
            border: Border.all(color: colors.borderSubtle),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (ehImagem)
                FutureBuilder<String>(
                  future: _analiseService.obterUrlAssinada(anexo),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                      );
                    }
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      return Image.network(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image,
                              size: 26, color: Colors.blueGrey),
                        ),
                      );
                    }
                    return const Center(
                      child: Icon(Icons.image, size: 28, color: Colors.blueGrey),
                    );
                  },
                )
              else
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        ehPdf ? Icons.picture_as_pdf : Icons.description,
                        size: 30,
                        color: ehPdf ? Colors.redAccent : Colors.blueGrey,
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: ehPdf ? Colors.red.shade50 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          ehPdf ? 'PDF' : 'DOC',
                          style: TextStyle(
                            fontSize: 9.0,
                            fontWeight: FontWeight.bold,
                            color: ehPdf ? Colors.red.shade900 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Indicador discreto: Evidência em uso (Requisito 42)
              if (_usosAnexosHistoricos.containsKey(anexo.id))
                Positioned(
                  top: 3,
                  left: 3,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withAlpha(235), // Âmbar 600
                      borderRadius: BorderRadius.circular(TFRadius.r4),
                      border: Border.all(color: Colors.white, width: 0.5),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_edu, size: 9, color: Colors.white),
                        SizedBox(width: 2),
                        Text(
                          'Evidência em uso',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Botão Comparar dedicado (Requisitos 5 e 6.A - apenas para imagens)
              if (ehImagem)
                Positioned(
                  top: 3,
                  right: 3,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(TFRadius.r4),
                      onTap: () {
                        NotaComparadorVisualDialog.abrirComNotaHistorica(
                          context: context,
                          notaAtual: widget.nota,
                          anexosAtuais: widget.anexosAtuais ?? [],
                          notaHistorica: item.notaSap,
                          anexosHistoricos: anexosDaNota,
                          indiceHistoricoInicial: indice,
                          service: _analiseService,
                        ).then((_) {
                          _carregarUsosAnexosHistoricos();
                          widget.onEvidenciasAlteradas?.call();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F766E).withAlpha(230),
                          borderRadius: BorderRadius.circular(TFRadius.r4),
                          border: Border.all(color: Colors.white70, width: 0.5),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.compare_arrows, size: 10, color: Colors.white),
                            SizedBox(width: 2),
                            Text(
                              'Comparar',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Rótulo inferior com nome resumido
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  color: Colors.black.withAlpha(160),
                  child: Text(
                    anexo.nomeOriginal ?? anexo.nomeArquivo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.0,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // VISÃO 2: ÁLBUNS DE CAMPO (Reutilização de NotaWorkspaceHistoricoVisualSection)
  // ---------------------------------------------------------------------------
  Widget _buildVisaoAlbuns(
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    // Reutilização direta da experiência de álbuns e seu visualizador existente (Itens 30 e 31)
    return NotaWorkspaceHistoricoVisualSection(
      nota: widget.nota,
      anexosAtuais: widget.anexosAtuais,
      service: _historicoVisualService,
      analiseService: _analiseService,
      onEvidenciasAlteradas: widget.onEvidenciasAlteradas,
      customMargin: EdgeInsets.zero,
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS VISUAIS
  // ---------------------------------------------------------------------------
  Widget _buildBadgeCriterio(NotaHistoricoTecnicoItem item) {
    final String label;
    final Color cor;
    final Color bg;

    switch (item.criterioFisicoPrincipal) {
      case NotaHistoricoCriterioFisico.mesmoEquipamento:
        label = 'Mesmo Equipamento';
        cor = const Color(0xFF0F766E);
        bg = const Color(0xFFCCFBF1);
        break;
      case NotaHistoricoCriterioFisico.mesmaEstrutura:
        label = 'Mesma Estrutura';
        cor = const Color(0xFF4338CA);
        bg = const Color(0xFFEEF2FF);
        break;
      case NotaHistoricoCriterioFisico.mesmoLocal:
        label = 'Mesmo Local';
        cor = const Color(0xFFB45309);
        bg = const Color(0xFFFEF3C7);
        break;
      case NotaHistoricoCriterioFisico.apenasSimilaridade:
        label = 'Similar';
        cor = const Color(0xFF0369A1);
        bg = const Color(0xFFE0F2FE);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: cor.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: cor,
        ),
      ),
    );
  }
}
