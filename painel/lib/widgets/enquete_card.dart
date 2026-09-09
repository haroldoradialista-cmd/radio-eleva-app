import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../servicos/auth_service.dart';
import '../servicos/config_service.dart';
import '../tema.dart';
import '../servicos/analytics_service.dart';
import 'midia_eleva.dart';

/// Cartão de enquete fixo na tela inicial (entre o banner e o player).
/// Depois de votar, o ouvinte vê a confirmação — os resultados ficam no Painel.
class EnqueteCard extends StatefulWidget {
  EnqueteCard({super.key});
  @override
  State<EnqueteCard> createState() => _EnqueteCardState();
}

class _EnqueteCardState extends State<EnqueteCard> {
  /// Chave do voto: quando há conta logada, o voto é DA CONTA
  /// (outro e-mail no mesmo celular vota normalmente).
  String _chaveVoto(String id) {
    final u = AuthService.instancia.usuario.value;
    return u == null ? 'enquete_$id' : 'enquete_${id}_${u.uid}';
  }

  bool _jaVotou = false;
  String _idCarregado = '';
  String _marcaCarregada = '';
  bool _enviando = false;
  int _minhaOpcao = -1;
  Map<int, int> _parcial = {};
  int _totalVotos = 0;
  bool _carregandoParcial = false;

  String _baseRtdb(AppConfig cfg) =>
      cfg.chatUrl.replaceAll(RegExp(r'/chat/?$'), '');

  Future<void> _prepararEnquete(Map<String, dynamic> e,
      {bool encerrada = false}) async {
    final id = (e['id'] ?? '').toString();
    final uid = AuthService.instancia.usuario.value?.uid ?? '';
    final marca = '$id|$uid';
    if (marca == _marcaCarregada) return;
    _idCarregado = id;
    _marcaCarregada = marca;
    final prefs = await SharedPreferences.getInstance();
    final escolha = prefs.getInt(_chaveVoto(id));
    final votou = escolha != null;
    _jaVotou = votou;
    _minhaOpcao = escolha ?? -1;
    if (mounted) setState(() {});
    if (votou || encerrada) _buscarParcial(id);
  }

  /// Busca a apuração dos votos (usada no resultado parcial e no encerrado)
  Future<void> _buscarParcial(String id) async {
    if (_carregandoParcial || id.isEmpty) return;
    _carregandoParcial = true;
    try {
      final cfg = ConfigService.instancia.config.value;
      final r = await http.get(Uri.parse(
          '${_baseRtdb(cfg)}/enquete_votos/$id.json?t=${DateTime.now().millisecondsSinceEpoch}'));
      final d = jsonDecode(r.body);
      final contagem = <int, int>{};
      var total = 0;
      if (d is Map) {
        d.forEach((_, v) {
          if (v is Map && v['opcao'] != null) {
            final o = int.tryParse(v['opcao'].toString());
            if (o != null) {
              contagem[o] = (contagem[o] ?? 0) + 1;
              total++;
            }
          }
        });
      }
      if (mounted) {
        setState(() {
          _parcial = contagem;
          _totalVotos = total;
        });
      }
    } catch (_) {}
    _carregandoParcial = false;
  }

  /// Barras do resultado (parcial para quem votou, final quando encerrada)
  Widget _barras(List<String> opcoes, {required bool encerrada}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List.generate(opcoes.length, (i) {
          final votos = _parcial[i] ?? 0;
          final pct = _totalVotos > 0 ? (votos * 100 / _totalVotos) : 0.0;
          final minha = i == _minhaOpcao;
          return Padding(
            padding: EdgeInsets.only(bottom: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (minha)
                      Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.check_circle_rounded,
                            size: 13, color: CoresEleva.verde),
                      ),
                    Expanded(
                      child: Text(opcoes[i],
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  minha ? FontWeight.w800 : FontWeight.w600,
                              color: minha
                                  ? CoresEleva.verde
                                  : CoresEleva.brancoSuave)),
                    ),
                    Text('$votos • ${pct.toStringAsFixed(0)}%',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: CoresEleva.dourado)),
                  ],
                ),
                SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _totalVotos > 0 ? pct / 100 : 0,
                    minHeight: 8,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation(
                        minha ? CoresEleva.verde : CoresEleva.dourado),
                  ),
                ),
              ],
            ),
          );
        }),
        Row(
          children: [
            Text(
                '$_totalVotos ${_totalVotos == 1 ? 'voto' : 'votos'}${encerrada ? ' • resultado final' : ' • parcial'}',
                style: TextStyle(
                    fontSize: 11, color: CoresEleva.textoFraco)),
            Spacer(),
            GestureDetector(
              onTap: () => _buscarParcial(_idCarregado),
              child: Row(
                children: [
                  Icon(Icons.refresh_rounded,
                      size: 13, color: CoresEleva.dourado),
                  SizedBox(width: 3),
                  Text('ATUALIZAR',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: CoresEleva.dourado)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _votar(AppConfig cfg, Map<String, dynamic> e, int opcao) async {
    AnalyticsService.registrarEvento(
        'enquete_cliques', (e['id'] ?? 'enquete').toString(), {
      'pergunta': (e['pergunta'] ?? '').toString(),
      'opcao': opcao,
    });
    if (_enviando || _jaVotou) return;
    setState(() => _enviando = true);
    final id = (e['id'] ?? '').toString();
    try {
      await http.post(
        Uri.parse('${_baseRtdb(cfg)}/enquete_votos/$id.json'),
        body: jsonEncode({
          'opcao': opcao,
          'quando': DateTime.now().toIso8601String(),
          'uid': AuthService.instancia.usuario.value?.uid ?? '',
          'email': AuthService.instancia.usuario.value?.email ?? '',
        }),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_chaveVoto(id), opcao);
      _jaVotou = true;
      _minhaOpcao = opcao;
      await _buscarParcial(id);
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
    return ValueListenableBuilder<Usuario?>(
      valueListenable: AuthService.instancia.usuario,
      builder: (context, _usuario, __) => ValueListenableBuilder<AppConfig>(
      valueListenable: ConfigService.instancia.config,
      builder: (context, cfg, _) {
        if (cfg.chatUrl.isEmpty) return SizedBox.shrink();
        final ativas = filtrarAgendados(cfg.enquetes);
        // Se não há enquete no ar, mostra o resultado da última encerrada
        // que foi marcada no painel para exibir o resultado aos ouvintes.
        final encerradas = filtrarEncerradasComResultado(cfg.enquetes);
        final encerrada = ativas.isEmpty && encerradas.isNotEmpty;
        if (ativas.isEmpty && encerradas.isEmpty) return SizedBox.shrink();
        final e = ativas.isNotEmpty ? ativas.first : encerradas.last;
        final opcoes = List<String>.from(e['opcoes'] ?? []);
        if (opcoes.isEmpty) return SizedBox.shrink();
        _prepararEnquete(e, encerrada: encerrada);

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
              if ((e['imagem'] ?? '').toString().isNotEmpty ||
                  MidiaEleva.ehVideo(e))
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      height: 122,
                      width: double.infinity,
                      child: MidiaEleva(
                          item: e,
                          fit: BoxFit.cover,
                          placeholder: () => SizedBox.shrink()),
                    ),
                  ),
                ),
              if (encerrada)
                Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: CoresEleva.verde.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: CoresEleva.verde.withOpacity(0.6)),
                    ),
                    child: Text('🏁 ENQUETE ENCERRADA — RESULTADO FINAL',
                        style: TextStyle(
                            fontSize: 9.5,
                            letterSpacing: 0.6,
                            fontWeight: FontWeight.w900,
                            color: CoresEleva.verde)),
                  ),
                ),
              Row(
                children: [
                  Icon(encerrada ? Icons.emoji_events_rounded : Icons.poll_rounded,
                      color: CoresEleva.dourado, size: 18),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      (e['pergunta'] ?? 'Enquete').toString(),
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: CoresEleva.branco),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              if (encerrada)
                _barras(opcoes, encerrada: true)
              else if (!_jaVotou)
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: CoresEleva.verde, size: 16),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Você já votou. Obrigado por participar! 🙌',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: CoresEleva.brancoSuave),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    _barras(opcoes, encerrada: false),
                  ],
                ),
            ],
          ),
        );
      },
    ),
    );
  }
}
