import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../design_system/foundations/tf_radius.dart';
import '../../models/nota_sap.dart';
import '../../models/nota_sap_analise.dart';
import '../../services/nota_sap_analise_service.dart';
import 'nota_anexo_annotation_editor.dart';
import 'nota_comparador_visual_dialog.dart';
import 'nota_vincular_evidencia_historica_dialog.dart';

/// Modal / Diálogo de Visualização Técnica em Tela Cheia com Galeria Interativa.
///
/// Preserva o contexto de filtragem da tela chamadora:
/// navega estritamente dentro da coleção visível [anexos], no índice [indiceInicial].
class NotaAnexoViewerDialog extends StatefulWidget {
  final List<NotaSapAnexo> anexos;
  final int indiceInicial;
  final String contextoFiltro;
  final NotaSapAnaliseService service;
  final void Function(NotaSapAnexo anexo, bool relevante)? onRelevanciaAlternada;
  final bool isHistoricoReadOnly;
  final String? notaHistoricaNumero;
  final String? notaHistoricaData;
  final NotaSAP? notaAtual;
  final List<NotaSapAnexo>? anexosAtuais;

  const NotaAnexoViewerDialog({
    super.key,
    required this.anexos,
    required this.indiceInicial,
    this.contextoFiltro = 'Todas as Evidências',
    required this.service,
    this.onRelevanciaAlternada,
    this.isHistoricoReadOnly = false,
    this.notaHistoricaNumero,
    this.notaHistoricaData,
    this.notaAtual,
    this.anexosAtuais,
  });

  /// Método utilitário para abrir o viewer em qualquer tela
  static Future<void> abrir({
    required BuildContext context,
    required List<NotaSapAnexo> anexos,
    required int indiceInicial,
    String contextoFiltro = 'Todas as Evidências',
    required NotaSapAnaliseService service,
    void Function(NotaSapAnexo anexo, bool relevante)? onRelevanciaAlternada,
    bool isHistoricoReadOnly = false,
    String? notaHistoricaNumero,
    String? notaHistoricaData,
    NotaSAP? notaAtual,
    List<NotaSapAnexo>? anexosAtuais,
  }) {
    if (anexos.isEmpty) return Future.value();
    return showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(220),
      builder: (ctx) => NotaAnexoViewerDialog(
        anexos: anexos,
        indiceInicial: indiceInicial,
        contextoFiltro: contextoFiltro,
        service: service,
        onRelevanciaAlternada: onRelevanciaAlternada,
        isHistoricoReadOnly: isHistoricoReadOnly,
        notaHistoricaNumero: notaHistoricaNumero,
        notaHistoricaData: notaHistoricaData,
        notaAtual: notaAtual,
        anexosAtuais: anexosAtuais,
      ),
    );
  }

  @override
  State<NotaAnexoViewerDialog> createState() => _NotaAnexoViewerDialogState();
}

class _NotaAnexoViewerDialogState extends State<NotaAnexoViewerDialog> {
  late int _indiceAtual;
  double _rotacaoGraus = 0.0;
  bool _mostrarDetalhes = true;
  bool _alternandoRelevancia = false;
  final FocusNode _focusNode = FocusNode();
  late PhotoViewController _photoViewController;
  Future<String>? _futureUrlAtual;

  @override
  void initState() {
    super.initState();
    _indiceAtual = widget.indiceInicial.clamp(0, widget.anexos.length - 1);
    _photoViewController = PhotoViewController();
    _carregarUrlAtual();
  }

  void _carregarUrlAtual() {
    _futureUrlAtual = widget.service.obterUrlAssinada(_anexoAtual);
  }

  @override
  void dispose() {
    _photoViewController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  NotaSapAnexo get _anexoAtual => widget.anexos[_indiceAtual];

  void _irParaAnterior() {
    if (_indiceAtual > 0) {
      setState(() {
        _indiceAtual--;
        _rotacaoGraus = 0.0;
        _photoViewController.scale = null;
        _photoViewController.position = Offset.zero;
        _carregarUrlAtual();
      });
    }
  }

  void _irParaProxima() {
    if (_indiceAtual < widget.anexos.length - 1) {
      setState(() {
        _indiceAtual++;
        _rotacaoGraus = 0.0;
        _photoViewController.scale = null;
        _photoViewController.position = Offset.zero;
        _carregarUrlAtual();
      });
    }
  }

  void _rotacionarHorario() {
    setState(() {
      _rotacaoGraus = (_rotacaoGraus + 90.0) % 360.0;
    });
  }

  void _rotacionarAntiHorario() {
    setState(() {
      _rotacaoGraus = (_rotacaoGraus - 90.0) % 360.0;
    });
  }

  void _aplicarZoom(double fator) {
    final current = _photoViewController.scale ?? _photoViewController.value.scale;
    if (current == null) {
      _photoViewController.scale = fator > 1.0 ? 1.25 : 0.8;
      return;
    }
    final next = (current * fator).clamp(0.01, 30.0);
    _photoViewController.scale = next;
  }

  void _zoomIn() => _aplicarZoom(1.25);
  void _zoomOut() => _aplicarZoom(0.8);

  void _resetZoom() {
    _photoViewController.scale = null;
    _photoViewController.position = Offset.zero;
  }

  void _alternarZoomDuploClique() {
    final current = _photoViewController.scale;
    if (current != null) {
      _resetZoom();
    } else {
      final base = _photoViewController.value.scale ?? 1.0;
      _photoViewController.scale = base * 2.5;
    }
  }

  void _tratarPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      if (event.scrollDelta.dy < 0) {
        _aplicarZoom(1.15);
      } else if (event.scrollDelta.dy > 0) {
        _aplicarZoom(0.87);
      }
    }
  }

  Future<void> _alternarRelevancia() async {
    final anexo = _anexoAtual;
    if (anexo.id == null || _alternandoRelevancia) return;

    final novoStatus = !anexo.relevanteAnalise;
    setState(() {
      _alternandoRelevancia = true;
      // Atualiza localmente o item atual na lista recebida
      widget.anexos[_indiceAtual] = anexo.copyWith(relevanteAnalise: novoStatus);
    });

    try {
      await widget.service.alternarRelevanteParaAnalise(
        anexoId: anexo.id!,
        notaSapId: anexo.notaSapId,
        relevante: novoStatus,
      );

      widget.onRelevanciaAlternada?.call(widget.anexos[_indiceAtual], novoStatus);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(novoStatus
                ? '★ Marcado como Evidência Técnica Relevante!'
                : 'Removido dos destaques de evidências.'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Rollback
      if (mounted) {
        setState(() {
          widget.anexos[_indiceAtual] = anexo.copyWith(relevanteAnalise: !novoStatus);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar evidência: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _alternandoRelevancia = false);
      }
    }
  }

  Future<void> _vincularComoEvidenciaHistorica() async {
    final anexo = _anexoAtual;
    if (anexo.id == null || widget.notaAtual == null) return;

    final vinculou = await NotaVincularEvidenciaHistoricaDialog.exibir(
      context: context,
      notaAtual: widget.notaAtual!,
      anexoHistorico: anexo,
      numeroNotaHistorica: widget.notaHistoricaNumero,
      service: widget.service,
    );

    if (vinculou == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🏛️ Anexo da Nota ${widget.notaHistoricaNumero ?? ''} vinculado como evidência técnica formal!',
          ),
          backgroundColor: const Color(0xFF0F766E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _abrirExternamente() async {
    try {
      final url = await widget.service.obterUrlAssinada(_anexoAtual);
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Não foi possível abrir no aplicativo externo');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir link: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _copiarLinkAssinado() async {
    try {
      final url = await widget.service.obterUrlAssinada(_anexoAtual);
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link assinado copiado para a área de transferência!'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao copiar link: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _tratarTeclado(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _irParaAnterior();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _irParaProxima();
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    } else if (event.logicalKey == LogicalKeyboardKey.keyR) {
      _rotacionarHorario();
    } else if (event.logicalKey == LogicalKeyboardKey.keyS && !widget.isHistoricoReadOnly) {
      _alternarRelevancia();
    } else if (event.logicalKey == LogicalKeyboardKey.keyA &&
        !widget.isHistoricoReadOnly &&
        _anexoAtual.tipoArquivo == NotaAnexoTipo.imagem) {
      _abrirEditorAnotacao(_anexoAtual);
    } else if (event.logicalKey == LogicalKeyboardKey.equal ||
        event.logicalKey == LogicalKeyboardKey.add ||
        event.logicalKey == LogicalKeyboardKey.numpadAdd ||
        event.character == '+') {
      _zoomIn();
    } else if (event.logicalKey == LogicalKeyboardKey.minus ||
        event.logicalKey == LogicalKeyboardKey.numpadSubtract ||
        event.character == '-') {
      _zoomOut();
    } else if (event.logicalKey == LogicalKeyboardKey.digit0 ||
        event.logicalKey == LogicalKeyboardKey.numpad0) {
      _resetZoom();
    }
  }

  Future<void> _abrirEditorAnotacao(NotaSapAnexo anexo) async {
    try {
      final url = await widget.service.obterUrlAssinada(anexo);
      if (!mounted) return;

      final salvo = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (ctx) => NotaAnexoAnnotationEditor(
            anexo: anexo,
            imageUrl: url,
            service: widget.service,
          ),
        ),
      );

      if (salvo == true && mounted && anexo.id != null) {
        final ultima = await widget.service.obterUltimaAnotacao(anexo.id!);
        if (ultima != null && mounted) {
          setState(() {
            widget.anexos[_indiceAtual] =
                anexo.copyWith(versaoAnotacao: ultima.versao);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir editor de anotação: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final anexo = _anexoAtual;
    final total = widget.anexos.length;
    final ehPrimeiro = _indiceAtual == 0;
    final ehUltimo = _indiceAtual == total - 1;
    final ehImagem = anexo.tipoArquivo == NotaAnexoTipo.imagem;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _tratarTeclado,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // Fundo escuro interativo
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() => _mostrarDetalhes = !_mostrarDetalhes);
                },
                child: Container(color: Colors.black.withAlpha(240)),
              ),
            ),

            // Conteúdo Central: Imagem ampliada ou Viewer Técnico de Mídia
            Positioned.fill(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 64),
                  child: ehImagem
                      ? _buildImageViewer(anexo)
                      : _buildMediaTechnicalViewer(anexo),
                ),
              ),
            ),

            // Barra Superior de Controle (Header Discreto)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(anexo, total),
            ),

            // Botão Navegação Anterior (Esquerda)
            if (total > 1)
              Positioned(
                left: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: ehPrimeiro ? Colors.black26 : Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 22),
                      color: ehPrimeiro ? Colors.white30 : Colors.white,
                      tooltip: ehPrimeiro ? 'Primeira evidência' : 'Anterior (←)',
                      onPressed: ehPrimeiro ? null : _irParaAnterior,
                    ),
                  ),
                ),
              ),

            // Botão Navegação Próxima (Direita)
            if (total > 1)
              Positioned(
                right: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: ehUltimo ? Colors.black26 : Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 22),
                      color: ehUltimo ? Colors.white30 : Colors.white,
                      tooltip: ehUltimo ? 'Última evidência' : 'Próxima (→)',
                      onPressed: ehUltimo ? null : _irParaProxima,
                    ),
                  ),
                ),
              ),

            // Barra Inferior de Metadados / Legenda Técnica
            if (_mostrarDetalhes)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomDetails(anexo),
              ),

            // Barra Flutuante de Controles de Zoom (somente para imagens)
            if (ehImagem)
              Positioned(
                right: 18,
                bottom: _mostrarDetalhes ? 140 : 24,
                child: _buildFloatingZoomControls(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingZoomControls() {
    return StreamBuilder<PhotoViewControllerValue>(
      stream: _photoViewController.outputStateStream,
      builder: (context, snapshot) {
        final escala = snapshot.data?.scale ?? _photoViewController.scale;
        final base = _photoViewController.value.scale;
        final pct = (escala != null && base != null && base > 0)
            ? ((escala / base) * 100).round()
            : 100;

        return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(200),
        borderRadius: BorderRadius.circular(TFRadius.rFull),
        border: Border.all(color: Colors.white24, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 18, color: Colors.white),
            tooltip: 'Afastar Zoom (-)',
            splashRadius: 18,
            visualDensity: VisualDensity.compact,
            onPressed: _zoomOut,
          ),
          InkWell(
            onTap: _resetZoom,
            borderRadius: BorderRadius.circular(TFRadius.r12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                '$pct%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18, color: Colors.white),
            tooltip: 'Aproximar Zoom (+)',
            splashRadius: 18,
            visualDensity: VisualDensity.compact,
            onPressed: _zoomIn,
          ),
          Container(
            width: 1,
            height: 18,
            color: Colors.white24,
            margin: const EdgeInsets.symmetric(horizontal: 2),
          ),
          IconButton(
            icon: const Icon(Icons.fit_screen_outlined, size: 18, color: Colors.white),
            tooltip: 'Ajustar à Tela (0)',
            splashRadius: 18,
            visualDensity: VisualDensity.compact,
            onPressed: _resetZoom,
          ),
        ],
      ),
    );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // BARRA SUPERIOR
  // ---------------------------------------------------------------------------
  Widget _buildTopBar(NotaSapAnexo anexo, int total) {
    final ehEvidencia = anexo.relevanteAnalise;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withAlpha(200),
            Colors.black.withAlpha(0),
          ],
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Contador de Contexto + Filtro
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_indiceAtual + 1} de $total',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.0,
                    ),
                  ),
                  if (widget.contextoFiltro.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(width: 1, height: 12, color: Colors.white38),
                    const SizedBox(width: 6),
                    Text(
                      widget.contextoFiltro,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11.0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Nome do arquivo
            Expanded(
              child: Text(
                anexo.nomeExibicao,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Banner de Origem Histórica (quando em modo consulta)
            if (widget.isHistoricoReadOnly) ...[
              Container(
                constraints: const BoxConstraints(maxWidth: 380),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withAlpha(200),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amberAccent.shade400),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.history, size: 14, color: Colors.amberAccent),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'NOTA HISTÓRICA SAP ${widget.notaHistoricaNumero ?? ""} • ${widget.notaHistoricaData ?? ""} • MODO DE CONSULTA',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.0,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],

            // Botão Comparar com Atual (somente histórico e se for imagem) - Requisito 6.B
            if (widget.isHistoricoReadOnly &&
                anexo.tipoArquivo == NotaAnexoTipo.imagem &&
                widget.notaAtual != null) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.compare_arrows, size: 16),
                label: const Text(
                  'Comparar com Atual',
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  NotaComparadorVisualDialog.abrirComNotaHistorica(
                    context: context,
                    notaAtual: widget.notaAtual!,
                    anexosAtuais: widget.anexosAtuais ?? [],
                    notaHistorica: NotaSAP(
                      id: widget.notaHistoricaNumero ?? '',
                      nota: widget.notaHistoricaNumero ?? '',
                    ),
                    anexosHistoricos: widget.anexos,
                    indiceHistoricoInicial: _indiceAtual,
                    service: widget.service,
                  );
                },
              ),
              const SizedBox(width: 8),
            ],

            // Botão Marcar Relevante (★) - para nota atual
            if (!widget.isHistoricoReadOnly) ...[
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: ehEvidencia ? Colors.amber.shade400 : Colors.white70,
                  backgroundColor: ehEvidencia ? Colors.amber.withAlpha(40) : Colors.white.withAlpha(20),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: ehEvidencia ? Colors.amber.shade400 : Colors.white24,
                    ),
                  ),
                ),
                icon: Icon(
                  ehEvidencia ? Icons.star : Icons.star_border,
                  color: ehEvidencia ? Colors.amber.shade400 : Colors.white70,
                  size: 18,
                ),
                label: Text(
                  ehEvidencia ? 'Relevante' : 'Marcar relevante',
                  style: TextStyle(
                    color: ehEvidencia ? Colors.amber.shade300 : Colors.white70,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: _alternarRelevancia,
              ),
            ] else if (widget.notaAtual != null) ...[
              // Ação explícita para anexo histórico: Usar como Evidência Formal
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.bookmark_add, size: 16),
                label: const Text(
                  'Usar como Evidência',
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _vincularComoEvidenciaHistorica,
              ),
              const SizedBox(width: 8),
            ],

            // Rotação Horária (somente se imagem)
            if (anexo.tipoArquivo == NotaAnexoTipo.imagem) ...[
              const SizedBox(width: 8),
              if (!widget.isHistoricoReadOnly)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: anexo.possuiAnotacao
                        ? Colors.teal.shade700
                        : Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: Text(
                    anexo.possuiAnotacao
                        ? 'Anotado (v${anexo.versaoAnotacao})'
                        : 'Anotar',
                    style: const TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () => _abrirEditorAnotacao(anexo),
                )
              else if (anexo.possuiAnotacao)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade800,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_note, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'Anotado (v${anexo.versaoAnotacao})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.zoom_out, color: Colors.white70, size: 20),
                tooltip: 'Afastar Zoom (-)',
                onPressed: _zoomOut,
              ),
              IconButton(
                icon: const Icon(Icons.zoom_in, color: Colors.white70, size: 20),
                tooltip: 'Aproximar Zoom (+)',
                onPressed: _zoomIn,
              ),
              IconButton(
                icon: const Icon(Icons.fit_screen_outlined, color: Colors.white70, size: 20),
                tooltip: 'Redefinir Zoom (0)',
                onPressed: _resetZoom,
              ),
              IconButton(
                icon: const Icon(Icons.rotate_90_degrees_ccw_outlined, color: Colors.white70, size: 20),
                tooltip: 'Girar anti-horário (-90°)',
                onPressed: _rotacionarAntiHorario,
              ),
              IconButton(
                icon: const Icon(Icons.rotate_90_degrees_cw_outlined, color: Colors.white70, size: 20),
                tooltip: 'Girar 90° horário (Pressione R)',
                onPressed: _rotacionarHorario,
              ),
              if (_rotacaoGraus != 0.0)
                IconButton(
                  icon: const Icon(Icons.restore, color: Colors.amberAccent, size: 20),
                  tooltip: 'Restaurar orientação original',
                  onPressed: () => setState(() => _rotacaoGraus = 0.0),
                ),
            ],

            // Copiar Link
            IconButton(
              icon: const Icon(Icons.link, color: Colors.white70, size: 20),
              tooltip: 'Copiar link assinado temporário',
              onPressed: _copiarLinkAssinado,
            ),

            // Abrir Externamente
            IconButton(
              icon: const Icon(Icons.open_in_new, color: Colors.white70, size: 20),
              tooltip: 'Abrir no navegador ou aplicativo padrão',
              onPressed: _abrirExternamente,
            ),

            // Fechar (X)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 22),
              tooltip: 'Fechar (Esc)',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // VIEWER DE IMAGEM COM PHOTOVIEW
  // ---------------------------------------------------------------------------
  Widget _buildImageViewer(NotaSapAnexo anexo) {
    return FutureBuilder<String>(
      future: _futureUrlAtual,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Carregando evidência técnica segura...',
                  style: TextStyle(color: Colors.white70, fontSize: 13.0),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade400),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  const Text(
                    'Não foi possível carregar esta evidência.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error ?? "Erro ao recuperar Signed URL"}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12.0),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Tentar Novamente'),
                    onPressed: () => setState(() {}),
                  ),
                ],
              ),
            ),
          );
        }

        final imageUrl = snapshot.data!;

        Widget photoWidget = Listener(
          onPointerSignal: _tratarPointerSignal,
          child: GestureDetector(
            onDoubleTap: _alternarZoomDuploClique,
            child: PhotoView(
              controller: _photoViewController,
              imageProvider: NetworkImage(imageUrl),
              backgroundDecoration: const BoxDecoration(color: Colors.transparent),
              minScale: PhotoViewComputedScale.contained * 0.8,
              maxScale: PhotoViewComputedScale.covered * 5.0,
              loadingBuilder: (context, event) {
                return Center(
                  child: CircularProgressIndicator(
                    value: event == null || event.expectedTotalBytes == null
                        ? null
                        : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
                    color: Colors.white,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image_outlined, size: 48, color: Colors.white60),
                      SizedBox(height: 8),
                      Text(
                        'Falha ao renderizar a imagem',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );

        if (_rotacaoGraus != 0.0) {
          final turns = (_rotacaoGraus / 90.0).round() % 4;
          photoWidget = RotatedBox(
            quarterTurns: turns,
            child: photoWidget,
          );
        }

        return photoWidget;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // VIEWER TÉCNICO DE MÍDIAS NÃO-IMAGEM (PDF, VÍDEO, DOCUMENTO, ÁUDIO)
  // ---------------------------------------------------------------------------
  Widget _buildMediaTechnicalViewer(NotaSapAnexo anexo) {
    IconData iconePrincipal;
    Color corIcone;
    String tipoLabel;
    String instrucaoAbertura;

    switch (anexo.tipoArquivo) {
      case NotaAnexoTipo.pdf:
        iconePrincipal = Icons.picture_as_pdf;
        corIcone = Colors.red.shade400;
        tipoLabel = 'Documento PDF / Laudo Técnico';
        instrucaoAbertura = 'Visualizar PDF';
        break;
      case NotaAnexoTipo.video:
        iconePrincipal = Icons.video_library_outlined;
        corIcone = Colors.purple.shade400;
        tipoLabel = 'Registro em Vídeo de Campo';
        instrucaoAbertura = 'Visualizar Vídeo';
        break;
      case NotaAnexoTipo.documento:
        iconePrincipal = Icons.description_outlined;
        corIcone = Colors.indigo.shade300;
        tipoLabel = 'Documento de Texto / Word';
        instrucaoAbertura = 'Abrir Documento';
        break;
      case NotaAnexoTipo.planilha:
        iconePrincipal = Icons.table_chart_outlined;
        corIcone = Colors.green.shade400;
        tipoLabel = 'Planilha de Dados / Medições';
        instrucaoAbertura = 'Abrir Planilha';
        break;
      case NotaAnexoTipo.audio:
        iconePrincipal = Icons.audio_file_outlined;
        corIcone = Colors.orange.shade400;
        tipoLabel = 'Áudio / Relato Gravado';
        instrucaoAbertura = 'Ouvir Áudio';
        break;
      default:
        iconePrincipal = Icons.insert_drive_file_outlined;
        corIcone = Colors.blueGrey.shade400;
        tipoLabel = 'Arquivo Técnico Anexo';
        instrucaoAbertura = 'Abrir Arquivo';
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(140),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: corIcone.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(iconePrincipal, size: 56, color: corIcone),
          ),
          const SizedBox(height: 16),
          Text(
            tipoLabel,
            style: TextStyle(
              color: corIcone,
              fontWeight: FontWeight.bold,
              fontSize: 14.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            anexo.nomeExibicao,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16.0,
            ),
            textAlign: TextAlign.center,
          ),
          if (anexo.legenda != null && anexo.legenda!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              anexo.legenda!,
              style: const TextStyle(
                color: Colors.white70,
                fontStyle: FontStyle.italic,
                fontSize: 13.0,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoItem('Tamanho', anexo.tamanhoFormatado),
                _buildInfoItem('Origem', anexo.origem),
                _buildInfoItem('Extensão', (anexo.extensao ?? '').toUpperCase()),
              ],
            ),
          ),
          if (anexo.tipoArquivo == NotaAnexoTipo.video) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.purple.withAlpha(40),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.purple.shade400.withAlpha(80)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.purpleAccent),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Autoplay desativado por política corporativa de dados.',
                      style: TextStyle(color: Colors.white70, fontSize: 11.0),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(instrucaoAbertura),
                onPressed: _abrirExternamente,
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white30),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copiar Link'),
                onPressed: _copiarLinkAssinado,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String valor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(color: Colors.white38, fontSize: 10.0, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: const TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BARRA INFERIOR DE DETALHES TÉCNICOS
  // ---------------------------------------------------------------------------
  Widget _buildBottomDetails(NotaSapAnexo anexo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withAlpha(220),
            Colors.black.withAlpha(0),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Legenda em Destaque
            if (anexo.legenda != null && anexo.legenda!.trim().isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(160),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  anexo.legenda!.trim(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            // Linha com Metadados Detalhados
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (anexo.sapDocumentId != null)
                  _buildTagMetadado(Icons.tag, 'SAP DOC: ${anexo.sapDocumentId!}'),
                if (anexo.sha256 != null)
                  _buildTagMetadado(Icons.fingerprint, 'SHA: ${anexo.sha256!.substring(0, 8)}...'),
                _buildTagMetadado(Icons.storage, anexo.tamanhoFormatado),
                _buildTagMetadado(Icons.cloud_done_outlined, 'Origem: ${anexo.origem}'),
                if (anexo.relevanteAnalise)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade900.withAlpha(180),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.amber.shade400),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, size: 12, color: Colors.amberAccent),
                        SizedBox(width: 4),
                        Text(
                          'EVIDÊNCIA TÉCNICA CRÍTICA',
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 10.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagMetadado(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white60),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: Colors.white70, fontSize: 11.0),
        ),
      ],
    );
  }
}
