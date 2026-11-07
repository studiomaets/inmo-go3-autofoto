# Einrichtung und Bedienung

## Einmal einrichten

1. Die [lokal gebaute APK](BUILD.md) installieren und **INMO AutoFoto** öffnen.
2. **Foto-Modus aktiv** eingeschaltet lassen.
3. Die Aufgaben-Anweisung bei Bedarf bearbeiten und speichern.
4. **INMO öffnen und Brille verbinden** wählen, mit dem eigenen INMO-Konto anmelden und die GO 3 verbinden.
5. Die Original-App während des Tests schließen, damit beide Apps nicht um die Bluetooth-Verbindung konkurrieren.

Wenn zunächst die INMO-Einrichtung erscheint, diese abschließen und AutoFoto anschließend erneut über das App-Symbol öffnen.

## Eine Aufgabe lösen

1. Auf eine gut lesbare Frage oder Aufgabe schauen und die Brille ruhig halten.
2. INMO AI an der Brille per Taste oder Menü öffnen, ohne zu sprechen. Alternativ **Foto-Aufgabe jetzt starten** am Handy wählen.
3. Auf Fotoübertragung und KI-Antwort warten. Im bestätigten Aufbau lagen die Antworten typischerweise etwa 11–13 Sekunden nach dem Fotobefehl vor; das ist keine zugesicherte Latenz.
4. Die Antwort im Brillendisplay lesen.
5. Für eine weitere Aufgabe INMO AI erneut starten oder den Handy-Knopf verwenden.

Während einer laufenden Aufgabe werden zusätzliche Starts ignoriert. Der normale Kamera-Auslöser wird nicht umbelegt. Es gibt keine kontinuierliche Bildanalyse und keine Foto-Dauerschleife.

## Ohne Kameraklick und KI-Stimme

Die AutoFoto-Kopie blockiert die Sprachausgabe der Brillen-KI und setzt die Brillenlautstärke vor dem Foto auf 0. Für den Kameraklick zusätzlich den vorhandenen Herstellerschalter ausschalten:

**INMO-Startseite → Profilbild oben rechts → eigene GO 3 → Systemsound AUS**

In der englischen Oberfläche heißt der Schalter **System Sound Effects**. Er betrifft Systemtöne unabhängig von der KI-Sprachausgabe, wird gerätebezogen gespeichert und beim erneuten Verbinden synchronisiert. Im bestätigten Test verschwand dadurch auch der Kameraklick. Keine weitere APK-Änderung war nötig.

## Sprache der Antwort

Die Antwort soll der Sprache der jeweiligen Frage im Foto folgen. Bei mehreren Aufgaben in verschiedenen Sprachen gilt dies pro Aufgabe. Die Sprache der App-Oberfläche oder der deutschen Anweisung soll die Antwortsprache nicht bestimmen.

Version 5 passt die vorherige gespeicherte Standard-Anweisung „Antworte auf Deutsch“ automatisch an. Auch eigenen Anweisungen wird die Sprachregel angefügt. Bei reinen Formeln ohne erkennbare Sprache wird möglichst wenig Begleittext verlangt. Das bleibt eine Anweisung an das KI-Modell; Erkennungsfehler sind möglich.

## Wenn etwas hängen bleibt

| Beobachtung | Nächster Schritt |
| --- | --- |
| Antwort bleibt stehen, kein neues Foto | Am Handy **INMO AI stoppen und schließen** wählen, kurz warten und erneut starten. |
| Keine fertige Antwort nach längerer Wartezeit | Verbindung und Internet prüfen; laufende Anfrage stoppen und neu starten. |
| Kameraklick hörbar | **Systemsound** in den Einstellungen der tatsächlich verbundenen Brille ausschalten. |
| Bild unlesbar / Antwort unpassend | Größere Schrift oder Papier verwenden; Bildschirmhelligkeit senken und Spiegelungen vermeiden. |
| Brille verbindet sich nicht | Original-App schließen, GO 3 einschalten und Verbindung in AutoFoto herstellen. |
| Meldung „Version zu alt“ | Prüfen, ob die lokale Version `.4` oder `.5` installiert ist, und neu verbinden. Das Problem verschwand im bestätigten Aufbau mit dem normalisierten Versions-Handshake. |
| Lange GO-Taste startet eine andere Funktion | Eine eigene AutoFoto-Belegung des langen Tastendrucks ist noch nicht implementiert. |

## Rückweg

**Foto-Modus aktiv** ausschalten stellt die normale Spracheingabe in der Testkopie wieder her. Die KI-Sprachausgabe bleibt in dieser Kopie blockiert. Alternativ AutoFoto schließen und die separate Original-App verwenden.

Die Testkopie lässt sich separat deinstallieren. Das löscht ihre lokalen Einstellungen und Anmeldung. Brillenlautstärke und Systemsound sind Geräteeinstellungen und lassen sich bei Bedarf in den Brillen-Einstellungen wieder ändern.
