import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../servicos/despertador_service.dart';
import '../tema.dart';

class DespertadorPage extends StatefulWidget {
  DespertadorPage({super.key});
  @override
  State<DespertadorPage> createState() => _DespertadorPageState();
}

class _DespertadorPageState extends State<DespertadorPage> {
  String _tipo = 'dias'; // 'dias' ou 'unico'
  TimeOfDay _hora = TimeOfDay(hour: 7, minute: 0);
  DateTime? _data;
  Set<int> _dias = {}; // dias da semana no padrão Calendar (dom=1..sáb=7)
  bool _ativo = false;
  String _resumo = '';
  Map<String, bool> _perms = {};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    _verificarPermissoes();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _ativo = prefs.getBool('desp_ativo') ?? false;
      _tipo = prefs.getString('desp_tipo') ?? 'dias';
      // "TODO DIA" foi substituído por "DIAS DA SEMANA" com todos os dias:
      // converte configurações antigas automaticamente.
      if (_tipo == 'diario') _tipo = 'dias';
      _hora = TimeOfDay(
          hour: prefs.getInt('desp_hora') ?? 7,
          minute: prefs.getInt('desp_min') ?? 0);
      final d = prefs.getString('desp_data') ?? '';
      _data = d.isEmpty ? null : DateTime.tryParse(d);
      final diasStr = prefs.getString('desp_dias') ?? '';
      _dias = diasStr.isEmpty
          ? <int>{}
          : diasStr
              .split(',')
              .map((e) => int.tryParse(e.trim()) ?? 0)
              .where((e) => e >= 1 && e <= 7)
              .toSet();
      // Se veio do antigo "TODO DIA" e ficou sem dias, marca a semana toda
      if (_tipo == 'dias' && _dias.isEmpty &&
          (prefs.getString('desp_tipo') ?? '') == 'diario') {
        _dias = {1, 2, 3, 4, 5, 6, 7};
      }
      _resumo = prefs.getString('desp_resumo') ?? '';
    });
  }

  Future<void> _verificarPermissoes() async {
    final m = await DespertadorService.statusPermissoes();
    if (mounted) setState(() => _perms = m);
  }

  Widget _linhaPerm(String chave, String titulo, String porque) {
    final ok = _perms[chave] ?? true;
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded,
              size: 18, color: ok ? CoresEleva.verde : Colors.red.shade300),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: ok
                            ? CoresEleva.brancoSuave
                            : Colors.red.shade100)),
                if (!ok)
                  Text(porque,
                      style: TextStyle(
                          fontSize: 10.5,
                          height: 1.35,
                          color: CoresEleva.textoFraco)),
              ],
            ),
          ),
          if (!ok)
            GestureDetector(
              onTap: () async {
                await DespertadorService.abrirPermissao(chave);
                await Future.delayed(Duration(seconds: 1));
                _verificarPermissoes();
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.red.shade400,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('LIBERAR',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }

  String _fmtHora(TimeOfDay h) =>
      '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';

  Future<void> _escolherHora() async {
    int h = _hora.hour;
    int mnt = _hora.minute;
    await showModalBottomSheet(
      context: context,
      backgroundColor: CoresEleva.azulMedio,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (context) {
        Widget roda(int total, int inicial, void Function(int) aoMudar) {
          return SizedBox(
            width: 84,
            child: ListWheelScrollView.useDelegate(
              controller:
                  FixedExtentScrollController(initialItem: inicial),
              itemExtent: 46,
              physics: FixedExtentScrollPhysics(),
              perspective: 0.004,
              overAndUnderCenterOpacity: 0.35,
              onSelectedItemChanged: aoMudar,
              childDelegate: ListWheelChildLoopingListDelegate(
                children: List.generate(
                  total,
                  (i) => Center(
                    child: Text(
                      i.toString().padLeft(2, '0'),
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: CoresEleva.branco),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Gire para escolher o horário',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                SizedBox(height: 6),
                SizedBox(
                  height: 170,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // faixa central destacada
                      Container(
                        height: 46,
                        margin: EdgeInsets.symmetric(horizontal: 40),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: CoresEleva.dourado, width: 1.4),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          roda(24, h, (i) => h = i),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Text(':',
                                style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    color: CoresEleva.dourado)),
                          ),
                          roda(60, mnt, (i) => mnt = i),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CoresEleva.verde,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26)),
                      textStyle: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    child: Text('CONFIRMAR HORÁRIO'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (mounted) setState(() => _hora = TimeOfDay(hour: h, minute: mnt));
  }

  Future<void> _escolherData() async {
    final agora = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _data ?? agora,
      firstDate: agora,
      lastDate: agora.add(Duration(days: 365)),
      helpText: 'Dia do despertador',
    );
    if (d != null) setState(() => _data = d);
  }

  Future<void> _ativar() async {
    try {
    await DespertadorService.pedirPermissoes();
    String resumo;
    if (_tipo == 'diario') {
      await DespertadorService.agendarDiario(_hora.hour, _hora.minute);
      resumo = 'TODO DIA às ${_fmtHora(_hora)}';
    } else if (_tipo == 'dias') {
      if (_dias.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Escolha pelo menos um dia da semana.')));
        return;
      }
      await DespertadorService.agendarDias(_hora.hour, _hora.minute, _dias);
      resumo = '${_resumoDias()} às ${_fmtHora(_hora)}';
    } else {
      if (_data == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Escolha o dia do despertador.')));
        return;
      }
      final quando = DateTime(_data!.year, _data!.month, _data!.day,
          _hora.hour, _hora.minute);
      if (quando.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Esse horário já passou. Escolha outro.')));
        return;
      }
      await DespertadorService.agendarUnico(quando);
      resumo =
          '${_data!.day.toString().padLeft(2, '0')}/${_data!.month.toString().padLeft(2, '0')} às ${_fmtHora(_hora)}';
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('desp_ativo', true);
    await prefs.setString('desp_tipo', _tipo);
    await prefs.setInt('desp_hora', _hora.hour);
    await prefs.setInt('desp_min', _hora.minute);
    await prefs.setString('desp_data', _data?.toIso8601String() ?? '');
    await prefs.setString(
        'desp_dias', (_dias.toList()..sort()).join(','));
    await prefs.setString('desp_resumo', resumo);
    await prefs.setInt('desp_sonecas', 0); // as 3 sonecas voltam a valer
    if (mounted) {
      setState(() {
        _ativo = true;
        _resumo = resumo;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: CoresEleva.verdeEscuro,
          content: Text('⏰ Despertador ativado: $resumo')));
    }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Colors.red.shade700,
            duration: Duration(seconds: 8),
            content: Text(
                'Não consegui ativar. Detalhe técnico: ${e.toString().substring(0, e.toString().length > 130 ? 130 : e.toString().length)}')));
      }
    }
  }

  Future<void> _desativar() async {
    try {
      await DespertadorService.cancelar();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('desp_ativo', false);
    await prefs.setString('desp_resumo', '');
    if (mounted) {
      setState(() => _ativo = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: CoresEleva.azulMedio,
          content: Text('Despertador desativado. ✅')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(18),
      children: [
        Center(
          child: Icon(Icons.alarm_rounded,
              size: 56, color: CoresEleva.dourado),
        ),
        SizedBox(height: 8),
        Center(
          child: Text(
            'Acorde com a Rádio Eleva',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: CoresEleva.brancoSuave),
          ),
        ),
        SizedBox(height: 18),

        if (_ativo)
          Container(
            margin: EdgeInsets.only(bottom: 14),
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CoresEleva.verdeEscuro.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: CoresEleva.verde, width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.alarm_on_rounded,
                    color: CoresEleva.verde, size: 30),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Despertador ativo: $_resumo',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: CoresEleva.branco)),
                ),
                TextButton(
                  onPressed: _desativar,
                  child: Text('DESATIVAR',
                      style: TextStyle(
                          color: Colors.red.shade300,
                          fontWeight: FontWeight.w800,
                          fontSize: 12)),
                ),
              ],
            ),
          ),

        // Tipo: DIAS DA SEMANA ou UMA VEZ
        Row(
          children: [
            _chipTipo('dias', 'DIAS DA SEMANA', Icons.date_range_rounded),
            SizedBox(width: 10),
            _chipTipo('unico', 'UMA VEZ', Icons.event_rounded),
          ],
        ),
        SizedBox(height: 14),

        if (_tipo == 'dias') _seletorDias(),

        if (_tipo == 'unico')
          _botaoEscolha(
            icone: Icons.calendar_month_rounded,
            rotulo: 'Dia',
            valor: _data == null
                ? 'Escolher o dia'
                : '${_data!.day.toString().padLeft(2, '0')}/${_data!.month.toString().padLeft(2, '0')}/${_data!.year}',
            aoTocar: _escolherData,
          ),
        _botaoEscolha(
          icone: Icons.schedule_rounded,
          rotulo: 'Horário',
          valor: _fmtHora(_hora),
          aoTocar: _escolherHora,
        ),

        // Botão principal logo abaixo do horário
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _ativar,
            style: ElevatedButton.styleFrom(
              backgroundColor: CoresEleva.verde,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
              textStyle:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            icon: Icon(Icons.alarm_add_rounded),
            label: Text(_ativo ? 'ATUALIZAR DESPERTADOR' : 'ATIVAR DESPERTADOR'),
          ),
        ),
        SizedBox(height: 16),
        // ===== PERMISSÕES DO DESPERTADOR =====
        Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
          decoration: BoxDecoration(
            color: CoresEleva.azulMedio,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: _perms.values.every((v) => v)
                    ? CoresEleva.borda
                    : Colors.red.shade300,
                width: _perms.values.every((v) => v) ? 1 : 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_rounded,
                      size: 18, color: CoresEleva.dourado),
                  SizedBox(width: 6),
                  Text('Permissões do despertador',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: CoresEleva.branco)),
                  Spacer(),
                  GestureDetector(
                    onTap: _verificarPermissoes,
                    child: Icon(Icons.refresh_rounded,
                        size: 18, color: CoresEleva.dourado),
                  ),
                ],
              ),
              SizedBox(height: 10),
              _linhaPerm('notificacao', 'Notificações',
                  'Sem ela o alarme não consegue tocar nem aparecer.'),
              _linhaPerm('alarme', 'Alarmes e lembretes',
                  'Sem ela o despertador não toca na hora exata.'),
              _linhaPerm('telacheia', 'Notificações em tela cheia ⭐',
                  'ESSENCIAL: é ela que acende a tela com o botão ADIAR no meio. Sem ela, o alarme só notifica.'),
              _linhaPerm('sobreposicao', 'Aparecer sobre outros apps ⭐',
                  'ESSENCIAL: garante a tela de adiar mesmo com o celular bloqueado.'),
              _linhaPerm('bateria', 'Economia de bateria DESLIGADA ⭐',
                  'IMPORTANTE: mantenha a economia de bateria DESLIGADA para este app. Com ela ligada, o celular segura o alarme e o despertador pode atrasar ou nem tocar.'),
              if (_perms['bateria'] == false)
                Container(
                  margin: EdgeInsets.only(top: 4, bottom: 6),
                  padding: EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Text(
                    '🔋 Ao tocar em LIBERAR, o Android pergunta se pode ignorar a economia de bateria para a Rádio Eleva: responda PERMITIR. Nunca ative "economia de bateria" ou "colocar o app em suspensão" para este app — é isso que faz o despertador falhar.',
                    style: TextStyle(
                        fontSize: 10.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade100),
                  ),
                ),
              if (_perms.values.every((v) => v) && _perms.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 2, bottom: 4),
                  child: Text('Tudo liberado — pode dormir tranquilo! 🌙',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: CoresEleva.verde)),
                ),
            ],
          ),
        ),

        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CoresEleva.avisoFundo,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: CoresEleva.dourado.withOpacity(0.6)),
          ),
          child: Text(
            '😴 Na hora do alarme, a tela acende (mesmo bloqueada) com a logo da rádio, a hora, a saudação do momento e um versículo de motivação — mais os botões grandes ADIAR 5 MINUTOS (até 3 vezes) e PARAR, sem precisar desbloquear o celular. O som sobe suavemente até 80%.\n\nℹ️ Na hora marcada, a tela do celular acende com a Rádio Eleva e a música começa a tocar. Permita tudo o que o app pedir ao ativar. IMPORTANTE: se no horário chegar apenas a notificação (sem a rádio abrir sozinha), ative a permissão de tela cheia: Configurações → Aplicativos → Rádio Eleva → Notificações → "Tela cheia" (ou "Acesso especial → Notificações de tela cheia"). Com ela ligada, o despertador acorda você com a rádio tocando. É preciso internet no horário do alarme.',
            style: TextStyle(
                fontSize: 11.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: CoresEleva.avisoTexto),
          ),
        ),
      ],
    );
  }

  // Rótulos dos dias no padrão Calendar (índice = dom=1 .. sáb=7)
  static const List<String> _abrevDias = [
    '', 'DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB'
  ];

  // Ordem de exibição começando na segunda (mais natural no Brasil)
  static const List<int> _ordemDias = [2, 3, 4, 5, 6, 7, 1];

  String _resumoDias() {
    if (_dias.length == 7) return 'TODO DIA';
    final semana = {2, 3, 4, 5, 6};
    if (_dias.length == 5 && _dias.containsAll(semana)) {
      return 'SEG A SEX';
    }
    if (_dias.length == 2 && _dias.contains(1) && _dias.contains(7)) {
      return 'FIM DE SEMANA';
    }
    final marcados =
        _ordemDias.where((d) => _dias.contains(d)).map((d) => _abrevDias[d]);
    return marcados.join(', ');
  }

  Widget _seletorDias() {
    Widget bolinha(int dia) {
      final marcado = _dias.contains(dia);
      return GestureDetector(
        onTap: () => setState(() {
          if (marcado) {
            _dias.remove(dia);
          } else {
            _dias.add(dia);
          }
        }),
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: marcado ? CoresEleva.botaoPlay : null,
            color: marcado ? null : CoresEleva.azulMedio,
            shape: BoxShape.circle,
            border: Border.all(
                color: marcado ? CoresEleva.verde : CoresEleva.borda,
                width: marcado ? 1.8 : 1),
          ),
          child: Text(
            _abrevDias[dia],
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: marcado ? Colors.white : CoresEleva.brancoSuave,
            ),
          ),
        ),
      );
    }

    void _marcar(Set<int> novos) => setState(() => _dias = {...novos});

    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: CoresEleva.azulMedio,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CoresEleva.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Toque nos dias em que quer acordar',
              style: TextStyle(
                  fontSize: 12, color: CoresEleva.textoFraco)),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _ordemDias.map(bolinha).toList(),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              _atalhoDias('Seg a Sex', () => _marcar({2, 3, 4, 5, 6})),
              SizedBox(width: 6),
              _atalhoDias('Sáb e Dom', () => _marcar({1, 7})),
              SizedBox(width: 6),
              _atalhoDias('Todos', () => _marcar({1, 2, 3, 4, 5, 6, 7})),
              SizedBox(width: 6),
              _atalhoDias('Limpar', () => _marcar({})),
            ],
          ),
        ],
      ),
    );
  }

  Widget _atalhoDias(String rotulo, VoidCallback aoTocar) {
    return Expanded(
      child: GestureDetector(
        onTap: aoTocar,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: CoresEleva.azulProfundo,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: CoresEleva.dourado.withOpacity(0.5)),
          ),
          child: Text(rotulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: CoresEleva.dourado)),
        ),
      ),
    );
  }

  Widget _chipTipo(String valor, String rotulo, IconData icone) {
    final marcado = _tipo == valor;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tipo = valor),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            gradient: marcado ? CoresEleva.botaoPlay : null,
            color: marcado ? null : CoresEleva.azulMedio,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: marcado ? CoresEleva.verde : CoresEleva.borda,
                width: marcado ? 1.8 : 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone,
                  size: 22,
                  color: marcado ? Colors.white : CoresEleva.dourado),
              SizedBox(height: 6),
              Text(rotulo,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                      height: 1.15,
                      color:
                          marcado ? Colors.white : CoresEleva.brancoSuave)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botaoEscolha(
      {required IconData icone,
      required String rotulo,
      required String valor,
      required VoidCallback aoTocar}) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: CoresEleva.azulMedio,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CoresEleva.borda),
      ),
      child: ListTile(
        leading: Icon(icone, color: CoresEleva.dourado),
        title: Text(rotulo,
            style: TextStyle(
                fontSize: 12.5, color: CoresEleva.textoFraco)),
        subtitle: Text(valor,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: CoresEleva.branco)),
        trailing: Icon(Icons.edit_rounded,
            size: 20, color: CoresEleva.dourado),
        onTap: aoTocar,
      ),
    );
  }
}
