import 'package:flutter/material.dart';
import '../servicos/historico_service.dart';
import '../tema.dart';

/// TOCOU NA RÁDIO
/// Lista das últimas músicas que passaram no ar, com horário e capa.
/// Serve para o ouvinte descobrir aquela música que ouviu no carro e
/// não deu tempo de anotar.
class TocouPage extends StatefulWidget {
  const TocouPage({super.key});

  @override
  State<TocouPage> createState() => _TocouPageState();
}

class _TocouPageState extends State<TocouPage> {
  List<Map<String, dynamic>> _lista = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _buscar();
  }

  Future<void> _buscar() async {
    if (mounted) setState(() => _carregando = true);
    final l = await HistoricoService.ultimas(quantas: 40);
    if (mounted) {
      setState(() {
        _lista = l;
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: CoresEleva.azulProfundo,
        iconTheme: IconThemeData(color: CoresEleva.dourado),
        title: Text('TOCOU NA RÁDIO',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: CoresEleva.dourado)),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            icon: Icon(Icons.refresh_rounded, color: CoresEleva.dourado),
            onPressed: _buscar,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: CoresEleva.fundoApp),
        child: SafeArea(
          child: _carregando
              ? Center(
                  child: CircularProgressIndicator(color: CoresEleva.dourado))
              : _lista.isEmpty
                  ? _vazio()
                  : RefreshIndicator(
                      color: CoresEleva.dourado,
                      backgroundColor: CoresEleva.azulProfundo,
                      onRefresh: _buscar,
                      child: ListView.builder(
                        padding: EdgeInsets.fromLTRB(14, 12, 14, 26),
                        itemCount: _lista.length,
                        itemBuilder: (_, i) => _linha(_lista[i], i),
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _vazio() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.queue_music_rounded,
                size: 62, color: CoresEleva.textoFraco),
            SizedBox(height: 16),
            Text('Nenhuma música registrada ainda',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: CoresEleva.branco)),
            SizedBox(height: 8),
            Text(
                'As músicas aparecem aqui conforme vão tocando.\n'
                'Deixe a rádio no ar e volte daqui a pouco. 🎵',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: CoresEleva.brancoSuave)),
          ],
        ),
      ),
    );
  }

  Widget _linha(Map<String, dynamic> item, int indice) {
    final bruto = (item['musica'] ?? '').toString();
    final (artista, titulo) = HistoricoService.separar(bruto);
    final hora = HistoricoService.hora((item['quando'] ?? '').toString());
    final dia = HistoricoService.dia((item['quando'] ?? '').toString());
    final capa = (item['capa'] ?? '').toString();
    final agora = indice == 0;

    // separador de dia (HOJE / ONTEM / data)
    final anterior = indice > 0
        ? HistoricoService.dia((_lista[indice - 1]['quando'] ?? '').toString())
        : '';
    final mostrarDia = indice == 0 || dia != anterior;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mostrarDia)
          Padding(
            padding: EdgeInsets.fromLTRB(4, indice == 0 ? 0 : 16, 4, 8),
            child: Text(dia,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: CoresEleva.dourado)),
          ),
        Container(
          margin: EdgeInsets.only(bottom: 9),
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: agora
                ? CoresEleva.verde.withOpacity(0.14)
                : CoresEleva.azulProfundo,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: agora
                    ? CoresEleva.verde.withOpacity(0.6)
                    : Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              // capa
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: capa.startsWith('http')
                      ? Image.network(capa,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _capaPadrao())
                      : _capaPadrao(),
                ),
              ),
              SizedBox(width: 11),
              // textos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (agora)
                      Padding(
                        padding: EdgeInsets.only(bottom: 3),
                        child: Text('▶ TOCANDO AGORA',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: CoresEleva.verde)),
                      ),
                    Text(titulo.isEmpty ? bruto : titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: CoresEleva.branco)),
                    if (artista.isNotEmpty)
                      Text(artista,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5,
                              color: CoresEleva.brancoSuave)),
                  ],
                ),
              ),
              SizedBox(width: 8),
              // horário
              Text(hora,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: CoresEleva.dourado)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _capaPadrao() => Container(
        color: CoresEleva.azulMedio,
        padding: EdgeInsets.all(9),
        child: Image.asset('assets/logo.png', fit: BoxFit.contain),
      );
}
