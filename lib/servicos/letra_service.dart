import 'dart:convert';
import 'package:http/http.dart' as http;

/// Busca a letra de uma música pelo nome que vem nos metadados do stream
/// (formato "Artista - Título"). Usa a API pública e gratuita lyrics.ovh,
/// que não exige cadastro nem chave.
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

  /// Limpa trechos que atrapalham a busca: (ao vivo), [clipe], feat., etc.
  static String _limpar(String s) {
    var r = s;
    r = r.replaceAll(RegExp(r'[\(\[].*?[\)\]]'), ' ');
    r = r.replaceAll(
        RegExp(r'\b(feat|ft|part|participacao|participação)\.?.*$',
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

  static Future<String?> _tentar(String artista, String titulo) async {
    if (titulo.trim().isEmpty) return null;
    try {
      final url = Uri.parse(
          'https://api.lyrics.ovh/v1/${Uri.encodeComponent(artista)}/${Uri.encodeComponent(titulo)}');
      final r = await http.get(url).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final corpo = jsonDecode(utf8.decode(r.bodyBytes));
        final letra = (corpo['lyrics'] ?? '').toString().trim();
        if (letra.length > 10) {
          return letra.replaceAll(RegExp(r'\n{3,}'), '\n\n');
        }
      }
    } catch (_) {}
    return null;
  }

  /// Retorna a letra, ou null. Faz várias tentativas com variações do nome.
  static Future<String?> buscar(String musicaBruta) async {
    final chave = musicaBruta.trim().toLowerCase();
    if (chave.isEmpty) return null;
    if (_cache.containsKey(chave)) return _cache[chave];

    final (artista, titulo) = _separar(musicaBruta);
    final aL = _limpar(artista);
    final tL = _limpar(titulo);

    final tentativas = <(String, String)>[
      if (aL.isNotEmpty) (aL, tL),
      if (aL.isNotEmpty) (tL, aL),
      if (aL.isNotEmpty) (_semAcento(aL), _semAcento(tL)),
      if (aL.isNotEmpty && artista != aL) (artista, titulo),
      if (aL.isEmpty) ('', tL),
    ];

    final vistos = <String>{};
    for (final (a, t) in tentativas) {
      final id = '$a|$t';
      if (vistos.contains(id)) continue;
      vistos.add(id);
      final letra = await _tentar(a, t);
      if (letra != null) {
        _cache[chave] = letra;
        return letra;
      }
    }

    _cache[chave] = null;
    return null;
  }
}
