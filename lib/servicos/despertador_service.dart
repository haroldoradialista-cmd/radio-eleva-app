import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config_service.dart';

/// Despertador da Rádio Eleva — versão NATIVA.
/// O alarme é gravado no relógio do Android (setAlarmClock) e, na hora,
/// um serviço nativo liga a rádio sozinho: sem app aberto, sem motor
/// Flutter, sobrevivendo ao "Fechar todos os aplicativos".
class DespertadorService {
  static const _canal = MethodChannel('br.com.radioeleva/despertador');
  static final _notif = FlutterLocalNotificationsPlugin();
  static bool _pronto = false;

  static Future<void> iniciar() async {
    if (!_pronto) {
      try {
        await _notif.initialize(InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher')));
        _pronto = true;
      } catch (_) {}
    }
    // Handoff: se o despertador nativo estiver tocando quando o app abre,
    // ele para na hora e o player principal assume — sem áudio duplo.
    try {
      await _canal.invokeMethod('parar');
    } catch (_) {}
  }

  static Future<void> pedirPermissoes() async {
    try {
      final android = _notif.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
    } catch (_) {}
  }

  static Future<void> _gravarAlarme(DateTime quando, bool diario) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cfg = ConfigService.instancia.config.value;
      if (cfg.streamUrl.isNotEmpty) {
        await prefs.setString('desp_stream', cfg.streamUrl);
      }
    } catch (_) {}
    await _canal.invokeMethod('agendar', {
      'millis': quando.millisecondsSinceEpoch,
      'diario': diario,
    });
  }

  /// Alarme único em data e hora específicas
  static Future<void> agendarUnico(DateTime quando) async {
    await _gravarAlarme(quando, false);
  }

  /// Alarme diário no mesmo horário (TODO DIA)
  static Future<void> agendarDiario(int hora, int minuto) async {
    final agora = DateTime.now();
    var primeiro = DateTime(agora.year, agora.month, agora.day, hora, minuto);
    if (!primeiro.isAfter(agora)) primeiro = primeiro.add(Duration(days: 1));
    await _gravarAlarme(primeiro, true);
  }

  static Future<void> cancelar() async {
    try {
      await _canal.invokeMethod('cancelar');
    } catch (_) {}
    try {
      await _canal.invokeMethod('parar');
    } catch (_) {}
  }
}
