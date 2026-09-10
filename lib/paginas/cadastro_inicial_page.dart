import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../servicos/auth_service.dart';
import '../servicos/cadastro_service.dart';
import '../servicos/config_service.dart';
import '../tema.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'pedidos_page.dart' show MaiusculasFormatter, TelefoneFormatter, ESTADOS_BR;

/// CADASTRO DA PRIMEIRA ENTRADA
///
/// Aparece uma única vez, logo após o login. O ouvinte informa nome
/// completo e WhatsApp; a partir daí esses dados são preenchidos
/// automaticamente em promoções, pedidos e anúncios.
class CadastroInicialPage extends StatefulWidget {
  final AppConfig cfg;
  final VoidCallback aoConcluir;
  const CadastroInicialPage(
      {super.key, required this.cfg, required this.aoConcluir});

  @override
  State<CadastroInicialPage> createState() => _CadastroInicialPageState();
}

class _CadastroInicialPageState extends State<CadastroInicialPage> {
  final _nome = TextEditingController();
  final _ddd = TextEditingController();
  final _numero = TextEditingController();
  final _email = TextEditingController();
  final _codigo = TextEditingController();
  bool _emailDoGoogle = false;   // veio do login Google: já confirmado
  final _estado = TextEditingController();
  final _cidade = TextEditingController();
  List<String> _cidadesDoEstado = [];
  bool _carregandoCidades = false;

  bool _salvando = false;
  bool _pedindoCodigo = false; // etapa de digitar o código
  String _codigoEsperado = '';
  String _aviso = '';

  @override
  void initState() {
    super.initState();
    _nome.text = CadastroService.nome;
    // separa o telefone guardado em DDD e número
    final so = CadastroService.whatsapp.replaceAll(RegExp(r'\D'), '');
    if (so.length >= 10) {
      _ddd.text = so.substring(0, 2);
      _numero.text = so.substring(2);
    }
    final u = AuthService.instancia.usuario.value;
    if (u != null) {
      // se o login foi pelo Google, aproveita nome e e-mail (já confirmado)
      if (_nome.text.isEmpty && u.nome.trim().contains(' ')) {
        _nome.text = u.nome.toUpperCase();
      }
      if (u.email.isNotEmpty) {
        _email.text = u.email.toLowerCase();
        _emailDoGoogle = true;
      }
    }
    _estado.text = CadastroService.estado;
    _cidade.text = CadastroService.cidade;
    if (_estado.text.isNotEmpty) _carregarCidades(_estado.text);
    for (final c in [_nome, _ddd, _numero, _email, _estado, _cidade]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _nome.dispose();
    _ddd.dispose();
    _numero.dispose();
    _email.dispose();
    _estado.dispose();
    _cidade.dispose();
    _codigo.dispose();
    super.dispose();
  }

  String get _falta {
    final e1 = CadastroService.erroNome(_nome.text);
    if (e1.isNotEmpty) return e1;
    final e2 = CadastroService.erroDDD(_ddd.text);
    if (e2.isNotEmpty) return e2;
    final e3 = CadastroService.erroNumero(_numero.text);
    if (e3.isNotEmpty) return e3;
    final e4 = CadastroService.erroEmail(_email.text);
    if (e4.isNotEmpty) return e4;
    if (_estado.text.trim().length != 2) return 'Escolha o seu ESTADO';
    if (_cidade.text.trim().length < 2) return 'Escolha a sua CIDADE';
    return '';
  }

  /// Telefone completo, no formato guardado
  String get _telefone =>
      CadastroService.montarTelefone(_ddd.text, _numero.text);

  bool get _completo => _falta.isEmpty;

  Future<void> _continuar() async {
    if (!_completo) {
      setState(() => _aviso = _falta);
      return;
    }
    final u = AuthService.instancia.usuario.value;
    if (u == null) return;
    setState(() {
      _salvando = true;
      _aviso = '';
    });

    // A rádio pode exigir validação por código (configurado no painel).
    // Se não estiver configurada, o cadastro é concluído direto.
    final exige = widget.cfg.exigirCodigo && widget.cfg.envioCodigoUrl.isNotEmpty;

    if (exige && !_pedindoCodigo) {
      _codigoEsperado = CadastroService.gerarCodigo();
      final erro = await CadastroService.enviarCodigo(
        envioUrl: widget.cfg.envioCodigoUrl,
        envioChave: widget.cfg.envioCodigoChave,
        envioFormato: widget.cfg.envioCodigoFormato,
        numero: _telefone,
        codigo: _codigoEsperado,
        nomeRadio: widget.cfg.nome,
      );
      if (!mounted) return;
      if (erro.isEmpty) {
        setState(() {
          _pedindoCodigo = true;
          _salvando = false;
          _aviso = '';
        });
        return;
      }
      // não conseguiu enviar: não trava o ouvinte, conclui sem código
      setState(() => _aviso = '');
    }

    await CadastroService.salvar(
      uid: u.uid,
      email: _email.text.trim().toLowerCase(),
      nomeCompleto: _nome.text,
      zap: _telefone,
      uf: _estado.text,
      municipio: _cidade.text,
      emailVerificado: _emailDoGoogle,
    );
    // E-MAIL DE BOAS-VINDAS: enviado em segundo plano, sem travar nada.
    // Quem entrou pelo Google não precisa (o e-mail já é confirmado).
    if (!_emailDoGoogle) {
      AuthService.instancia.enviarBoasVindas();
    }
    if (!mounted) return;
    setState(() => _salvando = false);
    widget.aoConcluir();
  }

  Future<void> _confirmarCodigo() async {
    final digitado = _codigo.text.replaceAll(RegExp(r'\D'), '');
    if (digitado != _codigoEsperado) {
      setState(() => _aviso = '❌ Código incorreto. Confira e digite de novo.');
      return;
    }
    final u = AuthService.instancia.usuario.value;
    if (u == null) return;
    setState(() => _salvando = true);
    await CadastroService.salvar(
      uid: u.uid,
      email: _email.text.trim().toLowerCase(),
      nomeCompleto: _nome.text,
      zap: _telefone,
      uf: _estado.text,
      municipio: _cidade.text,
      emailVerificado: _emailDoGoogle,
    );
    await CadastroService.marcarValidado(u.uid);
    if (!_emailDoGoogle) AuthService.instancia.enviarBoasVindas();
    if (!mounted) return;
    setState(() => _salvando = false);
    widget.aoConcluir();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: CoresEleva.fundoApp),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 26, 20, 30),
          child: _pedindoCodigo ? _telaCodigo() : _telaDados(),
        ),
      ),
    );
  }

  // ---------------- ETAPA 1: nome e WhatsApp ----------------
  Widget _telaDados() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: Image.asset('assets/logo.png', height: 70)),
        SizedBox(height: 16),
        Text('COMPLETE SEU CADASTRO',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
                color: CoresEleva.dourado)),
        SizedBox(height: 8),
        Text(
            'Você faz isso uma única vez. Depois, seus dados já vêm '
            'preenchidos nas promoções, pedidos musicais e anúncios. 💛',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13.5, height: 1.5, color: CoresEleva.brancoSuave)),
        SizedBox(height: 22),

        _campo('NOME COMPLETO *', _nome,
            icone: Icons.person_rounded,
            formatadores: [MaiusculasFormatter()],
            dica: 'Nome e sobrenome'),
        // WHATSAPP: DDD separado do número, cada um com sua conferência
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: _campo('DDD *', _ddd,
                  icone: Icons.pin_rounded,
                  teclado: TextInputType.number,
                  formatadores: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  dica: '21'),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _campo('WHATSAPP *', _numero,
                  icone: Icons.chat_rounded,
                  teclado: TextInputType.number,
                  formatadores: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                    _NumeroFormatter(),
                  ],
                  dica: '99999-9999'),
            ),
          ],
        ),
        // E-MAIL sempre em letras minúsculas
        _campo('E-MAIL *', _email,
            icone: Icons.mail_rounded,
            teclado: TextInputType.emailAddress,
            minusculas: true,
            somenteLeitura: _emailDoGoogle,
            dica: 'seuemail@gmail.com'),
        if (_emailDoGoogle)
          Padding(
            padding: EdgeInsets.only(bottom: 10, left: 4),
            child: Text('✅ E-mail confirmado pelo Google',
                style: TextStyle(fontSize: 11.5, color: CoresEleva.verde)),
          ),
        _listaEstados(),
        _escolherCidade(),

        if (_aviso.isNotEmpty || (!_completo && _falta.isNotEmpty))
          _faixaAviso(_aviso.isNotEmpty ? _aviso : _falta),

        SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_completo && !_salvando) ? _continuar : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _completo ? CoresEleva.verde : CoresEleva.azulProfundo,
              disabledBackgroundColor: CoresEleva.azulProfundo,
              foregroundColor: Colors.white,
              disabledForegroundColor: CoresEleva.textoFraco,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
            ),
            child: _salvando
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(_completo ? '✅ CONTINUAR' : 'CONTINUAR',
                    style: TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.bold)),
          ),
        ),
        SizedBox(height: 14),
        Text(
            'Seus dados são usados apenas pela ${widget.cfg.nome} para '
            'contato sobre promoções e pedidos. Não compartilhamos com '
            'terceiros (LGPD).',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: CoresEleva.textoFraco)),
      ],
    );
  }

  // ---------------- ETAPA 2: código de verificação ----------------
  Widget _telaCodigo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: Text('📲', style: TextStyle(fontSize: 52))),
        SizedBox(height: 14),
        Text('CONFIRME SEU NÚMERO',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
                color: CoresEleva.dourado)),
        SizedBox(height: 10),
        Text('Enviamos um código de 6 números para\n$_telefone',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, height: 1.5, color: CoresEleva.brancoSuave)),
        SizedBox(height: 22),
        TextField(
          controller: _codigo,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: TextStyle(
              fontSize: 26,
              letterSpacing: 10,
              fontWeight: FontWeight.bold,
              color: CoresEleva.branco),
          decoration: InputDecoration(
            counterText: '',
            hintText: '000000',
            hintStyle: TextStyle(
                fontSize: 26, letterSpacing: 10, color: CoresEleva.textoFraco),
            filled: true,
            fillColor: CoresEleva.azulProfundo,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: CoresEleva.dourado)),
          ),
          onChanged: (_) => setState(() => _aviso = ''),
        ),
        if (_aviso.isNotEmpty) _faixaAviso(_aviso),
        SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _salvando ? null : _confirmarCodigo,
            style: ElevatedButton.styleFrom(
              backgroundColor: CoresEleva.verde,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
            ),
            child: _salvando
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text('CONFIRMAR',
                    style: TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.bold)),
          ),
        ),
        SizedBox(height: 10),
        TextButton(
          onPressed: () => setState(() {
            _pedindoCodigo = false;
            _aviso = '';
            _codigo.clear();
          }),
          child: Text('← Corrigir meu número',
              style: TextStyle(color: CoresEleva.brancoSuave, fontSize: 13)),
        ),
      ],
    );
  }

  /// Baixa as cidades do estado escolhido (lista oficial do IBGE)
  Future<void> _carregarCidades(String uf) async {
    if (uf.isEmpty) return;
    setState(() {
      _carregandoCidades = true;
      _cidadesDoEstado = [];
    });
    try {
      final r = await http
          .get(Uri.parse(
              'https://servicodados.ibge.gov.br/api/v1/localidades/estados/$uf/municipios'))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        final lista = jsonDecode(utf8.decode(r.bodyBytes)) as List;
        final nomes = lista
            .map((m) => (m['nome'] ?? '').toString().toUpperCase())
            .where((n) => n.isNotEmpty)
            .toList()
          ..sort();
        if (mounted) setState(() => _cidadesDoEstado = nomes);
      }
    } catch (_) {}
    if (mounted) setState(() => _carregandoCidades = false);
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

  /// ESTADO: lista com os 27 estados
  Widget _listaEstados() {
    final uf = _estado.text.trim().toUpperCase();
    final ok = uf.length == 2;
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: ok ? uf : null,
        isExpanded: true,
        dropdownColor: CoresEleva.azulMedio,
        style: TextStyle(color: CoresEleva.branco, fontSize: 14.5),
        decoration: InputDecoration(
          labelText: 'ESTADO *',
          labelStyle: TextStyle(
              color: ok ? CoresEleva.verde : CoresEleva.dourado,
              fontSize: 12.5,
              fontWeight: FontWeight.bold),
          prefixIcon: Icon(Icons.map_rounded,
              color: ok ? CoresEleva.verde : CoresEleva.textoFraco, size: 20),
          filled: true,
          fillColor: CoresEleva.azulProfundo,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                BorderSide(color: ok ? CoresEleva.verde : Colors.white24),
          ),
        ),
        hint: Text('Escolha o seu estado',
            style: TextStyle(color: CoresEleva.textoFraco, fontSize: 13.5)),
        items: ESTADOS_BR
            .map((e) => DropdownMenuItem(
                value: e[0],
                child:
                    Text('${e[0]} — ${e[1]}', style: TextStyle(fontSize: 14))))
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            _estado.text = v;
            _cidade.clear();
          });
          _carregarCidades(v);
        },
      ),
    );
  }

  /// CIDADE: toca e escolhe numa lista com busca
  Widget _escolherCidade() {
    final temEstado = _estado.text.trim().isNotEmpty;
    final escolhida = _cidade.text.trim();
    final ok = escolhida.isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: temEstado && !_carregandoCidades ? _abrirListaCidades : null,
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'CIDADE *',
            labelStyle: TextStyle(
                color: ok ? CoresEleva.verde : CoresEleva.dourado,
                fontSize: 12.5,
                fontWeight: FontWeight.bold),
            prefixIcon: Icon(Icons.location_city_rounded,
                color: ok ? CoresEleva.verde : CoresEleva.textoFraco,
                size: 20),
            suffixIcon: Icon(
                ok ? Icons.check_circle_rounded : Icons.arrow_drop_down,
                color: ok ? CoresEleva.verde : CoresEleva.textoFraco),
            filled: true,
            fillColor: CoresEleva.azulProfundo,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  BorderSide(color: ok ? CoresEleva.verde : Colors.white24),
            ),
          ),
          child: Text(
            ok
                ? escolhida
                : (!temEstado
                    ? 'Escolha o estado primeiro'
                    : (_carregandoCidades
                        ? 'Carregando as cidades...'
                        : 'Escolha sua cidade')),
            style: TextStyle(
                fontSize: 14.5,
                color: ok ? CoresEleva.branco : CoresEleva.textoFraco),
          ),
        ),
      ),
    );
  }

  void _abrirListaCidades() {
    final busca = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: CoresEleva.azulProfundo,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, refazer) {
        final termo = _semAcento(busca.text.trim().toLowerCase());
        final lista = termo.isEmpty
            ? _cidadesDoEstado
            : _cidadesDoEstado
                .where((c) => _semAcento(c.toLowerCase()).contains(termo))
                .toList();
        return Padding(
          padding: EdgeInsets.only(
              left: 14,
              right: 14,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Escolha sua cidade — ${_estado.text}',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: CoresEleva.dourado)),
              SizedBox(height: 10),
              TextField(
                controller: busca,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => refazer(() {}),
                style: TextStyle(color: CoresEleva.branco),
                decoration: InputDecoration(
                  hintText: 'Digite as primeiras letras...',
                  hintStyle: TextStyle(color: CoresEleva.textoFraco),
                  prefixIcon:
                      Icon(Icons.search_rounded, color: CoresEleva.dourado),
                  filled: true,
                  fillColor: CoresEleva.azulMedio,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
              SizedBox(height: 8),
              SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.45,
                child: lista.isEmpty
                    ? Center(
                        child: Text('Nenhuma cidade encontrada',
                            style: TextStyle(color: CoresEleva.textoFraco)))
                    : ListView.builder(
                        itemCount: lista.length,
                        itemBuilder: (_, i) => ListTile(
                          dense: true,
                          leading: Icon(Icons.place_rounded,
                              color: CoresEleva.dourado, size: 18),
                          title: Text(lista[i],
                              style: TextStyle(
                                  fontSize: 14, color: CoresEleva.branco)),
                          onTap: () {
                            setState(() => _cidade.text = lista[i]);
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _faixaAviso(String texto) {
    final erro = texto.startsWith('❌');
    final cor = erro ? Colors.red : Colors.orange;
    return Container(
      margin: EdgeInsets.only(top: 4, bottom: 10),
      padding: EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: cor.shade900.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.shade400),
      ),
      child: Row(
        children: [
          Icon(erro ? Icons.error_outline_rounded : Icons.info_outline_rounded,
              color: cor.shade300, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(texto,
                style: TextStyle(
                    fontSize: 12.8,
                    fontWeight: FontWeight.w600,
                    color: cor.shade100)),
          ),
        ],
      ),
    );
  }

  Widget _campo(String rotulo, TextEditingController ctrl,
      {IconData? icone,
      TextInputType? teclado,
      List<TextInputFormatter>? formatadores,
      String? dica,
      bool minusculas = false,
      bool somenteLeitura = false}) {
    final bool ok;
    if (ctrl == _nome) {
      ok = CadastroService.erroNome(ctrl.text).isEmpty;
    } else if (ctrl == _ddd) {
      ok = CadastroService.erroDDD(ctrl.text).isEmpty;
    } else if (ctrl == _numero) {
      ok = CadastroService.erroNumero(ctrl.text).isEmpty;
    } else if (ctrl == _email) {
      ok = CadastroService.erroEmail(ctrl.text).isEmpty;
    } else {
      ok = ctrl.text.trim().length >= 2;
    }
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: teclado,
        readOnly: somenteLeitura,
        inputFormatters: [
          ...?formatadores,
          if (minusculas) _MinusculasFormatter(),
        ],
        textCapitalization: minusculas
            ? TextCapitalization.none
            : TextCapitalization.characters,
        style: TextStyle(color: CoresEleva.branco, fontSize: 14.5),
        decoration: InputDecoration(
          labelText: rotulo,
          hintText: dica,
          labelStyle: TextStyle(
              color: ok ? CoresEleva.verde : CoresEleva.dourado,
              fontSize: 12.5,
              fontWeight: FontWeight.bold),
          hintStyle: TextStyle(color: CoresEleva.textoFraco, fontSize: 13),
          prefixIcon: Icon(icone,
              color: ok ? CoresEleva.verde : CoresEleva.textoFraco, size: 20),
          suffixIcon: ok
              ? Icon(Icons.check_circle_rounded,
                  color: CoresEleva.verde, size: 20)
              : null,
          filled: true,
          fillColor: CoresEleva.azulProfundo,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                BorderSide(color: ok ? CoresEleva.verde : Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: CoresEleva.dourado, width: 1.6),
          ),
        ),
      ),
    );
  }
}

/// Escreve o número no formato 99999-9999 enquanto o ouvinte digita
class _NumeroFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue antigo, TextEditingValue novo) {
    final so = novo.text.replaceAll(RegExp(r'\D'), '');
    if (so.isEmpty) return novo.copyWith(text: '');
    final b = StringBuffer();
    for (int i = 0; i < so.length && i < 9; i++) {
      // celular (9 dígitos) separa após o 5º; fixo (8) após o 4º
      if ((so.length == 9 && i == 5) || (so.length == 8 && i == 4)) {
        b.write('-');
      }
      b.write(so[i]);
    }
    final txt = b.toString();
    return TextEditingValue(
      text: txt,
      selection: TextSelection.collapsed(offset: txt.length),
    );
  }
}

/// Deixa o e-mail sempre em letras minúsculas
class _MinusculasFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue antigo, TextEditingValue novo) {
    return TextEditingValue(
      text: novo.text.toLowerCase().replaceAll(' ', ''),
      selection: novo.selection,
    );
  }
}
