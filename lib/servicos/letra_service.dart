import 'dart:convert';
import 'package:http/http.dart' as http;

/// Busca a letra de uma música tentando VÁRIAS fontes em cascata,
/// para cobrir o máximo possível do repertório gospel brasileiro.
/// Fontes (todas públicas, sem chave obrigatória):
///   - Vagalume  — forte em MPB/gospel nacional
///   - LRCLIB    — base aberta e grande
///   - lyrics.ovh — reforço internacional
class LetraService {
  static final Map<String, String?> _cache = {};

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
      s.trim().replaceAll(RegExp(r'\r'), '').replaceAll(RegExp(r'\n{3,}'), '\n\n');

  // ---------- Fonte 1: Vagalume ----------
  static Future<String?> _vagalume(String artista, String titulo) async {
    if (artista.isEmpty || titulo.isEmpty) return null;
    try {
      final url = Uri.parse(
          'https://api.vagalume.com.br/search.php?art=${Uri.encodeComponent(artista)}&mus=${Uri.encodeComponent(titulo)}');
      final r = await http.get(url).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200 && r.body.isNotEmpty) {
        final j = jsonDecode(r.body);
        if (j is Map && j['mus'] is List && (j['mus'] as List).isNotEmpty) {
          final letra = (j['mus'][0]['text'] ?? '').toString();
          if (letra.trim().length > 10) return _limparLetra(letra);
        }
      }
    } catch (_) {}
    return null;
  }

  // ---------- Fonte 2: LRCLIB ----------
  static Future<String?> _lrclib(String artista, String titulo) async {
    if (titulo.isEmpty) return null;
    try {
      final url = Uri.parse(
          'https://lrclib.net/api/get?artist_name=${Uri.encodeComponent(artista)}&track_name=${Uri.encodeComponent(titulo)}');
      final r = await http.get(url).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final j = jsonDecode(utf8.decode(r.bodyBytes));
        final letra = (j['plainLyrics'] ?? '').toString();
        if (letra.trim().length > 10) return _limparLetra(letra);
      }
      // busca aproximada
      final url2 = Uri.parse(
          'https://lrclib.net/api/search?q=${Uri.encodeComponent('$artista $titulo')}');
      final r2 = await http.get(url2).timeout(const Duration(seconds: 8));
      if (r2.statusCode == 200) {
        final lista = jsonDecode(utf8.decode(r2.bodyBytes));
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

  // ---------- Fonte 3: lyrics.ovh ----------
  static Future<String?> _lyricsOvh(String artista, String titulo) async {
    if (titulo.isEmpty) return null;
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

  /// Tenta todas as fontes com uma dada combinação de artista/título.
  static Future<String?> _todasAsFontes(String a, String t) async {
    for (final fonte in [_vagalume, _lrclib, _lyricsOvh]) {
      final letra = await fonte(a, t);
      if (letra != null) return letra;
    }
    return null;
  }

  /// Retorna a letra, ou null. Faz várias tentativas (variações do nome)
  /// e, em cada uma, consulta as três fontes.
  static Future<String?> buscar(String musicaBruta) async {
    final chave = musicaBruta.trim().toLowerCase();
    if (chave.isEmpty) return null;
    if (_cache.containsKey(chave)) return _cache[chave];

    final (artista, titulo) = _separar(musicaBruta);
    final aL = _limpar(artista);
    final tL = _limpar(titulo);

    final tentativas = <(String, String)>[
      if (aL.isNotEmpty) (aL, tL),
      if (aL.isNotEmpty) (tL, aL), // stream pode vir "Título - Artista"
      if (aL.isNotEmpty) (_semAcento(aL), _semAcento(tL)),
      if (aL.isNotEmpty && (artista != aL || titulo != tL)) (artista, titulo),
      if (aL.isEmpty) ('', tL),
    ];

    final vistos = <String>{};
    for (final (a, t) in tentativas) {
      final id = '$a|$t';
      if (vistos.contains(id)) continue;
      vistos.add(id);
      final letra = await _todasAsFontes(a, t);
      if (letra != null) {
        _cache[chave] = letra;
        return letra;
      }
    }

    _cache[chave] = null;
    return null;
  }
}
