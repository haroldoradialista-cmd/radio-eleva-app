import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../app_config.dart';

/// Banner de anúncios do Google (AdMob) — retângulo reduzido no topo das abas.
/// Enquanto não há anúncio para exibir, o espaço fica invisível.
class AnuncioBanner extends StatefulWidget {
  AnuncioBanner({super.key});
  @override
  State<AnuncioBanner> createState() => _AnuncioBannerState();
}

class _AnuncioBannerState extends State<AnuncioBanner>
    with AutomaticKeepAliveClientMixin {
  BannerAd? _ad;
  bool _pronto = false;
  static bool _motorLigado = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    try {
      if (!_motorLigado) {
        await MobileAds.instance.initialize();
        _motorLigado = true;
      }
      _carregarAnuncio();
    } catch (_) {
      // Se o motor de anúncios falhar, o app segue vivo sem anúncios
    }
  }

  void _carregarAnuncio() {
    _ad = BannerAd(
      adUnitId: kAdmobBannerId,
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _pronto = true);
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_pronto || _ad == null) return SizedBox.shrink();
    return Container(
      width: double.infinity,
      height: _ad!.size.height.toDouble(),
      alignment: Alignment.center,
      color: Colors.transparent,
      child: SizedBox(
        width: _ad!.size.width.toDouble(),
        height: _ad!.size.height.toDouble(),
        child: AdWidget(ad: _ad!),
      ),
    );
  }
}
