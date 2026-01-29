import 'package:flutter/material.dart';
import '../models/local.dart';
import '../models/regional.dart';
import '../models/divisao.dart';
import '../models/segmento.dart';
import '../services/regional_service.dart';
import '../services/divisao_service.dart';
import '../services/segmento_service.dart';
import 'form_dialog_helpers.dart';

class LocalFormDialog extends StatefulWidget {
  final Local? local;

  const LocalFormDialog({
    super.key,
    this.local,
  });

  @override
  State<LocalFormDialog> createState() => _LocalFormDialogState();
}

class _LocalFormDialogState extends State<LocalFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _localController;
  late TextEditingController _descricaoController;
  late TextEditingController _localInstalacaoSapController;
  
  final RegionalService _regionalService = RegionalService();
  final DivisaoService _divisaoService = DivisaoService();
  final SegmentoService _segmentoService = SegmentoService();
  
  List<Regional> _regionais = [];
  List<Divisao> _divisoes = [];
  List<Segmento> _segmentos = [];
  
  bool _isLoading = true;
  
  // Flags de associação
  bool _paraTodaRegional = false;
  bool _paraTodaDivisao = false;
  
  // Seleções específicas
  Regional? _selectedRegional;
  Divisao? _selectedDivisao;
  Segmento? _selectedSegmento;

  @override
  void initState() {
    super.initState();
    _localController = TextEditingController(
      text: widget.local?.local ?? '',
    );
    _descricaoController = TextEditingController(
      text: widget.local?.descricao ?? '',
    );
    _localInstalacaoSapController = TextEditingController(
      text: widget.local?.localInstalacaoSap ?? '',
    );
    
    if (widget.local != null) {
      _paraTodaRegional = widget.local!.paraTodaRegional;
      _paraTodaDivisao = widget.local!.paraTodaDivisao;
    }
    
    _loadData();
  }

  @override
  void dispose() {
    _localController.dispose();
    _descricaoController.dispose();
    _localInstalacaoSapController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final futures = await Future.wait([
        _regionalService.getAllRegionais(),
        _divisaoService.getAllDivisoes(),
        _segmentoService.getAllSegmentos(),
      ]);

      setState(() {
        _regionais = futures[0] as List<Regional>;
        _divisoes = futures[1] as List<Divisao>;
        _segmentos = futures[2] as List<Segmento>;
        _isLoading = false;

        if (widget.local != null) {
          if (widget.local!.regionalId != null && widget.local!.regionalId!.isNotEmpty) {
            _selectedRegional = _regionais.firstWhere(
              (r) => r.id == widget.local!.regionalId,
              orElse: () => _regionais.isNotEmpty ? _regionais.first : _regionais.first,
            );
          }
          if (widget.local!.divisaoId != null && widget.local!.divisaoId!.isNotEmpty) {
            _selectedDivisao = _divisoes.firstWhere(
              (d) => d.id == widget.local!.divisaoId,
              orElse: () => _divisoes.isNotEmpty ? _divisoes.first : _divisoes.first,
            );
          }
          if (widget.local!.segmentoId != null && widget.local!.segmentoId!.isNotEmpty) {
            _selectedSegmento = _segmentos.firstWhere(
              (s) => s.id == widget.local!.segmentoId,
              orElse: () => _segmentos.isNotEmpty ? _segmentos.first : _segmentos.first,
            );
          }
        }
      });
    } catch (e) {
      print('Erro ao carregar dados: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      if (!_paraTodaRegional && 
          !_paraTodaDivisao && 
          _selectedRegional == null && 
          _selectedDivisao == null && 
          _selectedSegmento == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione pelo menos uma associação (Toda Regional, Toda Divisão, ou uma associação específica)'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final local = Local(
        id: widget.local?.id ?? '',
        local: _localController.text.trim(),
        descricao: _descricaoController.text.trim().isEmpty
            ? null
            : _descricaoController.text.trim(),
        localInstalacaoSap: _localInstalacaoSapController.text.trim().isEmpty
            ? null
            : _localInstalacaoSapController.text.trim(),
        paraTodaRegional: _paraTodaRegional,
        paraTodaDivisao: _paraTodaDivisao,
        regionalId: _paraTodaRegional ? null : _selectedRegional?.id,
        divisaoId: _paraTodaDivisao ? null : _selectedDivisao?.id,
        segmentoId: _selectedSegmento?.id,
        createdAt: widget.local?.createdAt,
        updatedAt: DateTime.now(),
      );

      Navigator.of(context).pop(local);
    }
  }

  String _getRegionalDisplayText(Regional regional) {
    return '${regional.regional} - ${regional.divisao} - ${regional.empresa}';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.local != null;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 512),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1e293b) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditing ? 'Editar Local' : 'Novo Local',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Atualize as informações do local e suas associações.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FloatingLabelTextField(
                        label: 'Local *',
                        controller: _localController,
                        isDark: isDark,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Campo obrigatório';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      FloatingLabelTextField(
                        label: 'Descrição',
                        controller: _descricaoController,
                        isDark: isDark,
                        maxLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 24),
                      FloatingLabelTextField(
                        label: 'Local da Instalação SAP',
                        controller: _localInstalacaoSapController,
                        isDark: isDark,
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Associações',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFcbd5e1) : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1e293b).withOpacity(0.5) : const Color(0xFFf8fafc),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155).withOpacity(0.5) : const Color(0xFFe2e8f0),
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            CheckboxListTile(
                              title: Text(
                                'Para Toda Regional',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                                ),
                              ),
                              subtitle: Text(
                                'Aplica-se a todas as regionais',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b),
                                ),
                              ),
                              value: _paraTodaRegional,
                              activeColor: const Color(0xFF3b82f6),
                              onChanged: (value) {
                                setState(() {
                                  _paraTodaRegional = value ?? false;
                                  if (_paraTodaRegional) {
                                    _selectedRegional = null;
                                  }
                                });
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                            CheckboxListTile(
                              title: Text(
                                'Para Toda Divisão',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                                ),
                              ),
                              subtitle: Text(
                                'Aplica-se a todas as divisões',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b),
                                ),
                              ),
                              value: _paraTodaDivisao,
                              activeColor: const Color(0xFF3b82f6),
                              onChanged: (value) {
                                setState(() {
                                  _paraTodaDivisao = value ?? false;
                                  if (_paraTodaDivisao) {
                                    _selectedDivisao = null;
                                  }
                                });
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Associações Específicas',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFcbd5e1) : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : Column(
                              children: [
                                FloatingLabelDropdown<Regional>(
                                  label: 'Regional Específica',
                                  value: _selectedRegional,
                                  items: _regionais,
                                  isLoading: false,
                                  displayText: (regional) => _getRegionalDisplayText(regional),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedRegional = value;
                                    });
                                  },
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 24),
                                FloatingLabelDropdown<Divisao>(
                                  label: 'Divisão Específica',
                                  value: _selectedDivisao,
                                  items: _divisoes,
                                  isLoading: false,
                                  displayText: (divisao) => '${divisao.divisao} - ${divisao.regional}',
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedDivisao = value;
                                    });
                                  },
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 24),
                                FloatingLabelDropdown<Segmento>(
                                  label: 'Segmento Específico',
                                  value: _selectedSegmento,
                                  items: _segmentos,
                                  isLoading: false,
                                  displayText: (segmento) => segmento.segmento,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedSegmento = value;
                                    });
                                  },
                                  isDark: isDark,
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer com botões
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0f172a).withOpacity(0.5) : const Color(0xFFf8fafc),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    ),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3b82f6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      isEditing ? 'Salvar Alterações' : 'Criar Local',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
