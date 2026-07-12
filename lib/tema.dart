import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controle global do tema (true = escuro). A escolha fica salva no aparelho.
final ValueNotifier<bool> modoEscuroNotifier = ValueNotifier(true);

Future<void> carregarTemaSalvo() async {
  try {
    final p = await SharedPreferences.getInstance();
    modoEscuroNotifier.value = p.getBool('modo_escuro') ?? true;
  } catch (_) {}
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
      escuro ? const Color(0xFF0E0857) : const Color(0xFFEDEFFC);
  static Color get azulMedio =>
      escuro ? const Color(0xFF201780) : const Color(0xFFFFFFFF);
  static Color get azulVivo => const Color(0xFF1E9BFF);
  static Color get verde => const Color(0xFF35C733);
  static Color get verdeEscuro => const Color(0xFF1E8A2E);
  static Color get dourado =>
      escuro ? const Color(0xFFFFD65A) : const Color(0xFFA9760A);
  static Color get branco =>
      escuro ? Colors.white : const Color(0xFF131046);
  static Color get brancoSuave =>
      escuro ? const Color(0xFFE9E7FF) : const Color(0xFF201C4E);
  static Color get textoFraco =>
      escuro ? Colors.white60 : const Color(0xFF474371);
  static Color get borda =>
      escuro ? Colors.white24 : const Color(0x3D131046);
  // Aviso destacado (ex.: aviso do chat público)
  static Color get avisoFundo =>
      escuro ? const Color(0xFFFFD65A).withOpacity(0.12)
             : const Color(0xFFFFF1C9);
  static Color get avisoTexto =>
      escuro ? const Color(0xFFE9E7FF) : const Color(0xFF4A3800);
  static Color get navFundo =>
      escuro ? const Color(0xFF0A053F) : Colors.white;

  static LinearGradient get fundoApp => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: escuro
            ? const [Color(0xFF1D14A8), Color(0xFF0E0857), Color(0xFF060330)]
            : const [Color(0xFFFFFFFF), Color(0xFFF2F4FE), Color(0xFFE3E7FA)],
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
