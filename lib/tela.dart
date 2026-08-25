import 'package:flutter/material.dart';

/// ADAPTAÇÃO A TELAS GRANDES
///
/// O app foi desenhado para celular. Em tablet, multimídia de carro e TV a
/// tela é muito mais larga — se o conteúdo simplesmente esticasse, os textos
/// ficariam minúsculos numa faixa enorme e as imagens deformadas.
///
/// Aqui centralizamos o conteúdo numa largura confortável de leitura e
/// aumentamos um pouco os tamanhos, para continuar legível de longe
/// (principalmente na TV, que é vista a metros de distância).
class Tela {
  /// Largura máxima confortável para o conteúdo principal
  static const double larguraMaxima = 760;

  static double largura(BuildContext c) => MediaQuery.of(c).size.width;

  /// celular comum
  static bool ehCelular(BuildContext c) => largura(c) < 600;

  /// tablet ou multimídia de carro
  static bool ehTablet(BuildContext c) =>
      largura(c) >= 600 && largura(c) < 1100;

  /// TV ou monitor grande
  static bool ehTv(BuildContext c) => largura(c) >= 1100;

  /// tela grande de qualquer tipo
  static bool ehGrande(BuildContext c) => largura(c) >= 600;

  /// Fator para aumentar textos e ícones em telas grandes.
  /// Na TV o conteúdo é visto de longe, então cresce um pouco mais.
  static double escala(BuildContext c) {
    final l = largura(c);
    if (l >= 1400) return 1.35;
    if (l >= 1100) return 1.25;
    if (l >= 900) return 1.15;
    if (l >= 600) return 1.08;
    return 1.0;
  }

  /// Quantas colunas usar em listas (promoções, notícias)
  static int colunas(BuildContext c) {
    final l = largura(c);
    if (l >= 1400) return 3;
    if (l >= 900) return 2;
    return 1;
  }
}

/// Centraliza o conteúdo numa largura confortável quando a tela é grande.
/// Em celular não muda nada — o conteúdo ocupa a tela inteira, como sempre.
class ConteudoCentral extends StatelessWidget {
  final Widget child;
  final double? larguraMaxima;
  const ConteudoCentral({super.key, required this.child, this.larguraMaxima});

  @override
  Widget build(BuildContext context) {
    if (!Tela.ehGrande(context)) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: larguraMaxima ?? Tela.larguraMaxima),
        child: child,
      ),
    );
  }
}
