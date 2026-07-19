import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../servicos/analytics_service.dart';
import '../servicos/config_service.dart';
import '../servicos/player_service.dart';
import '../tema.dart';
import '../widgets/anuncio_banner.dart';
import '../widgets/capa_musica.dart';

class HomePage extends StatefulWidget {
  HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _pageController = PageController();
  Timer? _timerBanner;
  int _bannerAtual = 0;
  bool _curtiu = false;
  String _musicaAtual = '';

  @override
  void initState() {
    super.initState();
    _timerBanner = Timer.periodic(Duration(seconds: 5), (_) {
      final banners =
          filtrarAgendados(ConfigService.instancia.config.value.banners);
      if (banners.length > 1 && _pageController.hasClients) {
        _bannerAtual = (_bannerAtual + 1) % banners.length;
        _pageController.animateToPage(_bannerAtual,
            duration: Duration(milliseconds: 450), curve: Curves.easeInOut);
      }
    });
  }

  @override
  void dispose() {
    _timerBanner?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _abrirLink(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Registra o clique (com localização e dispositivo para o relatório) e abre o link
  void _tocarBanner(AppConfig cfg, Map<String, dynamic> b) {
    if (cfg.chatUrl.isNotEmpty) {
      final base = cfg.chatUrl.replaceAll(RegExp(r'/chat/?$'), '');
      http.post(Uri.parse('$base/banner_cliques.json'),
          body: jsonEncode({
            'banner': (b['id'] ?? b['imagem'] ?? '').toString(),
            'quando': DateTime.now().toIso8601String(),
            'cidade': AnalyticsService.cidade,
            'estado': AnalyticsService.estado,
            'pais': AnalyticsService.pais,
            'dispositivo': 'Android',
          }));
    }
    _abrirLink(b['link']);
  }

  Future<void> _curtir(AppConfig cfg) async {
    if (_curtiu || _musicaAtual.isEmpty) return; // uma curtida por música
    setState(() => _curtiu = true);
    final prefs = await SharedPreferences.getInstance();
    final chave = 'curtiu_${_musicaAtual.hashCode}';
    if (prefs.getBool(chave) == true) return; // já curtiu esta música antes
    await prefs.setBool(chave, true);
    PlayerService.instancia.votar(cfg.chatUrl, 'like', _musicaAtual);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: Duration(seconds: 2),
        backgroundColor: CoresEleva.verdeEscuro,
        content: Text('Você curtiu esta música! ❤️'),
      ));
    }
  }

  /// Ao trocar de música, verifica se o ouvinte já a curtiu antes
  Future<void> _conferirCurtida(String musica) async {
    if (musica.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final ja = prefs.getBool('curtiu_${musica.hashCode}') == true;
    if (mounted && ja != _curtiu) setState(() => _curtiu = ja);
  }

  void _compartilhar(AppConfig cfg) {
    final musica = _musicaAtual.isNotEmpty ? '🎵 $_musicaAtual — ' : '';
    final link =
        cfg.linkCompartilhar.isNotEmpty ? '\n${cfg.linkCompartilhar}' : '';
    Share.share(
        '${musica}Estou ouvindo a ${cfg.nome} ao vivo! ${cfg.slogan} 📻$link');
  }

  @override
  Widget build(BuildContext context) {
    final player = PlayerService.instancia.player;
    return ValueListenableBuilder<AppConfig>(
      valueListenable: ConfigService.instancia.config,
      builder: (context, cfg, _) {
        final banners = filtrarAgendados(cfg.banners);
        final noAr = programaNoAr(cfg.programacao);
        return Container(
          decoration: BoxDecoration(gradient: CoresEleva.fundoApp),
          child: SafeArea(
            child: LayoutBuilder(builder: (context, c) {
              final alturaBanner = (c.maxHeight * 0.245).clamp(140.0, 196.0);
              return Column(
                children: [
                  AnuncioBanner(),

                  // ===== BANNER CARROSSEL COM MOLDURA NEON =====
                  Padding(
                    padding: EdgeInsets.fromLTRB(14, 8, 14, 0),
                    child: MolduraNeon(
                      raio: 20,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(17),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // tarja de data e hora ACIMA do banner (faixa própria)
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              color: Colors.black.withOpacity(
                                  CoresEleva.escuro ? 0.42 : 0.30),
                              child: RelogioAgora(),
                            ),
                            // banner (altura preservada, imagem intacta)
                            SizedBox(
                              height: alturaBanner,
                              width: double.infinity,
                              child: banners.isEmpty
                            ? _bannerPadrao()
                            : Stack(
                                children: [
                                  PageView.builder(
                                    controller: _pageController,
                                    itemCount: banners.length,
                                    onPageChanged: (i) =>
                                        setState(() => _bannerAtual = i),
                                    itemBuilder: (context, i) {
                                      final b = banners[i];
                                      return GestureDetector(
                                        onTap: () => _tocarBanner(cfg, b),
                                        child: Image.network(
                                          b['imagem'] ?? '',
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          errorBuilder: (_, __, ___) =>
                                              _bannerPadrao(),
                                          loadingBuilder: (_, w, p) =>
                                              p == null
                                                  ? w
                                                  : Container(
                                                      color: CoresEleva
                                                          .azulMedio),
                                        ),
                                      );
                                    },
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    left: 0,
                                    right: 0,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: List.generate(
                                        banners.length,
                                        (i) => AnimatedContainer(
                                          duration:
                                              Duration(milliseconds: 300),
                                          margin: EdgeInsets.symmetric(
                                              horizontal: 3),
                                          width: i == _bannerAtual ? 20 : 7,
                                          height: 7,
                                          decoration: BoxDecoration(
                                            color: i == _bannerAtual
                                                ? CoresEleva.dourado
                                                : Colors.white
                                                    .withOpacity(0.5),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),


                  // ===== PLAYER (modelo enviado) =====
                  Expanded(
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: 18),
                          // Capa da música / foto do programa no ar
                          CapaMusica(
                            tamanho: (c.maxHeight * 0.30)
                                .clamp(176.0, 240.0)
                                .toDouble(),
                              reserva: (noAr?['imagem'] ?? '').toString()),
                          SizedBox(height: 16),
                          Column(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade700,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle,
                                        size: 9, color: Colors.white),
                                    SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        noAr != null
                                            ? 'AO VIVO • ${(noAr['programa'] ?? '').toString().toUpperCase()}'
                                            : 'NO AR',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            letterSpacing: 1.2)),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 10),
                              // linha divisória entre o AO VIVO e o nome da música
                              Container(
                                width: 120,
                                height: 1,
                                color: CoresEleva.dourado.withOpacity(0.45),
                              ),
                              SizedBox(height: 10),
                              StreamBuilder<IcyMetadata?>(
                                stream: player.icyMetadataStream,
                                builder: (context, snap) {
                                  final titulo =
                                      snap.data?.info?.title?.trim() ?? '';
                                  if (titulo != _musicaAtual) {
                                    _musicaAtual = titulo;
                                    _curtiu = false;
                                    _conferirCurtida(titulo);
                                  }
                                  return Text(
                                    titulo.isEmpty
                                        ? 'Tocando agora na ${cfg.nome}'
                                        : titulo,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w600,
                                        color: CoresEleva.brancoSuave),
                                  );
                                },
                              ),
                            ],
                          ),

                          SizedBox(height: 22),
                          // CORAÇÃO — PLAY — COMPARTILHAR
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () => _curtir(cfg),
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: _curtiu
                                            ? Colors.pink
                                            : CoresEleva.dourado,
                                        width: 2),
                                  ),
                                  child: Icon(
                                    _curtiu
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: _curtiu
                                        ? Colors.pink
                                        : CoresEleva.dourado,
                                    size: 27,
                                  ),
                                ),
                              ),
                              SizedBox(width: 30),
                              StreamBuilder<PlayerState>(
                                stream: player.playerStateStream,
                                builder: (context, snap) {
                                  final estado = snap.data;
                                  final tocando = estado?.playing ?? false;
                                  final carregando =
                                      estado?.processingState ==
                                              ProcessingState.loading ||
                                          estado?.processingState ==
                                              ProcessingState.buffering;
                                  return GestureDetector(
                                    onTap: () async {
                                      await PlayerService.instancia
                                          .carregar(cfg.streamUrl, cfg.nome,
                                              cfg.logoUrl);
                                      await PlayerService.instancia
                                          .alternar();
                                    },
                                    child: Container(
                                      width: 88,
                                      height: 88,
                                      decoration: BoxDecoration(
                                        gradient: CoresEleva.botaoPlay,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: CoresEleva.dourado,
                                            width: 2.5),
                                        boxShadow: [
                                          BoxShadow(
                                            color: CoresEleva.verde
                                                .withOpacity(0.4),
                                            blurRadius: 24,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: carregando
                                          ? Padding(
                                              padding: EdgeInsets.all(26),
                                              child:
                                                  CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 3,
                                              ),
                                            )
                                          : Icon(
                                              tocando
                                                  ? Icons.pause_rounded
                                                  : Icons
                                                      .play_arrow_rounded,
                                              size: 48,
                                              color: Colors.white,
                                            ),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(width: 30),
                              GestureDetector(
                                onTap: () => _compartilhar(cfg),
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: CoresEleva.dourado,
                                        width: 2),
                                  ),
                                  child: Icon(Icons.share_rounded,
                                      color: CoresEleva.dourado, size: 24),
                                ),
                              ),
                            ],
                          ),

                          // ===== SLEEP TIMER ATIVO =====
                          ValueListenableBuilder<int>(
                            valueListenable:
                                PlayerService.instancia.sleepSegundos,
                            builder: (context, seg, _) {
                              if (seg <= 0) return SizedBox.shrink();
                              final min = (seg / 60).ceil();
                              final texto = seg >= 60
                                  ? '$min ${min == 1 ? 'minuto' : 'minutos'}'
                                  : '$seg ${seg == 1 ? 'segundo' : 'segundos'}';
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.bedtime_rounded,
                                      size: 15,
                                      color: CoresEleva.dourado),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Sua rádio desligará em $texto',
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: CoresEleva.brancoSuave),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  GestureDetector(
                                    onTap: () {
                                      PlayerService.instancia
                                          .definirSleep(0);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                        duration: Duration(seconds: 2),
                                        backgroundColor:
                                            CoresEleva.azulMedio,
                                        content: Text(
                                            'Sleep timer cancelado.'),
                                      ));
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        border: Border.all(
                                            color: CoresEleva.dourado,
                                            width: 1.2),
                                      ),
                                      child: Text('CANCELAR',
                                          style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                              color:
                                                  CoresEleva.dourado)),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }

  Widget _bannerPadrao() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [CoresEleva.azulMedio, CoresEleva.verdeEscuro],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(child: Image.asset('assets/logo.png', height: 100)),
    );
  }
}

// ============================================================
// RELÓGIO AO VIVO
// ============================================================
class RelogioAgora extends StatefulWidget {
  RelogioAgora({super.key});
  @override
  State<RelogioAgora> createState() => _RelogioAgoraState();
}

class _RelogioAgoraState extends State<RelogioAgora> {
  Timer? _timer;

  static final _dias = [
    'segunda-feira',
    'terça-feira',
    'quarta-feira',
    'quinta-feira',
    'sexta-feira',
    'sábado',
    'domingo'
  ];
  static final _meses = [
    'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
    'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final diaSemana = _dias[agora.weekday - 1];
    final diaCap = diaSemana[0].toUpperCase() + diaSemana.substring(1);
    final data =
        '$diaCap, ${agora.day} de ${_meses[agora.month - 1]} de ${agora.year}';
    final hora =
        '${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.schedule_rounded, size: 14, color: CoresEleva.dourado),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            '$data  •  $hora',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white),
          ),
        ),
      ],
    );
  }
}


/// Moldura com um facho de luz "neon" percorrendo a borda no sentido
/// anti-horário, com a cor mudando suavemente ao longo do tempo.
class MolduraNeon extends StatefulWidget {
  final Widget child;
  final double raio;
  const MolduraNeon({super.key, required this.child, this.raio = 20});
  @override
  State<MolduraNeon> createState() => _MolduraNeonState();
}

class _MolduraNeonState extends State<MolduraNeon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, filho) {
        return CustomPaint(
          foregroundPainter: _NeonPainter(_ctrl.value, widget.raio),
          child: filho,
        );
      },
      child: Padding(padding: const EdgeInsets.all(2), child: widget.child),
    );
  }
}

class _NeonPainter extends CustomPainter {
  final double t; // 0..1 (posição do facho)
  final double raio;
  _NeonPainter(this.t, this.raio);

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(raio),
    );

    // linha fininha de base
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFFFD65A).withOpacity(0.28);
    canvas.drawRRect(rrect.deflate(1), base);

    // cor que muda suavemente com o tempo (HSV girando)
    final matiz = (t * 360 * 1.0) % 360;
    final corNeon = HSVColor.fromAHSV(1, matiz, 0.85, 1).toColor();

    // caminho da borda para extrair o trecho iluminado
    final path = Path()..addRRect(rrect.deflate(1));
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final total = metric.length;

    // sentido ANTI-horário: andamos "para trás" no caminho
    final comprimentoFacho = total * 0.22;
    final inicio = (total * (1 - t)) % total;

    Path trecho;
    if (inicio + comprimentoFacho <= total) {
      trecho = metric.extractPath(inicio, inicio + comprimentoFacho);
    } else {
      trecho = metric.extractPath(inicio, total)
        ..addPath(
            metric.extractPath(0, (inicio + comprimentoFacho) - total),
            Offset.zero);
    }

    // brilho (glow) + núcleo do facho
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = corNeon.withOpacity(0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(trecho, glow);

    final nucleo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = corNeon;
    canvas.drawPath(trecho, nucleo);
  }

  @override
  bool shouldRepaint(_NeonPainter old) => old.t != t;
}
