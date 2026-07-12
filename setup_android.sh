#!/usr/bin/env bash
# Prepara a estrutura Android do projeto na nuvem (GitHub Actions)
set -e

# 1. Gera a pasta android/ preservando lib/ e pubspec.yaml existentes
flutter create --org br.com.radioeleva --project-name radio_eleva --platforms android .

M=android/app/src/main/AndroidManifest.xml

# 2. Permissões (internet, áudio em segundo plano e notificações)
sed -i 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <uses-permission android:name="android.permission.WAKE_LOCK"/>\n    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>\n    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>\n    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>\n    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>\n    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>\n    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>\n    <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>\n    <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>\n    <uses-permission android:name="android.permission.VIBRATE"/>\n    <uses-permission android:name="android.permission.WAKE_LOCK"/>\n    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>\n    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>\n    <application#' "$M"

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
                else -> result.notImplemented()
            }
        }
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
        val servico = Intent(context, DespertadorAudioService::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            context.startForegroundService(servico)
        } else {
            context.startService(servico)
        }
        // TODO DIA: grava sozinho o alarme de amanhã no mesmo horário
        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences", Context.MODE_PRIVATE)
        if (prefs.getString("flutter.desp_tipo", "") == "diario") {
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

        private fun pendente(context: Context): PendingIntent {
            val i = Intent(context, DespertadorReceiver::class.java)
            return PendingIntent.getBroadcast(
                context, CODIGO, i,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }

        fun agendar(context: Context, millis: Long, diario: Boolean) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val abrirApp = PendingIntent.getActivity(
                context, CODIGO,
                Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            am.setAlarmClock(
                AlarmManager.AlarmClockInfo(millis, abrirApp), pendente(context))
        }

        fun cancelar(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.cancel(pendente(context))
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
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper

class DespertadorAudioService : Service() {
    private var player: MediaPlayer? = null
    private val alca = Handler(Looper.getMainLooper())
    private var passo = 0

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "PARAR") {
            stopSelf()
            return START_NOT_STICKY
        }
        criarCanal()
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(4202, notificacao(),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(4202, notificacao())
        }
        tocar()
        alca.postDelayed({ stopSelf() }, 20L * 60L * 1000L)
        return START_NOT_STICKY
    }

    private fun tocar() {
        try {
            val prefs = getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE)
            val url = prefs.getString("flutter.desp_stream", null)
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

    // O som nasce baixinho e cresce em 30 segundos
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
            nm.createNotificationChannel(canal)
        }
    }

    private fun notificacao(): Notification {
        val abrir = PendingIntent.getActivity(
            this, 1, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val pararIntent = Intent(this, DespertadorAudioService::class.java)
        pararIntent.action = "PARAR"
        val parar = PendingIntent.getService(
            this, 2, pararIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val b = if (Build.VERSION.SDK_INT >= 26)
            Notification.Builder(this, "despertador_som")
        else
            @Suppress("DEPRECATION") Notification.Builder(this)
        return b.setContentTitle("⏰ Bom dia! A Rádio Eleva está despertando você")
            .setContentText("Toque para abrir o app — o som cresce aos poucos")
            .setSmallIcon(applicationInfo.icon)
            .setContentIntent(abrir)
            .setOngoing(true)
            .addAction(
                Notification.Action.Builder(
                    Icon.createWithResource(this, android.R.drawable.ic_media_pause),
                    "PARAR", parar).build())
            .build()
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
