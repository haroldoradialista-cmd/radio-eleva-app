import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config_service.dart';

/// Registra um acesso anônimo por abertura do app (sem identificar o ouvinte):
/// data/hora, plataforma e cidade aproximada (via internet, sem GPS).
class AnalyticsService {
  static bool _registrado = false;
  static String cidade = '', estado = '', pais = '', bairro = '';
  static String uf = ''; // sigla do estado (RJ, MG, SP...) para casar com o nome
  static String dispositivo = 'Android';

  static bool localizado = false; // true quando a localização por IP já carregou
  static Future<void>? _futLoc;

  /// Garante que a localização por IP foi buscada (uma única vez).
  /// Retorna quando terminar (ou falhar). Use antes de decidir anúncio regional.
  static Future<void> garantirLocalizacao() {
    _futLoc ??= _buscarLocalizacao();
    return _futLoc!;
  }

  static Future<void> _buscarLocalizacao() async {
    try {
      final g = await http
          .get(Uri.parse('https://ipwho.is/'))
          .timeout(const Duration(seconds: 6));
      if (g.statusCode == 200) {
        final d = jsonDecode(g.body);
        if (d['success'] == true) {
          cidade = (d['city'] ?? '').toString();
          estado = (d['region'] ?? '').toString();
          uf = (d['region_code'] ?? '').toString();
          pais = (d['country'] ?? '').toString();
          bairro = (d['district'] ?? d['borough'] ?? '').toString();
          localizado = true;
        }
      }
    } catch (_) {}
  }

  static Future<void> registrarAcesso() async {
    if (_registrado) return;
    _registrado = true;
    try {
      final cfg = ConfigService.instancia.config.value;
      if (cfg.chatUrl.isEmpty) return;
      final base = cfg.chatUrl.replaceAll(RegExp(r'/chat/?$'), '');

      // Localização aproximada por IP (sem GPS, sem pedir permissão)
      await garantirLocalizacao();

      await http.post(
        Uri.parse('$base/acessos.json'),
        body: jsonEncode({
          'quando': DateTime.now().toIso8601String(),
          'plataforma': 'android',
          'cidade': cidade,
          'estado': estado,
          'pais': pais,
        }),
      );
    } catch (_) {}
  }

  /// Registra um clique/evento com a localização do ouvinte
  /// (usado por notícias, enquetes e promoções para os relatórios)
  static Future<void> registrarEvento(
      String colecao, String id, Map<String, dynamic> extras) async {
    try {
      final cfg = ConfigService.instancia.config.value;
      if (cfg.chatUrl.isEmpty) return;
      final base = cfg.chatUrl.replaceAll(RegExp(r'/chat/?$'), '');
      await http.post(
        Uri.parse('$base/$colecao/$id.json'),
        body: jsonEncode({
          ...extras,
          'cidade': cidade,
          'estado': estado,
          'pais': pais,
          'quando': DateTime.now().toIso8601String(),
        }),
      );
    } catch (_) {}
  }
}
