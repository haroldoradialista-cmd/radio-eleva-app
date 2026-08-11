import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../servicos/analytics_service.dart';
import '../servicos/config_service.dart';
import 'midia_eleva.dart';

/// Pop-up de campanha na abertura do app.
///
/// Mostra uma imagem em tela cheia (definida no painel), com o botão X
/// aparecendo só depois de alguns segundos. Ao tocar na imagem, abre o
/// link da campanha (se houver) e registra o clique para o relatório.
/// Aparece no máximo UMA vez por dia por aparelho.
class CampanhaPopup {
  /// Remove acentos e deixa minúsculo, para comparar cidade/estado com folga.
  static String _norm(String s) {
    s = s.toLowerCase().trim();
    const de = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const para = 'aaaaaeeeeiiiiooooouuuuc';
    for (int i = 0; i < de.length; i++) {
      s = s.replaceAll(de[i], para[i]);
    }
    return s;
  }

  /// A campanha é para este ouvinte? (país / estado / cidade)
  /// Regra de ouro: se a localização do ouvinte é DESCONHECIDA, só campanha
  /// de nível 'pais' pode aparecer — nunca uma regional (evita vazar região).
  static bool _alcanca(Map<String, dynamic> c) {
    final nivel = (c['nivel'] ?? 'pais').toString(); // pais | estado | cidade
    if (nivel == 'pais') return true; // todo o país

    final estadoAlvo = _norm((c['estado'] ?? '').toString());
    final estadoOuvinte = _norm(AnalyticsService.estado);
    final ufOuvinte = _norm(AnalyticsService.uf);

    // Sem localização confiável do ouvinte, campanha regional NÃO aparece.
    if (estadoOuvinte.isEmpty && ufOuvinte.isEmpty) return false;
    if (estadoAlvo.isEmpty) return false;

    // Casa o estado: igualdade pelo nome OU pela sigla (RJ, MG...).
    // Nada de "contains" solto — evita casar por engano.
    final bool estadoBate =
        estadoOuvinte == estadoAlvo || ufOuvinte == estadoAlvo;
    if (nivel == 'estado') return estadoBate;

    if (nivel == 'cidade') {
      final cidadeAlvo = _norm((c['cidade'] ?? '').toString());
      final cidadeOuvinte = _norm(AnalyticsService.cidade);
      // exige cidade do ouvinte conhecida E igual à cidade-alvo
      if (cidadeAlvo.isEmpty || cidadeOuvinte.isEmpty) return false;
      final cidadeBate = cidadeOuvinte == cidadeAlvo;
      // cidade só vale se o estado também bater (duas cidades homônimas existem)
      return cidadeBate && estadoBate;
    }
    return false;
  }

  /// Está no ar? (tem mídia, não finalizada e dentro do agendamento)
  static bool _noAr(Map<String, dynamic> c) {
    final temMidia = (c['imagem'] ?? '').toString().isNotEmpty ||
        (c['video'] ?? '').toString().isNotEmpty ||
        (c['youtube'] ?? '').toString().isNotEmpty;
    if (!temMidia) return false;
    if ((c['finalizado'] ?? '').toString() == 'sim') return false;
    final agora = DateTime.now();
    final ini = DateTime.tryParse((c['publicar_em'] ?? '').toString());
    final fim = DateTime.tryParse((c['expirar_em'] ?? '').toString());
    if (ini != null && agora.isBefore(ini)) return false;
    if (fim != null && agora.isAfter(fim)) return false;
    return true;
  }

  /// Decide se deve mostrar e, em caso positivo, exibe o pop-up.
  /// true enquanto o banner esta na tela (evita abrir dois ao mesmo tempo)
  static bool _naTela = false;

  static Future<void> talvezMostrar(
      BuildContext context, AppConfig cfg) async {
    if (_naTela) return; // ja tem um banner aberto
    // monta a lista: novas campanhas + a campanha única antiga (compatibilidade)
    final lista = <Map<String, dynamic>>[];
    lista.addAll(cfg.campanhas);
    if (cfg.campanha.isNotEmpty) lista.add(cfg.campanha);
    if (lista.isEmpty) return;

    // Se existe alguma campanha REGIONAL, espera a localização carregar antes
    // de decidir (senão o anúncio de outra região pode vazar).
    final temRegional =
        lista.any((c) => (c['nivel'] ?? 'pais').toString() != 'pais');
    if (temRegional) {
      await AnalyticsService.garantirLocalizacao();
    }
    if (!context.mounted) return;

    // filtra: no ar E que alcança a região deste ouvinte
    final elegiveis =
        lista.where((c) => _noAr(c) && _alcanca(c)).toList();
    if (elegiveis.isEmpty) return;

    // se houver mais de uma, sorteia (divide a exposição entre clientes)
    elegiveis.shuffle();
    final c = elegiveis.first;

    final imagem = (c['imagem'] ?? '').toString();
    final agora = DateTime.now();

    // FREQUÊNCIA por campanha: sempre | hora | dia
    // Padrao = 'sempre': o banner de abertura e um COMERCIAL do cliente,
    // entao aparece toda vez que o ouvinte abre o app. So limita se o
    // painel pedir explicitamente 'dia' ou 'hora'.
    final freq = (c['frequencia'] ?? 'sempre').toString().trim().toLowerCase();
    final assinatura = '${(c['id'] ?? imagem)}';
    try {
      final prefs = await SharedPreferences.getInstance();
      final ultimaMs = prefs.getInt('campanha_vista_ms_$assinatura') ?? 0;
      final ultima = DateTime.fromMillisecondsSinceEpoch(ultimaMs);
      if (freq == 'dia') {
        final mesmoDia = ultima.year == agora.year &&
            ultima.month == agora.month &&
            ultima.day == agora.day;
        if (mesmoDia) return;
      } else if (freq == 'hora') {
        if (agora.difference(ultima).inMinutes < 60) return;
      }
      // qualquer outro valor (inclusive 'sempre' ou vazio) => mostra sempre
      await prefs.setInt(
          'campanha_vista_ms_$assinatura', agora.millisecondsSinceEpoch);
    } catch (_) {}

    // registra a VISUALIZAÇÃO (impressão) para o relatório
    _registrarEvento(cfg, assinatura, 'view');

    if (!context.mounted) return;
    final segundos = int.tryParse((c['segundos_fechar'] ?? '5').toString()) ?? 5;

    _naTela = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (_) => _CampanhaDialog(
        cfg: cfg,
        imagem: imagem,
        link: (c['link'] ?? '').toString(),
        idCampanha: assinatura,
        segundos: segundos,
        tamanho: (c['tamanho'] ?? 'retrato').toString(),
        item: c,
      ),
    ).whenComplete(() => _naTela = false);
  }

  /// Grava um evento (view/clique) com a localização, para os relatórios.
  static void _registrarEvento(
      AppConfig cfg, String idCampanha, String tipo) {
    if (cfg.chatUrl.isEmpty) return;
    final base = cfg.chatUrl.replaceAll(RegExp(r'/chat/?$'), '');
    // Grava no nó banner_cliques (já gravável no Firebase) com marca CAMPANHA:
    // e também no nó campanha_eventos (caso as regras permitam) — o que der.
    final corpo = jsonEncode({
      'banner': 'CAMPANHA:$idCampanha',
      'campanha': idCampanha,
      'tipo': tipo, // 'view' ou 'clique'
      'quando': DateTime.now().toIso8601String(),
      'cidade': AnalyticsService.cidade,
      'estado': AnalyticsService.estado,
      'pais': AnalyticsService.pais,
    });
    try {
      http.post(Uri.parse('$base/banner_cliques.json'), body: corpo);
    } catch (_) {}
    try {
      http.post(Uri.parse('$base/campanha_eventos.json'), body: corpo);
    } catch (_) {}
  }
}

class _CampanhaDialog extends StatefulWidget {
  final AppConfig cfg;
  final String imagem;
  final String link;
  final String idCampanha;
  final int segundos;
  final String tamanho;
  final Map<String, dynamic> item;
  const _CampanhaDialog({
    required this.cfg,
    required this.imagem,
    required this.link,
    required this.idCampanha,
    required this.segundos,
    required this.tamanho,
    required this.item,
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
    // registra o CLIQUE no relatório da campanha (mesma coleção da visualização)
    CampanhaPopup._registrarEvento(widget.cfg, widget.idCampanha, 'clique');
    final uri = Uri.tryParse(widget.link);
    if (widget.link.isNotEmpty && uri != null) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    _fechar();
  }

  @override
  Widget build(BuildContext context) {
    final podeFechar = _resta <= 0;
    final telaCheia = widget.tamanho == 'cheia';
    // Bloqueia o botão VOLTAR do Android: o anúncio só fecha pelo X.
    // Enquanto a contagem não zera, nem o X nem o Voltar fecham.
    return PopScope(
      canPop: false,
      child: Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: telaCheia
          ? EdgeInsets.zero
          : const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              // A imagem da campanha (toca para abrir o link)
              GestureDetector(
                onTap: widget.link.isEmpty ? null : _abrir,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(telaCheia ? 0 : 16),
                  child: MidiaEleva.ehVideo(widget.item)
                      ? SizedBox(
                          width: telaCheia
                              ? double.infinity
                              : MediaQuery.of(context).size.width,
                          height: telaCheia
                              ? MediaQuery.of(context).size.height
                              : MediaQuery.of(context).size.width * 1.25,
                          child: MidiaEleva(item: widget.item),
                        )
                      : Image.network(
                          widget.imagem,
                          fit: telaCheia ? BoxFit.cover : BoxFit.contain,
                          width: telaCheia ? double.infinity : null,
                          height: telaCheia
                              ? MediaQuery.of(context).size.height
                              : null,
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
      ),
    );
  }
}
