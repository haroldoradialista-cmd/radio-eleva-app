import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import '../servicos/player_service.dart';
import '../tema.dart';

/// Capa quadrada da música que está tocando (busca automática pela
/// identificação enviada pelo streaming). Some quando não encontra.
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
      for (final sep in [' - ', ' – ', ' — ']) {
        final idx = bruto.indexOf(sep);
        if (idx > 0) {
          artista = bruto.substring(0, idx).trim();
          titulo = bruto.substring(idx + sep.length).trim();
          break;
        }
      }
      // limpa "(ao vivo)", "[clipe]" etc.
      String limpar(String s) => s
          .replaceAll(RegExp(r'[\[\](){}].*?[\[\](){}]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final artL = limpar(artista);
      final titL = limpar(titulo);

      // busca pelo conjunto artista+título (bem mais preciso que só o título)
      final termo = Uri.encodeComponent(
          (artL.isNotEmpty ? '$artL $titL' : titL));
      final r = await http
          .get(Uri.parse(
              'https://itunes.apple.com/search?term=$termo&country=br&media=music&limit=5'))
          .timeout(Duration(seconds: 8));
      String? url;
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        final results = (d['results'] ?? []) as List;
        String semAcento(String s) {
          const de = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
          const pa = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
          var x = s.toLowerCase();
          for (var i = 0; i < de.length; i++) {
            x = x.replaceAll(de[i].toLowerCase(), pa[i].toLowerCase());
          }
          return x.replaceAll(RegExp(r'[^a-z0-9 ]'), '').trim();
        }

        for (final item in results) {
          final aResp = semAcento((item['artistName'] ?? '').toString());
          final tResp = semAcento((item['trackName'] ?? '').toString());
          final aBusca = semAcento(artL);
          final tBusca = semAcento(titL);
          // valida: o TÍTULO precisa bater, e o artista bate (ou não temos artista)
          final tituloOk = tResp.contains(tBusca) || tBusca.contains(tResp);
          final artistaOk = aBusca.isEmpty ||
              aResp.contains(aBusca) ||
              aBusca.contains(aResp);
          if (tituloOk && artistaOk) {
            final u = (item['artworkUrl100'] ?? '')
                .toString()
                .replaceAll('100x100', '600x600');
            if (u.isNotEmpty) {
              url = u;
              break;
            }
          }
        }
      }
      // se nada foi validado, NÃO usa capa aleatória — deixa a reserva/logo
      if (mounted) setState(() => _capaUrl = url);
    } catch (_) {
      if (mounted) setState(() => _capaUrl = null);
    }
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CoresEleva.dourado.withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(CoresEleva.escuro ? 0.4 : 0.15),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
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
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: CoresEleva.azulMedio,
                      padding: EdgeInsets.all(24),
                      child: Image.asset('assets/logo.png',
                          fit: BoxFit.contain),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
