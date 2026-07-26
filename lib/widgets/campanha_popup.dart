import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../servicos/analytics_service.dart';
import '../servicos/config_service.dart';

/// Pop-up de campanha na abertura do app.
///
/// Mostra uma imagem em tela cheia (definida no painel), com o botão X
/// aparecendo só depois de alguns segundos. Ao tocar na imagem, abre o
/// link da campanha (se houver) e registra o clique para o relatório.
/// Aparece no máximo UMA vez por dia por aparelho.
class CampanhaPopup {
  /// Decide se deve mostrar e, em caso positivo, exibe o pop-up.
  static Future<void> talvezMostrar(
      BuildContext context, AppConfig cfg) async {
    final c = cfg.campanha;
    if (c.isEmpty) return;

    final imagem = (c['imagem'] ?? '').toString();
    if (imagem.isEmpty) return;

    // Respeita o agendamento (publicar_em / expirar_em), igual aos banners
    final agora = DateTime.now();
    final ini = DateTime.tryParse((c['publicar_em'] ?? '').toString());
    final fim = DateTime.tryParse((c['expirar_em'] ?? '').toString());
    if ((c['finalizado'] ?? '').toString() == 'sim') return;
    if (ini != null && agora.isBefore(ini)) return;
    if (fim != null && agora.isAfter(fim)) return;

    // Mostra no máximo uma vez por dia (por versão da campanha)
    final assinatura = '$imagem|${c['publicar_em'] ?? ''}';
    try {
      final prefs = await SharedPreferences.getInstance();
      final hoje = '${agora.year}-${agora.month}-${agora.day}';
      final marca = prefs.getString('campanha_vista') ?? '';
      if (marca == '$hoje|$assinatura') return; // já viu hoje
      await prefs.setString('campanha_vista', '$hoje|$assinatura');
    } catch (_) {}

    if (!context.mounted) return;
    final segundos = int.tryParse((c['segundos_fechar'] ?? '5').toString()) ?? 5;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.88),
      builder: (_) => _CampanhaDialog(
        cfg: cfg,
        imagem: imagem,
        link: (c['link'] ?? '').toString(),
        idCampanha: (c['id'] ?? imagem).toString(),
        segundos: segundos,
      ),
    );
  }
}

class _CampanhaDialog extends StatefulWidget {
  final AppConfig cfg;
  final String imagem;
  final String link;
  final String idCampanha;
  final int segundos;
  const _CampanhaDialog({
    required this.cfg,
    required this.imagem,
    required this.link,
    required this.idCampanha,
    required this.segundos,
  });
  @override
  State<_CampanhaDialog> createState() => _CampanhaDialogState();
}

class _CampanhaDialogState extends State<_CampanhaDialog> {
  int _resta = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _resta = widget.segundos;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _resta--);
      if (_resta <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _fechar() {
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  void _abrir() {
    // registra o clique (mesmo relatório dos banners) e abre o link
    final cfg = widget.cfg;
    if (widget.link.isNotEmpty && cfg.chatUrl.isNotEmpty) {
      final base = cfg.chatUrl.replaceAll(RegExp(r'/chat/?$'), '');
      try {
        http.post(Uri.parse('$base/banner_cliques.json'),
            body: jsonEncode({
              'banner': 'CAMPANHA:${widget.idCampanha}',
              'quando': DateTime.now().toIso8601String(),
              'cidade': AnalyticsService.cidade,
              'estado': AnalyticsService.estado,
              'pais': AnalyticsService.pais,
              'dispositivo': 'Android',
            }));
      } catch (_) {}
    }
    final uri = Uri.tryParse(widget.link);
    if (widget.link.isNotEmpty && uri != null) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    _fechar();
  }

  @override
  Widget build(BuildContext context) {
    final podeFechar = _resta <= 0;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              // A imagem da campanha (toca para abrir o link)
              GestureDetector(
                onTap: widget.link.isEmpty ? null : _abrir,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    widget.imagem,
                    fit: BoxFit.contain,
                    loadingBuilder: (c, filho, prog) {
                      if (prog == null) return filho;
                      return Container(
                        height: 320,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(
                            color: Colors.white),
                      );
                    },
                    errorBuilder: (c, e, s) => const SizedBox.shrink(),
                  ),
                ),
              ),
              // Botão X: só aparece depois da contagem
              Positioned(
                top: 8,
                right: 8,
                child: podeFechar
                    ? GestureDetector(
                        onTap: _fechar,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 1.4),
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 22),
                        ),
                      )
                    : Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                        ),
                        child: Text('$_resta',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15)),
                      ),
              ),
            ],
          ),
          if (widget.link.isNotEmpty && podeFechar)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: GestureDetector(
                onTap: _abrir,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text('SAIBA MAIS',
                      style: TextStyle(
                          color: Color(0xFF0E0857),
                          fontWeight: FontWeight.w900,
                          fontSize: 13)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
