package de.local.inmo.autofoto;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.os.Bundle;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.Switch;
import android.widget.TextView;
import android.widget.Toast;

public final class SettingsActivity extends Activity {
    private EditText prompt;
    private TextView state;

    @Override public void onCreate(Bundle savedState) {
        super.onCreate(savedState);
        getWindow().setStatusBarColor(Color.rgb(18, 42, 49));
        getWindow().setNavigationBarColor(Color.rgb(18, 42, 49));
        ScrollView scroll = new ScrollView(this);
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        int pad = (int) (24 * getResources().getDisplayMetrics().density);
        layout.setPadding(pad, pad, pad, pad);
        layout.setBackgroundColor(Color.rgb(245, 249, 247));
        scroll.addView(layout);
        setContentView(scroll);

        addText(layout, "INMO AutoFoto", 28);
        addText(layout, "Lokale Testversion 5 · Basis: INMO Global 3.0.455", 13);
        addText(layout, "KI starten. Foto aufnehmen. Aufgabe lösen.", 20);
        addText(layout, "Richte die Brille auf die Aufgabe und starte INMO AI an der Brille. "
            + "Im aktiven Foto-Modus wird anstelle der Spracheingabe ein Foto mit der unten stehenden Anweisung angefordert. "
            + "Für das nächste Foto die KI schließen und erneut öffnen.", 16);
        addText(layout, "Stille Ausgabe: Die Sprachausgabe der Brillen-KI ist in dieser Version blockiert. "
            + "Vor jeder Foto-Anfrage wird die Brillenlautstärke auf 0 gesetzt. "
            + "Die Antwort erscheint im Display in der Sprache der jeweiligen Frage auf dem Foto.", 16);

        Switch enabled = new Switch(this);
        enabled.setText("Foto-Modus aktiv");
        enabled.setTextSize(18);
        enabled.setPadding(0, pad, 0, pad);
        enabled.setChecked(AutoFoto.prefs(this).getBoolean("enabled", true));
        enabled.setOnCheckedChangeListener((button, checked) ->
            AutoFoto.prefs(this).edit().putBoolean("enabled", checked).apply());
        layout.addView(enabled);

        Button photo = new Button(this);
        photo.setText("Foto-Aufgabe jetzt starten");
        photo.setOnClickListener(view -> {
            if (savePrompt()) AutoFoto.startFromPhone(this);
            refreshStatus();
        });
        layout.addView(photo);
        Button stop = new Button(this);
        stop.setText("INMO AI stoppen und schließen");
        stop.setOnClickListener(view -> { AutoFoto.stopFromPhone(this); refreshStatus(); });
        layout.addView(stop);
        addText(layout, "Falls die Antwort stehen bleibt: erst stoppen, dann erneut starten. "
            + "Während einer laufenden Aufgabe werden zusätzliche Fotostarts ignoriert.", 15);

        addText(layout, "Anweisung für jedes Foto", 17);
        prompt = new EditText(this);
        prompt.setTextSize(16);
        prompt.setMinLines(5);
        prompt.setGravity(android.view.Gravity.TOP);
        prompt.setInputType(android.text.InputType.TYPE_CLASS_TEXT | android.text.InputType.TYPE_TEXT_FLAG_MULTI_LINE);
        prompt.setText(AutoFoto.prompt(this));
        layout.addView(prompt, new LinearLayout.LayoutParams(-1, -2));
        Button save = new Button(this);
        save.setText("Anweisung speichern");
        save.setOnClickListener(view -> savePrompt());
        layout.addView(save);

        Button open = new Button(this);
        open.setText("INMO öffnen und Brille verbinden");
        open.setOnClickListener(view -> {
            if (!savePrompt()) return;
            Intent intent = new Intent();
            intent.setClassName(getPackageName(), "com.inmo.app.SplashActivity");
            startActivity(intent);
        });
        layout.addView(open);

        addText(layout, "Einrichtung", 19);
        addText(layout, "In dieser separaten App einmal mit deinem INMO-Konto anmelden und die GO 3 verbinden. "
            + "Die Original-App vorher schließen, damit sie die Bluetooth-Verbindung nicht belegt. "
            + "Modell, Internetzugang und Kontingent kommen weiterhin von INMO. "
            + "Fotos werden über den vorhandenen INMO-Ablauf zur Analyse übertragen.", 15);
        addText(layout, "Teststatus", 19);
        addText(layout, "Experimenteller Umbau. Eine vollständige Aufnahme samt Antwort im Display muss an deiner Brille geprüft werden. "
            + "Der normale Kamera-Auslöser ist in dieser Version nicht umbelegt; der Auslöser ist der Start von INMO AI.", 15);
        state = addText(layout, "", 14);
        Button refresh = new Button(this);
        refresh.setText("Status aktualisieren");
        refresh.setOnClickListener(view -> refreshStatus());
        layout.addView(refresh);
        addText(layout, "Rückweg: Foto-Modus ausschalten für manuelle Spracheingabe mit weiterhin stummen KI-Antworten. "
            + "Oder diese App schließen und die unveränderte Original-App verwenden.", 14);
    }

    private boolean savePrompt() {
        String value = prompt.getText().toString().trim();
        if (value.length() == 0) {
            prompt.setError("Bitte eine Anweisung eingeben.");
            return false;
        }
        if (value.length() > 2000) {
            prompt.setError("Bitte höchstens 2000 Zeichen verwenden.");
            return false;
        }
        AutoFoto.prefs(this).edit().putString("prompt", value).apply();
        prompt.setText(AutoFoto.prompt(this));
        Toast.makeText(this, "Anweisung gespeichert", Toast.LENGTH_SHORT).show();
        return true;
    }

    private TextView addText(LinearLayout layout, String text, int size) {
        TextView view = new TextView(this);
        view.setText(text);
        view.setTextSize(size);
        view.setTextColor(Color.rgb(23, 47, 51));
        view.setPadding(0, 14, 0, 8);
        layout.addView(view);
        return view;
    }

    @Override protected void onResume() { super.onResume(); refreshStatus(); }
    private void refreshStatus() {
        if (state != null) state.setText(AutoFoto.prefs(this).getString("last_status", "Noch kein Foto angefordert."));
    }
}
