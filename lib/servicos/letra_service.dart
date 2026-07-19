import 'dart:convert';
import 'package:http/http.dart' as http;

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
    var r = s;
    r = r.replaceAll(RegExp(r'[\(\[].*?[\)\]]'), ' ');
    r = r.replaceAll(
        RegExp(r'\b(feat|ft|part|participacao|participação|com)\.?\s.*$',
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

  // ---------- LRCLIB: busca aproximada ----------
  static Future<String?> _lrclibBusca(String consulta) async {
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
            if (letra.trim().length > 10) return _limparLetra(letra);
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

  /// Retorna a letra, ou null.
  static Future<String?> buscar(String musicaBruta) async {
    final chave = musicaBruta.trim().toLowerCase();
    if (chave.isEmpty) return null;
    if (_cache.containsKey(chave)) return _cache[chave];

    final (artista, titulo) = _separar(musicaBruta);
    final aL = _limpar(artista);
    final tL = _limpar(titulo);

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
        _cache[chave] = letra;
        return letra;
      }
    }

    // 2) LRCLIB busca aproximada (pega variações de grafia)
    for (final consulta in <String>[
      if (aL.isNotEmpty) '$aL $tL',
      if (tL.isNotEmpty) tL,
      if (aL.isNotEmpty) _semAcento('$aL $tL'),
    ]) {
      final letra = await _lrclibBusca(consulta);
      if (letra != null) {
        _cache[chave] = letra;
        return letra;
      }
    }

    // 3) lyrics.ovh como último reforço
    for (final (a, t) in combos) {
      final letra = await _lyricsOvh(a, t);
      if (letra != null) {
        _cache[chave] = letra;
        return letra;
      }
    }

    _cache[chave] = null;
    return null;
  }
}
