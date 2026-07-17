import 'package:flutter/material.dart';

class ChatFeedbackForm extends StatefulWidget {
  final Map<String, dynamic> itemInfo;
  final String refType;
  final Function(Map<String, dynamic>) onChanged;
  final Map<String, dynamic>? initialData;

  const ChatFeedbackForm({
    Key? key,
    required this.itemInfo,
    required this.refType,
    required this.onChanged,
    this.initialData,
  }) : super(key: key);

  @override
  _ChatFeedbackFormState createState() => _ChatFeedbackFormState();
}

class _ChatFeedbackFormState extends State<ChatFeedbackForm> {
  String _statusExecucao = 'NÃO INFORMADO';
  double _percentual = 0.0;
  String? _motivoNaoExecucao;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _statusExecucao = widget.initialData!['status'] ?? 'NÃO INFORMADO';
      _percentual = widget.initialData!['percentual']?.toDouble() ?? 0.0;
      _motivoNaoExecucao = widget.initialData!['motivoNaoExecucao'];
      _commentController.text = widget.initialData!['comentario'] ?? '';
    }
  }

  void _notifyChanges() {
    widget.onChanged({
      'status': _statusExecucao,
      'percentual': _percentual,
      'motivoNaoExecucao': _motivoNaoExecucao,
      'comentario': _commentController.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.refType == 'NOTA' ? 'Nota ${widget.itemInfo['nota']}' : 'Ordem ${widget.itemInfo['ordem']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (widget.itemInfo['descricao'] != null)
              Text(
                widget.itemInfo['descricao'],
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Executado?', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _statusExecucao,
                  items: const [
                    DropdownMenuItem(value: 'NÃO INFORMADO', child: Text('NÃO INFORMADO')),
                    DropdownMenuItem(value: 'SIM', child: Text('SIM')),
                    DropdownMenuItem(value: 'NÃO', child: Text('NÃO')),
                    DropdownMenuItem(value: 'PARCIAL', child: Text('PARCIAL')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _statusExecucao = val;
                        if (val == 'SIM') {
                          _percentual = 100;
                          _motivoNaoExecucao = null;
                        } else if (val == 'NÃO') {
                          _percentual = 0;
                        }
                      });
                      _notifyChanges();
                    }
                  },
                ),
              ],
            ),
            if (_statusExecucao == 'PARCIAL') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('% Execução:'),
                  Expanded(
                    child: Slider(
                      value: _percentual,
                      min: 0,
                      max: 99,
                      divisions: 99,
                      label: '${_percentual.round()}%',
                      onChanged: (val) {
                        setState(() => _percentual = val);
                        _notifyChanges();
                      },
                    ),
                  ),
                  Text('${_percentual.round()}%'),
                ],
              ),
            ],
            if (_statusExecucao == 'NÃO' || _statusExecucao == 'PARCIAL') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Motivo',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                value: _motivoNaoExecucao,
                items: const [
                  DropdownMenuItem(value: 'Falta de material', child: Text('Falta de material')),
                  DropdownMenuItem(value: 'Falta de tempo', child: Text('Falta de tempo')),
                  DropdownMenuItem(value: 'Impedimento operacional', child: Text('Impedimento operacional')),
                  DropdownMenuItem(value: 'Outro', child: Text('Outro')),
                ],
                onChanged: (val) {
                  setState(() => _motivoNaoExecucao = val);
                  _notifyChanges();
                },
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'Comentário / Observação (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              onChanged: (_) => _notifyChanges(),
            ),
          ],
        ),
      ),
    );
  }
}
