import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Notificações push da Rádio Eleva.
/// Todo app instalado entra no grupo "ouvintes" e recebe os avisos
/// enviados pela emissora — mesmo com o app fechado.
class NotificacoesService {
  static Future<void> iniciar() async {
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
