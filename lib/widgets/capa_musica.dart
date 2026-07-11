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
  CapaMusica({super.key, this.reserva, this.tamanho = 170});
  @override
  State<CapaMusica> createState() => _CapaMusicaState();
}

class _CapaMusicaState extends State<CapaMusica> {
  StreamSubscription? _sub;
  Timer? _debounce;
  String _ultimaBusca = '';
  String? _capaUrl;

  @override
  void initState() {
    super.initState();
    _sub = PlayerService.instancia.player.icyMetadataStream.listen((icy) {
      final titulo = icy?.info?.title?.trim() ?? '';
      if (titulo.isEmpty || titulo == _ultimaBusca) return;
      _ultimaBusca = titulo;
      _debounce?.cancel();
      _debounce = Timer(Duration(milliseconds: 900), () => _buscar(titulo));
    });
  }

  Future<void> _buscar(String titulo) async {
    try {
      final termo = Uri.encodeComponent(
          titulo.replaceAll(RegExp(r'[\[\](){}]'), ' ').trim());
      final r = await http
          .get(Uri.parse(
              'https://itunes.apple.com/search?term=$termo&country=br&media=music&limit=1'))
          .timeout(Duration(seconds: 8));
      String? url;
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if ((d['resultCount'] ?? 0) > 0) {
          url = (d['results'][0]['artworkUrl100'] ?? '')
              .toString()
              .replaceAll('100x100', '400x400');
          if (url.isEmpty) url = null;
        }
      }
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
        child: url == null
            ? Container(
                color: CoresEleva.azulMedio,
                padding: EdgeInsets.all(24),
                child: Image.asset('assets/logo.png', fit: BoxFit.contain),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: CoresEleva.azulMedio,
                  padding: EdgeInsets.all(24),
                  child:
                      Image.asset('assets/logo.png', fit: BoxFit.contain),
                ),
              ),
      ),
    );
  }
}
