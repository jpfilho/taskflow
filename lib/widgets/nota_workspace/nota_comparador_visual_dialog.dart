import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import '../../design_system/foundations/tf_radius.dart';
import '../../models/nota_sap.dart';
import '../../models/nota_sap_analise.dart';
import '../../models/nota_historico_visual.dart';
import '../../services/nota_sap_analise_service.dart';
import 'nota_vincular_evidencia_historica_dialog.dart';

/// Origem do item histórico para o comparador visual dedicado.
enum OrigemComparadorHistorico {
  notaAnterior,
  albumCampo,
}

/// Identificador de qual lado do comparador está em foco / ativo.
enum LadoComparadorAtivo {
  atual,
  historico,
}

/// Diálogo dedicado para Comparação Visual Lado a Lado (Atual × Histórico).
///
/// Características principais:
/// - Modo estritamente Read-Only (sem criação de vínculo formal, sem anotação, sem save);
/// - Zero alteração no banco de dados e zero cópia de arquivos de storage;
/// - Zoom e Pan 100% independentes por padrão via PhotoView;
/// - Rotação volátil independente em cada lado (0°, 90°, 180°, 270°);
/// - Resolução assíncrona desacoplada de Signed URLs com retry individual;
/// - Layout responsivo: split horizontal (50%/50%) em Desktop (>= 900px) e
///   modo com alternância prioritária e miniatura de contexto em Mobile (< 900px);
/// - Identificação textual e icônica permanente de ATUAL e HISTÓRICO;
/// - Cálculo em memória de diferença temporal entre as duas datas.
class NotaComparadorVisualDialog extends StatefulWidget {
  final NotaSAP notaAtual;
  final List<NotaSapAnexo> anexosAtuais;
  final NotaSapAnexo anexoAtualInicial;

  final OrigemComparadorHistorico origemHistorica;

  // Fonte A: Nota Anterior
  final NotaSAP? notaHistorica;
  final List<NotaSapAnexo>? anexosHistoricos;
  final int indiceHistoricoInicial;

  // Fonte B: Álbum de Campo
  final List<HistoricoVisualItem>? itensAlbum;
  final int indiceAlbumInicial;

  final NotaSapAnaliseService service;

  const NotaComparadorVisualDialog({
    super.key,
    required this.notaAtual,
    required this.anexosAtuais,
    required this.anexoAtualInicial,
    required this.origemHistorica,
    this.notaHistorica,
    this.anexosHistoricos,
    this.indiceHistoricoInicial = 0,
    this.itensAlbum,
    this.indiceAlbumInicial = 0,
    required this.service,
  });

  /// Método estático para iniciar o fluxo de comparação a partir de uma Nota Histórica
  static Future<void> abrirComNotaHistorica({
    required BuildContext context,
    required NotaSAP notaAtual,
    required List<NotaSapAnexo> anexosAtuais,
    required NotaSAP notaHistorica,
    required List<NotaSapAnexo> anexosHistoricos,
    int indiceHistoricoInicial = 0,
    required NotaSapAnaliseService service,
  }) async {
    final imagensAtuais = anexosAtuais
        .where((a) => a.tipoArquivo == NotaAnexoTipo.imagem)
        .toList();

    // Requisito 7: Se 0 imagens atuais, emite aviso claro e não abre
    if (imagensAtuais.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A Nota atual não possui imagens disponíveis para comparação.',
          ),
          backgroundColor: Colors.amber,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final imagensHistoricas = anexosHistoricos
        .where((a) => a.tipoArquivo == NotaAnexoTipo.imagem)
        .toList();

    if (imagensHistoricas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A Nota histórica não possui imagens para comparação visual.',
          ),
          backgroundColor: Colors.amber,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Requisito 8: Se 1 imagem atual, seleciona automaticamente
    if (imagensAtuais.length == 1) {
      return _exibirDialogo(
        context: context,
        notaAtual: notaAtual,
        anexosAtuais: imagensAtuais,
        anexoAtualInicial: imagensAtuais.first,
        origemHistorica: OrigemComparadorHistorico.notaAnterior,
        notaHistorica: notaHistorica,
        anexosHistoricos: imagensHistoricas,
        indiceHistoricoInicial: indiceHistoricoInicial.clamp(0, imagensHistoricas.length - 1),
        service: service,
      );
    }

    // Requisito 9: Se várias imagens atuais, abre seletor compacto
    final selecionada = await _exibirSeletorFotoAtual(context, imagensAtuais, service);
    if (selecionada == null || !context.mounted) return;

    return _exibirDialogo(
      context: context,
      notaAtual: notaAtual,
      anexosAtuais: imagensAtuais,
      anexoAtualInicial: selecionada,
      origemHistorica: OrigemComparadorHistorico.notaAnterior,
      notaHistorica: notaHistorica,
      anexosHistoricos: imagensHistoricas,
      indiceHistoricoInicial: indiceHistoricoInicial.clamp(0, imagensHistoricas.length - 1),
      service: service,
    );
  }

  /// Método estático para iniciar o fluxo de comparação a partir de um Álbum de Campo
  static Future<void> abrirComAlbum({
    required BuildContext context,
    required NotaSAP notaAtual,
    required List<NotaSapAnexo> anexosAtuais,
    required List<HistoricoVisualItem> itensAlbum,
    int indiceAlbumInicial = 0,
    required NotaSapAnaliseService service,
  }) async {
    final imagensAtuais = anexosAtuais
        .where((a) => a.tipoArquivo == NotaAnexoTipo.imagem)
        .toList();

    if (imagensAtuais.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A Nota atual não possui imagens disponíveis para comparação.',
          ),
          backgroundColor: Colors.amber,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (itensAlbum.isEmpty) return;

    if (imagensAtuais.length == 1) {
      return _exibirDialogo(
        context: context,
        notaAtual: notaAtual,
        anexosAtuais: imagensAtuais,
        anexoAtualInicial: imagensAtuais.first,
        origemHistorica: OrigemComparadorHistorico.albumCampo,
        itensAlbum: itensAlbum,
        indiceAlbumInicial: indiceAlbumInicial.clamp(0, itensAlbum.length - 1),
        service: service,
      );
    }

    final selecionada = await _exibirSeletorFotoAtual(context, imagensAtuais, service);
    if (selecionada == null || !context.mounted) return;

    return _exibirDialogo(
      context: context,
      notaAtual: notaAtual,
      anexosAtuais: imagensAtuais,
      anexoAtualInicial: selecionada,
      origemHistorica: OrigemComparadorHistorico.albumCampo,
      itensAlbum: itensAlbum,
      indiceAlbumInicial: indiceAlbumInicial.clamp(0, itensAlbum.length - 1),
      service: service,
    );
  }

  static Future<void> _exibirDialogo({
    required BuildContext context,
    required NotaSAP notaAtual,
    required List<NotaSapAnexo> anexosAtuais,
    required NotaSapAnexo anexoAtualInicial,
    required OrigemComparadorHistorico origemHistorica,
    NotaSAP? notaHistorica,
    List<NotaSapAnexo>? anexosHistoricos,
    int indiceHistoricoInicial = 0,
    List<HistoricoVisualItem>? itensAlbum,
    int indiceAlbumInicial = 0,
    required NotaSapAnaliseService service,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(230),
      builder: (ctx) => NotaComparadorVisualDialog(
        notaAtual: notaAtual,
        anexosAtuais: anexosAtuais,
        anexoAtualInicial: anexoAtualInicial,
        origemHistorica: origemHistorica,
        notaHistorica: notaHistorica,
        anexosHistoricos: anexosHistoricos,
        indiceHistoricoInicial: indiceHistoricoInicial,
        itensAlbum: itensAlbum,
        indiceAlbumInicial: indiceAlbumInicial,
        service: service,
      ),
    );
  }

  /// Seletor compacto modal de foto atual
  static Future<NotaSapAnexo?> _exibirSeletorFotoAtual(
    BuildContext context,
    List<NotaSapAnexo> imagensAtuais,
    NotaSapAnaliseService service,
  ) {
    return showDialog<NotaSapAnexo>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.photo_library_outlined, size: 20, color: Color(0xFF0F766E)),
              SizedBox(width: 8),
              Text('Escolha a imagem atual', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: imagensAtuais.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.0,
              ),
              itemBuilder: (context, index) {
                final anexo = imagensAtuais[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(TFRadius.r8),
                  onTap: () => Navigator.of(ctx).pop(anexo),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(TFRadius.r8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        FutureBuilder<String>(
                          future: service.obterUrlAssinada(anexo),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                              return Image.network(snapshot.data!, fit: BoxFit.cover);
                            }
                            return const Center(
                              child: Icon(Icons.image, size: 24, color: Colors.blueGrey),
                            );
                          },
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: Colors.black54,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              anexo.nomeOriginal ?? anexo.nomeArquivo,
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  @override
  State<NotaComparadorVisualDialog> createState() => _NotaComparadorVisualDialogState();
}

class _NotaComparadorVisualDialogState extends State<NotaComparadorVisualDialog> {
  // Estado Imagem Atual
  late NotaSapAnexo _anexoAtual;
  String? _urlAtual;
  bool _carregandoAtual = true;
  String? _erroAtual;
  double _rotacaoAtual = 0.0;
  late PhotoViewController _controllerAtual;

  // Estado Imagem Histórica
  late int _indiceHistorico;
  String? _urlHistorico;
  bool _carregandoHistorico = true;
  String? _erroHistorico;
  double _rotacaoHistorico = 0.0;
  late PhotoViewController _controllerHistorico;

  // Estado Geral de Interface
  LadoComparadorAtivo _ladoAtivo = LadoComparadorAtivo.historico;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _anexoAtual = widget.anexoAtualInicial;
    _controllerAtual = PhotoViewController();

    _indiceHistorico = widget.origemHistorica == OrigemComparadorHistorico.notaAnterior
        ? widget.indiceHistoricoInicial
        : widget.indiceAlbumInicial;
    _controllerHistorico = PhotoViewController();

    _carregarUrlAtual();
    _carregarUrlHistorico();
  }

  @override
  void dispose() {
    _controllerAtual.dispose();
    _controllerHistorico.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // RESOLUÇÃO DE SIGNED URLs DESACOPLADA (Itens 30, 31, 34, 35)
  // ---------------------------------------------------------------------------
  Future<void> _carregarUrlAtual() async {
    setState(() {
      _carregandoAtual = true;
      _erroAtual = null;
    });

    try {
      _urlAtual = await widget.service.obterUrlAssinada(_anexoAtual);
      if (mounted) {
        setState(() => _carregandoAtual = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _carregandoAtual = false;
          _erroAtual = 'Não foi possível carregar a imagem atual.';
        });
      }
    }
  }

  Future<void> _carregarUrlHistorico() async {
    setState(() {
      _carregandoHistorico = true;
      _erroHistorico = null;
    });

    try {
      if (widget.origemHistorica == OrigemComparadorHistorico.notaAnterior) {
        final anexos = widget.anexosHistoricos!;
        final anexo = anexos[_indiceHistorico];
        _urlHistorico = await widget.service.obterUrlAssinada(anexo);
      } else {
        final itens = widget.itensAlbum!;
        final item = itens[_indiceHistorico];
        _urlHistorico = item.imageUrl;
        if (_urlHistorico == null || _urlHistorico!.isEmpty) {
          throw Exception('URL do álbum indisponível');
        }
      }

      if (mounted) {
        setState(() => _carregandoHistorico = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _carregandoHistorico = false;
          _erroHistorico = 'Não foi possível carregar a imagem histórica.';
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // TRANSFORMAÇÕES INDEPENDENTES: ROTAÇÃO E RESET (Itens 15 a 20)
  // ---------------------------------------------------------------------------
  void _rotacionarLado(LadoComparadorAtivo lado) {
    setState(() {
      if (lado == LadoComparadorAtivo.atual) {
        _rotacaoAtual = (_rotacaoAtual + 90.0) % 360.0;
      } else {
        _rotacaoHistorico = (_rotacaoHistorico + 90.0) % 360.0;
      }
    });
  }

  void _resetLado(LadoComparadorAtivo lado) {
    setState(() {
      if (lado == LadoComparadorAtivo.atual) {
        _rotacaoAtual = 0.0;
        _controllerAtual.position = Offset.zero;
        _controllerAtual.scale = null;
      } else {
        _rotacaoHistorico = 0.0;
        _controllerHistorico.position = Offset.zero;
        _controllerHistorico.scale = null;
      }
    });
  }

  void _aplicarZoomLado(LadoComparadorAtivo lado, double fator) {
    final controller = lado == LadoComparadorAtivo.atual ? _controllerAtual : _controllerHistorico;
    final current = controller.scale ?? controller.value.scale;
    if (current == null) {
      controller.scale = fator > 1.0 ? 1.25 : 0.8;
      return;
    }
    final next = (current * fator).clamp(0.01, 30.0);
    controller.scale = next;
  }

  void _zoomInLado(LadoComparadorAtivo lado) => _aplicarZoomLado(lado, 1.25);
  void _zoomOutLado(LadoComparadorAtivo lado) => _aplicarZoomLado(lado, 0.8);

  void _alternarZoomDuploCliqueLado(LadoComparadorAtivo lado) {
    final controller = lado == LadoComparadorAtivo.atual ? _controllerAtual : _controllerHistorico;
    final current = controller.scale;
    if (current != null) {
      _resetLado(lado);
    } else {
      final base = controller.value.scale ?? 1.0;
      controller.scale = base * 2.5;
    }
  }

  void _tratarPointerSignalLado(LadoComparadorAtivo lado, PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      if (event.scrollDelta.dy < 0) {
        _aplicarZoomLado(lado, 1.15);
      } else if (event.scrollDelta.dy > 0) {
        _aplicarZoomLado(lado, 0.87);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // NAVEGAÇÃO E TROCA DE IMAGENS (Itens 21 a 24)
  // ---------------------------------------------------------------------------
  int get _totalHistorico {
    if (widget.origemHistorica == OrigemComparadorHistorico.notaAnterior) {
      return widget.anexosHistoricos?.length ?? 0;
    }
    return widget.itensAlbum?.length ?? 0;
  }

  void _irParaHistoricoAnterior() {
    if (_indiceHistorico > 0) {
      setState(() {
        _indiceHistorico--;
        _rotacaoHistorico = 0.0;
        _controllerHistorico.position = Offset.zero;
        _controllerHistorico.scale = null;
      });
      _carregarUrlHistorico();
    }
  }

  void _irParaHistoricoProximo() {
    if (_indiceHistorico < _totalHistorico - 1) {
      setState(() {
        _indiceHistorico++;
        _rotacaoHistorico = 0.0;
        _controllerHistorico.position = Offset.zero;
        _controllerHistorico.scale = null;
      });
      _carregarUrlHistorico();
    }
  }

  Future<void> _vincularHistoricoComoEvidencia() async {
    if (widget.origemHistorica != OrigemComparadorHistorico.notaAnterior) return;
    final anexo = widget.anexosHistoricos?[_indiceHistorico];
    if (anexo == null || anexo.id == null) return;

    final vinculou = await NotaVincularEvidenciaHistoricaDialog.exibir(
      context: context,
      notaAtual: widget.notaAtual,
      anexoHistorico: anexo,
      numeroNotaHistorica: widget.notaHistorica?.nota,
      service: widget.service,
    );

    if (vinculou == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🏛️ Anexo da Nota ${widget.notaHistorica?.nota ?? ""} vinculado como evidência técnica formal!',
          ),
          backgroundColor: const Color(0xFF0F766E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _trocarFotoAtual() async {
    final selecionada = await NotaComparadorVisualDialog._exibirSeletorFotoAtual(
      context,
      widget.anexosAtuais,
      widget.service,
    );
    if (selecionada != null && mounted) {
      setState(() {
        _anexoAtual = selecionada;
        _rotacaoAtual = 0.0;
        _controllerAtual.position = Offset.zero;
        _controllerAtual.scale = null;
      });
      _carregarUrlAtual();
    }
  }

  // ---------------------------------------------------------------------------
  // CÁLCULO DE DIFERENÇA TEMPORAL (Itens 28 e 29)
  // ---------------------------------------------------------------------------
  String? get _diferencaTemporalFormatada {
    final dataAtual = widget.notaAtual.criadoEm;
    DateTime? dataHist;

    if (widget.origemHistorica == OrigemComparadorHistorico.notaAnterior) {
      dataHist = widget.notaHistorica?.criadoEm ??
          widget.anexosHistoricos?[_indiceHistorico].createdAt;
    } else {
      dataHist = widget.itensAlbum?[_indiceHistorico].createdAt;
    }

    if (dataAtual == null || dataHist == null) return null;

    final diff = dataAtual.difference(dataHist).abs();
    final dias = diff.inDays;

    if (dias < 30) {
      return '$dias dias de diferença';
    } else if (dias < 365) {
      final meses = (dias / 30.4).round();
      return '$meses ${meses == 1 ? 'mês' : 'meses'} de diferença';
    } else {
      final anos = (dias / 365.25).floor();
      final restoMeses = ((dias % 365.25) / 30.4).round();
      if (restoMeses == 0) {
        return '$anos ${anos == 1 ? 'ano' : 'anos'} de diferença';
      }
      return '$anos ${anos == 1 ? 'ano' : 'anos'} e $restoMeses m de diferença';
    }
  }

  // ---------------------------------------------------------------------------
  // GESTÃO DE ATALHOS DE TECLADO (Itens 45, 46, 47)
  // ---------------------------------------------------------------------------
  void _lidarComTeclado(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    } else if (event.logicalKey == LogicalKeyboardKey.keyR) {
      _rotacionarLado(_ladoAtivo);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
        _ladoAtivo == LadoComparadorAtivo.historico) {
      _irParaHistoricoAnterior();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
        _ladoAtivo == LadoComparadorAtivo.historico) {
      _irParaHistoricoProximo();
    } else if (event.logicalKey == LogicalKeyboardKey.equal ||
        event.logicalKey == LogicalKeyboardKey.add ||
        event.logicalKey == LogicalKeyboardKey.numpadAdd ||
        event.character == '+') {
      _zoomInLado(_ladoAtivo);
    } else if (event.logicalKey == LogicalKeyboardKey.minus ||
        event.logicalKey == LogicalKeyboardKey.numpadSubtract ||
        event.character == '-') {
      _zoomOutLado(_ladoAtivo);
    } else if (event.logicalKey == LogicalKeyboardKey.digit0 ||
        event.logicalKey == LogicalKeyboardKey.numpad0) {
      _resetLado(_ladoAtivo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _lidarComTeclado,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: const Color(0xFF121417),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TFRadius.r16)),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;
            return SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Column(
                children: [
                  // 1. Barra de Topo do Comparador
                  _buildTopBar(isDesktop),

                  // 2. Área Central de Visualização
                  Expanded(
                    child: isDesktop
                        ? _buildDesktopLayout(constraints)
                        : _buildMobileLayout(constraints),
                  ),

                  // 3. Barra Inferior com Metadados e Diferença Temporal
                  _buildBottomBar(isDesktop),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BARRA SUPERIOR
  // ---------------------------------------------------------------------------
  Widget _buildTopBar(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1E2228),
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.compare_arrows_rounded, color: Colors.tealAccent, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              isDesktop ? 'Comparação Visual' : 'Comparador',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isDesktop && _diferencaTemporalFormatada != null) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.teal.withAlpha(50),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.tealAccent.withAlpha(120)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history_toggle_off, color: Colors.tealAccent, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _diferencaTemporalFormatada!,
                    style: const TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          if (!isDesktop)
            // Seletor rápido de alternância no Mobile (Requisito 13)
            Container(
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  _buildBotaoAlternanciaMobile(
                    'ATUAL',
                    Icons.check_circle_outline,
                    LadoComparadorAtivo.atual,
                    const Color(0xFF10B981),
                  ),
                  _buildBotaoAlternanciaMobile(
                    'HISTÓRICO',
                    Icons.history,
                    LadoComparadorAtivo.historico,
                    Colors.amberAccent,
                  ),
                ],
              ),
            ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            tooltip: 'Fechar (Esc)',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildBotaoAlternanciaMobile(
    String label,
    IconData icon,
    LadoComparadorAtivo lado,
    Color activeColor,
  ) {
    final ativo = _ladoAtivo == lado;
    return GestureDetector(
      onTap: () => setState(() => _ladoAtivo = lado),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: ativo ? activeColor.withAlpha(50) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: ativo ? activeColor : Colors.white54),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: ativo ? activeColor : Colors.white54,
                fontSize: 11,
                fontWeight: ativo ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LAYOUT DESKTOP (>= 900px): LADO A LADO 50% / 50% (Requisito 10)
  // ---------------------------------------------------------------------------
  Widget _buildDesktopLayout(BoxConstraints constraints) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Lado Esquerdo: ATUAL
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _ladoAtivo = LadoComparadorAtivo.atual),
            child: _buildPainelLado(
              lado: LadoComparadorAtivo.atual,
              tituloIdentificador: 'ATUAL',
              iconeIdentificador: Icons.check_circle_outline,
              corDestaque: const Color(0xFF10B981),
              subtituloNota: 'Nota SAP ${widget.notaAtual.nota.isNotEmpty ? widget.notaAtual.nota : widget.notaAtual.id}',
              dataNota: widget.notaAtual.criadoEm != null
                  ? '${widget.notaAtual.criadoEm!.day.toString().padLeft(2, "0")}/${widget.notaAtual.criadoEm!.month.toString().padLeft(2, "0")}/${widget.notaAtual.criadoEm!.year}'
                  : 'Data não informada',
              nomeArquivo: _anexoAtual.nomeOriginal ?? _anexoAtual.nomeArquivo,
              rotacaoGraus: _rotacaoAtual,
              controller: _controllerAtual,
              urlImagem: _urlAtual,
              carregando: _carregandoAtual,
              erro: _erroAtual,
              onRetry: _carregarUrlAtual,
              onRotacionar: () => _rotacionarLado(LadoComparadorAtivo.atual),
              onReset: () => _resetLado(LadoComparadorAtivo.atual),
              onTrocarImagem: widget.anexosAtuais.length > 1 ? _trocarFotoAtual : null,
            ),
          ),
        ),

        const VerticalDivider(width: 1, color: Colors.white12),

        // Lado Direito: HISTÓRICO
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _ladoAtivo = LadoComparadorAtivo.historico),
            child: _buildPainelLado(
              lado: LadoComparadorAtivo.historico,
              tituloIdentificador: 'HISTÓRICO',
              iconeIdentificador: Icons.history,
              corDestaque: const Color(0xFFF59E0B),
              subtituloNota: _obterSubtituloHistorico(),
              dataNota: _obterDataHistorica(),
              nomeArquivo: _obterNomeArquivoHistorico(),
              rotacaoGraus: _rotacaoHistorico,
              controller: _controllerHistorico,
              urlImagem: _urlHistorico,
              carregando: _carregandoHistorico,
              erro: _erroHistorico,
              onRetry: _carregarUrlHistorico,
              onRotacionar: () => _rotacionarLado(LadoComparadorAtivo.historico),
              onReset: () => _resetLado(LadoComparadorAtivo.historico),
              onAnterior: _indiceHistorico > 0 ? _irParaHistoricoAnterior : null,
              onProximo: _indiceHistorico < _totalHistorico - 1 ? _irParaHistoricoProximo : null,
              onUsarComoEvidencia: widget.origemHistorica == OrigemComparadorHistorico.notaAnterior
                  ? _vincularHistoricoComoEvidencia
                  : null,
              indiceNav: _indiceHistorico + 1,
              totalNav: _totalHistorico,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // LAYOUT MOBILE (< 900px): IMAGEM ATIVA QUASE TOTAL COM REFERÊNCIA (Requisito 13 e 14)
  // ---------------------------------------------------------------------------
  Widget _buildMobileLayout(BoxConstraints constraints) {
    final lado = _ladoAtivo;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Painel Central Expandido da Imagem Ativa
        if (lado == LadoComparadorAtivo.atual)
          _buildPainelLado(
            lado: LadoComparadorAtivo.atual,
            tituloIdentificador: 'ATUAL',
            iconeIdentificador: Icons.check_circle_outline,
            corDestaque: const Color(0xFF10B981),
            subtituloNota: 'Nota SAP ${widget.notaAtual.nota.isNotEmpty ? widget.notaAtual.nota : widget.notaAtual.id}',
            dataNota: widget.notaAtual.criadoEm != null
                ? '${widget.notaAtual.criadoEm!.day.toString().padLeft(2, "0")}/${widget.notaAtual.criadoEm!.month.toString().padLeft(2, "0")}/${widget.notaAtual.criadoEm!.year}'
                : '',
            nomeArquivo: _anexoAtual.nomeOriginal ?? _anexoAtual.nomeArquivo,
            rotacaoGraus: _rotacaoAtual,
            controller: _controllerAtual,
            urlImagem: _urlAtual,
            carregando: _carregandoAtual,
            erro: _erroAtual,
            onRetry: _carregarUrlAtual,
            onRotacionar: () => _rotacionarLado(LadoComparadorAtivo.atual),
            onReset: () => _resetLado(LadoComparadorAtivo.atual),
            onTrocarImagem: widget.anexosAtuais.length > 1 ? _trocarFotoAtual : null,
          )
        else
          _buildPainelLado(
            lado: LadoComparadorAtivo.historico,
            tituloIdentificador: 'HISTÓRICO',
            iconeIdentificador: Icons.history,
            corDestaque: const Color(0xFFF59E0B),
            subtituloNota: _obterSubtituloHistorico(),
            dataNota: _obterDataHistorica(),
            nomeArquivo: _obterNomeArquivoHistorico(),
            rotacaoGraus: _rotacaoHistorico,
            controller: _controllerHistorico,
            urlImagem: _urlHistorico,
            carregando: _carregandoHistorico,
            erro: _erroHistorico,
            onRetry: _carregarUrlHistorico,
            onRotacionar: () => _rotacionarLado(LadoComparadorAtivo.historico),
            onReset: () => _resetLado(LadoComparadorAtivo.historico),
            onAnterior: _indiceHistorico > 0 ? _irParaHistoricoAnterior : null,
            onProximo: _indiceHistorico < _totalHistorico - 1 ? _irParaHistoricoProximo : null,
            onUsarComoEvidencia: widget.origemHistorica == OrigemComparadorHistorico.notaAnterior
                ? _vincularHistoricoComoEvidencia
                : null,
            indiceNav: _indiceHistorico + 1,
            totalNav: _totalHistorico,
          ),

        // Miniatura Flutuante de Contexto do Outro Lado (Requisito 14)
        Positioned(
          top: 70,
          right: 16,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _ladoAtivo = lado == LadoComparadorAtivo.atual
                    ? LadoComparadorAtivo.historico
                    : LadoComparadorAtivo.atual;
              });
            },
            child: Container(
              width: 80,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF1E2228),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: lado == LadoComparadorAtivo.atual
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF10B981),
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      lado == LadoComparadorAtivo.atual ? 'HISTÓRICO' : 'ATUAL',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: lado == LadoComparadorAtivo.atual
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF10B981),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final outroUrl = lado == LadoComparadorAtivo.atual
                            ? _urlHistorico
                            : _urlAtual;
                        if (outroUrl != null && outroUrl.isNotEmpty) {
                          return Image.network(outroUrl, fit: BoxFit.cover);
                        }
                        return const Center(
                          child: Icon(Icons.image, size: 24, color: Colors.white24),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PAINEL INDIVIDUAL POR LADO
  // ---------------------------------------------------------------------------
  Widget _buildPainelLado({
    required LadoComparadorAtivo lado,
    required String tituloIdentificador,
    required IconData iconeIdentificador,
    required Color corDestaque,
    required String subtituloNota,
    required String dataNota,
    required String nomeArquivo,
    required double rotacaoGraus,
    required PhotoViewController controller,
    required String? urlImagem,
    required bool carregando,
    required String? erro,
    required VoidCallback onRetry,
    required VoidCallback onRotacionar,
    required VoidCallback onReset,
    VoidCallback? onTrocarImagem,
    VoidCallback? onAnterior,
    VoidCallback? onProximo,
    VoidCallback? onUsarComoEvidencia,
    int? indiceNav,
    int? totalNav,
  }) {
    final emFoco = _ladoAtivo == lado;
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(60),
        border: Border.all(
          color: emFoco ? corDestaque.withAlpha(120) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Cabeçalho Fixo do Lado (Requisitos 11 e 12)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: const Color(0xFF16191E),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: corDestaque.withAlpha(40),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: corDestaque),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(iconeIdentificador, color: corDestaque, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        tituloIdentificador,
                        style: TextStyle(
                          color: corDestaque,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        subtituloNota,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        dataNota.isNotEmpty ? '$dataNota • $nomeArquivo' : nomeArquivo,
                        style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Ações do Lado
                if (onTrocarImagem != null)
                  IconButton(
                    icon: const Icon(Icons.sync_alt, size: 18, color: Colors.white70),
                    tooltip: 'Trocar foto atual',
                    onPressed: onTrocarImagem,
                    visualDensity: VisualDensity.compact,
                  ),
                if (onAnterior != null || onProximo != null) ...[
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20, color: Colors.white70),
                    tooltip: 'Foto anterior',
                    onPressed: onAnterior,
                    visualDensity: VisualDensity.compact,
                  ),
                  if (indiceNav != null && totalNav != null)
                    Text(
                      '$indiceNav/$totalNav',
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20, color: Colors.white70),
                    tooltip: 'Próxima foto',
                    onPressed: onProximo,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
                if (onUsarComoEvidencia != null)
                  IconButton(
                    icon: const Icon(Icons.bookmark_add, size: 18, color: Colors.amberAccent),
                    tooltip: 'Usar este anexo histórico como evidência técnica formal',
                    onPressed: onUsarComoEvidencia,
                    visualDensity: VisualDensity.compact,
                  ),
                IconButton(
                  icon: const Icon(Icons.rotate_right, size: 18, color: Colors.white70),
                  tooltip: 'Rotacionar 90° (R)',
                  onPressed: onRotacionar,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_out, size: 18, color: Colors.white70),
                  tooltip: 'Afastar Zoom (-)',
                  onPressed: () => _zoomOutLado(lado),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_in, size: 18, color: Colors.white70),
                  tooltip: 'Aproximar Zoom (+)',
                  onPressed: () => _zoomInLado(lado),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.restart_alt, size: 18, color: Colors.white70),
                  tooltip: 'Resetar Zoom/Pan',
                  onPressed: onReset,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // Área da Imagem PhotoView
          Expanded(
            child: Builder(
              builder: (context) {
                if (carregando) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                  );
                }

                if (erro != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.broken_image_outlined, size: 48, color: Colors.amberAccent),
                          const SizedBox(height: 8),
                          Text(
                            erro,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white12,
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Tentar novamente'),
                            onPressed: onRetry,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (urlImagem == null || urlImagem.isEmpty) {
                  return const Center(
                    child: Text('Nenhuma imagem disponível', style: TextStyle(color: Colors.white38)),
                  );
                }

                final turns = (rotacaoGraus / 90.0).round() % 4;

                return Listener(
                  onPointerSignal: (e) => _tratarPointerSignalLado(lado, e),
                  child: GestureDetector(
                    onDoubleTap: () => _alternarZoomDuploCliqueLado(lado),
                    child: RotatedBox(
                      quarterTurns: turns,
                      child: PhotoView(
                        controller: controller,
                        imageProvider: NetworkImage(urlImagem),
                        backgroundDecoration: const BoxDecoration(color: Colors.transparent),
                        minScale: PhotoViewComputedScale.contained * 0.7,
                        maxScale: PhotoViewComputedScale.covered * 5.0,
                        loadingBuilder: (context, event) => Center(
                          child: CircularProgressIndicator(
                            value: event == null || event.expectedTotalBytes == null
                                ? null
                                : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        ),
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
                              const SizedBox(height: 8),
                              const Text(
                                'Erro ao renderizar imagem',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                              const SizedBox(height: 8),
                              TextButton(onPressed: onRetry, child: const Text('Recarregar')),
                            ],
                          ),
                        ),
                      ),
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

  // ---------------------------------------------------------------------------
  // BARRA INFERIOR DE LEGENDA
  // ---------------------------------------------------------------------------
  Widget _buildBottomBar(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF16191E),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Atual: ${_anexoAtual.legenda ?? _anexoAtual.nomeOriginal ?? _anexoAtual.nomeArquivo}',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Histórico: ${_obterLegendaHistorica()}',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS DE METADADOS HISTÓRICOS
  // ---------------------------------------------------------------------------
  String _obterSubtituloHistorico() {
    if (widget.origemHistorica == OrigemComparadorHistorico.notaAnterior) {
      final nota = widget.notaHistorica;
      return 'Nota SAP ${nota?.nota.isNotEmpty == true ? nota!.nota : (nota?.id ?? "")}';
    } else {
      final itens = widget.itensAlbum;
      if (itens != null && _indiceHistorico < itens.length) {
        final item = itens[_indiceHistorico];
        final local = item.localNome ?? '';
        return local.isNotEmpty
            ? 'Álbum de Campo • $local'
            : 'Álbum de Campo';
      }
      return 'Álbum de Campo';
    }
  }

  String _obterDataHistorica() {
    if (widget.origemHistorica == OrigemComparadorHistorico.notaAnterior) {
      final nota = widget.notaHistorica;
      if (nota?.criadoEm != null) {
        return '${nota!.criadoEm!.day.toString().padLeft(2, "0")}/${nota.criadoEm!.month.toString().padLeft(2, "0")}/${nota.criadoEm!.year}';
      }
      final anexo = widget.anexosHistoricos?[_indiceHistorico];
      if (anexo?.createdAt != null) {
        return '${anexo!.createdAt!.day.toString().padLeft(2, "0")}/${anexo.createdAt!.month.toString().padLeft(2, "0")}/${anexo.createdAt!.year}';
      }
      return 'Data não informada';
    } else {
      final itens = widget.itensAlbum;
      if (itens != null && _indiceHistorico < itens.length) {
        return itens[_indiceHistorico].dataFormatada;
      }
      return 'Data não informada';
    }
  }

  String _obterNomeArquivoHistorico() {
    if (widget.origemHistorica == OrigemComparadorHistorico.notaAnterior) {
      final anexo = widget.anexosHistoricos?[_indiceHistorico];
      return anexo?.nomeOriginal ?? anexo?.nomeArquivo ?? 'Arquivo';
    } else {
      final item = widget.itensAlbum?[_indiceHistorico];
      return item?.title ?? 'Foto de Álbum';
    }
  }

  String _obterLegendaHistorica() {
    if (widget.origemHistorica == OrigemComparadorHistorico.notaAnterior) {
      final anexo = widget.anexosHistoricos?[_indiceHistorico];
      return anexo?.legenda ?? anexo?.nomeOriginal ?? anexo?.nomeArquivo ?? '';
    } else {
      final item = widget.itensAlbum?[_indiceHistorico];
      return item?.description ?? item?.motivoCorrespondencia ?? item?.title ?? '';
    }
  }
}
