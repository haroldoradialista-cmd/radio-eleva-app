import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../servicos/config_service.dart';
import '../tema.dart';

class PedidosPage extends StatelessWidget {
  PedidosPage({super.key});

  Future<void> _abrirWhatsApp(BuildContext context, AppConfig cfg) async {
    if (cfg.whatsapp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('WhatsApp ainda não configurado. Aguarde!')));
      return;
    }
    final numero = cfg.whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse(
        'https://wa.me/$numero?text=${Uri.encodeComponent(cfg.mensagemPedido)}');
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
            return Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [CoresEleva.verde, CoresEleva.verdeEscuro],
                        ),
                        boxShadow: [
                          BoxShadow(
                              color: CoresEleva.verde.withOpacity(0.4),
                              blurRadius: 30),
                        ],
                      ),
                      child: Icon(Icons.music_note_rounded,
                          size: 56, color: Colors.white),
                    ),
                    SizedBox(height: 26),
                    Text('Pedido Musical',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800)),
                    SizedBox(height: 10),
                    Text(
                      'Quer ouvir sua música na Rádio Eleva?\nMande seu pedido direto pelo WhatsApp e participe da programação!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, height: 1.5),
                    ),
                    SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _abrirWhatsApp(context, cfg),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                          textStyle: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        icon: Icon(Icons.chat_rounded, size: 24),
                        label: Text('Pedir música no WhatsApp'),
                      ),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Atendemos durante a programação ao vivo 🎶',
                      style: TextStyle(
                          fontSize: 12, color: CoresEleva.dourado),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
