import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../servicos/config_service.dart';
import '../tema.dart';

/// Cartão de enquete fixo na tela inicial (entre o banner e o player).
/// Depois de votar, o ouvinte vê a confirmação — os resultados ficam no Painel.
class EnqueteCard extends StatefulWidget {
  EnqueteCard({super.key});
  @override
  State<EnqueteCard> createState() => _EnqueteCardState();
}

class _EnqueteCardState extends State<EnqueteCard> {
  bool _jaVotou = false;
  String _idCarregado = '';
  bool _enviando = false;

  String _baseRtdb(AppConfig cfg) =>
      cfg.chatUrl.replaceAll(RegExp(r'/chat/?$'), '');

  Future<void> _prepararEnquete(Map<String, dynamic> e) async {
    final id = (e['id'] ?? '').toString();
    if (id == _idCarregado) return;
    _idCarregado = id;
    final prefs = await SharedPreferences.getInstance();
    final votou = prefs.getInt('enquete_$id') != null;
    if (mounted && votou != _jaVotou) setState(() => _jaVotou = votou);
    _jaVotou = votou;
  }

  Future<void> _votar(AppConfig cfg, Map<String, dynamic> e, int opcao) async {
    if (_enviando || _jaVotou) return;
    setState(() => _enviando = true);
    final id = (e['id'] ?? '').toString();
    try {
      await http.post(
        Uri.parse('${_baseRtdb(cfg)}/enquete_votos/$id.json'),
        body: jsonEncode({
          'opcao': opcao,
          'quando': DateTime.now().toIso8601String(),
        }),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('enquete_$id', opcao);
      _jaVotou = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: Duration(seconds: 2),
          backgroundColor: CoresEleva.verdeEscuro,
          content: Text('Voto registrado. Obrigado por participar! 🙌'),
        ));
      }
    } catch (_) {}
    if (mounted) setState(() => _enviando = false);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppConfig>(
      valueListenable: ConfigService.instancia.config,
      builder: (context, cfg, _) {
        if (cfg.chatUrl.isEmpty) return SizedBox.shrink();
        final ativas = filtrarAgendados(cfg.enquetes);
        if (ativas.isEmpty) return SizedBox.shrink();
        final e = ativas.first;
        final opcoes = List<String>.from(e['opcoes'] ?? []);
        if (opcoes.isEmpty) return SizedBox.shrink();
        _prepararEnquete(e);

        return Container(
          margin: EdgeInsets.fromLTRB(14, 10, 14, 0),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CoresEleva.azulMedio,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: CoresEleva.dourado.withOpacity(0.55), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.poll_rounded,
                      color: CoresEleva.dourado, size: 18),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      (e['pergunta'] ?? 'Enquete').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: CoresEleva.branco),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              if (!_jaVotou)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: List.generate(opcoes.length, (i) {
                    return GestureDetector(
                      onTap: () => _votar(cfg, e, i),
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: CoresEleva.botaoPlay,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(opcoes[i],
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    );
                  }),
                )
              else
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: CoresEleva.verde, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Você já votou nesta enquete. Obrigado por participar! 🙌',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: CoresEleva.brancoSuave),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
