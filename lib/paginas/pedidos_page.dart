import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../servicos/config_service.dart';
import '../tema.dart';
import '../widgets/anuncio_banner.dart';

class PedidosPage extends StatelessWidget {
  PedidosPage({super.key});

  Future<void> _abrirZapDireto(BuildContext context, AppConfig cfg) async {
    if (cfg.whatsapp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('WhatsApp ainda não configurado. Aguarde!')));
      return;
    }
    final numero = cfg.whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse(
        'https://wa.me/$numero?text=${Uri.encodeComponent('Olá, Rádio Eleva! 👋')}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return FundoEleva(
      child: SafeArea(
        child: ValueListenableBuilder<AppConfig>(
          valueListenable: ConfigService.instancia.config,
          builder: (context, cfg, _) {
            return ListView(
              padding: EdgeInsets.all(20),
              children: [
                AnuncioBanner(),
                SizedBox(height: 10),
                Center(
                  child: Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          colors: [CoresEleva.verde, CoresEleva.verdeEscuro]),
                      boxShadow: [
                        BoxShadow(
                            color: CoresEleva.verde.withOpacity(0.4),
                            blurRadius: 28),
                      ],
                    ),
                    child: Icon(Icons.music_note_rounded,
                        size: 50, color: Colors.white),
                  ),
                ),
                SizedBox(height: 20),
                Center(
                  child: Text('Fale com a gente',
                      style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          color: CoresEleva.branco)),
                ),
                SizedBox(height: 24),
                _cartaoOpcao(
                  context,
                  icone: Icons.queue_music_rounded,
                  titulo: 'PEÇA SUA MÚSICA',
                  descricao:
                      'Seu pedido chega direto no estúdio da Rádio Eleva.',
                  aoTocar: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => PedidoMusicaPage(cfg: cfg)),
                  ),
                ),
                SizedBox(height: 14),
                _cartaoOpcao(
                  context,
                  icone: Icons.chat_rounded,
                  titulo: 'FALE COM A RÁDIO ELEVA',
                  descricao:
                      'Recados, oração, anúncios e parcerias — direto no nosso WhatsApp.',
                  aoTocar: () => _abrirZapDireto(context, cfg),
                ),
                SizedBox(height: 18),
                Center(
                  child: Text('Atendemos durante a programação ao vivo 🎶',
                      style:
                          TextStyle(fontSize: 12, color: CoresEleva.dourado)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _cartaoOpcao(BuildContext context,
      {required IconData icone,
      required String titulo,
      required String descricao,
      required VoidCallback aoTocar}) {
    return GestureDetector(
      onTap: aoTocar,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CoresEleva.azulMedio,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CoresEleva.borda, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: CoresEleva.botaoPlay,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icone, color: Colors.white, size: 26),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: CoresEleva.branco)),
                  SizedBox(height: 3),
                  Text(descricao,
                      style: TextStyle(
                          fontSize: 12.5, color: CoresEleva.brancoSuave)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: CoresEleva.dourado, size: 26),
          ],
        ),
      ),
    );
  }
}

// Deixa tudo em CAIXA ALTA enquanto o ouvinte digita
class MaiusculasFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue anterior, TextEditingValue novo) {
    return TextEditingValue(
      text: novo.text.toUpperCase(),
      selection: novo.selection,
    );
  }
}

// ============================================================
// FORMULÁRIO DE PEDIDO MUSICAL (vai direto para o Painel Eleva)
// ============================================================
class PedidoMusicaPage extends StatefulWidget {
  final AppConfig cfg;
  PedidoMusicaPage({super.key, required this.cfg});
  @override
  State<PedidoMusicaPage> createState() => _PedidoMusicaPageState();
}

class _PedidoMusicaPageState extends State<PedidoMusicaPage> {
  final _nome = TextEditingController();
  final _musica = TextEditingController();
  final _interprete = TextEditingController();
  final _bairro = TextEditingController();
  bool _enviando = false;

  Future<void> _enviar() async {
    if (_nome.text.trim().isEmpty ||
        _musica.text.trim().isEmpty ||
        _interprete.text.trim().isEmpty ||
        _bairro.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red.shade700,
          duration: Duration(seconds: 3),
          content: Text(
              'Preencha TODOS os campos (seu nome, a música, o intérprete e o bairro) para enviar o pedido.')));
      return;
    }
    if (widget.cfg.chatUrl.isEmpty || _enviando) return;
    setState(() => _enviando = true);
    try {
      final base = widget.cfg.chatUrl.replaceAll(RegExp(r'/chat/?$'), '');
      await http.post(
        Uri.parse('$base/pedidos_musicais.json'),
        body: jsonEncode({
          'nome': _nome.text.trim(),
          'musica': _musica.text.trim(),
          'interprete': _interprete.text.trim(),
          'bairro': _bairro.text.trim(),
          'quando': DateTime.now().toIso8601String(),
        }),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: CoresEleva.verdeEscuro,
            content: Text(
                'Pedido enviado ao estúdio! Fique ligado na programação 🎶')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Falha ao enviar. Verifique sua internet.')));
      }
    }
    if (mounted) setState(() => _enviando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FundoEleva(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_rounded,
                        color: CoresEleva.dourado),
                  ),
                  Text('Peça sua música',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: CoresEleva.branco)),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Preencha os campos e toque em enviar — seu pedido chega direto no estúdio da Rádio Eleva.',
                style: TextStyle(fontSize: 13, color: CoresEleva.brancoSuave),
              ),
              SizedBox(height: 20),
              _campo(_nome, 'NOME DO OUVINTE', Icons.person_rounded),
              _campo(_musica, 'MÚSICA', Icons.music_note_rounded),
              _campo(_interprete, 'INTÉRPRETE', Icons.mic_rounded),
              _campo(_bairro, 'SEU BAIRRO', Icons.location_on_rounded),
              SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _enviando ? null : _enviar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CoresEleva.verde,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    textStyle:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  icon: _enviando
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : Icon(Icons.send_rounded, size: 22),
                  label: Text(_enviando ? 'ENVIANDO...' : 'ENVIAR'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _campo(TextEditingController c, String rotulo, IconData icone) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: c,
        textCapitalization: TextCapitalization.characters,
        inputFormatters: [MaiusculasFormatter()],
        decoration: InputDecoration(
          labelText: rotulo,
          labelStyle: TextStyle(color: CoresEleva.textoFraco),
          prefixIcon: Icon(icone, color: CoresEleva.dourado, size: 20),
          filled: true,
          fillColor: CoresEleva.azulMedio,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
