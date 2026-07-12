import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../servicos/auth_service.dart';
import '../servicos/config_service.dart';
import '../servicos/moderacao.dart';
import '../widgets/login_widget.dart';
import '../widgets/anuncio_banner.dart';
import 'package:just_audio/just_audio.dart';
import '../servicos/player_service.dart';
import '../tema.dart';

class ChatPage extends StatefulWidget {
  ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  @override
  void initState() {
    super.initState();
    AuthService.instancia.restaurarSessao();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: CoresEleva.fundoApp),
      child: SafeArea(
        child: ValueListenableBuilder<AppConfig>(
          valueListenable: ConfigService.instancia.config,
          builder: (context, cfg, _) {
            if (cfg.chatUrl.isEmpty) {
              return _AvisoEmBreve();
            }
            return ValueListenableBuilder<Usuario?>(
              valueListenable: AuthService.instancia.usuario,
              builder: (context, u, _) {
                return u == null
                    ? SingleChildScrollView(child: LoginEleva(titulo: 'Entre no bate-papo'))
                    : _TelaChat(usuario: u);
              },
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// TELA DO CHAT (usuário logado)
// ============================================================
class _TelaChat extends StatefulWidget {
  final Usuario usuario;
  _TelaChat({required this.usuario});
  @override
  State<_TelaChat> createState() => _TelaChatState();
}

class _TelaChatState extends State<_TelaChat> {
  final _msg = TextEditingController();
  final _scroll = ScrollController();
  Timer? _timer;
  List<Map<String, dynamic>> _mensagens = [];
  bool _enviando = false;
  int _suspensoAte = 0; // epoch em milissegundos; 0 = livre

  String get _chatUrl => ConfigService.instancia.config.value.chatUrl;
  String get _baseRtdb => _chatUrl.replaceAll(RegExp(r'/chat/?$'), '');

  @override
  void initState() {
    super.initState();
    _verificarSuspensao();
    _buscar();
    _timer = Timer.periodic(Duration(seconds: 5), (_) => _buscar());
  }

  Future<void> _verificarSuspensao() async {
    try {
      final r = await http.get(Uri.parse(
          '$_baseRtdb/chat_suspensos/${widget.usuario.uid}.json'));
      if (r.statusCode == 200 && r.body != 'null') {
        final d = jsonDecode(r.body);
        final ate = int.tryParse((d['ate'] ?? '0').toString()) ?? 0;
        if (mounted && ate > DateTime.now().millisecondsSinceEpoch) {
          setState(() => _suspensoAte = ate);
        }
      }
    } catch (_) {}
  }

  Future<void> _suspender() async {
    final cfg = ConfigService.instancia.config.value;
    final ate = DateTime.now().millisecondsSinceEpoch +
        cfg.chatSuspensaoHoras * 3600 * 1000;
    try {
      await http.put(
        Uri.parse('$_baseRtdb/chat_suspensos/${widget.usuario.uid}.json'),
        body: jsonEncode({
          'nome': widget.usuario.nome,
          'ate': ate,
          'quando': DateTime.now().toIso8601String(),
        }),
      );
    } catch (_) {}
    if (mounted) setState(() => _suspensoAte = ate);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _msg.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    try {
      final r = await http.get(Uri.parse(
          '$_chatUrl.json?orderBy=%22%24key%22&limitToLast=80'));
      if (r.statusCode == 200 && r.body != 'null') {
        final dados = jsonDecode(r.body) as Map<String, dynamic>;
        final chaves = dados.keys.toList()..sort();
        final lista =
            chaves.map((k) => Map<String, dynamic>.from(dados[k])).toList();
        if (mounted && lista.length != _mensagens.length) {
          setState(() => _mensagens = lista);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scroll.hasClients) {
              _scroll.jumpTo(_scroll.position.maxScrollExtent);
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _enviar() async {
    final texto = _msg.text.trim();
    if (texto.isEmpty || _enviando) return;
    if (_suspensoAte > DateTime.now().millisecondsSinceEpoch) return;
    final cfg = ConfigService.instancia.config.value;
    if (contemPalavraOfensiva(texto, cfg.chatPalavras)) {
      _msg.clear();
      await _suspender();
      return;
    }
    setState(() => _enviando = true);
    try {
      final token = await AuthService.instancia.tokenValido();
      await http.post(
        Uri.parse('$_chatUrl.json?auth=$token'),
        body: jsonEncode({
          'nome': widget.usuario.nome,
          'uid': widget.usuario.uid,
          'msg': texto,
          'quando': DateTime.now().toIso8601String(),
        }),
      );
      _msg.clear();
      await _buscar();
    } catch (_) {}
    if (mounted) setState(() => _enviando = false);
  }

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now().millisecondsSinceEpoch;
    if (_suspensoAte > agora) {
      final volta = DateTime.fromMillisecondsSinceEpoch(_suspensoAte);
      final dd = volta.day.toString().padLeft(2, '0');
      final mm = volta.month.toString().padLeft(2, '0');
      final hh = volta.hour.toString().padLeft(2, '0');
      final mi = volta.minute.toString().padLeft(2, '0');
      return Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block_rounded, size: 64, color: Colors.red.shade400),
              SizedBox(height: 16),
              Text('Acesso ao chat suspenso',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              SizedBox(height: 10),
              Text(
                'Detectamos o uso de linguagem imprópria. Seu acesso ao bate-papo foi suspenso automaticamente até $dd/$mm às $hh:$mi.',
                textAlign: TextAlign.center,
                style: TextStyle(color: CoresEleva.brancoSuave, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }
    final playerEleva = PlayerService.instancia.player;
    final cfgEleva = ConfigService.instancia.config.value;
    return Column(
      children: [
        AnuncioBanner(),
        // ===== MINI PLAYER (modelo enviado) =====
        Container(
          margin: EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: CoresEleva.azulMedio,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: CoresEleva.dourado.withOpacity(0.6)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child:
                    Image.asset('assets/logo.png', width: 40, height: 40),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cfgEleva.nome,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: CoresEleva.branco)),
                    StreamBuilder<IcyMetadata?>(
                      stream: playerEleva.icyMetadataStream,
                      builder: (context, snap) {
                        final t = snap.data?.info?.title?.trim() ?? '';
                        return Text(t.isEmpty ? 'Ao vivo' : t,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11,
                                color: CoresEleva.textoFraco));
                      },
                    ),
                  ],
                ),
              ),
              StreamBuilder<PlayerState>(
                stream: playerEleva.playerStateStream,
                builder: (context, snap) {
                  final tocando = snap.data?.playing ?? false;
                  return GestureDetector(
                    onTap: () async {
                      await PlayerService.instancia.carregar(
                          cfgEleva.streamUrl,
                          cfgEleva.nome,
                          cfgEleva.logoUrl);
                      await PlayerService.instancia.alternar();
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: CoresEleva.dourado, width: 2),
                      ),
                      child: Icon(
                          tocando
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: CoresEleva.dourado,
                          size: 26),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        // ===== AVISO DE CHAT PÚBLICO =====
        Container(
          margin: EdgeInsets.fromLTRB(12, 10, 12, 0),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: CoresEleva.avisoFundo,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: CoresEleva.dourado.withOpacity(0.6), width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_rounded, size: 16, color: CoresEleva.dourado),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Você está em um chat público. Não compartilhe seu número de contato nem dados pessoais. O uso de palavras ofensivas e de baixo calão suspenderá automaticamente o seu acesso.',
                  style: TextStyle(
                      fontSize: 10.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: CoresEleva.avisoTexto),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(14, 14, 8, 8),
          child: Row(
            children: [
              Icon(Icons.forum_rounded, color: CoresEleva.dourado),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bate-papo dos ouvintes',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text('Você está como ${widget.usuario.nome}',
                        style: TextStyle(
                            fontSize: 12, color: CoresEleva.dourado)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Sair da conta',
                onPressed: () => AuthService.instancia.sair(),
                icon: Icon(Icons.logout_rounded,
                    color: CoresEleva.textoFraco, size: 20),
              ),
            ],
          ),
        ),
        Expanded(
          child: _mensagens.isEmpty
              ? Center(
                  child: Text('Seja o primeiro a mandar uma mensagem! 🙌'))
              : RefreshIndicator(
                  color: CoresEleva.verde,
                  onRefresh: _buscar,
                  child: ListView.builder(
                  physics: AlwaysScrollableScrollPhysics(),
                  controller: _scroll,
                  padding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  itemCount: _mensagens.length,
                  itemBuilder: (context, i) {
                    final m = _mensagens[i];
                    final minha = m['uid'] == widget.usuario.uid;
                    final nome = (m['nome'] ?? 'Ouvinte').toString();
                    final inicial =
                        nome.isNotEmpty ? nome[0].toUpperCase() : 'O';
                    final cores = [
                      Colors.teal,
                      Colors.indigo,
                      Colors.deepPurple,
                      Colors.green.shade700,
                      Colors.orange.shade800,
                      Colors.pink.shade700,
                    ];
                    final corAvatar =
                        cores[nome.codeUnits.fold(0, (a, b) => a + b) %
                            cores.length];
                    String hora = '';
                    final q = (m['quando'] ?? '').toString();
                    if (q.length >= 16) hora = q.substring(11, 16);
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 19,
                            backgroundColor: corAvatar,
                            child: Text(inicial,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16)),
                          ),
                          SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(maxWidth: 290),
                              decoration: BoxDecoration(
                                color: CoresEleva.azulMedio,
                                border: minha
                                    ? Border.all(
                                        color: CoresEleva.dourado
                                            .withOpacity(0.7),
                                        width: 1)
                                    : null,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(4),
                                  topRight: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(nome,
                                      style: TextStyle(
                                          color: CoresEleva.dourado,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12.5)),
                                  SizedBox(height: 3),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(m['msg'] ?? '',
                                            style: TextStyle(
                                                color:
                                                    CoresEleva.branco)),
                                      ),
                                      SizedBox(width: 8),
                                      Text(hora,
                                          style: TextStyle(
                                              fontSize: 10,
                                              color:
                                                  CoresEleva.textoFraco)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  ),
                ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msg,
                  maxLength: 200,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Escreva sua mensagem...',
                    filled: true,
                    fillColor: CoresEleva.azulMedio,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                  ),
                  onSubmitted: (_) => _enviar(),
                ),
              ),
              SizedBox(width: 8),
              GestureDetector(
                onTap: _enviar,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: CoresEleva.botaoPlay,
                    shape: BoxShape.circle,
                  ),
                  child: _enviando
                      ? Padding(
                          padding: EdgeInsets.all(13),
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.2))
                      : Icon(Icons.send_rounded,
                          color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
class _AvisoEmBreve extends StatelessWidget {
  _AvisoEmBreve();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_rounded, size: 64, color: CoresEleva.dourado),
            SizedBox(height: 16),
            Text('Chat em breve!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text(
              'O bate-papo entre os ouvintes será ativado em breve. Aguarde!',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
