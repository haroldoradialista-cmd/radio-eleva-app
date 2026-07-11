import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../servicos/auth_service.dart';
import '../servicos/config_service.dart';
import '../servicos/moderacao.dart';
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
                return u == null ? _TelaLogin() : _TelaChat(usuario: u);
              },
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// TELA DE LOGIN / CADASTRO
// ============================================================
class _TelaLogin extends StatefulWidget {
  _TelaLogin();
  @override
  State<_TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<_TelaLogin> {
  bool _cadastro = false;
  bool _ocupado = false;
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();

  Future<void> _executar(Future<String?> Function() acao) async {
    setState(() => _ocupado = true);
    final erro = await acao();
    if (mounted) {
      setState(() => _ocupado = false);
      if (erro != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Colors.red.shade700, content: Text(erro)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(28),
      child: Column(
        children: [
          SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset('assets/logo.png', width: 90, height: 90),
          ),
          SizedBox(height: 18),
          Text(_cadastro ? 'Crie sua conta' : 'Entre no bate-papo',
              style:
                  TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          SizedBox(height: 6),
          Text(
            'Converse com outros ouvintes da Rádio Eleva',
            textAlign: TextAlign.center,
            style: TextStyle(color: CoresEleva.brancoSuave),
          ),
          SizedBox(height: 26),

          // ---- Botão Google ----
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _ocupado
                  ? null
                  : () => _executar(AuthService.instancia.entrarComGoogle),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Color(0xFF1F1F1F),
                padding: EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                textStyle:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              icon: Text('G',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF4285F4))),
              label: Text('Entrar com Google'),
            ),
          ),

          SizedBox(height: 18),
          Row(children: [
            Expanded(child: Divider(color: CoresEleva.borda)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('ou', style: TextStyle(color: CoresEleva.textoFraco)),
            ),
            Expanded(child: Divider(color: CoresEleva.borda)),
          ]),
          SizedBox(height: 18),

          // ---- Formulário e-mail/senha ----
          if (_cadastro)
            _campo(_nome, 'Seu nome', Icons.person_rounded),
          _campo(_email, 'E-mail', Icons.email_rounded,
              teclado: TextInputType.emailAddress),
          _campo(_senha, 'Senha (mínimo 6 caracteres)', Icons.lock_rounded,
              senha: true),
          SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _ocupado
                  ? null
                  : () {
                      if (_cadastro && _nome.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Digite seu nome.')));
                        return;
                      }
                      _executar(() => _cadastro
                          ? AuthService.instancia.cadastrar(
                              _nome.text, _email.text, _senha.text)
                          : AuthService.instancia
                              .entrar(_email.text, _senha.text));
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: CoresEleva.verde,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                textStyle:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              child: _ocupado
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Text(_cadastro ? 'Cadastrar' : 'Entrar'),
            ),
          ),
          SizedBox(height: 14),
          TextButton(
            onPressed: () => setState(() => _cadastro = !_cadastro),
            child: Text(
              _cadastro
                  ? 'Já tenho conta — quero entrar'
                  : 'Não tem conta? Cadastre-se grátis',
              style: TextStyle(
                  color: CoresEleva.dourado, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campo(TextEditingController c, String rotulo, IconData icone,
      {bool senha = false, TextInputType? teclado}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        obscureText: senha,
        keyboardType: teclado,
        decoration: InputDecoration(
          hintText: rotulo,
          prefixIcon: Icon(icone, color: CoresEleva.dourado, size: 20),
          filled: true,
          fillColor: CoresEleva.azulMedio,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
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
    return Column(
      children: [
        // ===== AVISO DE CHAT PÚBLICO =====
        Container(
          margin: EdgeInsets.fromLTRB(12, 10, 12, 0),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: CoresEleva.dourado.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: CoresEleva.dourado.withOpacity(0.5), width: 1),
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
                      color: CoresEleva.brancoSuave),
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
              : ListView.builder(
                  controller: _scroll,
                  padding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  itemCount: _mensagens.length,
                  itemBuilder: (context, i) {
                    final m = _mensagens[i];
                    final minha = m['uid'] == widget.usuario.uid;
                    return Align(
                      alignment: minha
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        padding: EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(maxWidth: 290),
                        decoration: BoxDecoration(
                          color: minha
                              ? CoresEleva.verdeEscuro
                              : CoresEleva.azulMedio,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m['nome'] ?? 'Ouvinte',
                                style: TextStyle(
                                    color: CoresEleva.dourado,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12)),
                            SizedBox(height: 3),
                            Text(m['msg'] ?? '',
                                style: TextStyle(
                                    color: CoresEleva.branco)),
                          ],
                        ),
                      ),
                    );
                  },
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
