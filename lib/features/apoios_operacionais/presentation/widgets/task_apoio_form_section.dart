import 'package:flutter/material.dart';
import '../../../../design_system/taskflow_design_system.dart';
import '../../domain/enums/task_apoio_enums.dart';
import '../../domain/models/task_apoio_impacto_alteracao.dart';
import '../../domain/models/task_apoio_solicitacao.dart';
import '../../domain/models/task_apoio_vinculo.dart';
import '../task_apoio_ui_controller.dart';
import 'task_apoio_banner_estado.dart';

/// Seção opcional e recolhível "Apoios Operacionais" para o `TaskFormDialog` (Itens 7, 8, 24).
/// Não torna obrigatório o cadastro de apoios e não bloqueia o salvamento da atividade.
class TaskApoioFormSection extends StatefulWidget {
  final TaskApoioUiController controller;
  final String? taskId;
  final List<TaskApoioSolicitacao> rascunhosLocais;
  final TaskApoioImpactoAlteracao? impactoAlteracao;
  final VoidCallback onSolicitarApoio;
  final VoidCallback? onVincularExistente;
  final void Function(TaskApoioSolicitacao rascunho)? onEditarRascunho;
  final void Function(TaskApoioSolicitacao rascunho)? onRemoverRascunho;
  final void Function(TaskApoioSolicitacao sol)? onCancelarSolicitacao;
  final void Function(TaskApoioVinculo vinculo)? onDesvincular;
  final VoidCallback? onVerDetalhes;

  const TaskApoioFormSection({
    super.key,
    required this.controller,
    this.taskId,
    this.rascunhosLocais = const [],
    this.impactoAlteracao,
    required this.onSolicitarApoio,
    this.onVincularExistente,
    this.onEditarRascunho,
    this.onRemoverRascunho,
    this.onCancelarSolicitacao,
    this.onDesvincular,
    this.onVerDetalhes,
  });

  @override
  State<TaskApoioFormSection> createState() => _TaskApoioFormSectionState();
}

class _TaskApoioFormSectionState extends State<TaskApoioFormSection> {
  bool _expandido = false;
  bool _carregando = false;
  String? _erro;
  List<TaskApoioSolicitacao> _solicitacoes = const [];
  List<TaskApoioVinculo> _vinculos = const [];

  @override
  void initState() {
    super.initState();
    if (widget.taskId != null && !widget.controller.isBackendProtegido) {
      _carregar();
    }
  }

  @override
  void didUpdateWidget(covariant TaskApoioFormSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskId != widget.taskId ||
        oldWidget.controller.disponibilidade !=
            widget.controller.disponibilidade) {
      if (widget.taskId != null && !widget.controller.isBackendProtegido) {
        _carregar();
      }
    }
  }

  Future<void> _carregar() async {
    final id = widget.taskId;
    if (id == null) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final (sols, vincs) =
          await widget.controller.carregarDetalhesParaTask(id);
      if (!mounted) return;
      setState(() {
        _solicitacoes = sols;
        _vinculos = vincs;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typo = context.tfTypography;
    final total = _solicitacoes.length + widget.rascunhosLocais.length;
    final confirmados =
        _solicitacoes.where((s) => s.status == TaskApoioStatus.aceita).length;
    final pendentes = _solicitacoes
            .where(
              (s) =>
                  s.status == TaskApoioStatus.pendente ||
                  s.status == TaskApoioStatus.emAnalise ||
                  s.status == TaskApoioStatus.contraproposta,
            )
            .length +
        widget.rascunhosLocais.length;

    return TFCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expandido = !_expandido),
            child: Row(
              children: [
                Icon(Icons.handshake_outlined, size: 20, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Apoios Operacionais (opcional)',
                        style: typo.labelMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        total == 0 && _vinculos.isEmpty
                            ? 'Nenhum apoio vinculado ou solicitado'
                            : '$total solicitação(ões) • $confirmados confirmado(s) • $pendentes pendente(s)',
                        style: typo.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.impactoAlteracao != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: TFStatusBadge(
                      label: 'Impacto detectado',
                      severity: TFStatusSeverity.warning,
                      icon: Icons.warning_amber_rounded,
                      compact: true,
                    ),
                  ),
                Icon(_expandido ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),

          if (widget.impactoAlteracao != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: colors.warningBackground,
                borderRadius: TFRadius.borderRadiusSm,
                border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: colors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'A alteração desta atividade poderá comprometer ${widget.impactoAlteracao!.solicitacoesAfetadasIds.length} apoio(s) operacional(is) vinculado(s).',
                      style: typo.bodySmall.copyWith(color: colors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_expandido) ...[
            const Divider(height: 16),
            TaskApoioBannerEstado(
              estado: widget.controller.disponibilidade,
              mensagemErro: _erro,
              onAtivarDemo: widget.controller.isModoDemonstracao
                  ? null
                  : () async {
                      await widget.controller.ativarModoDemonstracaoDev();
                      if (widget.taskId != null) await _carregar();
                    },
            ),
            const SizedBox(height: 10),
            if (_carregando)
              const LinearProgressIndicator()
            else ...[
              // Rascunhos locais pré-salvamento (Item 8)
              for (final rasc in widget.rascunhosLocais)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: TFCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rasc.descricao,
                                style: typo.labelSmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Rascunho — será enviado após salvar a atividade',
                                style: typo.bodySmall.copyWith(
                                  color: colors.info,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.onEditarRascunho != null)
                          IconButton(
                            tooltip: 'Editar rascunho',
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => widget.onEditarRascunho!(rasc),
                          ),
                        if (widget.onRemoverRascunho != null)
                          IconButton(
                            tooltip: 'Remover rascunho',
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => widget.onRemoverRascunho!(rasc),
                          ),
                      ],
                    ),
                  ),
                ),

              // Solicitações já registradas
              for (final sol in _solicitacoes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '• ${sol.descricao} (${sol.status.label})',
                          style: typo.bodySmall,
                        ),
                      ),
                      if (sol.status.isAtiva &&
                          widget.onCancelarSolicitacao != null)
                        TextButton(
                          onPressed: () => widget.onCancelarSolicitacao!(sol),
                          child: const Text('Cancelar'),
                        ),
                    ],
                  ),
                ),

              // Vínculos existentes
              for (final vinc in _vinculos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '• Vínculo: ${vinc.taskApoioTituloSnapshot} (${vinc.finalidade.label})',
                          style: typo.bodySmall,
                        ),
                      ),
                      if (vinc.ativo && widget.onDesvincular != null)
                        TextButton(
                          onPressed: () => widget.onDesvincular!(vinc),
                          child: const Text('Desvincular'),
                        ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TFButton(
                  label: 'Solicitar apoio',
                  size: TFButtonSize.small,
                  variant: TFButtonVariant.secondary,
                  leadingIcon: Icons.add_rounded,
                  onPressed: widget.onSolicitarApoio,
                ),
                if (widget.onVincularExistente != null)
                  TFButton(
                    label: 'Vincular atividade existente',
                    size: TFButtonSize.small,
                    variant: TFButtonVariant.tertiary,
                    leadingIcon: Icons.link_rounded,
                    onPressed: widget.onVincularExistente,
                  ),
                if (widget.onVerDetalhes != null &&
                    (_solicitacoes.isNotEmpty || _vinculos.isNotEmpty))
                  TFButton(
                    label: 'Consultar detalhes',
                    size: TFButtonSize.small,
                    variant: TFButtonVariant.ghost,
                    onPressed: widget.onVerDetalhes,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
