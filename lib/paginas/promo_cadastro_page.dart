import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../servicos/auth_service.dart';
import '../servicos/config_service.dart';
import '../tema.dart';
import '../widgets/midia_eleva.dart';
import 'pedidos_page.dart' show MaiusculasFormatter, TelefoneFormatter;

/// Tela de cadastro do ouvinte numa promoção.
/// Abre quando ele toca no banner da promoção na aba Promoções.
class PromoCadastroPage extends StatefulWidget {
  final Map<String, dynamic> promo;
  final AppConfig cfg;
  const PromoCadastroPage({super.key, required this.promo, required this.cfg});

  @override
  State<PromoCadastroPage> createState() => _PromoCadastroPageState();
}

class _PromoCadastroPageState extends State<PromoCadastroPage> {
  final _nome = TextEditingController();
  final _zap = TextEditingController();
  final _insta = TextEditingController();
  final _cidade = TextEditingController();
  final _estado = TextEditingController();
  final _nasc = TextEditingController();
  bool? _maiorIdade;
  bool _enviando = false;
  bool _concluido = false;
  String _faltando = '';

  // sugestões de cidade (autocompletar)
  List<String> _sugestoes = [];
  bool _buscandoCidade = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_nome, _zap, _insta, _cidade, _estado, _nasc]) {
      c.addListener(() => setState(() {}));
    }
    _cidade.addListener(_buscarCidades);
  }

  @override
  void dispose() {
    for (final c in [_nome, _zap, _insta, _cidade, _estado, _nasc]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _id => (widget.promo['id'] ?? '').toString();
  String get _nomePromo =>
      (widget.promo['nome'] ?? widget.promo['pergunta'] ?? 'PROMOÇÃO')
          .toString();

  // ---------- AUTOCOMPLETAR CIDADE (lista oficial do IBGE) ----------
  Future<void> _buscarCidades() async {
    final termo = _cidade.text.trim();
    if (termo.length < 3) {
      if (_sugestoes.isNotEmpty && mounted) setState(() => _sugestoes = []);
      return;
    }
    if (_buscandoCidade) return;
    _buscandoCidade = true;
    try {
      final r = await http
          .get(Uri.parse(
              'https://servicodados.ibge.gov.br/api/v1/localidades/municipios'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final lista = jsonDecode(utf8.decode(r.bodyBytes)) as List;
        final t = _semAcento(termo.toLowerCase());
        final achados = <String>[];
        for (final m in lista) {
          final nome = (m['nome'] ?? '').toString();
          if (_semAcento(nome.toLowerCase()).startsWith(t)) {
            final uf = m['microrregiao']?['mesorregiao']?['UF']?['sigla'] ?? '';
            achados.add('$nome|$uf');
            if (achados.length >= 8) break;
          }
        }
        if (mounted) setState(() => _sugestoes = achados);
      }
    } catch (_) {}
    _buscandoCidade = false;
  }

  String _semAcento(String s) {
    const com = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
    const sem = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
    var r = s;
    for (int i = 0; i < com.length; i++) {
      r = r.replaceAll(com[i], sem[i]);
    }
    return r;
  }

  // ---------- VALIDAÇÃO PROGRESSIVA ----------
  /// Diz qual é o PRÓXIMO campo que falta preencher (para guiar o ouvinte)
  String _proximoFaltante() {
    if (_maiorIdade == null) return 'Marque se você é maior de 18 anos';
    if (_maiorIdade == false) return '';
    if (_nome.text.trim().length < 3) return 'Escreva seu NOME COMPLETO';
    if (_zap.text.replaceAll(RegExp(r'\D'), '').length < 10) {
      return 'Escreva seu WHATSAPP com DDD';
    }
    if (_insta.text.trim().isEmpty) return 'Escreva seu @ do INSTAGRAM';
    if (_cidade.text.trim().length < 3) return 'Escreva sua CIDADE';
    if (_estado.text.trim().length < 2) return 'Escreva seu ESTADO (UF)';
    final erroData = _erroNascimento();
    if (erroData.isNotEmpty) return erroData;
    return '';
  }

  /// Confere a DATA DE NASCIMENTO por completo:
  /// - dia entre 1 e 31, mes entre 1 e 12, data que realmente existe
  /// - ano nao pode ser mais antigo que 90 anos atras
  /// - a data nao pode ser no futuro
  /// - e a pessoa precisa ter 18 anos COMPLETOS (evita que alguem marque
  ///   "sou maior de 18" e coloque uma data de menor de idade)
  String _erroNascimento() {
    final so = _nasc.text.replaceAll(RegExp(r'\D'), '');
    if (so.length < 8) return 'Escreva sua DATA DE NASCIMENTO completa (DD/MM/AAAA)';
    final dia = int.tryParse(so.substring(0, 2)) ?? 0;
    final mes = int.tryParse(so.substring(2, 4)) ?? 0;
    final ano = int.tryParse(so.substring(4, 8)) ?? 0;

    if (mes < 1 || mes > 12) {
      return '❌ MÊS INCORRETO — o mês vai de 01 a 12. Digite a data de novo.';
    }
    if (dia < 1 || dia > 31) {
      return '❌ DIA INCORRETO — o dia vai de 01 a 31. Digite a data de novo.';
    }

    final agora = DateTime.now();
    if (ano < agora.year - 90) {
      return '❌ ANO INCORRETO — confira o ano de nascimento e digite de novo.';
    }
    if (ano > agora.year) {
      return '❌ ANO INCORRETO — o ano não pode ser no futuro. Digite de novo.';
    }

    // confere se a data existe mesmo (ex.: 31/02 nao existe)
    final d = DateTime(ano, mes, dia);
    if (d.day != dia || d.month != mes || d.year != ano) {
      return '❌ DATA INCORRETA — este dia não existe neste mês. Digite de novo.';
    }
    if (d.isAfter(agora)) {
      return '❌ DATA INCORRETA — a data não pode ser no futuro. Digite de novo.';
    }

    // idade completa
    var idade = agora.year - ano;
    if (agora.month < mes || (agora.month == mes && agora.day < dia)) {
      idade--;
    }
    if (idade < 18) {
      return '🔞 Esta promoção é só para quem já tem 18 anos completos. '
          'Continue ouvindo a rádio e fique de olho nas próximas! 💛';
    }
    return '';
  }

  bool get _completo => _maiorIdade == true && _proximoFaltante().isEmpty;

  // ---------- ENVIO ----------
  Future<void> _concluir() async {
    final falta = _proximoFaltante();
    if (falta.isNotEmpty) {
      setState(() => _faltando = falta);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.orange.shade800,
        content: Text('⚠️ $falta'),
      ));
      return;
    }
    setState(() => _enviando = true);
    final base = widget.cfg.chatUrl.replaceAll(RegExp(r'/chat/?$'), '');
    try {
      await http.post(
        Uri.parse('$base/promo_participacoes/$_id.json'),
        body: jsonEncode({
          'nome': _nome.text.trim().toUpperCase(),
          'whatsapp': _zap.text.trim(),
          'instagram': _insta.text.trim().toUpperCase(),
          'cidade': _cidade.text.trim().toUpperCase(),
          'estado': _estado.text.trim().toUpperCase(),
          'nascimento': _nasc.text.trim(),
          'maior_idade': 'SIM',
          'uid': AuthService.instancia.usuario.value?.uid ?? '',
          'promocao': _nomePromo,
          'quando': DateTime.now().toIso8601String(),
        }),
      );
      final prefs = await SharedPreferences.getInstance();
      final uid = AuthService.instancia.usuario.value?.uid ?? 'anon';
      await prefs.setBool('promo_${uid}_$_id', true);
      if (mounted) setState(() => _concluido = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red.shade800,
          content: Text('Não foi possível enviar. Verifique sua internet.'),
        ));
      }
    }
    if (mounted) setState(() => _enviando = false);
  }

  void _compartilhar() {
    Share.share(
      'Estou participando da ${_nomePromo.toUpperCase()} na ${widget.cfg.nome}! '
      'Baixe o app e participe você também. 🎁📻',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoresEleva.azulProfundo,
      appBar: AppBar(
        backgroundColor: CoresEleva.azulProfundo,
        iconTheme: IconThemeData(color: CoresEleva.dourado),
        title: Text(_nomePromo.toUpperCase(),
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: CoresEleva.dourado)),
      ),
      body: SafeArea(
        child: _concluido ? _telaCompartilhar() : _formulario(),
      ),
    );
  }

  // ---------- TELA DE COMPARTILHAR (depois de concluir) ----------
  /// Aparece assim que o cadastro e concluido: convida a compartilhar,
  /// mas sem obrigar — da a opcao de deixar para depois.
  Widget _telaCompartilhar() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 30, 20, 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('😄', style: TextStyle(fontSize: 64)),
          SizedBox(height: 16),
          Text('CADASTRO CONCLUÍDO!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: CoresEleva.verde,
                  letterSpacing: 0.8)),
          SizedBox(height: 22),
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [CoresEleva.verde, CoresEleva.azulVivo]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: CoresEleva.verde.withOpacity(0.32), blurRadius: 16)
              ],
            ),
            child: Column(
              children: [
                Text('COMPARTILHE ESTA PROMOÇÃO\nPARA AUMENTAR SUAS CHANCES 😄',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16.5,
                        height: 1.4,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _compartilhar();
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.share_rounded),
                    label: Text('COMPARTILHAR AGORA',
                        style: TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CoresEleva.dourado,
                      foregroundColor: Colors.black87,
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('MAIS TARDE',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: CoresEleva.brancoSuave)),
          ),
        ],
      ),
    );
  }

  // ---------- FORMULÁRIO ----------
  Widget _formulario() {
    final falta = _proximoFaltante();
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // banner pequeno no topo
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 110,
              width: double.infinity,
              child: MidiaEleva(item: widget.promo, fit: BoxFit.cover),
            ),
          ),
          SizedBox(height: 16),

          // aviso de autorização de uso de imagem
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CoresEleva.azulProfundo,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: CoresEleva.dourado.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AUTORIZAÇÃO DE USO DE IMAGEM',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: CoresEleva.dourado)),
                SizedBox(height: 8),
                Text(
                  'Ao participar desta promoção, os ouvintes autorizam, de forma '
                  'gratuita, o uso de seu nome, imagem e voz para fins de '
                  'divulgação da Promoção ${_nomePromo.toUpperCase()} nas redes '
                  'sociais e demais canais da ${widget.cfg.nome}, caso '
                  'sejam contemplados.\n\n'
                  'O uso será realizado em total conformidade com a Lei Geral '
                  'de Proteção de Dados (LGPD).',
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: CoresEleva.brancoSuave),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),

          // maior de 18 anos
          Text('SOU MAIOR DE 18 ANOS? *',
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: CoresEleva.branco)),
          Row(
            children: [
              Expanded(child: _opcaoIdade('SIM', true)),
              Expanded(child: _opcaoIdade('NÃO', false)),
            ],
          ),

          if (_maiorIdade == false)
            Container(
              margin: EdgeInsets.only(top: 6),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withOpacity(0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Text(
                'Esta promoção é válida apenas para maiores de 18 anos. '
                'Continue ouvindo a ${widget.cfg.nome}! 💛',
                style: TextStyle(fontSize: 13, color: Colors.white),
              ),
            ),

          if (_maiorIdade == true) ...[
            SizedBox(height: 8),
            _campo('NOME COMPLETO *', _nome,
                icone: Icons.person_rounded,
                formatadores: [MaiusculasFormatter()]),
            _campo('WHATSAPP COM DDD *', _zap,
                icone: Icons.chat_rounded,
                teclado: TextInputType.phone,
                formatadores: [TelefoneFormatter()]),
            _campo('@ DO INSTAGRAM *', _insta,
                icone: Icons.camera_alt_rounded,
                formatadores: [MaiusculasFormatter()]),
            _campoCidade(),
            _campo('ESTADO (UF) *', _estado,
                icone: Icons.map_rounded,
                formatadores: [MaiusculasFormatter()]),
            _campo('DATA DE NASCIMENTO *', _nasc,
                icone: Icons.cake_rounded,
                teclado: TextInputType.number,
                formatadores: [_DataFormatter()],
                dica: 'DD/MM/AAAA',
                comErro: _nasc.text.replaceAll(RegExp(r'\D'), '').length >= 8 &&
                    _erroNascimento().isNotEmpty),

            SizedBox(height: 10),

            // aviso do que falta (laranja) ou do que esta ERRADO (vermelho)
            if (falta.isNotEmpty)
              Builder(builder: (_) {
                final ehErro = _erroNascimento().isNotEmpty &&
                    falta == _erroNascimento();
                final cor = ehErro ? Colors.red : Colors.orange;
                return Container(
                  margin: EdgeInsets.only(bottom: 10),
                  padding: EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: cor.shade900.withOpacity(0.32),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cor.shade400),
                  ),
                  child: Row(
                    children: [
                      Icon(
                          ehErro
                              ? Icons.error_outline_rounded
                              : Icons.arrow_downward_rounded,
                          color: cor.shade300,
                          size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(falta,
                            style: TextStyle(
                                fontSize: 12.8,
                                fontWeight: FontWeight.w700,
                                color: cor.shade100)),
                      ),
                    ],
                  ),
                );
              }),

            // botão concluir (só "acende" quando tudo está preenchido)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_completo && !_enviando) ? _concluir : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _completo ? CoresEleva.verde : CoresEleva.azulProfundo,
                  disabledBackgroundColor: CoresEleva.azulProfundo,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: CoresEleva.textoFraco,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                  elevation: _completo ? 6 : 0,
                ),
                child: _enviando
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        _completo
                            ? '✅ CONCLUIR CADASTRO'
                            : 'CONCLUIR CADASTRO',
                        style: TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _opcaoIdade(String texto, bool valor) {
    final marcado = _maiorIdade == valor;
    return InkWell(
      onTap: () => setState(() => _maiorIdade = valor),
      child: Container(
        margin: EdgeInsets.only(top: 8, right: valor ? 8 : 0),
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: marcado
              ? CoresEleva.verde.withOpacity(0.22)
              : CoresEleva.azulProfundo,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: marcado ? CoresEleva.verde : Colors.white24, width: 1.6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
                marcado
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: marcado ? CoresEleva.verde : CoresEleva.textoFraco,
                size: 20),
            SizedBox(width: 8),
            Text(texto,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: marcado ? Colors.white : CoresEleva.brancoSuave)),
          ],
        ),
      ),
    );
  }

  Widget _campo(String rotulo, TextEditingController ctrl,
      {IconData? icone,
      TextInputType? teclado,
      List<TextInputFormatter>? formatadores,
      String? dica,
      bool comErro = false}) {
    final preenchido = ctrl.text.trim().length >= 2 && !comErro;
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        keyboardType: teclado,
        inputFormatters: formatadores,
        textCapitalization: TextCapitalization.characters,
        style: TextStyle(color: CoresEleva.branco, fontSize: 14.5),
        decoration: InputDecoration(
          labelText: rotulo,
          hintText: dica,
          labelStyle: TextStyle(
              color: preenchido ? CoresEleva.verde : CoresEleva.dourado,
              fontSize: 12.5,
              fontWeight: FontWeight.bold),
          hintStyle: TextStyle(color: CoresEleva.textoFraco, fontSize: 13),
          prefixIcon: icone == null
              ? null
              : Icon(icone,
                  color: preenchido ? CoresEleva.verde : CoresEleva.textoFraco,
                  size: 20),
          suffixIcon: preenchido
              ? Icon(Icons.check_circle_rounded,
                  color: CoresEleva.verde, size: 20)
              : null,
          filled: true,
          fillColor: CoresEleva.azulProfundo,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
                color: comErro
                    ? Colors.red.shade400
                    : (preenchido ? CoresEleva.verde : Colors.white24),
                width: comErro ? 1.6 : 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: CoresEleva.dourado, width: 1.6),
          ),
        ),
      ),
    );
  }

  /// Campo cidade com sugestões (autocompletar) para digitar menos
  Widget _campoCidade() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _campo('CIDADE *', _cidade, icone: Icons.location_city_rounded,
            formatadores: [MaiusculasFormatter()]),
        if (_sugestoes.isNotEmpty)
          Container(
            margin: EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: CoresEleva.azulMedio,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CoresEleva.dourado.withOpacity(0.4)),
            ),
            child: Column(
              children: _sugestoes.map((s) {
                final partes = s.split('|');
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: Icon(Icons.place_rounded,
                      color: CoresEleva.dourado, size: 18),
                  title: Text('${partes[0].toUpperCase()} — ${partes[1]}',
                      style: TextStyle(
                          fontSize: 13.5, color: CoresEleva.branco)),
                  onTap: () {
                    _cidade.text = partes[0].toUpperCase();
                    if (partes.length > 1) _estado.text = partes[1];
                    setState(() => _sugestoes = []);
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

/// Escreve a data no formato DD/MM/AAAA enquanto o ouvinte digita
class _DataFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue antigo, TextEditingValue novo) {
    final so = novo.text.replaceAll(RegExp(r'\D'), '');
    final b = StringBuffer();
    for (int i = 0; i < so.length && i < 8; i++) {
      if (i == 2 || i == 4) b.write('/');
      b.write(so[i]);
    }
    final txt = b.toString();
    return TextEditingValue(
      text: txt,
      selection: TextSelection.collapsed(offset: txt.length),
    );
  }
}
