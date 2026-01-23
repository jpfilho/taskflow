import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

/// Widget que permite redimensionar dois painéis arrastando um divisor entre eles
class ResizablePanel extends StatefulWidget {
  final Widget leftChild;
  final Widget rightChild;
  final double initialLeftWidth; // Largura inicial do painel esquerdo em pixels
  final double minLeftWidth; // Largura mínima do painel esquerdo
  final double minRightWidth; // Largura mínima do painel direito
  final double dividerWidth; // Largura do divisor
  final Color dividerColor; // Cor do divisor
  final Color dividerHoverColor; // Cor do divisor ao passar o mouse

  const ResizablePanel({
    super.key,
    required this.leftChild,
    required this.rightChild,
    this.initialLeftWidth = 400,
    this.minLeftWidth = 200,
    this.minRightWidth = 200,
    this.dividerWidth = 16.0,
    this.dividerColor = Colors.grey,
    this.dividerHoverColor = Colors.blue,
  });

  @override
  State<ResizablePanel> createState() => _ResizablePanelState();
}

class _ResizablePanelState extends State<ResizablePanel> {
  late double _leftWidth;
  bool _isDragging = false;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _leftWidth = widget.initialLeftWidth;
  }

  void _onPanStart(DragStartDetails details) {
    print('🖱️ ResizablePanel: _onPanStart - posição: ${details.globalPosition}');
    setState(() {
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    print('🖱️ ResizablePanel: _onPanUpdate - delta: ${details.delta.dx}');
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      print('⚠️ ResizablePanel: renderBox é null');
      return;
    }

    final screenWidth = renderBox.size.width;
    final delta = details.delta.dx;
    final newWidth = _leftWidth + delta;
    final clampedWidth = newWidth.clamp(
      widget.minLeftWidth,
      screenWidth - widget.minRightWidth - widget.dividerWidth,
    );

    print('📏 ResizablePanel: screenWidth=$screenWidth, _leftWidth=$_leftWidth, newWidth=$newWidth, clampedWidth=$clampedWidth');

    setState(() {
      _leftWidth = clampedWidth;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    print('🖱️ ResizablePanel: _onPanEnd');
    setState(() {
      _isDragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        
        // Garantir que a largura não ultrapasse os limites
        final clampedLeftWidth = _leftWidth.clamp(
          widget.minLeftWidth,
          screenWidth - widget.minRightWidth - widget.dividerWidth,
        );

        return Row(
          children: [
            // Painel esquerdo
            SizedBox(
              width: clampedLeftWidth,
              child: widget.leftChild,
            ),
            // Divisor arrastável
            MouseRegion(
              onEnter: (_) => setState(() => _isHovering = true),
              onExit: (_) => setState(() => _isHovering = false),
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: Container(
                  width: widget.dividerWidth,
                  decoration: BoxDecoration(
                    color: _isHovering || _isDragging
                        ? widget.dividerHoverColor
                        : widget.dividerColor,
                    border: Border.symmetric(
                      vertical: BorderSide(
                        color: _isHovering || _isDragging
                            ? Colors.blue[300]!
                            : Colors.grey[400]!,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.drag_handle,
                      color: _isHovering || _isDragging
                          ? Colors.white
                          : Colors.grey[800],
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
            // Painel direito
            Expanded(
              child: widget.rightChild,
            ),
          ],
        );
      },
    );
  }
}
