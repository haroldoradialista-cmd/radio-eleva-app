import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../app_config.dart';

/// Representa o conteúdo gerenciável do app (vem do config.json no GitHub)
class AppConfig {
  final String nome;
  final String slogan;
  final String streamUrl;
  final String logoUrl;
  final String whatsapp;
  final String mensagemPedido;
  final String chatUrl; // URL do Firebase Realtime Database (sem .json)
  final List<Map<String, dynamic>> banners;
  final List<Map<String, dynamic>> noticias;
  final List<Map<String, dynamic>> redes;
  final List<Map<String, dynamic>> programacao;

  AppConfig({
    required this.nome,
    required this.slogan,
    required this.streamUrl,
    required this.logoUrl,
    required this.whatsapp,
    required this.mensagemPedido,
    required this.chatUrl,
    required this.banners,
    required this.noticias,
    required this.redes,
    required this.programacao,
  });

  factory AppConfig.fromJson(Map<String, dynamic> j) => AppConfig(
        nome: j['nome'] ?? kNomeRadio,
        slogan: j['slogan'] ?? kSloganRadio,
        streamUrl: j['stream_url'] ?? kStreamPadrao,
        logoUrl: j['logo_url'] ?? '',
        whatsapp: j['whatsapp'] ?? '',
        mensagemPedido: j['mensagem_pedido'] ?? 'Olá! Quero pedir uma música:',
        chatUrl: j['chat_url'] ?? '',
        banners: List<Map<String, dynamic>>.from(j['banners'] ?? []),
        noticias: List<Map<String, dynamic>>.from(j['noticias'] ?? []),
        redes: List<Map<String, dynamic>>.from(j['redes'] ?? []),
        programacao: List<Map<String, dynamic>>.from(j['programacao'] ?? []),
      );

  factory AppConfig.padrao() => AppConfig(
        nome: kNomeRadio,
        slogan: kSloganRadio,
        streamUrl: kStreamPadrao,
        logoUrl: '',
        whatsapp: '',
        mensagemPedido: 'Olá! Quero pedir uma música:',
        chatUrl: '',
        banners: [],
        noticias: [],
        redes: [],
        programacao: [],
      );
}

class ConfigService {
  static final ConfigService instancia = ConfigService._();
  ConfigService._();

  final ValueNotifier<AppConfig> config = ValueNotifier(AppConfig.padrao());

  Future<void> carregar() async {
    try {
      final r = await http
          .get(Uri.parse('$kConfigUrl?v=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        config.value = AppConfig.fromJson(jsonDecode(utf8.decode(r.bodyBytes)));
      }
    } catch (_) {
      // mantém configuração padrão de emergência
    }
  }
}

/// Filtra itens pelo agendamento (campos opcionais publicar_em / expirar_em)
List<Map<String, dynamic>> filtrarAgendados(List<Map<String, dynamic>> itens) {
  final agora = DateTime.now();
  return itens.where((i) {
    final ini = DateTime.tryParse((i['publicar_em'] ?? '').toString());
    final fim = DateTime.tryParse((i['expirar_em'] ?? '').toString());
    if (ini != null && agora.isBefore(ini)) return false;
    if (fim != null && agora.isAfter(fim)) return false;
    return true;
  }).toList();
}
