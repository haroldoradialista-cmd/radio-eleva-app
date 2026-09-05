import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'correcoes_service.dart';

/// AUDITORIA DE LETRAS E CAPAS
///
/// Por que este serviço existe:
/// antes, a rádio só descobria um erro quando um ouvinte reclamava — e a
/// maioria não reclama. O resultado é que músicas seguiam com capa ou letra
/// errada por semanas.
///
/// Agora o app REGISTRA, a cada música tocada, o que foi exibido e com que
/// grau de certeza. No painel, isso vira uma lista de conferência ordenada
/// pelas músicas MAIS TOCADAS — assim a rádio corrige o que mais aparece,
/// antes do ouvinte perceber.
class AuditoriaService {
  static String base = '';

  /// Evita registrar a mesma música várias vezes seguidas
  static String _ultima = '';

  /// Guarda no aparelho quais músicas já foram registradas hoje, para não
  /// mandar o mesmo registro dezenas de vezes (economiza dados e banco).
  static final Set<String> _registradasNaSessao = {};

  /// Registra o resultado da busca desta música.
  ///
  /// [certeza] vai de 0 a 100:
  ///   100 = veio da base corrigida pela rádio (confiança total)
  ///    80 = artista e título conferiram exatamente
  ///    60 = conferiu com pequenas variações
  ///     0 = não encontrou nada
  static Future<void> registrar({
    required String musica,
    required bool temLetra,
    required bool temCapa,
    required int certezaLetra,
    required int certezaCapa,
    String origemLetra = '',
    String origemCapa = '',
  }) async {
    if (base.isEmpty) return;
    final chave = CorrecoesService.cru(musica);
    if (chave.length < 6 || !chave.contains(' ')) return; // vinheta, ID...
    if (chave == _ultima) return;
    _ultima = chave;

    // uma vez por música por sessão do app
    if (_registradasNaSessao.contains(chave)) {
      await _somarExecucao(chave);
      return;
    }
    _registradasNaSessao.add(chave);

    try {
      // PATCH mantém o registro existente e atualiza os campos
      await http.patch(
        Uri.parse('$base/auditoria/$chave.json'),
        body: jsonEncode({
          'musica': musica,
          'tem_letra': temLetra,
          'tem_capa': temCapa,
          'certeza_letra': certezaLetra,
          'certeza_capa': certezaCapa,
          'origem_letra': origemLetra,
          'origem_capa': origemCapa,
          'ultima_vez': DateTime.now().toIso8601String(),
        }),
      );
      await _somarExecucao(chave);
    } catch (_) {}
  }

  /// Soma +1 na contagem de execuções (para saber o que mais toca)
  static Future<void> _somarExecucao(String chave) async {
    try {
      final r = await http
          .get(Uri.parse('$base/auditoria/$chave/execucoes.json'))
          .timeout(const Duration(seconds: 6));
      var n = 0;
      if (r.statusCode == 200) {
        n = int.tryParse(r.body.replaceAll('"', '')) ?? 0;
      }
      await http.put(
        Uri.parse('$base/auditoria/$chave/execucoes.json'),
        body: jsonEncode(n + 1),
      );
    } catch (_) {}
  }

  /// Limpa a memória da sessão (chamado quando o app reabre)
  static void novaSessao() {
    _registradasNaSessao.clear();
    _ultima = '';
  }

  /// Guarda no aparelho a última certeza calculada, para o app saber
  /// quando NÃO vale a pena exibir (melhor nada do que errado).
  static Future<void> guardarCerteza(String chave, int valor) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('certeza_$chave', valor);
    } catch (_) {}
  }
}
