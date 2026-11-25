import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Player de vídeo embutido para anexos de Nota SAP (Web, Desktop e Mobile).
class NotaVideoPlayerWidget extends StatefulWidget {
  final Future<String> urlFuture;
  final String fileName;
  final VoidCallback? onOpenExternal;
  final VoidCallback? onDownload;

  const NotaVideoPlayerWidget({
    super.key,
    required this.urlFuture,
    required this.fileName,
    this.onOpenExternal,
    this.onDownload,
  });

  @override
  State<NotaVideoPlayerWidget> createState() => _NotaVideoPlayerWidgetState();
}

class _NotaVideoPlayerWidgetState extends State<NotaVideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitializing = true;
  String? _errorMessage;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void didUpdateWidget(NotaVideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.urlFuture != widget.urlFuture) {
      _disposeController();
      _initPlayer();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    _controller = null;
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _initPlayer() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      final url = await widget.urlFuture;
      if (!mounted) return;
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _controller = controller;
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(_onControllerUpdate);
      setState(() {
        _isInitializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorMessage = e.toString();
      });
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 12),
            Text(
              'Carregando vídeo...',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final ctrl = _controller;
    if (_errorMessage != null || ctrl == null || !ctrl.value.isInitialized) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off_outlined, size: 48, color: Colors.purple.shade300),
            const SizedBox(height: 12),
            Text(
              'Não foi possível reproduzir "${widget.fileName}" diretamente.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (widget.onOpenExternal != null)
                  ElevatedButton.icon(
                    onPressed: widget.onOpenExternal,
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Abrir Externamente'),
                  ),
                if (widget.onDownload != null)
                  OutlinedButton.icon(
                    onPressed: widget.onDownload,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white30),
                    ),
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Baixar Vídeo'),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    final isPlaying = ctrl.value.isPlaying;
    final position = ctrl.value.position;
    final duration = ctrl.value.duration;
    final aspect = ctrl.value.aspectRatio > 0 ? ctrl.value.aspectRatio : (16 / 9);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth * 0.92,
            maxHeight: constraints.maxHeight * 0.88,
          ),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: GestureDetector(
                    onTap: () => isPlaying ? ctrl.pause() : ctrl.play(),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(
                          aspectRatio: aspect,
                          child: VideoPlayer(ctrl),
                        ),
                        if (!isPlaying)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white54, width: 1.5),
                            ),
                            child: const Icon(Icons.play_arrow, color: Colors.white, size: 42),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VideoProgressIndicator(
                      ctrl,
                      allowScrubbing: true,
                      colors: VideoProgressColors(
                        playedColor: Theme.of(context).colorScheme.primary,
                        bufferedColor: Colors.white24,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                          ),
                          tooltip: isPlaying ? 'Pausar' : 'Reproduzir',
                          onPressed: () => isPlaying ? ctrl.pause() : ctrl.play(),
                        ),
                        IconButton(
                          icon: Icon(
                            _isMuted ? Icons.volume_off : Icons.volume_up,
                            color: Colors.white70,
                            size: 20,
                          ),
                          tooltip: _isMuted ? 'Ativar som' : 'Silenciar',
                          onPressed: () async {
                            final nextMuted = !_isMuted;
                            await ctrl.setVolume(nextMuted ? 0.0 : 1.0);
                            if (mounted) setState(() => _isMuted = nextMuted);
                          },
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_formatDuration(position)} / ${_formatDuration(duration)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const Spacer(),
                        if (widget.onDownload != null)
                          IconButton(
                            icon: const Icon(Icons.download, color: Colors.white70, size: 20),
                            tooltip: 'Baixar vídeo',
                            onPressed: widget.onDownload,
                          ),
                        if (widget.onOpenExternal != null)
                          IconButton(
                            icon: const Icon(Icons.open_in_new, color: Colors.white70, size: 20),
                            tooltip: 'Abrir externamente',
                            onPressed: widget.onOpenExternal,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

