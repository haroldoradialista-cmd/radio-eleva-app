import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../servicos/auth_service.dart';
import '../servicos/cadastro_service.dart';
import '../tema.dart';
import 'pedidos_page.dart' show MaiusculasFormatter;

/// MEUS DADOS
/// O ouvinte revê e corrige o que informou no cadastro — principalmente
/// o WhatsApp, que é por onde a rádio avisa quem ganhou uma promoção.
class MeusDadosPage extends StatefulWidget {
  const MeusDadosPage({super.key});

  @override
  State<MeusDadosPage> createState() => _MeusDadosPageState();
}

class _MeusDadosPageState extends State<MeusDadosPage> {
  final _nome = TextEditingController();
  final _ddd = TextEditingController();
  final _numero = TextEditingController();
  final _email = TextEditingController();

  bool _salvando = false;
  bool _emailConfirmado = false;
  bool _conferindoEmail = true;
  String _aviso = '';

  @override
  void initState() {
    super.initState();
    _nome.text = CadastroService.nome;
    final so = CadastroService.whatsapp.replaceAll(RegExp(r'\D'), '');
    if (so.length >= 10) {
      _ddd.text = so.substring(0, 2);
      _numero.text = so.substring(2);
    }
    final u = AuthService.instancia.usuario.value;
    _email.text = (u?.email ?? '').toLowerCase();
    for (final c in [_nome, _ddd, _numero]) {
      c.addListener(() => setState(() {}));
    }
    _conferirEmail();
  }

  @override
  void dispose() {
    _nome.dispose();
    _ddd.dispose();
    _numero.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _conferirEmail() async {
    final ok = await AuthService.instancia.emailConfirmado();
    if (mounted) {
      setState(() {
        _emailConfirmado = ok;
        _conferindoEmail = false;
      });
    }
  }

  String get _falta {
    final e1 = CadastroService.erroNome(_nome.text);
    if (e1.isNotEmpty) return e1;
    final e2 = CadastroService.erroDDD(_ddd.text);
    if (e2.isNotEmpty) return e2;
    final e3 = CadastroService.erroNumero(_numero.text);
    if (e3.isNotEmpty) return e3;
    return '';
  }

  Future<void> _salvar() async {
    if (_falta.isNotEmpty) {
      setState(() => _aviso = _falta);
      return;
    }
    final u = AuthService.instancia.usuario.value;
    if (u == null) return;
    setState(() {
      _salvando = true;
      _aviso = '';
    });
    final ok = await CadastroService.salvar(
      uid: u.uid,
      email: _email.text.trim().toLowerCase(),
      nomeCompleto: _nome.text,
      zap: CadastroService.montarTelefone(_ddd.text, _numero.text),
      emailVerificado: _emailConfirmado,
    );
    if (!mounted) return;
    setState(() => _salvando = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: ok ? CoresEleva.verde : Colors.red.shade700,
      content: Text(ok
          ? 'Dados atualizados! ✅'
          : 'Não foi possível salvar. Tente de novo.'),
    ));
  }

  Future<void> _reenviarEmail() async {
    setState(() => _salvando = true);
    final ok = await AuthService.instancia.enviarBoasVindas();
    if (!mounted) return;
    setState(() => _salvando = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: ok ? CoresEleva.verde : Colors.red.shade700,
      duration: Duration(seconds: 4),
      content: Text(ok
          ? 'Enviamos um e-mail para ${_email.text}. Confira sua caixa de entrada (e o spam).'
          : 'Não foi possível enviar agora.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final u = AuthService.instancia.usuario.value;
    if (u == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Text('Entre com sua conta para ver seus dados.',
              textAlign: TextAlign.center,
              style: TextStyle(color: CoresEleva.brancoSuave)),
        ),
      );
    }
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
              'Estes são os dados que a rádio usa para falar com você — '
              'principalmente para avisar se você ganhar uma promoção. '
              'Mantenha o WhatsApp correto. 💛',
              style: TextStyle(
                  fontSize: 13, height: 1.5, color: CoresEleva.brancoSuave)),
          SizedBox(height: 18),

          _campo('NOME COMPLETO', _nome,
              icone: Icons.person_rounded,
              formatadores: [MaiusculasFormatter()]),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 92,
                child: _campo('DDD', _ddd,
                    icone: Icons.pin_rounded,
                    teclado: TextInputType.number,
                    formatadores: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ]),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _campo('WHATSAPP', _numero,
                    icone: Icons.chat_rounded,
                    teclado: TextInputType.number,
                    formatadores: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(9),
                    ]),
              ),
            ],
          ),

          // e-mail (não pode ser trocado por aqui: é o login)
          Container(
            padding: EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: CoresEleva.azulProfundo,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.mail_rounded,
                        size: 19, color: CoresEleva.textoFraco),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(_email.text,
                          style: TextStyle(
                              fontSize: 14, color: CoresEleva.branco)),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                if (_conferindoEmail)
                  Text('Conferindo...',
                      style: TextStyle(
                          fontSize: 11.5, color: CoresEleva.textoFraco))
                else if (_emailConfirmado)
                  Text('✅ E-mail confirmado',
                      style:
                          TextStyle(fontSize: 11.5, color: CoresEleva.verde))
                else ...[
                  Text('⚠️ E-mail ainda não confirmado',
                      style: TextStyle(
                          fontSize: 11.5, color: Colors.orange.shade300)),
                  SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: _salvando ? null : _reenviarEmail,
                    icon: Icon(Icons.send_rounded,
                        size: 15, color: CoresEleva.dourado),
                    label: Text('Reenviar e-mail de confirmação',
                        style: TextStyle(
                            fontSize: 12.5, color: CoresEleva.dourado)),
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  ),
                ],
                SizedBox(height: 4),
                Text('O e-mail é o seu login e não pode ser alterado aqui.',
                    style: TextStyle(
                        fontSize: 11, color: CoresEleva.textoFraco)),
              ],
            ),
          ),

          if (_aviso.isNotEmpty)
            Container(
              margin: EdgeInsets.only(top: 12),
              padding: EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade400),
              ),
              child: Text(_aviso,
                  style: TextStyle(
                      fontSize: 12.8,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade100)),
            ),

          SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _salvando ? null : _salvar,
              style: ElevatedButton.styleFrom(
                backgroundColor: CoresEleva.verde,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26)),
              ),
              child: _salvando
                  ? SizedBox(
                      height: 19,
                      width: 19,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('💾 SALVAR ALTERAÇÕES',
                      style: TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campo(String rotulo, TextEditingController ctrl,
      {IconData? icone,
      TextInputType? teclado,
      List<TextInputFormatter>? formatadores}) {
    final bool ok;
    if (ctrl == _nome) {
      ok = CadastroService.erroNome(ctrl.text).isEmpty;
    } else if (ctrl == _ddd) {
      ok = CadastroService.erroDDD(ctrl.text).isEmpty;
    } else {
      ok = CadastroService.erroNumero(ctrl.text).isEmpty;
    }
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: teclado,
        inputFormatters: formatadores,
        textCapitalization: TextCapitalization.characters,
        style: TextStyle(color: CoresEleva.branco, fontSize: 14.5),
        decoration: InputDecoration(
          labelText: rotulo,
          labelStyle: TextStyle(
              color: ok ? CoresEleva.verde : CoresEleva.dourado,
              fontSize: 12.5,
              fontWeight: FontWeight.bold),
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
        ),
      ),
    );
  }
}
