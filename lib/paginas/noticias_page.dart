import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../servicos/config_service.dart';
import '../tema.dart';

class NoticiasPage extends StatelessWidget {
  const NoticiasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: CoresEleva.fundoApp),
      child: SafeArea(
        child: ValueListenableBuilder<AppConfig>(
          valueListenable: ConfigService.instancia.config,
          builder: (context, cfg, _) {
            return RefreshIndicator(
              color: CoresEleva.verde,
              onRefresh: () => ConfigService.instancia.carregar(),
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  Row(
                    children: [
                      const Icon(Icons.newspaper_rounded,
                          color: CoresEleva.dourado),
                      const SizedBox(width: 10),
                      Text('Notícias',
                          style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (filtrarAgendados(cfg.noticias).isEmpty)
                    const Padding(
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
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _abrir(context, n),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((n['imagem'] ?? '').toString().isNotEmpty)
              Image.network(
                n['imagem'],
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((n['data'] ?? '').toString().isNotEmpty)
                    Text(n['data'],
                        style: const TextStyle(
                            color: CoresEleva.dourado,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(n['titulo'] ?? '',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: CoresEleva.branco)),
                  const SizedBox(height: 6),
                  Text(n['resumo'] ?? '',
                      style:
                          const TextStyle(color: CoresEleva.brancoSuave)),
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
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          builder: (context, scroll) => SingleChildScrollView(
            controller: scroll,
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n['titulo'] ?? '',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: CoresEleva.branco)),
                const SizedBox(height: 14),
                Text(texto,
                    style: const TextStyle(
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
