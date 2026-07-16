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
  String _tipo = 'diario'; // 'diario' ou 'unico'
  TimeOfDay _hora = TimeOfDay(hour: 7, minute: 0);
  DateTime? _data;
  bool _ativo = false;
  String _resumo = '';
  int _volume = 85; // volume do despertar (% do canal de alarme)
  bool _telaCheiaOk = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    DespertadorService.podeTelaCheia().then((ok) {
      if (mounted) setState(() => _telaCheiaOk = ok);
    });
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _ativo = prefs.getBool('desp_ativo') ?? false;
      _tipo = prefs.getString('desp_tipo') ?? 'diario';
      _hora = TimeOfDay(
          hour: prefs.getInt('desp_hora') ?? 7,
          minute: prefs.getInt('desp_min') ?? 0);
      final d = prefs.getString('desp_data') ?? '';
      _data = d.isEmpty ? null : DateTime.tryParse(d);
      _resumo = prefs.getString('desp_resumo') ?? '';
      _volume = prefs.getInt('desp_volume') ?? 85;
    });
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
    await prefs.setString('desp_resumo', resumo);
    await prefs.setInt('desp_volume', _volume);
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
            'Acorde com a Rádio Eleva tocando,\nmesmo com o app fechado.',
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

        // Tipo: TODO DIA ou UMA VEZ
        Row(
          children: [
            _chipTipo('diario', 'TODO DIA', Icons.repeat_rounded),
            SizedBox(width: 8),
            _chipTipo('unico', 'UMA VEZ', Icons.event_rounded),
          ],
        ),
        SizedBox(height: 14),

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
        if (!_telaCheiaOk)
          Container(
            margin: EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.red.shade900.withOpacity(0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.red.shade300, width: 1.4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.red.shade200, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Falta uma permissão para o despertador acordar você',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Colors.red.shade100),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'Sem ela, o alarme só manda uma notificação em vez de abrir a tela com os botões de adiar e parar.',
                  style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: CoresEleva.brancoSuave),
                ),
                SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await DespertadorService.abrirPermissaoTelaCheia();
                      await Future.delayed(Duration(seconds: 1));
                      final ok = await DespertadorService.podeTelaCheia();
                      if (mounted) setState(() => _telaCheiaOk = ok);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22)),
                      textStyle: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                    child: Text('🔓 LIBERAR AGORA'),
                  ),
                ),
              ],
            ),
          ),

        SizedBox(height: 4),

        // ===== VOLUME DO DESPERTAR =====
        Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.fromLTRB(14, 10, 14, 4),
          decoration: BoxDecoration(
            color: CoresEleva.azulMedio,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: CoresEleva.borda),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                      _volume <= 35
                          ? Icons.volume_mute_rounded
                          : _volume <= 70
                              ? Icons.volume_down_rounded
                              : Icons.volume_up_rounded,
                      color: CoresEleva.dourado,
                      size: 20),
                  SizedBox(width: 8),
                  Text('Volume do despertar',
                      style: TextStyle(
                          fontSize: 12.5, color: CoresEleva.textoFraco)),
                  Spacer(),
                  Text('$_volume%',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: CoresEleva.dourado)),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: CoresEleva.dourado,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: CoresEleva.dourado,
                  overlayColor: CoresEleva.dourado.withOpacity(0.15),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: _volume.toDouble(),
                  min: 20,
                  max: 100,
                  divisions: 16,
                  onChanged: (v) => setState(() => _volume = v.round()),
                  onChangeEnd: (v) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('desp_volume', v.round());
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: 2, bottom: 6),
                child: Text(
                  'O celular ajusta o volume do alarme sozinho na hora de despertar. Durante o despertar, dá para abaixar pelo botão 🔉 da notificação ou pelas teclas de volume.',
                  style: TextStyle(
                      fontSize: 10.5,
                      height: 1.4,
                      color: CoresEleva.textoFraco),
                ),
              ),
            ],
          ),
        ),

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
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CoresEleva.avisoFundo,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: CoresEleva.dourado.withOpacity(0.6)),
          ),
          child: Text(
            '😴 SONECA: na hora do alarme, a tela acende (mesmo bloqueada) com os botões grandes ADIAR 5 MINUTOS (até 3 vezes), a barra de volume e PARAR — sem precisar desbloquear o celular.\n\nℹ️ Na hora marcada, a tela do celular acende com a Rádio Eleva e a música começa a tocar. Permita tudo o que o app pedir ao ativar. IMPORTANTE: se no horário chegar apenas a notificação (sem a rádio abrir sozinha), ative a permissão de tela cheia: Configurações → Aplicativos → Rádio Eleva → Notificações → "Tela cheia" (ou "Acesso especial → Notificações de tela cheia"). Com ela ligada, o despertador acorda você com a rádio tocando. É preciso internet no horário do alarme.',
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

  Widget _chipTipo(String valor, String rotulo, IconData icone) {
    final marcado = _tipo == valor;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tipo = valor),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: marcado ? CoresEleva.botaoPlay : null,
            color: marcado ? null : CoresEleva.azulMedio,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: marcado ? CoresEleva.verde : CoresEleva.borda,
                width: marcado ? 1.8 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone,
                  size: 18,
                  color: marcado ? Colors.white : CoresEleva.dourado),
              SizedBox(width: 6),
              Text(rotulo,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
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
