import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../servicos/config_service.dart';
import '../servicos/player_service.dart';
import '../tema.dart';

/// Aba TV: transmissões ao vivo do YouTube.
/// A metade de cima mostra o vídeo e a de baixo o chat da transmissão.
/// A página que junta os dois fica hospedada no GitHub Pages, porque o
/// chat do YouTube só funciona dentro de um domínio de verdade.
class TvPage extends StatefulWidget {
  const TvPage({super.key});

  @override
  State<TvPage> createState() => _TvPageState();
}

class _TvPageState extends State<TvPage> {
  static const _base =
      'https://haroldoradialista-cmd.github.io/radio-eleva-app/tv/';

  WebViewController? _ctrl;
  String _videoAtual = '';
  bool _carregando = true;
  bool _estaAoVivoDeVerdade = false;

  @override
  void initState() {
    super.initState();
    TvControle.registrar(this);
    _aplicar(ConfigService.instancia.config.value.tvVideo);
    ConfigService.instancia.config.addListener(_aoMudarConfig);
  }

  @override
  void dispose() {
    TvControle.limpar(this);
    ConfigService.instancia.config.removeListener(_aoMudarConfig);
    super.dispose();
  }

  /// Recebe o status real da transmissão vindo da página (YouTube).
  /// Só corta o rádio quando a live está MESMO no ar.
  void _aoReceberStatus(String status) {
    final aoVivo = status == 'AO_VIVO';
    if (aoVivo != _estaAoVivoDeVerdade) {
      _estaAoVivoDeVerdade = aoVivo;
      TvControle.aoVivoConfirmado.value = aoVivo;
      if (aoVivo) {
        // transmissão confirmada no ar → agora sim pausa o rádio
        TvControle.pedirPausaDoRadio();
      } else {
        // não há live de verdade → mantém/retoma o som da Eleva
        TvControle.pedirRetomadaDoRadio();
      }
    }
  }

  /// Dá o play na transmissão (chamado ao entrar na aba TV)
  void tocar() {
    try {
      _ctrl?.runJavaScript('window.tocarVideo && window.tocarVideo();');
    } catch (_) {}
  }

  /// Pausa a transmissão (chamado ao sair da aba TV)
  void pausar() {
    try {
      _ctrl?.runJavaScript('window.pausarVideo && window.pausarVideo();');
    } catch (_) {}
  }

  void _aoMudarConfig() {
    final novo = ConfigService.instancia.config.value.tvVideo;
    if (novo != _videoAtual && mounted) {
      setState(() => _aplicar(novo));
    }
  }

  void _aplicar(String video) {
    _videoAtual = video;
    _carregando = true;
    if (video.trim().isEmpty) {
      _ctrl = null;
      return;
    }
    final url = '$_base?v=${Uri.encodeComponent(video.trim())}';
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0B0720))
      ..addJavaScriptChannel('CanalTV',
          onMessageReceived: (msg) => _aoReceberStatus(msg.message))
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _carregando = false);
          // dá o play sozinho assim que a transmissão termina de carregar
          Future.delayed(const Duration(milliseconds: 700), tocar);
        },
        onWebResourceError: (_) {
          if (mounted) setState(() => _carregando = false);
        },
      ))
      ..loadRequest(Uri.parse(url));
    // No Android o vídeo só toca sozinho se liberarmos esta permissão
    try {
      if (c.platform is AndroidWebViewController) {
        (c.platform as AndroidWebViewController)
            .setMediaPlaybackRequiresUserGesture(false);
      }
    } catch (_) {}
    _ctrl = c;
  }

  void _recarregar() {
    setState(() {
      _aplicar(ConfigService.instancia.config.value.tvVideo);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FundoEleva(
      child: SafeArea(
        child: Column(
          children: [
            // ===== barra de título =====
            Padding(
              padding: EdgeInsets.fromLTRB(14, 8, 8, 6),
              child: Row(
                children: [
                  Icon(Icons.live_tv_rounded,
                      color: CoresEleva.dourado, size: 22),
                  SizedBox(width: 8),
                  Text('TV RÁDIO ELEVA',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                          color: CoresEleva.branco)),
                  Spacer(),
                  IconButton(
                    tooltip: 'Atualizar',
                    onPressed: _recarregar,
                    icon: Icon(Icons.refresh_rounded,
                        color: CoresEleva.dourado, size: 22),
                  ),
                ],
              ),
            ),

            // ===== conteúdo =====
            Expanded(
              child: _ctrl == null ? _semTransmissao() : _comWebView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _comWebView() {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      child: Stack(
        children: [
          WebViewWidget(controller: _ctrl!),
          if (_carregando)
            Container(
              color: const Color(0xFF0B0720),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: CoresEleva.dourado),
                    SizedBox(height: 14),
                    Text('Carregando a transmissão...',
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _semTransmissao() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tv_off_rounded, size: 66, color: CoresEleva.dourado),
            SizedBox(height: 16),
            Text('Nenhuma transmissão no ar',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: CoresEleva.branco)),
            SizedBox(height: 10),
            Text(
              'Quando a Rádio Eleva estiver ao vivo no YouTube, o vídeo e o '
              'chat da transmissão aparecem aqui nesta tela.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: CoresEleva.brancoSuave, height: 1.55, fontSize: 14),
            ),
            SizedBox(height: 18),
            Text('Adore • Viva • Eleve',
                style: TextStyle(
                    color: CoresEleva.dourado,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4)),
          ],
        ),
      ),
    );
  }
}

/// Ponte para o app controlar a transmissão de fora da aba TV.
class TvControle {
  static _TvPageState? _estado;
  static void registrar(_TvPageState e) => _estado = e;
  static void limpar(_TvPageState e) {
    if (identical(_estado, e)) _estado = null;
  }

  /// true quando o YouTube confirmou que a live está REALMENTE no ar
  static final ValueNotifier<bool> aoVivoConfirmado = ValueNotifier(false);

  /// Existe link de transmissão configurado no painel?
  static bool get temLink =>
      ConfigService.instancia.config.value.tvVideo.trim().isNotEmpty;

  static void tocar() => _estado?.tocar();
  static void pausar() => _estado?.pausar();

  // guardado aqui para o main saber se deve retomar o rádio ao sair
  static bool radioEstavaTocando = false;

  static void pedirPausaDoRadio() {
    try {
      final p = PlayerService.instancia.player;
      radioEstavaTocando = p.playing;
      if (p.playing) p.pause();
    } catch (_) {}
  }

  static void pedirRetomadaDoRadio() {
    try {
      if (radioEstavaTocando) {
        PlayerService.instancia.player.play();
        radioEstavaTocando = false;
      }
    } catch (_) {}
  }
}

/// Quando o app sai da aba TV: pausa o vídeo e garante que o rádio volte
/// (se ele havia sido pausado por causa de uma live).
void aoSairDaTv() {
  TvControle.pausar();
  TvControle.aoVivoConfirmado.value = false;
  TvControle.pedirRetomadaDoRadio();
}
