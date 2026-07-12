import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'config_service.dart';
import 'player_service.dart';

/// Despertador da Rádio Eleva: acorda o ouvinte com a rádio tocando,
/// mesmo com o app fechado (alarme exato do Android + tela cheia).
class DespertadorService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _idAlarme = 1001;
  static bool _pronto = false;

  static Future<void> iniciar() async {
    if (_pronto) return;
    try {
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
    } catch (_) {}
  }

  static Future<void> pedirPermissoes() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
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

  /// Alarme único em data e hora específicas
  static Future<void> agendarUnico(DateTime quando) async {
    await iniciar();
    await _plugin.zonedSchedule(
      _idAlarme,
      '⏰ Bom dia! Hora de despertar',
      'A Rádio Eleva já está no ar para você. Toque para ouvir! 🎶',
      tz.TZDateTime.from(quando, tz.local),
      _detalhes,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
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
    await _plugin.zonedSchedule(
      _idAlarme,
      '⏰ Bom dia! Hora de despertar',
      'A Rádio Eleva já está no ar para você. Toque para ouvir! 🎶',
      primeiro,
      _detalhes,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelar() async {
    await iniciar();
    await _plugin.cancel(_idAlarme);
  }
}
