import 'package:flutter/material.dart';
import '../servicos/config_service.dart';
import '../tema.dart';
import '../widgets/anuncio_banner.dart';

class ProgramacaoPage extends StatefulWidget {
  ProgramacaoPage({super.key});
  @override
  State<ProgramacaoPage> createState() => _ProgramacaoPageState();
}

class _ProgramacaoPageState extends State<ProgramacaoPage> {
  late String _diaSelecionado;

  String get _diaHoje => kOrdemDias[DateTime.now().weekday - 1];

  @override
  void initState() {
    super.initState();
    _diaSelecionado = _diaHoje;
  }

  Widget _chipDia(String dia) {
    final selecionado = dia == _diaSelecionado;
    final hoje = dia == _diaHoje;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: () => setState(() => _diaSelecionado = dia),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: selecionado ? CoresEleva.botaoPlay : null,
            color: selecionado ? null : CoresEleva.azulMedio,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hoje ? CoresEleva.dourado : CoresEleva.borda,
              width: hoje ? 2.2 : 1.2,
            ),
            boxShadow: selecionado
                ? [
                    BoxShadow(
                        color: CoresEleva.verde.withOpacity(0.35),
                        blurRadius: 10)
                  ]
                : null,
          ),
          child: Text(
            dia.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: hoje ? FontWeight.w900 : FontWeight.w700,
              letterSpacing: 0.3,
              color: selecionado
                  ? Colors.white
                  : (hoje ? CoresEleva.dourado : CoresEleva.brancoSuave),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FundoEleva(
      child: SafeArea(
        child: ValueListenableBuilder<AppConfig>(
          valueListenable: ConfigService.instancia.config,
          builder: (context, cfg, _) {
            final noAr = programaNoAr(cfg.programacao);
            final doDia = cfg.programacao
                .where((p) => diasDoPrograma(p).contains(_diaSelecionado))
                .toList()
              ..sort((a, b) => (a['horario'] ?? '')
                  .toString()
                  .compareTo((b['horario'] ?? '').toString()));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnuncioBanner(),
                Padding(
                  padding: EdgeInsets.fromLTRB(14, 14, 14, 8),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_rounded,
                          color: CoresEleva.dourado),
                      SizedBox(width: 10),
                      Text('Programação',
                          style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                ),

                // ===== SELETOR DE DIAS (modelo em duas fileiras) =====
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: ['Segunda', 'Terça', 'Quarta', 'Quinta']
                            .map((d) => _chipDia(d))
                            .toList(),
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: ['Sexta', 'Sábado', 'Domingo']
                            .map((d) => _chipDia(d))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8),

                // ===== PROGRAMAS DO DIA =====
                Expanded(
                  child: RefreshIndicator(
                    color: CoresEleva.verde,
                    onRefresh: () => ConfigService.instancia.carregar(),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(14, 4, 14, 14),
                      children: [
                        if (doDia.isEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: 80),
                            child: Center(
                                child: Text(
                                    'Nenhum programa cadastrado\npara $_diaSelecionado.',
                                    textAlign: TextAlign.center)),
                          ),
                        ...doDia.map((p) {
                          final foto = (p['imagem'] ?? '').toString();
                          final estaNoAr = _diaSelecionado == _diaHoje &&
                              noAr != null &&
                              noAr['programa'] == p['programa'] &&
                              noAr['horario'] == p['horario'];
                          return Container(
                            margin: EdgeInsets.only(bottom: 10),
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: CoresEleva.azulMedio,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: estaNoAr
                                    ? CoresEleva.verde
                                    : CoresEleva.borda,
                                width: estaNoAr ? 1.8 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                if (foto.isNotEmpty) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      foto,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          SizedBox(width: 48, height: 48),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (estaNoAr)
                                        Container(
                                          margin:
                                              EdgeInsets.only(bottom: 4),
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade700,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text('🔴 NO AR AGORA',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.white,
                                                  fontWeight:
                                                      FontWeight.w900,
                                                  letterSpacing: 0.5)),
                                        ),
                                      Text((p['programa'] ?? '').toString(),
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: CoresEleva.branco)),
                                      if ((p['apresentador'] ?? '')
                                          .toString()
                                          .isNotEmpty)
                                        Text('com ${p['apresentador']}',
                                            style: TextStyle(
                                                color:
                                                    CoresEleva.brancoSuave,
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
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                      (p['horario'] ?? '--:--').toString(),
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
