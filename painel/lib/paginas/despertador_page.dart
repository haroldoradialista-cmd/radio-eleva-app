import 'package:flutter/material.dart';
import '../servicos/despertador_service.dart';
import '../servicos/despertadores_lista.dart';
import '../tema.dart';

class DespertadorPage extends StatefulWidget {
  DespertadorPage({super.key});
  @override
  State<DespertadorPage> createState() => _DespertadorPageState();
}

class _DespertadorPageState extends State<DespertadorPage> {
  List<Despertador> _lista = [];
  bool _carregando = true;
  Map<String, bool> _perms = {};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    _verificarPermissoes();
    final lista = await DespertadoresLista.carregar();
    if (!mounted) return;
    setState(() {
      _lista = lista;
      _carregando = false;
    });
    await DespertadoresLista.reagendarProximo(_lista);
  }

  Future<void> _salvar() async {
    await DespertadoresLista.salvar(_lista);
    if (mounted) setState(() {});
  }

  Future<void> _verificarPermissoes() async {
    final m = await DespertadorService.statusPermissoes();
    if (mounted) setState(() => _perms = m);
  }

  Future<void> _novo() async {
    final novo = Despertador(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tipo: 'dias',
      hora: 7,
      minuto: 0,
      dias: {2, 3, 4, 5, 6},
      ativo: true,
    );
    final salvou = await _editarNoModal(novo, ehNovo: true);
    if (salvou == true) {
      setState(() => _lista.add(novo));
      await _salvar();
      _aviso('Despertador criado! \u2705');
    }
  }

  Future<void> _editar(int i) async {
    final orig = _lista[i];
    final copia = Despertador.doMapa(orig.paraMapa());
    final salvou = await _editarNoModal(copia, ehNovo: false);
    if (salvou == true) {
      setState(() => _lista[i] = copia);
      await _salvar();
      _aviso('Despertador atualizado! \u2705');
    }
  }

  Future<void> _alternarAtivo(int i, bool valor) async {
    setState(() => _lista[i].ativo = valor);
    await _salvar();
  }

  Future<void> _apagar(int i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CoresEleva.azulProfundo,
        title: Text('Apagar despertador?',
            style: TextStyle(color: CoresEleva.branco)),
        content: Text('Essa acao nao pode ser desfeita.',
            style: TextStyle(color: CoresEleva.brancoSuave)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar',
                  style: TextStyle(color: CoresEleva.textoFraco))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Apagar',
                  style: TextStyle(
                      color: Colors.red.shade300,
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _lista.removeAt(i));
      await _salvar();
      _aviso('Despertador apagado.');
    }
  }

  void _aviso(String txt) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(txt),
      backgroundColor: CoresEleva.verdeEscuro,
      duration: Duration(seconds: 2),
    ));
  }

  String _fmtHora(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  static const _nomesDias = {
    1: 'DOM', 2: 'SEG', 3: 'TER', 4: 'QUA', 5: 'QUI', 6: 'SEX', 7: 'SAB'
  };

  String _resumoDias(Set<int> dias) {
    if (dias.isEmpty) return 'nenhum dia';
    final semana = {2, 3, 4, 5, 6};
    final fds = {1, 7};
    if (dias.length == 7) return 'Todos os dias';
    if (dias.length == semana.length && dias.containsAll(semana)) {
      return 'Seg a Sex';
    }
    if (dias.length == fds.length && dias.containsAll(fds)) {
      return 'Sab e Dom';
    }
    final ordem = [2, 3, 4, 5, 6, 7, 1];
    final marcados =
        ordem.where((d) => dias.contains(d)).map((d) => _nomesDias[d]).toList();
    return marcados.join(', ');
  }

  String _resumoDespertador(Despertador d) {
    if (d.tipo == 'unico') {
      final data = d.data == null ? null : DateTime.tryParse(d.data!);
      final quando = data == null
          ? 'uma vez'
          : '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}';
      return '$quando as ${_fmtHora(d.hora, d.minuto)}';
    }
    return '${_resumoDias(d.dias)} as ${_fmtHora(d.hora, d.minuto)}';
  }

  Future<bool?> _editarNoModal(Despertador d, {required bool ehNovo}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditorDespertador(
        despertador: d,
        ehNovo: ehNovo,
        fmtHora: _fmtHora,
      ),
    );
  }

  Widget _linhaPerm(String chave, String titulo, String porque) {
    // ATENCAO: antes isso usava "?? true" e mostrava tudo verde mesmo sem
    // permissao. Agora, se nao der para confirmar, mostra como PENDENTE.
    final ok = _perms[chave] ?? false;
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
                        color:
                            ok ? CoresEleva.brancoSuave : Colors.red.shade100)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoresEleva.azulMedio,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Despertador',
            style: TextStyle(
                color: CoresEleva.branco, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: CoresEleva.dourado),
      ),
      body: _carregando
          ? Center(
              child: CircularProgressIndicator(color: CoresEleva.dourado))
          : SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 6),
                  Icon(Icons.alarm, size: 64, color: CoresEleva.dourado),
                  SizedBox(height: 8),
                  Text('Acorde com a Radio Eleva',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: CoresEleva.branco)),
                  SizedBox(height: 18),
                  if (_lista.isEmpty)
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: CoresEleva.azulProfundo,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.alarm_off,
                              size: 40, color: CoresEleva.textoFraco),
                          SizedBox(height: 10),
                          Text('Nenhum despertador ainda.',
                              style: TextStyle(
                                  color: CoresEleva.brancoSuave,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          SizedBox(height: 4),
                          Text(
                              'Toque em "Novo despertador" para criar o primeiro.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: CoresEleva.textoFraco, fontSize: 12)),
                        ],
                      ),
                    )
                  else
                    ...List.generate(_lista.length, (i) => _cardDespertador(i)),
                  SizedBox(height: 14),
                  _botaoNovo(),
                  SizedBox(height: 22),
                  _painelPermissoes(),
                ],
              ),
            ),
          ),
    );
  }

  Widget _cardDespertador(int i) {
    final d = _lista[i];
    final numero = i + 1;
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: CoresEleva.azulProfundo,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: d.ativo
              ? CoresEleva.verde.withOpacity(0.8)
              : Colors.white.withOpacity(0.08),
          width: 1.4,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: CoresEleva.dourado.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Despertador $numero',
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: CoresEleva.dourado)),
                      ),
                      SizedBox(height: 8),
                      Text(_fmtHora(d.hora, d.minuto),
                          style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                              color: d.ativo
                                  ? CoresEleva.branco
                                  : CoresEleva.textoFraco)),
                      SizedBox(height: 3),
                      Text(_resumoDespertador(d),
                          style: TextStyle(
                              fontSize: 12.5,
                              color: CoresEleva.brancoSuave)),
                    ],
                  ),
                ),
                Switch(
                  value: d.ativo,
                  activeColor: CoresEleva.verde,
                  onChanged: (v) => _alternarAtivo(i, v),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withOpacity(0.06)),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _editar(i),
                  icon: Icon(Icons.edit, size: 16, color: CoresEleva.dourado),
                  label: Text('Editar',
                      style: TextStyle(
                          color: CoresEleva.dourado,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              Container(
                  width: 1, height: 22, color: Colors.white.withOpacity(0.06)),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _apagar(i),
                  icon: Icon(Icons.delete_outline,
                      size: 16, color: Colors.red.shade300),
                  label: Text('Apagar',
                      style: TextStyle(
                          color: Colors.red.shade300,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _botaoNovo() {
    return GestureDetector(
      onTap: _novo,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [CoresEleva.verde, CoresEleva.azulVivo]),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
                color: CoresEleva.verde.withOpacity(0.35),
                blurRadius: 12,
                offset: Offset(0, 4))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_alarm, color: Colors.white),
            SizedBox(width: 8),
            Text('Novo despertador',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _painelPermissoes() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CoresEleva.azulProfundo,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 18, color: CoresEleva.dourado),
              SizedBox(width: 8),
              Expanded(
                child: Text('Permissoes do despertador',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: CoresEleva.branco)),
              ),
              GestureDetector(
                onTap: _verificarPermissoes,
                child:
                    Icon(Icons.refresh, size: 18, color: CoresEleva.textoFraco),
              ),
            ],
          ),
          SizedBox(height: 12),
          _linhaPerm('notificacao', 'Notificacoes',
              'Precisa estar ligada para o alarme aparecer.'),
          _linhaPerm('alarme', 'Alarmes e lembretes',
              'Deixa o alarme tocar na hora exata.'),
          _linhaPerm('telacheia', 'Notificacoes em tela cheia \u2b50',
              'Faz a tela do alarme abrir sozinha ao tocar.'),
          _linhaPerm('sobreposicao', 'Aparecer sobre outros apps \u2b50',
              'SEM ESTA, a tela do despertador (versiculo, soneca, parar) '
              'NAO abre com o celular bloqueado.'),
          _linhaPerm('bateria', 'Economia de bateria liberada \u2b50',
              'Impede o celular de segurar o alarme.'),
          SizedBox(height: 6),
          Text(
              'Dica: nos ajustes do celular, desligue a "economia de bateria" '
              'para o app da Radio Eleva, para o despertador nunca falhar.',
              style: TextStyle(
                  fontSize: 10.5, height: 1.4, color: CoresEleva.textoFraco)),
        ],
      ),
    );
  }
}

// ============================================================
// EDITOR DE UM DESPERTADOR (modal deslizante)
// ============================================================

class _EditorDespertador extends StatefulWidget {
  final Despertador despertador;
  final bool ehNovo;
  final String Function(int, int) fmtHora;
  const _EditorDespertador({
    required this.despertador,
    required this.ehNovo,
    required this.fmtHora,
  });

  @override
  State<_EditorDespertador> createState() => _EditorDespertadorState();
}

class _EditorDespertadorState extends State<_EditorDespertador> {
  late String _tipo;
  late int _hora;
  late int _minuto;
  late Set<int> _dias;
  DateTime? _data;

  static const _diasOrdem = [2, 3, 4, 5, 6, 7, 1];
  static const _nomes = {
    1: 'DOM', 2: 'SEG', 3: 'TER', 4: 'QUA', 5: 'QUI', 6: 'SEX', 7: 'SAB'
  };

  @override
  void initState() {
    super.initState();
    final d = widget.despertador;
    _tipo = d.tipo;
    _hora = d.hora;
    _minuto = d.minuto;
    _dias = Set<int>.from(d.dias);
    _data = d.data == null ? null : DateTime.tryParse(d.data!);
  }

  Future<void> _escolherHora() async {
    final r = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hora, minute: _minuto),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: CoresEleva.dourado,
            surface: CoresEleva.azulProfundo,
            onSurface: CoresEleva.branco,
          ),
        ),
        child: child!,
      ),
    );
    if (r != null) {
      setState(() {
        _hora = r.hour;
        _minuto = r.minute;
      });
    }
  }

  Future<void> _escolherData() async {
    final agora = DateTime.now();
    final r = await showDatePicker(
      context: context,
      initialDate: _data ?? agora,
      firstDate: agora,
      lastDate: agora.add(Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: CoresEleva.dourado,
            surface: CoresEleva.azulProfundo,
            onSurface: CoresEleva.branco,
          ),
        ),
        child: child!,
      ),
    );
    if (r != null) setState(() => _data = r);
  }

  bool get _podeSalvar {
    if (_tipo == 'dias') return _dias.isNotEmpty;
    if (_tipo == 'unico') return _data != null;
    return false;
  }

  void _salvar() {
    if (!_podeSalvar) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_tipo == 'dias'
            ? 'Escolha pelo menos um dia da semana.'
            : 'Escolha a data.'),
        backgroundColor: Colors.red.shade400,
      ));
      return;
    }
    final d = widget.despertador;
    d.tipo = _tipo;
    d.hora = _hora;
    d.minuto = _minuto;
    d.dias = _dias;
    d.data = _tipo == 'unico' ? _data?.toIso8601String() : null;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CoresEleva.azulMedio,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).viewPadding.bottom +
            32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(widget.ehNovo ? 'Novo despertador' : 'Editar despertador',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: CoresEleva.branco)),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child:
                      _botaoTipo('dias', Icons.calendar_month, 'DIAS DA SEMANA'),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _botaoTipo('unico', Icons.event, 'UMA VEZ'),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (_tipo == 'dias') _blocoDias() else _blocoUmaVez(),
            SizedBox(height: 14),
            _blocoHorario(),
            SizedBox(height: 18),
            GestureDetector(
              onTap: _salvar,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [CoresEleva.verde, CoresEleva.azulVivo]),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text(widget.ehNovo ? 'CRIAR' : 'SALVAR',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _botaoTipo(String tipo, IconData icone, String texto) {
    final sel = _tipo == tipo;
    return GestureDetector(
      onTap: () => setState(() => _tipo = tipo),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: sel
              ? LinearGradient(colors: [CoresEleva.verde, CoresEleva.azulVivo])
              : null,
          color: sel ? null : CoresEleva.azulProfundo,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color:
                  sel ? Colors.transparent : Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          children: [
            Icon(icone,
                color: sel ? Colors.white : CoresEleva.dourado, size: 22),
            SizedBox(height: 6),
            Text(texto,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: sel ? Colors.white : CoresEleva.brancoSuave)),
          ],
        ),
      ),
    );
  }

  Widget _blocoDias() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CoresEleva.azulProfundo,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Toque nos dias em que quer acordar',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: CoresEleva.brancoSuave)),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _diasOrdem.map((d) {
              final on = _dias.contains(d);
              return GestureDetector(
                onTap: () => setState(() {
                  if (on) {
                    _dias.remove(d);
                  } else {
                    _dias.add(d);
                  }
                }),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: on
                        ? LinearGradient(
                            colors: [CoresEleva.verde, CoresEleva.azulVivo])
                        : null,
                    color: on ? null : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: on
                            ? Colors.transparent
                            : CoresEleva.dourado.withOpacity(0.4)),
                  ),
                  child: Text(_nomes[d]!,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: on ? Colors.white : CoresEleva.brancoSuave)),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _atalho('Seg a Sex', {2, 3, 4, 5, 6}),
              _atalho('Sab e Dom', {1, 7}),
              _atalho('Todos', {1, 2, 3, 4, 5, 6, 7}),
              _atalhoLimpar(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _atalho(String texto, Set<int> conjunto) {
    return GestureDetector(
      onTap: () => setState(() => _dias = Set<int>.from(conjunto)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CoresEleva.dourado.withOpacity(0.5)),
        ),
        child: Text(texto,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: CoresEleva.dourado)),
      ),
    );
  }

  Widget _atalhoLimpar() {
    return GestureDetector(
      onTap: () => setState(() => _dias = <int>{}),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CoresEleva.dourado.withOpacity(0.5)),
        ),
        child: Text('Limpar',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: CoresEleva.dourado)),
      ),
    );
  }

  Widget _blocoUmaVez() {
    final txt = _data == null
        ? 'Escolher a data'
        : '${_data!.day.toString().padLeft(2, '0')}/${_data!.month.toString().padLeft(2, '0')}/${_data!.year}';
    return GestureDetector(
      onTap: _escolherData,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CoresEleva.azulProfundo,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.event, color: CoresEleva.dourado),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Data',
                      style: TextStyle(
                          fontSize: 11, color: CoresEleva.textoFraco)),
                  SizedBox(height: 2),
                  Text(txt,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: CoresEleva.branco)),
                ],
              ),
            ),
            Icon(Icons.edit, size: 18, color: CoresEleva.dourado),
          ],
        ),
      ),
    );
  }

  Widget _blocoHorario() {
    return GestureDetector(
      onTap: _escolherHora,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CoresEleva.azulProfundo,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, color: CoresEleva.dourado),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Horario',
                      style: TextStyle(
                          fontSize: 11, color: CoresEleva.textoFraco)),
                  SizedBox(height: 2),
                  Text(widget.fmtHora(_hora, _minuto),
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: CoresEleva.branco)),
                ],
              ),
            ),
            Icon(Icons.edit, size: 18, color: CoresEleva.dourado),
          ],
        ),
      ),
    );
  }
}
