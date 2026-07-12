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

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
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
    });
  }

  String _fmtHora(TimeOfDay h) =>
      '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';

  Future<void> _escolherHora() async {
    final h = await showTimePicker(
      context: context,
      initialTime: _hora,
      helpText: 'Horário do despertador',
    );
    if (h != null) setState(() => _hora = h);
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
    if (mounted) {
      setState(() {
        _ativo = true;
        _resumo = resumo;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: CoresEleva.verdeEscuro,
          content: Text('⏰ Despertador ativado: $resumo')));
    }
  }

  Future<void> _desativar() async {
    await DespertadorService.cancelar();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('desp_ativo', false);
    if (mounted) {
      setState(() => _ativo = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: CoresEleva.azulMedio,
          content: Text('Despertador desativado.')));
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
        SizedBox(height: 16),

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
            'ℹ️ Na hora marcada, a tela do celular acende com a Rádio Eleva e a música começa a tocar. Se o Android pedir permissão de "Alarmes e lembretes" ou de notificação, toque em Permitir. É preciso estar conectado à internet no horário do alarme.',
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
