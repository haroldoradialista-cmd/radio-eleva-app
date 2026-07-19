import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controle global do tema (true = escuro). A escolha fica salva no aparelho.
final ValueNotifier<bool> modoEscuroNotifier = ValueNotifier(false);

Future<void> carregarTemaSalvo() async {
  try {
    final p = await SharedPreferences.getInstance();
    // Migração para o novo padrão CLARO: se o app ainda não passou por
    // esta migração, começa no claro (independente do que estava salvo).
    // Depois disso, respeita a escolha manual do usuário normalmente.
    final jaMigrou = p.getBool('migrou_tema_claro') ?? false;
    if (!jaMigrou) {
      modoEscuroNotifier.value = false; // começa claro
      await p.setBool('modo_escuro', false);
      await p.setBool('migrou_tema_claro', true);
    } else {
      modoEscuroNotifier.value = p.getBool('modo_escuro') ?? false;
    }
  } catch (_) {
    modoEscuroNotifier.value = false;
  }
  CoresEleva.escuro = modoEscuroNotifier.value;
}

Future<void> alternarTema() async {
  modoEscuroNotifier.value = !modoEscuroNotifier.value;
  CoresEleva.escuro = modoEscuroNotifier.value;
  try {
    final p = await SharedPreferences.getInstance();
    await p.setBool('modo_escuro', modoEscuroNotifier.value);
  } catch (_) {}
}

/// Paleta oficial da Rádio Eleva — muda conforme o modo claro/escuro
class CoresEleva {
  static bool escuro = true;

  static Color get azulProfundo =>
      escuro ? const Color(0xFF0E0857) : const Color(0xFFFFD814);
  static Color get azulMedio =>
      escuro ? const Color(0xFF201780) : const Color(0xFFFFFDF5);
  static Color get azulVivo => const Color(0xFF1E9BFF);
  static Color get verde => const Color(0xFF35C733);
  static Color get verdeEscuro => const Color(0xFF1E8A2E);
  static Color get dourado =>
      escuro ? const Color(0xFFFFD65A) : const Color(0xFF7A4E00);
  static Color get branco =>
      escuro ? Colors.white : const Color(0xFF120A38);
  static Color get brancoSuave =>
      escuro ? const Color(0xFFE9E7FF) : const Color(0xFF241A52);
  static Color get textoFraco =>
      escuro ? Colors.white60 : const Color(0xFF5A4A1E);
  static Color get borda =>
      escuro ? Colors.white24 : const Color(0x33120A38);
  // Aviso destacado (ex.: aviso do chat público)
  static Color get avisoFundo =>
      escuro ? const Color(0xFFFFD65A).withOpacity(0.12)
             : const Color(0xFFFFF1C9);
  static Color get avisoTexto =>
      escuro ? const Color(0xFFE9E7FF) : const Color(0xFF4A3800);
  static Color get navFundo =>
      escuro ? const Color(0xFF0A053F) : const Color(0xFFFFFFFF);

  static LinearGradient get fundoApp => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: escuro
            ? const [Color(0xFF1D14A8), Color(0xFF0E0857), Color(0xFF060330)]
            : const [Color(0xFFFFE04D), Color(0xFFFFD814), Color(0xFFF7C500)],
      );

  static LinearGradient get botaoPlay => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF35C733), Color(0xFF1E9BFF)],
      );
}

ThemeData temaEleva() {
  final e = CoresEleva.escuro;
  return ThemeData(
    useMaterial3: true,
    brightness: e ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: CoresEleva.azulProfundo,
    colorScheme: e
        ? ColorScheme.dark(
            primary: CoresEleva.verde,
            secondary: CoresEleva.dourado,
            surface: CoresEleva.azulMedio,
          )
        : ColorScheme.light(
            primary: CoresEleva.verde,
            secondary: CoresEleva.dourado,
            surface: CoresEleva.azulMedio,
          ),
    fontFamily: 'Roboto',
    textTheme: TextTheme(
      titleLarge: TextStyle(
          fontWeight: FontWeight.w800,
          color: CoresEleva.branco,
          letterSpacing: 0.3),
      bodyMedium: TextStyle(color: CoresEleva.brancoSuave, height: 1.35),
    ),
  );
}


/// Fundo padrão do app: gradiente + marca d'água "RÁDIO ELEVA" repetida
/// na diagonal, bem sutil, dando profundidade ao fundo liso.
class FundoEleva extends StatelessWidget {
  final Widget child;
  const FundoEleva({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final marca = CoresEleva.escuro
        ? 'assets/marca_dagua_escura.png'
        : 'assets/marca_dagua_clara.png';
    return Container(
      decoration: BoxDecoration(gradient: CoresEleva.fundoApp),
      child: Stack(
        children: [
          // marca d'água em mosaico cobrindo todo o fundo
          Positioned.fill(
            child: Image.asset(
              marca,
              repeat: ImageRepeat.repeat,
              alignment: Alignment.topLeft,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
