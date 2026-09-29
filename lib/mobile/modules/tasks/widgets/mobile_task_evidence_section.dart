import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/tf_mobile_spacing.dart';
import '../../../core/theme/tf_mobile_typography.dart';
import '../../../core/theme/tf_mobile_colors.dart';
import '../../../core/widgets/tf_mobile_buttons.dart';
import '../models/mobile_task_detail_view_model.dart';

/// Seção de Evidências Fotográficas da Atividade.
/// Permite capturar fotos de campo, selecionar da galeria e acompanhar
/// o status de envio offline/sincronizado sem alterar a compressão técnica.
class MobileTaskEvidenceSection extends StatefulWidget {
  final List<MobileEvidenceItem> evidences;
  final Future<void> Function(XFile file) onAddPhoto;
  final bool isReadOnly;

  const MobileTaskEvidenceSection({
    super.key,
    required this.evidences,
    required this.onAddPhoto,
    this.isReadOnly = false,
  });

  @override
  State<MobileTaskEvidenceSection> createState() => _MobileTaskEvidenceSectionState();
}

class _MobileTaskEvidenceSectionState extends State<MobileTaskEvidenceSection> {
  final ImagePicker _picker = ImagePicker();
  bool _isCapturing = false;

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() => _isCapturing = true);
      HapticFeedback.lightImpact();

      // Compressão preservada no padrão auditado do TaskFlow (quality: 85)
      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (photo != null) {
        await widget.onAddPhoto(photo);
      }
    } catch (e) {
      debugPrint('⚠️ [MobileTaskEvidenceSection] Erro ao capturar imagem: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha ao capturar imagem: $e'),
            backgroundColor: TFMobileColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: TFMobileSpacing.lg, vertical: TFMobileSpacing.xs),
      padding: const EdgeInsets.all(TFMobileSpacing.lg),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.camera_alt_outlined, size: 20.0, color: Color(0xFF3B82F6)),
              const SizedBox(width: TFMobileSpacing.sm),
              Expanded(
                child: Text(
                  'Evidências Fotográficas (${widget.evidences.length})',
                  style: TFMobileTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: TFMobileSpacing.md),

          // Miniaturas das fotos
          if (widget.evidences.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: TFMobileSpacing.sm),
              child: Text(
                'Nenhuma foto anexada a esta atividade.',
                style: TFMobileTypography.bodyMedium.copyWith(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            )
          else
            SizedBox(
              height: 96.0,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.evidences.length,
                separatorBuilder: (_, __) => const SizedBox(width: TFMobileSpacing.sm),
                itemBuilder: (context, index) {
                  final ev = widget.evidences[index];
                  return Stack(
                    children: [
                      Container(
                        width: 96.0,
                        height: 96.0,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(color: borderColor),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ev.url != null && ev.url!.isNotEmpty
                            ? Image.network(
                                ev.url!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.broken_image_outlined, size: 24.0),
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.image_outlined, size: 28.0, color: Colors.grey),
                              ),
                      ),
                      // Indicador de status pendente de sincronização
                      if (ev.isLocalPending)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706),
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                            child: const Text(
                              'Pendente',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.0,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),

          if (!widget.isReadOnly) ...[
            const SizedBox(height: TFMobileSpacing.md),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48.0,
                    child: TFSecondaryButton(
                      label: 'Tirar Foto',
                      icon: Icons.photo_camera_rounded,
                      height: 48.0,
                      onPressed: _isCapturing ? null : () => _pickImage(ImageSource.camera),
                    ),
                  ),
                ),
                const SizedBox(width: TFMobileSpacing.sm),
                Expanded(
                  child: SizedBox(
                    height: 48.0,
                    child: TFSecondaryButton(
                      label: 'Galeria',
                      icon: Icons.photo_library_outlined,
                      height: 48.0,
                      onPressed: _isCapturing ? null : () => _pickImage(ImageSource.gallery),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
