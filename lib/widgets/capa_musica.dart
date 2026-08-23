import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import '../servicos/letra_service.dart';
import '../servicos/player_service.dart';
import '../servicos/correcoes_service.dart';
import '../tema.dart';

/// Capa quadrada da música que está tocando (busca automática pela
/// identificação enviada pelo streaming). Some quando não encontra.
/// Memoria de capas reprovadas pelos ouvintes: a cada aviso de "capa
/// errada", o app pula a fonte que errou e tenta a proxima na vez seguinte.
class CapaRejeicao {
  static Future<int> quantas(String musica) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('capa_rej_${musica.trim().toLowerCase()}') ?? 0;
    } catch (_) {}
    return 0;
  }

  static Future<void> marcarErrada(String musica) async {
    final k = 'capa_rej_${musica.trim().toLowerCase()}';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(k, (prefs.getInt(k) ?? 0) + 1);
    } catch (_) {}
  }
}

class CapaMusica extends StatefulWidget {
  final String? reserva; // foto do programa no ar
  final double tamanho;
  CapaMusica({super.key, this.reserva, this.tamanho = 230});
  @override
  State<CapaMusica> createState() => _CapaMusicaState();
}

class _CapaMusicaState extends State<CapaMusica> {
  StreamSubscription? _sub;
  Timer? _debounce;
  String _ultimaBusca = '';
  String? _capaUrl;
  // imagem ENVIADA pelo painel, ja convertida UMA vez.
  // Sem isto, a conversao acontecia a cada redesenho da tela e a capa
  // ficava PISCANDO enquanto a musica tocava.
  Uint8List? _capaBytes;
  String _musica = '';
  String _interprete = '';

  @override
  void initState() {
    super.initState();
    _sub = PlayerService.instancia.player.icyMetadataStream.listen((icy) {
      final titulo = icy?.info?.title?.trim() ?? '';
      if (titulo.isEmpty || titulo == _ultimaBusca) return;
      _ultimaBusca = titulo;
      // O padrão do streaming é "Intérprete - Música"
      final partes = titulo.split(' - ');
      if (mounted) {
        setState(() {
          if (partes.length >= 2) {
            _interprete = partes.first.trim();
            _musica = partes.sublist(1).join(' - ').trim();
          } else {
            _interprete = '';
            _musica = titulo.trim();
          }
        });
      }
      _debounce?.cancel();
      _debounce = Timer(Duration(milliseconds: 900), () => _buscar(titulo));
    });
  }

  Future<void> _buscar(String bruto) async {
    try {
      // separa "Artista - Título"
      String artista = '', titulo = bruto.trim();
      for (final sep in [' - ', ' – ', ' — ', ' _ ']) {
        final idx = bruto.indexOf(sep);
        if (idx > 0) {
          artista = bruto.substring(0, idx).trim();
          titulo = bruto.substring(idx + sep.length).trim();
          break;
        }
      }
      final artL = _limparNome(artista);
      final titL = _limparNome(titulo);
      if (titL.isEmpty) {
        _aplicarCapa(null);
        return;
      }

      // Estratégias em cascata (para na primeira que validar):
      //  1) artista+título no Brasil   2) artista+título nos EUA
      //  3) título+artista (invertido) 4) só o título (validação forte)
      // MUITAS formas de procurar a mesma capa (o catalogo pode guardar o
      // nome sem acento, com o artista abreviado, sem a dupla, etc.)
      final artCurto = artL.split(' ').take(2).join(' ');
      final artSemDupla = artL.split(RegExp(r'\s+(?:e|&|com)\s+')).first;
      final titCurto = titL.split(RegExp(r'[-:–]')).first.trim();
      final tentativas = <Map<String, dynamic>>[
        if (artL.isNotEmpty) {'termo': '$artL $titL', 'pais': 'br', 'soTitulo': false},
        if (artL.isNotEmpty) {'termo': '$artL $titL', 'pais': 'us', 'soTitulo': false},
        if (artL.isNotEmpty) {'termo': '$titL $artL', 'pais': 'br', 'soTitulo': false},
        if (artL.isNotEmpty && artCurto != artL)
          {'termo': '$artCurto $titL', 'pais': 'br', 'soTitulo': false},
        if (artL.isNotEmpty && artSemDupla != artL)
          {'termo': '$artSemDupla $titL', 'pais': 'br', 'soTitulo': false},
        if (artL.isNotEmpty && titCurto.isNotEmpty && titCurto != titL)
          {'termo': '$artL $titCurto', 'pais': 'br', 'soTitulo': false},
        // ATENCAO: buscar SO pelo titulo trazia capas de outro genero
        // (ex.: uma musica sertaneja com o mesmo nome de um louvor).
        // Por isso, so aceitamos busca por titulo quando NAO sabemos o
        // artista — se sabemos, o artista TEM que conferir.
        if (artL.isEmpty) {'termo': titL, 'pais': 'br', 'soTitulo': true},
        if (artL.isEmpty) {'termo': titL, 'pais': 'us', 'soTitulo': true},
      ];

      // 0) BASE DA RADIO: se a capa foi corrigida no painel, e ela que vale.
      //    Busca TOLERANTE (com/sem acento, "ao vivo", invertida) para a
      //    capa nao "sumir" quando a transmissao muda o nome da musica.
      String? url = CorrecoesService.capaDe(bruto);
      if (url == null) {
        url = await _daRadio(artL, titL);
      }
      // 0b) capa ja encontrada antes neste aparelho (nunca some)
      url ??= await CorrecoesService.lembrancaCapa(bruto);
      if (url != null) {
        _aplicarCapa(url);
        return;
      }
      // fontes ja reprovadas pelos ouvintes nesta musica: pula e tenta outra
      var pular = await CapaRejeicao.quantas('$artL $titL');
      for (final t in tentativas) {
        url = await _tentarItunes(
            t['termo'] as String, t['pais'] as String, artL, titL,
            soTitulo: t['soTitulo'] as bool);
        if (url != null) {
          if (pular > 0) { pular--; url = null; } else { break; }
        }
      }
      // se o iTunes não achou, tenta o Deezer com as mesmas estratégias
      if (url == null) {
        for (final t in tentativas) {
          url = await _tentarDeezer(
              t['termo'] as String, artL, titL,
              soTitulo: t['soTitulo'] as bool);
          if (url != null) {
            if (pular > 0) { pular--; url = null; } else { break; }
          }
        }
      }
      // se nada validou, NÃO usa capa aleatória — deixa a reserva/logo.
      // Se achou, GUARDA no aparelho para nunca mais sumir.
      if (url != null) CorrecoesService.lembrar(bruto, capa: url);
      _aplicarCapa(url);
    } catch (_) {
      _aplicarCapa(null);
    }
  }

  /// Limpa nomes: tira "(ao vivo)", "feat.", "playback", "clipe oficial" etc.
  String _limparNome(String s) {
    var r = ' $s ';
    r = r.replaceAll(RegExp(r'[\[\](){}].*?[\[\](){}]'), ' '); // (ao vivo), [clipe]
    r = r.replaceAll(
        RegExp(
            r'\b(feat|ft|part|participacao|participação|com)\.?\s.*$',
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

  String _semAcento(String s) {
    const de = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
    const pa = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
    var x = s.toLowerCase();
    for (var i = 0; i < de.length; i++) {
      x = x.replaceAll(de[i].toLowerCase(), pa[i].toLowerCase());
    }
    return x.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Faz uma busca no iTunes e devolve a URL da capa se um resultado validar.
  Future<String?> _tentarItunes(
      String termo, String pais, String artL, String titL,
      {required bool soTitulo}) async {
    try {
      final url = Uri.parse(
          'https://itunes.apple.com/search?term=${Uri.encodeComponent(termo)}&country=$pais&media=music&limit=8');
      final r = await http.get(url).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final d = jsonDecode(r.body);
      final results = (d['results'] ?? []) as List;
      final aBusca = _semAcento(artL);
      final tBusca = _semAcento(titL);
      for (final item in results) {
        final aResp = _semAcento((item['artistName'] ?? '').toString());
        final tResp = _semAcento((item['trackName'] ?? '').toString());
        final tituloOk = tResp == tBusca ||
            tResp.contains(tBusca) ||
            tBusca.contains(tResp);
        if (!tituloOk) continue;
        if (soTitulo) {
          // sem artista na busca: exige título forte para não pegar capa errada
          final forte = tResp == tBusca ||
              (tBusca.length >= 5 &&
                  (tResp.contains(tBusca) || tBusca.contains(tResp)));
          if (!forte) continue;
        } else {
          final artistaOk = aBusca.isEmpty ||
              aResp.contains(aBusca) ||
              aBusca.contains(aResp) ||
              // artista pode vir invertido/parcial: aceita 1ª palavra em comum
              _primeiraPalavraComum(aResp, aBusca);
          if (!artistaOk) continue;
        }
        final u = (item['artworkUrl100'] ?? '')
            .toString()
            .replaceAll('100x100', '600x600');
        if (u.isNotEmpty) return u;
      }
    } catch (_) {}
    return null;
  }

  bool _primeiraPalavraComum(String a, String b) {
    final pa = a.split(' ').where((w) => w.length >= 3).toSet();
    final pb = b.split(' ').where((w) => w.length >= 3).toSet();
    return pa.intersection(pb).isNotEmpty;
  }

  /// Define a capa atual e ja converte a imagem enviada UMA unica vez.
  void _aplicarCapa(String? url) {
    final bytes = (url == null) ? null : _bytesDaCapa(url);
    if (!mounted) return;
    // evita redesenhar a toa quando nada mudou (o que causava o piscar)
    if (_capaUrl == url && _capaBytes == bytes) return;
    setState(() {
      _capaUrl = url;
      _capaBytes = bytes;
    });
  }

  /// Converte a capa ENVIADA pelo painel (texto) em imagem, com seguranca.
  /// Devolve null quando nao e uma imagem enviada (ou se vier corrompida),
  /// para o app cair no caminho normal em vez de quebrar a tela.
  Uint8List? _bytesDaCapa(String valor) {
    if (!valor.startsWith('data:image')) return null;
    try {
      var b64 = valor.split(',').last;
      // tira espacos e quebras de linha que estragam a decodificacao
      b64 = b64.replaceAll(RegExp(r'\s'), '');
      // completa o preenchimento final quando vier faltando
      final resto = b64.length % 4;
      if (resto > 0) b64 = b64 + ('=' * (4 - resto));
      final bytes = base64Decode(b64);
      if (bytes.isEmpty) return null;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Procura a capa na BASE DA PROPRIA RADIO (correcoes feitas no painel).
  /// Tem prioridade sobre iTunes e Deezer.
  Future<String?> _daRadio(String artista, String titulo) async {
    final base = LetraService.baseRtdb;
    if (base.isEmpty) return null;
    try {
      final id = '${artista}_$titulo'
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      final r = await http
          .get(Uri.parse('$base/correcoes/$id.json'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body);
        if (j is Map) {
          final capa = (j['capa'] ?? '').toString();
          // aceita link da internet OU imagem enviada pelo painel
          // (guardada como texto no formato data:image/...;base64,...)
          if (capa.startsWith('http') || capa.startsWith('data:image')) {
            return capa;
          }
          // tolerancia: se veio o base64 puro (sem o prefixo), monta o prefixo
          if (capa.length > 200 && !capa.contains(' ')) {
            return 'data:image/jpeg;base64,$capa';
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Busca a capa no Deezer (API pública, sem chave). Boa cobertura,
  /// inclusive de gospel brasileiro que às vezes falta no iTunes.
  Future<String?> _tentarDeezer(String termo, String artL, String titL,
      {required bool soTitulo}) async {
    try {
      final url = Uri.parse(
          'https://api.deezer.com/search?q=${Uri.encodeComponent(termo)}&limit=8');
      final r = await http.get(url).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final d = jsonDecode(r.body);
      final results = (d['data'] ?? []) as List;
      final aBusca = _semAcento(artL);
      final tBusca = _semAcento(titL);
      for (final item in results) {
        final aResp =
            _semAcento((item['artist']?['name'] ?? '').toString());
        final tResp = _semAcento((item['title'] ?? '').toString());
        final tituloOk = tResp == tBusca ||
            tResp.contains(tBusca) ||
            tBusca.contains(tResp);
        if (!tituloOk) continue;
        if (soTitulo) {
          final forte = tResp == tBusca ||
              (tBusca.length >= 5 &&
                  (tResp.contains(tBusca) || tBusca.contains(tResp)));
          if (!forte) continue;
        } else {
          final artistaOk = aBusca.isEmpty ||
              aResp.contains(aBusca) ||
              aBusca.contains(aResp) ||
              _primeiraPalavraComum(aResp, aBusca);
          if (!artistaOk) continue;
        }
        // capa do álbum em alta resolução
        final capa = (item['album']?['cover_xl'] ??
                item['album']?['cover_big'] ??
                item['album']?['cover_medium'] ??
                '')
            .toString();
        if (capa.isNotEmpty) return capa;
      }
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urlReserva =
        (widget.reserva ?? '').isNotEmpty ? widget.reserva : null;
    final url = _capaUrl ?? urlReserva;
    return Container(
      width: widget.tamanho,
      height: widget.tamanho,
      padding: const EdgeInsets.all(6), // espessura da moldura
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        // moldura sutil com degradê dourado, como um porta-retrato fino
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF4D879).withOpacity(0.95), // dourado claro
            const Color(0xFFB8860B).withOpacity(0.85), // dourado escuro
            const Color(0xFFF4D879).withOpacity(0.95), // dourado claro
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: CoresEleva.dourado.withOpacity(0.25),
            blurRadius: 12,
            spreadRadius: 0.5,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(CoresEleva.escuro ? 0.4 : 0.15),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          fit: StackFit.expand,
          children: [
            url == null
                ? Container(
                    color: CoresEleva.azulMedio,
                    padding: EdgeInsets.all(24),
                    child:
                        Image.asset('assets/logo.png', fit: BoxFit.contain),
                  )
                : (_capaBytes != null
                    // capa ENVIADA pelo painel (ja convertida uma vez)
                    ? Image.memory(
                        _capaBytes!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => Container(
                          color: CoresEleva.azulMedio,
                          padding: EdgeInsets.all(24),
                          child: Image.asset('assets/logo.png',
                              fit: BoxFit.contain),
                        ),
                      )
                    // capa vinda de um link da internet
                    : Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: CoresEleva.azulMedio,
                          padding: EdgeInsets.all(24),
                          child: Image.asset('assets/logo.png',
                              fit: BoxFit.contain),
                        ),
                      )),
          ],
        ),
      ),
    );
  }
}
