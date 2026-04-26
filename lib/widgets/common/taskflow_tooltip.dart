import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

enum TooltipSeverity { danger, warning, info, success }
enum TooltipThemeStyle { corporateLight, darkGlass, compact }

class TooltipContent {
  final String title;
  final TooltipSeverity severity;
  final String? executor;
  final String? reason;
  final List<String>? tasks;
  final String? status;
  final String? period;

  const TooltipContent({
    required this.title,
    this.severity = TooltipSeverity.info,
    this.executor,
    this.reason,
    this.tasks,
    this.status,
    this.period,
  });
}

class TaskFlowTooltip extends StatefulWidget {
  final Widget child;
  final TooltipContent content;
  final TooltipThemeStyle themeStyle;
  final double maxWidth;
  final double minWidth;

  const TaskFlowTooltip({
    Key? key,
    required this.child,
    required this.content,
    this.themeStyle = TooltipThemeStyle.corporateLight,
    this.maxWidth = 520.0,
    this.minWidth = 320.0,
  }) : super(key: key);

  @override
  State<TaskFlowTooltip> createState() => _TaskFlowTooltipState();
}

class _TaskFlowTooltipState extends State<TaskFlowTooltip> {
  OverlayEntry? _overlayEntry;
  bool _isHovering = false;
  Timer? _hideTimer;
  
  final LayerLink _layerLink = LayerLink();

  Color _getSeverityColor(TooltipSeverity severity) {
    switch (severity) {
      case TooltipSeverity.danger:
        return const Color(0xFFDC2626);
      case TooltipSeverity.warning:
        return const Color(0xFFD97706);
      case TooltipSeverity.info:
        return const Color(0xFF2563EB);
      case TooltipSeverity.success:
        return const Color(0xFF16A34A);
    }
  }

  void _onEnter() {
    _hideTimer?.cancel();
    if (!_isHovering) {
      setState(() => _isHovering = true);
      _showOverlay();
    }
  }

  void _onExit() {
    _hideTimer = Timer(const Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() => _isHovering = false);
        _hideOverlay();
      }
    });
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;
    var offset = renderBox.localToGlobal(Offset.zero);
    
    // Configurações de posicionamento
    final screenSize = MediaQuery.of(context).size;
    
    // Calcular melhor posição
    bool showAbove = offset.dy > screenSize.height / 2;
    bool alignLeft = offset.dx > screenSize.width / 2;
    
    return OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Catcher para fechar no tap outside (mobile) ou clique (desktop)
            Positioned.fill(
              child: Listener(
                onPointerDown: (e) {
                  // Se houver qualquer clique fora, esconda o tooltip
                  setState(() {
                    _isHovering = false;
                  });
                  _hideOverlay();
                },
                behavior: HitTestBehavior.translucent, // Importante: não bloqueia hover!
                child: const SizedBox.expand(),
              ),
            ),
            
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(
                alignLeft ? -widget.maxWidth + size.width + 10 : -10,
                showAbove ? -10 : size.height + 10,
              ),
              child: FractionalTranslation(
                translation: Offset(0, showAbove ? -1.0 : 0.0),
                child: MouseRegion(
                  onEnter: (_) => _onEnter(),
                  onExit: (_) => _onExit(),
                  child: Material(
                    color: Colors.transparent,
                    child: _buildTooltipContent(showAbove, alignLeft),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTooltipContent(bool showAbove, bool alignLeft) {
    final severityColor = _getSeverityColor(widget.content.severity);
    
    Color bgColor = Colors.white;
    Color textColor = const Color(0xFF1F2937); // Cinza escuro corporativo
    Color subTextColor = const Color(0xFF4B5563);
    Color borderColor = const Color(0xFFE5EAF2);
    
    if (widget.themeStyle == TooltipThemeStyle.darkGlass) {
      bgColor = const Color(0xFF1E293B).withOpacity(0.95);
      textColor = Colors.white;
      subTextColor = const Color(0xFF94A3B8);
      borderColor = const Color(0xFF334155);
    }
    
    double arrowSize = 8.0;

    Widget cardContent = Container(
      constraints: BoxConstraints(
        minWidth: widget.minWidth,
        maxWidth: widget.maxWidth,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Stack(
          children: [
            // Barra lateral de severidade
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 6,
              child: Container(color: severityColor),
            ),
            
            Padding(
              padding: EdgeInsets.only(
                left: 6, // Espaço para a barra de severidade
              ),
              child: Padding(
                padding: EdgeInsets.all(widget.themeStyle == TooltipThemeStyle.compact ? 12.0 : 18.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Cabeçalho (Título + Severidade label)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.content.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: severityColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.content.severity.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: severityColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  if (widget.content.executor != null || widget.content.period != null || widget.content.status != null) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        if (widget.content.executor != null)
                          _buildInfoChip(Icons.person_outline, 'EXECUTOR', widget.content.executor!, subTextColor, textColor),
                        if (widget.content.status != null)
                          _buildInfoChip(Icons.info_outline, 'STATUS', widget.content.status!, subTextColor, textColor),
                        if (widget.content.period != null)
                          _buildInfoChip(Icons.calendar_today_outlined, 'PERÍODO', widget.content.period!, subTextColor, textColor),
                      ],
                    ),
                  ],
                  
                  if (widget.content.reason != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      widget.content.reason!,
                      style: TextStyle(
                        fontSize: 14,
                        color: subTextColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                  
                  if (widget.content.tasks != null && widget.content.tasks!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'TAREFAS:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: subTextColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: 200, // Limite para evitar que o tooltip fique gigante
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: widget.themeStyle == TooltipThemeStyle.darkGlass 
                              ? Colors.black.withOpacity(0.2) 
                              : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: widget.themeStyle == TooltipThemeStyle.darkGlass
                                ? Colors.white.withOpacity(0.05)
                                : const Color(0xFFF3F4F6),
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: widget.content.tasks!.asMap().entries.map((entry) {
                              int idx = entry.key;
                              String task = entry.value;
                              return Padding(
                                padding: EdgeInsets.only(bottom: idx == widget.content.tasks!.length - 1 ? 0 : 8.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${idx + 1}. ', style: TextStyle(fontWeight: FontWeight.bold, color: severityColor)),
                                    Expanded(
                                      child: Text(
                                        task,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: textColor,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // Adiciona a seta (arrow) apontando pro target
    return CustomPaint(
      painter: TooltipArrowPainter(
        color: bgColor,
        borderColor: borderColor,
        isTop: showAbove,
        alignLeft: alignLeft,
        arrowSize: arrowSize,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: showAbove ? 0 : arrowSize,
          bottom: showAbove ? arrowSize : 0,
        ),
        child: cardContent,
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value, Color labelColor, Color valueColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: labelColor),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: labelColor,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (event) {
          if (event.kind == PointerDeviceKind.mouse) {
            _onEnter();
          }
        },
        onExit: (event) {
          if (event.kind == PointerDeviceKind.mouse) {
            _onExit();
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            if (_isHovering) {
              setState(() => _isHovering = false);
              _hideOverlay();
            } else {
              _onEnter();
            }
          },
          child: widget.child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }
}

class TooltipArrowPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final bool isTop;
  final bool alignLeft;
  final double arrowSize;

  TooltipArrowPainter({
    required this.color,
    required this.borderColor,
    required this.isTop,
    required this.alignLeft,
    this.arrowSize = 8.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
      
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();
    
    double arrowX;
    if (alignLeft) {
      arrowX = size.width - 30; // Posiciona a seta próximo ao canto direito se o tooltip for alinhado a esquerda
    } else {
      arrowX = 30; // Posiciona a seta próximo ao canto esquerdo se o tooltip for alinhado a direita
    }

    if (isTop) {
      // Seta na parte de baixo apontando pra baixo
      path.moveTo(arrowX - arrowSize, size.height - arrowSize);
      path.lineTo(arrowX, size.height);
      path.lineTo(arrowX + arrowSize, size.height - arrowSize);
    } else {
      // Seta na parte de cima apontando pra cima
      path.moveTo(arrowX - arrowSize, arrowSize);
      path.lineTo(arrowX, 0);
      path.lineTo(arrowX + arrowSize, arrowSize);
    }
    
    path.close();
    
    canvas.drawShadow(path, Colors.black.withOpacity(0.05), 4.0, false);
    canvas.drawPath(path, paint);
    
    // Desenha as duas linhas laterais do triângulo (para a borda)
    final borderPath = Path();
    if (isTop) {
      borderPath.moveTo(arrowX - arrowSize, size.height - arrowSize);
      borderPath.lineTo(arrowX, size.height);
      borderPath.lineTo(arrowX + arrowSize, size.height - arrowSize);
    } else {
      borderPath.moveTo(arrowX - arrowSize, arrowSize);
      borderPath.lineTo(arrowX, 0);
      borderPath.lineTo(arrowX + arrowSize, arrowSize);
    }
    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant TooltipArrowPainter oldDelegate) {
    return color != oldDelegate.color ||
        borderColor != oldDelegate.borderColor ||
        isTop != oldDelegate.isTop ||
        alignLeft != oldDelegate.alignLeft;
  }
}
