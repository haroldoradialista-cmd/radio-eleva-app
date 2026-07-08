import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../servicos/config_service.dart';
import '../tema.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controllerMsg = TextEditingController();
  final _controllerNome = TextEditingController();
  final _scroll = ScrollController();
  Timer? _timer;
  List<Map<String, dynamic>> _mensagens = [];
  String _apelido = '';
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _buscar();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _buscar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controllerMsg.dispose();
    _controllerNome.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String get _chatUrl => ConfigService.instancia.config.value.chatUrl;

  Future<void> _buscar() async {
    if (_chatUrl.isEmpty) return;
    try {
      final r = await http.get(Uri.parse(
          '$_chatUrl.json?orderBy=%22%24key%22&limitToLast=80'));
      if (r.statusCode == 200 && r.body != 'null') {
        final dados = jsonDecode(r.body) as Map<String, dynamic>;
        final chaves = dados.keys.toList()..sort();
        final lista = chaves
            .map((k) => Map<String, dynamic>.from(dados[k]))
            .toList();
        if (mounted) {
          final desceu = _mensagens.length != lista.length;
          setState(() => _mensagens = lista);
          if (desceu) _descerLista();
        }
      }
    } catch (_) {}
  }

  void _descerLista() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _enviar() async {
    final texto = _controllerMsg.text.trim();
    if (texto.isEmpty || _chatUrl.isEmpty || _enviando) return;
    if (_apelido.isEmpty) {
      _pedirApelido();
      return;
    }
    setState(() => _enviando = true);
    try {
      await http.post(
        Uri.parse('$_chatUrl.json'),
        body: jsonEncode({
          'nome': _apelido,
          'msg': texto,
          'quando': DateTime.now().toIso8601String(),
        }),
      );
      _controllerMsg.clear();
      await _buscar();
    } catch (_) {}
    if (mounted) setState(() => _enviando = false);
  }

  void _pedirApelido() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CoresEleva.azulMedio,
        title: const Text('Como você quer aparecer no chat?'),
        content: TextField(
          controller: _controllerNome,
          maxLength: 20,
          decoration: const InputDecoration(hintText: 'Seu nome ou apelido'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final n = _controllerNome.text.trim();
              if (n.isNotEmpty) {
                setState(() => _apelido = n);
                Navigator.pop(context);
                _enviar();
              }
            },
            child: const Text('Entrar no chat',
                style: TextStyle(color: CoresEleva.verde)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: CoresEleva.fundoApp),
      child: SafeArea(
        child: _chatUrl.isEmpty
            ? _avisoEmBreve()
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(Icons.forum_rounded,
                            color: CoresEleva.dourado),
                        const SizedBox(width: 10),
                        Text('Bate-papo dos ouvintes',
                            style:
                                Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _mensagens.isEmpty
                        ? const Center(
                            child: Text(
                                'Seja o primeiro a mandar uma mensagem! 🙌'))
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            itemCount: _mensagens.length,
                            itemBuilder: (context, i) {
                              final m = _mensagens[i];
                              final minha = m['nome'] == _apelido;
                              return Align(
                                alignment: minha
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  constraints:
                                      const BoxConstraints(maxWidth: 290),
                                  decoration: BoxDecoration(
                                    color: minha
                                        ? CoresEleva.verdeEscuro
                                        : CoresEleva.azulMedio,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                            controller: _controllerMsg,
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
                            child: const Icon(Icons.send_rounded,
                                color: Colors.white, size: 22),
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

  Widget _avisoEmBreve() {
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
