import 'package:flutter/material.dart';
import '../../design_system/theme/taskflow_theme_extension.dart';
import '../../design_system/foundations/tf_radius.dart';
import '../../models/nota_sap_analise.dart';
import '../../services/auth_service_simples.dart';
import '../../services/nota_sap_analise_service.dart';

class NotaWorkspaceDiscussionTab extends StatefulWidget {
  final String notaSapId;
  final NotaSapAnaliseService service;

  const NotaWorkspaceDiscussionTab({
    super.key,
    required this.notaSapId,
    required this.service,
  });

  @override
  State<NotaWorkspaceDiscussionTab> createState() =>
      _NotaWorkspaceDiscussionTabState();
}

class _NotaWorkspaceDiscussionTabState
    extends State<NotaWorkspaceDiscussionTab> {
  final TextEditingController _mensagemController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<NotaSapComentario> _comentarios = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _erro;

  NotaSapComentario? _replyingTo;
  NotaSapComentario? _editingComentario;

  @override
  void initState() {
    super.initState();
    _carregarComentariosEIniciarRealtime();
  }

  Future<void> _carregarComentariosEIniciarRealtime() async {
    setState(() {
      _isLoading = true;
      _erro = null;
    });

    try {
      final list = await widget.service.listarComentarios(widget.notaSapId);
      if (mounted) {
        setState(() {
          _comentarios = list;
          _isLoading = false;
        });
        _scrollToBottom();
      }

      widget.service.assinarComentarios(
        notaSapId: widget.notaSapId,
        onNovoComentario: (novo) {
          if (!mounted) return;
          final existe = _comentarios.any((c) => c.id == novo.id);
          if (!existe) {
            setState(() {
              _comentarios.add(novo);
            });
            _scrollToBottom();
          }
        },
        onAtualizacao: (atualizado) {
          if (!mounted) return;
          setState(() {
            final idx = _comentarios.indexWhere((c) => c.id == atualizado.id);
            if (idx != -1) {
              if (atualizado.isDeleted) {
                _comentarios.removeAt(idx);
              } else {
                _comentarios[idx] = atualizado;
              }
            }
          });
        },
        onExclusao: (idExcluido) {
          if (!mounted) return;
          setState(() {
            _comentarios.removeWhere((c) => c.id == idExcluido);
          });
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = 'Não foi possível carregar a discussão técnica: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    widget.service.cancelarAssinaturaComentarios(widget.notaSapId);
    _mensagemController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _enviarMensagem() async {
    final texto = _mensagemController.text.trim();
    if (texto.isEmpty) return;

    String userId = 'usuario_local';
    String userName = 'Usuário';
    try {
      final auth = AuthServiceSimples();
      final user = auth.currentUser;
      userId = user?.id ?? 'usuario_local';
      userName = auth.getUserName() ?? user?.email ?? 'Usuário';
    } catch (_) {}

    setState(() => _isSending = true);

    try {
      if (_editingComentario != null && _editingComentario!.id != null) {
        final editado = await widget.service.editarComentario(
          _editingComentario!.id!,
          texto,
        );
        setState(() {
          final idx =
              _comentarios.indexWhere((c) => c.id == _editingComentario!.id);
          if (idx != -1) {
            _comentarios[idx] = editado;
          }
          _editingComentario = null;
          _mensagemController.clear();
        });
      } else {
        final novo = await widget.service.adicionarComentario(
          notaSapId: widget.notaSapId,
          mensagem: texto,
          usuarioId: userId,
          usuarioNome: userName,
          replyToId: _replyingTo?.id,
        );

        setState(() {
          final existe = _comentarios.any((c) => c.id == novo.id);
          if (!existe) {
            _comentarios.add(novo);
          }
          _replyingTo = null;
          _mensagemController.clear();
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar mensagem: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _confirmarExclusao(NotaSapComentario comentario) async {
    if (comentario.id == null) return;
    final colors = context.tfColors;
    final typography = context.tfTypography;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Excluir Comentário',
            style: typography.sectionTitle.copyWith(color: colors.textPrimary)),
        content: Text(
          'Deseja realmente remover esta mensagem da discussão técnica?',
          style: typography.bodyMedium.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar',
                style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmou == true) {
      try {
        await widget.service.excluirComentario(
          comentario.id!,
          notaSapId: widget.notaSapId,
        );
        setState(() {
          _comentarios.removeWhere((c) => c.id == comentario.id);
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir comentário: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _iniciarEdicao(NotaSapComentario c) {
    setState(() {
      _editingComentario = c;
      _replyingTo = null;
      _mensagemController.text = c.mensagem;
    });
  }

  void _cancelarEdicaoOuReply() {
    setState(() {
      _editingComentario = null;
      _replyingTo = null;
      _mensagemController.clear();
    });
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    String? currentUserId;
    try {
      currentUserId = AuthServiceSimples().currentUser?.id;
    } catch (_) {}

    return Column(
      children: [
        // Banner de topo informativo
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.md,
            vertical: spacing.sm,
          ),
          color: colors.surfaceSecondary,
          child: Row(
            children: [
              Icon(Icons.forum_outlined, color: colors.primary, size: 18),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Text(
                  'Discussão técnica em tempo real dedicada a esta Nota SAP. Comentários registrados aqui ficam preservados no histórico técnico.',
                  style: typography.caption.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Área de mensagens com scroll
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _erro != null
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(spacing.lg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_erro!,
                                style: TextStyle(color: Colors.red.shade800),
                                textAlign: TextAlign.center),
                            SizedBox(height: spacing.md),
                            OutlinedButton(
                              onPressed: _carregarComentariosEIniciarRealtime,
                              child: const Text('Tentar Novamente'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _comentarios.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_bubble_outline_rounded,
                                    size: 48,
                                    color:
                                        colors.textSecondary.withAlpha(100)),
                                SizedBox(height: spacing.md),
                                Text(
                                  'Nenhum comentário registrado ainda',
                                  style: typography.bodyMedium.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: spacing.xs),
                                Text(
                                  'Utilize o campo abaixo para compartilhar orientações técnicas, alertas de segurança ou dúvidas com a equipe.',
                                  style: typography.caption.copyWith(
                                      color: colors.textSecondary),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.all(spacing.md),
                          itemCount: _comentarios.length,
                          itemBuilder: (context, index) {
                            final c = _comentarios[index];
                            final isMe = currentUserId != null &&
                                c.usuarioId == currentUserId;

                            NotaSapComentario? replyMsg;
                            if (c.replyToId != null) {
                              replyMsg = _comentarios.cast<NotaSapComentario?>().firstWhere(
                                    (item) => item?.id == c.replyToId,
                                    orElse: () => null,
                                  );
                            }

                            return _buildMessageItem(
                              context,
                              c: c,
                              isMe: isMe,
                              replyMsg: replyMsg,
                              colors: colors,
                              typography: typography,
                              spacing: spacing,
                            );
                          },
                        ),
        ),

        // Barra de reply / edição se ativa
        if (_replyingTo != null || _editingComentario != null)
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: spacing.md, vertical: spacing.xs),
            color: colors.surfaceSecondary,
            child: Row(
              children: [
                Icon(
                  _editingComentario != null
                      ? Icons.edit_outlined
                      : Icons.reply_outlined,
                  size: 16,
                  color: colors.primary,
                ),
                SizedBox(width: spacing.xs),
                Expanded(
                  child: Text(
                    _editingComentario != null
                        ? 'Editando comentário'
                        : 'Respondendo a ${_replyingTo?.usuarioNome ?? 'Usuário'}: "${_replyingTo?.mensagem ?? ''}"',
                    style: typography.caption.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: _cancelarEdicaoOuReply,
                  tooltip: 'Cancelar',
                ),
              ],
            ),
          ),

        // Campo de input inferior fixo
        Container(
          padding: EdgeInsets.all(spacing.sm),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(top: BorderSide(color: colors.borderSubtle)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _mensagemController,
                  maxLines: 3,
                  minLines: 1,
                  style:
                      typography.bodyMedium.copyWith(color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: _editingComentario != null
                        ? 'Atualize seu comentário...'
                        : 'Escreva um comentário técnico...',
                    hintStyle: TextStyle(color: colors.textSecondary),
                    filled: true,
                    fillColor: colors.surfaceSecondary,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: spacing.md,
                      vertical: spacing.sm,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(TFRadius.r8),
                      borderSide: BorderSide(color: colors.borderSubtle),
                    ),
                  ),
                  onSubmitted: (_) => _enviarMensagem(),
                ),
              ),
              SizedBox(width: spacing.sm),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.primaryForeground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(TFRadius.r8),
                  ),
                ),
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _editingComentario != null ? Icons.check : Icons.send,
                        size: 18,
                      ),
                tooltip: _editingComentario != null ? 'Salvar Edição' : 'Enviar',
                onPressed: _isSending ? null : _enviarMensagem,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageItem(
    BuildContext context, {
    required NotaSapComentario c,
    required bool isMe,
    required NotaSapComentario? replyMsg,
    required dynamic colors,
    required dynamic typography,
    required dynamic spacing,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: colors.primary.withAlpha(30),
                child: Text(
                  (c.usuarioNome != null && c.usuarioNome!.isNotEmpty)
                      ? c.usuarioNome![0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
              ),
              SizedBox(width: spacing.xs),
              Text(
                c.usuarioNome ?? 'Usuário',
                style: typography.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              SizedBox(width: spacing.sm),
              Text(
                _formatDate(c.createdAt),
                style: typography.caption.copyWith(
                  color: colors.textSecondary,
                  fontSize: 10.0,
                ),
              ),
              if (c.updatedAt != null && c.updatedAt != c.createdAt) ...[
                SizedBox(width: spacing.xs),
                Text(
                  '(editado)',
                  style: typography.caption.copyWith(
                    color: colors.textSecondary,
                    fontSize: 10.0,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.reply, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Responder',
                onPressed: () {
                  setState(() {
                    _replyingTo = c;
                    _editingComentario = null;
                  });
                },
              ),
              if (isMe) ...[
                SizedBox(width: spacing.sm),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Editar',
                  onPressed: () => _iniciarEdicao(c),
                ),
                SizedBox(width: spacing.sm),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: Colors.red.shade600,
                  tooltip: 'Excluir',
                  onPressed: () => _confirmarExclusao(c),
                ),
              ],
            ],
          ),
          SizedBox(height: spacing.xs * 0.5),

          if (replyMsg != null)
            Container(
              margin: EdgeInsets.only(left: 28, bottom: spacing.xs),
              padding: EdgeInsets.all(spacing.xs),
              decoration: BoxDecoration(
                color: colors.surfaceSecondary,
                borderRadius: BorderRadius.circular(TFRadius.r8),
                border: Border(left: BorderSide(color: colors.primary, width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    replyMsg.usuarioNome ?? 'Usuário',
                    style: typography.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 11.0,
                      color: colors.primary,
                    ),
                  ),
                  Text(
                    replyMsg.mensagem,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: typography.caption.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11.0,
                    ),
                  ),
                ],
              ),
            ),

          Container(
            margin: const EdgeInsets.only(left: 28),
            padding: EdgeInsets.all(spacing.md),
            decoration: BoxDecoration(
              color: isMe
                  ? colors.primary.withAlpha(15)
                  : colors.surface,
              borderRadius: BorderRadius.circular(TFRadius.r8),
              border: Border.all(
                color: isMe
                    ? colors.primary.withAlpha(50)
                    : colors.borderSubtle,
              ),
            ),
            child: SelectableText(
              c.mensagem,
              style: typography.bodyMedium.copyWith(
                color: colors.textPrimary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
