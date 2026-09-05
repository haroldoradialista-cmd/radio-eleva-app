import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'correcoes_service.dart';

/// TOCOU NA RÁDIO — histórico das músicas executadas
///
/// Guarda a sequência do que tocou, para o ouvinte poder consultar depois
/// aquela música que ouviu no carro e não deu tempo de anotar.
///
/// Como funciona: o registro é feito pelo próprio app quando a música muda.
/// Vários aparelhos podem registrar a mesma música ao mesmo tempo, então
/// usamos uma CHAVE POR MINUTO — assim a mesma execução vira um registro
/// só, mesmo com 150 ouvintes online.
class HistoricoService {
  static String base = '';
  static String _ultimaRegistrada = '';

  /// Nomes que não são música (vinheta, identificação da rádio...)
  static bool _ehMusica(String bruto) {
    final t = bruto.trim();
    if (t.length < 6) return false;
    final cru = CorrecoesService.cru(t);
    if (cru.length < 6) return false;
    // precisa ter separação "artista - música"
    if (!t.contains(' - ')) return false;
    const naoSao = [
      'vinheta', 'id da radio', 'identificacao', 'comercial', 'spot',
      'break', 'intervalo', 'chamada', 'oferecimento', 'patrocinio',
      'sem titulo', 'unknown', 'no title', 'radio eleva', 'ao vivo'
    ];
    for (final n in naoSao) {
      if (cru.contains(n)) return false;
    }
    return true;
  }

  /// Registra a música que está tocando agora
  static Future<void> registrar(String musicaBruta, {String? capa}) async {
    if (base.isEmpty) return;
    if (!_ehMusica(musicaBruta)) return;

    final chaveMusica = CorrecoesService.cru(musicaBruta);
    if (chaveMusica == _ultimaRegistrada) return;
    _ultimaRegistrada = chaveMusica;

    final agora = DateTime.now();
    // chave por MINUTO: se 150 aparelhos registrarem a mesma música no
    // mesmo minuto, todos gravam no mesmo lugar — vira um registro só.
    final id = '${agora.year}'
        '${agora.month.toString().padLeft(2, '0')}'
        '${agora.day.toString().padLeft(2, '0')}_'
        '${agora.hour.toString().padLeft(2, '0')}'
        '${agora.minute.toString().padLeft(2, '0')}';

    try {
      await http
          .put(
            Uri.parse('$base/tocou/$id.json'),
            body: jsonEncode({
              'musica': musicaBruta.trim(),
              'quando': agora.toIso8601String(),
              if (capa != null && capa.startsWith('http')) 'capa': capa,
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  /// Busca as últimas músicas tocadas (mais recentes primeiro)
  static Future<List<Map<String, dynamic>>> ultimas({int quantas = 30}) async {
    if (base.isEmpty) return [];
    try {
      final r = await http
          .get(Uri.parse(
              '$base/tocou.json?orderBy="\$key"&limitToLast=$quantas'))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        final d = jsonDecode(utf8.decode(r.bodyBytes));
        if (d is Map) {
          final lista = <Map<String, dynamic>>[];
          d.forEach((id, v) {
            if (v is Map) {
              final item = Map<String, dynamic>.from(v);
              item['_id'] = id;
              lista.add(item);
            }
          });
          // mais recentes primeiro
          lista.sort((a, b) =>
              (b['_id'] ?? '').toString().compareTo((a['_id'] ?? '').toString()));
          await _guardarCopia(lista);
          return lista;
        }
      }
    } catch (_) {}
    // sem internet: devolve a última lista guardada
    return await _copiaGuardada();
  }

  static Future<void> _guardarCopia(List<Map<String, dynamic>> lista) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tocou_guardado', jsonEncode(lista));
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> _copiaGuardada() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final txt = prefs.getString('tocou_guardado');
      if (txt != null && txt.isNotEmpty) {
        final d = jsonDecode(txt);
        if (d is List) {
          return d.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Separa "ARTISTA - MÚSICA"
  static (String, String) separar(String bruto) {
    final t = bruto.trim();
    final i = t.indexOf(' - ');
    if (i > 0) {
      return (t.substring(0, i).trim(), t.substring(i + 3).trim());
    }
    return ('', t);
  }

  /// Hora no formato 18:42
  static String hora(String quando) {
    try {
      final d = DateTime.parse(quando);
      return '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {}
    return '';
  }

  /// Diz se foi hoje, ontem, ou a data
  static String dia(String quando) {
    try {
      final d = DateTime.parse(quando);
      final hoje = DateTime.now();
      final ontem = hoje.subtract(const Duration(days: 1));
      if (d.year == hoje.year && d.month == hoje.month && d.day == hoje.day) {
        return 'HOJE';
      }
      if (d.year == ontem.year && d.month == ontem.month && d.day == ontem.day) {
        return 'ONTEM';
      }
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}';
    } catch (_) {}
    return '';
  }
}
