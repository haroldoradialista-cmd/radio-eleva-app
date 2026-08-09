import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'despertador_service.dart';

/// Um despertador individual da lista (até 6 no total).
class Despertador {
  String id;
  String tipo; // 'dias' ou 'unico'
  int hora;
  int minuto;
  Set<int> dias; // padrão Calendar (dom=1..sáb=7)
  String? data; // ISO, só para 'unico'
  bool ativo;

  Despertador({
    required this.id,
    this.tipo = 'dias',
    this.hora = 7,
    this.minuto = 0,
    Set<int>? dias,
    this.data,
    this.ativo = true,
  }) : dias = dias ?? {1, 2, 3, 4, 5, 6, 7};

  Map<String, dynamic> paraMapa() => {
        'id': id,
        'tipo': tipo,
        'hora': hora,
        'minuto': minuto,
        'dias': dias.toList(),
        'data': data,
        'ativo': ativo,
      };

  static Despertador doMapa(Map<String, dynamic> m) => Despertador(
        id: (m['id'] ?? DateTime.now().millisecondsSinceEpoch.toString())
            .toString(),
        tipo: (m['tipo'] ?? 'dias').toString(),
        hora: (m['hora'] ?? 7) is int
            ? m['hora']
            : int.tryParse('${m['hora']}') ?? 7,
        minuto: (m['minuto'] ?? 0) is int
            ? m['minuto']
            : int.tryParse('${m['minuto']}') ?? 0,
        dias: (m['dias'] as List?)
                ?.map((e) => e is int ? e : int.tryParse('$e') ?? 0)
                .where((e) => e >= 1 && e <= 7)
                .toSet() ??
            {1, 2, 3, 4, 5, 6, 7},
        data: m['data']?.toString(),
        ativo: m['ativo'] == true,
      );

  /// Próxima vez (DateTime) em que este despertador vai tocar, ou null se
  /// nunca mais (ex.: alarme único cuja data já passou, ou inativo).
  DateTime? proximaOcorrencia() {
    if (!ativo) return null;
    final agora = DateTime.now();
    if (tipo == 'unico') {
      if (data == null) return null;
      final d = DateTime.tryParse(data!);
      if (d == null) return null;
      final alvo = DateTime(d.year, d.month, d.day, hora, minuto);
      return alvo.isAfter(agora) ? alvo : null;
    }
    // tipo == 'dias'
    if (dias.isEmpty) return null;
    for (int i = 0; i < 8; i++) {
      final d = DateTime(agora.year, agora.month, agora.day, hora, minuto)
          .add(Duration(days: i));
      final calDia = (d.weekday % 7) + 1; // Dart→Calendar
      if (dias.contains(calDia) && d.isAfter(agora)) return d;
    }
    return null;
  }
}

/// Gerencia a lista de despertadores e mantém o sistema nativo agendado
/// sempre para o PRÓXIMO alarme a tocar entre todos os ativos.
class DespertadoresLista {
  static const _chave = 'despertadores_v1';
  static const int maximo = 6;

  static Future<List<Despertador>> carregar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final txt = prefs.getString(_chave);
      if (txt == null || txt.isEmpty) {
        // migração: se havia um despertador antigo (formato único), traz ele
        return _migrarAntigo(prefs);
      }
      final lista = (jsonDecode(txt) as List)
          .map((e) => Despertador.doMapa(Map<String, dynamic>.from(e)))
          .toList();
      return lista;
    } catch (_) {
      return [];
    }
  }

  /// Traz o despertador do formato antigo (desp_*) para a nova lista.
  static List<Despertador> _migrarAntigo(SharedPreferences prefs) {
    try {
      final tinha = prefs.getBool('desp_ativo');
      if (tinha == null) return [];
      var tipo = prefs.getString('desp_tipo') ?? 'dias';
      if (tipo == 'diario') tipo = 'dias';
      final diasStr = prefs.getString('desp_dias') ?? '';
      final dias = diasStr.isEmpty
          ? <int>{1, 2, 3, 4, 5, 6, 7}
          : diasStr
              .split(',')
              .map((e) => int.tryParse(e.trim()) ?? 0)
              .where((e) => e >= 1 && e <= 7)
              .toSet();
      final d = Despertador(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        tipo: tipo,
        hora: prefs.getInt('desp_hora') ?? 7,
        minuto: prefs.getInt('desp_min') ?? 0,
        dias: dias,
        data: prefs.getString('desp_data'),
        ativo: tinha,
      );
      return [d];
    } catch (_) {
      return [];
    }
  }

  static Future<void> salvar(List<Despertador> lista) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final txt = jsonEncode(lista.map((e) => e.paraMapa()).toList());
      await prefs.setString(_chave, txt);
    } catch (_) {}
    await reagendarProximo(lista);
  }

  /// Descobre o próximo despertador a tocar e agenda ELE no sistema nativo.
  /// Se nenhum estiver ativo, cancela tudo.
  static Future<void> reagendarProximo(List<Despertador> lista) async {
    DateTime? maisCedo;
    Despertador? escolhido;
    for (final d in lista) {
      final prox = d.proximaOcorrencia();
      if (prox == null) continue;
      if (maisCedo == null || prox.isBefore(maisCedo)) {
        maisCedo = prox;
        escolhido = d;
      }
    }
    if (escolhido == null || maisCedo == null) {
      await DespertadorService.cancelar();
      return;
    }
    // 'diario:true' faz o nativo reagendar sozinho; como recalculamos a cada
    // toque pelo app, passamos como único e o app cuida do próximo.
    await DespertadorService.agendarUnico(maisCedo);
  }

  static int quantosAtivos(List<Despertador> lista) =>
      lista.where((d) => d.ativo && d.proximaOcorrencia() != null).length;
}
