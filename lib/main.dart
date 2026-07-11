import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'paginas/home_page.dart';
import 'paginas/programacao_page.dart';
import 'paginas/promocoes_page.dart';
import 'paginas/chat_page.dart';
import 'paginas/pedidos_page.dart';
import 'paginas/menu_page.dart';
import 'servicos/config_service.dart';
import 'servicos/analytics_service.dart';
import 'servicos/notificacoes_service.dart';
import 'servicos/presenca_service.dart';
import 'servicos/player_service.dart';
import 'tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await JustAudioBackground.init(
    androidNotificationChannelId: 'br.com.radioeleva.audio',
    androidNotificationChannelName: 'Rádio Eleva',
    androidNotificationOngoing: true,
  );
  MobileAds.instance.initialize();
  await NotificacoesService.iniciar();
  ConfigService.instancia.carregar().then((_) {
    AnalyticsService.registrarAcesso();
    PresencaService.iniciar();
    // AUTOPLAY: a rádio começa a tocar assim que o app abre
    final cfg = ConfigService.instancia.config.value;
    if (cfg.streamUrl.isNotEmpty) {
      PlayerService.instancia
          .carregar(cfg.streamUrl, cfg.nome, cfg.logoUrl)
          .then((_) => PlayerService.instancia.player.play());
    }
  });
  await carregarTemaSalvo();
  runApp(RadioElevaApp());
}

class RadioElevaApp extends StatelessWidget {
  RadioElevaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: modoEscuroNotifier,
      builder: (context, escuro, _) {
        CoresEleva.escuro = escuro;
        return MaterialApp(
          title: 'Rádio Eleva',
          debugShowCheckedModeBanner: false,
          theme: temaEleva(),
          home: TelaPrincipal(),
        );
      },
    );
  }
}

class TelaPrincipal extends StatefulWidget {
  TelaPrincipal({super.key});
  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  int _abaAtual = 0;

  final _paginas = [
    HomePage(),
    ChatPage(),
    PromocoesPage(),
    ProgramacaoPage(),
    PedidosPage(),
    MenuPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _abaAtual, children: _paginas),
      bottomNavigationBar: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: CoresEleva.navFundo,
            border:
                Border(top: BorderSide(color: CoresEleva.dourado, width: 1.2)),
          ),
          child: BottomNavigationBar(
            currentIndex: _abaAtual,
            onTap: (i) => setState(() => _abaAtual = i),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: CoresEleva.dourado,
            unselectedItemColor: CoresEleva.textoFraco,
            selectedFontSize: 9.5,
            unselectedFontSize: 9.5,
            selectedLabelStyle: TextStyle(fontWeight: FontWeight.w800),
            items: [
              BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded), label: 'Início'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.forum_rounded), label: 'Chat'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.card_giftcard_rounded),
                  label: 'Promoções'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_month_rounded),
                  label: 'Programação'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.music_note_rounded), label: 'Pedidos'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.menu_rounded), label: 'Menu'),
            ],
          ),
        ),
      ),
    );
  }
}
