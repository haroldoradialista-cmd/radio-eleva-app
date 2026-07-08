import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../servicos/auth_service.dart';
import '../servicos/config_service.dart';
import '../tema.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
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
      decoration: const BoxDecoration(gradient: CoresEleva.fundoApp),
      child: SafeArea(
        child: ValueListenableBuilder<Usuario?>(
          valueListenable: AuthService.instancia.usuario,
          builder: (context, u, _) {
            if (ConfigService.instancia.config.value.chatUrl.isEmpty) {
              return const _AvisoEmBreve();
            }
            return u == null ? const _TelaLogin() : _TelaChat(usuario: u);
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
  const _TelaLogin();
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
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset('assets/logo.png', width: 90, height: 90),
          ),
          const SizedBox(height: 18),
          Text(_cadastro ? 'Crie sua conta' : 'Entre no bate-papo',
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text(
            'Converse com outros ouvintes da Rádio Eleva',
            textAlign: TextAlign.center,
            style: TextStyle(color: CoresEleva.brancoSuave),
          ),
          const SizedBox(height: 26),

          // ---- Botão Google ----
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _ocupado
                  ? null
                  : () => _executar(AuthService.instancia.entrarComGoogle),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1F1F1F),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              icon: const Text('G',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF4285F4))),
              label: const Text('Entrar com Google'),
            ),
          ),

          const SizedBox(height: 18),
          Row(children: const [
            Expanded(child: Divider(color: Colors.white24)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('ou', style: TextStyle(color: Colors.white54)),
            ),
            Expanded(child: Divider(color: Colors.white24)),
          ]),
          const SizedBox(height: 18),

          // ---- Formulário e-mail/senha ----
          if (_cadastro)
            _campo(_nome, 'Seu nome', Icons.person_rounded),
          _campo(_email, 'E-mail', Icons.email_rounded,
              teclado: TextInputType.emailAddress),
          _campo(_senha, 'Senha (mínimo 6 caracteres)', Icons.lock_rounded,
              senha: true),
          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _ocupado
                  ? null
                  : () {
                      if (_cadastro && _nome.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
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
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              child: _ocupado
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Text(_cadastro ? 'Cadastrar' : 'Entrar'),
            ),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () => setState(() => _cadastro = !_cadastro),
            child: Text(
              _cadastro
                  ? 'Já tenho conta — quero entrar'
                  : 'Não tem conta? Cadastre-se grátis',
              style: const TextStyle(
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
      padding: const EdgeInsets.only(bottom: 12),
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
  const _TelaChat({required this.usuario});
  @override
  State<_TelaChat> createState() => _TelaChatState();
}

class _TelaChatState extends State<_TelaChat> {
  final _msg = TextEditingController();
  final _scroll = ScrollController();
  Timer? _timer;
  List<Map<String, dynamic>> _mensagens = [];
  bool _enviando = false;

  String get _chatUrl => ConfigService.instancia.config.value.chatUrl;

  @override
  void initState() {
    super.initState();
    _buscar();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _buscar());
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 8),
          child: Row(
            children: [
              const Icon(Icons.forum_rounded, color: CoresEleva.dourado),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bate-papo dos ouvintes',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text('Você está como ${widget.usuario.nome}',
                        style: const TextStyle(
                            fontSize: 12, color: CoresEleva.dourado)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Sair da conta',
                onPressed: () => AuthService.instancia.sair(),
                icon: const Icon(Icons.logout_rounded,
                    color: Colors.white54, size: 20),
              ),
            ],
          ),
        ),
        Expanded(
          child: _mensagens.isEmpty
              ? const Center(
                  child: Text('Seja o primeiro a mandar uma mensagem! 🙌'))
              : ListView.builder(
                  controller: _scroll,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  itemCount: _mensagens.length,
                  itemBuilder: (context, i) {
                    final m = _mensagens[i];
                    final minha = m['uid'] == widget.usuario.uid;
                    return Align(
                      alignment: minha
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        constraints: const BoxConstraints(maxWidth: 290),
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
                                style: const TextStyle(
                                    color: CoresEleva.dourado,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12)),
                            const SizedBox(height: 3),
                            Text(m['msg'] ?? '',
                                style: const TextStyle(
                                    color: CoresEleva.branco)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
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
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                  ),
                  onSubmitted: (_) => _enviar(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _enviar,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    gradient: CoresEleva.botaoPlay,
                    shape: BoxShape.circle,
                  ),
                  child: _enviando
                      ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.2))
                      : const Icon(Icons.send_rounded,
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
  const _AvisoEmBreve();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
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
