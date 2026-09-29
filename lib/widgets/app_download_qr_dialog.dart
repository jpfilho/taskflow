import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/app_download_service.dart';

class AppDownloadQrDialog extends StatefulWidget {
  final String? initialTab; // 'android' ou 'ios'

  const AppDownloadQrDialog({
    super.key,
    this.initialTab,
  });

  static Future<void> show(BuildContext context, {String? initialTab}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AppDownloadQrDialog(initialTab: initialTab),
    );
  }

  @override
  State<AppDownloadQrDialog> createState() => _AppDownloadQrDialogState();
}

class _AppDownloadQrDialogState extends State<AppDownloadQrDialog>
    with SingleTickerProviderStateMixin {
  final _downloadService = AppDownloadService.instance;
  String _androidUrl = '';
  String _iosUrl = '';
  bool _carregando = true;
  String? _linkCopiadoFeedback;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == 'ios' ? 1 : 0,
    );
    _carregarUrls();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _carregarUrls() async {
    final android = await _downloadService.getAndroidUrl();
    final ios = await _downloadService.getIosUrl();
    if (mounted) {
      setState(() {
        _androidUrl = android;
        _iosUrl = ios;
        _carregando = false;
      });
    }
  }

  void _copiarParaClipboard(String url, String platformName) {
    Clipboard.setData(ClipboardData(text: url));
    setState(() {
      _linkCopiadoFeedback = platformName;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Link do $platformName copiado para a área de transferência!',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _linkCopiadoFeedback == platformName) {
        setState(() {
          _linkCopiadoFeedback = null;
        });
      }
    });
  }

  void _abrirConfiguracaoLinks() {
    Navigator.of(context).pop();
    _mostrarDialogConfigurarLinks();
  }

  void _mostrarDialogConfigurarLinks() async {
    final currentAndroidUrl = await _downloadService.getAndroidUrl();
    final currentIpaUrl = await _downloadService.getIpaUrl();
    final currentIosUrl = await _downloadService.getIosUrl();

    if (!mounted) return;

    final androidController = TextEditingController(text: currentAndroidUrl);
    final ipaController = TextEditingController(text: currentIpaUrl);
    final iosController = TextEditingController(text: currentIosUrl);

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 540,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.link_rounded, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Configurar Links de Download Mobile',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ajuste as URLs utilizadas nos QR Codes e links diretos do aplicativo.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 20),
                const Text('URL do APK Android (Instalação Direta):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: androidController,
                  decoration: InputDecoration(
                    hintText: 'https://.../taskflow.apk',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    suffixIcon: IconButton(
                      tooltip: 'Restaurar padrão',
                      icon: const Icon(Icons.restore, size: 18),
                      onPressed: () => androidController.text = AppDownloadService.defaultAndroidUrl,
                    ),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
                const Text('URL do TestFlight iOS (Apple):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: iosController,
                  decoration: InputDecoration(
                    hintText: 'https://testflight.apple.com/join/...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    suffixIcon: IconButton(
                      tooltip: 'Restaurar padrão',
                      icon: const Icon(Icons.restore, size: 18),
                      onPressed: () => iosController.text = AppDownloadService.defaultIosUrl,
                    ),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        await _downloadService.setUrls(
                          androidUrl: androidController.text.trim(),
                          ipaUrl: ipaController.text.trim(),
                          iosUrl: iosController.text.trim(),
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                          if (mounted) {
                            AppDownloadQrDialog.show(context);
                          }
                        }
                      },
                      child: const Text('Salvar Alterações'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 720;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 780 : 440,
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context),
                if (_carregando)
                  const Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(),
                  )
                else
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isDesktop)
                            _buildDesktopSideBySide()
                          else
                            _buildMobileTabbed(),
                          const SizedBox(height: 20),
                          _buildFooterNotes(),
                        ],
                      ),
                    ),
                  ),
                _buildBottomBar(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Slate 900
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Instalar Task Flow no Celular',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Aponte a câmera do seu smartphone para o QR Code para instalar',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 22),
            tooltip: 'Fechar',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopSideBySide() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildPlatformCard(
            platform: 'android',
            title: 'Android',
            badgeText: 'Instalação Direta (.APK)',
            badgeColor: const Color(0xFF2E7D32),
            badgeBgColor: const Color(0xFFE8F5E9),
            icon: Icons.android_rounded,
            iconColor: const Color(0xFF2E7D32),
            url: _androidUrl,
            actionButtonLabel: 'Baixar APK',
            actionButtonIcon: Icons.download_rounded,
            actionButtonColor: const Color(0xFF2E7D32),
            onActionPressed: () => _downloadService.downloadAndroid(),
            tipText: 'Ao baixar, autorize a instalação de fontes desconhecidas se solicitado pelo navegador.',
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _buildPlatformCard(
            platform: 'ios',
            title: 'iOS (iPhone / iPad)',
            badgeText: 'Apple TestFlight',
            badgeColor: const Color(0xFF1D4ED8),
            badgeBgColor: const Color(0xFFEFF6FF),
            icon: Icons.apple_rounded,
            iconColor: const Color(0xFF1E293B),
            url: _iosUrl,
            actionButtonLabel: 'Abrir no TestFlight',
            actionButtonIcon: Icons.open_in_new_rounded,
            actionButtonColor: const Color(0xFF2563EB),
            onActionPressed: () => _downloadService.openIosInstall(),
            tipText: 'Requer o aplicativo TestFlight instalado pela App Store para aceitar o convite público.',
          ),
        ),
      ],
    );
  }

  Widget _buildMobileTabbed() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 44,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: const Color(0xFF0F172A),
            unselectedLabelColor: const Color(0xFF64748B),
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.android_rounded, size: 18, color: Color(0xFF2E7D32)),
                    SizedBox(width: 6),
                    Text('Android (APK)'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.apple_rounded, size: 18, color: Color(0xFF1E293B)),
                    SizedBox(width: 6),
                    Text('iOS (TestFlight)'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 470,
          child: TabBarView(
            controller: _tabController,
            children: [
              SingleChildScrollView(
                child: _buildPlatformCard(
                  platform: 'android',
                  title: 'Android',
                  badgeText: 'Instalação Direta (.APK)',
                  badgeColor: const Color(0xFF2E7D32),
                  badgeBgColor: const Color(0xFFE8F5E9),
                  icon: Icons.android_rounded,
                  iconColor: const Color(0xFF2E7D32),
                  url: _androidUrl,
                  actionButtonLabel: 'Baixar APK',
                  actionButtonIcon: Icons.download_rounded,
                  actionButtonColor: const Color(0xFF2E7D32),
                  onActionPressed: () => _downloadService.downloadAndroid(),
                  tipText: 'Ao baixar, autorize a instalação de fontes desconhecidas se solicitado pelo navegador.',
                ),
              ),
              SingleChildScrollView(
                child: _buildPlatformCard(
                  platform: 'ios',
                  title: 'iOS (iPhone / iPad)',
                  badgeText: 'Apple TestFlight',
                  badgeColor: const Color(0xFF1D4ED8),
                  badgeBgColor: const Color(0xFFEFF6FF),
                  icon: Icons.apple_rounded,
                  iconColor: const Color(0xFF1E293B),
                  url: _iosUrl,
                  actionButtonLabel: 'Abrir no TestFlight',
                  actionButtonIcon: Icons.open_in_new_rounded,
                  actionButtonColor: const Color(0xFF2563EB),
                  onActionPressed: () => _downloadService.openIosInstall(),
                  tipText: 'Requer o aplicativo TestFlight instalado pela App Store para aceitar o convite público.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlatformCard({
    required String platform,
    required String title,
    required String badgeText,
    required Color badgeColor,
    required Color badgeBgColor,
    required IconData icon,
    required Color iconColor,
    required String url,
    required String actionButtonLabel,
    required IconData actionButtonIcon,
    required Color actionButtonColor,
    required VoidCallback onActionPressed,
    required String tipText,
  }) {
    final bool linkCopiado = _linkCopiadoFeedback == title;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: badgeBgColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                color: badgeColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // QR Code Container
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: url.isNotEmpty
                ? QrImageView(
                    data: url,
                    version: QrVersions.auto,
                    size: 160.0,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  )
                : const SizedBox(
                    width: 160,
                    height: 160,
                    child: Center(
                      child: Text('URL não definida', style: TextStyle(color: Colors.grey)),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            'Escaneie com a câmera do celular',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          // Ações do Card
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(
                    linkCopiado ? Icons.check_circle_rounded : Icons.copy_rounded,
                    size: 15,
                    color: linkCopiado ? const Color(0xFF2E7D32) : const Color(0xFF475569),
                  ),
                  label: Text(
                    linkCopiado ? 'Copiado!' : 'Copiar Link',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: linkCopiado ? const Color(0xFF2E7D32) : const Color(0xFF475569),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: linkCopiado ? const Color(0xFFE8F5E9) : Colors.white,
                    side: BorderSide(
                      color: linkCopiado ? const Color(0xFF2E7D32) : const Color(0xFFCBD5E1),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _copiarParaClipboard(url, title),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(actionButtonIcon, size: 16),
                  label: Text(
                    actionButtonLabel,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: actionButtonColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: onActionPressed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tipText,
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterNotes() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.devices_rounded, size: 18, color: Color(0xFF475569)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'O Task Flow Mobile sincroniza automaticamente todas as atividades, ordens e tarefas diretamente com a versão Web em tempo real.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          TextButton.icon(
            icon: const Icon(Icons.settings_outlined, size: 16, color: Color(0xFF64748B)),
            label: const Text(
              'Configurar Links',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            onPressed: _abrirConfiguracaoLinks,
          ),
          const Spacer(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Concluído', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
