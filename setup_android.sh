#!/usr/bin/env bash
# Prepara a estrutura Android do projeto na nuvem (GitHub Actions)
set -e

# 1. Gera a pasta android/ preservando lib/ e pubspec.yaml existentes
flutter create --org br.com.radioeleva --project-name radio_eleva --platforms android .

M=android/app/src/main/AndroidManifest.xml

# 2. Permissões (internet, áudio em segundo plano e notificações)
sed -i 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <uses-permission android:name="android.permission.WAKE_LOCK"/>\n    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>\n    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>\n    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n    <application#' "$M"

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

# 6a. AdMob (anúncios): ID do app vem de admob_app_id.txt ou usa o de TESTE
ADMOB_ID=$(cat admob_app_id.txt 2>/dev/null || echo "ca-app-pub-3940256099942544~3347511713")
sed -i "s#</application>#    <meta-data android:name=\"com.google.android.gms.ads.APPLICATION_ID\" android:value=\"$ADMOB_ID\"/>\n    </application>#" "$M"
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
