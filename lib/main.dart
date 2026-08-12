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
import 'paginas/tv_page.dart';
import 'paginas/menu_page.dart';
import 'widgets/campanha_popup.dart';
import 'servicos/config_service.dart';
import 'servicos/analytics_service.dart';
import 'servicos/notificacoes_service.dart';
import 'servicos/despertador_service.dart';
import 'servicos/despertadores_lista.dart';
import 'servicos/presenca_service.dart';
import 'servicos/player_service.dart';
import 'tema.dart';

/// Mantém a tela do celular acesa por 1 minuto (renovável a cada toque),
/// para o ouvinte acompanhar o app sem a tela apagar no meio.
class WakelockEleva {
  static const _canal = MethodChannel('br.com.radioeleva/despertador');
  static Timer? _timer;

  /// Mantém a tela do celular acesa por 1 minuto (renovável a cada toque).
  /// Depois de 1 minuto sem interação, o próprio Android apaga a tela
  /// normalmente, no tempo configurado pelo usuário — o app NÃO esmaece.
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
  DespertadorService.iniciar().then((_) async {
    // depois do handoff, recalcula qual e o proximo despertador a tocar
    try {
      final lista = await DespertadoresLista.carregar();
      await DespertadoresLista.reagendarProximo(lista);
    } catch (_) {}
  }).catchError((_) {});
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

class _TelaPrincipalState extends State<TelaPrincipal>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const int _abaTv = 4;
  int _abaAtual = 0;
  final PageController _pageCtrl = PageController();
  Timer? _telaAcesa;
  late final AnimationController _pulso;
  DateTime? _saiuEm; // quando o app foi para segundo plano

  @override
  void initState() {
    super.initState();
    // pulso do "AO VIVO" na aba TV
    _pulso = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    // Mantém a tela acesa por 1 minuto sempre que o app está em uso
    _manterTelaAcesa();
    // ATENCAO: o Android costuma MANTER o app vivo em segundo plano. Quando o
    // ouvinte "fecha" e abre de novo, o initState NAO roda outra vez — por
    // isso o comercial de abertura nao reaparecia. Observamos o ciclo de vida
    // para mostrar o banner tambem quando o app volta do segundo plano.
    WidgetsBinding.instance.addObserver(this);
    // Campanha de abertura: mostra o pop-up assim que o app abre
    WidgetsBinding.instance.addPostFrameCallback((_) => _mostrarCampanha());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.paused ||
        estado == AppLifecycleState.hidden) {
      _saiuEm = DateTime.now();
    } else if (estado == AppLifecycleState.resumed) {
      final saiu = _saiuEm;
      _saiuEm = null;
      // reagenda o proximo despertador sempre que o app volta: garante que
      // os alarmes que se repetem continuem valendo nos dias seguintes
      DespertadoresLista.carregar()
          .then((lista) => DespertadoresLista.reagendarProximo(lista));
      // O comercial de abertura NAO reaparece quando o app estava apenas
      // minimizado/escondido (o ouvinte continua ouvindo a radio). Ele so
      // volta quando o app e FECHADO e aberto de novo — nesse caso o app
      // inicia do zero e o comercial aparece pelo initState.
      // (a variavel 'saiu' fica so para registro do momento da saida)
      if (saiu == null) {}
    }
  }

  /// Exibe o comercial de abertura. O banner e OBRIGATORIO: se na primeira
  /// tentativa o config.json (ou a localizacao do ouvinte) ainda nao tiver
  /// chegado, continua tentando por ate 40 segundos, ate conseguir mostrar.
  void _mostrarCampanha() async {
    final cfg = ConfigService.instancia.config;
    for (var tentativa = 0; tentativa < 20; tentativa++) {
      if (!mounted) return;
      final mostrou = await CampanhaPopup.talvezMostrar(context, cfg.value);
      if (mostrou) return; // apareceu: missao cumprida
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulso.dispose();
    _telaAcesa?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  /// Entrar na TV dá play na live (o rádio só é cortado quando a página
  /// confirmar que a transmissão está mesmo no ar). Sair da TV pausa o
  /// vídeo e retoma o rádio, se ele havia sido pausado.
  void _aoTrocarAba(int novo) {
    final anterior = _abaAtual;
    if (novo == _abaTv && anterior != _abaTv) {
      // só tenta tocar o vídeo; o corte do rádio vem depois, se houver live
      Future.delayed(const Duration(milliseconds: 250), TvControle.tocar);
    } else if (anterior == _abaTv && novo != _abaTv) {
      aoSairDaTv();
    }
  }

  /// Mantém a tela ligada por 60s e renova a cada interação
  void _manterTelaAcesa() {
    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {}
    WakelockEleva.ativarPorUmMinuto();
  }

  /// Item do menu inferior — o selecionado ganha brilho dourado (glow).
  /// Quando [aoVivo] é true (transmissão no ar), a aba pulsa em vermelho.
  Widget _itemNav(int i, IconData icone, String rotulo,
      {bool aoVivo = false}) {
    final ativo = _abaAtual == i;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _irParaAba(i),
        child: AnimatedBuilder(
          animation: _pulso,
          builder: (context, _) {
            // 0 = apagado, 1 = aceso — só pulsa quando há transmissão
            final p = aoVivo ? _pulso.value : 0.0;
            final vermelho =
                Color.lerp(const Color(0xFFFF6B6B), const Color(0xFFE01010), p)!;
            final corPrincipal = aoVivo
                ? vermelho
                : (ativo ? CoresEleva.dourado : CoresEleva.textoFraco);
            return AnimatedContainer(
              duration: Duration(milliseconds: 280),
              curve: Curves.easeOut,
              margin: EdgeInsets.symmetric(horizontal: 1),
              padding: EdgeInsets.symmetric(horizontal: 1, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: aoVivo
                    ? vermelho.withOpacity(0.10 + 0.14 * p)
                    : (ativo
                        ? CoresEleva.dourado.withOpacity(0.16)
                        : Colors.transparent),
                boxShadow: aoVivo
                    ? [
                        BoxShadow(
                          color: vermelho.withOpacity(0.30 + 0.45 * p),
                          blurRadius: 10 + 12 * p,
                          spreadRadius: 1,
                        )
                      ]
                    : (ativo
                        ? [
                            BoxShadow(
                              color: CoresEleva.dourado.withOpacity(0.55),
                              blurRadius: 16,
                              spreadRadius: 1,
                            )
                          ]
                        : []),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(icone,
                          size: ativo ? 22 : 19, color: corPrincipal),
                      // bolinha vermelha piscando de "ao vivo"
                      if (aoVivo)
                        Positioned(
                          right: -3,
                          top: -2,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red
                                  .withOpacity(0.45 + 0.55 * p),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(aoVivo ? 'AO VIVO' : rotulo,
                        maxLines: 1,
                        style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: (ativo || aoVivo)
                                ? FontWeight.w900
                                : FontWeight.w600,
                            color: corPrincipal)),
                  ),
                ],
              ),
            );
          },
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
  Widget build(BuildContext context) {
    // Recriadas a cada build: garante que TODAS as abas troquem de tema
    // juntas (fundo, textos e cartões), sem perder o estado interno.
    final paginas = [
      HomePage(),
      ChatPage(),
      PromocoesPage(),
      PedidosPage(),
      TvPage(),
      MenuPage(),
    ];
    return Scaffold(
      body: Listener(
        onPointerDown: (_) => _manterTelaAcesa(),
        child: PageView(
          controller: _pageCtrl,
          onPageChanged: (i) {
            _manterTelaAcesa();
            _aoTrocarAba(i);
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
              padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: ValueListenableBuilder<AppConfig>(
                valueListenable: ConfigService.instancia.config,
                builder: (context, cfg, _) {
                  // há transmissão no ar? então a aba TV pulsa em vermelho
                  final aoVivo = cfg.tvVideo.trim().isNotEmpty;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _itemNav(0, Icons.home_rounded, 'Início'),
                      _itemNav(1, Icons.forum_rounded, 'Chat'),
                      _itemNav(2, Icons.card_giftcard_rounded, 'Promoções'),
                      _itemNav(3, Icons.music_note_rounded, 'Pedidos'),
                      _itemNav(4, Icons.live_tv_rounded, 'TV',
                          aoVivo: aoVivo),
                      _itemNav(5, Icons.menu_rounded, 'Menu'),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
