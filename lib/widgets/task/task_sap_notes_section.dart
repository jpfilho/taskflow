import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/nota_sap.dart';
import '../../models/nota_sap_analise.dart';
import '../../models/task.dart';
import '../../services/nota_sap_analise_service.dart';
import '../nota_analise_workspace.dart';
import '../nota_workspace/nota_analise_badge.dart';

/// Seção canônica para exibição e consulta das Notas SAP vinculadas e suas respectivas
/// análises técnicas dentro da visualização da tarefa ([TaskViewDialog] / Mobile / Web).
class TaskSapNotesSection extends StatefulWidget {
  final List<NotaSAP> notasSAP;
  final Task task;
  final NotaSapAnaliseService? analiseService;
  final bool readOnly;

  const TaskSapNotesSection({
    super.key,
    required this.notasSAP,
    required this.task,
    this.analiseService,
    this.readOnly = true,
  });

  @override
  State<TaskSapNotesSection> createState() => _TaskSapNotesSectionState();
}

class _TaskSapNotesSectionState extends State<TaskSapNotesSection> {
  late final NotaSapAnaliseService _analiseService;

  final Map<String, NotaSapResumoAnalise> _resumos = {};
  final Map<String, NotaSapAnalise?> _analisesCompletas = {};
  final Map<String, List<NotaSapMaterial>> _materiais = {};
  final Map<String, List<NotaSapAnexo>> _anexos = {};
  final Map<String, List<NotaSapComentario>> _comentarios = {};

  final Map<String, bool> _loadingNota = {};
  final Map<String, String?> _errosNota = {};
  bool _loadingResumos = true;
  String? _erroGeral;

  static const Color _primaryNavy = Color(0xFF1E3A5F);
  static const Color _accentBlue = Color(0xFF1E88E5);

  @override
  void initState() {
    super.initState();
    _analiseService = widget.analiseService ?? NotaSapAnaliseService();
    _carregarResumos();
  }

  @override
  void didUpdateWidget(covariant TaskSapNotesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notasSAP.length != widget.notasSAP.length ||
        oldWidget.notasSAP.map((n) => n.id).join() !=
            widget.notasSAP.map((n) => n.id).join()) {
      _carregarResumos();
    }
  }

  Future<void> _carregarResumos({bool forceRefresh = false}) async {
    if (widget.notasSAP.isEmpty) {
      if (mounted) setState(() => _loadingResumos = false);
      return;
    }

    setState(() {
      _loadingResumos = true;
      _erroGeral = null;
    });

    try {
      final ids = widget.notasSAP.map((n) => n.id).toList();
      final resumos = await _analiseService.buscarResumoAnalises(
        ids,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _resumos.addAll(resumos);
          _loadingResumos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erroGeral = 'Não foi possível carregar os indicadores técnicos.';
          _loadingResumos = false;
        });
      }
    }
  }

  Future<void> _carregarDetalhesNota(String notaId) async {
    if (_analisesCompletas.containsKey(notaId)) return;

    setState(() {
      _loadingNota[notaId] = true;
      _errosNota[notaId] = null;
    });

    try {
      final analise = await _analiseService.buscarAnalise(notaId);
      final materiais = await _analiseService.listarMateriais(notaId);
      final anexos = await _analiseService.listarAnexos(notaId);
      final comentarios = await _analiseService.listarComentarios(notaId);

      if (mounted) {
        setState(() {
          _analisesCompletas[notaId] = analise;
          _materiais[notaId] = materiais;
          _anexos[notaId] = anexos;
          _comentarios[notaId] = comentarios;
          _loadingNota[notaId] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errosNota[notaId] = 'Erro ao carregar detalhes técnicos da nota: $e';
          _loadingNota[notaId] = false;
        });
      }
    }
  }

  Future<void> _abrirWorkspace(NotaSAP nota, {int initialTab = 0}) async {
    await NotaAnaliseWorkspace.abrir(
      context,
      nota: nota,
      listaNotas: widget.notasSAP,
      initialTab: initialTab,
      readOnly: widget.readOnly,
      service: _analiseService,
    );

    // Atualização cirúrgica da nota após fechar o workspace
    try {
      final novoResumo = await _analiseService.buscarResumoAnalises(
        [nota.id],
        forceRefresh: true,
      );
      final analise = await _analiseService.buscarAnalise(nota.id);
      final materiais = await _analiseService.listarMateriais(nota.id);
      final anexos = await _analiseService.listarAnexos(nota.id);
      final comentarios = await _analiseService.listarComentarios(nota.id);

      if (mounted) {
        setState(() {
          if (novoResumo.containsKey(nota.id)) {
            _resumos[nota.id] = novoResumo[nota.id]!;
          }
          _analisesCompletas[nota.id] = analise;
          _materiais[nota.id] = materiais;
          _anexos[nota.id] = anexos;
          _comentarios[nota.id] = comentarios;
        });
      }
    } catch (_) {}
  }

  void _visualizarAnexo(NotaSapAnexo anexo) {
    if (anexo.tipoArquivo == NotaAnexoTipo.imagem) {
      final url = _analiseService.obterUrlAnexo(anexo);
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.black.withAlpha(235),
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Center(
                child: PhotoView(
                  imageProvider: NetworkImage(url),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3.0,
                  initialScale: PhotoViewComputedScale.contained,
                  loadingBuilder: (context, event) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Text(
                      'Não foi possível carregar a imagem.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
              if (anexo.legenda != null && anexo.legenda!.isNotEmpty)
                Positioned(
                  bottom: 24,
                  left: 24,
                  right: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      anexo.legenda!,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    } else {
      _analiseService.obterUrlAssinada(anexo).then((url) async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Não foi possível abrir o documento.')),
            );
          }
        }
      }).catchError((e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao abrir documento: $e')),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.notasSAP.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.description, size: 18, color: _primaryNavy),
            const SizedBox(width: 8),
            const Text(
              'NOTAS SAP VINCULADAS',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _primaryNavy,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _primaryNavy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${widget.notasSAP.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _primaryNavy,
                ),
              ),
            ),
            const Spacer(),
            if (_loadingResumos)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh, size: 18, color: Colors.grey),
                tooltip: 'Atualizar análise técnica',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _carregarResumos(forceRefresh: true),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_erroGeral != null)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.amber.shade800, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _erroGeral!,
                    style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                  ),
                ),
              ],
            ),
          ),
        ...widget.notasSAP.map((nota) => _buildNotaCard(nota)),
      ],
    );
  }

  Widget _buildNotaCard(NotaSAP nota) {
    final resumo = _resumos[nota.id];
    final temAnalise = resumo != null &&
        resumo.status != NotaAnaliseStatus.naoIniciada;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
          onExpansionChanged: (expanded) {
            if (expanded) {
              _carregarDetalhesNota(nota.id);
            }
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _primaryNavy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.assignment_outlined,
                color: _primaryNavy, size: 20),
          ),
          title: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Nota SAP ${nota.nota}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _primaryNavy,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  'Origem: Nota SAP ${nota.nota}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              if (resumo != null)
                NotaAnaliseBadge(
                  compact: true,
                  resumo: resumo,
                  onTapStatus: () => _abrirWorkspace(nota, initialTab: 1),
                  onTapMateriais: () => _abrirWorkspace(nota, initialTab: 2),
                  onTapAnexos: () => _abrirWorkspace(nota, initialTab: 3),
                  onTapComentarios: () => _abrirWorkspace(nota, initialTab: 4),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Análise técnica: Não iniciada',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              nota.descricao ?? 'Sem descrição cadastrada',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          children: [
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            const SizedBox(height: 12),
            _buildDetalhesExpandidos(nota, temAnalise),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _abrirWorkspace(nota, initialTab: 0),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(temAnalise ? 'Ver Nota e Análise' : 'Ver Nota SAP'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _accentBlue,
                    side: const BorderSide(color: _accentBlue),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildDetalhesExpandidos(NotaSAP nota, bool temAnalise) {
    final isLoading = _loadingNota[nota.id] == true;
    final erro = _errosNota[nota.id];

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text(
                'Carregando dados da análise técnica...',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (erro != null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(erro, style: TextStyle(color: Colors.red.shade800, fontSize: 12)),
      );
    }

    final analise = _analisesCompletas[nota.id];
    final materiais = _materiais[nota.id] ?? [];
    final anexos = _anexos[nota.id] ?? [];
    final comentarios = _comentarios[nota.id] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (analise != null && temAnalise) ...[
          // Bloco Escopo Sugerido na Análise (Diferenciado explicitamente)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.psychology, size: 16, color: Colors.blue.shade800),
                    const SizedBox(width: 6),
                    Text(
                      'ESCOPO SUGERIDO NA ANÁLISE DA NOTA',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Sugestão técnica',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  (analise.escopoDetalhado != null &&
                          analise.escopoDetalhado!.trim().isNotEmpty)
                      ? analise.escopoDetalhado!
                      : 'Nenhum escopo detalhado registrado na análise.',
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Bloco Diagnóstico Prévio da Nota
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.notes, size: 16, color: Colors.amber.shade900),
                    const SizedBox(width: 6),
                    Text(
                      'DIAGNÓSTICO PRÉVIO DA NOTA',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  (analise.diagnosticoPrevio != null &&
                          analise.diagnosticoPrevio!.trim().isNotEmpty)
                      ? analise.diagnosticoPrevio!
                      : 'Nenhum diagnóstico registrado.',
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Requisitos operacionais e planejamento
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildInfoChip(
                icon: Icons.person_outline,
                label: 'Analista',
                value: analise.analistaNome ?? 'Não informado',
              ),
              if (analise.quantidadeTecnicos != null)
                _buildInfoChip(
                  icon: Icons.groups_outlined,
                  label: 'Qtd. Técnicos',
                  value: '${analise.quantidadeTecnicos}',
                ),
              _buildInfoChip(
                icon: Icons.schedule_outlined,
                label: 'Estimativa',
                value: analise.estimativaHoras != null
                    ? '${analise.estimativaHoras!.toStringAsFixed(1)}h'
                    : 'Não informada',
              ),
              _buildInfoChip(
                icon: Icons.power_off_outlined,
                label: 'Desligamento',
                value: analise.necessitaDesligamento == true ? 'Sim' : 'Não',
                highlight: analise.necessitaDesligamento == true,
              ),
              if (analise.valorPv != null && analise.valorPv! > 0)
                _buildInfoChip(
                  icon: Icons.attach_money,
                  label: 'Parcela Variável (PV)',
                  value: 'R\$ ${analise.valorPv!.toStringAsFixed(2)}',
                  highlight: true,
                )
              else if (analise.necessitaBloqueio == true)
                _buildInfoChip(
                  icon: Icons.lock_outline,
                  label: 'Bloqueio / LOTO',
                  value: 'Sim',
                  highlight: true,
                ),
            ],
          ),
          const SizedBox(height: 14),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Esta Nota SAP ainda não possui análise técnica prévia cadastrada.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Subseção Materiais Levantados
        _buildSubsecaoMateriais(nota, materiais),
        const SizedBox(height: 10),

        // Subseção Anexos da Nota
        _buildSubsecaoAnexos(nota, anexos),
        const SizedBox(height: 10),

        // Subseção Discussão Técnica da Nota
        _buildSubsecaoDiscussao(nota, comentarios),
      ],
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight ? Colors.red.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight ? Colors.red.shade300 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: highlight ? Colors.red.shade700 : _primaryNavy,
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: highlight ? Colors.red.shade900 : Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: highlight ? Colors.red.shade900 : _primaryNavy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubsecaoMateriais(NotaSAP nota, List<NotaSapMaterial> materiais) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
        title: Row(
          children: [
            const Icon(Icons.inventory_2_outlined, size: 16, color: _primaryNavy),
            const SizedBox(width: 8),
            const Text(
              'Materiais Levantados',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${materiais.length}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          if (materiais.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nenhum material levantado na análise técnica.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.blueGrey),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Materiais levantados no planejamento técnico (não implica reserva física).',
                      style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                    ),
                  ),
                ],
              ),
            ),
            ...materiais.map((mat) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          mat.codigoSap ?? 'S/ Cód.',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          mat.descricao,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${mat.quantidade} ${mat.unidade}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _primaryNavy,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
      ),
    );
  }

  Widget _buildSubsecaoAnexos(NotaSAP nota, List<NotaSapAnexo> anexos) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
        title: Row(
          children: [
            const Icon(Icons.attach_file, size: 16, color: _primaryNavy),
            const SizedBox(width: 8),
            const Text(
              'Anexos da Nota SAP',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${anexos.length}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          if (anexos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nenhum anexo registrado nesta Nota SAP.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: anexos.map((anexo) {
                final isImg = anexo.tipoArquivo == NotaAnexoTipo.imagem;
                return InkWell(
                  onTap: () => _visualizarAnexo(anexo),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 140,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isImg
                              ? Icons.image_outlined
                              : Icons.picture_as_pdf_outlined,
                          size: 28,
                          color: isImg ? Colors.teal : Colors.red.shade700,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          anexo.nomeArquivo,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubsecaoDiscussao(
      NotaSAP nota, List<NotaSapComentario> comentarios) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
        title: Row(
          children: [
            const Icon(Icons.forum_outlined, size: 16, color: _primaryNavy),
            const SizedBox(width: 8),
            const Text(
              'Discussão Técnica da Nota SAP',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${comentarios.length}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              children: [
                Icon(Icons.chat_bubble_outline, size: 14, color: Colors.grey),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Histórico técnico da Nota SAP (independente do chat da tarefa).',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          if (comentarios.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nenhum comentário na análise técnica.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            )
          else
            ...comentarios.map((c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              c.usuarioNome ?? 'Usuário',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _primaryNavy,
                              ),
                            ),
                            const Spacer(),
                            if (c.createdAt != null)
                              Text(
                                '${c.createdAt!.day.toString().padLeft(2, '0')}/${c.createdAt!.month.toString().padLeft(2, '0')} ${c.createdAt!.hour.toString().padLeft(2, '0')}:${c.createdAt!.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(c.mensagem, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                )),
        ],
      ),
      ),
    );
  }
}
