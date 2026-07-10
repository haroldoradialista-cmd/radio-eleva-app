import 'package:flutter/material.dart';
import '../servicos/config_service.dart';
import '../tema.dart';

class ProgramacaoPage extends StatelessWidget {
  ProgramacaoPage({super.key});

  static final _ordemDias = [
    'Segunda',
    'Terça',
    'Quarta',
    'Quinta',
    'Sexta',
    'Sábado',
    'Domingo',
  ];

  String get _diaHoje => _ordemDias[DateTime.now().weekday - 1];

  /// Aceita o formato novo (lista "dias") e o antigo (campo "dia")
  List<String> _diasDoPrograma(Map<String, dynamic> p) {
    if (p['dias'] is List && (p['dias'] as List).isNotEmpty) {
      return List<String>.from(p['dias']);
    }
    final d = (p['dia'] ?? '').toString();
    if (d == 'Todos os dias' || d.isEmpty) return List.from(_ordemDias);
    return [d];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: CoresEleva.fundoApp),
      child: SafeArea(
        child: ValueListenableBuilder<AppConfig>(
          valueListenable: ConfigService.instancia.config,
          builder: (context, cfg, _) {
            final Map<String, List<Map<String, dynamic>>> porDia = {};
            for (final p in cfg.programacao) {
              for (final dia in _diasDoPrograma(p)) {
                porDia.putIfAbsent(dia, () => []).add(p);
              }
            }
            porDia.forEach((_, lista) => lista.sort((a, b) =>
                (a['horario'] ?? '').toString().compareTo(
                    (b['horario'] ?? '').toString())));
            final dias =
                _ordemDias.where((d) => porDia.containsKey(d)).toList();

            return RefreshIndicator(
              color: CoresEleva.verde,
              onRefresh: () => ConfigService.instancia.carregar(),
              child: ListView(
                padding: EdgeInsets.all(14),
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_month_rounded,
                          color: CoresEleva.dourado),
                      SizedBox(width: 10),
                      Text('Programação',
                          style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                  SizedBox(height: 12),
                  if (dias.isEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(
                          child: Text(
                              'Programação em breve.\nPuxe para atualizar.',
                              textAlign: TextAlign.center)),
                    ),
                  ...dias.map((dia) {
                    final hoje = dia == _diaHoje;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: 10, bottom: 6),
                          child: Row(
                            children: [
                              Text(dia,
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: hoje
                                          ? CoresEleva.verde
                                          : CoresEleva.dourado)),
                              if (hoje)
                                Container(
                                  margin: EdgeInsets.only(left: 8),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: CoresEleva.verdeEscuro,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text('HOJE',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800)),
                                ),
                            ],
                          ),
                        ),
                        ...porDia[dia]!.map((p) {
                          final foto = (p['imagem'] ?? '').toString();
                          return Card(
                            color: CoresEleva.azulMedio,
                            margin: EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  if (foto.isNotEmpty) ...[
                                    ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      child: Image.network(
                                        foto,
                                        width: 46,
                                        height: 46,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            SizedBox(
                                                width: 46, height: 46),
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            (p['programa'] ?? '')
                                                .toString(),
                                            style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: CoresEleva.branco)),
                                        if ((p['apresentador'] ?? '')
                                            .toString()
                                            .isNotEmpty)
                                          Text('com ${p['apresentador']}',
                                              style: TextStyle(
                                                  color: CoresEleva
                                                      .brancoSuave,
                                                  fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      gradient: CoresEleva.botaoPlay,
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                        (p['horario'] ?? '--:--')
                                            .toString(),
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
