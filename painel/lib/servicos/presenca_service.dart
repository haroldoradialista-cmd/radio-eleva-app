import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config_service.dart';
import 'player_service.dart';

/// Sinaliza "estou ouvindo agora" a cada 60s enquanto o player toca,
/// para o contador de OUVINTES CONECTADOS do Painel Eleva.
class PresencaService {
  static Timer? _timer;
  static String _id = '';

  static Future<void> iniciar() async {
    final prefs = await SharedPreferences.getInstance();
    _id = prefs.getString('presenca_id') ?? '';
    if (_id.isEmpty) {
      _id = 'd${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(99999)}';
      await prefs.setString('presenca_id', _id);
    }
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 60), (_) => _pulsar());
    _pulsar();
  }

  static Future<void> _pulsar() async {
    try {
      if (!PlayerService.instancia.player.playing) return;
      final cfg = ConfigService.instancia.config.value;
      if (cfg.chatUrl.isEmpty) return;
      final base = cfg.chatUrl.replaceAll(RegExp(r'/chat/?$'), '');
      await http.put(
        Uri.parse('$base/ouvintes_online/$_id.json'),
        body: jsonEncode({'t': DateTime.now().millisecondsSinceEpoch}),
      );
    } catch (_) {}
  }
}
