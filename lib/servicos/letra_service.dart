import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'correcoes_service.dart';

/// Busca a letra de uma música tentando VÁRIAS fontes em cascata.
/// Nenhuma exige cadastro ou chave.
///   - LRCLIB   — base aberta com ~3 milhões de letras (com User-Agent)
///   - lyrics.ovh — reforço
/// Para cada fonte, tenta variações do nome (com/sem acento, invertido,
/// limpo de "ao vivo/feat.") para acertar o máximo possível.
class LetraService {
  static final Map<String, String?> _cache = {};

  // Identificação exigida pela LRCLIB (melhora muito a taxa de resposta)
  static const _headers = {
    'User-Agent': 'RadioEleva/1.0 (https://radioeleva.com.br)',
  };

  static (String, String) _separar(String bruto) {
    final t = bruto.trim();
    for (final s in [' - ', ' – ', ' — ', ' _ ']) {
      final i = t.indexOf(s);
      if (i > 0) {
        return (t.substring(0, i).trim(), t.substring(i + s.length).trim());
      }
    }
    return ('', t);
  }

  static String _limpar(String s) {
    var r = ' $s ';
    r = r.replaceAll(RegExp(r'[\(\[].*?[\)\]]'), ' ');
    r = r.replaceAll(
        RegExp(r'\b(feat|ft|part|participacao|participação|com)\.?\s.*$',
            caseSensitive: false),
        ' ');
    r = r.replaceAll(
        RegExp(
            r'\b(ao vivo|acustico|acústico|playback|clipe|clip|video oficial|vídeo oficial|official video|official music video|lyric video|lyrics|cover|remix|versao|versão)\b',
            caseSensitive: false),
        ' ');
    r = r.replaceAll(RegExp(r'[|/•].*$'), ' ');
    r = r.replaceAll(RegExp(r'\s+'), ' ').trim();
    return r;
  }

  static String _semAcento(String s) {
    const de = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
    const para = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
    var r = s;
    for (var i = 0; i < de.length; i++) {
      r = r.replaceAll(de[i], para[i]);
    }
    return r;
  }

  static String _limparLetra(String s) =>
      s.trim().replaceAll('\r', '').replaceAll(RegExp(r'\n{3,}'), '\n\n');

  // ---------- BASE DA RADIO (correcoes feitas no painel) ----------
  /// Endereco do Firebase da radio (preenchido pelo app na abertura).
  static String baseRtdb = '';

  /// Procura a letra na BASE DA PROPRIA RADIO. Tem prioridade sobre tudo:
  /// se o Haroldo (ou a equipe) corrigiu a letra no painel, e ela que vale.
  static Future<String?> _daRadio(String artista, String titulo) async {
    if (baseRtdb.isEmpty) return null;
    try {
      final id = _idMusica(artista, titulo);
      final url = Uri.parse('$baseRtdb/correcoes/$id.json');
      final r = await http.get(url).timeout(const Duration(seconds: 6));
      if (r.statusCode == 200) {
        final j = jsonDecode(utf8.decode(r.bodyBytes));
        if (j is Map) {
          final letra = (j['letra'] ?? '').toString();
          if (letra.trim().length > 10) return _limparLetra(letra);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Identificador da musica usado na base da radio (mesmo padrao do painel)
  static String _idMusica(String artista, String titulo) {
    final s = '${artista}_$titulo'
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return s.replaceAll(RegExp(r'^_|_$'), '');
  }

  // ---------- VAGALUME (acervo brasileiro, inclui gospel) ----------
  static Future<String?> _vagalume(String artista, String titulo) async {
    if (artista.isEmpty || titulo.isEmpty) return null;
    try {
      final url = Uri.parse(
          'https://api.vagalume.com.br/search.php?art=${Uri.encodeComponent(artista)}&mus=${Uri.encodeComponent(titulo)}');
      final r = await http.get(url).timeout(const Duration(seconds: 9));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is! Map) return null;
      if ((j['type'] ?? '').toString() == 'notfound') return null;
      final mus = j['mus'];
      if (mus is List && mus.isNotEmpty) {
        final letra = (mus.first['text'] ?? '').toString();
        if (letra.trim().length > 10) return _limparLetra(letra);
      }
    } catch (_) {}
    return null;
  }

  // ---------- LRCLIB: get exato ----------
  static Future<String?> _lrclibGet(String artista, String titulo) async {
    if (titulo.isEmpty) return null;
    try {
      final url = Uri.parse(
          'https://lrclib.net/api/get?artist_name=${Uri.encodeComponent(artista)}&track_name=${Uri.encodeComponent(titulo)}');
      final r =
          await http.get(url, headers: _headers).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final j = jsonDecode(utf8.decode(r.bodyBytes));
        final letra = (j['plainLyrics'] ?? '').toString();
        if (letra.trim().length > 10) return _limparLetra(letra);
      }
    } catch (_) {}
    return null;
  }

  /// Compara dois nomes ignorando acentos, maiúsculas e pontuação.
  /// Retorna true se um contém o outro (match forte).
  static bool _combina(String a, String b) {
    String n(String s) => _semAcento(s.toLowerCase())
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final x = n(a), y = n(b);
    if (x.isEmpty || y.isEmpty) return false;
    return x == y || x.contains(y) || y.contains(x);
  }

  // ---------- LRCLIB: busca aproximada COM VALIDAÇÃO ----------
  /// Só aceita o resultado se o artista E o título realmente conferem
  /// com a música que está tocando (evita exibir letra de outra música).
  static Future<String?> _lrclibBusca(
      String consulta, String artistaReal, String tituloReal) async {
    if (consulta.trim().isEmpty) return null;
    try {
      final url = Uri.parse(
          'https://lrclib.net/api/search?q=${Uri.encodeComponent(consulta)}');
      final r =
          await http.get(url, headers: _headers).timeout(const Duration(seconds: 9));
      if (r.statusCode == 200) {
        final lista = jsonDecode(utf8.decode(r.bodyBytes));
        if (lista is List) {
          for (final item in lista) {
            final letra = (item['plainLyrics'] ?? '').toString();
            if (letra.trim().length <= 10) continue;
            final artResp = (item['artistName'] ?? '').toString();
            final titResp = (item['trackName'] ?? '').toString();
            // o TÍTULO precisa bater; o artista bate ou não foi informado
            final tituloOk = _combina(titResp, tituloReal);
            final artistaOk =
                artistaReal.isEmpty || _combina(artResp, artistaReal);
            if (tituloOk && artistaOk) return _limparLetra(letra);
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // ---------- lyrics.ovh ----------
  static Future<String?> _lyricsOvh(String artista, String titulo) async {
    if (titulo.isEmpty || artista.isEmpty) return null;
    try {
      final url = Uri.parse(
          'https://api.lyrics.ovh/v1/${Uri.encodeComponent(artista)}/${Uri.encodeComponent(titulo)}');
      final r = await http.get(url).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final j = jsonDecode(utf8.decode(r.bodyBytes));
        final letra = (j['lyrics'] ?? '').toString();
        if (letra.trim().length > 10) return _limparLetra(letra);
      }
    } catch (_) {}
    return null;
  }

  // ---------- lrcmux.dev (agrega vários provedores) ----------
  static Future<String?> _lrcmux(String artista, String titulo) async {
    if (titulo.isEmpty) return null;
    try {
      final url = Uri.parse(
          'https://lrcmux.dev/api/get?artist_name=${Uri.encodeComponent(artista)}&track_name=${Uri.encodeComponent(titulo)}');
      final r = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final j = jsonDecode(utf8.decode(r.bodyBytes));
        final letra = (j['plainLyrics'] ?? j['lyrics'] ?? '').toString();
        if (letra.trim().length > 10) return _limparLetra(letra);
      }
    } catch (_) {}
    return null;
  }

  // ---------- ChartLyrics (busca por artista+título) ----------
  static Future<String?> _chartLyrics(String artista, String titulo) async {
    if (titulo.isEmpty || artista.isEmpty) return null;
    try {
      final url = Uri.parse(
          'http://api.chartlyrics.com/apiv1.asmx/SearchLyricDirect?artist=${Uri.encodeComponent(artista)}&song=${Uri.encodeComponent(titulo)}');
      final r = await http.get(url).timeout(const Duration(seconds: 9));
      if (r.statusCode == 200) {
        // resposta é XML: extrai o conteúdo de <Lyric>...</Lyric>
        final corpo = utf8.decode(r.bodyBytes);
        final m = RegExp(r'<Lyric>([\s\S]*?)</Lyric>').firstMatch(corpo);
        if (m != null) {
          var letra = m.group(1) ?? '';
          // desfaz entidades básicas do XML
          letra = letra
              .replaceAll('&amp;', '&')
              .replaceAll('&lt;', '<')
              .replaceAll('&gt;', '>')
              .replaceAll('&apos;', "'")
              .replaceAll('&quot;', '"')
              .replaceAll('&#39;', "'");
          if (letra.trim().length > 10) return _limparLetra(letra);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Retorna a letra, ou null.
  /// Quantas vezes os ouvintes ja disseram que a letra desta musica esta
  /// errada. A cada aviso, o app PULA a fonte que errou e tenta a proxima —
  /// e assim a correcao acontece sozinha, sem ninguem mexer.
  static Future<int> _rejeicoes(String chave) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('letra_rej_$chave') ?? 0;
    } catch (_) {}
    return 0;
  }

  /// Chamada quando o ouvinte reporta que a letra nao e desta musica.
  static Future<void> marcarErrada(String musicaBruta) async {
    final chave = musicaBruta.trim().toLowerCase();
    if (chave.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final atual = prefs.getInt('letra_rej_$chave') ?? 0;
      await prefs.setInt('letra_rej_$chave', atual + 1);
    } catch (_) {}
    _cache.remove(chave); // esquece a letra rejeitada
  }

  static Future<String?> buscar(String musicaBruta) async {
    final chave = musicaBruta.trim().toLowerCase();
    if (chave.isEmpty) return null;
    if (_cache.containsKey(chave)) return _cache[chave];

    final (artista, titulo) = _separar(musicaBruta);
    final aL = _limpar(artista);
    final tL = _limpar(titulo);

    // quantas fontes ja foram rejeitadas pelos ouvintes nesta musica
    var pular = await _rejeicoes(chave);

    // 0) BASE DA RADIO: correcoes feitas no painel valem mais que tudo.
    //    A busca e TOLERANTE (com/sem acento, com "ao vivo", invertida),
    //    entao a correcao nao "some" quando a transmissao muda o nome.
    final daCentral = CorrecoesService.letraDe(musicaBruta);
    if (daCentral != null) {
      _cache[chave] = _limparLetra(daCentral);
      return _cache[chave];
    }
    final daRadio = await _daRadio(aL, tL);
    if (daRadio != null) {
      _cache[chave] = daRadio;
      return daRadio;
    }
    // 0b) o que JA foi encontrado antes neste aparelho (nunca some)
    final lembrada = await CorrecoesService.lembrancaLetra(musicaBruta);
    if (lembrada != null && lembrada.trim().length > 10) {
      _cache[chave] = lembrada;
      // segue tentando na internet em segundo plano, mas ja mostra esta
      return lembrada;
    }

    // 1) LRCLIB get exato, com variações de nome
    final combos = <(String, String)>[
      if (aL.isNotEmpty) (aL, tL),
      if (aL.isNotEmpty) (tL, aL), // stream pode vir "Título - Artista"
      if (aL.isNotEmpty) (_semAcento(aL), _semAcento(tL)),
      if (aL.isNotEmpty && (artista != aL || titulo != tL)) (artista, titulo),
    ];
    final vistos = <String>{};
    for (final (a, t) in combos) {
      final id = '$a|$t';
      if (vistos.contains(id)) continue;
      vistos.add(id);
      final letra = await _lrclibGet(a, t);
      if (letra != null) {
        if (pular > 0) {
          pular--; // fonte ja reprovada pelos ouvintes: tenta a proxima
        } else {
          _cache[chave] = letra;
          CorrecoesService.lembrar(musicaBruta, letra: letra);
          return letra;
        }
      }
    }

    // 2) LRCLIB busca aproximada — só aceita se conferir artista e título
    for (final consulta in <String>[
      if (aL.isNotEmpty) '$aL $tL',
      if (aL.isNotEmpty) _semAcento('$aL $tL'),
    ]) {
      final letra = await _lrclibBusca(consulta, aL, tL);
      if (letra != null) {
        if (pular > 0) {
          pular--; // fonte ja reprovada pelos ouvintes: tenta a proxima
        } else {
          _cache[chave] = letra;
          CorrecoesService.lembrar(musicaBruta, letra: letra);
          return letra;
        }
      }
    }

    // 2b) VAGALUME — acervo brasileiro, melhor chance para gospel nacional
    for (final (a, t) in combos) {
      final letra = await _vagalume(a, t);
      if (letra != null) {
        if (pular > 0) {
          pular--; // fonte ja reprovada pelos ouvintes: tenta a proxima
        } else {
          _cache[chave] = letra;
          CorrecoesService.lembrar(musicaBruta, letra: letra);
          return letra;
        }
      }
    }

    // 3) lyrics.ovh como reforço
    for (final (a, t) in combos) {
      final letra = await _lyricsOvh(a, t);
      if (letra != null) {
        if (pular > 0) {
          pular--; // fonte ja reprovada pelos ouvintes: tenta a proxima
        } else {
          _cache[chave] = letra;
          CorrecoesService.lembrar(musicaBruta, letra: letra);
          return letra;
        }
      }
    }

    // 4) lrcmux.dev — agrega vários provedores de letra
    for (final (a, t) in combos) {
      final letra = await _lrcmux(a, t);
      if (letra != null) {
        if (pular > 0) {
          pular--; // fonte ja reprovada pelos ouvintes: tenta a proxima
        } else {
          _cache[chave] = letra;
          CorrecoesService.lembrar(musicaBruta, letra: letra);
          return letra;
        }
      }
    }

    // 5) ChartLyrics — mais uma base independente
    for (final (a, t) in combos) {
      final letra = await _chartLyrics(a, t);
      if (letra != null) {
        if (pular > 0) {
          pular--; // fonte ja reprovada pelos ouvintes: tenta a proxima
        } else {
          _cache[chave] = letra;
          CorrecoesService.lembrar(musicaBruta, letra: letra);
          return letra;
        }
      }
    }

    // 6) último reforço: LRCLIB só pelo título — SOMENTE quando o artista
    //    nao veio no metadado. Aceitar so pelo titulo com artista conhecido
    //    trazia LETRA DE OUTRA MUSICA de mesmo nome (de outro genero).
    if (tL.isNotEmpty && aL.isEmpty) {
      final letra = await _lrclibBusca(tL, '', tL);
      if (letra != null) {
        if (pular > 0) {
          pular--; // fonte ja reprovada pelos ouvintes: tenta a proxima
        } else {
          _cache[chave] = letra;
          CorrecoesService.lembrar(musicaBruta, letra: letra);
          return letra;
        }
      }
    }

    _cache[chave] = null;
    return null;
  }
}
