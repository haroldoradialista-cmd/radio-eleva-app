import 'dart:ui' show DartPluginRegistrant;
import 'package:flutter/widgets.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'config_service.dart';
import 'player_service.dart';

/// Despertador da Rádio Eleva: acorda o ouvinte com a rádio tocando,
/// mesmo com o app fechado (alarme exato do Android + tela cheia).
class DespertadorService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const int idAlarme = 1001;
  static const _idAlarme = idAlarme;
  static bool _pronto = false;

  static Future<void> iniciar() async {
    if (_pronto) return;
    try {
      try {
        await AndroidAlarmManager.initialize();
      } catch (_) {}
      tzdata.initializeTimeZones();
      try {
        final nome = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(nome));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
      }
      await _plugin.initialize(
        InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (_) => tocarRadio(),
      );
      // Se o app foi ABERTO pelo alarme (app estava fechado),
      // o primeiro play nasce com fade in
      try {
        final det = await _plugin.getNotificationAppLaunchDetails();
        if (det?.didNotificationLaunchApp == true &&
            det?.notificationResponse?.id == _idAlarme) {
          PlayerService.instancia.marcarFadeInParaProximoPlay();
        }
      } catch (_) {}
      _pronto = true;
    } catch (_) {}
  }

  /// Liga a rádio (usado quando o alarme dispara com o app aberto/na memória)
  static Future<void> tocarRadio() async {
    try {
      var cfg = ConfigService.instancia.config.value;
      if (cfg.streamUrl.isEmpty) {
        await ConfigService.instancia.carregar();
        cfg = ConfigService.instancia.config.value;
      }
      if (cfg.streamUrl.isEmpty) return;
      await PlayerService.instancia
          .carregar(cfg.streamUrl, cfg.nome, cfg.logoUrl);
      await PlayerService.instancia.player.play();
      PlayerService.instancia.iniciarFadeIn(); // acorda de leve
    } catch (_) {}
  }

  static Future<void> pedirPermissoes() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
      // Android 14+: permissão especial para acender a tela e abrir o app
      try {
        await android?.requestFullScreenIntentPermission();
      } catch (_) {}
    } catch (_) {}
  }

  static NotificationDetails get _detalhes => NotificationDetails(
        android: AndroidNotificationDetails(
          'despertador',
          'Despertador',
          channelDescription: 'Alarme que desperta você com a Rádio Eleva',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          playSound: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      );

  static Future<void> _agendar(tz.TZDateTime quando,
      {DateTimeComponents? repete}) async {
    Future<void> tentar(AndroidScheduleMode modo) {
      return _plugin.zonedSchedule(
        _idAlarme,
        '⏰ Bom dia! Hora de despertar',
        'A Rádio Eleva já está no ar para você. Toque para ouvir! 🎶',
        quando,
        _detalhes,
        androidScheduleMode: modo,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: repete,
      );
    }

    // Limpa o alarme anterior antes de reagendar (evita conflito no ATUALIZAR)
    try {
      await _plugin.cancel(_idAlarme);
    } catch (_) {}
    try {
      // Plano A: alarme exato (precisa da permissão "Alarmes e lembretes")
      await tentar(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (_) {
      try {
        // Plano B: alarme comum (dispara com pequena tolerância)
        await tentar(AndroidScheduleMode.inexactAllowWhileIdle);
      } catch (_) {
        // Plano C: modo mais simples possível
        await tentar(AndroidScheduleMode.inexact);
      }
    }
  }

  /// Grava o alarme AUTÔNOMO: na hora, o Android acorda o motor do app
  /// em segundo plano e a rádio toca sozinha, sem toque do ouvinte.
  static Future<void> _agendarAutonomo(DateTime quando) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cfg = ConfigService.instancia.config.value;
      if (cfg.streamUrl.isNotEmpty) {
        await prefs.setString('desp_stream', cfg.streamUrl);
      }
      await AndroidAlarmManager.oneShotAt(
        quando,
        idAlarme,
        despertadorAutonomo,
        exact: true,
        wakeup: true,
        allowWhileIdle: true,
        alarmClock: true,
        rescheduleOnReboot: true,
      );
    } catch (_) {}
  }

  /// Alarme único em data e hora específicas
  static Future<void> agendarUnico(DateTime quando) async {
    await iniciar();
    await _agendar(tz.TZDateTime.from(quando, tz.local));
    await _agendarAutonomo(quando);
  }

  /// Alarme diário no mesmo horário (TODO DIA)
  static Future<void> agendarDiario(int hora, int minuto) async {
    await iniciar();
    final agora = tz.TZDateTime.now(tz.local);
    var primeiro = tz.TZDateTime(
        tz.local, agora.year, agora.month, agora.day, hora, minuto);
    if (primeiro.isBefore(agora)) {
      primeiro = primeiro.add(Duration(days: 1));
    }
    await _agendar(primeiro, repete: DateTimeComponents.time);
    await _agendarAutonomo(DateTime(primeiro.year, primeiro.month,
        primeiro.day, primeiro.hour, primeiro.minute));
  }

  static Future<void> cancelar() async {
    await iniciar();
    await _plugin.cancel(_idAlarme);
    try {
      await AndroidAlarmManager.cancel(idAlarme);
    } catch (_) {}
  }
}

/// ================================================================
/// MOTOR AUTÔNOMO DO DESPERTADOR
/// Executado pelo Android em segundo plano na hora exata do alarme,
/// mesmo com o app fechado e a tela apagada. Liga a rádio sozinho.
/// ================================================================
@pragma('vm:entry-point')
Future<void> despertadorAutonomo() async {
  AudioPlayer? player;
  try {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();

    // Se for TODO DIA, já deixa gravado o alarme de amanhã
    if ((prefs.getString('desp_tipo') ?? '') == 'diario') {
      final h = prefs.getInt('desp_hora') ?? 7;
      final m = prefs.getInt('desp_min') ?? 0;
      final agora = DateTime.now();
      final amanha = DateTime(agora.year, agora.month, agora.day, h, m)
          .add(Duration(days: 1));
      try {
        await AndroidAlarmManager.oneShotAt(
          amanha,
          DespertadorService.idAlarme,
          despertadorAutonomo,
          exact: true,
          wakeup: true,
          allowWhileIdle: true,
          alarmClock: true,
          rescheduleOnReboot: true,
        );
      } catch (_) {}
    }

    // Liga a rádio com fade in (nasce baixinho e cresce em 30s)
    final url = prefs.getString('desp_stream') ??
        'https://sv16.hdradios.net:8516/stream';
    player = AudioPlayer();
    await player.setVolume(0.03);
    await player.setAudioSource(AudioSource.uri(Uri.parse(url)));
    player.play();
    for (var i = 1; i <= 30; i++) {
      await Future.delayed(Duration(seconds: 1));
      try {
        await player.setVolume((i / 30).clamp(0.03, 1.0).toDouble());
      } catch (_) {}
    }

    // Mantém a rádio despertando por 20 minutos
    // (se o ouvinte abrir o app nesse meio-tempo, o player principal assume)
    await Future.delayed(Duration(minutes: 20));
    await player.stop();
    await player.dispose();
  } catch (_) {
    try {
      await player?.dispose();
    } catch (_) {}
  }
}
