import 'package:flutter/material.dart';

import '../../data/gtd_sync_service.dart';
import '../../domain/gtd_session.dart';
import '../tabs/gtd_capture_tab.dart';
import '../tabs/gtd_process_tab.dart';
import '../tabs/gtd_agora_tab.dart';
import '../tabs/gtd_someday_tab.dart';
import '../tabs/gtd_projects_tab.dart';
import '../tabs/gtd_weekly_review_tab.dart';
import '../tabs/gtd_panel_tab.dart';
import '../tabs/gtd_andamento_tab.dart';

/// Página principal GTD com abas: Painel, Capturar, Processar, Agora, Algum dia, Em andamento, Projetos, Revisão.
class GtdHomePage extends StatefulWidget {
  const GtdHomePage({super.key});

  @override
  State<GtdHomePage> createState() => _GtdHomePageState();
}

class _GtdHomePageState extends State<GtdHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _syncReady = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _initSync();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initSync() async {
    final userId = GtdSession.currentUserId;
    if (userId != null) {
      await GtdSyncService.instance().initialize(userId);
    }
    if (mounted) setState(() => _syncReady = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!GtdSession.canAccessGtd) {
      return const Scaffold(
        body: Center(child: Text('Acesso ao GTD não permitido. Faça login.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('GTD'),
        elevation: 0,
        scrolledUnderElevation: 2,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded), text: 'Painel'),
            Tab(icon: Icon(Icons.inbox), text: 'Capturar'),
            Tab(icon: Icon(Icons.tune), text: 'Processar'),
            Tab(icon: Icon(Icons.play_circle_fill), text: 'Agora'),
            Tab(icon: Icon(Icons.schedule), text: 'Algum dia'),
            Tab(icon: Icon(Icons.note_alt_outlined), text: 'Em andamento'),
            Tab(icon: Icon(Icons.folder), text: 'Projetos'),
            Tab(icon: Icon(Icons.calendar_view_week), text: 'Revisão'),
          ],
        ),
      ),
      body: _syncReady
          ? TabBarView(
              controller: _tabController,
              children: [
                GtdPanelTab(
                  onGoToTab: _tabController.animateTo,
                  tabController: _tabController,
                ),
                GtdCaptureTab(tabController: _tabController),
                const GtdProcessTab(),
                const GtdAgoraTab(),
                const GtdSomedayTab(),
                const GtdAndamentoTab(),
                const GtdProjectsTab(),
                const GtdWeeklyReviewTab(),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
