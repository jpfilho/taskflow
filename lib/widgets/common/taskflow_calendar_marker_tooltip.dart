import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';

enum MarkerType { 
  nationalHoliday, 
  stateHoliday, 
  cityHoliday, 
  specialEvent, 
  operationalEvent 
}

class CalendarMarkerData {
  final String title;
  final MarkerType type;
  final DateTime date;
  final String? observation;

  const CalendarMarkerData({
    required this.title,
    required this.type,
    required this.date,
    this.observation,
  });
}

class TaskFlowCalendarMarkerTooltip extends StatefulWidget {
  final Widget child;
  final CalendarMarkerData data;
  final double maxWidth;

  const TaskFlowCalendarMarkerTooltip({
    Key? key,
    required this.child,
    required this.data,
    this.maxWidth = 420.0,
  }) : super(key: key);

  @override
  State<TaskFlowCalendarMarkerTooltip> createState() => _TaskFlowCalendarMarkerTooltipState();
}

class _TaskFlowCalendarMarkerTooltipState extends State<TaskFlowCalendarMarkerTooltip> {
  OverlayEntry? _overlayEntry;
  bool _isHovering = false;
  Timer? _hideTimer;
  final LayerLink _layerLink = LayerLink();

  Color _getMarkerColor(MarkerType type) {
    switch (type) {
      case MarkerType.nationalHoliday:
        return const Color(0xFF7C3AED);
      case MarkerType.stateHoliday:
        return const Color(0xFF9333EA);
      case MarkerType.cityHoliday:
        return const Color(0xFFA855F7);
      case MarkerType.specialEvent:
        return const Color(0xFFD97706);
      case MarkerType.operationalEvent:
        return const Color(0xFF2563EB);
    }
  }

  String _getTypeLabel(MarkerType type) {
    switch (type) {
      case MarkerType.nationalHoliday:
        return 'FERIADO NACIONAL';
      case MarkerType.stateHoliday:
        return 'FERIADO ESTADUAL';
      case MarkerType.cityHoliday:
        return 'FERIADO MUNICIPAL';
      case MarkerType.specialEvent:
        return 'EVENTO';
      case MarkerType.operationalEvent:
        return 'EVENTO OPERACIONAL';
    }
  }

  IconData _getTypeIcon(MarkerType type) {
    switch (type) {
      case MarkerType.nationalHoliday:
      case MarkerType.stateHoliday:
      case MarkerType.cityHoliday:
        return Icons.event_available;
      case MarkerType.specialEvent:
        return Icons.star;
      case MarkerType.operationalEvent:
        return Icons.settings;
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
    _hideTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted && _isHovering) {
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
    final screenSize = MediaQuery.of(context).size;
    
    bool showAbove = offset.dy > screenSize.height / 2;
    bool alignLeft = offset.dx > screenSize.width / 2;

    return OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() => _isHovering = false);
                  _hideOverlay();
                },
                behavior: HitTestBehavior.translucent,
                child: Container(color: Colors.transparent),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(
                alignLeft ? -widget.maxWidth + size.width + 10 : -10,
                showAbove ? -4 : size.height + 4,
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
    final color = _getMarkerColor(widget.data.type);
    final label = _getTypeLabel(widget.data.type);
    final icon = _getTypeIcon(widget.data.type);
    
    final dateStr = DateFormat('EEE, dd/MM/yyyy', 'pt_BR').format(widget.data.date);
    final formattedDate = dateStr[0].toUpperCase() + dateStr.substring(1);
    
    const double arrowSize = 8.0;

    Widget card = Container(
      constraints: BoxConstraints(
        maxWidth: widget.maxWidth,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5EAF2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: IntrinsicWidth(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(11),
                    bottomLeft: Radius.circular(11),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: color,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, size: 14, color: color),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.data.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$formattedDate${widget.data.observation != null ? ' · ${widget.data.observation}' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return CustomPaint(
      painter: TooltipArrowPainter(
        color: Colors.white,
        borderColor: const Color(0xFFE5EAF2),
        isTop: showAbove,
        alignLeft: alignLeft,
        arrowSize: arrowSize,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: showAbove ? 0 : arrowSize,
          bottom: showAbove ? arrowSize : 0,
        ),
        child: card,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) => _onEnter(),
        onExit: (_) => _onExit(),
        child: GestureDetector(
          onTap: _onEnter,
          child: widget.child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hideOverlay();
    _hideTimer?.cancel();
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
      arrowX = size.width - 25;
    } else {
      arrowX = 25;
    }

    if (isTop) {
      path.moveTo(arrowX - arrowSize, size.height - arrowSize);
      path.lineTo(arrowX, size.height);
      path.lineTo(arrowX + arrowSize, size.height - arrowSize);
    } else {
      path.moveTo(arrowX - arrowSize, arrowSize);
      path.lineTo(arrowX, 0);
      path.lineTo(arrowX + arrowSize, arrowSize);
    }
    
    path.close();
    
    canvas.drawShadow(path, Colors.black.withOpacity(0.05), 4.0, false);
    canvas.drawPath(path, paint);
    
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
