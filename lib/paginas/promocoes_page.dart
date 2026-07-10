import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../servicos/config_service.dart';
import '../tema.dart';

class PromocoesPage extends StatefulWidget {
  PromocoesPage({super.key});
  @override
  State<PromocoesPage> createState() => _PromocoesPageState();
}

class _PromocoesPageState extends State<PromocoesPage> {
  final _nome = TextEditingController();
  final _zap = TextEditingController();
  final _insta = TextEditingController();
  int? _resposta;
  bool _enviando = false;
  bool _jaParticipou = false;
  String _idCarregado = '';

  Future<void> _verificarParticipacao(String id) async {
    if (id == _idCarregado) return;
    _idCarregado = id;
    final prefs = await SharedPreferences.getInstance();
    final ja = prefs.getBool('promo_$id') ?? false;
    if (mounted && ja != _jaParticipou) setState(() => _jaParticipou = ja);
    _jaParticipou = ja;
  }

  Future<void> _participar(AppConfig cfg, Map<String, dynamic> promo) async {
    if (_enviando) return;
    if (_nome.text.trim().isEmpty ||
        _zap.text.trim().isEmpty ||
        _resposta == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
              'Preencha seu nome, WhatsApp e escolha uma resposta.')));
      return;
    }
    setState(() => _enviando = true);
    final id = (promo['id'] ?? '').toString();
    final opcoes = [
      (promo['opcao1'] ?? '').toString(),
      (promo['opcao2'] ?? '').toString()
    ];
    try {
      final base = cfg.chatUrl.replaceAll(RegExp(r'/chat/?$'), '');
      await http.post(
        Uri.parse('$base/promo_participacoes/$id.json'),
        body: jsonEncode({
          'nome': _nome.text.trim(),
          'whatsapp': _zap.text.trim(),
          'instagram': _insta.text.trim(),
          'resposta': opcoes[_resposta!],
          'quando': DateTime.now().toIso8601String(),
        }),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('promo_$id', true);
      if (mounted) {
        setState(() => _jaParticipou = true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: CoresEleva.verdeEscuro,
            content:
                Text('Participação registrada! Boa sorte! 🍀')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Falha ao enviar. Verifique sua internet.')));
      }
    }
    if (mounted) setState(() => _enviando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: CoresEleva.fundoApp),
      child: SafeArea(
        child: ValueListenableBuilder<AppConfig>(
          valueListenable: ConfigService.instancia.config,
          builder: (context, cfg, _) {
            final ativas = filtrarAgendados(cfg.promocoes);
            if (ativas.isEmpty || cfg.chatUrl.isEmpty) {
              return _semPromocao(context);
            }
            final promo = ativas.first;
            _verificarParticipacao((promo['id'] ?? '').toString());
            final banner = (promo['imagem'] ?? '').toString();
            final opcoes = [
              (promo['opcao1'] ?? '').toString(),
              (promo['opcao2'] ?? '').toString()
            ];

            return ListView(
              padding: EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Icon(Icons.card_giftcard_rounded,
                        color: CoresEleva.dourado),
                    SizedBox(width: 10),
                    Text('Promoções',
                        style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
                SizedBox(height: 14),

                // Banner da promoção
                if (banner.isNotEmpty)
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: CoresEleva.borda, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(19),
                      child: Image.network(banner,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => SizedBox.shrink()),
                    ),
                  ),
                SizedBox(height: 16),

                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CoresEleva.azulMedio,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: CoresEleva.dourado.withOpacity(0.5),
                        width: 1),
                  ),
                  child: _jaParticipou
                      ? Column(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: CoresEleva.verde, size: 52),
                            SizedBox(height: 10),
                            Text('Você já está participando!',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: CoresEleva.branco)),
                            SizedBox(height: 6),
                            Text(
                              'Sua participação foi registrada. Fique ligado na programação para saber o resultado. Boa sorte! 🍀',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: CoresEleva.brancoSuave),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (promo['pergunta'] ?? 'Participe!').toString(),
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: CoresEleva.branco),
                            ),
                            SizedBox(height: 12),

                            // Duas bolinhas de opção
                            ...List.generate(2, (i) {
                              final marcada = _resposta == i;
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _resposta = i),
                                child: Container(
                                  margin: EdgeInsets.only(bottom: 8),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: marcada
                                        ? CoresEleva.verdeEscuro
                                            .withOpacity(0.35)
                                        : CoresEleva.azulProfundo,
                                    borderRadius:
                                        BorderRadius.circular(14),
                                    border: Border.all(
                                        color: marcada
                                            ? CoresEleva.verde
                                            : CoresEleva.borda,
                                        width: marcada ? 1.8 : 1),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        marcada
                                            ? Icons
                                                .radio_button_checked_rounded
                                            : Icons
                                                .radio_button_unchecked_rounded,
                                        color: marcada
                                            ? CoresEleva.verde
                                            : CoresEleva.textoFraco,
                                        size: 22,
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(opcoes[i],
                                            style: TextStyle(
                                                fontWeight:
                                                    FontWeight.w700,
                                                color:
                                                    CoresEleva.branco)),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),

                            SizedBox(height: 8),
                            _campo(_nome, 'Nome', Icons.person_rounded),
                            _campo(_zap, 'WhatsApp com DDD',
                                Icons.phone_rounded,
                                teclado: TextInputType.phone),
                            _campo(_insta, 'Instagram (@seuusuario)',
                                Icons.camera_alt_rounded),
                            SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _enviando
                                    ? null
                                    : () => _participar(cfg, promo),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: CoresEleva.verde,
                                  foregroundColor: Colors.white,
                                  padding:
                                      EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(28)),
                                  textStyle: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800),
                                ),
                                child: _enviando
                                    ? SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5))
                                    : Text('PARTICIPAR 🎁'),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _campo(TextEditingController c, String rotulo, IconData icone,
      {TextInputType? teclado}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: teclado,
        decoration: InputDecoration(
          hintText: rotulo,
          hintStyle: TextStyle(color: CoresEleva.textoFraco),
          prefixIcon: Icon(icone, color: CoresEleva.dourado, size: 20),
          filled: true,
          fillColor: CoresEleva.azulProfundo,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        style: TextStyle(color: CoresEleva.branco),
      ),
    );
  }

  Widget _semPromocao(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.card_giftcard_rounded,
                size: 64, color: CoresEleva.dourado),
            SizedBox(height: 16),
            Text('Nenhuma promoção no momento',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text(
              'Fique ligado na Rádio Eleva — em breve tem promoção nova por aqui! 🎁',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
