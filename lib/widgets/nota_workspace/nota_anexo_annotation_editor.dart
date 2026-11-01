import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../design_system/theme/taskflow_theme_extension.dart';
import '../../design_system/foundations/tf_colors.dart';
import '../../design_system/foundations/tf_spacing.dart';
import '../../design_system/foundations/tf_radius.dart';
import '../../models/nota_sap_analise.dart';
import '../../models/nota_sap_anotacao.dart';
import '../../services/auth_service_simples.dart';
import '../../services/nota_sap_analise_service.dart';
import 'nota_anotacao_transform_helper.dart';

enum _FerramentaAnotacao {
  pan,
  selecionar,
  retangulo,
  circulo,
  seta,
  texto,
}

class NotaAnexoAnnotationEditor extends StatefulWidget {
  final NotaSapAnexo anexo;
  final String imageUrl;
  final NotaSapAnaliseService service;
  final VoidCallback? onSalvo;
  final Size? initialImageSize;
  final Uint8List? originalImageBytes;

  const NotaAnexoAnnotationEditor({
    super.key,
    required this.anexo,
    required this.imageUrl,
    required this.service,
    this.onSalvo,
    this.initialImageSize,
    this.originalImageBytes,
  });

  @override
  State<NotaAnexoAnnotationEditor> createState() =>
      _NotaAnexoAnnotationEditorState();
}

class _NotaAnexoAnnotationEditorState extends State<NotaAnexoAnnotationEditor> {
  // Elementos e estado de anotação
  List<NotaSapAnotacaoElemento> _elements = [];
  String? _selectedElementId;
  NotaSapAnotacaoElemento? _tempElement;

  // Dimensões intrínsecas da imagem
  Size? _imageSize;
  bool _isLoadingImage = true;
  String? _loadError;

  // Ferramentas e estilo ativos
  _FerramentaAnotacao _ferramenta = _FerramentaAnotacao.retangulo;
  String _corSelecionada = '#E53935'; // Vermelho de alto contraste
  double _espessuraSelecionada = 3.0;

  // Pilhas de Undo / Redo
  final List<List<NotaSapAnotacaoElemento>> _undoStack = [];
  final List<List<NotaSapAnotacaoElemento>> _redoStack = [];

  // Controle de alterações
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;

  // Drag interativo para mover
  Offset? _dragStartNormalized;
  NotaSapAnotacaoElemento? _elementBeforeDrag;

  // Paleta de cores essenciais
  static const List<String> _coresDisponiveis = [
    '#E53935', // Vermelho
    '#FBC02D', // Amarelo
    '#1E88E5', // Azul
    '#FFFFFF', // Branco
    '#212121', // Preto
  ];

  // Zoom e transformação da viewport
  late final TransformationController _transformationController;
  bool _isSpacePressed = false;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    if (widget.initialImageSize != null) {
      _imageSize = widget.initialImageSize;
      _isLoadingImage = false;
    } else {
      _resolverDimensoesImagem();
    }
    _carregarAnotacaoExistente();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  /// Resolve a dimensão física da imagem via ImageStream
  void _resolverDimensoesImagem() {
    final imageProvider = NetworkImage(widget.imageUrl);
    final imageStream = imageProvider.resolve(ImageConfiguration.empty);

    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        if (!mounted) return;
        setState(() {
          _imageSize = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          );
          _isLoadingImage = false;
        });
        imageStream.removeListener(listener);
      },
      onError: (exception, stackTrace) {
        if (!mounted) return;
        setState(() {
          _loadError = 'Não foi possível carregar a imagem para anotação.';
          _isLoadingImage = false;
        });
        imageStream.removeListener(listener);
      },
    );

    imageStream.addListener(listener);
  }

  /// Carrega anotação prévia se já houver no banco
  Future<void> _carregarAnotacaoExistente() async {
    if (widget.anexo.id == null) return;
    try {
      final ultima = await widget.service.obterUltimaAnotacao(widget.anexo.id!);
      if (ultima != null && mounted) {
        setState(() {
          _elements = List.from(ultima.dadosJson.elements);
          _hasUnsavedChanges = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ [_carregarAnotacaoExistente] Erro: $e');
    }
  }

  // ============================================================================
  // UNDO / REDO / HISTÓRICO
  // ============================================================================

  void _pushUndoSnapshot() {
    _undoStack.add(List.unmodifiable(_elements));
    _redoStack.clear();
    _hasUnsavedChanges = true;
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _redoStack.add(List.unmodifiable(_elements));
      _elements = _undoStack.removeLast();
      _selectedElementId = null;
      _hasUnsavedChanges = true;
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _undoStack.add(List.unmodifiable(_elements));
      _elements = _redoStack.removeLast();
      _selectedElementId = null;
      _hasUnsavedChanges = true;
    });
  }

  void _excluirSelecionado() {
    if (_selectedElementId == null) return;
    _pushUndoSnapshot();
    setState(() {
      _elements.removeWhere((e) => e.id == _selectedElementId);
      _selectedElementId = null;
    });
  }

  // ============================================================================
  // ZOOM E TRANSFORMAÇÃO DA VIEWPORT
  // ============================================================================

  void _zoomAt(Offset focalPoint, double factor) {
    final matrix = _transformationController.value.clone();
    final currentScale = matrix.getMaxScaleOnAxis();
    final targetScale = (currentScale * factor).clamp(0.2, 12.0);
    final actualFactor = targetScale / currentScale;

    if ((actualFactor - 1.0).abs() < 0.001) return;

    final focalTransform = Matrix4.identity()
      ..multiply(Matrix4.translationValues(focalPoint.dx, focalPoint.dy, 0.0))
      ..multiply(Matrix4.diagonal3Values(actualFactor, actualFactor, 1.0))
      ..multiply(Matrix4.translationValues(-focalPoint.dx, -focalPoint.dy, 0.0));

    _transformationController.value = focalTransform * matrix;
  }

  void _zoomAtCenter(double factor, [Size? containerSize]) {
    final size = containerSize ?? const Size(800, 600);
    _zoomAt(Offset(size.width / 2, size.height / 2), factor);
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  void _handlePointerSignal(PointerSignalEvent event, Size containerSize) {
    if (event is! PointerScrollEvent) return;
    final delta = event.scrollDelta.dy;
    if (delta == 0) return;

    final factor = delta < 0 ? 1.15 : (1.0 / 1.15);
    _zoomAt(event.localPosition, factor);
  }

  MouseCursor get _currentCursor {
    if (_isSpacePressed || _ferramenta == _FerramentaAnotacao.pan) {
      return SystemMouseCursors.grab;
    }
    if (_ferramenta == _FerramentaAnotacao.selecionar) {
      return SystemMouseCursors.basic;
    }
    return SystemMouseCursors.precise;
  }

  // ============================================================================
  // INTERAÇÃO COM O CANVAS / GESTOS
  // ============================================================================

  void _onPanStart(Offset point, Rect imageRect) {
    if (_imageSize == null || imageRect.isEmpty) return;

    final normPoint = NotaAnotacaoTransformHelper.screenToNormalized(
      screenOffset: point,
      imageRect: imageRect,
    );

    if (_ferramenta == _FerramentaAnotacao.selecionar) {
      // Hit testing do topo para o fundo
      NotaSapAnotacaoElemento? hit;
      for (final el in _elements.reversed) {
        if (NotaAnotacaoTransformHelper.hitTestElement(
          element: el,
          normalizedPoint: normPoint,
          imageRect: imageRect,
        )) {
          hit = el;
          break;
        }
      }

      setState(() {
        _selectedElementId = hit?.id;
        if (hit != null) {
          _dragStartNormalized = normPoint;
          _elementBeforeDrag = hit;
        }
      });
      return;
    }

    if (_ferramenta == _FerramentaAnotacao.texto) {
      // Abre o diálogo para inserir texto no ponto tocado
      _abrirDialogoTexto(normPoint);
      return;
    }

    // Ferramentas de desenho vetorial (Retângulo, Círculo, Seta)
    _pushUndoSnapshot();

    NotaSapElementoTipo tipo;
    switch (_ferramenta) {
      case _FerramentaAnotacao.retangulo:
        tipo = NotaSapElementoTipo.rect;
        break;
      case _FerramentaAnotacao.circulo:
        tipo = NotaSapElementoTipo.circle;
        break;
      case _FerramentaAnotacao.seta:
        tipo = NotaSapElementoTipo.arrow;
        break;
      default:
        tipo = NotaSapElementoTipo.rect;
    }

    setState(() {
      _tempElement = NotaSapAnotacaoElemento(
        id: 'elem_${DateTime.now().millisecondsSinceEpoch}',
        type: tipo,
        x1: normPoint.dx,
        y1: normPoint.dy,
        x2: normPoint.dx,
        y2: normPoint.dy,
        strokeWidth: _espessuraSelecionada,
        color: _corSelecionada,
        zIndex: _elements.length + 1,
      );
    });
  }

  void _onPanUpdate(Offset point, Rect imageRect) {
    if (_imageSize == null || imageRect.isEmpty) return;

    final normPoint = NotaAnotacaoTransformHelper.screenToNormalized(
      screenOffset: point,
      imageRect: imageRect,
    );

    // Mover elemento selecionado
    if (_ferramenta == _FerramentaAnotacao.selecionar &&
        _selectedElementId != null &&
        _dragStartNormalized != null &&
        _elementBeforeDrag != null) {
      final delta = normPoint - _dragStartNormalized!;
      final idx = _elements.indexWhere((e) => e.id == _selectedElementId);
      if (idx != -1) {
        final orig = _elementBeforeDrag!;
        final newX1 = (orig.x1 + delta.dx).clamp(0.0, 1.0);
        final newY1 = (orig.y1 + delta.dy).clamp(0.0, 1.0);
        final newX2 = orig.x2 != null
            ? (orig.x2! + delta.dx).clamp(0.0, 1.0)
            : null;
        final newY2 = orig.y2 != null
            ? (orig.y2! + delta.dy).clamp(0.0, 1.0)
            : null;

        setState(() {
          _elements[idx] = orig.copyWith(
            x1: newX1,
            y1: newY1,
            x2: newX2,
            y2: newY2,
          );
        });
      }
      return;
    }

    // Atualização de desenho provisório
    if (_tempElement != null) {
      setState(() {
        _tempElement = _tempElement!.copyWith(
          x2: normPoint.dx,
          y2: normPoint.dy,
        );
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_dragStartNormalized != null && _elementBeforeDrag != null) {
      // Conclusão do movimento: salvar snapshot no undo se houve deslocamento real
      _pushUndoSnapshot();
      _dragStartNormalized = null;
      _elementBeforeDrag = null;
    }

    if (_tempElement != null) {
      // Conclui desenho do elemento
      final el = _tempElement!;
      _tempElement = null;

      // Verifica tamanho mínimo para evitar criação acidental por clique simples
      final dx = ((el.x2 ?? el.x1) - el.x1).abs();
      final dy = ((el.y2 ?? el.y1) - el.y1).abs();
      if (dx > 0.01 || dy > 0.01) {
        setState(() {
          _elements.add(el);
          _selectedElementId = el.id;
          _hasUnsavedChanges = true;
        });
      } else {
        setState(() {});
      }
    }
  }

  Future<void> _abrirDialogoTexto(Offset normPoint) async {
    final controller = TextEditingController();
    final texto = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar Texto Técnico'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Ex.: Trinca, Oxidação, Substituir...',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (val) => Navigator.of(ctx).pop(val.trim()),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                'Trinca',
                'Oxidação',
                'Substituir',
                'Vazamento',
                'Avariado',
              ].map((sugestao) {
                return ActionChip(
                  label: Text(sugestao, style: const TextStyle(fontSize: 12)),
                  onPressed: () {
                    controller.text = sugestao;
                  },
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Inserir'),
          ),
        ],
      ),
    );

    if (texto != null && texto.isNotEmpty && mounted) {
      _pushUndoSnapshot();
      setState(() {
        final el = NotaSapAnotacaoElemento(
          id: 'elem_${DateTime.now().millisecondsSinceEpoch}',
          type: NotaSapElementoTipo.text,
          x1: normPoint.dx,
          y1: normPoint.dy,
          text: texto,
          color: _corSelecionada,
          fontSize: 15.0,
          zIndex: _elements.length + 1,
        );
        _elements.add(el);
        _selectedElementId = el.id;
        _hasUnsavedChanges = true;
      });
    }
  }

  // ============================================================================
  // SALVAMENTO E PERSISTÊNCIA
  // ============================================================================

  Future<void> _salvarAnotacao() async {
    if (widget.anexo.id == null) return;
    setState(() => _isSaving = true);

    try {
      String? userId;
      String? userName;
      try {
        final auth = AuthServiceSimples();
        userId = auth.currentUser?.id;
        userName = auth.getUserName() ?? auth.currentUser?.email;
      } catch (_) {}

      final doc = NotaSapAnotacaoDocumento(
        version: 1,
        canvasWidth: _imageSize?.width ?? 1920.0,
        canvasHeight: _imageSize?.height ?? 1080.0,
        elements: _elements,
      );

      final nova = await widget.service.salvarAnotacao(
        anexoId: widget.anexo.id!,
        dadosJson: doc,
        imagemLargura: _imageSize?.width.toInt(),
        imagemAltura: _imageSize?.height.toInt(),
        criadoPor: userId,
        criadoPorNome: userName,
      );

      _hasUnsavedChanges = false;

      // 2. Tentar gerar e registrar imagem derivada PNG (secundária ao JSON)
      bool derivadaSucesso = false;
      String? derivadaErro;
      try {
        Uint8List? rawBytes = widget.originalImageBytes;
        if (rawBytes == null || rawBytes.isEmpty) {
          final uri = Uri.tryParse(widget.imageUrl);
          if (uri != null && uri.scheme.startsWith('http')) {
            final resp = await http.get(uri).timeout(const Duration(seconds: 15));
            if (resp.statusCode == 200) {
              rawBytes = resp.bodyBytes;
            }
          }
        }

        if (rawBytes != null && rawBytes.isNotEmpty) {
          final resultadoDerivada = await widget.service.gerarERegistrarDerivada(
            anexoOriginal: widget.anexo,
            anotacao: nova,
            imagemOriginalBytes: rawBytes,
          );
          derivadaSucesso = resultadoDerivada.sucesso;
          derivadaErro = resultadoDerivada.erro;
        }
      } catch (err) {
        derivadaErro = err.toString();
      }

      if (mounted) {
        if (derivadaSucesso) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Anotação técnica v${nova.versao} e evidência PNG salvas com sucesso!',
              ),
              backgroundColor: Colors.green.shade700,
            ),
          );
        } else {
          // Item 22 e 40: JSON permanece salvo, mas avisa sobre a derivada
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Anotação salva. Não foi possível gerar a imagem anotada.${derivadaErro != null ? " ($derivadaErro)" : ""}',
              ),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        widget.onSalvo?.call();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar anotação: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _fecharComConfirmacao() async {
    if (!_hasUnsavedChanges) {
      Navigator.of(context).pop(false);
      return;
    }

    final descartar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar alterações?'),
        content: const Text(
          'Existem marcações técnicas não salvas. Se fechar agora, o trabalho será perdido.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Continuar editando'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Descartar e Fechar'),
          ),
        ],
      ),
    );

    if (descartar == true && mounted) {
      Navigator.of(context).pop(false);
    }
  }

  // ============================================================================
  // ATALHOS DE TECLADO
  // ============================================================================

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final isCtrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;

    // Espaço mantido pressionado para pan dinâmico
    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent && !_isSpacePressed) {
        setState(() => _isSpacePressed = true);
        return KeyEventResult.handled;
      } else if (event is KeyUpEvent && _isSpacePressed) {
        setState(() => _isSpacePressed = false);
        return KeyEventResult.handled;
      }
    }

    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Atalhos de Zoom: +, -, 0
    if (event.logicalKey == LogicalKeyboardKey.equal ||
        event.logicalKey == LogicalKeyboardKey.add ||
        event.logicalKey == LogicalKeyboardKey.numpadAdd) {
      _zoomAtCenter(1.25);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.minus ||
        event.logicalKey == LogicalKeyboardKey.numpadSubtract) {
      _zoomAtCenter(0.8);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.digit0 ||
        event.logicalKey == LogicalKeyboardKey.numpad0) {
      _resetZoom();
      return KeyEventResult.handled;
    }

    // Atalhos rápidos de ferramentas (quando sem Ctrl/Meta)
    if (!isCtrl) {
      if (event.logicalKey == LogicalKeyboardKey.keyH) {
        setState(() => _ferramenta = _FerramentaAnotacao.pan);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyV) {
        setState(() => _ferramenta = _FerramentaAnotacao.selecionar);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyR) {
        setState(() => _ferramenta = _FerramentaAnotacao.retangulo);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyC) {
        setState(() => _ferramenta = _FerramentaAnotacao.circulo);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyA) {
        setState(() => _ferramenta = _FerramentaAnotacao.seta);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyT) {
        setState(() => _ferramenta = _FerramentaAnotacao.texto);
        return KeyEventResult.handled;
      }
    }

    if (isCtrl && !isShift && event.logicalKey == LogicalKeyboardKey.keyZ) {
      _undo();
      return KeyEventResult.handled;
    }

    if (isCtrl && (isShift || event.logicalKey == LogicalKeyboardKey.keyY) &&
        (event.logicalKey == LogicalKeyboardKey.keyZ ||
            event.logicalKey == LogicalKeyboardKey.keyY)) {
      _redo();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      _excluirSelecionado();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() => _selectedElementId = null);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // ============================================================================
  // BUILD PRINCIPAL
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tfTheme = theme.extension<TaskFlowThemeExtension>();
    final colors = tfTheme?.colors ?? TFSemanticColors.dark();
    final spacing = tfTheme?.spacing ?? const TFSpacing();
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF252526),
          foregroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Voltar',
            onPressed: _fecharComConfirmacao,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Anotação Técnica: ${widget.anexo.nomeExibicao}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Edição Não Destrutiva • Original Intacto',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
            ],
          ),
          actions: [
            // Ação Salvar
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.primaryForeground,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check, size: 18),
                label: Text(_isSaving ? 'Salvando...' : 'Salvar Versão'),
                onPressed: _isSaving ? null : _salvarAnotacao,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Toolbar superior para Desktop
            if (isDesktop) _buildDesktopToolbar(colors, spacing),

            // Canvas da Imagem com Letterboxing e Overlay Vetorial
            Expanded(
              child: _isLoadingImage
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : _loadError != null
                      ? Center(
                          child: Text(
                            _loadError!,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final containerSize = Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );
                            final imageRect =
                                NotaAnotacaoTransformHelper.calculateImageRect(
                              containerSize: containerSize,
                              imageSize: _imageSize!,
                              fit: BoxFit.contain,
                            );

                            final isPanActive =
                                _ferramenta == _FerramentaAnotacao.pan ||
                                    _isSpacePressed;

                            return Stack(
                              children: [
                                Positioned.fill(
                                  child: Listener(
                                    onPointerSignal: (event) =>
                                        _handlePointerSignal(
                                            event, containerSize),
                                    child: MouseRegion(
                                      cursor: _currentCursor,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onPanStart: (d) {
                                          if (isPanActive) return;
                                          final point =
                                              _transformationController
                                                  .toScene(d.localPosition);
                                          _onPanStart(point, imageRect);
                                        },
                                        onPanUpdate: (d) {
                                          if (isPanActive) {
                                            final translation =
                                                Matrix4.translationValues(
                                                    d.delta.dx,
                                                    d.delta.dy,
                                                    0.0);
                                            _transformationController.value =
                                                translation *
                                                    _transformationController
                                                        .value;
                                            return;
                                          }
                                          final point =
                                              _transformationController
                                                  .toScene(d.localPosition);
                                          _onPanUpdate(point, imageRect);
                                        },
                                        onPanEnd: (d) {
                                          if (isPanActive) return;
                                          _onPanEnd(d);
                                        },
                                        child: ClipRect(
                                          child: ValueListenableBuilder<Matrix4>(
                                            valueListenable:
                                                _transformationController,
                                            builder: (context, matrix, _) {
                                              return Transform(
                                                transform: matrix,
                                                child: Stack(
                                                  children: [
                                                    // 1. Imagem de Fundo (Intacta)
                                                    Positioned.fromRect(
                                                      rect: imageRect,
                                                      child: Image.network(
                                                        widget.imageUrl,
                                                        fit: BoxFit.fill,
                                                        errorBuilder: (ctx, _, __) =>
                                                            const Center(
                                                          child: Icon(
                                                              Icons.broken_image,
                                                              color: Colors.white30,
                                                              size: 48),
                                                        ),
                                                      ),
                                                    ),

                                                    // 2. Camada de Desenho Vetorial
                                                    CustomPaint(
                                                      size: containerSize,
                                                      painter: _NotaAnotacaoPainter(
                                                        elements: _elements,
                                                        selectedElementId:
                                                            _selectedElementId,
                                                        tempElement: _tempElement,
                                                        imageRect: imageRect,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Controle Flutuante de Zoom no canto inferior direito
                                Positioned(
                                  right: 16,
                                  bottom: 16,
                                  child: _buildFloatingZoomControls(
                                      colors, containerSize),
                                ),
                              ],
                            );
                          },
                        ),
            ),

            // Toolbar inferior para Mobile / Compacto
            if (!isDesktop) _buildMobileBottomBar(colors, spacing),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // TOOLBARS
  // ============================================================================

  Widget _buildDesktopToolbar(
    TFSemanticColors colors,
    TFSpacing spacing,
  ) {
    return Container(
      height: 52,
      padding: EdgeInsets.symmetric(horizontal: spacing.md),
      decoration: const BoxDecoration(
        color: Color(0xFF2D2D2D),
        border: Border(bottom: BorderSide(color: Color(0xFF3E3E3E))),
      ),
      child: Row(
        children: [
          // Ferramentas principais
          _buildToolButton(
            icon: Icons.pan_tool_outlined,
            tool: _FerramentaAnotacao.pan,
            tooltip: 'Mover Tela (Pan / H)',
          ),
          _buildToolButton(
            icon: Icons.pan_tool_alt_outlined,
            tool: _FerramentaAnotacao.selecionar,
            tooltip: 'Selecionar / Mover',
          ),
          const VerticalDivider(width: 16, indent: 12, endIndent: 12),
          _buildToolButton(
            icon: Icons.crop_square_outlined,
            tool: _FerramentaAnotacao.retangulo,
            tooltip: 'Retângulo',
          ),
          _buildToolButton(
            icon: Icons.circle_outlined,
            tool: _FerramentaAnotacao.circulo,
            tooltip: 'Círculo / Elipse',
          ),
          _buildToolButton(
            icon: Icons.north_east_outlined,
            tool: _FerramentaAnotacao.seta,
            tooltip: 'Seta Técnica',
          ),
          _buildToolButton(
            icon: Icons.text_fields_outlined,
            tool: _FerramentaAnotacao.texto,
            tooltip: 'Texto / Legenda',
          ),

          const VerticalDivider(width: 24, indent: 12, endIndent: 12),

          // Seletor de Cores
          Row(
            children: _coresDisponiveis.map((hex) {
              final isSelected = _corSelecionada == hex;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _corSelecionada = hex;
                    if (_selectedElementId != null) {
                      _pushUndoSnapshot();
                      final idx = _elements.indexWhere(
                        (e) => e.id == _selectedElementId,
                      );
                      if (idx != -1) {
                        _elements[idx] = _elements[idx].copyWith(color: hex);
                      }
                    }
                  });
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _parseColor(hex),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.white.withAlpha(128),
                              blurRadius: 4,
                            )
                          ]
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),

          const VerticalDivider(width: 24, indent: 12, endIndent: 12),

          // Espessura
          Row(
            children: [
              _buildStrokeButton(label: 'Fina', width: 2.0),
              _buildStrokeButton(label: 'Média', width: 4.0),
              _buildStrokeButton(label: 'Grossa', width: 6.0),
            ],
          ),

          const Spacer(),

          // Ações Auxiliares: Undo / Redo / Excluir
          IconButton(
            icon: const Icon(Icons.undo, size: 20, color: Colors.white70),
            tooltip: 'Desfazer (Ctrl+Z)',
            onPressed: _undoStack.isNotEmpty ? _undo : null,
          ),
          IconButton(
            icon: const Icon(Icons.redo, size: 20, color: Colors.white70),
            tooltip: 'Refazer (Ctrl+Y)',
            onPressed: _redoStack.isNotEmpty ? _redo : null,
          ),
          if (_selectedElementId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: Colors.redAccent),
              tooltip: 'Excluir elemento selecionado (Delete)',
              onPressed: _excluirSelecionado,
            ),

          const VerticalDivider(width: 20, indent: 12, endIndent: 12),

          // Zoom na Toolbar Desktop
          _buildToolbarZoomControls(),
        ],
      ),
    );
  }

  Widget _buildMobileBottomBar(
    TFSemanticColors colors,
    TFSpacing spacing,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF252526),
        border: Border(top: BorderSide(color: Color(0xFF3E3E3E))),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildToolButton(
                icon: Icons.pan_tool_outlined,
                tool: _FerramentaAnotacao.pan,
                tooltip: 'Mover Tela',
              ),
              _buildToolButton(
                icon: Icons.pan_tool_alt_outlined,
                tool: _FerramentaAnotacao.selecionar,
                tooltip: 'Selecionar',
              ),
              _buildToolButton(
                icon: Icons.crop_square_outlined,
                tool: _FerramentaAnotacao.retangulo,
                tooltip: 'Retângulo',
              ),
              _buildToolButton(
                icon: Icons.circle_outlined,
                tool: _FerramentaAnotacao.circulo,
                tooltip: 'Círculo',
              ),
              _buildToolButton(
                icon: Icons.north_east_outlined,
                tool: _FerramentaAnotacao.seta,
                tooltip: 'Seta',
              ),
              _buildToolButton(
                icon: Icons.text_fields_outlined,
                tool: _FerramentaAnotacao.texto,
                tooltip: 'Texto',
              ),
              const SizedBox(width: 8),
              // Cores em bolinhas compactas
              ..._coresDisponiveis.map((hex) {
                final isSelected = _corSelecionada == hex;
                return GestureDetector(
                  onTap: () => setState(() => _corSelecionada = hex),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _parseColor(hex),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.undo, size: 20, color: Colors.white70),
                onPressed: _undoStack.isNotEmpty ? _undo : null,
              ),
              IconButton(
                icon: const Icon(Icons.redo, size: 20, color: Colors.white70),
                onPressed: _redoStack.isNotEmpty ? _redo : null,
              ),
              if (_selectedElementId != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: Colors.redAccent),
                  onPressed: _excluirSelecionado,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required _FerramentaAnotacao tool,
    required String tooltip,
  }) {
    final isSelected = _ferramenta == tool;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white24 : Colors.transparent,
        borderRadius: BorderRadius.circular(TFRadius.r8),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          size: 20,
          color: isSelected ? Colors.white : Colors.white70,
        ),
        tooltip: tooltip,
        onPressed: () {
          setState(() {
            _ferramenta = tool;
            if (tool != _FerramentaAnotacao.selecionar) {
              _selectedElementId = null;
            }
          });
        },
      ),
    );
  }

  Widget _buildStrokeButton({required String label, required double width}) {
    final isSelected = (_espessuraSelecionada - width).abs() < 0.1;
    return GestureDetector(
      onTap: () {
        setState(() {
          _espessuraSelecionada = width;
          if (_selectedElementId != null) {
            _pushUndoSnapshot();
            final idx = _elements.indexWhere((e) => e.id == _selectedElementId);
            if (idx != -1) {
              _elements[idx] = _elements[idx].copyWith(strokeWidth: width);
            }
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white24 : Colors.transparent,
          borderRadius: BorderRadius.circular(TFRadius.r4),
          border: Border.all(
            color: isSelected ? Colors.white60 : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      final h = hex.replaceAll('#', '').trim();
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return Colors.red;
    }
  }

  // ============================================================================
  // WIDGETS DE CONTROLE DE ZOOM
  // ============================================================================

  Widget _buildToolbarZoomControls() {
    return ValueListenableBuilder<Matrix4>(
      valueListenable: _transformationController,
      builder: (context, matrix, _) {
        final scale = matrix.getMaxScaleOnAxis();
        final scalePercent = (scale * 100).round();

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove, size: 18, color: Colors.white70),
              tooltip: 'Afastar (Zoom -)',
              onPressed: () => _zoomAtCenter(0.8),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(TFRadius.r4),
              onTap: _resetZoom,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  '$scalePercent%',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add, size: 18, color: Colors.white70),
              tooltip: 'Aproximar (Zoom +)',
              onPressed: () => _zoomAtCenter(1.25),
            ),
            IconButton(
              icon: const Icon(Icons.fit_screen_outlined,
                  size: 18, color: Colors.white70),
              tooltip: 'Ajustar à Tela (100% / 0)',
              onPressed: _resetZoom,
            ),
          ],
        );
      },
    );
  }

  Widget _buildFloatingZoomControls(
      TFSemanticColors colors, Size containerSize) {
    return ValueListenableBuilder<Matrix4>(
      valueListenable: _transformationController,
      builder: (context, matrix, _) {
        final scale = matrix.getMaxScaleOnAxis();
        final scalePercent = (scale * 100).round();

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF252526).withAlpha(235),
            borderRadius: BorderRadius.circular(TFRadius.rFull),
            border: Border.all(color: Colors.white24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 18, color: Colors.white),
                tooltip: 'Afastar (Zoom -)',
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => _zoomAtCenter(0.8, containerSize),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(TFRadius.rFull),
                onTap: _resetZoom,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    '$scalePercent%',
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
                tooltip: 'Aproximar (Zoom +)',
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => _zoomAtCenter(1.25, containerSize),
              ),
              Container(
                width: 1,
                height: 16,
                color: Colors.white24,
                margin: const EdgeInsets.symmetric(horizontal: 2),
              ),
              IconButton(
                icon: const Icon(Icons.fit_screen_outlined,
                    size: 18, color: Colors.white70),
                tooltip: 'Ajustar à Tela (0)',
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: _resetZoom,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// CUSTOM PAINTER VETORIAL PARA ANOTAÇÕES TÉCNICAS
// ============================================================================

class _NotaAnotacaoPainter extends CustomPainter {
  final List<NotaSapAnotacaoElemento> elements;
  final String? selectedElementId;
  final NotaSapAnotacaoElemento? tempElement;
  final Rect imageRect;

  _NotaAnotacaoPainter({
    required this.elements,
    this.selectedElementId,
    this.tempElement,
    required this.imageRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageRect.isEmpty) return;

    // 1. Renderiza elementos consolidados
    for (final el in elements) {
      _paintElement(canvas, el, isSelected: el.id == selectedElementId);
    }

    // 2. Renderiza elemento temporário em drag ativo
    if (tempElement != null) {
      _paintElement(canvas, tempElement!, isSelected: false, isTemp: true);
    }
  }

  void _paintElement(
    Canvas canvas,
    NotaSapAnotacaoElemento el, {
    required bool isSelected,
    bool isTemp = false,
  }) {
    final p1 = NotaAnotacaoTransformHelper.normalizedToScreen(
      normalizedOffset: Offset(el.x1, el.y1),
      imageRect: imageRect,
    );
    final p2 = el.x2 != null && el.y2 != null
        ? NotaAnotacaoTransformHelper.normalizedToScreen(
            normalizedOffset: Offset(el.x2!, el.y2!),
            imageRect: imageRect,
          )
        : p1;

    final paint = Paint()
      ..color = isTemp ? el.colorValue.withAlpha(217) : el.colorValue
      ..strokeWidth = el.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    switch (el.type) {
      case NotaSapElementoTipo.rect:
        final rect = Rect.fromPoints(p1, p2);
        canvas.drawRect(rect, paint);
        if (isSelected) _paintBoundingBox(canvas, rect);
        break;

      case NotaSapElementoTipo.circle:
        final rect = Rect.fromPoints(p1, p2);
        canvas.drawOval(rect, paint);
        if (isSelected) _paintBoundingBox(canvas, rect);
        break;

      case NotaSapElementoTipo.arrow:
        _paintArrow(canvas, p1, p2, paint);
        if (isSelected) {
          final rect = Rect.fromPoints(p1, p2).inflate(8.0);
          _paintBoundingBox(canvas, rect);
        }
        break;

      case NotaSapElementoTipo.text:
        _paintText(canvas, el, p1, isSelected);
        break;
    }
  }

  void _paintArrow(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    // Desenha a linha da seta
    canvas.drawLine(p1, p2, paint);

    // Desenha a cabeça proporcional da seta em p2
    final double arrowSize = math.max(paint.strokeWidth * 4.0, 14.0);
    final double angle = math.atan2(p2.dy - p1.dy, p2.dx - p1.dx);

    final pLeft = Offset(
      p2.dx - arrowSize * math.cos(angle - math.pi / 6),
      p2.dy - arrowSize * math.sin(angle - math.pi / 6),
    );
    final pRight = Offset(
      p2.dx - arrowSize * math.cos(angle + math.pi / 6),
      p2.dy - arrowSize * math.sin(angle + math.pi / 6),
    );

    final path = Path()
      ..moveTo(p2.dx, p2.dy)
      ..lineTo(pLeft.dx, pLeft.dy)
      ..lineTo(pRight.dx, pRight.dy)
      ..close();

    final fillPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(path, fillPaint);
  }

  void _paintText(
    Canvas canvas,
    NotaSapAnotacaoElemento el,
    Offset pos,
    bool isSelected,
  ) {
    final text = el.text ?? el.label ?? '';
    if (text.isEmpty) return;

    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: el.colorValue,
        fontSize: el.fontSize,
        fontWeight: FontWeight.bold,
        shadows: const [
          Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
        ],
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    // Fundo semitransparente para legibilidade técnica
    final bgRect = Rect.fromLTWH(
      pos.dx - 4,
      pos.dy - 2,
      textPainter.width + 8,
      textPainter.height + 4,
    );
    final bgPaint = Paint()
      ..color = Colors.black.withAlpha(166)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
      bgPaint,
    );

    textPainter.paint(canvas, pos);

    if (isSelected) {
      _paintBoundingBox(canvas, bgRect);
    }
  }

  void _paintBoundingBox(Canvas canvas, Rect rect) {
    final boxPaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawRect(rect.inflate(4.0), boxPaint);

    // Handles nos 4 cantos
    final handlePaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.fill;

    for (final corner in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      canvas.drawCircle(corner, 3.5, handlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NotaAnotacaoPainter oldDelegate) {
    return oldDelegate.elements != elements ||
        oldDelegate.selectedElementId != selectedElementId ||
        oldDelegate.tempElement != tempElement ||
        oldDelegate.imageRect != imageRect;
  }
}
