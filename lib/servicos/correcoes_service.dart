import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// CENTRAL DE CORREÇÕES DA RÁDIO
///
/// Problema que este serviço resolve (a causa de letras e capas "sumirem"):
/// a transmissão manda o nome da música de jeitos diferentes ao longo dos
/// dias — com acento, sem acento, com "(AO VIVO)", com espaços a mais.
/// Antes, cada variação gerava uma CHAVE diferente no banco, então a
/// correção salva num dia não era encontrada no outro.
///
/// Agora a busca NÃO depende de chave exata:
///  1. a lista de correções é baixada UMA vez e fica guardada no aparelho
///     (funciona até sem internet);
///  2. cada correção é indexada por VÁRIAS formas de escrever o nome;
///  3. se ainda assim não bater, faz uma comparação tolerante (sem acento,
///     sem pontuação, ignorando "ao vivo", inversão de artista/música).
class CorrecoesService {
  static String base = '';
  static Map<String, Map<String, dynamic>> _indice = {};
  static List<Map<String, dynamic>> _todas = [];
  static Timer? _relogio;
  static bool _pronto = false;

  /// Guarda o que já foi resolvido nesta sessão: uma vez encontrado,
  /// nunca mais some enquanto o app estiver aberto.
  static final Map<String, Map<String, String>> _memoria = {};

  // ---------------- NORMALIZAÇÃO ----------------
  static String semAcento(String s) {
    const com = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
    const sem = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';
    var r = s;
    for (int i = 0; i < com.length; i++) {
      r = r.replaceAll(com[i], sem[i]);
    }
    return r;
  }

  /// Deixa o texto "cru": sem acento, sem pontuação, sem extras, minúsculo.
  static String cru(String s) {
    var r = ' ${semAcento(s.toLowerCase())} ';
    r = r.replaceAll(RegExp(r'[\(\[\{].*?[\)\]\}]'), ' ');
    r = r.replaceAll(
        RegExp(r'\b(feat|ft|part|participacao|com)\.?\s.*$'), ' ');
    r = r.replaceAll(
        RegExp(
            r'\b(ao vivo|acustico|playback|clipe|clip|video oficial|official video|lyric video|lyrics|cover|remix|versao|single|oficial)\b'),
        ' ');
    r = r.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    return r.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Separa "ARTISTA - MÚSICA"
  static (String, String) separar(String bruto) {
    final t = bruto.trim();
    final corte = t.indexOf(' - ');
    if (corte > 0) {
      return (t.substring(0, corte).trim(), t.substring(corte + 3).trim());
    }
    return ('', t);
  }

  /// Todas as formas de identificar a mesma música
  static List<String> chavesDe(String artista, String titulo) {
    final a = cru(artista);
    final t = cru(titulo);
    final lista = <String>[];
    if (a.isNotEmpty && t.isNotEmpty) {
      lista.add('$a|$t');
      lista.add('$t|$a'); // invertido
    }
    if (t.isNotEmpty) lista.add('|$t'); // só o título
    return lista;
  }

  // ---------------- CARGA ----------------
  static Future<void> iniciar(String enderecoBanco) async {
    base = enderecoBanco;
    await _lerDoAparelho(); // instantâneo, funciona offline
    await atualizar(); // busca a versão mais nova
    _relogio?.cancel();
    _relogio = Timer.periodic(const Duration(minutes: 10), (_) => atualizar());
  }

  static Future<void> _lerDoAparelho() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final txt = prefs.getString('correcoes_guardadas');
      if (txt != null && txt.isNotEmpty) {
        _montarIndice(jsonDecode(txt));
        _pronto = true;
      }
    } catch (_) {}
  }

  static Future<void> atualizar() async {
    if (base.isEmpty) return;
    try {
      final r = await http
          .get(Uri.parse('$base/correcoes.json'))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        final d = jsonDecode(utf8.decode(r.bodyBytes));
        if (d is Map && d['error'] == null) {
          _montarIndice(d);
          _pronto = true;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('correcoes_guardadas', jsonEncode(d));
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  static void _montarIndice(dynamic dados) {
    final indice = <String, Map<String, dynamic>>{};
    final todas = <Map<String, dynamic>>[];
    if (dados is Map) {
      dados.forEach((id, valor) {
        if (valor is! Map) return;
        final item = Map<String, dynamic>.from(valor);
        final musica = (item['musica'] ?? id).toString();
        final (art, tit) = separar(musica);
        item['_artista'] = cru(art);
        item['_titulo'] = cru(tit);
        todas.add(item);
        for (final k in chavesDe(art, tit)) {
          indice.putIfAbsent(k, () => item);
        }
        // também indexa pelo id salvo (compatibilidade com o formato antigo)
        indice.putIfAbsent('id|${id.toString().toLowerCase()}', () => item);
      });
    }
    _indice = indice;
    _todas = todas;
  }

  // ---------------- BUSCA ----------------
  /// Procura a correção desta música. Tenta chave exata e, se não achar,
  /// faz a comparação tolerante.
  static Map<String, dynamic>? procurar(String musicaBruta) {
    if (musicaBruta.trim().isEmpty) return null;
    final (art, tit) = separar(musicaBruta);
    final a = cru(art);
    final t = cru(tit);
    if (t.isEmpty) return null;

    // 1) chave direta
    for (final k in chavesDe(art, tit)) {
      final achado = _indice[k];
      if (achado != null) return achado;
    }

    // 2) comparação tolerante: título tem que bater; artista ajuda
    Map<String, dynamic>? melhor;
    for (final item in _todas) {
      final ai = (item['_artista'] ?? '').toString();
      final ti = (item['_titulo'] ?? '').toString();
      if (ti.isEmpty) continue;
      final tituloBate = ti == t ||
          (t.length >= 4 && (ti.contains(t) || t.contains(ti)));
      if (!tituloBate) continue;
      if (a.isEmpty || ai.isEmpty) {
        melhor ??= item; // guarda como possibilidade
        continue;
      }
      final artistaBate = ai == a ||
          ai.contains(a) ||
          a.contains(ai) ||
          _palavraEmComum(ai, a);
      if (artistaBate) return item; // combinação forte
      melhor ??= item;
    }
    return melhor;
  }

  static bool _palavraEmComum(String a, String b) {
    final pa = a.split(' ').where((w) => w.length >= 4).toSet();
    return b.split(' ').where((w) => w.length >= 4).any(pa.contains);
  }

  /// Letra corrigida desta música (ou null)
  static String? letraDe(String musicaBruta) {
    final item = procurar(musicaBruta);
    final l = (item?['letra'] ?? '').toString();
    return l.trim().length > 10 ? l : null;
  }

  /// Capa corrigida desta música (ou null)
  static String? capaDe(String musicaBruta) {
    final item = procurar(musicaBruta);
    final c = (item?['capa'] ?? '').toString();
    if (c.startsWith('http') || c.startsWith('data:image')) return c;
    if (c.length > 200 && !c.contains(' ')) return 'data:image/jpeg;base64,$c';
    return null;
  }

  static bool get pronto => _pronto;

  // ---------------- MEMÓRIA PERMANENTE ----------------
  /// Guarda no aparelho o que já deu certo, para NUNCA MAIS sumir —
  /// mesmo que a internet falhe ou o site de busca saia do ar.
  static Future<void> lembrar(
      String musicaBruta, {String? letra, String? capa}) async {
    final chave = cru(musicaBruta);
    if (chave.isEmpty) return;
    _memoria.putIfAbsent(chave, () => {});
    if (letra != null && letra.trim().length > 10) {
      _memoria[chave]!['letra'] = letra;
    }
    if (capa != null && capa.isNotEmpty) _memoria[chave]!['capa'] = capa;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (letra != null && letra.trim().length > 10) {
        await prefs.setString('lembrada_letra_$chave', letra);
      }
      if (capa != null && capa.isNotEmpty) {
        await prefs.setString('lembrada_capa_$chave', capa);
      }
    } catch (_) {}
  }

  /// Recupera o que já foi encontrado antes para esta música
  static Future<String?> lembrancaLetra(String musicaBruta) async {
    final chave = cru(musicaBruta);
    final naMemoria = _memoria[chave]?['letra'];
    if (naMemoria != null) return naMemoria;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('lembrada_letra_$chave');
    } catch (_) {}
    return null;
  }

  static Future<String?> lembrancaCapa(String musicaBruta) async {
    final chave = cru(musicaBruta);
    final naMemoria = _memoria[chave]?['capa'];
    if (naMemoria != null) return naMemoria;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('lembrada_capa_$chave');
    } catch (_) {}
    return null;
  }
}
