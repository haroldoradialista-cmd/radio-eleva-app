import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'paginas/home_page.dart';
import 'paginas/programacao_page.dart';
import 'paginas/chat_page.dart';
import 'paginas/noticias_page.dart';
import 'paginas/pedidos_page.dart';
import 'servicos/config_service.dart';
import 'tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'br.com.radioeleva.audio',
    androidNotificationChannelName: 'Rádio Eleva',
    androidNotificationOngoing: true,
  );
  ConfigService.instancia.carregar();
  runApp(const RadioElevaApp());
}

class RadioElevaApp extends StatelessWidget {
  const RadioElevaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rádio Eleva',
      debugShowCheckedModeBanner: false,
      theme: temaEleva(),
      home: const TelaPrincipal(),
    );
  }
}

class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});
  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  int _abaAtual = 0;

  final _paginas = const [
    HomePage(),
    ProgramacaoPage(),
    ChatPage(),
    NoticiasPage(),
    PedidosPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _abaAtual, children: _paginas),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF04101F),
          border:
              Border(top: BorderSide(color: CoresEleva.dourado, width: 1.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _abaAtual,
          onTap: (i) => setState(() => _abaAtual = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: CoresEleva.dourado,
          unselectedItemColor: Colors.white54,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded), label: 'Início'),
            BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month_rounded),
                label: 'Programação'),
            BottomNavigationBarItem(
                icon: Icon(Icons.forum_rounded), label: 'Chat'),
            BottomNavigationBarItem(
                icon: Icon(Icons.newspaper_rounded), label: 'Notícias'),
            BottomNavigationBarItem(
                icon: Icon(Icons.music_note_rounded), label: 'Pedidos'),
          ],
        ),
      ),
    );
  }
}
