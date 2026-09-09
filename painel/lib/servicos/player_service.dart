import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  void iniciarFadeIn({int duracaoSegundos = 60}) {
    _fadeInTimer?.cancel();
    player.setVolume(0.02);
    var passo = 0;
    final totalPassos = duracaoSegundos * 4; // passos de 250ms
    _fadeInTimer = Timer.periodic(const Duration(milliseconds: 250), (t) {
      passo++;
      final fracao = (passo / totalPassos).clamp(0.0, 1.0);
      final curva = fracao * fracao; // sobe bem devagar no início
      final v = (0.02 + (1.0 - 0.02) * curva).clamp(0.02, 1.0);
      player.setVolume(v.toDouble());
      if (passo >= totalPassos) {
        t.cancel();
        player.setVolume(1.0);
      }
    });
  }

  /// Marca que o PRÓXIMO play deve nascer com fade in
  /// (chamado quando o app é aberto pelo alarme do despertador)
  void marcarFadeInParaProximoPlay() {
    player.setVolume(0.02);
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
    player.setVolume(1.0); // comeca no volume cheio
    final fimEm = DateTime.now().add(Duration(minutes: minutos));
    // Fade-out suave nos ultimos 2 minutos (ou na metade do tempo, se o
    // ouvinte escolher um tempo curto). O som vai baixando devagarinho ate
    // o silencio, para ele adormecer sem susto.
    final totalSegundos = minutos * 60;
    final fadeSegundos = totalSegundos >= 240 ? 120 : (totalSegundos ~/ 2);
    _sleepTimer = Timer.periodic(const Duration(milliseconds: 150), (t) {
      final restanteMs = fimEm.difference(DateTime.now()).inMilliseconds;
      final segs = (restanteMs / 1000).ceil();
      sleepSegundos.value = segs > 0 ? segs : 0;
      sleepRestante.value = (sleepSegundos.value / 60).ceil();
      // Curva suave: o som vai sumindo e os ultimos segundos sao um
      // sussurro ate o silencio completo.
      if (restanteMs <= fadeSegundos * 1000) {
        final f = (restanteMs / (fadeSegundos * 1000)).clamp(0.0, 1.0);
        player.setVolume((f * f).toDouble());
      }
      if (restanteMs <= 0) {
        t.cancel();
        sleepRestante.value = 0;
        sleepSegundos.value = 0;
        _encerrarParaDormir();
      }
    });
  }

  /// Fim do sleep timer: silencia, para a radio e FECHA o aplicativo.
  /// Isso e proposital — se o app ficasse aberto a noite toda, no dia
  /// seguinte (depois do despertador) o ouvinte poderia apertar o play da
  /// sessao antiga e ouvir dois audios ao mesmo tempo.
  Future<void> _encerrarParaDormir() async {
    try {
      await player.setVolume(0.0); // silencio total antes de parar
      await player.stop();
      _carregado = false;
      await player.setVolume(1.0); // deixa pronto para a proxima vez
    } catch (_) {}
    // da um instante para o som e a notificacao encerrarem de verdade
    await Future.delayed(const Duration(milliseconds: 600));
    try {
      await SystemNavigator.pop(); // fecha o app pelo caminho normal
    } catch (_) {}
    // ATENCAO: NAO usar exit(0) aqui. Matar o app a forca com o servico de
    // audio ainda ativo deixava a sessao de som presa no Android, e nas
    // aberturas seguintes a radio nao tocava mais.
  }

  Future<void> carregar(String streamUrl, String nome, String logoUrl) async {
    if (_carregado) return;
    _carregado = true;
    // Tenta ate 3 vezes: a primeira conexao pode falhar por internet lenta
    // ou porque o servico de audio ainda esta subindo. Sem isto, uma falha
    // passageira deixava a radio muda ate o ouvinte reabrir o app.
    for (var tentativa = 1; tentativa <= 3; tentativa++) {
      try {
        await player.setVolume(1.0); // garante que nao ficou mudo
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
        return; // conseguiu
      } catch (_) {
        _carregado = false;
        if (tentativa < 3) {
          await Future.delayed(Duration(seconds: tentativa * 2));
          _carregado = true; // segue tentando
        }
      }
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
