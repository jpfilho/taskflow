import 'package:flutter/material.dart';

import '../../data/models/document_status.dart';

class DocumentStatusBadge extends StatelessWidget {
  final DocumentStatus? status;
  final EdgeInsets padding;

  const DocumentStatusBadge({
    super.key,
    required this.status,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    if (status == null) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: status!.backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status!.nome,
        style: TextStyle(
          color: status!.textColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
