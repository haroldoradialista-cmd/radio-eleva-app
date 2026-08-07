import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../servicos/auth_service.dart';
import '../servicos/config_service.dart';
import '../tema.dart';
import '../servicos/analytics_service.dart';
import '../widgets/anuncio_banner.dart';
import '../widgets/login_widget.dart';
import 'pedidos_page.dart' show MaiusculasFormatter, TelefoneFormatter;
import '../widgets/midia_eleva.dart';

class PromocoesPage extends StatefulWidget {
  PromocoesPage({super.key});
  @override
  State<PromocoesPage> createState() => _PromocoesPageState();
}

class _PromocoesPageState extends State<PromocoesPage> {
  final Map<String, TextEditingController> _nome = {};
  final Map<String, TextEditingController> _zap = {};
  final Map<String, TextEditingController> _insta = {};
  final Map<String, TextEditingController> _cidade = {};
  final Map<String, TextEditingController> _estado = {};
  final Map<String, int> _resposta = {};
  final Set<String> _participadas = {};
  final Set<String> _regulamentoAberto = {};
  bool _enviando = false;
  bool _atualizando = false;
  Timer? _timerContagem;

  @override
  void initState() {
    super.initState();
    _carregarParticipadas();
    // contagem regressiva ao vivo
    _timerContagem = Timer.periodic(Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timerContagem?.cancel();
    super.dispose();
  }

  Future<void> _carregarParticipadas() async {
    final prefs = await SharedPreferences.getInstance();
    final chaves =
        prefs.getKeys().where((k) => k.startsWith('promo_')).toList();
    if (mounted) {
      setState(() {
        for (final k in chaves) {
          if (prefs.getBool(k) == true) {
            _participadas.add(k.replaceFirst('promo_', ''));
          }
        }
      });
    }
  }

  TextEditingController _ctrl(Map<String, TextEditingController> m, String id) {
    return m.putIfAbsent(id, () => TextEditingController());
  }

  Future<void> _atualizar() async {
    setState(() => _atualizando = true);
    await ConfigService.instancia.carregar();
    if (mounted) {
      setState(() => _atualizando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: CoresEleva.verdeEscuro,
          duration: Duration(seconds: 2),
          content: Text('Promoções atualizadas! ✅')));
    }
  }

  String _contagem(Map<String, dynamic> p) {
    final fim = DateTime.tryParse((p['expirar_em'] ?? '').toString());
    if (fim == null) return '';
    final resta = fim.difference(DateTime.now());
    if (resta.isNegative) return 'Promoção encerrada';
    final d = resta.inDays;
    final h = (resta.inHours % 24).toString().padLeft(2, '0');
    final m = (resta.inMinutes % 60).toString().padLeft(2, '0');
    final s = (resta.inSeconds % 60).toString().padLeft(2, '0');
    return d > 0
        ? 'A promoção termina em ${d}d ${h}h ${m}m ${s}s'
        : 'A promoção termina em ${h}h ${m}m ${s}s';
  }

  void _compartilharPromo(AppConfig cfg, Map<String, dynamic> p) {
    final link =
        cfg.linkCompartilhar.isNotEmpty ? '\n📲 ${cfg.linkCompartilhar}' : '';
    final texto = Uri.encodeComponent(
        '🎁 Olha essa promoção da ${cfg.nome} que eu achei incrível!\n\n'
        '"${p['nome'] ?? p['pergunta'] ?? 'Participe!'}"\n\n'
        'Baixe o app, participe e concorra você também! 🍀$link');
    launchUrl(Uri.parse('https://wa.me/?text=$texto'),
        mode: LaunchMode.externalApplication);
  }

  Future<void> _participar(
      AppConfig cfg, Map<String, dynamic> promo, Usuario u) async {
    final id = (promo['id'] ?? '').toString();
    if (_enviando) return;
    final resp = _resposta[id];
    if (_ctrl(_nome, id).text.trim().isEmpty ||
        _ctrl(_zap, id).text.trim().isEmpty ||
        _ctrl(_insta, id).text.trim().isEmpty ||
        _ctrl(_cidade, id).text.trim().isEmpty ||
        _ctrl(_estado, id).text.trim().isEmpty ||
        resp == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red.shade700,
          duration: Duration(seconds: 3),
          content: Text(
              'Preencha TODOS os campos da promoção (nome, WhatsApp, Instagram, cidade e estado) e escolha uma resposta para participar.')));
      return;
    }
    setState(() => _enviando = true);
    final opcoes = [
      (promo['opcao1'] ?? '').toString(),
      (promo['opcao2'] ?? '').toString()
    ];
    try {
      final base = cfg.chatUrl.replaceAll(RegExp(r'/chat/?$'), '');
      await http.post(
        Uri.parse('$base/promo_participacoes/$id.json'),
        body: jsonEncode({
          'nome': _ctrl(_nome, id).text.trim(),
          'whatsapp': _ctrl(_zap, id).text.trim(),
          'instagram': '@${_ctrl(_insta, id).text.trim().replaceAll('@', '')}',
          'resposta': opcoes[resp],
          'email': u.email,
          'uid': u.uid,
          'quando': DateTime.now().toIso8601String(),
          'cidade': _ctrl(_cidade, id).text.trim(),
          'estado': _ctrl(_estado, id).text.trim(),
          'pais': AnalyticsService.pais,
          'dispositivo': AnalyticsService.dispositivo,
        }),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('promo_$id', true);
      if (mounted) {
        setState(() => _participadas.add(id));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: CoresEleva.verdeEscuro,
            content: Text('Participação registrada! Boa sorte! 🍀')));
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

  void _abrirLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.transparent,
          body: FundoEleva(
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back_rounded,
                            color: CoresEleva.dourado),
                      ),
                      Text('Entrar',
                          style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: CoresEleva.branco)),
                    ],
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: ValueListenableBuilder<Usuario?>(
                        valueListenable: AuthService.instancia.usuario,
                        builder: (context, u, _) {
                          if (u != null) {
                            Future.microtask(() {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              }
                            });
                          }
                          return LoginEleva(
                              titulo: 'Entre para participar');
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FundoEleva(
      child: SafeArea(
        child: ValueListenableBuilder<AppConfig>(
          valueListenable: ConfigService.instancia.config,
          builder: (context, cfg, _) {
            final ativas = filtrarAgendados(cfg.promocoes);
            return ValueListenableBuilder<Usuario?>(
              valueListenable: AuthService.instancia.usuario,
              builder: (context, u, _) {
                return Column(
                  children: [
                    AnuncioBanner(),
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 10, 12, 4),
                      child: Row(
                        children: [
                          Icon(Icons.card_giftcard_rounded,
                              color: CoresEleva.dourado),
                          SizedBox(width: 10),
                          Text('Promoções',
                              style:
                                  Theme.of(context).textTheme.titleLarge),
                          Spacer(),
                          TextButton.icon(
                            onPressed: _atualizando ? null : _atualizar,
                            icon: _atualizando
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: CoresEleva.dourado))
                                : Icon(Icons.refresh_rounded,
                                    size: 20, color: CoresEleva.dourado),
                            label: Text('ATUALIZAR',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: CoresEleva.dourado)),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ativas.isEmpty
                          ? _semPromocao()
                          : ListView(
                              padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                              children: ativas
                                  .map((p) => _cartaoPromo(cfg, p, u))
                                  .toList(),
                            ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _cartaoPromo(
      AppConfig cfg, Map<String, dynamic> promo, Usuario? u) {
    final id = (promo['id'] ?? '').toString();
    final nomePromo =
        (promo['nome'] ?? promo['pergunta'] ?? 'Promoção').toString();
    final banner = (promo['imagem'] ?? '').toString();
    final regulamento = (promo['regulamento'] ?? '').toString();
    final contagem = _contagem(promo);
    final participou = _participadas.contains(id);
    final opcoes = [
      (promo['opcao1'] ?? '').toString(),
      (promo['opcao2'] ?? '').toString()
    ];

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: CoresEleva.azulMedio,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: CoresEleva.dourado.withOpacity(0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (banner.isNotEmpty || MidiaEleva.ehVideo(promo))
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: MidiaEleva(
                    item: promo,
                    fit: BoxFit.cover,
                    placeholder: () => SizedBox.shrink()),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Contagem regressiva
                if (contagem.isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(bottom: 8),
                    padding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.alarm_rounded,
                            size: 15, color: Colors.white),
                        SizedBox(width: 6),
                        Text(contagem,
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ],
                    ),
                  ),

                Text(nomePromo,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                        color: CoresEleva.dourado)),
                if ((promo['nome'] ?? '').toString().isNotEmpty &&
                    (promo['pergunta'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(promo['pergunta'].toString(),
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: CoresEleva.branco)),
                  ),

                // Regulamento
                if (regulamento.isNotEmpty) ...[
                  SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setState(() {
                      _regulamentoAberto.contains(id)
                          ? _regulamentoAberto.remove(id)
                          : _regulamentoAberto.add(id);
                    }),
                    child: Row(
                      children: [
                        Icon(Icons.description_rounded,
                            size: 16, color: CoresEleva.dourado),
                        SizedBox(width: 6),
                        Text('Regulamento',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: CoresEleva.dourado)),
                        Icon(
                            _regulamentoAberto.contains(id)
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 18,
                            color: CoresEleva.dourado),
                      ],
                    ),
                  ),
                  if (_regulamentoAberto.contains(id))
                    Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(regulamento,
                          style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: CoresEleva.brancoSuave)),
                    ),
                ],
                SizedBox(height: 10),

                // Conteúdo conforme a situação do ouvinte
                if (participou)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CoresEleva.verdeEscuro.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: CoresEleva.verde),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: CoresEleva.verde, size: 28),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '🎉 Participação confirmada na promoção "$nomePromo"! Saiba que cada promoção tem cadastro próprio.',
                            style: TextStyle(
                                fontSize: 12.5,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                                color: CoresEleva.branco),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (u == null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _abrirLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CoresEleva.verde,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                      ),
                      icon: Icon(Icons.login_rounded, size: 20),
                      label: Text('FAZER LOGIN PARA PARTICIPAR',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800)),
                    ),
                  )
                else ...[
                  ...List.generate(2, (i) {
                    final marcada = _resposta[id] == i;
                    return GestureDetector(
                      onTap: () => setState(() => _resposta[id] = i),
                      child: Container(
                        margin: EdgeInsets.only(bottom: 8),
                        padding: EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: marcada
                              ? CoresEleva.verdeEscuro.withOpacity(0.35)
                              : CoresEleva.azulProfundo.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(14),
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
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: marcada
                                  ? CoresEleva.verde
                                  : CoresEleva.textoFraco,
                              size: 22,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(opcoes[i],
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: CoresEleva.branco)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  SizedBox(height: 4),
                  _campo(_ctrl(_nome, id), 'NOME', Icons.person_rounded),
                  _campo(_ctrl(_zap, id), 'WHATSAPP COM DDD',
                      Icons.phone_rounded,
                      teclado: TextInputType.phone, mascara: true),
                  _campo(_ctrl(_insta, id), 'SEU USUÁRIO',
                      Icons.camera_alt_rounded,
                      prefixo: '@'),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _campo(_ctrl(_estado, id), 'ESTADO',
                            Icons.map_rounded),
                      ),
                      SizedBox(width: 7),
                      Expanded(
                        flex: 3,
                        child: _campo(_ctrl(_cidade, id), 'SUA CIDADE',
                            Icons.location_city_rounded),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _enviando
                          ? null
                          : () => _participar(cfg, promo, u),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CoresEleva.verde,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26)),
                        textStyle: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      child: _enviando
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : Text('PARTICIPAR 🎁'),
                    ),
                  ),
                ],

                // Compartilhar
                SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: () => _compartilharPromo(cfg, promo),
                    icon: Icon(Icons.share_rounded,
                        size: 18, color: Color(0xFF25D366)),
                    label: Text('COMPARTILHAR',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: Color(0xFF25D366))),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _campo(TextEditingController c, String rotulo, IconData icone,
      {TextInputType? teclado, String? prefixo, bool mascara = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 7),
      child: TextField(
        controller: c,
        keyboardType: teclado,
        textCapitalization: mascara ? TextCapitalization.none : TextCapitalization.characters,
        inputFormatters: mascara ? [TelefoneFormatter()] : [MaiusculasFormatter()],
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              EdgeInsets.symmetric(vertical: 11, horizontal: 10),
          hintText: rotulo,
          hintStyle: TextStyle(
              color: CoresEleva.textoFraco, fontSize: 13),
          prefixIcon: Icon(icone, color: CoresEleva.dourado, size: 18),
          prefixIconConstraints:
              BoxConstraints(minWidth: 34, minHeight: 34),
          prefixText: prefixo,
          prefixStyle: TextStyle(
              color: CoresEleva.dourado,
              fontWeight: FontWeight.w800,
              fontSize: 14),
          filled: true,
          fillColor: CoresEleva.azulProfundo.withOpacity(0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        style: TextStyle(color: CoresEleva.branco, fontSize: 14),
      ),
    );
  }

  Widget _semPromocao() {
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
