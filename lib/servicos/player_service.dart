import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class PlayerService {
  static final PlayerService instancia = PlayerService._();
  PlayerService._();

  // Buffer de partida reduzido: o play começa a tocar muito mais rápido
  final AudioPlayer player = AudioPlayer(
    audioLoadConfiguration: AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        minBufferDuration: Duration(seconds: 8),
        maxBufferDuration: Duration(seconds: 30),
        bufferForPlaybackDuration: Duration(milliseconds: 700),
        bufferForPlaybackAfterRebufferDuration: Duration(seconds: 2),
      ),
    ),
  );
  bool _carregado = false;

  // ----- SLEEP TIMER -----
  Timer? _sleepTimer;
  final ValueNotifier<int> sleepRestante = ValueNotifier(0); // minutos; 0 = off

  /// Segundos restantes do sleep timer (0 = desligado)
  final ValueNotifier<int> sleepSegundos = ValueNotifier(0);

  Timer? _fadeInTimer;

  /// Sobe o volume em rampa suave (usado pelo despertador)
  void iniciarFadeIn({int duracaoSegundos = 30}) {
    _fadeInTimer?.cancel();
    player.setVolume(0.03);
    var passo = 0;
    _fadeInTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      passo++;
      final v = (passo / duracaoSegundos).clamp(0.03, 1.0);
      player.setVolume(v.toDouble());
      if (passo >= duracaoSegundos) {
        t.cancel();
        player.setVolume(1.0);
      }
    });
  }

  /// Marca que o PRÓXIMO play deve nascer com fade in
  /// (chamado quando o app é aberto pelo alarme do despertador)
  void marcarFadeInParaProximoPlay() {
    player.setVolume(0.03);
    player.playingStream
        .firstWhere((tocando) => tocando)
        .then((_) => iniciarFadeIn());
  }

  void definirSleep(int minutos) {
    _sleepTimer?.cancel();
    if (minutos <= 0) {
      sleepRestante.value = 0;
      sleepSegundos.value = 0;
      player.setVolume(1.0);
      return;
    }
    sleepRestante.value = minutos;
    sleepSegundos.value = minutos * 60;
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      sleepSegundos.value = sleepSegundos.value - 1;
      sleepRestante.value = (sleepSegundos.value / 60).ceil();
      // Fade out: nos últimos 15 segundos o volume desce suavemente
      if (sleepSegundos.value > 0 && sleepSegundos.value <= 15) {
        player.setVolume(sleepSegundos.value / 15);
      }
      if (sleepSegundos.value <= 0) {
        t.cancel();
        player.stop();
        player.setVolume(1.0); // volume restaurado para a próxima vez
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
