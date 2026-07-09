import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class PlayerService {
  static final PlayerService instancia = PlayerService._();
  PlayerService._();

  final AudioPlayer player = AudioPlayer();
  bool _carregado = false;

  // ----- SLEEP TIMER -----
  Timer? _sleepTimer;
  final ValueNotifier<int> sleepRestante = ValueNotifier(0); // minutos; 0 = off

  void definirSleep(int minutos) {
    _sleepTimer?.cancel();
    sleepRestante.value = minutos;
    if (minutos <= 0) return;
    _sleepTimer = Timer.periodic(const Duration(minutes: 1), (t) {
      sleepRestante.value = sleepRestante.value - 1;
      if (sleepRestante.value <= 0) {
        t.cancel();
        player.stop();
        _carregado = false;
      }
    });
  }

  Future<void> carregar(String streamUrl, String nome, String logoUrl) async {
    if (_carregado) return;
    _carregado = true;
    try {
      await player.setAudioSource(
        AudioSource.uri(
          Uri.parse(streamUrl),
          tag: MediaItem(
            id: 'radio_eleva_ao_vivo',
            title: nome,
            artist: 'Ao vivo',
            artUri: logoUrl.isNotEmpty ? Uri.parse(logoUrl) : null,
          ),
        ),
      );
    } catch (_) {
      _carregado = false;
    }
  }

  Future<void> alternar() async {
    if (player.playing) {
      await player.stop();
      _carregado = false; // força reconexão ao vivo no próximo play
    } else {
      await player.play();
    }
  }

  /// Envia voto de gostei/não gostei para o Firebase (se configurado)
  Future<void> votar(String chatUrl, String tipo, String musica) async {
    if (chatUrl.isEmpty) return;
    try {
      final base = chatUrl.replaceAll(RegExp(r'/chat/?$'), '');
      await http.post(
        Uri.parse('$base/votos.json'),
        body: jsonEncode({
          'tipo': tipo,
          'musica': musica,
          'quando': DateTime.now().toIso8601String(),
        }),
      );
    } catch (_) {}
  }
}
