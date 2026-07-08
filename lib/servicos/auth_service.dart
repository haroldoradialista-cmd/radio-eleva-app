import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../app_config.dart';

class Usuario {
  final String uid;
  final String nome;
  final String email;
  String idToken;
  String refreshToken;
  int expiraEm; // epoch em segundos

  Usuario({
    required this.uid,
    required this.nome,
    required this.email,
    required this.idToken,
    required this.refreshToken,
    required this.expiraEm,
  });
}

class AuthService {
  static final AuthService instancia = AuthService._();
  AuthService._();

  final ValueNotifier<Usuario?> usuario = ValueNotifier(null);
  static const _base = 'https://identitytoolkit.googleapis.com/v1';

  // ---------- SESSÃO ----------
  Future<void> restaurarSessao() async {
    if (usuario.value != null) return;
    final p = await SharedPreferences.getInstance();
    final rt = p.getString('refreshToken');
    if (rt == null || rt.isEmpty) return;
    try {
      final r = await http.post(
        Uri.parse('https://securetoken.googleapis.com/v1/token?key=$kFirebaseApiKey'),
        body: {'grant_type': 'refresh_token', 'refresh_token': rt},
      );
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        usuario.value = Usuario(
          uid: d['user_id'],
          nome: p.getString('nome') ?? 'Ouvinte',
          email: p.getString('email') ?? '',
          idToken: d['id_token'],
          refreshToken: d['refresh_token'],
          expiraEm: DateTime.now().millisecondsSinceEpoch ~/ 1000 +
              int.parse(d['expires_in'].toString()),
        );
      }
    } catch (_) {}
  }

  Future<String?> tokenValido() async {
    final u = usuario.value;
    if (u == null) return null;
    final agora = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (u.expiraEm - agora > 300) return u.idToken;
    try {
      final r = await http.post(
        Uri.parse('https://securetoken.googleapis.com/v1/token?key=$kFirebaseApiKey'),
        body: {'grant_type': 'refresh_token', 'refresh_token': u.refreshToken},
      );
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        u.idToken = d['id_token'];
        u.refreshToken = d['refresh_token'];
        u.expiraEm = agora + int.parse(d['expires_in'].toString());
        return u.idToken;
      }
    } catch (_) {}
    return u.idToken;
  }

  Future<void> _salvarSessao(Usuario u) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('refreshToken', u.refreshToken);
    await p.setString('nome', u.nome);
    await p.setString('email', u.email);
    usuario.value = u;
  }

  Future<void> sair() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('refreshToken');
    await p.remove('nome');
    await p.remove('email');
    try {
      await GoogleSignIn(serverClientId: kGoogleServerClientId).signOut();
    } catch (_) {}
    usuario.value = null;
  }

  // ---------- CADASTRO COM E-MAIL ----------
  Future<String?> cadastrar(String nome, String email, String senha) async {
    try {
      final r = await http.post(
        Uri.parse('$_base/accounts:signUp?key=$kFirebaseApiKey'),
        body: jsonEncode({
          'email': email.trim(),
          'password': senha,
          'returnSecureToken': true,
        }),
      );
      final d = jsonDecode(r.body);
      if (r.statusCode != 200) return _traduzErro(d);
      // define o nome do usuário
      await http.post(
        Uri.parse('$_base/accounts:update?key=$kFirebaseApiKey'),
        body: jsonEncode({
          'idToken': d['idToken'],
          'displayName': nome.trim(),
          'returnSecureToken': false,
        }),
      );
      await _salvarSessao(Usuario(
        uid: d['localId'],
        nome: nome.trim(),
        email: email.trim(),
        idToken: d['idToken'],
        refreshToken: d['refreshToken'],
        expiraEm: DateTime.now().millisecondsSinceEpoch ~/ 1000 +
            int.parse(d['expiresIn'].toString()),
      ));
      return null;
    } catch (_) {
      return 'Falha de conexão. Verifique sua internet.';
    }
  }

  // ---------- LOGIN COM E-MAIL ----------
  Future<String?> entrar(String email, String senha) async {
    try {
      final r = await http.post(
        Uri.parse('$_base/accounts:signInWithPassword?key=$kFirebaseApiKey'),
        body: jsonEncode({
          'email': email.trim(),
          'password': senha,
          'returnSecureToken': true,
        }),
      );
      final d = jsonDecode(r.body);
      if (r.statusCode != 200) return _traduzErro(d);
      await _salvarSessao(Usuario(
        uid: d['localId'],
        nome: (d['displayName'] ?? '').toString().isNotEmpty
            ? d['displayName']
            : email.split('@').first,
        email: email.trim(),
        idToken: d['idToken'],
        refreshToken: d['refreshToken'],
        expiraEm: DateTime.now().millisecondsSinceEpoch ~/ 1000 +
            int.parse(d['expiresIn'].toString()),
      ));
      return null;
    } catch (_) {
      return 'Falha de conexão. Verifique sua internet.';
    }
  }

  // ---------- LOGIN COM GOOGLE ----------
  Future<String?> entrarComGoogle() async {
    try {
      final g = GoogleSignIn(serverClientId: kGoogleServerClientId);
      final conta = await g.signIn();
      if (conta == null) return 'Login cancelado.';
      final autent = await conta.authentication;
      final idTokenGoogle = autent.idToken;
      if (idTokenGoogle == null) {
        return 'Não foi possível obter a credencial do Google.';
      }
      final r = await http.post(
        Uri.parse('$_base/accounts:signInWithIdp?key=$kFirebaseApiKey'),
        body: jsonEncode({
          'postBody': 'id_token=$idTokenGoogle&providerId=google.com',
          'requestUri': 'http://localhost',
          'returnIdpCredential': true,
          'returnSecureToken': true,
        }),
      );
      final d = jsonDecode(r.body);
      if (r.statusCode != 200) return _traduzErro(d);
      await _salvarSessao(Usuario(
        uid: d['localId'],
        nome: (d['displayName'] ?? conta.displayName ?? 'Ouvinte').toString(),
        email: (d['email'] ?? conta.email).toString(),
        idToken: d['idToken'],
        refreshToken: d['refreshToken'],
        expiraEm: DateTime.now().millisecondsSinceEpoch ~/ 1000 +
            int.parse((d['expiresIn'] ?? '3600').toString()),
      ));
      return null;
    } catch (e) {
      return 'Erro no login Google. Tente novamente.';
    }
  }

  String _traduzErro(Map d) {
    final cod = (d['error']?['message'] ?? '').toString();
    if (cod.contains('EMAIL_EXISTS')) {
      return 'Este e-mail já está cadastrado. Use "Entrar".';
    }
    if (cod.contains('INVALID_LOGIN_CREDENTIALS') ||
        cod.contains('INVALID_PASSWORD') ||
        cod.contains('EMAIL_NOT_FOUND')) {
      return 'E-mail ou senha incorretos.';
    }
    if (cod.contains('WEAK_PASSWORD')) {
      return 'A senha precisa ter pelo menos 6 caracteres.';
    }
    if (cod.contains('INVALID_EMAIL')) return 'E-mail inválido.';
    if (cod.contains('TOO_MANY_ATTEMPTS')) {
      return 'Muitas tentativas. Aguarde alguns minutos.';
    }
    return 'Não foi possível completar. Tente novamente.';
  }
}
