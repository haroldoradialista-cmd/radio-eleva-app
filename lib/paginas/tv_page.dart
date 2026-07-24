import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
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

  @override
  void initState() {
    super.initState();
    _aplicar(ConfigService.instancia.config.value.tvVideo);
    ConfigService.instancia.config.addListener(_aoMudarConfig);
  }

  @override
  void dispose() {
    ConfigService.instancia.config.removeListener(_aoMudarConfig);
    super.dispose();
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
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0B0720))
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _carregando = false);
        },
        onWebResourceError: (_) {
          if (mounted) setState(() => _carregando = false);
        },
      ))
      ..loadRequest(Uri.parse(url));
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

/// Pausa o rádio ao entrar na TV, para os áudios não se misturarem.
void pausarRadioParaTv() {
  try {
    if (PlayerService.instancia.player.playing) {
      PlayerService.instancia.player.pause();
    }
  } catch (_) {}
}
