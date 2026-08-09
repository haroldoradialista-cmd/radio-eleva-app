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
import '../servicos/letra_service.dart';
import '../servicos/auth_service.dart';
import '../tema.dart';
import '../widgets/anuncio_banner.dart';
import '../widgets/midia_eleva.dart';
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

  /// Corrige o nome da música vindo do metadado do stream:
  /// - conserta acentuação corrompida (encoding Latin-1 lido como UTF-8)
  /// - padroniza o travessão longo (— ou –) para traço simples ( - )
  String _limparNomeMusica(String bruto) {
    if (bruto.isEmpty) return bruto;
    var s = bruto;
    if (s.contains('Ã') || s.contains('Â') || s.contains('â€')) {
      try {
        final recuperado = latin1.decode(s.codeUnits);
        if (!recuperado.contains('Ã') && !recuperado.contains('â€')) {
          s = recuperado;
        }
      } catch (_) {}
    }
    s = s.replaceAll(' — ', ' - ').replaceAll(' – ', ' - ');
    s = s.replaceAll('—', ' - ').replaceAll('–', ' - ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  @override
  void initState() {
    super.initState();
    // Quando o usuário troca de conta, reavalia a curtida da música atual
    AuthService.instancia.usuario.addListener(_aoTrocarUsuario);
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

  void _aoTrocarUsuario() {
    // novo usuário → confere se ELE já curtiu a música que está tocando
    _conferirCurtida(_musicaAtual);
  }

  @override
  void dispose() {
    AuthService.instancia.usuario.removeListener(_aoTrocarUsuario);
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

  /// Identificador do usuário logado (para a curtida ser por conta).
  /// Se ninguém está logado, usa 'anon' (curtida do aparelho).
  String get _idUsuario =>
      AuthService.instancia.usuario.value?.uid ?? 'anon';

  /// Chave da curtida: música + usuário → cada conta tem a sua curtida
  String _chaveCurtida(String musica) =>
      'curtiu_${_idUsuario}_${musica.hashCode}';

  Future<void> _curtir(AppConfig cfg) async {
    if (_curtiu || _musicaAtual.isEmpty) return; // uma curtida por música
    setState(() => _curtiu = true);
    final prefs = await SharedPreferences.getInstance();
    final chave = _chaveCurtida(_musicaAtual);
    if (prefs.getBool(chave) == true) return; // este usuário já curtiu
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

  /// Ao trocar de música (ou de usuário), verifica se ESTE usuário já curtiu
  Future<void> _conferirCurtida(String musica) async {
    if (musica.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final ja = prefs.getBool(_chaveCurtida(musica)) == true;
    if (mounted && ja != _curtiu) setState(() => _curtiu = ja);
  }

  /// Abre um painel deslizante com a letra da música tocando agora
  void _abrirLetra(BuildContext context, AppConfig cfg) {
    final musica = _musicaAtual.trim();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.62,
          minChildSize: 0.4,
          maxChildSize: 0.62,
          expand: false,
          builder: (ctx, scrollCtrl) {
            return Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(CoresEleva.escuro
                      ? 'assets/fundo_escuro.jpg'
                      : 'assets/fundo_claro.jpg'),
                  fit: BoxFit.cover,
                ),
                color: CoresEleva.escuro
                    ? const Color(0xFF2E105A)
                    : const Color(0xFFE6F65A),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(
                    color: CoresEleva.dourado.withOpacity(0.5), width: 1),
              ),
              child: Column(
                children: [
                  // puxador
                  Container(
                    margin: EdgeInsets.only(top: 10, bottom: 6),
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: CoresEleva.dourado.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 4),
                    child: Row(
                      children: [
                        Icon(Icons.lyrics_rounded,
                            color: CoresEleva.dourado, size: 22),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            musica.isEmpty ? 'Letra da música' : musica,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: CoresEleva.dourado),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: CoresEleva.textoFraco),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: CoresEleva.dourado.withOpacity(0.3), height: 1),
                  Expanded(
                    child: musica.isEmpty
                        ? _letraMensagem(
                            '🎵 Aguarde uma música começar a tocar para ver a letra aqui.')
                        : FutureBuilder<String?>(
                            future: LetraService.buscar(musica),
                            builder: (ctx, snap) {
                              if (snap.connectionState ==
                                  ConnectionState.waiting) {
                                return Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(
                                          color: CoresEleva.dourado),
                                      SizedBox(height: 14),
                                      Text('Buscando a letra...',
                                          style: TextStyle(
                                              color: CoresEleva.textoFraco)),
                                    ],
                                  ),
                                );
                              }
                              final letra = snap.data;
                              if (letra == null || letra.isEmpty) {
                                return Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(28),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '😕 Não encontramos a letra desta música na nossa base.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontSize: 14,
                                              height: 1.5,
                                              color: CoresEleva.textoFraco),
                                        ),
                                        SizedBox(height: 18),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            final busca = Uri.encodeComponent(
                                                '$musica letra');
                                            launchUrl(
                                                Uri.parse(
                                                    'https://www.google.com/search?q=$busca'),
                                                mode: LaunchMode
                                                    .externalApplication);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                CoresEleva.dourado,
                                            foregroundColor:
                                                const Color(0xFF0E0857),
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 20,
                                                vertical: 12),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        22)),
                                          ),
                                          icon: Icon(Icons.search_rounded,
                                              size: 18),
                                          label: Text('Buscar no navegador',
                                              style: TextStyle(
                                                  fontWeight:
                                                      FontWeight.w800)),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              return SingleChildScrollView(
                                controller: scrollCtrl,
                                padding: EdgeInsets.fromLTRB(22, 16, 22, 40),
                                child: Text(
                                  letra,
                                  style: TextStyle(
                                      fontSize: 16,
                                      height: 1.6,
                                      fontWeight: FontWeight.w500,
                                      color: CoresEleva.branco),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _letraMensagem(String texto) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Text(
          texto,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: CoresEleva.textoFraco),
        ),
      ),
    );
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
        return FundoEleva(
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
                                        child: MidiaEleva(
                                          item: b,
                                          fit: BoxFit.cover,
                                          placeholder: _bannerPadrao,
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
                          SizedBox(height: 8),
                          // Botão LETRA (acima da capa)
                          GestureDetector(
                            onTap: () => _abrirLetra(context, cfg),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  CoresEleva.dourado,
                                  CoresEleva.dourado.withOpacity(0.7),
                                ]),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        CoresEleva.dourado.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lyrics_rounded,
                                      size: 14,
                                      color: CoresEleva.escuro
                                          ? const Color(0xFF0E0857)
                                          : Colors.white),
                                  SizedBox(width: 5),
                                  Text('LETRA',
                                      style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.2,
                                          color: CoresEleva.escuro
                                              ? const Color(0xFF0E0857)
                                              : Colors.white)),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          // Capa da música / foto do programa no ar
                          CapaMusica(
                            tamanho: (c.maxHeight * 0.32)
                                .clamp(184.0, 248.0)
                                .toDouble(),
                              reserva: (noAr?['imagem'] ?? '').toString()),
                          SizedBox(height: 12),
                          Column(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFB71C1C),
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
                                            ? 'NO AR • ${(noAr['programa'] ?? '').toString().toUpperCase()}'
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
                              SizedBox(height: 8),
                              // linha divisória entre o AO VIVO e o nome da música
                              Container(
                                width: 110,
                                height: 1,
                                color: CoresEleva.dourado.withOpacity(0.45),
                              ),
                              SizedBox(height: 8),
                              StreamBuilder<IcyMetadata?>(
                                stream: player.icyMetadataStream,
                                builder: (context, snap) {
                                  final titulo = _limparNomeMusica(
                                      snap.data?.info?.title?.trim() ?? '');
                                  if (titulo != _musicaAtual) {
                                    _musicaAtual = titulo;
                                    // NÃO zera _curtiu aqui: quem decide é o
                                    // _conferirCurtida, que lê do disco se
                                    // este usuário já curtiu esta música.
                                    // (evita "descurtir" ao trocar de tema)
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
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: CoresEleva.brancoSuave),
                                  );
                                },
                              ),
                            ],
                          ),

                          SizedBox(height: 10),
                          // CORAÇÃO — PLAY — COMPARTILHAR
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () => _curtir(cfg),
                                child: Container(
                                  width: 48,
                                  height: 48,
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
                                    size: 23,
                                  ),
                                ),
                              ),
                              SizedBox(width: 26),
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
                                      width: 74,
                                      height: 74,
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
                                              padding: EdgeInsets.all(22),
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
                                              size: 40,
                                              color: Colors.white,
                                            ),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(width: 26),
                              GestureDetector(
                                onTap: () => _compartilhar(cfg),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: CoresEleva.dourado,
                                        width: 2),
                                  ),
                                  child: Icon(Icons.share_rounded,
                                      color: CoresEleva.dourado, size: 20),
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


/// Moldura com pequenas lâmpadas coloridas em volta de toda a borda,
/// piscando alternadamente como os letreiros luminosos antigos
/// (marquises de cinema/teatro dos anos 70, 80, 90).
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
      duration: const Duration(milliseconds: 700),
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
          foregroundPainter: _LampadasPainter(_ctrl.value, widget.raio),
          child: filho,
        );
      },
      child: Padding(padding: const EdgeInsets.all(11), child: widget.child),
    );
  }
}

/// Desenha lâmpadas pequenas ao redor de toda a borda, acendendo e
/// apagando alternadamente em cores vivas (estilo letreiro retrô).
class _LampadasPainter extends CustomPainter {
  final double t;
  final double raio;
  _LampadasPainter(this.t, this.raio);

  @override
  void paint(Canvas canvas, Size size) {
    // ===== MOLDURA (trilho onde as lâmpadas ficam dentro) =====
    // faixa escura com borda dourada em volta de toda a imagem
    final rExterno = RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(raio));
    final rInterno = RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(9),
        Radius.circular((raio - 6).clamp(0, raio)));

    // corpo da moldura (o "trilho"): anel escuro entre a borda e o miolo
    final trilho = Path.combine(
        PathOperation.difference,
        Path()..addRRect(rExterno),
        Path()..addRRect(rInterno));
    canvas.drawPath(trilho, Paint()..color = const Color(0xFF1A1636));

    // borda dourada externa e interna da moldura
    final ouro = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFFE6C15A).withOpacity(0.9);
    canvas.drawRRect(rExterno.deflate(0.7), ouro);
    canvas.drawRRect(rInterno, ouro);

    // ===== LÂMPADAS BRANCAS dentro da moldura =====
    // caminho central do trilho (meio do anel) por onde passam as lâmpadas
    final meio = RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(4.5),
        Radius.circular((raio - 3).clamp(0, raio)));
    final path = Path()..addRRect(meio);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final total = metric.length;

    const espacamento = 16.0;
    int qtd = (total / espacamento).round();
    if (qtd < 8) qtd = 8;

    final onda = t;

    for (int i = 0; i < qtd; i++) {
      final dist = (i / qtd) * total;
      final tan = metric.getTangentForOffset(dist);
      if (tan == null) continue;
      final p = tan.position;

      final grupo = i % 2;
      double brilho;
      if (grupo == 0) {
        brilho = (onda < 0.5) ? 1.0 : 0.25;
      } else {
        brilho = (onda >= 0.5) ? 1.0 : 0.25;
      }

      // todas as lâmpadas são BRANCAS; muda só a intensidade ao piscar
      final corAcesa = Colors.white.withOpacity(0.25 + 0.75 * brilho);

      if (brilho > 0.6) {
        final halo = Paint()
          ..color = Colors.white.withOpacity(0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(p, 4.5, halo);
      }

      final bulbo = Paint()..color = corAcesa;
      canvas.drawCircle(p, 2.8, bulbo);
    }
  }

  @override
  bool shouldRepaint(_LampadasPainter old) => old.t != t;
}
