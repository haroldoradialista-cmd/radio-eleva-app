import 'dart:convert';
import 'package:http/http.dart' as http;

/// Busca a letra de uma música pelo nome que vem nos metadados do stream
/// (formato "Artista - Título"). Usa a API pública e gratuita lyrics.ovh,
/// que não exige cadastro nem chave.
class LetraService {
  /// Guarda as letras já buscadas nesta sessão (evita repetir a busca)
  static final Map<String, String?> _cache = {};

  /// Separa "Artista - Título" em (artista, titulo).
  /// Se não houver o hífen, usa tudo como título e artista vazio.
  static (String, String) _separar(String bruto) {
    final t = bruto.trim();
    final separadores = [' - ', ' – ', ' — '];
    for (final s in separadores) {
      final i = t.indexOf(s);
      if (i > 0) {
        return (t.substring(0, i).trim(), t.substring(i + s.length).trim());
      }
    }
    return ('', t);
  }

  /// Retorna a letra, ou null se não encontrar.
  static Future<String?> buscar(String musicaBruta) async {
    final chave = musicaBruta.trim().toLowerCase();
    if (chave.isEmpty) return null;
    if (_cache.containsKey(chave)) return _cache[chave];

    final (artista, titulo) = _separar(musicaBruta);
    if (titulo.isEmpty) {
      _cache[chave] = null;
      return null;
    }

    // tenta primeiro "artista/titulo"; se falhar e não houver artista,
    // tenta uma busca só com o título trocando a ordem não ajuda muito,
    // então mantemos simples e robusto.
    final tentativas = <(String, String)>[
      if (artista.isNotEmpty) (artista, titulo),
      // fallback: alguns streams mandam "Título - Artista"
      if (artista.isNotEmpty) (titulo, artista),
    ];

    for (final (a, t) in tentativas) {
      try {
        final url = Uri.parse(
            'https://api.lyrics.ovh/v1/${Uri.encodeComponent(a)}/${Uri.encodeComponent(t)}');
        final r = await http.get(url).timeout(const Duration(seconds: 8));
        if (r.statusCode == 200) {
          final corpo = jsonDecode(utf8.decode(r.bodyBytes));
          final letra = (corpo['lyrics'] ?? '').toString().trim();
          if (letra.length > 10) {
            // limpa quebras de linha exageradas
            final limpa = letra.replaceAll(RegExp(r'\n{3,}'), '\n\n');
            _cache[chave] = limpa;
            return limpa;
          }
        }
      } catch (_) {
        // tenta a próxima
      }
    }

    _cache[chave] = null;
    return null;
  }
}
