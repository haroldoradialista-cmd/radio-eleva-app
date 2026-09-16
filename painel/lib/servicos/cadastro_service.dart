import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// CADASTRO COMPLETO DO OUVINTE
///
/// Na primeira vez que entra, o ouvinte informa NOME COMPLETO e WHATSAPP.
/// A partir daí, esses dados são preenchidos sozinhos em promoções,
/// pedidos musicais e anúncios — ele não digita mais nada.
///
/// A validação por código é OPCIONAL e ligada no painel, porque depende
/// de um serviço de envio (SMS ou WhatsApp) contratado pela rádio.
class CadastroService {
  static String base = '';

  // ---------- dados guardados no aparelho ----------
  static String nome = '';
  static String whatsapp = '';
  static String estado = '';
  static String cidade = '';
  static String nascimento = '';
  static bool validado = false;

  /// Carrega o cadastro do ouvinte (do aparelho e do banco)
  static Future<void> carregar(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      nome = prefs.getString('cad_nome_$uid') ?? '';
      whatsapp = prefs.getString('cad_zap_$uid') ?? '';
      estado = prefs.getString('cad_uf_$uid') ?? '';
      cidade = prefs.getString('cad_cidade_$uid') ?? '';
      nascimento = prefs.getString('cad_nasc_$uid') ?? '';
      validado = prefs.getBool('cad_validado_$uid') == true;
    } catch (_) {}

    // confere no banco (o ouvinte pode ter trocado de aparelho)
    if (base.isEmpty || uid.isEmpty) return;
    try {
      final r = await http
          .get(Uri.parse('$base/ouvintes/$uid.json'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200 && r.body != 'null') {
        final d = jsonDecode(utf8.decode(r.bodyBytes));
        if (d is Map) {
          nome = (d['nome'] ?? nome).toString();
          whatsapp = (d['whatsapp'] ?? whatsapp).toString();
          estado = (d['estado'] ?? estado).toString();
          cidade = (d['cidade'] ?? cidade).toString();
          nascimento = (d['nascimento'] ?? nascimento).toString();
          validado = d['validado'] == true || validado;
          await _guardarNoAparelho(uid);
        }
      }
    } catch (_) {}
  }

  static Future<void> _guardarNoAparelho(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cad_nome_$uid', nome);
      await prefs.setString('cad_zap_$uid', whatsapp);
      await prefs.setString('cad_uf_$uid', estado);
      await prefs.setString('cad_cidade_$uid', cidade);
      await prefs.setString('cad_nasc_$uid', nascimento);
      await prefs.setBool('cad_validado_$uid', validado);
    } catch (_) {}
  }

  /// Diz se o ouvinte já completou o cadastro
  static bool get completo =>
      nome.trim().length >= 5 &&
      _soNumeros(whatsapp).length >= 10 &&
      estado.trim().length == 2 &&
      cidade.trim().length >= 2 &&
      nascimento.replaceAll(RegExp(r'\D'), '').length == 8;

  /// Salva o cadastro (aparelho + banco)
  static Future<bool> salvar({
    required String uid,
    required String email,
    required String nomeCompleto,
    required String zap,
    String uf = '',
    String municipio = '',
    String dataNascimento = '',
    bool emailVerificado = false,
  }) async {
    nome = nomeCompleto.trim().toUpperCase();
    whatsapp = zap.trim();
    if (uf.isNotEmpty) estado = uf.trim().toUpperCase();
    if (municipio.isNotEmpty) cidade = municipio.trim().toUpperCase();
    if (dataNascimento.isNotEmpty) nascimento = dataNascimento.trim();
    await _guardarNoAparelho(uid);
    if (base.isEmpty || uid.isEmpty) return true;
    try {
      await http
          .put(
            Uri.parse('$base/ouvintes/$uid.json'),
            body: jsonEncode({
              'nome': nome,
              'whatsapp': whatsapp,
              'estado': estado,
              'cidade': cidade,
              'nascimento': nascimento,
              'email': email,
              'email_verificado': emailVerificado,
              'validado': validado,
              'quando': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 10));
      return true;
    } catch (_) {}
    return false;
  }

  /// Marca o cadastro como validado pelo código
  static Future<void> marcarValidado(String uid) async {
    validado = true;
    await _guardarNoAparelho(uid);
    if (base.isEmpty || uid.isEmpty) return;
    try {
      await http.patch(Uri.parse('$base/ouvintes/$uid.json'),
          body: jsonEncode({'validado': true}));
    } catch (_) {}
  }

  // ---------- CÓDIGO DE VERIFICAÇÃO ----------
  /// Gera um código de 6 números
  static String gerarCodigo() {
    final r = Random.secure();
    return List.generate(6, (_) => r.nextInt(10)).join();
  }

  /// Envia o código pelo serviço configurado no painel.
  ///
  /// A rádio configura o endereço e a chave do fornecedor (SMS ou
  /// WhatsApp) na aba Rádio & Redes. Assim, trocar de fornecedor não
  /// exige mudar o aplicativo.
  ///
  /// Devolve '' quando enviou, ou a mensagem de erro.
  static Future<String> enviarCodigo({
    required String envioUrl,
    required String envioChave,
    required String envioFormato,
    required String numero,
    required String codigo,
    required String nomeRadio,
  }) async {
    if (envioUrl.isEmpty) return 'Envio de código não configurado.';
    final texto = 'Seu codigo de acesso na $nomeRadio e $codigo. '
        'Nao compartilhe com ninguem.';
    final so = _soNumeros(numero);
    // o formato é definido pela rádio no painel, trocando as marcações
    final corpo = envioFormato
        .replaceAll('{numero}', so)
        .replaceAll('{numero55}', so.startsWith('55') ? so : '55$so')
        .replaceAll('{mensagem}', texto)
        .replaceAll('{codigo}', codigo)
        .replaceAll('{chave}', envioChave);
    try {
      final url = envioUrl
          .replaceAll('{numero}', so)
          .replaceAll('{numero55}', so.startsWith('55') ? so : '55$so')
          .replaceAll('{mensagem}', Uri.encodeComponent(texto))
          .replaceAll('{codigo}', codigo)
          .replaceAll('{chave}', envioChave);
      final r = corpo.trim().isEmpty
          ? await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20))
          : await http
              .post(Uri.parse(url),
                  headers: {
                    'Content-Type': 'application/json',
                    if (envioChave.isNotEmpty)
                      'Authorization': 'Bearer $envioChave',
                  },
                  body: corpo)
              .timeout(const Duration(seconds: 20));
      if (r.statusCode >= 200 && r.statusCode < 300) return '';
      return 'O serviço de envio respondeu ${r.statusCode}.';
    } catch (e) {
      return 'Não foi possível enviar agora.';
    }
  }

  static String _soNumeros(String s) => s.replaceAll(RegExp(r'\D'), '');

  /// Confere a data de nascimento (DD/MM/AAAA)
  static String erroNascimento(String texto) {
    final so = _soNumeros(texto);
    if (so.length < 8) return 'Escreva sua DATA DE NASCIMENTO (DD/MM/AAAA)';
    final dia = int.tryParse(so.substring(0, 2)) ?? 0;
    final mes = int.tryParse(so.substring(2, 4)) ?? 0;
    final ano = int.tryParse(so.substring(4, 8)) ?? 0;
    if (mes < 1 || mes > 12) return '❌ MÊS INCORRETO — vai de 01 a 12';
    if (dia < 1 || dia > 31) return '❌ DIA INCORRETO — vai de 01 a 31';
    final agora = DateTime.now();
    if (ano < agora.year - 110 || ano > agora.year) {
      return '❌ ANO INCORRETO — confira o ano de nascimento';
    }
    final d = DateTime(ano, mes, dia);
    if (d.day != dia || d.month != mes || d.year != ano) {
      return '❌ Esta data não existe';
    }
    if (d.isAfter(agora)) return '❌ A data não pode ser no futuro';
    return '';
  }

  /// Idade em anos completos a partir da data guardada
  static int get idade {
    final so = _soNumeros(nascimento);
    if (so.length < 8) return 0;
    final dia = int.tryParse(so.substring(0, 2)) ?? 0;
    final mes = int.tryParse(so.substring(2, 4)) ?? 0;
    final ano = int.tryParse(so.substring(4, 8)) ?? 0;
    final hoje = DateTime.now();
    var i = hoje.year - ano;
    if (hoje.month < mes || (hoje.month == mes && hoje.day < dia)) i--;
    return i;
  }

  /// Confere o DDD (11 a 99, e só os que existem no Brasil)
  static String erroDDD(String texto) {
    final so = _soNumeros(texto);
    if (so.isEmpty) return 'Informe o DDD';
    if (so.length < 2) return 'DDD incompleto';
    final n = int.tryParse(so) ?? 0;
    const existentes = [
      11,12,13,14,15,16,17,18,19, 21,22,24, 27,28,
      31,32,33,34,35,37,38, 41,42,43,44,45,46, 47,48,49,
      51,53,54,55, 61, 62,64, 63, 65,66, 67, 68, 69,
      71,73,74,75,77, 79, 81,87, 82, 83, 84, 85,88, 86,89,
      91,93,94, 92,97, 95, 96, 98,99
    ];
    if (!existentes.contains(n)) return '❌ DDD $so não existe';
    return '';
  }

  /// Confere o número (sem o DDD): celular 9, fixo 8
  static String erroNumero(String texto) {
    final so = _soNumeros(texto);
    if (so.isEmpty) return 'Informe o número';
    if (so.length < 8) return '❌ NÚMERO INCOMPLETO — 9 dígitos (celular) ou 8 (fixo)';
    if (so.length > 9) return '❌ NÚMERO MUITO LONGO';
    if (so.length == 9 && so[0] != '9') {
      return '❌ Celular começa com 9';
    }
    return '';
  }

  /// Confere o e-mail e avisa quando parece erro de digitação
  static String erroEmail(String texto) {
    final e = texto.trim().toLowerCase();
    if (e.isEmpty) return 'Informe seu e-mail';
    final formato = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    if (!formato.hasMatch(e)) return '❌ E-MAIL INVÁLIDO — confira o endereço';
    // erros de digitação mais comuns nos domínios
    const enganos = {
      'gmail.con':'gmail.com', 'gmail.co':'gmail.com', 'gmial.com':'gmail.com',
      'gmai.com':'gmail.com', 'gmail.cm':'gmail.com', 'gmailcom':'gmail.com',
      'hotmail.con':'hotmail.com', 'hotmal.com':'hotmail.com',
      'hotmai.com':'hotmail.com', 'outlok.com':'outlook.com',
      'yahoo.con':'yahoo.com', 'bol.com':'bol.com.br', 'uol.com':'uol.com.br',
    };
    final dominio = e.split('@').last;
    if (enganos.containsKey(dominio)) {
      return '❌ Você quis dizer @${enganos[dominio]}?';
    }
    return '';
  }

  /// Junta DDD e número no formato guardado
  static String montarTelefone(String ddd, String numero) {
    final d = _soNumeros(ddd), n = _soNumeros(numero);
    if (d.isEmpty || n.isEmpty) return '';
    return n.length == 9
        ? '($d) ${n.substring(0,5)}-${n.substring(5)}'
        : '($d) ${n.substring(0,4)}-${n.substring(4)}';
  }

  /// Confere o telefone (celular 11 dígitos, fixo 10)
  static String erroWhatsapp(String texto) {
    final so = _soNumeros(texto);
    if (so.isEmpty) return 'Escreva seu WhatsApp com DDD';
    if (so.length < 10) {
      return '❌ NÚMERO INCOMPLETO — use DDD + 9 números';
    }
    if (so.length > 11) return '❌ NÚMERO MUITO LONGO';
    if (so.length == 11 && so[2] != '9') {
      return '❌ Depois do DDD, o celular começa com 9';
    }
    final ddd = int.tryParse(so.substring(0, 2)) ?? 0;
    if (ddd < 11 || ddd > 99) return '❌ DDD inválido';
    return '';
  }

  /// Confere o nome completo (precisa de nome e sobrenome)
  static String erroNome(String texto) {
    final t = texto.trim();
    if (t.length < 5) return 'Escreva seu NOME COMPLETO';
    if (!t.contains(' ')) return 'Escreva também o SOBRENOME';
    return '';
  }
}
