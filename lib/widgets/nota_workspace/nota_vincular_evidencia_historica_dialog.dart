import 'package:flutter/material.dart';
import '../../models/nota_sap.dart';
import '../../models/nota_sap_analise.dart';
import '../../models/nota_sap_analise_evidencia.dart';
import '../../services/nota_sap_analise_service.dart';

/// Diálogo contextual para vincular formalmente um anexo de Nota SAP histórica
/// como evidência em uma seção técnica da Nota SAP atual.
class NotaVincularEvidenciaHistoricaDialog extends StatefulWidget {
  final NotaSAP notaAtual;
  final NotaSapAnexo anexoHistorico;
  final String? numeroNotaHistorica;
  final NotaSapAnaliseService service;

  const NotaVincularEvidenciaHistoricaDialog({
    super.key,
    required this.notaAtual,
    required this.anexoHistorico,
    this.numeroNotaHistorica,
    required this.service,
  });

  static Future<bool?> exibir({
    required BuildContext context,
    required NotaSAP notaAtual,
    required NotaSapAnexo anexoHistorico,
    String? numeroNotaHistorica,
    required NotaSapAnaliseService service,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => NotaVincularEvidenciaHistoricaDialog(
        notaAtual: notaAtual,
        anexoHistorico: anexoHistorico,
        numeroNotaHistorica: numeroNotaHistorica,
        service: service,
      ),
    );
  }

  @override
  State<NotaVincularEvidenciaHistoricaDialog> createState() =>
      _NotaVincularEvidenciaHistoricaDialogState();
}

class _NotaVincularEvidenciaHistoricaDialogState
    extends State<NotaVincularEvidenciaHistoricaDialog> {
  NotaTipoVinculoEvidencia _secaoSelecionada = NotaTipoVinculoEvidencia.diagnostico;
  bool _usarVersaoAnotada = false;
  final _obsController = TextEditingController();
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    // Se tiver anotação, usuário pode optar
    _usarVersaoAnotada = widget.anexoHistorico.possuiAnotacao;
  }

  @override
  void dispose() {
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _confirmarVinculo() async {
    if (_salvando) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });

    try {
      final anexo = widget.anexoHistorico;
      if (anexo.id == null) throw ArgumentError('ID do anexo inválido.');

      final versaoFinal = (_usarVersaoAnotada && anexo.possuiAnotacao)
          ? anexo.versaoAnotacao
          : null;

      final obs = _obsController.text.trim();

      await widget.service.vincularEvidencia(
        notaSapId: widget.notaAtual.id,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
        anexoId: anexo.id!,
        tipoVinculo: _secaoSelecionada,
        anotacaoVersao: versaoFinal,
        observacao: obs.isEmpty ? null : obs,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _salvando = false;
          _erro = e.toString().replaceAll('Exception:', '').replaceAll('ArgumentError:', '').trim();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numNotaOrigem = widget.numeroNotaHistorica ?? widget.anexoHistorico.notaSapId;
    final temAnotacao = widget.anexoHistorico.possuiAnotacao;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.history_edu,
                      color: Color(0xFF0F766E),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Vincular Evidência Histórica',
                          style: TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Origem: Nota SAP $numNotaOrigem • Arquivo: ${widget.anexoHistorico.nomeExibicao}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 18),

              // Aviso contextual de semântica referencial (zero storage copy)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Esta evidência é referencial: o arquivo permanece na Nota original sem duplicação no Storage.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 1. Seção da Análise Técnica
              const Text(
                'Seção Técnica da Análise:',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: NotaTipoVinculoEvidencia.values.map((tipo) {
                  final selecionado = _secaoSelecionada == tipo;
                  return ChoiceChip(
                    label: Text(tipo.label),
                    selected: selecionado,
                    onSelected: (val) {
                      if (val) setState(() => _secaoSelecionada = tipo);
                    },
                    selectedColor: const Color(0xFF0F766E).withAlpha(50),
                    labelStyle: TextStyle(
                      fontSize: 12.0,
                      fontWeight: selecionado ? FontWeight.bold : FontWeight.normal,
                      color: selecionado
                          ? const Color(0xFF0F766E)
                          : theme.colorScheme.onSurface,
                    ),
                  );
                }).toList(),
              ),

              // 2. Seletor de Versão (se houver anotação)
              if (temAnotacao) ...[
                const SizedBox(height: 18),
                const Text(
                  'Representação do Anexo:',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _usarVersaoAnotada = false),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: !_usarVersaoAnotada
                                  ? const Color(0xFF0F766E)
                                  : Colors.grey.shade300,
                              width: !_usarVersaoAnotada ? 2 : 1,
                            ),
                            color: !_usarVersaoAnotada
                                ? const Color(0xFF0F766E).withAlpha(20)
                                : Colors.transparent,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                !_usarVersaoAnotada
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                size: 18,
                                color: !_usarVersaoAnotada
                                    ? const Color(0xFF0F766E)
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              const Text('Original puro', style: TextStyle(fontSize: 12.5)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _usarVersaoAnotada = true),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _usarVersaoAnotada
                                  ? const Color(0xFF0F766E)
                                  : Colors.grey.shade300,
                              width: _usarVersaoAnotada ? 2 : 1,
                            ),
                            color: _usarVersaoAnotada
                                ? const Color(0xFF0F766E).withAlpha(20)
                                : Colors.transparent,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _usarVersaoAnotada
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                size: 18,
                                color: _usarVersaoAnotada
                                    ? const Color(0xFF0F766E)
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Anotado (v${widget.anexoHistorico.versaoAnotacao})',
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 18),

              // 3. Justificativa / Observação Técnica
              const Text(
                'Observação / Justificativa Técnica (opcional):',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _obsController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Ex: Mostra a corrosão original na sapata da torre em 2024...',
                  hintStyle: const TextStyle(fontSize: 12.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                style: const TextStyle(fontSize: 13.0),
              ),

              if (_erro != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _erro!,
                          style: TextStyle(color: Colors.red.shade900, fontSize: 12.0),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Ações
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _salvando ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _salvando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: Text(_salvando ? 'Vinculando...' : 'Confirmar Vínculo'),
                    onPressed: _salvando ? null : _confirmarVinculo,
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
