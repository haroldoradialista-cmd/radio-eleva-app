#!/usr/bin/env bash
# Prepara a estrutura Android do projeto na nuvem (GitHub Actions)
set -e

# 1. Gera a pasta android/ preservando lib/ e pubspec.yaml existentes
flutter create --org br.com.radioeleva --project-name radio_eleva --platforms android .

M=android/app/src/main/AndroidManifest.xml

# 2. Permissões (internet, áudio em segundo plano e notificações)
sed -i 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <uses-permission android:name="android.permission.WAKE_LOCK"/>\n    <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>\n    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>\n    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>\n    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>\n    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>\n    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>\n    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>\n    <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>\n    <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>\n    <uses-permission android:name="android.permission.VIBRATE"/>\n    <uses-permission android:name="android.permission.WAKE_LOCK"/>\n    <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>\n    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>\n    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>\n    <application#' "$M"

# 3. Serviço de áudio (notificação com play/pause e tocar com tela desligada)
sed -i 's#</application>#    <service android:name="com.ryanheise.audioservice.AudioService" android:foregroundServiceType="mediaPlayback" android:exported="true">\n            <intent-filter>\n                <action android:name="android.media.browse.MediaBrowserService"/>\n            </intent-filter>\n        </service>\n        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver" android:exported="true">\n            <intent-filter>\n                <action android:name="android.intent.action.MEDIA_BUTTON"/>\n            </intent-filter>\n        </receiver>\n    </application>#' "$M"

# 4. Nome do app na tela do celular
sed -i 's#android:label="radio_eleva"#android:label="Rádio Eleva"#' "$M"

# 5. MainActivity compatível com o serviço de áudio
K=$(find android/app/src/main/kotlin -name MainActivity.kt)
cat > "$K" <<'KOTLIN'
package br.com.radioeleva.radio_eleva

import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity()
KOTLIN

# 5b. Despertador: receptores de alarme (disparam mesmo com o app fechado)
sed -i 's#</application>#    <receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" android:exported="false"/>\n        <receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver" android:exported="false">\n            <intent-filter>\n                <action android:name="android.intent.action.BOOT_COMPLETED"/>\n                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>\n                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>\n            </intent-filter>\n        </receiver>\n        <receiver android:name="br.com.radioeleva.radio_eleva.DespertadorReceiver" android:exported="false"/>\n        <service android:name="br.com.radioeleva.radio_eleva.DespertadorAudioService" android:exported="false" android:foregroundServiceType="mediaPlayback"/>\n    </application>#' "$M"

# 5c. Desugaring (exigência do despertador) — bloco anexado, método robusto
if [ -f android/app/build.gradle.kts ]; then
  cat >> android/app/build.gradle.kts <<'GRADLE'

android {
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
GRADLE
elif [ -f android/app/build.gradle ]; then
  cat >> android/app/build.gradle <<'GRADLE'

android {
    compileOptions {
        coreLibraryDesugaringEnabled true
    }
}

dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'
}
GRADLE
fi
echo "Desugaring configurado para o despertador!"

# 5d. Lista de peças intocáveis do compactador (cura do "Missing type parameter")
cat > android/app/proguard-rules.pro <<'PROGUARD'
# Despertador (flutter_local_notifications) — não raspar as peças de gravação de alarmes
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
PROGUARD

# Injeta a regra DENTRO do bloco release existente (sem criar novo buildTypes)
if [ -f android/app/build.gradle.kts ]; then
  sed -i 's#signingConfig = signingConfigs.getByName("debug")#signingConfig = signingConfigs.getByName("debug")\n            proguardFiles(\n                getDefaultProguardFile("proguard-android-optimize.txt"),\n                "proguard-rules.pro"\n            )#' android/app/build.gradle.kts
elif [ -f android/app/build.gradle ]; then
  sed -i 's#signingConfig signingConfigs.debug#signingConfig signingConfigs.debug\n            proguardFiles getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro"#' android/app/build.gradle
fi
echo "Regras do compactador aplicadas (despertador protegido)!"

# 5d2. Som característico das notificações (som_eleva.mp3 na raiz do repo)
# O ID do canal é derivado do PRÓPRIO ARQUIVO: trocou o som, o canal muda
# sozinho — sem isso o Android continuaria tocando o som antigo para sempre.
mkdir -p android/app/src/main/res/raw
SOM_ORIGEM=""
[ -f som_eleva.mp3 ] && SOM_ORIGEM="som_eleva.mp3"
[ -z "$SOM_ORIGEM" ] && [ -f assets/som_eleva.mp3 ] && SOM_ORIGEM="assets/som_eleva.mp3"

if [ -n "$SOM_ORIGEM" ]; then
  cp "$SOM_ORIGEM" android/app/src/main/res/raw/som_eleva.mp3
  ASSINATURA_SOM=$(md5sum "$SOM_ORIGEM" | cut -c1-8)
  CANAL_SOM="eleva_som_${ASSINATURA_SOM}"
  echo "Som da Eleva instalado! Canal: $CANAL_SOM (muda sozinho a cada troca de som)"
else
  CANAL_SOM="eleva_som_padrao"
  echo "AVISO: som_eleva.mp3 nao encontrado - as notificacoes usarao o som padrao do celular."
fi

# grava o ID do canal no app (Dart) e no manifesto, sempre iguais
sed -i "s/eleva_som_v2/${CANAL_SOM}/g" lib/servicos/notificacoes_service.dart
sed -i "s#</application>#    <meta-data android:name=\"com.google.firebase.messaging.default_notification_channel_id\" android:value=\"${CANAL_SOM}\"/>\n    </application>#" "$M"

# 5e. Despertador NATIVO: alarme de relógio + serviço de áudio em Kotlin
KDIR="android/app/src/main/kotlin/br/com/radioeleva/radio_eleva"
mkdir -p "$KDIR"

cat > "$KDIR/MainActivity.kt" <<'KOTLIN'
package br.com.radioeleva.radio_eleva

import android.content.Intent
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "br.com.radioeleva/despertador"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "agendar" -> {
                    val millis = (call.argument<Any>("millis") as Number).toLong()
                    val diario = call.argument<Boolean>("diario") ?: false
                    DespertadorReceiver.agendar(this, millis, diario)
                    result.success(true)
                }
                "cancelar" -> {
                    DespertadorReceiver.cancelar(this)
                    result.success(true)
                }
                "parar" -> {
                    stopService(Intent(this, DespertadorAudioService::class.java))
                    result.success(true)
                }
                "statusPermissoes" -> {
                    val m = HashMap<String, Boolean>()
                    // notificação (Android 13+)
                    var notif = true
                    if (android.os.Build.VERSION.SDK_INT >= 33) {
                        notif = checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
                                android.content.pm.PackageManager.PERMISSION_GRANTED
                    }
                    m["notificacao"] = notif
                    // alarme exato (Android 12+)
                    var alarme = true
                    if (android.os.Build.VERSION.SDK_INT >= 31) {
                        try {
                            val am = getSystemService(android.app.AlarmManager::class.java)
                            alarme = am.canScheduleExactAlarms()
                        } catch (e: Exception) {}
                    }
                    m["alarme"] = alarme
                    // tela cheia (Android 14+)
                    var fsi = true
                    if (android.os.Build.VERSION.SDK_INT >= 34) {
                        try {
                            val nm = getSystemService(android.app.NotificationManager::class.java)
                            fsi = nm.canUseFullScreenIntent()
                        } catch (e: Exception) {}
                    }
                    m["telacheia"] = fsi
                    // economia de bateria
                    var bateria = true
                    try {
                        val pm = getSystemService(android.os.PowerManager::class.java)
                        bateria = pm.isIgnoringBatteryOptimizations(packageName)
                    } catch (e: Exception) {}
                    m["bateria"] = bateria
                    result.success(m)
                }
                "abrirPermissao" -> {
                    val qual = call.argument<String>("qual") ?: ""
                    try {
                        val pac = android.net.Uri.parse("package:" + packageName)
                        val i = when (qual) {
                            "notificacao" ->
                                Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                    .putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, packageName)
                            "alarme" ->
                                Intent(android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).setData(pac)
                            "telacheia" ->
                                Intent(android.provider.Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).setData(pac)
                            "bateria" ->
                                Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).setData(pac)
                            else ->
                                Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).setData(pac)
                        }
                        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(i)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val i2 = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                                .setData(android.net.Uri.parse("package:" + packageName))
                            i2.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(i2)
                        } catch (e2: Exception) {}
                        result.success(false)
                    }
                }
                "testarAgora" -> {
                    val quando = System.currentTimeMillis() + 10000
                    DespertadorReceiver.agendar(this, quando, false, false)
                    result.success(true)
                }
                "podeTelaCheia" -> {
                    // Android 14+: precisa da permissão de notificação em tela cheia
                    var pode = true
                    if (android.os.Build.VERSION.SDK_INT >= 34) {
                        try {
                            val nm = getSystemService(android.app.NotificationManager::class.java)
                            pode = nm.canUseFullScreenIntent()
                        } catch (e: Exception) { pode = true }
                    }
                    result.success(pode)
                }
                "abrirPermissaoTelaCheia" -> {
                    try {
                        val i = if (android.os.Build.VERSION.SDK_INT >= 34)
                            Intent(android.provider.Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT)
                                .setData(android.net.Uri.parse("package:" + packageName))
                        else
                            Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                                .setData(android.net.Uri.parse("package:" + packageName))
                        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(i)
                        result.success(true)
                    } catch (e: Exception) { result.success(false) }
                }
                else -> result.notImplemented()
            }
        }
    }
}
KOTLIN

cat > "$KDIR/DespertadorAlarmeActivity.kt" <<'KOTLIN'
package br.com.radioeleva.radio_eleva

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/// Tela do despertador tocando. Aparece SOBRE a tela de bloqueio,
/// acende o visor e permite adiar/abaixar/parar SEM desbloquear.
class DespertadorAlarmeActivity : Activity() {
    private val alca = Handler(Looper.getMainLooper())
    private var relogio: TextView? = null

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()

    override fun onCreate(b: Bundle?) {
        super.onCreate(b)
        // aparecer com o celular bloqueado e acender a tela
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
        )
        volumeControlStream = AudioManager.STREAM_ALARM
        setContentView(montarTela())
        tique()
    }

    private fun prefs() =
        getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    private fun enviar(acao: String) {
        val i = Intent(this, DespertadorAudioService::class.java)
        i.action = acao
        try {
            if (Build.VERSION.SDK_INT >= 26) startForegroundService(i) else startService(i)
        } catch (_: Exception) {}
    }

    private fun tique() {
        alca.postDelayed(object : Runnable {
            override fun run() {
                relogio?.text = SimpleDateFormat("HH:mm", Locale("pt", "BR")).format(Date())
                alca.postDelayed(this, 10000)
            }
        }, 10000)
    }

    private fun botao(texto: String, cor: String, aoTocar: () -> Unit): Button {
        val bt = Button(this)
        bt.text = texto
        bt.textSize = 17f
        bt.setTextColor(Color.WHITE)
        bt.isAllCaps = false
        val fundo = GradientDrawable()
        fundo.cornerRadius = dp(32).toFloat()
        fundo.setColor(Color.parseColor(cor))
        bt.background = fundo
        bt.setPadding(dp(16), dp(22), dp(16), dp(22))
        val lp = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        lp.topMargin = dp(14)
        bt.layoutParams = lp
        bt.setOnClickListener { aoTocar() }
        return bt
    }

    private fun montarTela(): View {
        val raiz = LinearLayout(this)
        raiz.orientation = LinearLayout.VERTICAL
        raiz.gravity = Gravity.CENTER
        raiz.setBackgroundColor(Color.parseColor("#0E0857"))
        raiz.setPadding(dp(26), dp(36), dp(26), dp(36))

        val titulo = TextView(this)
        titulo.text = "⏰ BOM DIA!"
        titulo.textSize = 30f
        titulo.setTextColor(Color.parseColor("#FFD65A"))
        titulo.gravity = Gravity.CENTER
        raiz.addView(titulo)

        val hora = TextView(this)
        hora.text = SimpleDateFormat("HH:mm", Locale("pt", "BR")).format(Date())
        hora.textSize = 68f
        hora.setTextColor(Color.WHITE)
        hora.gravity = Gravity.CENTER
        relogio = hora
        raiz.addView(hora)

        val sub = TextView(this)
        sub.text = "A Rádio Eleva está tocando para você\nAdore • Viva • Eleve"
        sub.textSize = 14f
        sub.setTextColor(Color.parseColor("#BDB8F0"))
        sub.gravity = Gravity.CENTER
        sub.setPadding(0, dp(6), 0, dp(18))
        raiz.addView(sub)

        // ===== ADIAR 5 MINUTOS (até 3 vezes) =====
        val usadas = prefs().getLong("flutter.desp_sonecas", 0L).toInt()
        val restam = 3 - usadas
        if (restam > 0) {
            raiz.addView(botao(
                "😴  ADIAR 5 MINUTOS   (" + restam + " restante" + (if (restam == 1) "" else "s") + ")",
                "#1B7A4B") {
                enviar("SONECA"); finish()
            })
        } else {
            val aviso = TextView(this)
            aviso.text = "🌅 Sonecas esgotadas — hora de levantar!"
            aviso.textSize = 13f
            aviso.setTextColor(Color.parseColor("#FFD65A"))
            aviso.gravity = Gravity.CENTER
            aviso.setPadding(0, dp(14), 0, 0)
            raiz.addView(aviso)
        }

        raiz.addView(botao("⏹️  PARAR O DESPERTADOR", "#7a1b1b") {
            enviar("PARAR"); finish()
        })

        raiz.addView(botao("📻  ABRIR A RÁDIO ELEVA", "#1D14A8") {
            try {
                val i = Intent(this, MainActivity::class.java)
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(i)
            } catch (_: Exception) {}
            finish()
        })
        return raiz
    }

    override fun onDestroy() {
        alca.removeCallbacksAndMessages(null)
        super.onDestroy()
    }
}
KOTLIN

cat > "$KDIR/DespertadorReceiver.kt" <<'KOTLIN'
package br.com.radioeleva.radio_eleva

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

class DespertadorReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val ehSoneca = intent.getBooleanExtra("soneca", false)
        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences", Context.MODE_PRIVATE)

        // Alarme "de verdade" (não soneca): zera o contador de sonecas
        if (!ehSoneca) {
            prefs.edit().putLong("flutter.desp_sonecas", 0L).apply()
        }

        val servico = Intent(context, DespertadorAudioService::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            context.startForegroundService(servico)
        } else {
            context.startService(servico)
        }

        // TODO DIA: grava sozinho o alarme de amanhã (nunca a partir da soneca)
        if (!ehSoneca && prefs.getString("flutter.desp_tipo", "") == "diario") {
            val h = prefs.getLong("flutter.desp_hora", 7L).toInt()
            val m = prefs.getLong("flutter.desp_min", 0L).toInt()
            val cal = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, h)
                set(Calendar.MINUTE, m)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            agendar(context, cal.timeInMillis, true)
        }
    }

    companion object {
        private const val CODIGO = 4201

        private fun pendente(context: Context, ehSoneca: Boolean): PendingIntent {
            val i = Intent(context, DespertadorReceiver::class.java)
            i.putExtra("soneca", ehSoneca)
            return PendingIntent.getBroadcast(
                context, CODIGO, i,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }

        fun agendar(context: Context, millis: Long, diario: Boolean,
                    ehSoneca: Boolean = false) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val abrirApp = PendingIntent.getActivity(
                context, CODIGO,
                Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            am.setAlarmClock(
                AlarmManager.AlarmClockInfo(millis, abrirApp),
                pendente(context, ehSoneca))
        }

        fun cancelar(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.cancel(pendente(context, false))
            am.cancel(pendente(context, true))
        }
    }
}
KOTLIN

cat > "$KDIR/DespertadorAudioService.kt" <<'KOTLIN'
package br.com.radioeleva.radio_eleva

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.drawable.Icon
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class DespertadorAudioService : Service() {
    private var player: MediaPlayer? = null
    private val alca = Handler(Looper.getMainLooper())
    private var passo = 0

    companion object {
        const val MAX_SONECAS = 3         // adiar no máximo 3 vezes
        const val MIN_SONECA = 5          // 5 minutos por soneca
        const val ID_NOTIF = 4202
        const val ID_AVISO = 4203
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun prefs() =
        getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        criarCanal()
        // O Android exige entrar em foreground logo de cara, em qualquer caso
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(ID_NOTIF, notificacao(),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(ID_NOTIF, notificacao())
        }
        val acao = intent?.action ?: ""
        when {
            acao == "PARAR" -> {
                prefs().edit().putLong("flutter.desp_sonecas", 0L).apply()
                stopSelf(); return START_NOT_STICKY
            }
            acao == "SONECA" -> { soneca(); return START_NOT_STICKY }
        }
        ajustarVolumeSistema()
        abrirTelaAlarme()   // tela cheia sobre o bloqueio
        tocar()
        alca.postDelayed({ stopSelf() }, 20L * 60L * 1000L)
        return START_NOT_STICKY
    }

    /// Abre a tela do alarme por cima do bloqueio (como o relógio do celular)
    private fun abrirTelaAlarme() {
        try {
            val i = Intent(this, DespertadorAlarmeActivity::class.java)
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or
                       Intent.FLAG_ACTIVITY_CLEAR_TOP or
                       Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
            startActivity(i)
        } catch (_: Exception) {}
    }

    /// Coloca o canal de alarme no volume escolhido pelo ouvinte no app
    private fun ajustarVolumeSistema() {
        try {
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val maximo = am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            val alvo = (maximo * 0.80f).toInt().coerceAtLeast(1)  // padrão: 80%
            am.setStreamVolume(AudioManager.STREAM_ALARM, alvo, 0)
        } catch (_: Exception) {}
    }

    // ===== SONECA =====
    private fun soneca() {
        val usadas = prefs().getLong("flutter.desp_sonecas", 0L).toInt()
        if (usadas >= MAX_SONECAS) {
            avisar("🌅 Sonecas esgotadas", "Você já adiou $MAX_SONECAS vezes. Bom dia!")
            stopSelf(); return
        }
        val nova = usadas + 1
        prefs().edit().putLong("flutter.desp_sonecas", nova.toLong()).apply()
        val quando = System.currentTimeMillis() + MIN_SONECA * 60L * 1000L
        DespertadorReceiver.agendar(this, quando, false, true)
        val hora = SimpleDateFormat("HH:mm", Locale("pt", "BR")).format(Date(quando))
        val restam = MAX_SONECAS - nova
        avisar("😴 Soneca de $MIN_SONECA minutos",
            if (restam > 0) "A Rádio Eleva volta às $hora — você ainda pode adiar $restam ${if (restam == 1) "vez" else "vezes"}."
            else "Última soneca! A Rádio Eleva volta às $hora e não adia mais. 🌅")
        stopSelf()
    }

    private fun avisar(titulo: String, texto: String) {
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val b = if (Build.VERSION.SDK_INT >= 26)
                Notification.Builder(this, "despertador_som")
            else
                @Suppress("DEPRECATION") Notification.Builder(this)
            nm.notify(ID_AVISO, b.setContentTitle(titulo)
                .setContentText(texto)
                .setStyle(Notification.BigTextStyle().bigText(texto))
                .setSmallIcon(applicationInfo.icon)
                .setAutoCancel(true)
                .setTimeoutAfter(MIN_SONECA * 60L * 1000L)
                .build())
        } catch (_: Exception) {}
    }

    // ===== ÁUDIO =====
    private fun tocar() {
        try {
            val url = prefs().getString("flutter.desp_stream", null)
                ?: "https://sv16.hdradios.net:8516/stream"
            player = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build())
                setDataSource(url)
                setVolume(0.03f, 0.03f)
                setOnPreparedListener {
                    it.start()
                    fade()
                }
                setOnErrorListener { _, _, _ ->
                    stopSelf()
                    true
                }
                prepareAsync()
            }
        } catch (e: Exception) {
            stopSelf()
        }
    }

    /// O som nasce baixinho e cresce em 30s, respeitando o botão de volume
    private fun fade() {
        passo = 0
        val rampa = object : Runnable {
            override fun run() {
                passo++
                val v = (passo / 30f).coerceIn(0.03f, 1f)
                try { player?.setVolume(v, v) } catch (_: Exception) {}
                if (passo < 30) alca.postDelayed(this, 1000)
            }
        }
        alca.postDelayed(rampa, 1000)
    }

    private fun criarCanal() {
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val canal = NotificationChannel(
                "despertador_som", "Despertador tocando",
                NotificationManager.IMPORTANCE_HIGH)
            canal.setSound(null, null)
            canal.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            nm.createNotificationChannel(canal)
        }
    }

    private fun acao(nome: String, codigo: Int): PendingIntent {
        val i = Intent(this, DespertadorAudioService::class.java)
        i.action = nome
        return PendingIntent.getService(this, codigo, i,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun notificacao(): Notification {
        val usadas = prefs().getLong("flutter.desp_sonecas", 0L).toInt()
        val restam = MAX_SONECAS - usadas
        val b = if (Build.VERSION.SDK_INT >= 26)
            Notification.Builder(this, "despertador_som")
        else
            @Suppress("DEPRECATION") Notification.Builder(this)
        // full screen intent: o Android abre a TELA DO ALARME sozinho,
        // mesmo com o celular bloqueado
        val telaCheia = PendingIntent.getActivity(
            this, 9,
            Intent(this, DespertadorAlarmeActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        b.setContentTitle("⏰ Bom dia! A Rádio Eleva está despertando você")
            .setContentText(
                if (restam > 0) "Adie $MIN_SONECA min (restam $restam) • abaixe o som • ou pare"
                else "Última chamada — sonecas esgotadas 🌅")
            .setSmallIcon(applicationInfo.icon)
            .setContentIntent(telaCheia)
            .setFullScreenIntent(telaCheia, true)
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(true)
        if (restam > 0) {
            b.addAction(Notification.Action.Builder(
                Icon.createWithResource(this, android.R.drawable.ic_menu_recent_history),
                "😴 +$MIN_SONECA MIN", acao("SONECA", 2)).build())
        }
        b.addAction(Notification.Action.Builder(
            Icon.createWithResource(this, android.R.drawable.ic_media_pause),
            "⏹️ PARAR", acao("PARAR", 4)).build())
        return b.build()
    }

    override fun onDestroy() {
        try {
            player?.stop()
            player?.release()
        } catch (_: Exception) {}
        player = null
        alca.removeCallbacksAndMessages(null)
        super.onDestroy()
    }
}
KOTLIN
echo "Despertador nativo instalado (Kotlin)!"

# 6pre. Android mínimo 23 (exigência do Google Mobile Ads)
if [ -f android/app/build.gradle.kts ]; then
  sed -i 's#minSdk = flutter.minSdkVersion#minSdk = 23#' android/app/build.gradle.kts
elif [ -f android/app/build.gradle ]; then
  sed -i 's#minSdkVersion flutter.minSdkVersion#minSdkVersion 23#' android/app/build.gradle
fi

# 6a. AdMob (anúncios): ID do app vem de admob_app_id.txt
ADMOB_ID=$(cat admob_app_id.txt 2>/dev/null || echo "ca-app-pub-3940256099942544~3347511713")
sed -i "s#</application>#    <meta-data android:name=\"com.google.android.gms.ads.APPLICATION_ID\" android:value=\"$ADMOB_ID\"/>\n    <meta-data android:name=\"com.google.android.gms.ads.DELAY_APP_MEASUREMENT_INIT\" android:value=\"true\"/>\n    <meta-data android:name=\"com.google.android.gms.ads.flag.OPTIMIZE_INITIALIZATION\" android:value=\"true\"/>\n    <meta-data android:name=\"com.google.android.gms.ads.flag.OPTIMIZE_AD_LOADING\" android:value=\"true\"/>\n    </application>#" "$M"
echo "AdMob configurado: $ADMOB_ID"

# 6. Firebase (notificações push)
if [ -f firebase/google-services.json ]; then
  cp firebase/google-services.json android/app/google-services.json

  if [ -f android/settings.gradle.kts ]; then
    sed -i 's#id("com.android.application") version "\([^"]*\)" apply false#id("com.android.application") version "\1" apply false\n    id("com.google.gms.google-services") version "4.4.2" apply false#' android/settings.gradle.kts
  elif [ -f android/settings.gradle ]; then
    sed -i 's#id "com.android.application" version "\([^"]*\)" apply false#id "com.android.application" version "\1" apply false\n    id "com.google.gms.google-services" version "4.4.2" apply false#' android/settings.gradle
  fi

  if [ -f android/app/build.gradle.kts ]; then
    sed -i 's#id("com.android.application")#id("com.android.application")\n    id("com.google.gms.google-services")#' android/app/build.gradle.kts
  elif [ -f android/app/build.gradle ]; then
    sed -i 's#id "com.android.application"#id "com.android.application"\n    id "com.google.gms.google-services"#' android/app/build.gradle
  fi
  echo "Firebase configurado para notificações!"
fi

# 7. ASSINATURA EXPLÍCITA: obriga o uso da nossa chave (chave.keystore na raiz)
if [ -f chave.keystore ]; then
  if [ -f android/app/build.gradle.kts ]; then
    # cria o signingConfig "release" apontando para a nossa chave
    sed -i 's#buildTypes {#signingConfigs {\n        create("release") {\n            storeFile = file("../../chave.keystore")\n            storePassword = "android"\n            keyAlias = "androiddebugkey"\n            keyPassword = "android"\n        }\n    }\n\n    buildTypes {#' android/app/build.gradle.kts
    sed -i 's#signingConfig = signingConfigs.getByName("debug")#signingConfig = signingConfigs.getByName("release")#' android/app/build.gradle.kts
  elif [ -f android/app/build.gradle ]; then
    sed -i 's#buildTypes {#signingConfigs {\n        release {\n            storeFile file("../../chave.keystore")\n            storePassword "android"\n            keyAlias "androiddebugkey"\n            keyPassword "android"\n        }\n    }\n\n    buildTypes {#' android/app/build.gradle
    sed -i 's#signingConfig signingConfigs.debug#signingConfig signingConfigs.release#' android/app/build.gradle
  fi
  echo "Assinatura explícita configurada com a chave oficial!"
fi

echo "Configuração Android concluída!"
