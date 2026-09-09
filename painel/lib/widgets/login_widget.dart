import 'package:flutter/material.dart';
import '../servicos/auth_service.dart';
import '../tema.dart';

// ============================================================
// TELA DE LOGIN / CADASTRO
// ============================================================
class LoginEleva extends StatefulWidget {
  final String titulo;
  /// Quando a tela que chama JA mostra logo e titulo, passe false aqui
  /// para nao repetir tudo de novo.
  final bool mostrarCabecalho;
  LoginEleva({
    super.key,
    this.titulo = 'Entre para participar',
    this.mostrarCabecalho = true,
  });
  @override
  State<LoginEleva> createState() => _LoginElevaState();
}

class _LoginElevaState extends State<LoginEleva> {
  bool _cadastro = false;
  bool _ocupado = false;
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();

  Future<void> _executar(Future<String?> Function() acao) async {
    setState(() => _ocupado = true);
    final erro = await acao();
    if (mounted) {
      setState(() => _ocupado = false);
      if (erro != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Colors.red.shade700, content: Text(erro)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          22, widget.mostrarCabecalho ? 28 : 4, 22, 20),
      child: Column(
        children: [
          if (widget.mostrarCabecalho) ...[
            SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset('assets/logo.png', width: 90, height: 90),
            ),
            SizedBox(height: 18),
            Text(_cadastro ? 'Crie sua conta' : widget.titulo,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text(
              'Sua conta vale para o chat e para as promoções da Rádio Eleva',
              textAlign: TextAlign.center,
              style: TextStyle(color: CoresEleva.brancoSuave),
            ),
            SizedBox(height: 26),
          ] else if (_cadastro) ...[
            // no modo cadastro, mantem so um titulo curto
            Text('Crie sua conta',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            SizedBox(height: 14),
          ],

          // ---- Botão Google ----
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _ocupado
                  ? null
                  : () => _executar(AuthService.instancia.entrarComGoogle),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Color(0xFF1F1F1F),
                padding: EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                textStyle:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              icon: Text('G',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF4285F4))),
              label: Text('Entrar com Google'),
            ),
          ),

          SizedBox(height: 18),
          Row(children: [
            Expanded(child: Divider(color: CoresEleva.borda)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('ou', style: TextStyle(color: CoresEleva.textoFraco)),
            ),
            Expanded(child: Divider(color: CoresEleva.borda)),
          ]),
          SizedBox(height: 18),

          // ---- Formulário e-mail/senha ----
          if (_cadastro)
            _campo(_nome, 'Seu nome', Icons.person_rounded),
          _campo(_email, 'E-mail', Icons.email_rounded,
              teclado: TextInputType.emailAddress),
          _campo(_senha, 'Senha (mínimo 6 caracteres)', Icons.lock_rounded,
              senha: true),
          SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _ocupado
                  ? null
                  : () {
                      if (_cadastro && _nome.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Digite seu nome.')));
                        return;
                      }
                      _executar(() => _cadastro
                          ? AuthService.instancia.cadastrar(
                              _nome.text, _email.text, _senha.text)
                          : AuthService.instancia
                              .entrar(_email.text, _senha.text));
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: CoresEleva.verde,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                textStyle:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              child: _ocupado
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Text(_cadastro ? 'Cadastrar' : 'Entrar'),
            ),
          ),
          SizedBox(height: 14),
          TextButton(
            onPressed: () => setState(() => _cadastro = !_cadastro),
            child: Text(
              _cadastro
                  ? 'Já tenho conta — quero entrar'
                  : 'Não tem conta? Cadastre-se grátis',
              style: TextStyle(
                  color: CoresEleva.dourado, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campo(TextEditingController c, String rotulo, IconData icone,
      {bool senha = false, TextInputType? teclado}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        obscureText: senha,
        keyboardType: teclado,
        decoration: InputDecoration(
          hintText: rotulo,
          prefixIcon: Icon(icone, color: CoresEleva.dourado, size: 20),
          filled: true,
          fillColor: CoresEleva.azulMedio,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

