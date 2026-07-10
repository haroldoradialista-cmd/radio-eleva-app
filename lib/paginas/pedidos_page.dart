import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../servicos/config_service.dart';
import '../tema.dart';

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
    return Container(
      decoration: BoxDecoration(gradient: CoresEleva.fundoApp),
      child: SafeArea(
        child: ValueListenableBuilder<AppConfig>(
          valueListenable: ConfigService.instancia.config,
          builder: (context, cfg, _) {
            return ListView(
              padding: EdgeInsets.all(20),
              children: [
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

                // ===== CARTÃO: PEÇA SUA MÚSICA =====
                _cartaoOpcao(
                  context,
                  icone: Icons.queue_music_rounded,
                  titulo: 'PEÇA SUA MÚSICA',
                  descricao:
                      'Preencha seu pedido e ele chega organizadinho no estúdio.',
                  aoTocar: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => PedidoMusicaPage(cfg: cfg)),
                  ),
                ),
                SizedBox(height: 14),

                // ===== CARTÃO: FALE COM A RÁDIO =====
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
                      style: TextStyle(
                          fontSize: 12, color: CoresEleva.dourado)),
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

// ============================================================
// TELA DO FORMULÁRIO DE PEDIDO MUSICAL
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

  Future<void> _enviar() async {
    if (_nome.text.trim().isEmpty || _musica.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Preencha pelo menos seu nome e a música.')));
      return;
    }
    if (widget.cfg.whatsapp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('WhatsApp ainda não configurado.')));
      return;
    }
    final numero = widget.cfg.whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
    final texto = '🎵 *PEDIDO MUSICAL*\n'
        '👤 Ouvinte: ${_nome.text.trim()}\n'
        '🎶 Música: ${_musica.text.trim()}\n'
        '🎤 Intérprete: ${_interprete.text.trim().isEmpty ? '-' : _interprete.text.trim()}';
    final uri = Uri.parse(
        'https://wa.me/$numero?text=${Uri.encodeComponent(texto)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: CoresEleva.fundoApp),
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
                'Preencha os campos e toque em enviar — seu pedido chega direto no WhatsApp da Rádio Eleva.',
                style:
                    TextStyle(fontSize: 13, color: CoresEleva.brancoSuave),
              ),
              SizedBox(height: 20),
              _campo(_nome, 'Nome do ouvinte', Icons.person_rounded),
              _campo(_musica, 'Música', Icons.music_note_rounded),
              _campo(_interprete, 'Intérprete', Icons.mic_rounded),
              SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _enviar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    textStyle: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  icon: Icon(Icons.send_rounded, size: 22),
                  label: Text('ENVIAR'),
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
