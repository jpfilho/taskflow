import 'package:flutter/material.dart';
import '../models/empresa.dart';
import '../models/regional.dart';
import '../models/divisao.dart';
import '../services/regional_service.dart';
import '../services/divisao_service.dart';
import 'form_dialog_helpers.dart';

class EmpresaFormDialog extends StatefulWidget {
  final Empresa? empresa;

  const EmpresaFormDialog({
    super.key,
    this.empresa,
  });

  @override
  State<EmpresaFormDialog> createState() => _EmpresaFormDialogState();
}

class _EmpresaFormDialogState extends State<EmpresaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _empresaController;
  final RegionalService _regionalService = RegionalService();
  final DivisaoService _divisaoService = DivisaoService();
  List<Regional> _regionais = [];
  List<Divisao> _divisoes = [];
  Regional? _selectedRegional;
  Divisao? _selectedDivisao;
  String _selectedTipo = 'PROPRIA';
  bool _isLoadingRegionais = true;
  bool _isLoadingDivisoes = true;

  @override
  void initState() {
    super.initState();
    _empresaController = TextEditingController(
      text: widget.empresa?.empresa ?? '',
    );
    _selectedTipo = widget.empresa?.tipo ?? 'PROPRIA';
    _loadRegionais();
  }

  @override
  void dispose() {
    _empresaController.dispose();
    super.dispose();
  }

  Future<void> _loadRegionais() async {
    setState(() {
      _isLoadingRegionais = true;
    });

    try {
      final regionais = await _regionalService.getAllRegionais();
      setState(() {
        _regionais = regionais;
        _isLoadingRegionais = false;

        if (widget.empresa != null && widget.empresa!.regionalId.isNotEmpty) {
          _selectedRegional = regionais.firstWhere(
            (r) => r.id == widget.empresa!.regionalId,
            orElse: () => regionais.isNotEmpty ? regionais.first : regionais.first,
          );
          _loadDivisoes();
        } else if (regionais.isNotEmpty) {
          _selectedRegional = regionais.first;
          _loadDivisoes();
        }
      });
    } catch (e) {
      print('Erro ao carregar regionais: $e');
      setState(() {
        _isLoadingRegionais = false;
      });
    }
  }

  Future<void> _loadDivisoes() async {
    if (_selectedRegional == null) return;

    setState(() {
      _isLoadingDivisoes = true;
    });

    try {
      final divisoes = await _divisaoService.getAllDivisoes();
      final divisoesFiltradas = divisoes
          .where((d) => d.regionalId == _selectedRegional!.id)
          .toList();

      setState(() {
        _divisoes = divisoesFiltradas;
        _isLoadingDivisoes = false;

        if (widget.empresa != null && widget.empresa!.divisaoId.isNotEmpty) {
          _selectedDivisao = divisoesFiltradas.firstWhere(
            (d) => d.id == widget.empresa!.divisaoId,
            orElse: () => divisoesFiltradas.isNotEmpty
                ? divisoesFiltradas.first
                : divisoesFiltradas.first,
          );
        } else if (divisoesFiltradas.isNotEmpty) {
          _selectedDivisao = divisoesFiltradas.first;
        } else {
          _selectedDivisao = null;
        }
      });
    } catch (e) {
      print('Erro ao carregar divisões: $e');
      setState(() {
        _isLoadingDivisoes = false;
      });
    }
  }

  void _onRegionalChanged(Regional? regional) {
    setState(() {
      _selectedRegional = regional;
      _selectedDivisao = null;
    });
    _loadDivisoes();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      if (_selectedRegional == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione uma regional.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_selectedDivisao == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione uma divisão.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final empresa = Empresa(
        id: widget.empresa?.id ?? '',
        empresa: _empresaController.text.trim(),
        regionalId: _selectedRegional!.id,
        divisaoId: _selectedDivisao!.id,
        tipo: _selectedTipo,
      );

      Navigator.of(context).pop(empresa);
    }
  }

  String _getRegionalDisplayText(Regional regional) {
    return '${regional.regional} - ${regional.divisao} - ${regional.empresa}';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.empresa != null;
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
                    isEditing ? 'Editar Empresa' : 'Nova Empresa',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Atualize as informações da empresa.',
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
                        label: 'Nome da Empresa *',
                        controller: _empresaController,
                        isDark: isDark,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Campo obrigatório';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      FloatingLabelDropdown<Regional>(
                        label: 'Regional *',
                        value: _selectedRegional,
                        items: _regionais,
                        isLoading: _isLoadingRegionais,
                        displayText: (regional) => _getRegionalDisplayText(regional),
                        onChanged: _onRegionalChanged,
                        isDark: isDark,
                        validator: (value) {
                          if (value == null) {
                            return 'Selecione uma regional';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      FloatingLabelDropdown<Divisao>(
                        label: 'Divisão *',
                        value: _selectedDivisao,
                        items: _divisoes,
                        isLoading: _isLoadingDivisoes,
                        displayText: (divisao) => divisao.divisao,
                        onChanged: (divisao) {
                          setState(() {
                            _selectedDivisao = divisao;
                          });
                        },
                        isDark: isDark,
                        validator: (value) {
                          if (value == null) {
                            return 'Selecione uma divisão';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      FloatingLabelDropdown<String>(
                        label: 'Tipo *',
                        value: _selectedTipo,
                        items: const ['PROPRIA', 'TERCEIRA'],
                        isLoading: false,
                        displayText: (tipo) => tipo == 'PROPRIA' ? 'Própria' : 'Terceira',
                        onChanged: (tipo) {
                          setState(() {
                            _selectedTipo = tipo!;
                          });
                        },
                        isDark: isDark,
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
                      isEditing ? 'Salvar Alterações' : 'Criar Empresa',
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
