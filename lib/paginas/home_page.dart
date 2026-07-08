import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../servicos/config_service.dart';
import '../servicos/player_service.dart';
import '../tema.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _pageController = PageController();
  Timer? _timerBanner;
  int _bannerAtual = 0;
  String? _voto; // 'like' | 'dislike'
  String _musicaAtual = '';

  @override
  void initState() {
    super.initState();
    _timerBanner = Timer.periodic(const Duration(seconds: 5), (_) {
      final banners = ConfigService.instancia.config.value.banners;
      if (banners.length > 1 && _pageController.hasClients) {
        _bannerAtual = (_bannerAtual + 1) % banners.length;
        _pageController.animateToPage(_bannerAtual,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOut);
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

  void _registrarVoto(String tipo, AppConfig cfg) {
    setState(() => _voto = tipo);
    PlayerService.instancia.votar(cfg.chatUrl, tipo, _musicaAtual);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 2),
      backgroundColor:
          tipo == 'like' ? CoresEleva.verdeEscuro : CoresEleva.azulMedio,
      content: Text(tipo == 'like'
          ? 'Que bom que você gostou! 🙌'
          : 'Obrigado pela sua opinião!'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final player = PlayerService.instancia.player;
    return ValueListenableBuilder<AppConfig>(
      valueListenable: ConfigService.instancia.config,
      builder: (context, cfg, _) {
        return Container(
          decoration: const BoxDecoration(gradient: CoresEleva.fundoApp),
          child: SafeArea(
            child: LayoutBuilder(builder: (context, c) {
              final alturaBanner = c.maxHeight / 3; // 1/3 da tela, como pedido
              return Column(
                children: [
                  // ===== BANNERS (1/3 superior) =====
                  SizedBox(
                    height: alturaBanner,
                    width: double.infinity,
                    child: cfg.banners.isEmpty
                        ? _bannerPadrao(cfg)
                        : Stack(
                            children: [
                              PageView.builder(
                                controller: _pageController,
                                itemCount: cfg.banners.length,
                                onPageChanged: (i) =>
                                    setState(() => _bannerAtual = i),
                                itemBuilder: (context, i) {
                                  final b = cfg.banners[i];
                                  return GestureDetector(
                                    onTap: () => _abrirLink(b['link']),
                                    child: Image.network(
                                      b['imagem'] ?? '',
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      errorBuilder: (_, __, ___) =>
                                          _bannerPadrao(cfg),
                                      loadingBuilder: (_, w, p) => p == null
                                          ? w
                                          : Container(
                                              color: CoresEleva.azulMedio),
                                    ),
                                  );
                                },
                              ),
                              // Indicadores de página
                              Positioned(
                                bottom: 10,
                                left: 0,
                                right: 0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    cfg.banners.length,
                                    (i) => AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 3),
                                      width: i == _bannerAtual ? 22 : 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: i == _bannerAtual
                                            ? CoresEleva.dourado
                                            : Colors.white38,
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

                  // ===== ÁREA DO PLAYER (2/3 inferior) =====
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Logo discreta + nome
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset('assets/logo.png',
                                    width: 46, height: 46),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cfg.nome,
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: CoresEleva.branco)),
                                  Text(cfg.slogan,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: CoresEleva.dourado,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1.2)),
                                ],
                              ),
                            ],
                          ),

                          // Selo AO VIVO + música atual (metadados do streaming)
                          Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade700,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.circle,
                                        size: 9, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text('AO VIVO',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            letterSpacing: 1.5)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              StreamBuilder<IcyMetadata?>(
                                stream: player.icyMetadataStream,
                                builder: (context, snap) {
                                  final titulo =
                                      snap.data?.info?.title?.trim() ?? '';
                                  if (titulo != _musicaAtual) {
                                    _musicaAtual = titulo;
                                    _voto = null; // nova música, zera voto
                                  }
                                  return Text(
                                    titulo.isEmpty
                                        ? 'Tocando agora na ${cfg.nome}'
                                        : titulo,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: CoresEleva.brancoSuave),
                                  );
                                },
                              ),
                            ],
                          ),

                          // DESLIKE — PLAY — LIKE (como pedido)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _botaoVoto(
                                icone: Icons.thumb_down_rounded,
                                ativo: _voto == 'dislike',
                                corAtiva: CoresEleva.azulVivo,
                                aoTocar: () => _registrarVoto('dislike', cfg),
                              ),
                              const SizedBox(width: 28),
                              StreamBuilder<PlayerState>(
                                stream: player.playerStateStream,
                                builder: (context, snap) {
                                  final estado = snap.data;
                                  final tocando = estado?.playing ?? false;
                                  final carregando = estado?.processingState ==
                                          ProcessingState.loading ||
                                      estado?.processingState ==
                                          ProcessingState.buffering;
                                  return GestureDetector(
                                    onTap: () async {
                                      await PlayerService.instancia.carregar(
                                          cfg.streamUrl,
                                          cfg.nome,
                                          cfg.logoUrl);
                                      await PlayerService.instancia.alternar();
                                    },
                                    child: Container(
                                      width: 92,
                                      height: 92,
                                      decoration: BoxDecoration(
                                        gradient: CoresEleva.botaoPlay,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: CoresEleva.dourado,
                                            width: 2.5),
                                        boxShadow: [
                                          BoxShadow(
                                            color: CoresEleva.verde
                                                .withOpacity(0.45),
                                            blurRadius: 26,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: carregando
                                          ? const Padding(
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
                                                  : Icons.play_arrow_rounded,
                                              size: 52,
                                              color: Colors.white,
                                            ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 28),
                              _botaoVoto(
                                icone: Icons.thumb_up_rounded,
                                ativo: _voto == 'like',
                                corAtiva: CoresEleva.verde,
                                aoTocar: () => _registrarVoto('like', cfg),
                              ),
                            ],
                          ),

                          // Redes sociais (gerenciável pelo config.json)
                          if (cfg.redes.isNotEmpty)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: cfg.redes.map((r) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  child: IconButton(
                                    onPressed: () => _abrirLink(r['link']),
                                    icon: Icon(_iconeRede(r['nome'] ?? ''),
                                        color: CoresEleva.dourado, size: 28),
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
        duration: const Duration(milliseconds: 200),
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ativo ? corAtiva : CoresEleva.azulMedio,
          border: Border.all(
              color: ativo ? CoresEleva.dourado : Colors.white24, width: 1.5),
        ),
        child: Icon(icone,
            color: ativo ? Colors.white : Colors.white70, size: 26),
      ),
    );
  }

  Widget _bannerPadrao(AppConfig cfg) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [CoresEleva.azulMedio, CoresEleva.verdeEscuro],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Image.asset('assets/logo.png', height: 130),
      ),
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
