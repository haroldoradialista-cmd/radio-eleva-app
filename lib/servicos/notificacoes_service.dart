import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notificações push da Rádio Eleva.
/// Todo app instalado entra no grupo "ouvintes" e recebe os avisos
/// enviados pela emissora — mesmo com o app fechado.
class NotificacoesService {
  /// Canal com o som característico da rádio.
  /// O id abaixo é reescrito na compilação com a "impressão digital" do
  /// arquivo som_eleva.mp3: trocou o som no repositório, nasce um canal
  /// novo automaticamente (o Android congela o som do canal na criação).
  static const canalId = 'eleva_som_v2';

  static Future<void> iniciar() async {
    try {
      // Canal com o som da Eleva (arquivo som_eleva em res/raw)
      final plugin = FlutterLocalNotificationsPlugin();
      final android = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(AndroidNotificationChannel(
        canalId,
        'Avisos da Rádio Eleva',
        description: 'Novidades, promoções e recados da Rádio Eleva',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('som_eleva'),
        playSound: true,
      ));
    } catch (_) {}
    try {
      await Firebase.initializeApp();
      final fcm = FirebaseMessaging.instance;
      await fcm.requestPermission(alert: true, badge: true, sound: true);
      await fcm.subscribeToTopic('ouvintes');
    } catch (_) {
      // Sem o google-services.json o app segue funcionando, só sem push
    }
  }
}
