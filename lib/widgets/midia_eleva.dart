import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../tema.dart';

/// Mostra a mídia de um item (banner, anúncio, notícia, enquete, promoção).
///
/// Decide sozinho o que exibir com base nos campos do item:
///   tipo == 'video'   -> vídeo MP4 (campo 'video'), toca sozinho em loop
///   tipo == 'youtube' -> vídeo do YouTube (campo 'youtube'/'video')
///   senão             -> imagem (campo 'imagem')  [comportamento antigo]
///
/// O som é controlado pelo campo 'som' ('com' | 'sem'). O padrão é 'sem'
/// (mudo), que é mais leve e não atrapalha a rádio tocando.
///
/// Para vídeo e YouTube usa o webview_flutter (já usado na aba TV), então
/// NÃO precisa de nenhuma dependência nova.
class MidiaEleva extends StatefulWidget {
  final Map<String, dynamic> item;
  final BoxFit fit;
  final Widget Function()? placeholder; // o que mostrar se a imagem falhar

  const MidiaEleva({
    Key? key,
    required this.item,
    this.fit = BoxFit.cover,
    this.placeholder,
  }) : super(key: key);

  /// true se este item é um vídeo (MP4 ou YouTube)
  static bool ehVideo(Map<String, dynamic> item) {
    final tipo = (item['tipo'] ?? 'imagem').toString();
    return tipo == 'video' || tipo == 'youtube';
  }

  @override
  State<MidiaEleva> createState() => _MidiaElevaState();
}

class _MidiaElevaState extends State<MidiaEleva> {
  WebViewController? _ctrl;

  @override
  void initState() {
    super.initState();
    _montarSeVideo();
  }

  String get _tipo => (widget.item['tipo'] ?? 'imagem').toString();
  bool get _comSom => (widget.item['som'] ?? 'sem').toString() == 'com';

  /// Extrai o ID do vídeo de um link do YouTube (ou aceita o ID puro).
  String _idYoutube(String v) {
    v = v.trim();
    final padroes = [
      RegExp(r'youtu\.be/([A-Za-z0-9_-]{11})'),
      RegExp(r'[?&]v=([A-Za-z0-9_-]{11})'),
      RegExp(r'youtube\.com/embed/([A-Za-z0-9_-]{11})'),
      RegExp(r'youtube\.com/shorts/([A-Za-z0-9_-]{11})'),
      RegExp(r'youtube\.com/live/([A-Za-z0-9_-]{11})'),
      // aceita tambem quando o usuario cola o CODIGO DE INCORPORACAO
      // inteiro (o <iframe src="...">), pegando o id de dentro dele
      RegExp(r'src="[^"]*?/embed/([A-Za-z0-9_-]{11})'),
    ];
    for (final p in padroes) {
      final m = p.firstMatch(v);
      if (m != null) return m.group(1)!;
    }
    if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(v)) return v;
    return '';
  }

  void _montarSeVideo() {
    if (!MidiaEleva.ehVideo(widget.item)) return;
    final mudo = _comSom ? '' : 'muted';
    String html;

    if (_tipo == 'youtube') {
      final id = _idYoutube(
          (widget.item['youtube'] ?? widget.item['video'] ?? '').toString());
      if (id.isEmpty) return;
      final muteParam = _comSom ? '0' : '1';
      html = '''
<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"><style>
html,body{margin:0;padding:0;background:#000;overflow:hidden;height:100%}
iframe{position:fixed;top:0;left:0;width:100%;height:100%;border:0}
</style></head><body>
<iframe src="https://www.youtube.com/embed/$id?autoplay=1&mute=$muteParam&controls=0&loop=1&playlist=$id&playsinline=1&modestbranding=1&rel=0"
allow="autoplay; encrypted-media" allowfullscreen></iframe>
</body></html>''';
    } else {
      // MP4 direto
      final url = (widget.item['video'] ?? '').toString();
      if (url.isEmpty) return;
      html = '''
<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"><style>
html,body{margin:0;padding:0;background:#000;overflow:hidden;height:100%}
video{width:100%;height:100%;object-fit:cover;display:block}
</style></head><body>
<video src="$url" autoplay loop playsinline $mudo webkit-playsinline></video>
</body></html>''';
    }

    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      // IMPORTANTE: o YouTube RECUSA tocar quando a pagina nao tem um
      // endereco de origem valido. Informando o baseUrl, ele aceita e o
      // video roda normalmente dentro do banner.
      ..loadHtmlString(html,
          baseUrl: _tipo == 'youtube'
              ? 'https://www.youtube.com'
              : 'https://radioeleva.local');
    try {
      if (c.platform is AndroidWebViewController) {
        (c.platform as AndroidWebViewController)
            .setMediaPlaybackRequiresUserGesture(false);
      }
    } catch (_) {}
    _ctrl = c;
  }

  Widget _erro() {
    if (widget.placeholder != null) return widget.placeholder!();
    return Container(color: CoresEleva.azulMedio);
  }

  @override
  Widget build(BuildContext context) {
    if (MidiaEleva.ehVideo(widget.item)) {
      if (_ctrl == null) return _erro();
      // IgnorePointer: deixa o toque passar para o GestureDetector de fora
      // (abrir link ao tocar), sem o webview "engolir" o toque.
      return IgnorePointer(
        ignoring: true,
        child: WebViewWidget(controller: _ctrl!),
      );
    }
    // imagem (comportamento antigo)
    return Image.network(
      (widget.item['imagem'] ?? '').toString(),
      fit: widget.fit,
      width: double.infinity,
      errorBuilder: (_, __, ___) => _erro(),
      loadingBuilder: (_, w, p) =>
          p == null ? w : Container(color: CoresEleva.azulMedio),
    );
  }
}
