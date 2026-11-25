import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../design_system/taskflow_design_system.dart';
import '../../../notificacoes/data/notificacoes_gateway_service.dart';
import '../../../notificacoes/domain/models/notificacao_interna.dart';

/// Conversa operacional vinculada a uma solicitação de apoio.
/// Acessível exclusivamente às unidades participantes; não expõe chat privado
/// de outras divisões e não altera o status formal da solicitação.
class TaskApoioMensagensDialog extends StatefulWidget {
  final String solicitacaoId;
  final String tituloSolicitacao;
  final String usuarioAtualId;
  final String usuarioAtualNome;
  final bool modoDemonstracao;
  final NotificacoesGatewayService? gateway;

  const TaskApoioMensagensDialog({
    super.key,
    required this.solicitacaoId,
    required this.tituloSolicitacao,
    required this.usuarioAtualId,
    required this.usuarioAtualNome,
    this.modoDemonstracao = false,
    this.gateway,
  });

  @override
  State<TaskApoioMensagensDialog> createState() =>
      _TaskApoioMensagensDialogState();
}

class _TaskApoioMensagensDialogState extends State<TaskApoioMensagensDialog> {
  final _msgCtrl = TextEditingController();
  final _fmt = DateFormat('dd/MM HH:mm');
  late final NotificacoesGatewayService _gateway;

  bool _carregando = true;
  bool _enviando = false;
  String? _erro;
  List<ApoioMensagemOperacional> _mensagens = [];

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? NotificacoesGatewayService();
    _carregar();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      if (widget.modoDemonstracao) {
        _mensagens = [
          ApoioMensagemOperacional(
            id: 'demo-msg-1',
            solicitacaoId: widget.solicitacaoId,
            autorUsuarioId: 'demo-sol',
            autorNome: 'Coordenação Manutenção (Demo)',
            mensagem:
                '[DEMONSTRAÇÃO] Favor confirmar se o caminhão Munck possui lança de 12m para acesso na SE.',
            createdAt: DateTime.now().subtract(const Duration(minutes: 18)),
          ),
        ];
      } else {
        _mensagens =
            await _gateway.listarMensagensSolicitacao(widget.solicitacaoId);
      }
    } catch (e) {
      _erro = e.toString();
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _enviar() async {
    final texto = _msgCtrl.text.trim();
    if (texto.isEmpty || _enviando) return;
    setState(() => _enviando = true);
    try {
      if (widget.modoDemonstracao) {
        setState(() {
          _mensagens = [
            ..._mensagens,
            ApoioMensagemOperacional(
              id: 'demo-msg-${DateTime.now().microsecondsSinceEpoch}',
              solicitacaoId: widget.solicitacaoId,
              autorUsuarioId: widget.usuarioAtualId,
              autorNome: widget.usuarioAtualNome,
              mensagem: texto,
              createdAt: DateTime.now(),
            ),
          ];
          _msgCtrl.clear();
        });
      } else {
        final nova = await _gateway.enviarMensagemSolicitacao(
          widget.solicitacaoId,
          texto,
        );
        if (!mounted) return;
        setState(() {
          _mensagens = [..._mensagens, nova];
          _msgCtrl.clear();
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar mensagem: $e')),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typo = context.tfTypography;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 540),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.chat_bubble_outline, color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esclarecimentos: ${widget.tituloSolicitacao}',
                      style: typo.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Text(
                'Conversa restrita às unidades envolvidas. Decisões formais devem ser registradas pelos botões de ação.',
                style: typo.labelSmall.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              Expanded(
                child: _carregando
                    ? const Center(child: CircularProgressIndicator())
                    : _erro != null
                        ? Center(
                            child: Text(
                              _erro!,
                              style: typo.bodySmall.copyWith(color: colors.danger),
                            ),
                          )
                        : _mensagens.isEmpty
                            ? Center(
                                child: Text(
                                  'Nenhuma mensagem registrada ainda.',
                                  style: typo.bodySmall.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                itemCount: _mensagens.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, idx) {
                                  final m = _mensagens[idx];
                                  final ehMinha =
                                      m.autorUsuarioId == widget.usuarioAtualId;
                                  return Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: ehMinha
                                          ? colors.primary.withValues(alpha: 0.08)
                                          : colors.surface,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: colors.borderSubtle),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              m.autorNome,
                                              style: typo.labelSmall.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: colors.textPrimary,
                                              ),
                                            ),
                                            Text(
                                              _fmt.format(m.createdAt.toLocal()),
                                              style: typo.labelSmall.copyWith(
                                                color: colors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          m.mensagem,
                                          style: typo.bodySmall.copyWith(
                                            color: colors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Escreva um esclarecimento operacional...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _enviar(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _enviando ? null : _enviar,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
