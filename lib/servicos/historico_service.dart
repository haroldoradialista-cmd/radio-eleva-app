import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'correcoes_service.dart';

/// TOCOU NA RÁDIO — histórico das músicas executadas
///
/// Guarda a sequência do que tocou, para o ouvinte poder consultar depois
/// aquela música que ouviu no carro e não deu tempo de anotar.
///
/// Como funciona: o registro é feito pelo próprio app quando a música muda.
/// Vários aparelhos podem registrar a mesma música ao mesmo tempo, então
/// usamos uma CHAVE POR MINUTO — assim a mesma execução vira um registro
/// só, mesmo com 150 ouvintes online.
class HistoricoService {
  static String base = '';
  static String _ultimaRegistrada = '';

  /// Diz se o que veio da transmissão é uma música.
  ///
  /// ATENÇÃO: aqui é melhor ERRAR PARA MAIS do que para menos. Se uma
  /// vinheta escapar, o ouvinte apenas vê uma linha estranha. Mas se uma
  /// música legítima for bloqueada, ela some do histórico — que foi o que
  /// acontecia com as versões "AO VIVO" (muito comuns no gospel).
  static bool _ehMusica(String bruto) {
    final t = bruto.trim();
    if (t.length < 6) return false;
    if (!t.contains(' - ')) return false; // precisa de "artista - música"

    final (artista, titulo) = separar(t);
    final aCru = CorrecoesService.cru(artista);
    final tCru = CorrecoesService.cru(titulo);
    if (aCru.length < 2 || tCru.length < 2) return false;

    // bloqueia só quando a PARTE INTEIRA é claramente institucional
    // Lista curta de propósito: "chamada" e "intervalo" saíram porque
    // existem MÚSICAS com esses nomes. Na dúvida, registramos.
    const soIsso = [
      'id', 'ids', 'vinheta', 'vinhetas', 'spot', 'spots',
      'comercial', 'comerciais', 'oferecimento', 'patrocinio',
      'sem titulo', 'unknown', 'no title', 'nao identificado'
    ];
    if (soIsso.contains(tCru) || soIsso.contains(aCru)) return false;

    // bloqueia quando começa com essas palavras (ex.: "VINHETA DE ABERTURA")
    for (final n in ['vinheta', 'comercial', 'spot ', 'oferecimento']) {
      if (tCru.startsWith(n) || aCru.startsWith(n)) return false;
    }
    return true;
  }

  /// Registra a música que está tocando agora.
  /// Devolve o identificador do registro (para acrescentar a capa depois),
  /// ou string vazia se não registrou.
  static Future<String> registrar(String musicaBruta, {String? capa}) async {
    if (base.isEmpty) return '';
    if (!_ehMusica(musicaBruta)) return '';

    final chaveMusica = CorrecoesService.cru(musicaBruta);
    if (chaveMusica == _ultimaRegistrada) return '';
    _ultimaRegistrada = chaveMusica;

    final agora = DateTime.now();
    // chave por MINUTO: se 150 aparelhos registrarem a mesma música no
    // mesmo minuto, todos gravam no mesmo lugar — vira um registro só.
    final id = '${agora.year}'
        '${agora.month.toString().padLeft(2, '0')}'
        '${agora.day.toString().padLeft(2, '0')}_'
        '${agora.hour.toString().padLeft(2, '0')}'
        '${agora.minute.toString().padLeft(2, '0')}';

    try {
      await http
          .put(
            Uri.parse('$base/tocou/$id.json'),
            body: jsonEncode({
              'musica': musicaBruta.trim(),
              'quando': agora.toIso8601String(),
              if (capa != null && capa.startsWith('http')) 'capa': capa,
            }),
          )
          .timeout(const Duration(seconds: 8));
      return id;
    } catch (_) {}
    return '';
  }

  /// Acrescenta a capa a um registro já feito (a capa demora mais que o
  /// registro da música, então ela chega depois).
  static Future<void> completarCapa(String id, String? capa) async {
    if (base.isEmpty || id.isEmpty) return;
    if (capa == null || !capa.startsWith('http')) return;
    try {
      await http
          .patch(Uri.parse('$base/tocou/$id.json'),
              body: jsonEncode({'capa': capa}))
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  /// Busca as últimas músicas tocadas (mais recentes primeiro)
  static Future<List<Map<String, dynamic>>> ultimas({int quantas = 30}) async {
    if (base.isEmpty) return [];
    try {
      final r = await http
          .get(Uri.parse(
              '$base/tocou.json?orderBy="\$key"&limitToLast=$quantas'))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        final d = jsonDecode(utf8.decode(r.bodyBytes));
        if (d is Map) {
          final lista = <Map<String, dynamic>>[];
          d.forEach((id, v) {
            if (v is Map) {
              final item = Map<String, dynamic>.from(v);
              item['_id'] = id;
              lista.add(item);
            }
          });
          // mais recentes primeiro
          lista.sort((a, b) =>
              (b['_id'] ?? '').toString().compareTo((a['_id'] ?? '').toString()));
          await _guardarCopia(lista);
          return lista;
        }
      }
    } catch (_) {}
    // sem internet: devolve a última lista guardada
    return await _copiaGuardada();
  }

  static Future<void> _guardarCopia(List<Map<String, dynamic>> lista) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tocou_guardado', jsonEncode(lista));
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> _copiaGuardada() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final txt = prefs.getString('tocou_guardado');
      if (txt != null && txt.isNotEmpty) {
        final d = jsonDecode(txt);
        if (d is List) {
          return d.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// ---------- CURTIDA NO HISTÓRICO ----------
  /// O ouvinte pode curtir uma música que já passou (aquela que ele ouviu
  /// no carro e não deu tempo). A curtida vale UMA VEZ por execução e não
  /// pode ser desfeita — é um voto, não um favorito.
  ///
  /// O voto vai para o MESMO lugar das curtidas da tela inicial, então
  /// aparece normalmente na aba Votos do painel.
  static Future<bool> jaCurtiu(String idMomento) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('curtiu_tocou_$idMomento') == true;
    } catch (_) {}
    return false;
  }

  static Future<bool> curtir(String idMomento, String musica) async {
    if (base.isEmpty || idMomento.isEmpty) return false;
    if (await jaCurtiu(idMomento)) return false;
    try {
      final r = await http
          .post(
            Uri.parse('$base/votos.json'),
            body: jsonEncode({
              'tipo': 'like',
              'musica': musica,
              'origem': 'tocou na rádio',
              'quando': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (r.statusCode >= 200 && r.statusCode < 300) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('curtiu_tocou_$idMomento', true);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Descobre de uma vez quais itens da lista já foram curtidos
  static Future<Set<String>> curtidasDe(List<String> ids) async {
    final curtidas = <String>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final id in ids) {
        if (prefs.getBool('curtiu_tocou_$id') == true) curtidas.add(id);
      }
    } catch (_) {}
    return curtidas;
  }

  /// Separa "ARTISTA - MÚSICA"
  static (String, String) separar(String bruto) {
    final t = bruto.trim();
    final i = t.indexOf(' - ');
    if (i > 0) {
      return (t.substring(0, i).trim(), t.substring(i + 3).trim());
    }
    return ('', t);
  }

  /// Hora no formato 18:42
  static String hora(String quando) {
    try {
      final d = DateTime.parse(quando);
      return '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {}
    return '';
  }

  /// Diz se foi hoje, ontem, ou a data
  static String dia(String quando) {
    try {
      final d = DateTime.parse(quando);
      final hoje = DateTime.now();
      final ontem = hoje.subtract(const Duration(days: 1));
      if (d.year == hoje.year && d.month == hoje.month && d.day == hoje.day) {
        return 'HOJE';
      }
      if (d.year == ontem.year && d.month == ontem.month && d.day == ontem.day) {
        return 'ONTEM';
      }
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}';
    } catch (_) {}
    return '';
  }
}
