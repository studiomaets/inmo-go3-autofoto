param([string]$JavaHome = $env:JAVA_HOME)
$ErrorActionPreference = 'Stop'
if (-not $JavaHome) { throw 'Set JAVA_HOME or pass -JavaHome with your JDK 17 directory.' }
$testRoot = Join-Path $PSScriptRoot 'work\tests'
$jdk = [IO.Path]::GetFullPath($JavaHome)
$files = @{
'android/content/SharedPreferences.java' = @'
package android.content;
public class SharedPreferences {
  private final java.util.Map<String,Object> data = new java.util.HashMap<>();
  public boolean getBoolean(String k,boolean d){return data.containsKey(k)?(Boolean)data.get(k):d;}
  public String getString(String k,String d){return data.containsKey(k)?(String)data.get(k):d;}
  public Editor edit(){return new Editor();}
  public class Editor {
    public Editor putString(String k,String v){data.put(k,v);return this;}
    public Editor putBoolean(String k,boolean v){data.put(k,v);return this;}
    public Editor putLong(String k,long v){data.put(k,v);return this;}
    public void apply(){}
  }
}
'@
'android/content/Context.java' = @'
package android.content;
public class Context {
  public static final int MODE_PRIVATE=0;
  private final SharedPreferences settings = new SharedPreferences();
  public SharedPreferences getSharedPreferences(String n,int mode){return settings;}
}
'@
'android/app/Service.java' = 'package android.app; public class Service extends android.content.Context {public boolean stopRequested;public void stopSelf(){stopRequested=true;}}'
'android/os/Looper.java' = 'package android.os; public class Looper {public static Looper getMainLooper(){return new Looper();}}'
'android/os/SystemClock.java' = 'package android.os; public class SystemClock {public static long now=10000; public static long elapsedRealtime(){return now;}}'
'android/os/Handler.java' = @'
package android.os;
public class Handler {
  public static final java.util.List<Runnable> pending = new java.util.ArrayList<>();
  public static final java.util.Map<Runnable,Long> due = new java.util.HashMap<>();
  public Handler(Looper l){}
  public boolean post(Runnable r){return postDelayed(r,0);}
  public boolean postDelayed(Runnable r,long delay){pending.add(r);due.put(r,SystemClock.now+delay);return true;}
  public void removeCallbacks(Runnable r){pending.remove(r);due.remove(r);}
  public static void flush(){for(Runnable r:new java.util.ArrayList<>(pending)){if(due.containsKey(r)&&due.get(r)<=SystemClock.now){pending.remove(r);due.remove(r);r.run();}}}
  public static void advance(long ms){SystemClock.now+=ms;flush();}
}
'@
'android/util/Log.java' = 'package android.util; public class Log {public static int i(String t,String m){return 0;} public static int e(String t,String m,Throwable e){return 0;}}'
'android/widget/Toast.java' = 'package android.widget; public class Toast {public static final int LENGTH_LONG=1; public static Toast makeText(android.content.Context c,CharSequence t,int d){return new Toast();} public void show(){}}'
'com/inmo/app/module_go3device/MessageProto.java' = 'package com.inmo.app.module_go3device; public class MessageProto {public static class Message {public final String kind,prompt;public Message(String k,String p){kind=k;prompt=p;}}}'
'com/inmo/app/module_go3device/AiChatProto.java' = 'package com.inmo.app.module_go3device; public class AiChatProto {public enum AiSwitchApplicationType{AI_SWITCHPP_AI_ASSISTANT} public enum AiOpenOrCloseType{AI_APP_OPEN,AI_APP_CLOSE}}'
'com/inmo/app/module_go3device/SwitchApplicationProto.java' = 'package com.inmo.app.module_go3device; public class SwitchApplicationProto {public enum SwitchApplicationType{SWITCHPP_AI_ASSISTANT} public enum OpenOrCloseType{APP_OPEN,APP_CLOSE}}'
'com/inmo/app/module_go3device/manager/AiChatProbufProcessManager.java' = @'
package com.inmo.app.module_go3device.manager;
public class AiChatProbufProcessManager {
  public static final Companion Companion=new Companion();
  public static int starts=0,stops=0;
  public static class Companion {public AiChatProbufProcessManager getInstance(){return new AiChatProbufProcessManager();}}
  public void startAiService(){starts++;}
  public void stopAiService(){stops++;}
}
'@
'com/inmo/app/module_go3device/utils/bt/ProtocolGenerateHelper.java' = @'
package com.inmo.app.module_go3device.utils.bt;
import com.inmo.app.module_go3device.MessageProto;
public class ProtocolGenerateHelper {
  public static final Companion Companion=new Companion();
  public static class Companion {public ProtocolGenerateHelper getInstance(){return new ProtocolGenerateHelper();}}
  public MessageProto.Message takePictureAndRecognize(String p){return new MessageProto.Message("photo",p);}
  public MessageProto.Message controlCommandVolume(int v){return new MessageProto.Message("volume",String.valueOf(v));}
  public MessageProto.Message aiTTSMute(boolean v){return new MessageProto.Message("mute",String.valueOf(v));}
  public MessageProto.Message aiTTSMessage(boolean v){return new MessageProto.Message("ttsState",String.valueOf(v));}
  public MessageProto.Message aiASRMessage(String p,boolean end){return new MessageProto.Message("inputComplete",p+"|"+end);}
  public MessageProto.Message switchApplication(com.inmo.app.module_go3device.SwitchApplicationProto.SwitchApplicationType a,com.inmo.app.module_go3device.SwitchApplicationProto.OpenOrCloseType o){return new MessageProto.Message("switch",o.name());}
  public MessageProto.Message aiSwitchApplication(com.inmo.app.module_go3device.AiChatProto.AiSwitchApplicationType a,com.inmo.app.module_go3device.AiChatProto.AiOpenOrCloseType o){return new MessageProto.Message("aiSwitch",o.name());}
}
'@
'com/inmo/app/module_go3device/utils/bt/BluetoothMultiProfileHelper.java' = @'
package com.inmo.app.module_go3device.utils.bt;
import com.inmo.app.module_go3device.MessageProto;
public class BluetoothMultiProfileHelper {
  public static final Companion Companion=new Companion();
  public static final java.util.List<MessageProto.Message> sent=new java.util.ArrayList<>();
  public static boolean connected=true;
  public static boolean failMute=false;
  public static class Companion {public BluetoothMultiProfileHelper getInstance(){return new BluetoothMultiProfileHelper();}}
  public boolean isSPPConnected(){return connected;}
  public void unpackWrapWrite(MessageProto.Message m,int destination){if(destination!=1)throw new AssertionError("wrong chip");if(failMute&&m.kind.equals("mute"))throw new IllegalStateException("mute rejected");sent.add(m);}
}
'@
'com/inmo/app/module_go3device/services/InmoAiService.java' = @'
package com.inmo.app.module_go3device.services;
public class InmoAiService extends android.app.Service {
  public boolean destroyed=false;
  public static final Companion Companion=new Companion();
  public boolean isDestroyed(){return destroyed;}
  public static class Companion {public void setStopAi(boolean value){}}
  private final FakeModel inmoAiViewModel=new FakeModel();
  public static class FakeModel {public static boolean muted=false,stopped=false;public void setMuted(boolean m){muted=m;}public void stopTTS(){stopped=true;}}
}
'@
'com/inmo/app/module_go3device/manager/InmoAiDataManager.java' = @'
package com.inmo.app.module_go3device.manager;
public class InmoAiDataManager {
  public static final Companion Companion=new Companion();
  public static class Companion {public InmoAiDataManager getInstance(){return new InmoAiDataManager();}}
  public void setMuteTTS(boolean value){}
}
'@
'AutoFotoTest.java' = @'
import de.local.inmo.autofoto.AutoFoto;
import com.inmo.app.module_go3device.services.InmoAiService;
import com.inmo.app.module_go3device.utils.bt.BluetoothMultiProfileHelper;
import android.os.Handler;
import android.os.SystemClock;
public class AutoFotoTest {
  static int checks=0;
  static void check(boolean condition,String label){checks++;if(!condition)throw new AssertionError(label);System.out.println("PASS "+label);}
  static void tick(){Handler.advance(3000);}
  static long photos(){return BluetoothMultiProfileHelper.sent.stream().filter(m->m.kind.equals("photo")).count();}
  public static class Chat {final int state;Chat(int s){state=s;}public int getState(){return state;}public String getContent(){return "answer";}}
  static void finish(InmoAiService s){AutoFoto.noteDisplay(s,new Chat(5));}
  public static void main(String[] args){
    InmoAiService service=new InmoAiService();
    check(BluetoothMultiProfileHelper.sent.isEmpty(),"no capture on construction");
    AutoFoto.prefs(service).edit().putBoolean("enabled",false).apply();
    check(!AutoFoto.handleStart(service)&&Handler.pending.isEmpty(),"disabled mode leaves voice path intact");
    check(AutoFoto.blockSpeech(service),"AI speech stays blocked even with manual voice input");
    Handler.flush();
    check(BluetoothMultiProfileHelper.sent.get(0).kind.equals("ttsState")&&BluetoothMultiProfileHelper.sent.get(0).prompt.equals("false"),"blocked speech explicitly releases firmware playback state");
    BluetoothMultiProfileHelper.sent.clear();
    AutoFoto.prefs(service).edit().putBoolean("enabled",true).putString("prompt","TEST QUESTION").apply();
    check(AutoFoto.handleStart(service)&&BluetoothMultiProfileHelper.sent.isEmpty(),"capture waits for service listeners");
    AutoFoto.handleStart(service);
    check(Handler.pending.size()==2,"duplicate start does not schedule a second photo or timeout");
    Handler.advance(800);
    check(photos()==1&&BluetoothMultiProfileHelper.sent.get(4).prompt.equals("TEST QUESTION " + AutoFoto.LANGUAGE_RULE),"one photo contains configured question and answer language rule");
    check(BluetoothMultiProfileHelper.sent.get(0).kind.equals("volume")&&BluetoothMultiProfileHelper.sent.get(0).prompt.equals("0"),"glasses volume is set to zero before capture");
    check(BluetoothMultiProfileHelper.sent.get(1).kind.equals("mute")&&BluetoothMultiProfileHelper.sent.get(1).prompt.equals("true")&&BluetoothMultiProfileHelper.sent.get(2).prompt.equals("false"),"mute and inactive playback state precede capture");
    check(InmoAiService.FakeModel.muted&&InmoAiService.FakeModel.stopped,"existing app speech is muted and stopped");
    check(BluetoothMultiProfileHelper.sent.get(3).kind.equals("inputComplete")&&BluetoothMultiProfileHelper.sent.get(3).prompt.endsWith("|true"),"display input completes before the photo request");
    tick();AutoFoto.handleStart(service);Handler.advance(800);
    check(photos()==1,"busy request prevents overlapping capture even after debounce");
    finish(service);
    check(Handler.pending.isEmpty(),"answer completion clears timeout without an automatic repeat");
    check(AutoFoto.handleExistingStart(),"START_AI is handled while the old service is alive");
    Handler.flush();Handler.advance(800);
    check(photos()==2,"new explicit START_AI produces another photo in the same service");
    finish(service);tick();
    AutoFoto.handleStart(service);AutoFoto.onServiceDestroyed(service);service.destroyed=true;Handler.advance(800);
    check(photos()==2&&Handler.pending.isEmpty(),"destroy cancels queued capture and timeout");
    check(!AutoFoto.handleExistingStart(),"destroyed service leaves original start path available");
    InmoAiService next=new InmoAiService();
    BluetoothMultiProfileHelper.connected=false;AutoFoto.handleStart(next);Handler.advance(800);
    check(photos()==2,"disconnected glasses receive no photo");
    tick();BluetoothMultiProfileHelper.connected=true;AutoFoto.prefs(next).edit().putString("prompt","   ").apply();AutoFoto.handleStart(next);Handler.advance(800);
    check(photos()==3&&BluetoothMultiProfileHelper.sent.get(BluetoothMultiProfileHelper.sent.size()-1).prompt.equals(AutoFoto.DEFAULT_PROMPT),"retry works and empty prompt uses default");
    finish(service);tick();AutoFoto.handleStart(next);Handler.advance(800);
    check(photos()==3,"late end from previous service cannot unlock the active request");
    finish(next);tick();BluetoothMultiProfileHelper.failMute=true;AutoFoto.handleStart(next);Handler.advance(800);
    check(photos()==3,"silencing failure prevents camera capture");
    BluetoothMultiProfileHelper.failMute=false;tick();AutoFoto.handleStart(next);Handler.advance(800);finish(next);
    check(photos()==4,"failed request can be retried");
    tick();AutoFoto.handleStart(next);AutoFoto.stopFromPhone(next);Handler.advance(800);
    check(photos()==4&&next.stopRequested&&Handler.pending.isEmpty(),"phone stop cancels pending capture and stops service");
    check(BluetoothMultiProfileHelper.sent.get(BluetoothMultiProfileHelper.sent.size()-1).prompt.equals("AI_APP_CLOSE"),"phone stop requests glasses exit using vendor command");
    InmoAiService fresh=new InmoAiService();AutoFoto.handleStart(fresh);Handler.advance(800);finish(fresh);
    check(photos()==5,"immediate reopen is not suppressed by previous service debounce");
    for(int i=0;i<4;i++){tick();AutoFoto.handleExistingStart();Handler.flush();Handler.advance(800);finish(fresh);}
    check(photos()==9,"four further completed rounds do not get stuck");
    AutoFoto.handleExistingStart();AutoFoto.onServiceDestroyed(fresh);Handler.flush();Handler.advance(800);
    check(photos()==9&&Handler.pending.isEmpty(),"stop invalidates an already queued repeat start");
    fresh.destroyed=true;
    AutoFoto.startFromPhone(fresh);
    check(BluetoothMultiProfileHelper.sent.get(BluetoothMultiProfileHelper.sent.size()-1).prompt.equals("APP_OPEN"),"phone start opens glasses AI and waits for its start event");
    check(AutoFoto.protocolVersion("3.0.455-autofoto.4").equals("3.0.455")&&AutoFoto.protocolVersion("3.0.455").equals("3.0.455")&&AutoFoto.protocolVersion("3.0.455-beta").equals("3.0.455-beta"),"handshake removes only our suffix without inventing a newer version");
    System.out.println(checks+" checks passed; hardware and vendor backend are not simulated.");
  }
}
'@
}
$src = Join-Path $testRoot 'src'
$classes = Join-Path $testRoot 'classes'
New-Item -ItemType Directory -Force -Path $src,$classes | Out-Null
foreach ($entry in $files.GetEnumerator()) {
  $path = Join-Path $src $entry.Key
  New-Item -ItemType Directory -Force -Path (Split-Path $path -Parent) | Out-Null
  [IO.File]::WriteAllText($path, $entry.Value, [Text.UTF8Encoding]::new($false))
}
$helper = Join-Path $PSScriptRoot 'AutoFoto.java'
$javaFiles = @(Get-ChildItem $src -Recurse -Filter '*.java' | ForEach-Object FullName) + @($helper)
& (Join-Path $jdk 'bin\javac.exe') --release 8 -encoding UTF-8 -d $classes @javaFiles
if ($LASTEXITCODE -ne 0) { throw 'Test compilation failed.' }
& (Join-Path $jdk 'bin\java.exe') -cp $classes AutoFotoTest
if ($LASTEXITCODE -ne 0) { throw 'Hook behavior checks failed.' }
