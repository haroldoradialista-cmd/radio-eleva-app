import 'package:flutter/material.dart';

// Paleta oficial derivada da logo da Rádio Eleva
class CoresEleva {
  static const Color azulProfundo = Color(0xFF071A33); // fundo principal
  static const Color azulMedio = Color(0xFF0D2B52);
  static const Color azulVivo = Color(0xFF1E9BFF);
  static const Color verde = Color(0xFF35C733);
  static const Color verdeEscuro = Color(0xFF1E8A2E);
  static const Color dourado = Color(0xFFE6B93F);
  static const Color branco = Color(0xFFFFFFFF);
  static const Color brancoSuave = Color(0xFFE8EEF6);

  static const LinearGradient fundoApp = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A2140), azulProfundo, Color(0xFF041020)],
  );

  static const LinearGradient botaoPlay = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [verde, azulVivo],
  );
}

ThemeData temaEleva() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: CoresEleva.azulProfundo,
    colorScheme: const ColorScheme.dark(
      primary: CoresEleva.verde,
      secondary: CoresEleva.dourado,
      surface: CoresEleva.azulMedio,
    ),
    fontFamily: 'Roboto',
    textTheme: const TextTheme(
      titleLarge: TextStyle(
          fontWeight: FontWeight.w800,
          color: CoresEleva.branco,
          letterSpacing: 0.3),
      bodyMedium: TextStyle(color: CoresEleva.brancoSuave, height: 1.35),
    ),
  );
}
