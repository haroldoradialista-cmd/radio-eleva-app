import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../servicos/auth_service.dart';
import '../servicos/config_service.dart';
import '../servicos/player_service.dart';
import '../tema.dart';
import '../widgets/anuncio_banner.dart';
import '../widgets/enquete_card.dart';
import '../widgets/login_widget.dart';
import 'noticias_page.dart';
import 'despertador_page.dart';

class MenuPage extends StatelessWidget {
  MenuPage({super.key});

  void _sleep(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: CoresEleva.azulMedio,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(14),
              child: Text('Desligar a rádio em...',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            ...[15, 30, 45, 60, 90].map((m) => ListTile(
                  leading:
                      Icon(Icons.bedtime_rounded, color: CoresEleva.dourado),
                  title: Text('$m minutos'),
                  onTap: () {
                    PlayerService.instancia.definirSleep(m);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      duration: Duration(seconds: 3),
                      backgroundColor: CoresEleva.verdeEscuro,
                      content:
                          Text('⏰ A Rádio Eleva desligará em $m minutos'),
                    ));
                  },
                )),
            ListTile(
              leading:
                  Icon(Icons.close_rounded, color: CoresEleva.textoFraco),
              title: Text('Cancelar sleep timer'),
              onTap: () {
                // Captura o messenger ANTES de fechar o menu (senão o
                // context é removido e a tarja aparece vazia)
                final messenger = ScaffoldMessenger.of(context);
                PlayerService.instancia.definirSleep(0);
                Navigator.pop(context);
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(SnackBar(
                  backgroundColor: CoresEleva.verdeEscuro,
                  behavior: SnackBarBehavior.floating,
                  margin: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  duration: Duration(seconds: 3),
                  content: Row(
                    children: [
                      Icon(Icons.bedtime_off_rounded,
                          color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text('Sleep Timer Cancelado',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _abrirPagina(BuildContext context, String titulo, Widget corpo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.transparent,
          body: FundoEleva(
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back_rounded,
                            color: CoresEleva.dourado),
                      ),
                      Text(titulo,
                          style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: CoresEleva.branco)),
                    ],
                  ),
                  Expanded(child: corpo),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _abrirLink(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  IconData _iconeRede(String nome) {
    final n = nome.toLowerCase();
    if (n.contains('insta')) return Icons.camera_alt_rounded;
    if (n.contains('face')) return Icons.facebook_rounded;
    if (n.contains('you')) return Icons.play_circle_fill_rounded;
    if (n.contains('tiktok') || n.contains('tik tok') || n.contains('tik'))
      return Icons.music_note_rounded;
    if (n.contains('site')) return Icons.language_rounded;
    return Icons.public_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return FundoEleva(
      child: SafeArea(
        child: ValueListenableBuilder<AppConfig>(
          valueListenable: ConfigService.instancia.config,
          builder: (context, cfg, _) {
            return ListView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 20),
              children: [
                AnuncioBanner(),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.menu_rounded, color: CoresEleva.dourado),
                    SizedBox(width: 10),
                    Text('Menu',
                        style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
                SizedBox(height: 12),

                // ===== CONTA / LOGIN =====
                ValueListenableBuilder<Usuario?>(
                  valueListenable: AuthService.instancia.usuario,
                  builder: (context, u, _) {
                    return Container(
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: CoresEleva.azulMedio,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: CoresEleva.dourado.withOpacity(0.5)),
                      ),
                      child: u == null
                          ? Row(
                              children: [
                                Icon(Icons.account_circle_rounded,
                                    size: 38, color: CoresEleva.dourado),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                      'Entre para participar do chat e das promoções',
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          color: CoresEleva.brancoSuave)),
                                ),
                                ElevatedButton(
                                  onPressed: () => _abrirPagina(
                                      context,
                                      'Sua conta',
                                      SingleChildScrollView(
                                        child:
                                            ValueListenableBuilder<Usuario?>(
                                          valueListenable: AuthService
                                              .instancia.usuario,
                                          builder: (context, logado, _) {
                                            if (logado != null) {
                                              // Logou (Google ou e-mail):
                                              // fecha e volta ao Menu
                                              Future.microtask(() {
                                                if (Navigator.of(context)
                                                    .canPop()) {
                                                  Navigator.of(context)
                                                      .pop();
                                                }
                                              });
                                            }
                                            return LoginEleva(
                                                titulo:
                                                    'Entre ou crie sua conta');
                                          },
                                        ),
                                      )),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: CoresEleva.verde,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                  ),
                                  child: Text('ENTRAR',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800)),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Icon(Icons.verified_user_rounded,
                                    size: 34, color: CoresEleva.verde),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(u.nome,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: CoresEleva.branco)),
                                      Text(u.email,
                                          style: TextStyle(
                                              fontSize: 11.5,
                                              color:
                                                  CoresEleva.textoFraco)),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      AuthService.instancia.sair(),
                                  child: Text('Sair',
                                      style: TextStyle(
                                          color: Colors.red.shade300,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                    );
                  },
                ),
                SizedBox(height: 10),

                _itemMenu(context, Icons.newspaper_rounded, 'Notícias',
                    'Fique por dentro do que acontece',
                    () => _abrirPagina(context, 'Notícias', NoticiasPage())),
                _itemMenu(context, Icons.poll_rounded, 'Enquetes',
                    'Dê sua opinião e vote',
                    () => _abrirPagina(
                        context, 'Enquetes', PaginaEnquetes())),
                _itemMenu(context, Icons.alarm_rounded, 'Despertador',
                    'Acorde com a Rádio Eleva tocando',
                    () => _abrirPagina(
                        context, 'Despertador', DespertadorPage())),
                _itemMenu(context, Icons.bedtime_rounded, 'Sleep timer',
                    'Desligue a rádio automaticamente',
                    () => _sleep(context)),

                // ===== MODO CLARO/ESCURO =====
                ValueListenableBuilder<bool>(
                  valueListenable: modoEscuroNotifier,
                  builder: (context, escuro, _) {
                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: CoresEleva.azulMedio,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: CoresEleva.borda),
                      ),
                      child: SwitchListTile(
                        secondary: Icon(
                            escuro
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            color: CoresEleva.dourado),
                        title: Text('Modo escuro',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                                color: CoresEleva.branco)),
                        value: escuro,
                        activeColor: CoresEleva.verde,
                        onChanged: (_) => alternarTema(),
                      ),
                    );
                  },
                ),

                // ===== REDES SOCIAIS =====
                if (cfg.redes.isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CoresEleva.azulMedio,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: CoresEleva.borda),
                    ),
                    child: Column(
                      children: [
                        Text('Siga a Rádio Eleva',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: CoresEleva.branco)),
                        SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: cfg.redes
                              .where((r) =>
                                  (r['link'] ?? '').toString().trim().isNotEmpty)
                              .map((r) {
                            return IconButton(
                              onPressed: () => _abrirLink(r['link']),
                              icon: Icon(_iconeRede(r['nome'] ?? ''),
                                  color: CoresEleva.dourado, size: 28),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _itemMenu(BuildContext context, IconData icone, String titulo,
      String sub, VoidCallback aoTocar) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: CoresEleva.azulMedio,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CoresEleva.borda),
      ),
      child: ListTile(
        leading: Icon(icone, color: CoresEleva.dourado),
        title: Text(titulo,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                color: CoresEleva.branco)),
        subtitle: Text(sub,
            style: TextStyle(fontSize: 11.5, color: CoresEleva.textoFraco)),
        trailing:
            Icon(Icons.chevron_right_rounded, color: CoresEleva.dourado),
        onTap: aoTocar,
      ),
    );
  }
}


// ============================================================
// PÁGINA DE ENQUETES (com botão Atualizar)
// ============================================================
class PaginaEnquetes extends StatefulWidget {
  PaginaEnquetes({super.key});
  @override
  State<PaginaEnquetes> createState() => _PaginaEnquetesState();
}

class _PaginaEnquetesState extends State<PaginaEnquetes> {
  bool _atualizando = false;

  Future<void> _atualizar() async {
    setState(() => _atualizando = true);
    await ConfigService.instancia.carregar();
    if (mounted) {
      setState(() => _atualizando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: CoresEleva.verdeEscuro,
          duration: Duration(seconds: 2),
          content: Text('Enquetes atualizadas! ✅')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(right: 8),
          child: Row(
            children: [
              Spacer(),
              TextButton.icon(
                onPressed: _atualizando ? null : _atualizar,
                icon: _atualizando
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: CoresEleva.dourado))
                    : Icon(Icons.refresh_rounded,
                        size: 20, color: CoresEleva.dourado),
                label: Text('ATUALIZAR',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: CoresEleva.dourado)),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: CoresEleva.verde,
            onRefresh: () => ConfigService.instancia.carregar(),
            child: ListView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(top: 4, bottom: 20),
              children: [EnqueteCard()],
            ),
          ),
        ),
      ],
    );
  }
}
