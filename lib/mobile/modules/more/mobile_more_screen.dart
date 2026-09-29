import 'package:flutter/material.dart';
import '../../core/theme/tf_mobile_spacing.dart';
import '../../core/theme/tf_mobile_typography.dart';
import '../../core/theme/tf_mobile_colors.dart';
import '../../core/widgets/tf_mobile_buttons.dart';
import '../../core/navigation/tf_mobile_navigator.dart';
import '../schedule/models/mobile_agenda_view_mode.dart';

/// Tela "Mais" do TaskFlow Mobile.
/// Elimina a lista plana do Drawer organizando os módulos em categorias operacionais claras.
class MobileMoreScreen extends StatelessWidget {
  final TFMobileNavigator navigator;
  final VoidCallback onLogout;

  const MobileMoreScreen({
    super.key,
    required this.navigator,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TFMobileColors.background(context),
      body: ListView(
        padding: const EdgeInsets.all(TFMobileSpacing.lg),
        children: [
          // 1. Categoria: OPERAÇÃO
          _buildCategoryHeader('OPERAÇÃO & RECURSOS'),
          _buildCategoryCard(
            context,
            items: [
              _MoreItem(
                icon: Icons.groups_rounded,
                title: 'Equipes de Manutenção',
                subtitle: 'Escala e atividades por equipe',
                index: 1,
                onTapOverride: () => navigator.openSchedule(
                  initialMode: MobileAgendaViewMode.teams,
                ),
              ),
              _MoreItem(
                icon: Icons.directions_car_rounded,
                title: 'Gestão da Frota',
                subtitle: 'Escala e veículos em operação',
                index: 2,
                onTapOverride: () => navigator.openSchedule(
                  initialMode: MobileAgendaViewMode.fleet,
                ),
              ),
              _MoreItem(icon: Icons.assignment_late_rounded, title: 'Demandas Operacionais', subtitle: 'Abertura e acompanhamento de chamados', index: 3),
              _MoreItem(icon: Icons.description_rounded, title: 'Documentos, APR & CRC', subtitle: 'Relatórios, procedimentos e PDFs', index: 5),
              _MoreItem(icon: Icons.notifications_active_rounded, title: 'Central de Alertas', subtitle: 'Avisos de prazos e impedimentos', index: 9),
            ],
          ),

          const SizedBox(height: TFMobileSpacing.xl),

          // 2. Categoria: INTEGRAÇÃO SAP
          _buildCategoryHeader('SISTEMA SAP'),
          _buildCategoryCard(
            context,
            items: [
              _MoreItem(icon: Icons.assignment_outlined, title: 'Notas SAP', subtitle: 'Consulta e associação de notas de avaria', index: 16),
              _MoreItem(icon: Icons.build_circle_outlined, title: 'Ordens SAP', subtitle: 'Ordens de serviço de manutenção', index: 17),
              _MoreItem(icon: Icons.access_time_filled_rounded, title: 'Horas SAP', subtitle: 'Apontamento de horas normais e extras', index: 20),
              _MoreItem(icon: Icons.electric_bolt_outlined, title: 'Solicitações de Intervenção (SIs)', subtitle: 'Bloqueios elétricos e desligamentos', index: 19),
              _MoreItem(icon: Icons.verified_user_outlined, title: 'Autorizações de Trabalho (ATs)', subtitle: 'Validação e liberação técnica', index: 18),
              _MoreItem(icon: Icons.fact_check_outlined, title: 'Confirmação de Ordens', subtitle: 'Encerramento de operações no SAP', index: 25),
            ],
          ),

          const SizedBox(height: TFMobileSpacing.xl),

          // 3. Categoria: ENGENHARIA & ESPECIALIDADES
          _buildCategoryHeader('ENGENHARIA & ESPECIALIDADES'),
          _buildCategoryCard(
            context,
            items: [
              _MoreItem(icon: Icons.alt_route_rounded, title: 'Linhas de Transmissão', subtitle: 'Vãos, torres e mapas georreferenciados', index: 15),
              _MoreItem(icon: Icons.park_outlined, title: 'Supressão de Vegetação', subtitle: 'Poda e monitoramento de faixa de servidão', index: 21),
              _MoreItem(icon: Icons.attach_money_rounded, title: 'Gestão de Custos', subtitle: 'Apropriação e despesas operacionais', index: 12),
              _MoreItem(icon: Icons.folder_shared_outlined, title: 'Projetos e Obras', subtitle: 'Avanço físico e cronogramas', index: 27),
            ],
          ),

          const SizedBox(height: TFMobileSpacing.xl),

          // 4. Categoria: PRODUTIVIDADE & COMUNICAÇÃO
          _buildCategoryHeader('PRODUTIVIDADE & SUPORTE'),
          _buildCategoryCard(
            context,
            items: [
              _MoreItem(icon: Icons.chat_outlined, title: 'Chat Operacional Completo', subtitle: 'Mensagens diretas e canais técnicos', index: 14),
              _MoreItem(icon: Icons.check_box_outlined, title: 'Gestão GTD', subtitle: 'Caixa de entrada e tarefas pessoais', index: 23),
              _MoreItem(icon: Icons.smart_toy_outlined, title: 'Assistente Inteligente (IA)', subtitle: 'Consultas e diagnósticos assistidos', index: 26),
              _MoreItem(icon: Icons.bug_report_outlined, title: 'Melhorias & Bugs', subtitle: 'Sugestões e relato de problemas do app', index: 24),
            ],
          ),

          const SizedBox(height: TFMobileSpacing.xl),

          // 5. Categoria: SISTEMA
          _buildCategoryHeader('SISTEMA & PREFERÊNCIAS'),
          _buildCategoryCard(
            context,
            items: [
              _MoreItem(icon: Icons.settings_outlined, title: 'Configurações do Usuário', subtitle: 'Preferências de visualização e perfil', index: 13),
              _MoreItem(icon: Icons.cloud_sync_outlined, title: 'Central de Sincronização', subtitle: 'Fila de envio local e status do banco', index: 0),
            ],
          ),

          const SizedBox(height: TFMobileSpacing.xxl),

          // 6. Ação Sair: Isolada no Rodapé com Confirmação (Ajuste #14)
          Container(
            padding: const EdgeInsets.all(TFMobileSpacing.md),
            decoration: BoxDecoration(
              color: TFMobileColors.surface(context),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: TFMobileColors.border(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sessão do Usuário',
                  style: TFMobileTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4.0),
                Text(
                  'Ao sair, será necessário autenticar novamente com suas credenciais.',
                  style: TFMobileTypography.caption.copyWith(color: TFMobileColors.textSecondary(context)),
                ),
                const SizedBox(height: TFMobileSpacing.md),
                TFDestructiveButton(
                  label: 'Sair da Conta',
                  icon: Icons.logout_rounded,
                  onPressed: () => _confirmLogout(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: TFMobileSpacing.xxxl),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Encerrar Sessão', style: TFMobileTypography.titleLarge),
        content: Text(
          'Deseja realmente sair da sua conta no TaskFlow Mobile?',
          style: TFMobileTypography.bodyMedium,
        ),
        actions: [
          TFTertiaryButton(
            label: 'Cancelar',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TFMobileColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              onLogout();
            },
            child: const Text('Sim, Sair'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TFMobileSpacing.sm, left: 4.0),
      child: Text(
        title,
        style: TFMobileTypography.label.copyWith(
          color: TFMobileColors.primaryBlue,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, {required List<_MoreItem> items}) {
    final surfaceColor = TFMobileColors.surface(context);
    final borderColor = TFMobileColors.border(context);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final isLast = idx == items.length - 1;

          return Column(
            children: [
              InkWell(
                onTap: () {
                  if (item.onTapOverride != null) {
                    item.onTapOverride!();
                  } else {
                    navigator.openLegacyModule(item.index);
                  }
                },
                borderRadius: BorderRadius.circular(12.0),
                child: Padding(
                  padding: const EdgeInsets.all(TFMobileSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        width: 40.0,
                        height: 40.0,
                        decoration: BoxDecoration(
                          color: TFMobileColors.primaryBlue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Icon(item.icon, color: TFMobileColors.primaryBlue, size: 22.0),
                      ),
                      const SizedBox(width: TFMobileSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: TFMobileTypography.titleMedium.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              item.subtitle,
                              style: TFMobileTypography.caption.copyWith(
                                color: TFMobileColors.textSecondary(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20.0),
                    ],
                  ),
                ),
              ),
              if (!isLast) const Divider(height: 1.0),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MoreItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final int index;
  final VoidCallback? onTapOverride;

  const _MoreItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.index,
    this.onTapOverride,
  });
}
