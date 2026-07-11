/// Moderação automática do chat: detecta linguagem ofensiva/baixo calão.
/// A lista base pode ser complementada pelo Painel Eleva (config.json).

String normalizar(String texto) {
  var t = texto.toLowerCase();
  const mapa = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ç': 'c',
    '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't',
    '@': 'a', r'$': 's',
  };
  mapa.forEach((k, v) => t = t.replaceAll(k, v));
  return t;
}

const List<String> _listaBase = [
  'porra', 'caralho', 'krl', 'merda', 'bosta', 'cacete', 'caraio',
  'puta', 'puto', 'putaria', 'pqp', 'fdp', 'vsf', 'vtnc',
  'foda', 'foder', 'fodase', 'fude', 'fudido', 'fudida',
  'buceta', 'xereca', 'xoxota', 'cu', 'cuzao', 'cuzinho',
  'rola', 'pinto', 'piroca', 'punheta', 'siririca',
  'viado', 'boiola', 'baitola', 'sapatao',
  'vagabunda', 'vagabundo', 'piranha', 'corno', 'corna',
  'arrombado', 'arrombada', 'desgracado', 'desgracada',
  'babaca', 'otario', 'otaria', 'imbecil', 'retardado', 'retardada',
  'macaco', 'macaca', 'crioulo',
];

/// Retorna true se o texto contém palavra bloqueada (lista base + extras do painel)
bool contemPalavraOfensiva(String texto, List<String> extras) {
  final bloqueadas = <String>{
    ..._listaBase,
    ...extras.map((e) => normalizar(e.trim())).where((e) => e.isNotEmpty),
  };
  final tokens = normalizar(texto)
      .split(RegExp(r'[^a-z]+'))
      .where((t) => t.isNotEmpty);
  for (final t in tokens) {
    if (bloqueadas.contains(t)) return true;
  }
  // pega tentativas de disfarce com espaços/pontos (ex.: p.o.r.r.a)
  final grudado = normalizar(texto).replaceAll(RegExp(r'[^a-z]'), '');
  for (final p in bloqueadas) {
    if (p.length >= 4 && grudado.contains(p)) return true;
  }
  return false;
}
