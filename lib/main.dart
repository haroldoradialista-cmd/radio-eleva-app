import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'servicos/despertador_service.dart';
import 'servicos/presenca_service.dart';
import 'servicos/player_service.dart';
import 'tema.dart';

/// Mantém a tela do celular acesa por 1 minuto (renovável a cada toque),
/// para o ouvinte acompanhar o app sem a tela apagar no meio.
class WakelockEleva {
  static const _canal = MethodChannel('br.com.radioeleva/despertador');
  static Timer? _timer;

  static void ativarPorUmMinuto() {
    try {
      _canal.invokeMethod('manterTelaAcesa', {'ligar': true});
    } catch (_) {}
    _timer?.cancel();
    _timer = Timer(const Duration(minutes: 1), () {
      try {
        _canal.invokeMethod('manterTelaAcesa', {'ligar': false});
      } catch (_) {}
    });
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await JustAudioBackground.init(
    androidNotificationChannelId: 'br.com.radioeleva.audio',
    androidNotificationChannelName: 'Rádio Eleva',
    androidNotificationOngoing: true,
  );
  // Tarefas secundárias em segundo plano: NUNCA seguram a abertura do app
  NotificacoesService.iniciar().catchError((_) {});
  DespertadorService.iniciar().catchError((_) {});
  ConfigService.instancia.carregar().then((_) {
    ConfigService.instancia.iniciarAutoAtualizacao();
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
          locale: Locale('pt', 'BR'),
          supportedLocales: [Locale('pt', 'BR')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
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
  final PageController _pageCtrl = PageController();
  Timer? _telaAcesa;

  @override
  void initState() {
    super.initState();
    // Mantém a tela acesa por 1 minuto sempre que o app está em uso
    _manterTelaAcesa();
  }

  /// Mantém a tela ligada por 60s e renova a cada interação
  void _manterTelaAcesa() {
    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {}
    WakelockEleva.ativarPorUmMinuto();
  }

  /// Item do menu inferior — o selecionado ganha brilho dourado (glow)
  Widget _itemNav(int i, IconData icone, String rotulo) {
    final ativo = _abaAtual == i;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _irParaAba(i),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 280),
          curve: Curves.easeOut,
          margin: EdgeInsets.symmetric(horizontal: 2),
          padding: EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: ativo
                ? CoresEleva.dourado.withOpacity(0.16)
                : Colors.transparent,
            boxShadow: ativo
                ? [
                    BoxShadow(
                      color: CoresEleva.dourado.withOpacity(0.55),
                      blurRadius: 16,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone,
                  size: ativo ? 25 : 22,
                  color: ativo ? CoresEleva.dourado : CoresEleva.textoFraco),
              SizedBox(height: 2),
              Text(rotulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: ativo ? FontWeight.w900 : FontWeight.w600,
                      color: ativo
                          ? CoresEleva.dourado
                          : CoresEleva.textoFraco)),
            ],
          ),
        ),
      ),
    );
  }

  void _irParaAba(int i) {
    _manterTelaAcesa();
    setState(() => _abaAtual = i);
    _pageCtrl.animateToPage(i,
        duration: Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _telaAcesa?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Recriadas a cada build: garante que TODAS as abas troquem de tema
    // juntas (fundo, textos e cartões), sem perder o estado interno.
    final paginas = [
      HomePage(),
      ChatPage(),
      PromocoesPage(),
      ProgramacaoPage(),
      PedidosPage(),
      MenuPage(),
    ];
    return Scaffold(
      body: Listener(
        onPointerDown: (_) => _manterTelaAcesa(),
        child: PageView(
          controller: _pageCtrl,
          onPageChanged: (i) {
            _manterTelaAcesa();
            setState(() => _abaAtual = i);
          },
          children: paginas,
        ),
      ),
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
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _itemNav(0, Icons.home_rounded, 'Início'),
                  _itemNav(1, Icons.forum_rounded, 'Chat'),
                  _itemNav(2, Icons.card_giftcard_rounded, 'Promoções'),
                  _itemNav(3, Icons.calendar_month_rounded, 'Programação'),
                  _itemNav(4, Icons.music_note_rounded, 'Pedidos'),
                  _itemNav(5, Icons.menu_rounded, 'Menu'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
