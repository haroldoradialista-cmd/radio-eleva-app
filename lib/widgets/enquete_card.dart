import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../servicos/config_service.dart';
import '../tema.dart';

/// Cartão de enquete fixo na tela inicial (entre o banner e o player).
/// A enquete ativa é definida e agendada pelo Painel Eleva.
class EnqueteCard extends StatefulWidget {
  const EnqueteCard({super.key});
  @override
  State<EnqueteCard> createState() => _EnqueteCardState();
}

class _EnqueteCardState extends State<EnqueteCard> {
  int? _votoDado;
  Map<int, int> _resultados = {};
  String _idCarregado = '';
  bool _enviando = false;

  String _baseRtdb(AppConfig cfg) =>
      cfg.chatUrl.replaceAll(RegExp(r'/chat/?$'), '');

  Future<void> _prepararEnquete(AppConfig cfg, Map<String, dynamic> e) async {
    final id = (e['id'] ?? '').toString();
    if (id == _idCarregado) return;
    _idCarregado = id;
    final prefs = await SharedPreferences.getInstance();
    final voto = prefs.getInt('enquete_$id');
    if (voto != null) {
      _votoDado = voto;
      await _buscarResultados(cfg, id);
    } else {
      _votoDado = null;
      _resultados = {};
    }
    if (mounted) setState(() {});
  }

  Future<void> _buscarResultados(AppConfig cfg, String id) async {
    try {
      final r = await http
          .get(Uri.parse('${_baseRtdb(cfg)}/enquete_votos/$id.json'));
      if (r.statusCode == 200 && r.body != 'null') {
        final dados = jsonDecode(r.body) as Map<String, dynamic>;
        final mapa = <int, int>{};
        for (final v in dados.values) {
          final o = int.tryParse((v['opcao'] ?? '').toString()) ?? -1;
          if (o >= 0) mapa[o] = (mapa[o] ?? 0) + 1;
        }
        _resultados = mapa;
      }
    } catch (_) {}
  }

  Future<void> _votar(AppConfig cfg, Map<String, dynamic> e, int opcao) async {
    if (_enviando) return;
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
      _votoDado = opcao;
      await _buscarResultados(cfg, id);
    } catch (_) {}
    if (mounted) setState(() => _enviando = false);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppConfig>(
      valueListenable: ConfigService.instancia.config,
      builder: (context, cfg, _) {
        if (cfg.chatUrl.isEmpty) return const SizedBox.shrink();
        final ativas = filtrarAgendados(cfg.enquetes);
        if (ativas.isEmpty) return const SizedBox.shrink();
        final e = ativas.first;
        final opcoes = List<String>.from(e['opcoes'] ?? []);
        if (opcoes.isEmpty) return const SizedBox.shrink();
        _prepararEnquete(cfg, e);

        final totalVotos =
            _resultados.values.fold<int>(0, (s, v) => s + v);

        return Container(
          margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          padding: const EdgeInsets.all(12),
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
                  const Icon(Icons.poll_rounded,
                      color: CoresEleva.dourado, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      (e['pergunta'] ?? 'Enquete').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: CoresEleva.branco),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_votoDado == null)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: List.generate(opcoes.length, (i) {
                    return GestureDetector(
                      onTap: () => _votar(cfg, e, i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: CoresEleva.botaoPlay,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(opcoes[i],
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    );
                  }),
                )
              else
                Column(
                  children: List.generate(opcoes.length, (i) {
                    final votos = _resultados[i] ?? 0;
                    final fracao =
                        totalVotos == 0 ? 0.0 : votos / totalVotos;
                    final pct = (fracao * 100).round();
                    final minha = i == _votoDado;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                Container(
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: CoresEleva.azulProfundo,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor:
                                      fracao.clamp(0.02, 1.0),
                                  child: Container(
                                    height: 20,
                                    decoration: BoxDecoration(
                                      gradient: minha
                                          ? CoresEleva.botaoPlay
                                          : null,
                                      color: minha
                                          ? null
                                          : CoresEleva.azulVivo
                                              .withOpacity(0.35),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '${opcoes[i]}${minha ? ' ✓' : ''}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: CoresEleva.branco),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 36,
                            child: Text('$pct%',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: CoresEleva.dourado)),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              if (_votoDado != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('$totalVotos votos • obrigado por participar!',
                      style: const TextStyle(
                          fontSize: 10.5, color: CoresEleva.brancoSuave)),
                ),
            ],
          ),
        );
      },
    );
  }
}
