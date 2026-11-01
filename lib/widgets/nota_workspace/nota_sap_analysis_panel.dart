import 'package:flutter/material.dart';
import '../../models/nota_sap.dart';
import '../../models/nota_sap_analise.dart';
import '../../services/nota_sap_analise_service.dart';
import 'nota_analise_badge.dart';
import '../nota_analise_workspace.dart';

enum AcaoAproveitamentoTexto {
  cancelar,
  adicionar,
  substituir,
}

/// Painel integrado ao [TaskFormDialog] para exibição e aproveitamento
/// opcional dos dados da análise técnica da(s) Nota(s) SAP vinculada(s).
class NotaSapAnalysisPanel extends StatefulWidget {
  final List<NotaSAP> notas;
  final String currentEscopo;
  final String currentObservacoes;
  final double? currentHoras;
  final ValueChanged<String>? onUsarEscopo;
  final ValueChanged<String>? onUsarDiagnostico;
  final ValueChanged<double>? onUsarEstimativa;
  final ValueChanged<NotaSAP>? onAbrirWorkspace;
  final NotaSapAnaliseService? analiseService;

  const NotaSapAnalysisPanel({
    super.key,
    required this.notas,
    this.currentEscopo = '',
    this.currentObservacoes = '',
    this.currentHoras,
    this.onUsarEscopo,
    this.onUsarDiagnostico,
    this.onUsarEstimativa,
    this.onAbrirWorkspace,
    this.analiseService,
  });

  @override
  State<NotaSapAnalysisPanel> createState() => _NotaSapAnalysisPanelState();
}

class _NotaSapAnalysisPanelState extends State<NotaSapAnalysisPanel> {
  late final NotaSapAnaliseService _analiseService;
  final Map<String, NotaSapAnalise?> _analises = {};
  final Map<String, NotaSapResumoAnalise?> _resumos = {};
  final Map<String, bool> _loading = {};
  final Map<String, String?> _erros = {};

  static const Color _primaryColor = Color(0xFF1E88E5);
  static const Color _warningColor = Color(0xFFF57C00);
  static const Color _successColor = Color(0xFF388E3C);

  @override
  void initState() {
    super.initState();
    _analiseService = widget.analiseService ?? NotaSapAnaliseService();
    _carregarAnalises();
  }

  @override
  void didUpdateWidget(covariant NotaSapAnalysisPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notas.length != widget.notas.length ||
        oldWidget.notas.map((n) => n.id).join() != widget.notas.map((n) => n.id).join()) {
      _carregarAnalises();
    }
  }

  Future<void> _carregarAnalises() async {
    for (final nota in widget.notas) {
      if (_analises.containsKey(nota.id) && _analises[nota.id] != null) continue;
      setState(() {
        _loading[nota.id] = true;
        _erros[nota.id] = null;
      });

      try {
        final analise = await _analiseService.buscarAnalise(nota.id);
        final resumos = await _analiseService.buscarResumoAnalises([nota.id]);
        if (mounted) {
          setState(() {
            _analises[nota.id] = analise;
            _resumos[nota.id] = resumos[nota.id];
            _loading[nota.id] = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _erros[nota.id] = 'Não foi possível carregar a análise.';
            _loading[nota.id] = false;
          });
        }
      }
    }
  }

  Future<void> _processarAproveitamentoTexto({
    required BuildContext context,
    required String titulo,
    required String campo,
    required String numeroNota,
    required String novoConteudo,
    required String conteudoAtual,
    required ValueChanged<String>? onAplicar,
  }) async {
    if (onAplicar == null) return;

    if (conteudoAtual.trim().isEmpty) {
      onAplicar(novoConteudo);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$campo preenchido com dados da análise técnica.'),
          backgroundColor: _primaryColor,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final acao = await showDialog<AcaoAproveitamentoTexto>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.help_outline, color: _warningColor),
            const SizedBox(width: 8),
            Expanded(child: Text(titulo)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'O campo "$campo" já possui conteúdo preenchido. Como deseja prosseguir?',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Conteúdo da análise:\n$novoConteudo',
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(AcaoAproveitamentoTexto.cancelar),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(AcaoAproveitamentoTexto.adicionar),
            child: const Text('Adicionar ao conteúdo atual'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(AcaoAproveitamentoTexto.substituir),
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            child: const Text('Substituir conteúdo'),
          ),
        ],
      ),
    );

    if (acao == null || acao == AcaoAproveitamentoTexto.cancelar) {
      return;
    }

    if (acao == AcaoAproveitamentoTexto.adicionar) {
      final separador = '\n\n--- Nota SAP $numeroNota ---\n';
      final resultado = '$conteudoAtual$separador$novoConteudo';
      onAplicar(resultado);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conteúdo adicionado ao campo $campo.'),
            backgroundColor: _successColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else if (acao == AcaoAproveitamentoTexto.substituir) {
      onAplicar(novoConteudo);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$campo substituído com sucesso.'),
            backgroundColor: _successColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _processarAproveitamentoHoras({
    required BuildContext context,
    required double horasEstimadas,
    required ValueChanged<double>? onAplicar,
  }) async {
    if (onAplicar == null) return;

    final horasAtuais = widget.currentHoras ?? 0.0;
    if (horasAtuais <= 0) {
      onAplicar(horasEstimadas);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Horas previstas atualizadas para ${horasEstimadas.toStringAsFixed(1)}h.'),
          backgroundColor: _primaryColor,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: _warningColor),
            SizedBox(width: 8),
            Expanded(child: Text('Substituir Horas Previstas')),
          ],
        ),
        content: Text(
          'A tarefa já possui ${horasAtuais.toStringAsFixed(1)}h previstas. Deseja substituir por ${horasEstimadas.toStringAsFixed(1)}h sugeridas pela análise técnica?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            child: const Text('Substituir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onAplicar(horasEstimadas);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Horas previstas substituídas por ${horasEstimadas.toStringAsFixed(1)}h.'),
            backgroundColor: _successColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.notas.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primaryColor.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: _primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Análise Prévia da Nota SAP',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF263238),
                ),
              ),
              const Spacer(),
              Text(
                '${widget.notas.length} vinculada${widget.notas.length > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...widget.notas.map((nota) => _buildNotaAnaliseCard(nota)),
        ],
      ),
    );
  }

  Widget _buildNotaAnaliseCard(NotaSAP nota) {
    final isLoading = _loading[nota.id] == true;
    final analise = _analises[nota.id];
    final resumo = _resumos[nota.id];
    final erro = _erros[nota.id];

    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              'Carregando análise da nota ${nota.nota}...',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (erro != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, size: 16, color: _warningColor),
            const SizedBox(width: 8),
            Text(erro, style: const TextStyle(fontSize: 12, color: _warningColor)),
            const Spacer(),
            TextButton(
              onPressed: _carregarAnalises,
              child: const Text('Tentar novamente', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    final temAnalise = analise != null && analise.statusAnalise != NotaAnaliseStatus.naoIniciada;
    final temEscopo = (analise?.escopoDetalhado ?? '').trim().isNotEmpty;
    final temDiagnostico = (analise?.diagnosticoPrevio ?? '').trim().isNotEmpty;
    final temHoras = (analise?.estimativaHoras ?? 0) > 0;
    final totalMateriais = resumo?.quantidadeMateriais ?? 0;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Nota ${nota.nota}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(width: 8),
              if (temAnalise && resumo != null)
                NotaAnaliseBadge(
                  compact: true,
                  resumo: resumo,
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Text(
                    'Sem análise técnica',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => widget.onAbrirWorkspace?.call(nota),
                icon: const Icon(Icons.open_in_new, size: 14),
                label: Text(
                  temAnalise ? 'Ver Workspace' : 'Iniciar Análise',
                  style: const TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),

          if (temAnalise) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (temEscopo)
                  ActionChip(
                    avatar: const Icon(Icons.copy, size: 14, color: _primaryColor),
                    label: const Text('Copiar Escopo', style: TextStyle(fontSize: 11)),
                    backgroundColor: _primaryColor.withValues(alpha: 0.08),
                    onPressed: () {
                      _processarAproveitamentoTexto(
                        context: context,
                        titulo: 'Aproveitar Escopo da Análise',
                        campo: 'Tarefa',
                        numeroNota: nota.nota,
                        novoConteudo: analise.escopoDetalhado!,
                        conteudoAtual: widget.currentEscopo,
                        onAplicar: widget.onUsarEscopo,
                      );
                    },
                  ),
                if (temDiagnostico)
                  ActionChip(
                    avatar: const Icon(Icons.notes, size: 14, color: _primaryColor),
                    label: const Text('Copiar Diagnóstico', style: TextStyle(fontSize: 11)),
                    backgroundColor: _primaryColor.withValues(alpha: 0.08),
                    onPressed: () {
                      _processarAproveitamentoTexto(
                        context: context,
                        titulo: 'Aproveitar Diagnóstico',
                        campo: 'Observações',
                        numeroNota: nota.nota,
                        novoConteudo: analise.diagnosticoPrevio!,
                        conteudoAtual: widget.currentObservacoes,
                        onAplicar: widget.onUsarDiagnostico,
                      );
                    },
                  ),
                if (temHoras)
                  ActionChip(
                    avatar: const Icon(Icons.schedule, size: 14, color: _primaryColor),
                    label: Text('Usar Horas: ${analise.estimativaHoras!.toStringAsFixed(1)}h', style: const TextStyle(fontSize: 11)),
                    backgroundColor: _primaryColor.withValues(alpha: 0.08),
                    onPressed: () {
                      _processarAproveitamentoHoras(
                        context: context,
                        horasEstimadas: analise.estimativaHoras!,
                        onAplicar: widget.onUsarEstimativa,
                      );
                    },
                  ),
                if (totalMateriais > 0)
                  Chip(
                    avatar: const Icon(Icons.inventory_2_outlined, size: 14, color: Colors.grey),
                    label: Text('$totalMateriais materiais previstos', style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.grey.shade50,
                  ),
              ],
            ),

            if (resumo != null && resumo.quantidadeAnexos > 0) ...[
              const SizedBox(height: 8),
              _buildCardCompactoAnexos(context, nota, resumo),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCardCompactoAnexos(
    BuildContext context,
    NotaSAP nota,
    NotaSapResumoAnalise resumo,
  ) {
    final total = resumo.quantidadeAnexos;

    final partes = <String>[];
    if (resumo.quantidadeImagens > 0) {
      partes.add('${resumo.quantidadeImagens} imag${resumo.quantidadeImagens > 1 ? 'ens' : 'em'}');
    }
    if (resumo.quantidadePdfs > 0) {
      partes.add('${resumo.quantidadePdfs} PDF${resumo.quantidadePdfs > 1 ? 's' : ''}');
    }
    if (resumo.quantidadeVideos > 0) {
      partes.add('${resumo.quantidadeVideos} vídeo${resumo.quantidadeVideos > 1 ? 's' : ''}');
    }
    if (resumo.quantidadePlanilhas > 0) {
      partes.add('${resumo.quantidadePlanilhas} planilha${resumo.quantidadePlanilhas > 1 ? 's' : ''}');
    }
    if (resumo.quantidadeDocumentos > 0) {
      partes.add('${resumo.quantidadeDocumentos} doc${resumo.quantidadeDocumentos > 1 ? 's' : ''}');
    }
    if (resumo.quantidadeAudios > 0) {
      partes.add('${resumo.quantidadeAudios} áudio${resumo.quantidadeAudios > 1 ? 's' : ''}');
    }
    if (resumo.quantidadeOutros > 0) {
      partes.add('${resumo.quantidadeOutros} outro${resumo.quantidadeOutros > 1 ? 's' : ''}');
    }

    final discriminacao = partes.isNotEmpty
        ? partes.join(' · ')
        : (total > 0 ? '$total arquivo(s)' : 'Nenhum anexo');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.attach_file, color: _primaryColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'ANEXOS E EVIDÊNCIAS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: _primaryColor,
                      ),
                    ),
                    if (resumo.quantidadeRelevantes > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '★ ${resumo.quantidadeRelevantes} relevante${resumo.quantidadeRelevantes > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '$total arquivo${total == 1 ? '' : 's'} • $discriminacao',
                  style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                ),
              ],
            ),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
            icon: const Icon(Icons.open_in_new, size: 13),
            label: const Text('Ver anexos', style: TextStyle(fontSize: 11)),
            onPressed: () {
              NotaAnaliseWorkspace.abrir(
                context,
                nota: nota,
                initialTab: 3, // Aba Anexos
              );
            },
          ),
        ],
      ),
    );
  }
}
