# Lokal bauen

Die Skripte sind für **Windows und PowerShell 7** ausgelegt. Der Patch ist an **INMO Global 3.0.455 / versionCode 30455** gebunden. `build.ps1` prüft die Eingabeversion und die erwarteten Smali-Einstiegspunkte. Nicht auf eine beliebige neue Hersteller-Version anwenden.

## 1. Werkzeuge

- JDK 17; `JAVA_HOME` auf das JDK-Verzeichnis setzen.
- Android SDK mit Platform Tools (`adb`), einer installierten Build-Tools-Version mit `d8`, `zipalign`, `apksigner` und `platforms/android-35/android.jar`.
- [APKEditor 1.4.9](https://github.com/REAndroid/APKEditor/releases/tag/V1.4.9), lokal als `tools/apkeditor.jar` ablegen.
- [Apktool 3.0.3](https://github.com/iBotPeaches/Apktool/releases/tag/v3.0.3), lokal als `tools/apktool.jar` ablegen.

Die Tools werden nicht mitgeliefert und nicht automatisch heruntergeladen. `tools/` ist von Git ausgeschlossen. Die Release-Links dienen der Zuordnung der beim ursprünglichen Umbau verwendeten Versionen.

Beispielkonfiguration – Pfade auf den eigenen PC anpassen:

```powershell
$env:JAVA_HOME = 'C:\Tools\jdk-17'
$env:ANDROID_SDK_ROOT = 'C:\Android\Sdk'
$adb = Join-Path $env:ANDROID_SDK_ROOT 'platform-tools\adb.exe'
& $adb devices -l
```

Bei mehreren Android-Geräten in den folgenden ADB-Befehlen zusätzlich `-s DEINE_GERAETE_ID` angeben. USB-Debugging auf dem eigenen Telefon freigeben.

## 2. Eigene installierte App bereitstellen

Die Original-App muss auf dem Telefon vorhanden sein. Diese Befehle lesen ihre Paketdateien aus; sie kopieren keine Konto- oder App-Nutzerdaten:

```powershell
& $adb shell dumpsys package com.inmo.app.googleplay |
    Select-String -Pattern 'versionCode=|versionName='

New-Item -ItemType Directory -Force -Path .\work\inmo-apk | Out-Null
$packagePaths = & $adb shell pm path com.inmo.app.googleplay
foreach ($entry in $packagePaths) {
    if ($entry.StartsWith('package:')) {
        $remotePath = $entry.Substring(8).Trim()
        & $adb pull $remotePath .\work\inmo-apk\
        if ($LASTEXITCODE -ne 0) { throw 'ADB pull fehlgeschlagen.' }
    }
}
```

Im bestätigten ARM64-Aufbau waren dies `base.apk`, `split_config.arm64_v8a.apk` und `split_config.xxhdpi.apk`. Alle vom eigenen Gerät gemeldeten Split-Dateien gemeinsam verwenden.

## 3. Vorbereiten und prüfen

Im Repository-Verzeichnis:

```powershell
pwsh -File .\test.ps1
pwsh -File .\prepare.ps1
```

Die Tests benötigen nur JDK 17 und keine Original-APK. Sie prüfen Auslöser, Stummschaltung, Wiederholungen und Abbruchverhalten; Brillen-Firmware und INMO-Server werden nicht simuliert.

`prepare.ps1` erzeugt `work/inmo-merged.apk` und `work/inmo-autofoto/`. Eine vorhandene dekodierte Arbeitskopie wird nicht überschrieben. Für einen frischen Versuch kann `-WorkingDirectory` auf ein neues Verzeichnis zeigen; denselben Pfad dann auch an `build.ps1` übergeben.

## 4. Bauen und signieren

```powershell
pwsh -File .\build.ps1 -BuildToolsVersion '35.0.0'
```

`-BuildToolsVersion` muss dem Namen des tatsächlich installierten Ordners unter `AndroidSdk/build-tools/` entsprechen. Das Skript nutzt standardmäßig Android Platform 35. Alle Pfade sind auch als Parameter verfügbar:

```powershell
pwsh -File .\build.ps1 `
    -JavaHome 'C:\Tools\jdk-17' `
    -AndroidSdk 'C:\Android\Sdk' `
    -BuildToolsVersion '35.0.0' `
    -AndroidPlatform 'android-35'
```

Ergebnis: **`dist/INMO-AutoFoto-Test.apk`**. Der Build prüft die APK-Signatur.

Beim ersten Build entstehen ein persönlicher lokaler Test-Signierschlüssel (`work/autofoto-local-test.p12`) und ein zufälliges Passwort in `work/keystore-password.txt`. Alternativ kann das Passwort über `AUTOFOTO_KEYSTORE_PASSWORD` vorgegeben werden. Für spätere Updates denselben Schlüssel verwenden. Diese Dateien privat sichern und nicht veröffentlichen.

## 5. Installieren

```powershell
& $adb install --no-incremental -r .\dist\INMO-AutoFoto-Test.apk
```

Die neue Paket-ID ist `com.inmo.app.autofoto`; die Original-App bleibt separat installiert. Anschließend [INMO AutoFoto einrichten](ANLEITUNG.md).

Ein Update einer bereits installierten AutoFoto-Kopie braucht denselben Signierschlüssel. Bei `INSTALL_FAILED_UPDATE_INCOMPATIBLE` zuerst den richtigen Schlüssel verwenden. Eine Deinstallation der alten Testkopie würde deren lokale Einstellungen und Anmeldung entfernen; das Skript führt sie deshalb nicht automatisch aus.

## Was der Build ändert

- Separate Paket-ID und interne Paket-/Provider-Verweise.
- Eigener Launcher mit Foto-Aufgaben-Einstellungen.
- Versionsgebundene Hooks für Foto-Auslöser, TTS-Unterdrückung, wiederholten Start und Dienstende.
- Die lokale Kopie startet die originale `com.inmo.app.MyApplication` direkt statt des hinzugefügten `com.pairip.application.Application`-Startwrappers. Die erste Versuchskopie mit diesem Google-Play-Installations-/Lizenzwrapper beendete sich selbst. INMO-Anmeldung und serverseitige KI-Berechtigungen bleiben erforderlich.
- Die Basisversion 3.0.455 bleibt im Handshake zur Brille erhalten; nur der eigene `-autofoto.N`-Zusatz wird dort entfernt.

Hersteller-APK, dekodierter Hersteller-Code, SDKs, Tools und private Signierdateien sind kein Bestandteil dieses Repositories. Der entstandene Build enthält weiterhin Hersteller-Code und ist kein vollständig selbst entwickelter Ersatz für INMO Global.
