# INMO GO 3 AutoFoto

**INMO AI öffnen → Foto der Aufgabe → KI-Antwort im Brillendisplay. Ohne Sprachbefehl.**

Experimentelle lokale Erweiterung für die Android-Begleit-App **INMO Global 3.0.455**. Die separat installierte App heißt **INMO AutoFoto** und nutzt den vorhandenen INMO-Datenweg für Kamera, Bildanalyse und Display-Ausgabe.

Dieses Repository enthält die eigenen Java-Ergänzungen, Patch-/Build-Skripte und Verhaltenstests. Die INMO-App wird aus einer eigenen Installation lokal bereitgestellt und gebaut. Es gibt hier keine vorgefertigte Hersteller-APK und keinen gemeinsamen Signierschlüssel. Das Projekt ist keine offizielle INMO-Veröffentlichung.

## Funktionen

- Beim Start von INMO AI wird automatisch ein Foto mit einer gespeicherten Aufgaben-Anweisung angefordert.
- Die Antwort erscheint als Text im Brillendisplay; die KI-Sprachausgabe ist blockiert.
- Die KI wird angewiesen, in der Sprache der jeweiligen Frage im Foto zu antworten. Bei mehreren Sprachen gilt die Regel pro Aufgabe.
- Wiederholte Foto-Runden, Abbruch und erneuter Start werden unterstützt.
- Zwei Handy-Knöpfe erlauben **„Foto-Aufgabe jetzt starten“** und **„INMO AI stoppen und schließen“**.
- Die Aufgaben-Anweisung lässt sich bearbeiten.

Der normale Kamera-Auslöser wird nicht umbelegt. Eine eigene Belegung des langen Tastendrucks ist noch nicht enthalten. Es gibt keine automatische Aufnahmeschleife: Jede neue Aufgabe braucht einen ausdrücklichen Start.

## Getesteter Stand

| Bestandteil | Stand |
| --- | --- |
| Brille | INMO GO 3 |
| Telefon | moto g51 5G, Android 12, ARM64 |
| Original-App | `com.inmo.app.googleplay`, 3.0.455 / 30455 |
| Lokale Kopie | `com.inmo.app.autofoto`, 3.0.455-autofoto.5 |
| Foto und Display-Antwort | Am Gerät bestätigt |
| Mehrere Runden, Stoppen, erneuter Start | Am Gerät bestätigt |
| Antwortsprache passend zur Frage | Vom Nutzer bestätigt; keine vollständige Sprach-Testmatrix |
| Vollständig stumm einschließlich Kameraklick | Mit **Systemsound AUS** am Gerät bestätigt |
| Lokale Verhaltenstests | 29 Prüfungen bestanden |

Andere App-Versionen, Brillenmodelle und Firmwarestände sind nicht validiert. Ein vollständiges Bild- oder KI-Ergebnis lässt sich aus einem lokalen „gesendet“-Status allein nicht ableiten. KI-Antworten können falsch sein, insbesondere bei unscharfen oder überbelichteten Bildern.

## Einstieg

1. Mit der [Bauanleitung](BUILD.md) aus der eigenen INMO-Installation eine APK bauen.
2. APK installieren und die [Einrichtung](ANLEITUNG.md) abschließen.
3. Für einen stummen Kameraklick den vorhandenen Brillenschalter **Systemsound AUS** setzen.
4. Auf eine gut lesbare Aufgabe schauen und INMO AI an der Brille öffnen.

Für Fragen und reproduzierbare Fehlerberichte können GitHub Issues genutzt werden. Bitte App-/Firmwareversion, Android-Version und beobachteten Ablauf nennen. Bilder, Kontodaten, Seriennummern und ungefilterte Hersteller-Logs werden für einen ersten Bericht nicht benötigt.

## Dateien

| Datei | Aufgabe |
| --- | --- |
| `AutoFoto.java` | Foto-Auslöser, Zustandsverwaltung, Sprachregel und stumme Ausgabe |
| `SettingsActivity.java` | Einstellungen und Start-/Stopp-Knöpfe |
| `prepare.ps1` | Eigene Split-APKs zusammenführen und Arbeitskopie dekodieren |
| `build.ps1` | Versionsgebundene Hooks einfügen, kompilieren, ausrichten und lokal signieren |
| `test.ps1` | JVM-Verhaltenstests mit kleinen Android-/INMO-Testdoubles |
| [BUILD.md](BUILD.md) | Voraussetzungen, eigener Build und Installation |
| [ANLEITUNG.md](ANLEITUNG.md) | Bedienung, Ton, Sprache und Fehlerbehebung |
| [TECHNIK.md](TECHNIK.md) | Integration, Datenweg und technische Grenzen |

## Datenweg

Fotos und Aufgaben-Anweisung werden über die vorhandene INMO-Funktion zur Analyse übertragen. Ein INMO-Konto, Internet und gegebenenfalls KI-Kontingent bleiben erforderlich. Es wird kein eigener KI-Anbieter oder zusätzlicher API-Schlüssel eingerichtet; das in INMO verfügbare Modell wird weiterverwendet.

Die eigenen Diagnose-Ereignisse enthalten Zustände und Text-/Bildlängen. Die unveränderte Hersteller-App kann daneben ausführlichere Logs erzeugen. Private APKs, Fotos, Rohlogs und Signierdateien gehören nicht ins Repository; `.gitignore` schließt die lokalen Arbeits- und Ausgabeordner aus.

## English overview

INMO GO 3 AutoFoto is an experimental local patch for **INMO Global 3.0.455**. Opening INMO AI triggers one photo request with a configurable task prompt and sends the answer to the glasses display without spoken output. The model is instructed to answer in the language of each question in the image. Turn **System Sound Effects off** in the glasses settings to silence the shutter click as well.

Only the custom source and build scripts are included. Supply your own installed vendor APKs; build on Windows with PowerShell 7, JDK 17, Android SDK tools, APKEditor and Apktool. The original INMO account/backend requirements still apply. This is not an official INMO SDK or release, and it has only been verified on the setup listed above.
