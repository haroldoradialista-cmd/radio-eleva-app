import 'dart:async';
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
  final int chatSuspensaoHoras;
  final int chatSuspensaoMinutos;
  final int chatBanirApos; // banir após X suspensões (0 = nunca)
  final String tvVideo;    // link ou ID do vídeo/live do YouTube
  final List<String> chatPalavras;
  final String linkCompartilhar;
  final bool anunciosAtivos;
  final List<Map<String, dynamic>> banners;
  final List<Map<String, dynamic>> noticias;
  final List<Map<String, dynamic>> redes;
  final List<Map<String, dynamic>> programacao;
  final List<Map<String, dynamic>> enquetes;
  final List<Map<String, dynamic>> promocoes;

  AppConfig({
    required this.nome,
    required this.slogan,
    required this.streamUrl,
    required this.logoUrl,
    required this.whatsapp,
    required this.mensagemPedido,
    required this.chatUrl,
    required this.chatSuspensaoHoras,
    required this.chatSuspensaoMinutos,
    required this.chatBanirApos,
    required this.tvVideo,
    required this.chatPalavras,
    required this.linkCompartilhar,
    required this.anunciosAtivos,
    required this.banners,
    required this.noticias,
    required this.redes,
    required this.programacao,
    required this.enquetes,
    required this.promocoes,
  });

  factory AppConfig.fromJson(Map<String, dynamic> j) => AppConfig(
        nome: j['nome'] ?? kNomeRadio,
        slogan: j['slogan'] ?? kSloganRadio,
        streamUrl: j['stream_url'] ?? kStreamPadrao,
        logoUrl: j['logo_url'] ?? '',
        whatsapp: j['whatsapp'] ?? '',
        mensagemPedido: j['mensagem_pedido'] ?? 'Olá! Quero pedir uma música:',
        chatUrl: j['chat_url'] ?? '',
        chatSuspensaoHoras: int.tryParse((j['chat_suspensao_horas'] ?? '24').toString()) ?? 24,
        chatSuspensaoMinutos: int.tryParse((j['chat_suspensao_minutos'] ?? '0').toString()) ?? 0,
        chatBanirApos: int.tryParse((j['chat_banir_apos'] ?? '0').toString()) ?? 0,
        tvVideo: (j['tv_video'] ?? '').toString(),
        chatPalavras: List<String>.from(j['chat_palavras'] ?? []),
        linkCompartilhar: j['link_compartilhar'] ?? '',
        anunciosAtivos: (j['anuncios'] ?? 'sim').toString() != 'nao',
        banners: List<Map<String, dynamic>>.from(j['banners'] ?? []),
        noticias: List<Map<String, dynamic>>.from(j['noticias'] ?? []),
        redes: List<Map<String, dynamic>>.from(j['redes'] ?? []),
        programacao: List<Map<String, dynamic>>.from(j['programacao'] ?? []),
        enquetes: List<Map<String, dynamic>>.from(j['enquetes'] ?? []),
        promocoes: List<Map<String, dynamic>>.from(j['promocoes'] ?? []),
      );

  factory AppConfig.padrao() => AppConfig(
        nome: kNomeRadio,
        slogan: kSloganRadio,
        streamUrl: kStreamPadrao,
        logoUrl: '',
        whatsapp: '',
        mensagemPedido: 'Olá! Quero pedir uma música:',
        chatUrl: '',
        chatSuspensaoHoras: 24,
        chatSuspensaoMinutos: 0,
        chatBanirApos: 0,
        tvVideo: '',
        chatPalavras: [],
        linkCompartilhar: '',
        anunciosAtivos: true,
        banners: [],
        noticias: [],
        redes: [],
        programacao: [],
        enquetes: [],
        promocoes: [],
      );
}

class ConfigService {
  static final ConfigService instancia = ConfigService._();
  ConfigService._();

  final ValueNotifier<AppConfig> config = ValueNotifier(AppConfig.padrao());
  Timer? _autoTimer;

  /// Recarrega o config.json a cada 30s: mudanças feitas no Painel Eleva
  /// chegam a todas as abas do app automaticamente, sem ação do ouvinte.
  void iniciarAutoAtualizacao() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(Duration(seconds: 30), (_) => carregar());
  }

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
    // Finalizado manualmente pelo painel (botão ⏹️) → sai do ar na hora
    if ((i['finalizado'] ?? '').toString() == 'sim') return false;
    final ini = DateTime.tryParse((i['publicar_em'] ?? '').toString());
    final fim = DateTime.tryParse((i['expirar_em'] ?? '').toString());
    if (ini != null && agora.isBefore(ini)) return false;
    if (fim != null && agora.isAfter(fim)) return false;
    return true;
  }).toList();
}

/// Enquetes que JÁ SAÍRAM DO AR e estão marcadas para exibir o
/// resultado aos ouvintes (opção "exibir_resultado" do painel).
List<Map<String, dynamic>> filtrarEncerradasComResultado(
    List<Map<String, dynamic>> itens) {
  final agora = DateTime.now();
  return itens.where((i) {
    if ((i['exibir_resultado'] ?? '').toString() != 'sim') return false;
    // mostra o resultado se foi finalizada no painel OU se passou do prazo
    if ((i['finalizado'] ?? '').toString() == 'sim') return true;
    final fim = DateTime.tryParse((i['expirar_em'] ?? '').toString());
    if (fim == null) return false;
    return agora.isAfter(fim);
  }).toList();
}

const List<String> kOrdemDias = [
  'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'
];

/// Dias em que um programa acontece (aceita formato novo e antigo)
List<String> diasDoPrograma(Map<String, dynamic> p) {
  if (p['dias'] is List && (p['dias'] as List).isNotEmpty) {
    return List<String>.from(p['dias']);
  }
  final d = (p['dia'] ?? '').toString();
  if (d == 'Todos os dias' || d.isEmpty) return List.from(kOrdemDias);
  return [d];
}

/// Descobre qual programa está no ar agora, com base no dia e no horário
Map<String, dynamic>? programaNoAr(List<Map<String, dynamic>> programacao) {
  final agora = DateTime.now();
  final hoje = kOrdemDias[agora.weekday - 1];
  final hhmm =
      '${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}';
  final doDia = programacao
      .where((p) =>
          diasDoPrograma(p).contains(hoje) &&
          (p['horario'] ?? '').toString().isNotEmpty)
      .toList()
    ..sort((a, b) =>
        a['horario'].toString().compareTo(b['horario'].toString()));
  Map<String, dynamic>? atual;
  for (final p in doDia) {
    if (p['horario'].toString().compareTo(hhmm) <= 0) atual = p;
  }
  return atual;
}
