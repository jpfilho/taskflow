import 'package:flutter/material.dart';
import '../models/mensagem.dart';
import '../models/grupo_chat.dart';
import '../services/chat_service.dart';
import '../services/auth_service_simples.dart';
import '../services/anexo_service.dart';
import '../models/anexo.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class ChatScreen extends StatefulWidget {
  final String grupoId;
  final VoidCallback onBack;

  const ChatScreen({
    super.key,
    required this.grupoId,
    required this.onBack,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  
  List<Mensagem> _mensagens = [];
  bool _isLoading = true;
  StreamSubscription<List<Mensagem>>? _mensagensSubscription;
  String? _grupoNome;
  String? _mensagemEditandoId; // ID da mensagem sendo editada
  final TextEditingController _editController = TextEditingController();
  
  // Para resposta de mensagens
  Mensagem? _mensagemRespondendo;
  
  // Para gravação de áudio
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _audioPath;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  
  // Para menções (será usado futuramente para sugestões de usuários)
  // List<String> _usuariosDisponiveis = [];
  
  // Para emoji picker
  bool _mostrarEmojiPicker = false;

  @override
  void initState() {
    super.initState();
    _loadMensagens();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _mensagensSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _editController.dispose();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _loadMensagens() async {
    setState(() => _isLoading = true);
    try {
      final mensagens = await _chatService.listarMensagens(widget.grupoId);
      
      // Obter nome do grupo
      final grupo = await _chatService.obterGrupoPorId(widget.grupoId);
      if (grupo == null) {
        // Tentar buscar por tarefa_id caso widget.grupoId seja o ID da tarefa
        final grupoPorTarefa = await _chatService.obterGrupoPorTarefaId(widget.grupoId);
        _grupoNome = grupoPorTarefa?.tarefaNome ?? 'Grupo';
      } else {
        _grupoNome = grupo.tarefaNome;
      }

      setState(() {
        _mensagens = mensagens;
        _isLoading = false;
      });

      // Scroll para o final
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      print('Erro ao carregar mensagens: $e');
      setState(() => _isLoading = false);
    }
  }

  void _setupRealtimeSubscription() {
    // Usar stream do Supabase para atualizações em tempo real
    _mensagensSubscription = _chatService
        .streamMensagens(widget.grupoId)
        .listen((mensagens) {
      // Evitar duplicações: mesclar mensagens existentes com novas
      setState(() {
        // Criar um mapa de IDs para evitar duplicações
        final mensagensMap = <String, Mensagem>{};
        
        // Adicionar mensagens existentes (incluindo temporárias)
        for (var msg in _mensagens) {
          if (msg.id != null) {
            mensagensMap[msg.id!] = msg;
          }
        }
        
        // Adicionar/atualizar com mensagens do stream
        for (var msg in mensagens) {
          if (msg.id != null) {
            mensagensMap[msg.id!] = msg;
          }
        }
        
        // Converter de volta para lista e ordenar por data
        _mensagens = mensagensMap.values.toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }


  Future<void> _mostrarOpcoesAnexo() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF075E54)),
                title: const Text('Tirar foto'),
                onTap: () {
                  Navigator.pop(context);
                  _tirarFoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF075E54)),
                title: const Text('Galeria'),
                onTap: () {
                  Navigator.pop(context);
                  _escolherDaGaleria();
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file, color: Color(0xFF075E54)),
                title: const Text('Documentos'),
                onTap: () {
                  Navigator.pop(context);
                  _enviarAnexo();
                },
              ),
              ListTile(
                leading: const Icon(Icons.mic, color: Color(0xFF075E54)),
                title: const Text('Áudio'),
                onTap: () {
                  Navigator.pop(context);
                  _iniciarGravacaoAudio();
                },
              ),
              ListTile(
                leading: const Icon(Icons.location_on, color: Color(0xFF075E54)),
                title: const Text('Localização'),
                onTap: () {
                  Navigator.pop(context);
                  _enviarLocalizacao();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _tirarFoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo != null) {
        await _processarImagem(photo);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao tirar foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _escolherDaGaleria() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        await _processarImagem(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao escolher imagem: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _isImageFile(XFile file) {
    final name = file.name.toLowerCase();
    final mime = (file.mimeType ?? '').toLowerCase();
    return mime.startsWith('image/') ||
        name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.gif') ||
        name.endsWith('.webp');
  }

  Future<void> _processarImagem(XFile imageFile) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enviando imagem...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Obter tarefaId do grupo
      final grupo = await _chatService.obterGrupoPorId(widget.grupoId);
      if (grupo == null) {
        throw Exception('Grupo não encontrado');
      }

      // Ler bytes da imagem
      Uint8List bytes;
      if (kIsWeb) {
        bytes = await imageFile.readAsBytes();
      } else {
        final file = File(imageFile.path);
        bytes = await file.readAsBytes();
      }

      if (bytes.isEmpty) {
        throw Exception('Imagem vazia');
      }

      // Usar AnexoService para fazer upload
      final anexoService = AnexoService();
      final fileName = imageFile.name;
      final mimeType = 'image/${fileName.split('.').last.toLowerCase()}';
      
      Anexo anexo;
      if (kIsWeb) {
        debugPrint('[Chat] upload imagem (web) task=${grupo.tarefaId} file=$fileName bytes=${bytes.length}');
        anexo = await anexoService.uploadAnexoFromBytes(
          taskId: grupo.tarefaId,
          bytes: bytes,
          nomeArquivo: fileName,
          mimeType: mimeType,
        );
      } else {
        debugPrint('[Chat] upload imagem (device) task=${grupo.tarefaId} file=${imageFile.path}');
        anexo = await anexoService.uploadAnexo(
          taskId: grupo.tarefaId,
          file: File(imageFile.path),
        );
      }

      // Obter URL (pública ou assinada)
      final arquivoUrl = await anexoService.getSignedUrl(anexo);
      debugPrint('[Chat] upload imagem OK task=${grupo.tarefaId} id=${anexo.id} path=${anexo.caminhoArquivo} url=$arquivoUrl');

      // Enviar mensagem com imagem (sem nome do arquivo)
      await _enviarMensagemComAnexo(
        conteudo: '', // Não enviar nome do arquivo para imagens/vídeos
        tipo: 'imagem',
        arquivoUrl: arquivoUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagem enviada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('[Chat] erro ao processar/enviar imagem: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar imagem: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _enviarAnexo() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        final fileName = file.name;

        // Mostrar indicador de carregamento
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enviando arquivo...'),
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Obter tarefaId do grupo
        final grupo = await _chatService.obterGrupoPorId(widget.grupoId);
        if (grupo == null) {
          throw Exception('Grupo não encontrado');
        }

        // Ler bytes do arquivo
        Uint8List bytes;
        String? mimeType;

        if (kIsWeb) {
          // Web: usar bytes diretamente (path não está disponível)
          if (file.bytes == null || file.bytes!.isEmpty) {
            throw Exception('Arquivo vazio ou não foi possível ler');
          }
          bytes = Uint8List.fromList(file.bytes!);
          mimeType = file.extension != null 
              ? _getMimeTypeFromExtension(file.extension!)
              : null;
          debugPrint('[Chat] upload anexo (web) task=${grupo.tarefaId} file=$fileName bytes=${bytes.length}');
        } else {
          // Mobile/Desktop: ler do arquivo usando path
          if (file.path == null) {
            throw Exception('Caminho do arquivo não disponível');
          }
          final fileObj = File(file.path!);
          bytes = await fileObj.readAsBytes();
          mimeType = _getMimeTypeFromExtension(fileName.split('.').last);
          debugPrint('[Chat] upload anexo (device) task=${grupo.tarefaId} file=${file.path} bytes=${bytes.length}');
        }

        if (bytes.isEmpty) {
          throw Exception('Arquivo vazio');
        }

        // Usar AnexoService para fazer upload (mesma tabela das tarefas)
        final anexoService = AnexoService();
        Anexo anexo;
        
        if (kIsWeb) {
          anexo = await anexoService.uploadAnexoFromBytes(
            taskId: grupo.tarefaId,
            bytes: bytes,
            nomeArquivo: fileName,
            mimeType: mimeType,
          );
        } else {
          anexo = await anexoService.uploadAnexo(
            taskId: grupo.tarefaId,
            file: File(file.path!),
          );
        }
        debugPrint('[Chat] upload anexo OK task=${grupo.tarefaId} id=${anexo.id} path=${anexo.caminhoArquivo}');

        // Obter URL assinada do arquivo
        final arquivoUrl = await anexoService.getSignedUrl(anexo);

        // Determinar tipo de arquivo
        final tipoArquivo = anexo.tipoArquivo;

        // Enviar mensagem com anexo
        // Para imagens e vídeos, não enviar nome do arquivo
        final conteudo = (tipoArquivo == 'imagem' || tipoArquivo == 'video') ? '' : fileName;
        await _enviarMensagemComAnexo(
          conteudo: conteudo,
          tipo: tipoArquivo,
          arquivoUrl: arquivoUrl,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Arquivo enviado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[Chat] erro ao enviar arquivo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar arquivo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _enviarMensagemComAnexo({
    required String conteudo,
    required String tipo,
    required String arquivoUrl,
  }) async {
    // Obter nome do usuário atual
    final authService = AuthServiceSimples();
    final nomeUsuario = authService.getUserName() ?? 'Você';
    final userId = _chatService.currentUserId ?? 'anonymous';

    // Criar mensagem temporária
    final mensagemTemporaria = Mensagem(
      grupoId: widget.grupoId,
      usuarioId: userId,
      usuarioNome: nomeUsuario,
      conteudo: conteudo,
      tipo: tipo,
      arquivoUrl: arquivoUrl,
      createdAt: DateTime.now(),
    );

    // Adicionar mensagem localmente imediatamente
    setState(() {
      _mensagens = [..._mensagens, mensagemTemporaria];
    });
    
    // Scroll para o final
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    try {
      // Enviar mensagem ao servidor
      final mensagemEnviada = await _chatService.enviarMensagem(
        widget.grupoId,
        conteudo,
        tipo: tipo,
        arquivoUrl: arquivoUrl,
        usuarioNome: nomeUsuario,
      );

      // Atualizar a mensagem temporária
      setState(() {
        final index = _mensagens.indexWhere((m) => 
          m.id == null &&
          m.conteudo == conteudo && 
          m.usuarioId == userId &&
          m.createdAt.difference(mensagemTemporaria.createdAt).inSeconds < 5
        );
        if (index != -1) {
          _mensagens[index] = mensagemEnviada;
        } else {
          final existeMensagem = _mensagens.any((m) => m.id == mensagemEnviada.id);
          if (!existeMensagem) {
            _mensagens = [..._mensagens, mensagemEnviada];
          }
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      // Remover mensagem temporária em caso de erro
      setState(() {
        _mensagens.removeWhere((m) => 
          m.id == null &&
          m.conteudo == conteudo && 
          m.usuarioId == userId &&
          m.createdAt.difference(mensagemTemporaria.createdAt).inSeconds < 5
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar mensagem: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  String? _getMimeTypeFromExtension(String extension) {
    final ext = extension.toLowerCase();
    final mimeTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'mp4': 'video/mp4',
      'mp3': 'audio/mpeg',
    };
    return mimeTypes[ext];
  }

  Future<void> _enviarMensagem() async {
    final texto = _messageController.text.trim();
    if (texto.isEmpty) return;

    // Obter nome do usuário atual
    final authService = AuthServiceSimples();
    final nomeUsuario = authService.getUserName() ?? 'Você';
    final userId = _chatService.currentUserId ?? 'anonymous';

    // Processar menções no texto (detectar @menções)
    // TODO: Em produção, mapear nomes de menções para IDs de usuários
    final usuariosMencionados = <String>[];

    // Salvar ID da mensagem respondida antes de limpar
    final mensagemRespondidaId = _mensagemRespondendo?.id;
    final mensagemRespondida = _mensagemRespondendo;

    // Criar mensagem temporária para adicionar imediatamente (otimistic update)
    final mensagemTemporaria = Mensagem(
      grupoId: widget.grupoId,
      usuarioId: userId,
      usuarioNome: nomeUsuario,
      conteudo: texto,
      mensagemRespondidaId: mensagemRespondidaId,
      mensagemRespondida: mensagemRespondida,
      usuariosMencionados: usuariosMencionados.isNotEmpty ? usuariosMencionados : null,
      createdAt: DateTime.now(),
    );

    // Adicionar mensagem localmente imediatamente
    setState(() {
      _mensagens = [..._mensagens, mensagemTemporaria];
    });
    _messageController.clear();
    _cancelarResposta(); // Limpar preview da resposta
    _focusNode.requestFocus();
    
    // Scroll para o final imediatamente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    try {
      // Enviar mensagem ao servidor (usar variáveis salvas, não _mensagemRespondendo que já foi limpo)
      final mensagemEnviada = await _chatService.enviarMensagem(
        widget.grupoId,
        texto,
        usuarioNome: nomeUsuario,
        mensagemRespondidaId: mensagemRespondidaId,
        usuariosMencionados: usuariosMencionados.isNotEmpty ? usuariosMencionados : null,
      );

      // Atualizar a mensagem temporária com os dados reais do servidor
      setState(() {
        final index = _mensagens.indexWhere((m) => 
          m.id == null && // Mensagem temporária não tem ID
          m.conteudo == texto && 
          m.usuarioId == userId &&
          m.createdAt.difference(mensagemTemporaria.createdAt).inSeconds < 5
        );
        if (index != -1) {
          _mensagens[index] = mensagemEnviada;
        } else {
          // Se não encontrou, verificar se a mensagem já existe (pelo ID)
          final existeMensagem = _mensagens.any((m) => m.id == mensagemEnviada.id);
          if (!existeMensagem) {
            _mensagens = [..._mensagens, mensagemEnviada];
          }
        }
      });

      // Scroll novamente após atualização
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      // Remover mensagem temporária em caso de erro
      setState(() {
        _mensagens.removeWhere((m) => 
          m.id == null && // Mensagem temporária não tem ID
          m.conteudo == texto && 
          m.usuarioId == userId &&
          m.createdAt.difference(mensagemTemporaria.createdAt).inSeconds < 5
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar mensagem: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ========== GRAVAÇÃO DE ÁUDIO ==========
  
  Future<void> _iniciarGravacaoAudio() async {
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permissão de microfone negada'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _audioPath = '${directory.path}/audio_$timestamp.m4a';

      if (await _audioRecorder.hasPermission()) {
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: _audioPath!,
        );

        setState(() {
          _isRecording = true;
          _recordingDuration = 0;
        });

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordingDuration++;
          });
        });

        _mostrarDialogoGravacao();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao iniciar gravação: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _mostrarDialogoGravacao() async {
    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Gravando áudio'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mic, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  _formatarDuracao(_recordingDuration),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _cancelarGravacao();
                  Navigator.of(context).pop(false);
                },
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  _pararGravacao();
                  Navigator.of(context).pop(true);
                },
                child: const Text('Enviar'),
              ),
            ],
          );
        },
      ),
    );

    if (resultado != true && _isRecording) {
      _cancelarGravacao();
    }
  }

  String _formatarDuracao(int segundos) {
    final minutos = segundos ~/ 60;
    final segs = segundos % 60;
    return '${minutos.toString().padLeft(2, '0')}:${segs.toString().padLeft(2, '0')}';
  }

  Future<void> _pararGravacao() async {
    if (!_isRecording || _audioPath == null) return;

    try {
      final path = await _audioRecorder.stop();
      _recordingTimer?.cancel();
      
      setState(() {
        _isRecording = false;
        _recordingDuration = 0;
      });

      if (path != null && path.isNotEmpty) {
        await _enviarAudio(path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao parar gravação: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelarGravacao() async {
    if (!_isRecording) return;

    try {
      await _audioRecorder.stop();
      _recordingTimer?.cancel();
      
      setState(() {
        _isRecording = false;
        _recordingDuration = 0;
      });

      if (_audioPath != null) {
        final file = File(_audioPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      _audioPath = null;
    } catch (e) {
      // Ignorar erros ao cancelar
    }
  }

  Future<void> _enviarAudio(String audioPath) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enviando áudio...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final grupo = await _chatService.obterGrupoPorId(widget.grupoId);
      if (grupo == null) {
        throw Exception('Grupo não encontrado');
      }

      final file = File(audioPath);
      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        throw Exception('Áudio vazio');
      }

      final anexoService = AnexoService();
      final anexo = await anexoService.uploadAnexoFromBytes(
        taskId: grupo.tarefaId,
        bytes: bytes,
        nomeArquivo: 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
        mimeType: 'audio/m4a',
      );

      final arquivoUrl = await anexoService.getSignedUrl(anexo);

      await _enviarMensagemComAnexo(
        conteudo: '',
        tipo: 'audio',
        arquivoUrl: arquivoUrl,
      );

      if (await file.exists()) {
        await file.delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Áudio enviado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar áudio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ========== ENVIO DE LOCALIZAÇÃO ==========
  
  Future<void> _enviarLocalizacao() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Serviço de localização desabilitado'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Permissão de localização negada'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permissão de localização negada permanentemente'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Obtendo localização...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      String? endereco = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';

      final authService = AuthServiceSimples();
      final nomeUsuario = authService.getUserName() ?? 'Você';
      final userId = _chatService.currentUserId ?? 'anonymous';

      final mensagemTemporaria = Mensagem(
        grupoId: widget.grupoId,
        usuarioId: userId,
        usuarioNome: nomeUsuario,
        conteudo: '📍 Localização',
        tipo: 'localizacao',
        localizacao: {
          'lat': position.latitude,
          'lng': position.longitude,
          'endereco': endereco,
        },
        createdAt: DateTime.now(),
      );

      setState(() {
        _mensagens = [..._mensagens, mensagemTemporaria];
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });

      try {
        final mensagemEnviada = await _chatService.enviarMensagem(
          widget.grupoId,
          '📍 Localização',
          tipo: 'localizacao',
          usuarioNome: nomeUsuario,
          localizacao: {
            'lat': position.latitude,
            'lng': position.longitude,
            'endereco': endereco,
          },
        );

        setState(() {
          final index = _mensagens.indexWhere((m) => 
            m.id == null &&
            m.conteudo == '📍 Localização' &&
            m.usuarioId == userId &&
            m.createdAt.difference(mensagemTemporaria.createdAt).inSeconds < 5
          );
          if (index != -1) {
            _mensagens[index] = mensagemEnviada;
          } else {
            final existeMensagem = _mensagens.any((m) => m.id == mensagemEnviada.id);
            if (!existeMensagem) {
              _mensagens = [..._mensagens, mensagemEnviada];
            }
          }
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      } catch (e) {
        setState(() {
          _mensagens.removeWhere((m) => 
            m.id == null &&
            m.conteudo == '📍 Localização' &&
            m.usuarioId == userId &&
            m.createdAt.difference(mensagemTemporaria.createdAt).inSeconds < 5
          );
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao enviar localização: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao obter localização: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ========== RESPOSTA A MENSAGENS ==========
  
  void _responderMensagem(Mensagem mensagem) {
    setState(() {
      _mensagemRespondendo = mensagem;
    });
    _focusNode.requestFocus();
  }

  void _cancelarResposta() {
    setState(() {
      _mensagemRespondendo = null;
    });
  }

  // ========== MARCAÇÃO DE USUÁRIOS ==========
  
  // TODO: Implementar sugestões de usuários ao digitar @
  // void _processarMencao(String texto) {
  //   final regex = RegExp(r'@(\w*)');
  //   final matches = regex.allMatches(texto);
  //   if (matches.isNotEmpty) {
  //     // Mostrar overlay com sugestões de usuários
  //   }
  // }

  // ========== WIDGETS DE EXIBIÇÃO ==========
  
  Widget _buildMensagemRespondida(Mensagem mensagem) {
    Mensagem? msgRespondida = mensagem.mensagemRespondida;
    
    // Se não temos a mensagem completa, buscar pelo ID
    if (msgRespondida == null && mensagem.mensagemRespondidaId != null) {
      msgRespondida = _mensagens.firstWhere(
        (m) => m.id == mensagem.mensagemRespondidaId,
        orElse: () => Mensagem(
          grupoId: mensagem.grupoId,
          usuarioId: 'unknown',
          conteudo: 'Mensagem não encontrada',
          createdAt: DateTime.now(),
        ),
      );
    }
    
    if (msgRespondida == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(color: Colors.blue[700]!, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            msgRespondida.usuarioNome ?? 'Usuário',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            msgRespondida.conteudo.isNotEmpty 
                ? msgRespondida.conteudo 
                : (msgRespondida.tipo == 'imagem' ? '📷 Imagem' : 
                   msgRespondida.tipo == 'video' ? '🎥 Vídeo' :
                   msgRespondida.tipo == 'audio' ? '🎤 Áudio' :
                   msgRespondida.tipo == 'localizacao' ? '📍 Localização' : 'Arquivo'),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  Widget _buildLocalizacaoWidget(Mensagem mensagem) {
    final localizacao = mensagem.localizacao;
    if (localizacao == null) return const SizedBox.shrink();
    
    final lat = localizacao['lat'] as double?;
    final lng = localizacao['lng'] as double?;
    final endereco = localizacao['endereco'] as String?;
    
    if (lat == null || lng == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.red[700], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  endereco ?? '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              // Abrir no Google Maps ou Apple Maps
              final url = Uri.parse(
                'https://www.google.com/maps/search/?api=1&query=$lat,$lng'
              );
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue[700],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Abrir no mapa',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildConteudoComMencoes(Mensagem mensagem) {
    final conteudo = mensagem.conteudo;
    final usuariosMencionados = mensagem.usuariosMencionados ?? [];
    
    if (usuariosMencionados.isEmpty) {
      return Text(
        conteudo,
        style: const TextStyle(fontSize: 14),
      );
    }
    
    // Destacar menções no texto
    final spans = <TextSpan>[];
    final regex = RegExp(r'@(\w+)');
    int lastIndex = 0;
    
    for (final match in regex.allMatches(conteudo)) {
      // Texto antes da menção
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: conteudo.substring(lastIndex, match.start),
          style: const TextStyle(fontSize: 14),
        ));
      }
      
      // Menção destacada
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ));
      
      lastIndex = match.end;
    }
    
    // Texto restante
    if (lastIndex < conteudo.length) {
      spans.add(TextSpan(
        text: conteudo.substring(lastIndex),
        style: const TextStyle(fontSize: 14),
      ));
    }
    
    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Widget _buildAnexoWidget(Mensagem mensagem) {
    final tipo = mensagem.tipo ?? 'arquivo';
    final url = mensagem.arquivoUrl ?? '';
    final nomeArquivo = mensagem.conteudo;

    // Para imagens: exibir diretamente
    if (tipo == 'imagem' && url.isNotEmpty) {
      return GestureDetector(
        onTap: () {
          // Abrir imagem em tela cheia
          _mostrarImagemFullScreen(url);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: const BoxConstraints(
            maxWidth: 250,
            maxHeight: 300,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 250,
                  height: 200,
                  color: Colors.grey[200],
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 250,
                  height: 200,
                  color: Colors.grey[200],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.grey[600]),
                      const SizedBox(height: 8),
                      Text(
                        'Erro ao carregar imagem',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    // Para vídeos: exibir preview com botão de play
    if (tipo == 'video' && url.isNotEmpty) {
      return GestureDetector(
        onTap: () async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Não foi possível abrir o vídeo'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: const BoxConstraints(
            maxWidth: 250,
            maxHeight: 200,
          ),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Preview do vídeo (pode ser uma imagem de preview ou cor sólida)
              Container(
                width: 250,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.videocam,
                  size: 64,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              // Botão de play
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(12),
                child: const Icon(
                  Icons.play_arrow,
                  size: 32,
                  color: Color(0xFF075E54),
                ),
              ),
              // Nome do arquivo no canto inferior
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    nomeArquivo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Para áudio: exibir player
    if (tipo == 'audio' && url.isNotEmpty)
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[700],
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Áudio',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Toque para reproduzir',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
        ),
      );

    // Para outros tipos: exibir como antes (documentos, etc)
    return GestureDetector(
      onTap: () async {
        if (url.isNotEmpty) {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Não foi possível abrir o arquivo'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(
              _getIconForTipo(tipo),
              size: 32,
              color: _getColorForTipo(tipo),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nomeArquivo,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getTipoLabel(tipo),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.download,
              size: 20,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarImagemFullScreen(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 300,
                      height: 300,
                      color: Colors.black,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 300,
                      height: 300,
                      color: Colors.black,
                      child: const Center(
                        child: Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForTipo(String tipo) {
    switch (tipo) {
      case 'imagem':
        return Icons.image;
      case 'video':
        return Icons.videocam;
      case 'audio':
        return Icons.audiotrack;
      case 'documento':
        return Icons.description;
      default:
        return Icons.attach_file;
    }
  }

  Color _getColorForTipo(String tipo) {
    switch (tipo) {
      case 'imagem':
        return Colors.purple;
      case 'video':
        return Colors.red;
      case 'audio':
        return Colors.orange;
      case 'documento':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getTipoLabel(String tipo) {
    switch (tipo) {
      case 'imagem':
        return 'Imagem';
      case 'video':
        return 'Vídeo';
      case 'audio':
        return 'Áudio';
      case 'documento':
        return 'Documento';
      default:
        return 'Arquivo';
    }
  }

  void _iniciarEdicao(Mensagem mensagem) {
    setState(() {
      _mensagemEditandoId = mensagem.id;
      _editController.text = mensagem.conteudo;
    });
  }

  void _cancelarEdicao() {
    setState(() {
      _mensagemEditandoId = null;
      _editController.clear();
    });
  }

  Future<void> _salvarEdicao(Mensagem mensagem) async {
    final novoConteudo = _editController.text.trim();
    if (novoConteudo.isEmpty) {
      _cancelarEdicao();
      return;
    }

    if (novoConteudo == mensagem.conteudo) {
      _cancelarEdicao();
      return;
    }

    try {
      final mensagemEditada = await _chatService.editarMensagem(
        mensagem.id!,
        novoConteudo,
      );

      setState(() {
        final index = _mensagens.indexWhere((m) => m.id == mensagem.id);
        if (index != -1) {
          _mensagens[index] = mensagemEditada;
        }
        _mensagemEditandoId = null;
        _editController.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao editar mensagem: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mostrarMenuMensagem(BuildContext context, Mensagem mensagem) {
    final isMinhaMensagem = mensagem.usuarioId ==
        (_chatService.currentUserId ?? 'anonymous');
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Responder'),
                onTap: () {
                  Navigator.pop(context);
                  _responderMensagem(mensagem);
                },
              ),
              if (isMinhaMensagem && mensagem.tipo == 'texto')
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Editar'),
                  onTap: () {
                    Navigator.pop(context);
                    _iniciarEdicao(mensagem);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Compartilhar'),
                onTap: () {
                  Navigator.pop(context);
                  _compartilharMensagem(mensagem);
                },
              ),
              ListTile(
                leading: const Icon(Icons.forward),
                title: const Text('Encaminhar'),
                onTap: () {
                  Navigator.pop(context);
                  _encaminharMensagem(mensagem);
                },
              ),
              if (isMinhaMensagem)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Excluir', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmarExclusao(mensagem);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _compartilharMensagem(Mensagem mensagem) async {
    try {
      String textoCompartilhar = mensagem.conteudo;
      
      if (mensagem.arquivoUrl != null && mensagem.arquivoUrl!.isNotEmpty) {
        textoCompartilhar += '\n\nAnexo: ${mensagem.arquivoUrl}';
      }
      
      if (mensagem.usuarioNome != null) {
        textoCompartilhar = '${mensagem.usuarioNome}: $textoCompartilhar';
      }
      
      await Share.share(
        textoCompartilhar,
        subject: 'Mensagem do chat',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao compartilhar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _encaminharMensagem(Mensagem mensagem) async {
    try {
      // Carregar todos os grupos disponíveis
      final todasComunidades = await _chatService.listarComunidades();
      final todosGrupos = <String, List<GrupoChat>>{};
      
      for (var comunidade in todasComunidades) {
        final grupos = await _chatService.listarGruposPorComunidade(comunidade.id ?? '');
        todosGrupos[comunidade.id ?? ''] = grupos;
      }

      // Mostrar dialog para selecionar grupo de destino
      final grupoSelecionado = await showDialog<String>(
        context: context,
        builder: (context) => Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            constraints: const BoxConstraints(maxHeight: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Encaminhar para',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: todasComunidades.length,
                    itemBuilder: (context, indexComunidade) {
                      final comunidade = todasComunidades[indexComunidade];
                      final grupos = todosGrupos[comunidade.id ?? ''] ?? [];
                      
                      return ExpansionTile(
                        title: Text('${comunidade.divisaoNome} - ${comunidade.segmentoNome}'),
                        children: grupos
                            .where((g) => (g.id ?? g.tarefaId) != widget.grupoId) // Excluir grupo atual
                            .map((grupo) => ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF075E54),
                                    child: Text(
                                      (grupo.tarefaNome.isNotEmpty)
                                          ? grupo.tarefaNome[0].toUpperCase()
                                          : 'G',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(grupo.tarefaNome),
                                  onTap: () {
                                    Navigator.of(context).pop(grupo.id ?? grupo.tarefaId);
                                  },
                                ))
                            .toList(),
                      );
                    },
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        ),
      );

      if (grupoSelecionado != null && grupoSelecionado.isNotEmpty) {
        // Obter nome do usuário atual
        final authService = AuthServiceSimples();
        final nomeUsuario = authService.getUserName() ?? 'Você';

        // Criar mensagem encaminhada
        String conteudoEncaminhado = mensagem.conteudo;
        if (mensagem.arquivoUrl != null && mensagem.arquivoUrl!.isNotEmpty) {
          conteudoEncaminhado = '📎 ${mensagem.conteudo}';
        }

        // Enviar mensagem encaminhada
        await _chatService.enviarMensagem(
          grupoSelecionado,
          conteudoEncaminhado,
          tipo: mensagem.tipo,
          arquivoUrl: mensagem.arquivoUrl,
          usuarioNome: nomeUsuario,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mensagem encaminhada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao encaminhar mensagem: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmarExclusao(Mensagem mensagem) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir mensagem'),
        content: const Text('Tem certeza que deseja excluir esta mensagem?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _chatService.excluirMensagem(mensagem.id!);

        setState(() {
          _mensagens.removeWhere((m) => m.id == mensagem.id);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mensagem excluída'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir mensagem: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildCampoEdicao(Mensagem mensagem) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _editController,
            autofocus: true,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: Colors.grey[400]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFF075E54), width: 2),
              ),
            ),
            onSubmitted: (_) => _salvarEdicao(mensagem),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.check, color: Colors.green),
          onPressed: () => _salvarEdicao(mensagem),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.red),
          onPressed: _cancelarEdicao,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  String _formatarHora(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  bool _isMesmoDia(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _formatarData(DateTime date) {
    final now = DateTime.now();
    if (_isMesmoDia(date, now)) {
      return 'Hoje';
    } else if (_isMesmoDia(date, now.subtract(const Duration(days: 1)))) {
      return 'Ontem';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragDone: (details) async {
        for (final file in details.files) {
          if (_isImageFile(file)) {
            await _processarImagem(file);
          }
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(_grupoNome ?? 'Chat'),
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Menu de opções do grupo
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Lista de mensagens
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _mensagens.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Nenhuma mensagem ainda',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Envie a primeira mensagem!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _mensagens.length,
                        itemBuilder: (context, index) {
                          final mensagem = _mensagens[index];
                          final isMinhaMensagem = mensagem.usuarioId ==
                              (_chatService.currentUserId ?? 'anonymous');

                          // Verificar se precisa mostrar data
                          final mostrarData = index == 0 ||
                              !_isMesmoDia(
                                mensagem.createdAt,
                                _mensagens[index - 1].createdAt,
                              );

                          return Column(
                            children: [
                              if (mostrarData)
                                Container(
                                  margin: const EdgeInsets.symmetric(vertical: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _formatarData(mensagem.createdAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                              Align(
                                alignment: isMinhaMensagem
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: GestureDetector(
                                  onLongPress: () => _mostrarMenuMensagem(context, mensagem),
                                  child: Container(
                                    margin: EdgeInsets.only(
                                      left: isMinhaMensagem ? 60 : 8,
                                      right: isMinhaMensagem ? 8 : 60,
                                      bottom: 4,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMinhaMensagem
                                          ? const Color(0xFFDCF8C6) // Verde claro do WhatsApp
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (!isMinhaMensagem)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 4),
                                            child: Text(
                                              mensagem.usuarioNome ?? 'Usuário',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue[700],
                                              ),
                                            ),
                                          ),
                                        // Exibir mensagem respondida se houver
                                        if (mensagem.mensagemRespondidaId != null || mensagem.mensagemRespondida != null)
                                          _buildMensagemRespondida(mensagem),
                                        // Exibir localização se houver
                                        if (mensagem.tipo == 'localizacao' && mensagem.localizacao != null)
                                          _buildLocalizacaoWidget(mensagem),
                                        // Exibir anexo se houver
                                        if (mensagem.arquivoUrl != null && mensagem.arquivoUrl!.isNotEmpty)
                                          _buildAnexoWidget(mensagem),
                                        // Exibir conteúdo da mensagem (ou campo de edição)
                                        if (_mensagemEditandoId == mensagem.id)
                                          _buildCampoEdicao(mensagem)
                                        else if (mensagem.conteudo.isNotEmpty)
                                          _buildConteudoComMencoes(mensagem),
                                      const SizedBox(height: 4),
                                      // Hora da mensagem e indicador de edição
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          if (mensagem.updatedAt != null && 
                                              mensagem.updatedAt!.isAfter(mensagem.createdAt))
                                            Padding(
                                              padding: const EdgeInsets.only(right: 4),
                                              child: Text(
                                                'editado',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontStyle: FontStyle.italic,
                                                  color: Colors.grey[500],
                                                ),
                                              ),
                                            ),
                                          Text(
                                            _formatarHora(mensagem.createdAt),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
          ),
          // Preview da resposta (se houver)
          if (_mensagemRespondendo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 40,
                    color: Colors.blue[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _mensagemRespondendo!.usuarioNome ?? 'Usuário',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _mensagemRespondendo!.conteudo.isNotEmpty
                              ? _mensagemRespondendo!.conteudo
                              : (_mensagemRespondendo!.tipo == 'imagem' ? '📷 Imagem' :
                                 _mensagemRespondendo!.tipo == 'video' ? '🎥 Vídeo' :
                                 _mensagemRespondendo!.tipo == 'audio' ? '🎤 Áudio' :
                                 _mensagemRespondendo!.tipo == 'localizacao' ? '📍 Localização' : 'Arquivo'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _cancelarResposta,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          // Campo de input
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.attach_file),
                          onPressed: _mostrarOpcoesAnexo,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            focusNode: _focusNode,
                            onTap: () {
                              // Fechar emoji picker quando focar no campo de texto
                              if (_mostrarEmojiPicker) {
                                setState(() {
                                  _mostrarEmojiPicker = false;
                                });
                              }
                            },
                            decoration: InputDecoration(
                              hintText: _mensagemRespondendo != null 
                                  ? 'Digite sua resposta...'
                                  : 'Digite uma mensagem...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey[200],
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            maxLines: null,
                            textCapitalization: TextCapitalization.sentences,
                            onSubmitted: (_) => _enviarMensagem(),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _mostrarEmojiPicker ? Icons.keyboard : Icons.emoji_emotions,
                            color: _mostrarEmojiPicker ? Colors.blue : Colors.grey[600],
                          ),
                          onPressed: () {
                            setState(() {
                              _mostrarEmojiPicker = !_mostrarEmojiPicker;
                            });
                            if (_mostrarEmojiPicker) {
                              _focusNode.unfocus();
                            } else {
                              _focusNode.requestFocus();
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, color: Color(0xFF075E54)),
                          onPressed: _enviarMensagem,
                        ),
                      ],
                    ),
                    // Emoji picker
                    if (_mostrarEmojiPicker)
                      SizedBox(
                        height: 250,
                        child: EmojiPicker(
                          onEmojiSelected: (category, emoji) {
                            // Inserir emoji no campo de texto
                            final text = _messageController.text;
                            final selection = _messageController.selection;
                            final newText = text.replaceRange(
                              selection.start,
                              selection.end,
                              emoji.emoji,
                            );
                            _messageController.value = TextEditingValue(
                              text: newText,
                              selection: TextSelection.collapsed(
                                offset: selection.start + emoji.emoji.length,
                              ),
                            );
                          },
                          config: Config(
                            height: 256,
                            checkPlatformCompatibility: true,
                            emojiViewConfig: EmojiViewConfig(
                              emojiSizeMax: 28 * (kIsWeb ? 1.0 : (Platform.isIOS ? 1.20 : 1.0)),
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}

