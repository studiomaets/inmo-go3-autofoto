package de.local.inmo.autofoto;

import android.app.Service;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;
import android.widget.Toast;
import java.lang.reflect.Method;
import java.lang.ref.WeakReference;

/** A small, local hook into the user's INMO Global 3.0.455 installation copy. */
public final class AutoFoto {
    public static final String TAG = "INMO_AutoFoto";
    public static final String LANGUAGE_RULE = "Antworte immer in der Sprache der jeweiligen Frage oder Aufgabe "
        + "auf dem Foto, nicht in der Sprache dieser Anweisung oder der App. "
        + "Bei mehreren Aufgaben in verschiedenen Sprachen beantworte jede in ihrer eigenen Sprache. "
        + "Wenn nur Zahlen oder Formeln ohne erkennbare Sprache zu sehen sind, verwende moeglichst wenig Begleittext.";
    public static final String DEFAULT_PROMPT = "Lies die Aufgabe auf diesem Foto und loese sie. "
        + "Antworte zuerst mit dem Ergebnis und danach mit hoechstens drei kurzen "
        + "Erklaerungs- oder Rechenschritten. Wenn mehrere Aufgaben sichtbar sind, nummeriere die Antworten. "
        + "Falls wichtige Angaben unlesbar sind, sage genau, welcher Bildausschnitt fehlt, statt zu raten. "
        + LANGUAGE_RULE;
    private static final Handler MAIN = new Handler(Looper.getMainLooper());
    private static long lastStart = -10000;
    private static volatile WeakReference<Service> active = new WeakReference<>(null);
    private static Runnable pendingPhoto;
    private static Runnable pendingTimeout;
    private static boolean busy;
    private static long generation;

    private AutoFoto() {}

    public static SharedPreferences prefs(Context context) {
        return context.getSharedPreferences("autofoto_settings", Context.MODE_PRIVATE);
    }

    public static String prompt(Context context) {
        String saved = prefs(context).getString("prompt", DEFAULT_PROMPT);
        String value = saved == null ? "" : saved.trim();
        if (value.length() == 0) value = DEFAULT_PROMPT;
        // Migrate the previous saved instruction, including an otherwise customized task.
        value = value.replace("Antworte auf Deutsch, zuerst", "Antworte zuerst");
        if (!value.contains(LANGUAGE_RULE)) value += " " + LANGUAGE_RULE;
        if (!value.equals(saved)) prefs(context).edit().putString("prompt", value).apply();
        return value;
    }

    public static Object singleton(String className) throws Exception {
        Object companion = Class.forName(className).getField("Companion").get(null);
        return companion.getClass().getMethod("getInstance").invoke(companion);
    }

    /** This local build is deliberately silent, including when photo mode is disabled. */
    public static boolean blockSpeech(Context context) {
        Log.i(TAG, "TTS_BLOCKED");
        if (context instanceof Service) {
            final Service service = (Service) context;
            MAIN.post(() -> playbackIdle(service));
        }
        return true;
    }

    public static void notePhoto(Service service, byte[] bytes) {
        Log.i(TAG, "PHOTO_RECEIVED bytes=" + (bytes == null ? 0 : bytes.length));
        if (active.get() == service) status(service, "Bild empfangen. KI verarbeitet die Aufgabe.");
    }

    /** Records only state and length; never the user's question or answer. */
    public static void noteDisplay(Service service, Object chat) {
        try {
            int state = (Integer) chat.getClass().getMethod("getState").invoke(chat);
            String content = (String) chat.getClass().getMethod("getContent").invoke(chat);
            Log.i(TAG, "DISPLAY_PACKET_LOCAL state=" + state + " chars=" + content.length());
            if (state == 5 && active.get() == service) {
                busy = false;
                if (pendingTimeout != null) MAIN.removeCallbacks(pendingTimeout);
                pendingTimeout = null;
                status(service, "Antwort gesendet. Bereit fuer das naechste Foto.");
                playbackIdle(service);
            }
        } catch (Exception ignored) {
            Log.i(TAG, "DISPLAY_PACKET_LOCAL");
        }
    }

    /** Keep the actual vendor version in the firmware handshake; only remove our suffix. */
    public static String protocolVersion(String version) {
        return version == null ? "" : version.replaceFirst("-autofoto\\.[0-9]+$", "");
    }

    private static boolean destroyed(Service service) {
        try { return (Boolean) service.getClass().getMethod("isDestroyed").invoke(service); }
        catch (Exception error) { return true; }
    }

    private static void playbackIdle(Service service) {
        if (destroyed(service)) return;
        try {
            Object bluetooth = singleton("com.inmo.app.module_go3device.utils.bt.BluetoothMultiProfileHelper");
            if (!(Boolean) bluetooth.getClass().getMethod("isSPPConnected").invoke(bluetooth)) return;
            Object protocol = singleton("com.inmo.app.module_go3device.utils.bt.ProtocolGenerateHelper");
            send(bluetooth, protocol.getClass().getMethod("aiTTSMessage", boolean.class).invoke(protocol, false));
            Log.i(TAG, "PLAYBACK_IDLE_DISPATCHED");
        } catch (Exception error) { Log.e(TAG, "PLAYBACK_IDLE_FAILED", error); }
    }

    public static synchronized void onServiceDestroyed(Service service) {
        if (active.get() != service) return;
        generation++;
        if (pendingPhoto != null) MAIN.removeCallbacks(pendingPhoto);
        if (pendingTimeout != null) MAIN.removeCallbacks(pendingTimeout);
        pendingPhoto = null;
        pendingTimeout = null;
        active.clear();
        busy = false;
        lastStart = -10000;
        Log.i(TAG, "PHOTO_SESSION_CLOSED");
    }

    /** The original manager discards START_AI when its service is already running. */
    public static boolean handleExistingStart() {
        final Service service = active.get();
        if (service == null || destroyed(service) || !prefs(service).getBoolean("enabled", true)) return false;
        MAIN.post(() -> {
            if (active.get() == service && !destroyed(service)) {
                Log.i(TAG, "EXISTING_SESSION_START");
                handleStart(service);
            }
        });
        return true;
    }

    public static void startFromPhone(Context context) {
        try {
            if (!prefs(context).getBoolean("enabled", true)) {
                status(context, "Bitte zuerst den Foto-Modus einschalten.");
                return;
            }
            if (handleExistingStart()) return;
            Object bluetooth = singleton("com.inmo.app.module_go3device.utils.bt.BluetoothMultiProfileHelper");
            if (!(Boolean) bluetooth.getClass().getMethod("isSPPConnected").invoke(bluetooth))
                throw new IllegalStateException("Brille ist nicht verbunden");
            Object protocol = singleton("com.inmo.app.module_go3device.utils.bt.ProtocolGenerateHelper");
            // Opening the glasses AI sends its normal START_AI event back to the app.
            send(bluetooth, switchAi(protocol, false, true));
            status(context, "INMO AI angefordert. Warte auf den Start der Brille.");
            Log.i(TAG, "PHONE_START_DISPATCHED");
        } catch (Exception error) { actionFailed(context, error); }
    }

    public static void stopFromPhone(Context context) {
        Service service = active.get();
        if (service != null) {
            onServiceDestroyed(service);
            service.stopSelf();
        }
        try {
            Object manager = singleton("com.inmo.app.module_go3device.manager.AiChatProbufProcessManager");
            manager.getClass().getMethod("stopAiService").invoke(manager);
            Object bluetooth = singleton("com.inmo.app.module_go3device.utils.bt.BluetoothMultiProfileHelper");
            Object protocol = singleton("com.inmo.app.module_go3device.utils.bt.ProtocolGenerateHelper");
            send(bluetooth, protocol.getClass().getMethod("aiTTSMessage", boolean.class).invoke(protocol, false));
            send(bluetooth, switchAi(protocol, true, false));
            status(context, "Stoppen und Schliessen von INMO AI angefordert.");
            Log.i(TAG, "PHONE_STOP_DISPATCHED");
        } catch (Exception error) { actionFailed(context, error); }
    }

    private static Object switchAi(Object protocol, boolean aiCommand, boolean open) throws Exception {
        String prefix = "com.inmo.app.module_go3device.";
        Class<?> appType = Class.forName(prefix + (aiCommand ? "AiChatProto$AiSwitchApplicationType" : "SwitchApplicationProto$SwitchApplicationType"));
        Class<?> ocType = Class.forName(prefix + (aiCommand ? "AiChatProto$AiOpenOrCloseType" : "SwitchApplicationProto$OpenOrCloseType"));
        Object app = appType.getField(aiCommand ? "AI_SWITCHPP_AI_ASSISTANT" : "SWITCHPP_AI_ASSISTANT").get(null);
        Object oc = ocType.getField((aiCommand ? "AI_APP_" : "APP_") + (open ? "OPEN" : "CLOSE")).get(null);
        return protocol.getClass().getMethod(aiCommand ? "aiSwitchApplication" : "switchApplication", appType, ocType).invoke(protocol, app, oc);
    }

    private static void actionFailed(Context context, Exception error) {
        Throwable cause = error.getCause() != null ? error.getCause() : error;
        status(context, "Aktion fehlgeschlagen: " + cause.getClass().getSimpleName());
        Log.e(TAG, "PHONE_ACTION_FAILED", error);
        Toast.makeText(context, "AutoFoto: " + cause.getMessage(), Toast.LENGTH_LONG).show();
    }

    private static void send(Object bluetooth, Object message) throws Exception {
        Method write = bluetooth.getClass().getMethod("unpackWrapWrite",
            Class.forName("com.inmo.app.module_go3device.MessageProto$Message"), int.class);
        write.invoke(bluetooth, message, 1);
    }

    private static void silence(Service service, Object bluetooth, Object protocol) throws Exception {
        // Silence the glasses before any capture command or input-state change is sent.
        send(bluetooth, protocol.getClass().getMethod("controlCommandVolume", int.class).invoke(protocol, 0));
        send(bluetooth, protocol.getClass().getMethod("aiTTSMute", boolean.class).invoke(protocol, true));
        send(bluetooth, protocol.getClass().getMethod("aiTTSMessage", boolean.class).invoke(protocol, false));
        // The original preference is ignored on some older firmware. The separate startTTS
        // guard below remains authoritative even if the preference is unsupported.
        Object manager = singleton("com.inmo.app.module_go3device.manager.InmoAiDataManager");
        manager.getClass().getMethod("setMuteTTS", boolean.class).invoke(manager, true);
        java.lang.reflect.Field field = service.getClass().getDeclaredField("inmoAiViewModel");
        field.setAccessible(true);
        Object model = field.get(service);
        if (model != null) {
            model.getClass().getMethod("setMuted", boolean.class).invoke(model, true);
            model.getClass().getMethod("stopTTS").invoke(model);
        }
        Log.i(TAG, "SILENCE_COMMANDS_DISPATCHED");
    }

    /** Return true to consume an explicit glasses AI-start instead of starting speech recognition. */
    public static synchronized boolean handleStart(final Service service) {
        if (!prefs(service).getBoolean("enabled", true)) return false;
        if (destroyed(service)) return true;
        if (active.get() != service) {
            Service previous = active.get();
            if (previous != null) onServiceDestroyed(previous);
            active = new WeakReference<>(service);
            lastStart = -10000;
        }
        if (busy) {
            Log.i(TAG, "PHOTO_BUSY_START_IGNORED");
            return true;
        }
        long now = SystemClock.elapsedRealtime();
        if (now - lastStart < 2500) {
            Log.i(TAG, "Duplicate AI start ignored");
            return true;
        }
        lastStart = now;
        busy = true;
        final long ticket = ++generation;
        status(service, "Foto-Anfrage wird vorbereitet.");
        // Let INMO's onStartCommand finish registering its listeners and foreground notification.
        pendingPhoto = () -> {
            if (active.get() != service || generation != ticket) return;
            pendingPhoto = null;
            requestPhoto(service);
        };
        MAIN.postDelayed(pendingPhoto, 800);
        pendingTimeout = () -> {
            if (active.get() != service || generation != ticket || !busy) return;
            // Do not start another camera request or overlap a late server response.
            status(service, "Keine fertige Antwort. Bitte INMO AI stoppen und neu starten.");
            Log.i(TAG, "PHOTO_SESSION_TIMEOUT");
        };
        MAIN.postDelayed(pendingTimeout, 75000);
        return true;
    }

    private static void requestPhoto(Service service) {
        try {
            if (destroyed(service) || !prefs(service).getBoolean("enabled", true)) {
                status(service, "Abgebrochen: INMO AI wurde geschlossen.");
                onServiceDestroyed(service);
                return;
            }
            Object bluetooth = singleton("com.inmo.app.module_go3device.utils.bt.BluetoothMultiProfileHelper");
            if (!(Boolean) bluetooth.getClass().getMethod("isSPPConnected").invoke(bluetooth)) {
                throw new IllegalStateException("Brille ist nicht verbunden");
            }
            Object serviceCompanion = service.getClass().getField("Companion").get(null);
            serviceCompanion.getClass().getMethod("setStopAi", boolean.class).invoke(serviceCompanion, false);
            String prompt = prompt(service);
            Object protocol = singleton("com.inmo.app.module_go3device.utils.bt.ProtocolGenerateHelper");
            silence(service, bluetooth, protocol);
            // No speech is recorded: this is the protocol's ordinary input-complete marker,
            // needed to move the glasses UI out of its listening state before the answer.
            send(bluetooth, protocol.getClass().getMethod("aiASRMessage", String.class, boolean.class)
                .invoke(protocol, "Foto-Aufgabe", true));
            Log.i(TAG, "DISPLAY_INPUT_FINISHED_DISPATCHED");
            Object message = protocol.getClass().getMethod("takePictureAndRecognize", String.class).invoke(protocol, prompt);
            send(bluetooth, message);
            // This confirms local dispatch only, not photo reception or a successful AI answer.
            status(service, "Fotobefehl gesendet. Bild und KI-Antwort noch nicht bestaetigt.");
            Log.i(TAG, "PHOTO_COMMAND_DISPATCHED");
        } catch (Exception error) {
            busy = false;
            if (pendingTimeout != null) MAIN.removeCallbacks(pendingTimeout);
            pendingTimeout = null;
            Throwable cause = error.getCause() != null ? error.getCause() : error;
            status(service, "Foto-Anfrage fehlgeschlagen: " + cause.getClass().getSimpleName());
            Log.e(TAG, "PHOTO_COMMAND_FAILED", error);
            Toast.makeText(service, "AutoFoto: " + cause.getMessage(), Toast.LENGTH_LONG).show();
        }
    }

    private static void status(Context context, String value) {
        prefs(context).edit().putString("last_status", value)
            .putLong("last_status_time", System.currentTimeMillis()).apply();
    }
}
