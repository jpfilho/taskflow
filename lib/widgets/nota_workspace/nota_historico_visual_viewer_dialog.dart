import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../design_system/foundations/tf_radius.dart';
import '../../models/nota_sap.dart';
import '../../models/nota_sap_analise.dart';
import '../../models/nota_historico_visual.dart';
import '../../models/nota_sap_analise_evidencia.dart';
import '../../services/nota_sap_analise_service.dart';
import 'nota_comparador_visual_dialog.dart';

/// Modal / Diálogo de Visualização em Tela Cheia para o Histórico Visual do Local (Álbuns de Campo).
///
/// Oferece a mesma experiência interativa do visualizador de anexos da nota:
/// - Navegação lateral entre fotografias (< e >, teclado ← e →, swipe e carrossel de miniaturas inferior);
/// - Zoom suave de alta resolução e pan via PhotoView com suporte à rodinha do mouse e atalhos;
/// - Rotação da imagem em 90° e restauração de orientação;
/// - Botão direto de vinculação à Análise Técnica ("Usar na Análise Técnica");
/// - Badges técnicos por nível de correspondência (Equipamento, Sala, Mesmo Local).
class NotaHistoricoVisualViewerDialog extends StatefulWidget {
  final List<HistoricoVisualItem> itens;
  final int indiceInicial;
  final Map<String, List<NotaTipoVinculoEvidencia>> secoesVinculadasPorFoto;
  final Future<void> Function(HistoricoVisualItem item)? onVincularFoto;
  final NotaSAP? notaAtual;
  final List<NotaSapAnexo>? anexosAtuais;
  final NotaSapAnaliseService? analiseService;

  const NotaHistoricoVisualViewerDialog({
    super.key,
    required this.itens,
    required this.indiceInicial,
    this.secoesVinculadasPorFoto = const {},
    this.onVincularFoto,
    this.notaAtual,
    this.anexosAtuais,
    this.analiseService,
  });

  /// Abre o visualizador técnico em qualquer tela
  static Future<void> abrir({
    required BuildContext context,
    required List<HistoricoVisualItem> itens,
    required int indiceInicial,
    Map<String, List<NotaTipoVinculoEvidencia>> secoesVinculadasPorFoto = const {},
    Future<void> Function(HistoricoVisualItem item)? onVincularFoto,
    NotaSAP? notaAtual,
    List<NotaSapAnexo>? anexosAtuais,
    NotaSapAnaliseService? analiseService,
  }) {
    if (itens.isEmpty) return Future.value();
    return showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(220),
      builder: (ctx) => NotaHistoricoVisualViewerDialog(
        itens: itens,
        indiceInicial: indiceInicial,
        secoesVinculadasPorFoto: secoesVinculadasPorFoto,
        onVincularFoto: onVincularFoto,
        notaAtual: notaAtual,
        anexosAtuais: anexosAtuais,
        analiseService: analiseService,
      ),
    );
  }

  @override
  State<NotaHistoricoVisualViewerDialog> createState() =>
      _NotaHistoricoVisualViewerDialogState();
}

class _NotaHistoricoVisualViewerDialogState
    extends State<NotaHistoricoVisualViewerDialog> {
  late int _indiceAtual;
  double _rotacaoGraus = 0.0;
  bool _mostrarDetalhes = true;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _miniaturasScrollController = ScrollController();
  late PhotoViewController _photoViewController;

  @override
  void initState() {
    super.initState();
    _indiceAtual = widget.indiceInicial.clamp(0, widget.itens.length - 1);
    _photoViewController = PhotoViewController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollParaMiniaturaAtual());
  }

  @override
  void dispose() {
    _photoViewController.dispose();
    _focusNode.dispose();
    _miniaturasScrollController.dispose();
    super.dispose();
  }

  HistoricoVisualItem get _itemAtual => widget.itens[_indiceAtual];

  void _scrollParaMiniaturaAtual() {
    if (!_miniaturasScrollController.hasClients) return;
    const itemWidth = 64.0;
    final targetOffset = (_indiceAtual * itemWidth) - 100.0;
    _miniaturasScrollController.animateTo(
      targetOffset.clamp(0.0, _miniaturasScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _irParaAnterior() {
    if (_indiceAtual > 0) {
      setState(() {
        _indiceAtual--;
        _rotacaoGraus = 0.0;
        _photoViewController.scale = null;
        _photoViewController.position = Offset.zero;
      });
      _scrollParaMiniaturaAtual();
    }
  }

  void _irParaProxima() {
    if (_indiceAtual < widget.itens.length - 1) {
      setState(() {
        _indiceAtual++;
        _rotacaoGraus = 0.0;
        _photoViewController.scale = null;
        _photoViewController.position = Offset.zero;
      });
      _scrollParaMiniaturaAtual();
    }
  }

  void _rotacionarHorario() {
    setState(() {
      _rotacaoGraus = (_rotacaoGraus + 90.0) % 360.0;
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

  Future<void> _abrirExternamente() async {
    final url = _itemAtual.imageUrl;
    if (url == null || url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir link: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _copiarLink() async {
    final url = _itemAtual.imageUrl;
    if (url == null || url.isEmpty) return;
    try {
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link da fotografia copiado para a área de transferência!'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao copiar link: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _itemAtual;
    final total = widget.itens.length;
    final ehPrimeiro = _indiceAtual == 0;
    final ehUltimo = _indiceAtual == total - 1;

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

            // Imagem Central com Zoom e Rotação
            Positioned.fill(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 56,
                    right: 56,
                    top: 64,
                    bottom: total > 1 ? 120 : 64,
                  ),
                  child: _buildImageViewer(item),
                ),
              ),
            ),

            // Barra Superior de Controle
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(item, total),
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
                      tooltip: ehPrimeiro ? 'Primeira foto' : 'Anterior (←)',
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
                      tooltip: ehUltimo ? 'Última foto' : 'Próxima (→)',
                      onPressed: ehUltimo ? null : _irParaProxima,
                    ),
                  ),
                ),
              ),

            // Barra Inferior de Informações e Carrossel de Miniaturas
            if (_mostrarDetalhes)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomBar(item, total),
              ),

            // Barra Flutuante de Controles de Zoom
            Positioned(
              right: 18,
              bottom: _mostrarDetalhes ? (total > 1 ? 140 : 80) : 24,
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

  Widget _buildImageViewer(HistoricoVisualItem item) {
    if (item.imageUrl == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported, size: 64, color: Colors.white38),
            SizedBox(height: 12),
            Text(
              'Fotografia sem arquivo disponível.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    final turns = (_rotacaoGraus / 90.0).round() % 4;

    return Listener(
      onPointerSignal: _tratarPointerSignal,
      child: GestureDetector(
        onDoubleTap: _alternarZoomDuploClique,
        child: RotatedBox(
          quarterTurns: turns,
          child: PhotoView(
            controller: _photoViewController,
            imageProvider: NetworkImage(item.imageUrl!),
            backgroundDecoration: const BoxDecoration(color: Colors.transparent),
            minScale: PhotoViewComputedScale.contained * 0.8,
            maxScale: PhotoViewComputedScale.covered * 5.0,
        loadingBuilder: (context, event) {
          return Center(
            child: CircularProgressIndicator(
              value: event == null || event.expectedTotalBytes == null
                  ? null
                  : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
              color: Colors.white70,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined, size: 56, color: Colors.white60),
                SizedBox(height: 10),
                Text(
                  'Falha ao carregar imagem histórica',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          );
        },
      ),
    ),
  ),
);
  }

  Widget _buildTopBarIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color? color,
    double size = 18.0,
  }) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: const EdgeInsets.all(6),
      icon: Icon(icon, color: color ?? Colors.white70, size: size),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }

  Widget _buildTopBar(HistoricoVisualItem item, int total) {
    final secoesVinculadas = widget.secoesVinculadasPorFoto[item.mediaImage.id] ?? [];
    final estaVinculada = secoesVinculadas.isNotEmpty;

    return AnimatedOpacity(
      opacity: _mostrarDetalhes ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withAlpha(220),
              Colors.black.withAlpha(0),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 800;
              final isUltraCompact = constraints.maxWidth < 560;

              return Row(
                children: [
                  // Badge de Nível
                  if (!isUltraCompact) ...[
                    _buildBadgeNivel(item.nivel),
                    const SizedBox(width: 8),
                  ],

                  // Título e Data
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          isCompact
                              ? '${item.dataFormatada} • ${item.motivoCorrespondencia}'
                              : '${item.dataFormatada} (${item.idadeFormatada}) • ${item.motivoCorrespondencia}',
                          style: const TextStyle(color: Colors.white70, fontSize: 11.0),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Contador X / N
                  if (total > 1) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(TFRadius.r12),
                      ),
                      child: Text(
                        '${_indiceAtual + 1} de $total',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],

                  // Botão Usar na Análise Técnica
                  if (widget.onVincularFoto != null) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: estaVinculada ? Colors.purple.shade700 : Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(TFRadius.r8),
                        ),
                      ),
                      icon: Icon(
                        estaVinculada ? Icons.check_circle_outline : Icons.add_link_rounded,
                        size: 15,
                      ),
                      label: Text(
                        isCompact
                            ? (estaVinculada ? 'Vinculada' : 'Vincular')
                            : (estaVinculada ? 'Na Análise (${secoesVinculadas.length})' : 'Usar na Análise'),
                        style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        widget.onVincularFoto!(item);
                      },
                    ),
                    const SizedBox(width: 4),
                  ],

                  // Botão Comparar com Atual (Álbum de Campo) - Requisito 6.C
                  if (widget.notaAtual != null) ...[
                    if (isCompact)
                      _buildTopBarIconButton(
                        icon: Icons.compare_arrows,
                        color: const Color(0xFF2DD4BF),
                        tooltip: 'Comparar com Atual',
                        onPressed: () {
                          NotaComparadorVisualDialog.abrirComAlbum(
                            context: context,
                            notaAtual: widget.notaAtual!,
                            anexosAtuais: widget.anexosAtuais ?? [],
                            itensAlbum: widget.itens,
                            indiceAlbumInicial: _indiceAtual,
                            service: widget.analiseService ?? NotaSapAnaliseService(),
                          );
                        },
                      )
                    else
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(TFRadius.r8),
                          ),
                        ),
                        icon: const Icon(Icons.compare_arrows, size: 15),
                        label: const Text(
                          'Comparar com Atual',
                          style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          NotaComparadorVisualDialog.abrirComAlbum(
                            context: context,
                            notaAtual: widget.notaAtual!,
                            anexosAtuais: widget.anexosAtuais ?? [],
                            itensAlbum: widget.itens,
                            indiceAlbumInicial: _indiceAtual,
                            service: widget.analiseService ?? NotaSapAnaliseService(),
                          );
                        },
                      ),
                    const SizedBox(width: 4),
                  ],

                  // Controles de Zoom (apenas em telas não compactas; em compactas usa a barra flutuante)
                  if (!isCompact) ...[
                    _buildTopBarIconButton(
                      icon: Icons.zoom_out,
                      tooltip: 'Afastar Zoom (-)',
                      onPressed: _zoomOut,
                    ),
                    _buildTopBarIconButton(
                      icon: Icons.zoom_in,
                      tooltip: 'Aproximar Zoom (+)',
                      onPressed: _zoomIn,
                    ),
                    _buildTopBarIconButton(
                      icon: Icons.fit_screen_outlined,
                      tooltip: 'Redefinir Zoom (0)',
                      onPressed: _resetZoom,
                    ),
                  ],

                  // Botão Girar Imagem
                  _buildTopBarIconButton(
                    icon: Icons.rotate_90_degrees_cw_outlined,
                    tooltip: 'Girar 90° horário (R)',
                    onPressed: _rotacionarHorario,
                  ),

                  if (_rotacaoGraus != 0.0)
                    _buildTopBarIconButton(
                      icon: Icons.restore,
                      color: Colors.amberAccent,
                      tooltip: 'Restaurar orientação original',
                      onPressed: () => setState(() => _rotacaoGraus = 0.0),
                    ),

                  // Copiar link
                  _buildTopBarIconButton(
                    icon: Icons.link,
                    tooltip: 'Copiar link da fotografia',
                    onPressed: _copiarLink,
                  ),

                  // Abrir Externamente
                  _buildTopBarIconButton(
                    icon: Icons.open_in_new,
                    tooltip: 'Abrir no navegador',
                    onPressed: _abrirExternamente,
                  ),

                  // Fechar (X)
                  _buildTopBarIconButton(
                    icon: Icons.close,
                    color: Colors.white,
                    size: 20,
                    tooltip: 'Fechar (Esc)',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(HistoricoVisualItem item, int total) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withAlpha(240),
            Colors.black.withAlpha(0),
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Informações de Local e Ativo
            Row(
              children: [
                const Icon(Icons.place_outlined, color: Colors.white70, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${item.localNome ?? "Ativo Técnico"}${item.sala != null ? " • Sala: ${item.sala}" : ""}${item.equipamento != null ? " • Eq: ${item.equipamento}" : ""}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            if (total > 1) ...[
              const SizedBox(height: 10),
              // Carrossel de Miniaturas com Navegação Direta
              SizedBox(
                height: 54,
                child: ListView.separated(
                  controller: _miniaturasScrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: total,
                  separatorBuilder: (ctx, i) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final foto = widget.itens[i];
                    final ehAtual = i == _indiceAtual;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _indiceAtual = i;
                          _rotacaoGraus = 0.0;
                        });
                        _scrollParaMiniaturaAtual();
                      },
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(TFRadius.r8),
                          border: Border.all(
                            color: ehAtual ? Colors.blueAccent : Colors.white24,
                            width: ehAtual ? 2.5 : 1.0,
                          ),
                          boxShadow: ehAtual
                              ? [
                                  BoxShadow(
                                    color: Colors.blueAccent.withAlpha(120),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(TFRadius.r8 - 2),
                          child: foto.imageUrl != null
                              ? Image.network(
                                  foto.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.broken_image, size: 16, color: Colors.white38),
                                  ),
                                )
                              : const Center(
                                  child: Icon(Icons.image, size: 16, color: Colors.white38),
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeNivel(HistoricoVisualNivel nivel) {
    Color bg;
    Color fg;
    IconData icon;

    switch (nivel) {
      case HistoricoVisualNivel.equipamento:
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        icon = Icons.precision_manufacturing_rounded;
        break;
      case HistoricoVisualNivel.sala:
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1565C0);
        icon = Icons.apartment_rounded;
        break;
      case HistoricoVisualNivel.local:
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        icon = Icons.location_on_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(TFRadius.r8),
        border: Border.all(color: fg.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            nivel.badgeText,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
