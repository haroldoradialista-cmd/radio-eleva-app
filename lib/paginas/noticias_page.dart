import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../servicos/config_service.dart';
import '../tema.dart';
import '../servicos/analytics_service.dart';
import '../widgets/anuncio_banner.dart';
import '../widgets/midia_eleva.dart';

class NoticiasPage extends StatelessWidget {
  NoticiasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FundoEleva(
      child: SafeArea(
        child: ValueListenableBuilder<AppConfig>(
          valueListenable: ConfigService.instancia.config,
          builder: (context, cfg, _) {
            return RefreshIndicator(
              color: CoresEleva.verde,
              onRefresh: () => ConfigService.instancia.carregar(),
              child: ListView(
                padding: EdgeInsets.all(14),
                children: [
                  AnuncioBanner(),
                  Row(
                    children: [
                      Icon(Icons.newspaper_rounded,
                          color: CoresEleva.dourado),
                      SizedBox(width: 10),
                      Text('Notícias',
                          style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                  SizedBox(height: 12),
                  if (filtrarAgendados(cfg.noticias).isEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(
                          child: Text('Nenhuma notícia no momento.\nPuxe para atualizar.',
                              textAlign: TextAlign.center)),
                    ),
                  ...filtrarAgendados(cfg.noticias).map((n) => _cardNoticia(context, n)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _cardNoticia(BuildContext context, Map<String, dynamic> n) {
    return Card(
      color: CoresEleva.azulMedio,
      margin: EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          AnalyticsService.registrarEvento('noticia_cliques',
              (n['id'] ?? n['titulo'] ?? 'noticia').toString(), {
            'titulo': (n['titulo'] ?? '').toString(),
          });
          _abrir(context, n);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((n['imagem'] ?? '').toString().isNotEmpty ||
                MidiaEleva.ehVideo(n))
              SizedBox(
                height: 160,
                width: double.infinity,
                child: MidiaEleva(
                    item: n,
                    fit: BoxFit.cover,
                    placeholder: () => const SizedBox.shrink()),
              ),
            Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((n['data'] ?? '').toString().isNotEmpty)
                    Text(n['data'],
                        style: TextStyle(
                            color: CoresEleva.dourado,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text(n['titulo'] ?? '',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: CoresEleva.branco)),
                  SizedBox(height: 6),
                  Text(n['resumo'] ?? '',
                      style:
                          TextStyle(color: CoresEleva.brancoSuave)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrir(BuildContext context, Map<String, dynamic> n) {
    final link = (n['link'] ?? '').toString();
    final texto = (n['texto'] ?? '').toString();
    if (link.isNotEmpty) {
      final uri = Uri.tryParse(link);
      if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (texto.isNotEmpty) {
      showModalBottomSheet(
        context: context,
        backgroundColor: CoresEleva.azulMedio,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          builder: (context, scroll) => SingleChildScrollView(
            controller: scroll,
            padding: EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n['titulo'] ?? '',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: CoresEleva.branco)),
                SizedBox(height: 14),
                Text(texto,
                    style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: CoresEleva.brancoSuave)),
              ],
            ),
          ),
        ),
      );
    }
  }
}
