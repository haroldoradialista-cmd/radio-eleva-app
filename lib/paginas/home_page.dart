import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../servicos/config_service.dart';
import '../servicos/player_service.dart';
import '../tema.dart';
import '../widgets/enquete_card.dart';

class HomePage extends StatefulWidget {
  HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _pageController = PageController();
  Timer? _timerBanner;
  int _bannerAtual = 0;
  String? _voto;
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

  /// Registra o clique no banner (pós-venda para anunciantes) e abre o link
  void _tocarBanner(AppConfig cfg, Map<String, dynamic> b) {
    if (cfg.chatUrl.isNotEmpty) {
      final base = cfg.chatUrl.replaceAll(RegExp(r'/chat/?$'), '');
      http.post(Uri.parse('$base/banner_cliques.json'),
          body: jsonEncode({
            'banner': (b['id'] ?? b['imagem'] ?? '').toString(),
            'quando': DateTime.now().toIso8601String(),
          }));
    }
    _abrirLink(b['link']);
  }

  void _registrarVoto(String tipo, AppConfig cfg) {
    setState(() => _voto = tipo);
    PlayerService.instancia.votar(cfg.chatUrl, tipo, _musicaAtual);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: Duration(seconds: 2),
      backgroundColor:
          tipo == 'like' ? CoresEleva.verdeEscuro : CoresEleva.azulMedio,
      content: Text(tipo == 'like'
          ? 'Que bom que você gostou! 🙌'
          : 'Obrigado pela sua opinião!'),
    ));
  }

  void _escolherSleep() {
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
                  },
                )),
            ListTile(
              leading:
                  Icon(Icons.close_rounded, color: CoresEleva.textoFraco),
              title: Text('Cancelar sleep timer'),
              onTap: () {
                PlayerService.instancia.definirSleep(0);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
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
              final alturaBanner = (c.maxHeight * 0.26).clamp(120.0, 210.0);
              return Column(
                children: [
                  // ===== BANNER COM MOLDURA SUAVE =====
                  Padding(
                    padding: EdgeInsets.fromLTRB(14, 12, 14, 0),
                    child: Container(
                      height: alturaBanner,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: CoresEleva.borda, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withOpacity(CoresEleva.escuro ? 0.35 : 0.10),
                            blurRadius: 14,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(21),
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
                                          loadingBuilder: (_, w, p) => p ==
                                                  null
                                              ? w
                                              : Container(
                                                  color:
                                                      CoresEleva.azulMedio),
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
                    ),
                  ),

                  // ===== DATA E HORA =====
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: RelogioAgora(),
                  ),

                  // ===== ENQUETE FIXA =====
                  EnqueteCard(),

                  // ===== ÁREA DO PLAYER =====
                  Expanded(
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.asset('assets/logo.png',
                                    width: 44, height: 44),
                              ),
                              SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cfg.nome,
                                      style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: CoresEleva.branco)),
                                  Text(cfg.slogan,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: CoresEleva.dourado,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1.2)),
                                ],
                              ),
                            ],
                          ),

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
                                    Text('AO VIVO',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            letterSpacing: 1.5)),
                                  ],
                                ),
                              ),
                              if (noAr != null)
                                Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Text(
                                    '📻 ${noAr['programa']}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: CoresEleva.dourado),
                                  ),
                                ),
                              SizedBox(height: 10),
                              StreamBuilder<IcyMetadata?>(
                                stream: player.icyMetadataStream,
                                builder: (context, snap) {
                                  final titulo =
                                      snap.data?.info?.title?.trim() ?? '';
                                  if (titulo != _musicaAtual) {
                                    _musicaAtual = titulo;
                                    _voto = null;
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

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _botaoVoto(
                                icone: Icons.thumb_down_rounded,
                                ativo: _voto == 'dislike',
                                corAtiva: CoresEleva.azulVivo,
                                aoTocar: () =>
                                    _registrarVoto('dislike', cfg),
                              ),
                              SizedBox(width: 28),
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
                                      width: 90,
                                      height: 90,
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
                                                  ? Icons.stop_rounded
                                                  : Icons
                                                      .play_arrow_rounded,
                                              size: 50,
                                              color: Colors.white,
                                            ),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(width: 28),
                              _botaoVoto(
                                icone: Icons.thumb_up_rounded,
                                ativo: _voto == 'like',
                                corAtiva: CoresEleva.verde,
                                aoTocar: () => _registrarVoto('like', cfg),
                              ),
                            ],
                          ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ValueListenableBuilder<int>(
                                valueListenable:
                                    PlayerService.instancia.sleepRestante,
                                builder: (context, restante, _) {
                                  return TextButton.icon(
                                    onPressed: _escolherSleep,
                                    icon: Icon(Icons.bedtime_rounded,
                                        size: 20,
                                        color: restante > 0
                                            ? CoresEleva.verde
                                            : CoresEleva.dourado),
                                    label: Text(
                                      restante > 0
                                          ? 'Dormir em ${restante}min'
                                          : 'Sleep timer',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: restante > 0
                                              ? CoresEleva.verde
                                              : CoresEleva.dourado),
                                    ),
                                  );
                                },
                              ),
                              ValueListenableBuilder<bool>(
                                valueListenable: modoEscuroNotifier,
                                builder: (context, escuro, _) {
                                  return TextButton.icon(
                                    onPressed: alternarTema,
                                    icon: Icon(
                                        escuro
                                            ? Icons.light_mode_rounded
                                            : Icons.dark_mode_rounded,
                                        size: 20,
                                        color: CoresEleva.dourado),
                                    label: Text(
                                      escuro ? 'Modo claro' : 'Modo escuro',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: CoresEleva.dourado),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),

                          if (cfg.redes.isNotEmpty)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: cfg.redes.map((r) {
                                return Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 8),
                                  child: IconButton(
                                    onPressed: () => _abrirLink(r['link']),
                                    icon: Icon(_iconeRede(r['nome'] ?? ''),
                                        color: CoresEleva.dourado,
                                        size: 26),
                                  ),
                                );
                              }).toList(),
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

  Widget _botaoVoto({
    required IconData icone,
    required bool ativo,
    required Color corAtiva,
    required VoidCallback aoTocar,
  }) {
    return GestureDetector(
      onTap: aoTocar,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ativo ? corAtiva : CoresEleva.azulMedio,
          border: Border.all(
              color: ativo ? CoresEleva.dourado : CoresEleva.borda,
              width: 1.5),
        ),
        child: Icon(icone,
            color: ativo ? Colors.white : CoresEleva.textoFraco, size: 25),
      ),
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
      child: Center(child: Image.asset('assets/logo.png', height: 110)),
    );
  }

  IconData _iconeRede(String nome) {
    final n = nome.toLowerCase();
    if (n.contains('insta')) return Icons.camera_alt_rounded;
    if (n.contains('face')) return Icons.facebook_rounded;
    if (n.contains('you')) return Icons.play_circle_fill_rounded;
    if (n.contains('site')) return Icons.language_rounded;
    return Icons.public_rounded;
  }
}


// ============================================================
// RELÓGIO AO VIVO (data e hora para o ouvinte)
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
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro'
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
    final data =
        '${_dias[agora.weekday - 1]}, ${agora.day} de ${_meses[agora.month - 1]} de ${agora.year}';
    final hora =
        '${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}:${agora.second.toString().padLeft(2, '0')}';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.schedule_rounded, size: 15, color: CoresEleva.dourado),
        SizedBox(width: 6),
        Text(data,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: CoresEleva.brancoSuave)),
        SizedBox(width: 8),
        Text(hora,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: CoresEleva.dourado,
                letterSpacing: 0.5)),
      ],
    );
  }
}
