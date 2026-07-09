import 'package:flutter/material.dart';
import '../servicos/config_service.dart';
import '../tema.dart';

class ProgramacaoPage extends StatelessWidget {
  const ProgramacaoPage({super.key});

  static const _ordemDias = [
    'Segunda',
    'Terça',
    'Quarta',
    'Quinta',
    'Sexta',
    'Sábado',
    'Domingo',
    'Todos os dias',
  ];

  String get _diaHoje {
    const nomes = [
      'Segunda',
      'Terça',
      'Quarta',
      'Quinta',
      'Sexta',
      'Sábado',
      'Domingo'
    ];
    return nomes[DateTime.now().weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: CoresEleva.fundoApp),
      child: SafeArea(
        child: ValueListenableBuilder<AppConfig>(
          valueListenable: ConfigService.instancia.config,
          builder: (context, cfg, _) {
            // agrupa por dia
            final Map<String, List<Map<String, dynamic>>> porDia = {};
            for (final p in cfg.programacao) {
              final dia = (p['dia'] ?? 'Todos os dias').toString();
              porDia.putIfAbsent(dia, () => []).add(p);
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
                padding: const EdgeInsets.all(14),
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded,
                          color: CoresEleva.dourado),
                      const SizedBox(width: 10),
                      Text('Programação',
                          style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (dias.isEmpty)
                    const Padding(
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
                          padding: const EdgeInsets.only(top: 10, bottom: 6),
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
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: CoresEleva.verdeEscuro,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text('HOJE',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800)),
                                ),
                            ],
                          ),
                        ),
                        ...porDia[dia]!.map((p) => Card(
                              color: CoresEleva.azulMedio,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: CoresEleva.botaoPlay,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                      (p['horario'] ?? '--:--').toString(),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white)),
                                ),
                                title: Text(
                                    (p['programa'] ?? '').toString(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: CoresEleva.branco)),
                                subtitle: (p['apresentador'] ?? '')
                                        .toString()
                                        .isNotEmpty
                                    ? Text('com ${p['apresentador']}',
                                        style: const TextStyle(
                                            color: CoresEleva.brancoSuave,
                                            fontSize: 12))
                                    : null,
                              ),
                            )),
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
