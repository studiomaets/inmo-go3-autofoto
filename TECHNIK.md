# Technischer Stand

Stand der Hardware-Bestätigung: 7. November 2026. Version: `3.0.455-autofoto.5`.

## Einbindung

Die eigene Java-Ergänzung wird als zusätzliche `classes6.dex` eingebunden. Das Build-Skript patcht ausschließlich die lokal dekodierte Kopie der eigenen INMO Global 3.0.455-Installation.

- `InmoAiService.startAsr()` wird bei aktivem Foto-Modus abgefangen. Nach ungefähr 800 ms wird `ProtocolGenerateHelper.takePictureAndRecognize(prompt)` über den bestehenden Bluetooth-Transport gesendet.
- Ein synthetischer ASR-Abschluss (`Foto-Aufgabe`, fertig) führt die Brillenoberfläche aus dem Eingabezustand. Dabei wird keine Sprache aufgenommen.
- Der bestehende INMO-Pfad übernimmt Fotoempfang, Upload, Modellanfrage und Antwortpakete fürs Display.
- `startTTS()` der Brillen-KI wird vor Erzeugung/Versand von Sprache blockiert. Ein expliziter TTS-Zustand `false` wird nach blockierter Sprache und Antwortende gesendet.
- Erneutes `START_AI` wird auch bei einem bereits laufenden Dienst verarbeitet. Pro Sitzung darf nur eine Anfrage laufen.
- Dienstende entfernt wartende Foto- und Zeitlimit-Callbacks. Ein veralteter Dienst kann eine neue Anfrage nicht freigeben. Ein Zeitlimit startet keine zusätzliche Aufnahme.
- `sendPhoneInfo()` meldet weiterhin die tatsächliche Hersteller-Basisversion. Die Entfernung des eigenen Versionssuffixes beseitigte im bestätigten Aufbau die Meldung „Version zu alt“; die genaue Firmware-Parserursache wurde nicht untersucht.

Der separate Systemsound-Schalter verwendet `getGlassesSettingsCommonMessage(SYSTEM_SOUND, 0)`. Die Hersteller-App speichert `key_system_sound=false` pro Gerät und synchronisiert es über `Go3Application.sendSystemSoundMessage()` beim Verbinden. Das wird über die vorhandene Benutzeroberfläche eingestellt, nicht durch einen weiteren AutoFoto-Patch.

## Prüfungen

`test.ps1` führt 29 JVM-Prüfungen mit kleinen Android-/INMO-Testdoubles aus. Abgedeckt werden unter anderem:

- kein Foto bei bloßer Objekterstellung und kein Wiederholungsautomat;
- unterdrückte Sprachausgabe und explizites Wiedergabeende;
- keine überlappenden Aufnahmen;
- erneuter Start im selben Dienst;
- Abbruch wartender Aufnahmen beim Stoppen;
- sofortiger Neustart und mehrere weitere vollständige Runden;
- keine Freigabe einer aktuellen Anfrage durch alte Sitzungen;
- kein Fotobefehl bei fehlender Verbindung oder gescheiterter Stummschaltung;
- Übergabe von Aufgaben-Anweisung und Sprachregel;
- Entfernung ausschließlich des eigenen Versionssuffixes.

Der Hardware-Test bestätigte vier aufeinanderfolgende Bild-/Antwort-Runden einschließlich Stoppen und Neustarten. Weitere Starts, sichtbare Antwort, Bedienbarkeit, passende Antwortsprache und vollständig stumme Aufnahme wurden anschließend vom Brillenträger bestätigt. Es wurde keine umfassende Matrix aus Firmwareständen und Sprachen getestet.

## Grenzen

- Keine offizielle GO-3-SDK-Anbindung und keine Zusicherung für andere App-Versionen.
- Kein Root und keine Änderungen an der Brillen-Firmware.
- Kein eigener Cloud-KI-Dienst; INMO-Konto, Netzwerk und Kontingent bleiben nötig.
- „Antwort gesendet“ bestätigt nur die lokale Übergabe an den vorhandenen Bluetooth-Pfad.
- KI-Antworten werden nicht auf sachliche Richtigkeit geprüft.
- Die lange GO-Taste erhält noch keine eigene AutoFoto-Belegung.
- Keine personenbezogenen Fotos, Seriennummern, Konto-Exporte oder Rohlogs im veröffentlichten Quellpaket.
