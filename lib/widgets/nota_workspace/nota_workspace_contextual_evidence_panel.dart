import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../design_system/foundations/tf_radius.dart';
import '../../design_system/theme/taskflow_theme_extension.dart';
import '../../models/nota_sap.dart';
import '../../models/nota_sap_analise.dart';
import '../../models/nota_sap_analise_evidencia.dart';
import '../../models/nota_historico_visual.dart';
import '../../services/nota_sap_analise_service.dart';
import '../../services/nota_historico_visual_service.dart';
import '../../models/nota_historico_tecnico.dart';
import '../../services/nota_historico_tecnico_service.dart';
import '../../features/media_albums/data/repositories/supabase_media_repository.dart';
import '../../features/media_albums/data/models/media_image.dart';
import '../nota_analise_workspace.dart';
import 'nota_anexo_viewer_dialog.dart';

enum _FiltroPainelEvidencia {
  secaoAtual,
  todas,
  historicoVisual,
  notasAnteriores,
}

/// Painel Contextual de Evidências Integrado à Análise Técnica (Fase 4C)
/// Responsável pela inspeção contínua lateral, preview de imagens/documentos,
/// rastreabilidade de versões e comparação visual lado a lado.
class NotaWorkspaceContextualEvidencePanel extends StatefulWidget {
  final String notaSapId;
  final NotaSAP? nota;
  final List<NotaSapAnaliseEvidencia> evidencias;
  final NotaSapAnaliseEvidencia? selectedEvidence;
  final NotaTipoVinculoEvidencia activeSection;
  final NotaSapAnaliseService service;
  final ValueChanged<NotaSapAnaliseEvidencia?> onSelectEvidence;
  final VoidCallback onRefreshEvidencias;
  final void Function(NotaTipoVinculoEvidencia secao) onVincularNovaEvidencia;
  final void Function(NotaSAP notaHistorica)? onAbrirNotaHistorica;
  final bool isReadOnly;

  const NotaWorkspaceContextualEvidencePanel({
    super.key,
    required this.notaSapId,
    this.nota,
    required this.evidencias,
    required this.selectedEvidence,
    required this.activeSection,
    required this.service,
    required this.onSelectEvidence,
    required this.onRefreshEvidencias,
    required this.onVincularNovaEvidencia,
    this.onAbrirNotaHistorica,
    this.isReadOnly = false,
  });

  @override
  State<NotaWorkspaceContextualEvidencePanel> createState() =>
      _NotaWorkspaceContextualEvidencePanelState();
}

class _NotaWorkspaceContextualEvidencePanelState
    extends State<NotaWorkspaceContextualEvidencePanel> {
  _FiltroPainelEvidencia _filtro = _FiltroPainelEvidencia.secaoAtual;

  // Estado para modo de comparação lado a lado (Fase 4C - MVP)
  bool _modoComparacao = false;
  HistoricoVisualItem? _fotoHistoricaComparacao;

  // Cache e carregamento lazy do Histórico Visual
  HistoricoVisualResultado? _historicoResultado;
  bool _isLoadingHistorico = false;

  // Cache e carregamento lazy do Histórico Técnico de Notas Anteriores
  NotaHistoricoTecnicoResultado? _historicoTecnicoResultado;
  bool _isLoadingHistoricoTecnico = false;
  final Set<String> _expandidosHistoricoIds = {};
  final Map<String, NotaHistoricoTecnicoItem> _itensHistoricoDetalhados = {};
  final Set<String> _carregandoDetalhesHistorico = {};

  Future<void> _carregarHistoricoTecnicoSeNecessario() async {
    if (_historicoTecnicoResultado != null || _isLoadingHistoricoTecnico || widget.nota == null) {
      return;
    }

    setState(() => _isLoadingHistoricoTecnico = true);
    try {
      final s = NotaHistoricoTecnicoService();
      final res = await s.buscarHistoricoTecnico(notaReferencia: widget.nota!);
      if (mounted) {
        setState(() {
          _historicoTecnicoResultado = res;
          _isLoadingHistoricoTecnico = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingHistoricoTecnico = false);
    }
  }

  Future<void> _alternarExpansaoNotaHistorica(NotaHistoricoTecnicoItem item) async {
    final id = item.notaSap.id;
    if (_expandidosHistoricoIds.contains(id)) {
      setState(() => _expandidosHistoricoIds.remove(id));
      return;
    }

    setState(() => _expandidosHistoricoIds.add(id));

    if (!_itensHistoricoDetalhados.containsKey(id) && !item.detalhesCarregados) {
      setState(() => _carregandoDetalhesHistorico.add(id));
      try {
        final s = NotaHistoricoTecnicoService();
        final itemCompleto = await s.carregarDetalhesLazy(item);
        if (mounted) {
          setState(() {
            _itensHistoricoDetalhados[id] = itemCompleto;
            _carregandoDetalhesHistorico.remove(id);
          });
        }
      } catch (_) {
        if (mounted) setState(() => _carregandoDetalhesHistorico.remove(id));
      }
    }
  }

  String? _obterUrlMediaImage(MediaImage? img) {
    if (img == null) return null;
    try {
      return SupabaseMediaRepository().getPublicUrl(img.filePath);
    } catch (_) {
      return null;
    }
  }

  String? _obterUrlHistorico(HistoricoVisualItem? item) {
    if (item == null) return null;
    if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
      return item.imageUrl;
    }
    return _obterUrlMediaImage(item.mediaImage);
  }

  @override
  void didUpdateWidget(covariant NotaWorkspaceContextualEvidencePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeSection != widget.activeSection &&
        _filtro == _FiltroPainelEvidencia.secaoAtual) {
      // Se a seção ativa mudou e estamos no filtro de seção atual,
      // atualizamos a seleção se a evidência atual não pertencer à nova seção
      if (widget.selectedEvidence != null &&
          widget.selectedEvidence!.tipoVinculo != widget.activeSection) {
        final novaEvidenciasSecao = widget.evidencias
            .where((e) => e.tipoVinculo == widget.activeSection)
            .toList();
        if (novaEvidenciasSecao.isNotEmpty) {
          widget.onSelectEvidence(novaEvidenciasSecao.first);
        }
      }
    }
  }

  Future<void> _carregarHistoricoSeNecessario() async {
    if (_historicoResultado != null || _isLoadingHistorico || widget.nota == null) {
      return;
    }

    setState(() => _isLoadingHistorico = true);
    try {
      final s = NotaHistoricoVisualService();
      final res = await s.buscarHistoricoVisual(widget.nota!);
      if (mounted) {
        setState(() {
          _historicoResultado = res;
          _isLoadingHistorico = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingHistorico = false);
    }
  }

  Future<void> _atualizarParaVersaoMaisRecente(NotaSapAnaliseEvidencia ev) async {
    final novaVer = ev.versaoMaisRecenteAnexo;
    if (novaVer == null || ev.anexoId == null || ev.id == null) return;

    try {
      await widget.service.atualizarVersaoVinculada(
        evidenciaId: ev.id!,
        anexoId: ev.anexoId!,
        novaVersao: novaVer,
      );
      widget.onRefreshEvidencias();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vínculo atualizado para a versão mais recente v$novaVer'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar versão: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _desvincularEvidencia(NotaSapAnaliseEvidencia ev) async {
    try {
      await widget.service.desvincularEvidencia(
        notaSapId: widget.notaSapId,
        anexoId: ev.anexoId,
        mediaImageId: ev.mediaImageId,
        tipoFonte: ev.tipoFonte,
        tipoVinculo: ev.tipoVinculo,
      );
      widget.onSelectEvidence(null);
      widget.onRefreshEvidencias();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Evidência desvinculada de ${ev.tipoVinculo.labelCurto}'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao desvincular: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _abrirNotaOrigem(NotaSapAnaliseEvidencia ev) {
    if (widget.onAbrirNotaHistorica == null) return;
    final notaId = ev.anexo?.notaSapId;
    if (notaId == null || notaId.isEmpty) return;

    final notaHistorica = NotaSAP(
      id: notaId,
      nota: ev.numeroNotaHistorica ?? '',
      descricao: 'Nota de Origem do Anexo Histórico',
    );
    widget.onAbrirNotaHistorica!(notaHistorica);
  }

  void _abrirViewerCompleto(NotaSapAnaliseEvidencia ev) {
    if (ev.isFotoAlbum) {
      final img = ev.mediaImage;
      if (img == null) return;
      final url = _obterUrlMediaImage(img) ?? '';
      final dataStr = ev.dataRegistro != null
          ? DateFormat('dd/MM/yyyy').format(ev.dataRegistro!)
          : '';

      showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                color: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      '📷 Álbum de Campo • ${ev.tituloExibicao} $dataStr',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.network(url, fit: BoxFit.contain),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final anx = ev.anexo;
      if (anx == null) return;
      NotaAnexoViewerDialog.abrir(
        context: context,
        anexos: [anx],
        indiceInicial: 0,
        contextoFiltro: 'Evidência - ${ev.tipoVinculo.labelCurto}',
        service: widget.service,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(TFRadius.r12),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Cabeçalho do Painel Contextual
          _buildHeader(colors, typography, spacing),
          Divider(height: 1, color: colors.borderSubtle),

          // 2. Modo Comparação Lado a Lado ou Painel de Inspeção Padrão
          Expanded(
            child: _modoComparacao
                ? _buildModoComparacao(colors, typography, spacing)
                : _buildCorpoPainel(colors, typography, spacing),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(dynamic colors, dynamic typography, dynamic spacing) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.remove_red_eye_outlined, size: 18, color: colors.primary),
              SizedBox(width: spacing.xs),
              Expanded(
                child: Text(
                  'Inspeção Contextual de Evidências',
                  style: typography.sectionTitle.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              if (_modoComparacao)
                TextButton.icon(
                  onPressed: () => setState(() => _modoComparacao = false),
                  icon: const Icon(Icons.close, size: 14),
                  label: const Text('Fechar Comparação', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Seletor de Filtro
          Wrap(
            spacing: 6,
            children: [
              ChoiceChip(
                label: Text('Seção: ${widget.activeSection.labelCurto}'),
                selected: _filtro == _FiltroPainelEvidencia.secaoAtual,
                onSelected: (sel) {
                  if (sel) setState(() => _filtro = _FiltroPainelEvidencia.secaoAtual);
                },
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _filtro == _FiltroPainelEvidencia.secaoAtual
                      ? Colors.white
                      : colors.textPrimary,
                ),
                selectedColor: colors.primary,
              ),
              ChoiceChip(
                label: Text('Todas (${widget.evidencias.length})'),
                selected: _filtro == _FiltroPainelEvidencia.todas,
                onSelected: (sel) {
                  if (sel) setState(() => _filtro = _FiltroPainelEvidencia.todas);
                },
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _filtro == _FiltroPainelEvidencia.todas
                      ? Colors.white
                      : colors.textPrimary,
                ),
                selectedColor: colors.primary,
              ),
              ChoiceChip(
                label: const Text('Histórico Visual'),
                selected: _filtro == _FiltroPainelEvidencia.historicoVisual,
                onSelected: (sel) {
                  if (sel) {
                    setState(() => _filtro = _FiltroPainelEvidencia.historicoVisual);
                    _carregarHistoricoSeNecessario();
                  }
                },
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _filtro == _FiltroPainelEvidencia.historicoVisual
                      ? Colors.white
                      : colors.textPrimary,
                ),
                selectedColor: Colors.blue.shade700,
              ),
              ChoiceChip(
                label: const Text('Notas Anteriores'),
                selected: _filtro == _FiltroPainelEvidencia.notasAnteriores,
                onSelected: (sel) {
                  if (sel) {
                    setState(() => _filtro = _FiltroPainelEvidencia.notasAnteriores);
                    _carregarHistoricoTecnicoSeNecessario();
                  }
                },
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _filtro == _FiltroPainelEvidencia.notasAnteriores
                      ? Colors.white
                      : colors.textPrimary,
                ),
                selectedColor: const Color(0xFF0F766E),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCorpoPainel(dynamic colors, dynamic typography, dynamic spacing) {
    if (_filtro == _FiltroPainelEvidencia.historicoVisual) {
      return _buildListaHistoricoVisualAba(colors, typography, spacing);
    }

    if (_filtro == _FiltroPainelEvidencia.notasAnteriores) {
      return _buildListaNotasAnterioresAba(colors, typography, spacing);
    }

    final ev = widget.selectedEvidence;

    if (ev == null) {
      return _buildEstadoVazioOuListaSecao(colors, typography, spacing);
    }

    // Exibe o preview e metadados detalhados da evidência selecionada
    return SingleChildScrollView(
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner de Identificação
          _buildBannerEvidencia(ev, colors, typography),
          const SizedBox(height: 12),

          // Visualizador Integrado (Preview)
          _buildPreviewArquivo(ev, colors, typography),
          const SizedBox(height: 12),

          // Rastreabilidade de Versões (se for Anexo)
          if (ev.isAnexo) ...[
            _buildBlocoVersao(ev, colors, typography),
            const SizedBox(height: 12),
          ],

          // Observação Analítica
          if (ev.observacao != null && ev.observacao!.trim().isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.surfaceSecondary,
                borderRadius: BorderRadius.circular(TFRadius.r8),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Observação Analítica:',
                    style: typography.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ev.observacao!.trim(),
                    style: typography.bodyMedium.copyWith(
                      color: colors.textPrimary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Barra de Ações Rápidas
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _abrirViewerCompleto(ev),
                  icon: const Icon(Icons.fullscreen, size: 16),
                  label: const Text('Tela Cheia'),
                ),
              ),
              const SizedBox(width: 8),
              if (ev.isAnexoHistorico && widget.onAbrirNotaHistorica != null) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amber.shade900,
                      side: BorderSide(color: Colors.amber.shade700),
                    ),
                    onPressed: () => _abrirNotaOrigem(ev),
                    icon: const Icon(Icons.history, size: 16),
                    label: Text(
                      ev.numeroNotaHistorica != null &&
                              ev.numeroNotaHistorica!.trim().isNotEmpty
                          ? 'Nota ${ev.numeroNotaHistorica!.trim()}'
                          : 'Nota Origem',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (ev.isAnexo && ev.anexo?.tipoArquivo == NotaAnexoTipo.imagem) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      _carregarHistoricoSeNecessario();
                      setState(() {
                        _modoComparacao = true;
                        _fotoHistoricaComparacao = _historicoResultado?.itens.isNotEmpty == true
                            ? _historicoResultado!.itens.first
                            : null;
                      });
                    },
                    icon: const Icon(Icons.compare, size: 16),
                    label: const Text('Comparar'),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (!widget.isReadOnly)
                IconButton(
                  tooltip: 'Desvincular desta seção',
                  icon: const Icon(Icons.link_off, color: Colors.red),
                  onPressed: () => _desvincularEvidencia(ev),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBannerEvidencia(
    NotaSapAnaliseEvidencia ev,
    dynamic colors,
    dynamic typography,
  ) {
    final isAlbum = ev.isFotoAlbum;
    final isHist = ev.isAnexoHistorico;
    final dataStr = ev.dataRegistro != null
        ? DateFormat('dd/MM/yyyy').format(ev.dataRegistro!)
        : 'Data não informada';

    final Color bgColor = isHist
        ? Colors.amber.shade50
        : (isAlbum ? Colors.blue.shade50 : Colors.purple.shade50);
    final Color borderColor = isHist
        ? Colors.amber.shade300
        : (isAlbum ? Colors.blue.shade200 : Colors.purple.shade200);
    final Color tagColor = isHist
        ? Colors.amber.shade900
        : (isAlbum ? Colors.blue.shade900 : Colors.purple.shade900);
    final String tagLabel = isHist
        ? (ev.numeroNotaHistorica != null && ev.numeroNotaHistorica!.trim().isNotEmpty
            ? '🏛️ EVIDÊNCIA HISTÓRICA • NOTA ${ev.numeroNotaHistorica!.trim()}'
            : '🏛️ EVIDÊNCIA HISTÓRICA')
        : (isAlbum ? '📷 HISTÓRICO DE CAMPO' : '📎 ANEXO DA NOTA');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(TFRadius.r8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tagColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      tagLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'Seção: ${ev.tipoVinculo.labelCurto}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                dataStr,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: isAlbum ? Colors.blue.shade900 : Colors.purple.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            ev.tituloExibicao,
            style: typography.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewArquivo(
    NotaSapAnaliseEvidencia ev,
    dynamic colors,
    dynamic typography,
  ) {
    if (ev.isFotoAlbum) {
      final img = ev.mediaImage;
      if (img == null) return const SizedBox.shrink();
      final url = _obterUrlMediaImage(img);
      if (url == null) {
        return Container(
          height: 120,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.surfaceSecondary,
            borderRadius: BorderRadius.circular(TFRadius.r8),
          ),
          child: const Text('Imagem indisponível offline'),
        );
      }

      return Container(
        height: 280,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(TFRadius.r8),
        ),
        clipBehavior: Clip.antiAlias,
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 3.0,
          child: Center(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image, color: Colors.white54, size: 40),
              ),
            ),
          ),
        ),
      );
    } else {
      final anx = ev.anexo;
      if (anx == null) return const SizedBox.shrink();

      if (anx.tipoArquivo == NotaAnexoTipo.imagem) {
        final url = anx.urlAssinada ?? anx.urlPublica;
        if (url == null || url.isEmpty) {
          return Container(
            height: 200,
            color: Colors.grey.shade100,
            child: const Center(child: Text('Pré-visualização indisponível')),
          );
        }
        return Container(
          height: 280,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(TFRadius.r8),
          ),
          clipBehavior: Clip.antiAlias,
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 3.0,
            child: Center(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white54, size: 40),
                ),
              ),
            ),
          ),
        );
      } else {
        // PDF ou Outro Documento
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.surfaceSecondary,
            borderRadius: BorderRadius.circular(TFRadius.r8),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                anx.tipoArquivo == NotaAnexoTipo.pdf
                    ? Icons.picture_as_pdf
                    : Icons.description,
                size: 54,
                color: Colors.red.shade700,
              ),
              const SizedBox(height: 10),
              Text(
                anx.nomeExibicao,
                style: typography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Tamanho: ${anx.tamanhoFormatado}',
                style: typography.caption.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _abrirViewerCompleto(ev),
                icon: const Icon(Icons.visibility, size: 16),
                label: const Text('Abrir Documento'),
              ),
            ],
          ),
        );
      }
    }
  }

  Widget _buildBlocoVersao(
    NotaSapAnaliseEvidencia ev,
    dynamic colors,
    dynamic typography,
  ) {
    final verVinculada = ev.rotuloVersao;
    final hasMaisRecente = ev.hasVersaoMaisRecente;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(TFRadius.r8),
        border: Border.all(
          color: hasMaisRecente ? Colors.amber.shade400 : colors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Versão Vinculada:',
                style: typography.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.teal.shade300, width: 0.8),
                ),
                child: Text(
                  verVinculada,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade900,
                  ),
                ),
              ),
            ],
          ),
          if (hasMaisRecente) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.amber.shade900),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Nova versão disponível: v${ev.versaoMaisRecenteAnexo}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
                if (!widget.isReadOnly)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: const Size(0, 28),
                    ),
                    onPressed: () => _atualizarParaVersaoMaisRecente(ev),
                    child: Text('Usar v${ev.versaoMaisRecenteAnexo}',
                        style: const TextStyle(fontSize: 10.5)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEstadoVazioOuListaSecao(
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    final evidenciasDestaSecao = widget.evidencias
        .where((e) => e.tipoVinculo == widget.activeSection)
        .toList();

    return Padding(
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Evidências de ${widget.activeSection.labelCurto}',
                style: typography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (!widget.isReadOnly)
                TextButton.icon(
                  onPressed: () =>
                      widget.onVincularNovaEvidencia(widget.activeSection),
                  icon: const Icon(Icons.add, size: 15),
                  label: const Text('Vincular', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (evidenciasDestaSecao.isEmpty) ...[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.attachment,
                        size: 40, color: colors.textSecondary.withAlpha(80)),
                    const SizedBox(height: 8),
                    Text(
                      'Nenhuma evidência vinculada a ${widget.activeSection.labelCurto}',
                      style: typography.caption.copyWith(color: colors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    if (!widget.isReadOnly)
                      ElevatedButton.icon(
                        onPressed: () =>
                            widget.onVincularNovaEvidencia(widget.activeSection),
                        icon: const Icon(Icons.add_link, size: 16),
                        label: Text('Vincular à seção ${widget.activeSection.labelCurto}'),
                      ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: ListView.separated(
                itemCount: evidenciasDestaSecao.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, idx) {
                  final ev = evidenciasDestaSecao[idx];
                  return ListTile(
                    tileColor: colors.surfaceSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(TFRadius.r8),
                    ),
                    leading: Icon(
                      ev.isFotoAlbum
                          ? Icons.photo_library
                          : (ev.isAnexoHistorico
                              ? Icons.history_edu
                              : (ev.anexo?.tipoArquivo == NotaAnexoTipo.imagem
                                  ? Icons.image
                                  : Icons.description)),
                      color: ev.isFotoAlbum
                          ? Colors.blue.shade700
                          : (ev.isAnexoHistorico ? Colors.amber.shade800 : colors.primary),
                    ),
                    title: Text(
                      ev.tituloExibicao,
                      style: typography.caption.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      ev.isFotoAlbum
                          ? '📷 Álbum de Campo'
                          : (ev.isAnexoHistorico
                              ? '🏛️ Nota ${ev.numeroNotaHistorica ?? 'Anterior'} • ${ev.rotuloVersao}'
                              : '📎 Anexo • ${ev.rotuloVersao}'),
                      style: const TextStyle(fontSize: 10),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                    onTap: () => widget.onSelectEvidence(ev),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildListaHistoricoVisualAba(
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    if (_isLoadingHistorico) {
      return const Center(child: CircularProgressIndicator());
    }

    final fotos = _historicoResultado?.itens ?? [];

    if (fotos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_library_outlined,
                  size: 40, color: colors.textSecondary.withAlpha(90)),
              const SizedBox(height: 8),
              Text(
                'Nenhuma foto histórica encontrada pelo matching contextual',
                style: typography.caption.copyWith(color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(spacing.md),
      itemCount: fotos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final item = fotos[idx];
        final url = _obterUrlHistorico(item) ?? '';

        return Container(
          decoration: BoxDecoration(
            color: colors.surfaceSecondary,
            borderRadius: BorderRadius.circular(TFRadius.r8),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                ),
              ),
            ),
            title: Text(
              item.title,
              style: typography.caption.copyWith(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${item.nivel.badgeText} • ${item.dataFormatada}',
              style: const TextStyle(fontSize: 10),
            ),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 28),
              ),
              onPressed: () {
                widget.onVincularNovaEvidencia(widget.activeSection);
              },
              child: const Text('Usar', style: TextStyle(fontSize: 10.5)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildListaNotasAnterioresAba(
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    if (_isLoadingHistoricoTecnico) {
      return const Center(child: CircularProgressIndicator());
    }

    final notas = _historicoTecnicoResultado?.todosItensDeduplicados ?? [];

    if (notas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_toggle_off,
                  size: 40, color: colors.textSecondary.withAlpha(90)),
              const SizedBox(height: 8),
              Text(
                'Nenhuma nota anterior encontrada para este ativo',
                style: typography.caption.copyWith(color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(spacing.md),
      itemCount: notas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final item = notas[idx];
        final itemAtual = _itensHistoricoDetalhados[item.notaSap.id] ?? item;
        final isExpandido = _expandidosHistoricoIds.contains(item.notaSap.id);
        final isCarregando = _carregandoDetalhesHistorico.contains(item.notaSap.id);

        return Container(
          decoration: BoxDecoration(
            color: colors.surfaceSecondary,
            borderRadius: BorderRadius.circular(TFRadius.r8),
            border: Border.all(
              color: item.ehMesmoEquipamento ? const Color(0xFF99F6E4) : colors.borderSubtle,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                dense: true,
                title: Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Nota SAP ${item.notaSap.nota}',
                      style: typography.caption.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (item.dataFormatada.isNotEmpty)
                      Text(
                        item.dataFormatada,
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    if (item.notaSap.statusSistema != null &&
                        item.notaSap.statusSistema!.trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: item.estaAberta
                              ? const Color(0xFFFFF7ED)
                              : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: item.estaAberta
                                ? const Color(0xFFFDBA74)
                                : const Color(0xFF86EFAC),
                          ),
                        ),
                        child: Text(
                          'Sis: ${item.notaSap.statusSistema!.trim()}',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: item.estaAberta
                                ? const Color(0xFFC2410C)
                                : const Color(0xFF15803D),
                          ),
                        ),
                      ),
                    if (item.notaSap.statusUsuario != null &&
                        item.notaSap.statusUsuario!.trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: const Color(0xFFDDD6FE)),
                        ),
                        child: Text(
                          'Usu: ${item.notaSap.statusUsuario!.trim()}',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6D28D9),
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.motivosFisicos.isNotEmpty)
                      Text(
                        item.motivosFisicos.first,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    if (item.notaSap.descricao != null)
                      Text(
                        item.notaSap.descricao!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (item.totalAnexos > 0)
                          Text('📎 ${item.totalAnexos} anexos  ', style: const TextStyle(fontSize: 10)),
                        if (item.temAnalise)
                          const Text('📋 Análise  ', style: TextStyle(fontSize: 10)),
                        if (item.totalTasks > 0)
                          Text('⏱ ${item.totalTasks} tasks', style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(isExpandido ? Icons.expand_less : Icons.expand_more, size: 18),
                  onPressed: () => _alternarExpansaoNotaHistorica(item),
                ),
              ),

              if (isExpandido) ...[
                const Divider(height: 1),
                if (isCarregando)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (itemAtual.anexos.isNotEmpty) ...[
                          const Text(
                            'Anexos Históricos (Clique para visualizar):',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 60,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: itemAtual.anexos.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 6),
                              itemBuilder: (context, aIdx) {
                                final anx = itemAtual.anexos[aIdx];
                                return InkWell(
                                  onTap: () {
                                    NotaAnexoViewerDialog.abrir(
                                      context: context,
                                      anexos: itemAtual.anexos,
                                      indiceInicial: aIdx,
                                      contextoFiltro: 'Nota ${item.notaSap.nota}',
                                      service: widget.service,
                                      isHistoricoReadOnly: true,
                                      notaHistoricaNumero: item.notaSap.nota,
                                      notaHistoricaData: item.dataFormatada,
                                    );
                                  },
                                  child: Container(
                                    width: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: colors.borderSubtle),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        anx.tipoArquivo == NotaAnexoTipo.imagem
                                            ? Icons.image
                                            : Icons.description,
                                        size: 24,
                                        color: colors.primary,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            onPressed: () {
                              NotaAnaliseWorkspace.abrir(
                                context,
                                nota: item.notaSap,
                                readOnly: true,
                              );
                            },
                            icon: const Icon(Icons.open_in_new, size: 14),
                            label: const Text('Abrir Nota Completa', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // MODO COMPARAÇÃO LADO A LADO (MVP - FASE 4C)
  // ---------------------------------------------------------------------------
  Widget _buildModoComparacao(
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    final evAtual = widget.selectedEvidence;
    final itemHist = _fotoHistoricaComparacao;

    final urlAtual = evAtual?.anexo?.urlAssinada ??
        evAtual?.anexo?.urlPublica ??
        (evAtual?.mediaImage != null
            ? _obterUrlMediaImage(evAtual!.mediaImage)
            : null);

    final urlHist = itemHist != null
        ? _obterUrlHistorico(itemHist)
        : null;

    final dataAtual = evAtual?.dataRegistro != null
        ? DateFormat('dd/MM/yyyy').format(evAtual!.dataRegistro!)
        : 'Atual';

    final dataHist = itemHist != null ? itemHist.dataFormatada : 'Histórico';

    return Padding(
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(6),
                  color: Colors.green.shade50,
                  child: Text(
                    'ATUAL • $dataAtual',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(6),
                  color: Colors.blue.shade50,
                  child: Text(
                    'HISTÓRICO • $dataHist',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                // Painel Imagem Atual
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(TFRadius.r8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: urlAtual != null
                        ? InteractiveViewer(
                            minScale: 0.8,
                            maxScale: 3.0,
                            child: Center(
                              child: Image.network(urlAtual, fit: BoxFit.contain),
                            ),
                          )
                        : const Center(
                            child: Text('Sem imagem atual',
                                style: TextStyle(color: Colors.white70)),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                // Painel Foto Histórica
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(TFRadius.r8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: urlHist != null
                        ? InteractiveViewer(
                            minScale: 0.8,
                            maxScale: 3.0,
                            child: Center(
                              child: Image.network(urlHist, fit: BoxFit.contain),
                            ),
                          )
                        : const Center(
                            child: Text('Selecione uma foto histórica',
                                style: TextStyle(color: Colors.white70)),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Seletor rápido de qual foto histórica comparar
          if (_historicoResultado?.itens.isNotEmpty == true)
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _historicoResultado!.itens.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final h = _historicoResultado!.itens[i];
                  final isSel = h.id == itemHist?.id;
                  final thumbUrl = _obterUrlHistorico(h) ?? '';

                  return InkWell(
                    onTap: () => setState(() => _fotoHistoricaComparacao = h),
                    child: Container(
                      width: 52,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSel ? Colors.blue.shade700 : Colors.grey.shade300,
                          width: isSel ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Image.network(thumbUrl, fit: BoxFit.cover),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
