package cn.myfines.instrument.devicetest;

import android.app.Instrumentation;
import android.content.Intent;
import android.os.Bundle;
import android.os.SystemClock;
import cn.myfines.instrument.DirectExtension;
import cn.myfines.instrument.WifiSession;
import cn.myfines.instrument.ExtensionProtocol;
import cn.myfines.instrument.ScoreDownload;
import cn.myfines.instrument.reference.ReferenceActivity;
import cn.myfines.instrument.reference.Protocol;
import org.json.JSONArray;
import org.json.JSONObject;
import java.lang.reflect.Field;
import java.io.File;
import java.io.FileOutputStream;
import android.view.View;
import android.view.MotionEvent;
import android.view.InputDevice;
import android.graphics.RectF;

/** Real installed App callbacks + real ESP TCP; not a physical touch/display test. */
public final class DeviceSuite extends Instrumentation {
    private ReferenceActivity activity;
    private final JSONArray results=new JSONArray();
    private long started;
    private String mode="full";
    private String downloadUrl="https://cdn.jsdelivr.net/gh/myfines/d-dfdf@e031-web-control/docs/demo-score.txt";
    private Object field(Object object,String name)throws Exception {
        Field f=object.getClass().getDeclaredField(name);f.setAccessible(true);return f.get(object);
    }
    private void action(Runnable work){runOnMainSync(work);waitForIdleSync();}
    private Object activityField(String name)throws Exception {
        final Object[] value=new Object[1];final Exception[] error=new Exception[1];
        runOnMainSync(()->{try{value[0]=field(activity,name);}catch(Exception e){error[0]=e;}});
        if(error[0]!=null)throw error[0];return value[0];
    }
    private Protocol.Snapshot snapshot()throws Exception {
        final Object[] value=new Object[1];final Exception[] error=new Exception[1];
        runOnMainSync(()->{try{value[0]=field(field(activity,"view"),"snapshot");}catch(Exception e){error[0]=e;}});
        if(error[0]!=null)throw error[0];return (Protocol.Snapshot)value[0];
    }
    private void check(String name,boolean passed,Object observed)throws Exception {
        JSONObject row=new JSONObject().put("test",name).put("passed",passed).put("observed",String.valueOf(observed)).put("elapsed_ms",SystemClock.elapsedRealtime()-started);
        results.put(row);Bundle progress=new Bundle();progress.putString("stream",row.toString()+"\n");sendStatus(0,progress);
        if(!passed)throw new AssertionError(name+": "+observed);
    }
    private View textView(View root,String text){
        if(root instanceof android.widget.TextView&&text.contentEquals(((android.widget.TextView)root).getText()))return root;
        if(root instanceof android.view.ViewGroup){android.view.ViewGroup group=(android.view.ViewGroup)root;for(int i=0;i<group.getChildCount();i++){View found=textView(group.getChildAt(i),text);if(found!=null)return found;}}
        return null;
    }
    private void openEffects()throws Exception {
        action(()->activity.onSettings());
        android.app.AlertDialog settings=(android.app.AlertDialog)activityField("settingsDialog");
        View button=textView(settings.getWindow().getDecorView(),"直连扩展 · 颤音 / ADSR / 曲谱 / 键位 / 录音");
        if(button==null)throw new AssertionError("extension entry missing");
        action(()->button.performClick());
    }
    private android.widget.CheckBox effectBox(String text)throws Exception {
        android.app.AlertDialog dialog=(android.app.AlertDialog)activityField("extensionDialog");
        return (android.widget.CheckBox)textView(dialog.getWindow().getDecorView(),text);
    }
    private void applyEffects()throws Exception {
        android.app.AlertDialog dialog=(android.app.AlertDialog)activityField("extensionDialog");
        View button=textView(dialog.getWindow().getDecorView(),"应用FPGA效果器组合");
        action(()->button.performClick());SystemClock.sleep(600);
    }
    private void closeEffects()throws Exception {
        android.app.AlertDialog extra=(android.app.AlertDialog)activityField("extensionDialog");
        android.app.AlertDialog settings=(android.app.AlertDialog)activityField("settingsDialog");
        action(()->{extra.dismiss();settings.dismiss();});
    }
    private void connected()throws Exception {
        action(()->activity.onConnectClick());
        long end=SystemClock.elapsedRealtime()+30000;
        while(SystemClock.elapsedRealtime()<end&&!Boolean.TRUE.equals(activityField("ready")))SystemClock.sleep(200);
        check("real TCP connection and snapshot",Boolean.TRUE.equals(activityField("ready")),activityField("ready"));
        Protocol.Snapshot s=snapshot();check("FPGA armed",s!=null&&s.armed(),s==null?"no snapshot":s.flags);
        check("32-point actual snapshot",s.wave.length==32,s.wave.length);
    }
    @Override public void onCreate(Bundle arguments){super.onCreate(arguments);if(arguments!=null){mode=arguments.getString("mode","full");downloadUrl=arguments.getString("url",downloadUrl);}start();}
    private void touch(int count,int actionCode,long down)throws Exception {
        View view=(View)activityField("view");RectF[] pads=(RectF[])field(view,"pads");
        MotionEvent.PointerProperties[] properties=new MotionEvent.PointerProperties[count];
        MotionEvent.PointerCoords[] coordinates=new MotionEvent.PointerCoords[count];
        for(int i=0;i<count;i++){
            properties[i]=new MotionEvent.PointerProperties();properties[i].id=i;properties[i].toolType=MotionEvent.TOOL_TYPE_FINGER;
            coordinates[i]=new MotionEvent.PointerCoords();coordinates[i].x=pads[i].centerX();coordinates[i].y=pads[i].bottom-20;coordinates[i].pressure=1;coordinates[i].size=1;
        }
        MotionEvent event=MotionEvent.obtain(down,SystemClock.uptimeMillis(),actionCode,count,properties,coordinates,0,0,1,1,0,0,InputDevice.SOURCE_TOUCHSCREEN,0);
        try{action(()->view.dispatchTouchEvent(event));}finally{event.recycle();}
    }
    private void export(Bundle output)throws Exception {
        File file=new File(getTargetContext().getExternalFilesDir(null),"device-suite-record.wav");
        byte[] wav=java.nio.file.Files.readAllBytes(file.toPath());
        android.content.ContentValues values=new android.content.ContentValues();
        values.put(android.provider.MediaStore.MediaColumns.DISPLAY_NAME,"FPGA-test-export-"+System.currentTimeMillis()+".wav");
        values.put(android.provider.MediaStore.MediaColumns.MIME_TYPE,"audio/wav");
        values.put(android.provider.MediaStore.MediaColumns.RELATIVE_PATH,android.os.Environment.DIRECTORY_DOWNLOADS);
        android.net.Uri uri=activity.getContentResolver().insert(android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI,values);
        if(uri==null)throw new java.io.IOException("test export URI not created");
        try{
            action(()->{try{
                Field pending=activity.getClass().getDeclaredField("pendingWav");pending.setAccessible(true);pending.set(activity,wav);
                java.lang.reflect.Method result=activity.getClass().getDeclaredMethod("onActivityResult",int.class,int.class,Intent.class);result.setAccessible(true);
                result.invoke(activity,701,android.app.Activity.RESULT_OK,new Intent().setData(uri));
            }catch(Exception e){throw new RuntimeException(e);}});
            byte[] saved=new byte[0];long end=SystemClock.elapsedRealtime()+5000;
            while(SystemClock.elapsedRealtime()<end){
                try(java.io.InputStream stream=activity.getContentResolver().openInputStream(uri);java.io.ByteArrayOutputStream bytes=new java.io.ByteArrayOutputStream()){
                    byte[] buffer=new byte[4096];int n;while((n=stream.read(buffer))!=-1)bytes.write(buffer,0,n);saved=bytes.toByteArray();
                }
                if(saved.length==wav.length)break;SystemClock.sleep(100);
            }
            check("actual App export handler and content URI bytes",java.util.Arrays.equals(wav,saved),saved.length);
            android.media.MediaPlayer player=new android.media.MediaPlayer();
            try{
                java.util.concurrent.CountDownLatch done=new java.util.concurrent.CountDownLatch(1);
                player.setDataSource(activity,uri);player.setOnCompletionListener(p->done.countDown());player.prepare();int duration=player.getDuration();player.start();
                check("Android player decodes and completes exported WAV",done.await(3,java.util.concurrent.TimeUnit.SECONDS)&&duration>600&&duration<900,duration);
            }finally{player.release();}
            output.putBoolean("passed",true);
        }finally{activity.getContentResolver().delete(uri,null,null);}
    }
    private void gesture(WifiSession link,Bundle output)throws Exception {
        link.effects(0);link.vibrato(0);link.demo(false);link.page(1);
        ((DirectExtension)activityField("extension")).resetEnvelope();
        action(()->{activity.onTimbre(1);activity.onVolumeChanged(160,true);});
        SystemClock.sleep(700);action(()->activity.onPadDown(4));
        JSONArray samples=new JSONArray();long begin=SystemClock.elapsedRealtime(),last=0;
        Bundle ready=new Bundle();ready.putString("stream","GESTURE_WINDOW_READY_90_SECONDS\n");sendStatus(0,ready);
        try{
            while(SystemClock.elapsedRealtime()-begin<90000){
                Protocol.Snapshot s=snapshot();long elapsed=SystemClock.elapsedRealtime()-begin;
                int min=9999,max=-9999;for(int v:s.wave){min=Math.min(min,v);max=Math.max(max,v);}
                JSONObject row=new JSONObject().put("ms",elapsed).put("sequence",s.sequence).put("pinch",s.pinch).put("height",s.gestureY).put("confidence",s.confidence).put("gesture_active",s.gestureActive).put("x",s.x).put("y",s.y).put("volume",s.volume).put("keys",s.keys).put("wave_span",max-min);
                samples.put(row);
                if(elapsed-last>5000){Bundle progress=new Bundle();progress.putString("stream",row.toString()+"\n");sendStatus(0,progress);last=elapsed;}
                SystemClock.sleep(200);
            }
        }finally{action(()->activity.onPadUp(4));link.page(0);}
        File file=new File(getTargetContext().getExternalFilesDir(null),"device-suite-gesture.json");
        try(FileOutputStream stream=new FileOutputStream(file)){stream.write(samples.toString().getBytes("UTF-8"));}
        output.putString("gesture_path",file.getAbsolutePath());
        check("real phone gesture telemetry capture",samples.length()>300,samples.length());
    }
    @Override public void onStart(){
        started=SystemClock.elapsedRealtime();Bundle output=new Bundle();
        try {
            Intent launch=new Intent(getTargetContext(),ReferenceActivity.class);launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            activity=(ReferenceActivity)startActivitySync(launch);
            if(mode.equals("score-setup")){
                android.content.SharedPreferences prefs=activity.getSharedPreferences("reference_wifi",0);
                String previousUrl=prefs.getString("score_url",null),previousScore=prefs.getString("score",null);
                try{
                    prefs.edit().putString("score_url","").remove("score").commit();openEffects();
                    android.app.AlertDialog dialog=(android.app.AlertDialog)activityField("extensionDialog");
                    check("ready-to-use example URL visible",textView(dialog.getWindow().getDecorView(),ScoreDownload.EXAMPLE_URL)!=null,"default URL");
                    check("bundled example visible offline",textView(dialog.getWindow().getDecorView(),ScoreDownload.EXAMPLE_SCORE)!=null,"valid score without network");
                    View record=textView(dialog.getWindow().getDecorView(),"录制设备PCM并导出WAV（点击后演奏）");
                    action(()->{try{Field busy=activity.getClass().getDeclaredField("extensionBusy");busy.setAccessible(true);busy.setBoolean(activity,true);}catch(Exception e){throw new RuntimeException(e);}record.performClick();});
                    check("rejected busy recording keeps dialog open",dialog.isShowing(),"no unrelated dismissal");
                    output.putBoolean("passed",true);return;
                }finally{
                    prefs.edit().putString("score_url",previousUrl).putString("score",previousScore).commit();
                    action(()->{try{Field busy=activity.getClass().getDeclaredField("extensionBusy");busy.setAccessible(true);busy.setBoolean(activity,false);}catch(Exception e){throw new RuntimeException(e);}});closeEffects();
                }
            }
            if(mode.equals("export")){export(output);return;}
            if(mode.equals("download")){
                String text=ScoreDownload.fetch(downloadUrl);
                activity.getSharedPreferences("reference_wifi",0).edit().putString("score",text).commit();
                check("actual phone Internet score download and cache",text.equals(activity.getSharedPreferences("reference_wifi",0).getString("score","")),text);
                boolean rejected=false;try{ScoreDownload.fetch("file:///sdcard/not-a-score");}catch(Exception expected){rejected=true;}
                check("invalid download scheme rejected on phone",rejected,rejected);
                output.putBoolean("passed",true);return;
            }
            connected();
            WifiSession link=(WifiSession)activityField("session");
            DirectExtension extension=(DirectExtension)activityField("extension");
            if(mode.equals("effects")){
                openEffects();
                android.widget.CheckBox chorus=effectBox("合唱"),delay=effectBox("延迟"),reverb=effectBox("混响");
                action(()->{chorus.setChecked(false);delay.setChecked(false);reverb.setChecked(false);});applyEffects();
                action(()->{chorus.performClick();reverb.performClick();});
                check("real checkbox click toggles chorus/reverb",chorus.isChecked()&&reverb.isChecked()&&!delay.isChecked(),"mask5 selected");
                applyEffects();check("combined command retains exact mask5",((Integer)field(link,"fx"))==5,field(link,"fx"));
                check("saved effect mask5",activity.getSharedPreferences("reference_wifi",0).getInt("effects",-1)==5,"saved effects");
                closeEffects();openEffects();
                check("dialog reopen retains chorus/reverb",effectBox("合唱").isChecked()&&effectBox("混响").isChecked()&&!effectBox("延迟").isChecked(),"mask5 restored");
                closeEffects();action(()->activity.onEcho(true));
                check("main delay on preserves chorus/reverb",((Integer)field(link,"fx"))==7,field(link,"fx"));
                action(()->activity.onEcho(false));
                check("main delay off preserves chorus/reverb",((Integer)field(link,"fx"))==5,field(link,"fx"));
                action(()->activity.onConnectClick());connected();link=(WifiSession)activityField("session");
                check("reconnect replays chorus/reverb mask5",((Integer)field(link,"fx"))==5,field(link,"fx"));
                check("FPGA aggregate effect flag active",snapshot().echo,"aggregate only, not exact mask readback");
                openEffects();android.widget.CheckBox c=effectBox("合唱"),d=effectBox("延迟"),r=effectBox("混响");
                action(()->{c.setChecked(false);d.setChecked(false);r.setChecked(false);});applyEffects();closeEffects();
                output.putBoolean("passed",true);return;
            }
            if(mode.equals("touch")){
                long down=SystemClock.uptimeMillis();
                touch(1,MotionEvent.ACTION_DOWN,down);SystemClock.sleep(300);
                for(int i=1;i<4;i++){touch(i+1,MotionEvent.ACTION_POINTER_DOWN|(i<<MotionEvent.ACTION_POINTER_INDEX_SHIFT),down);SystemClock.sleep(300);}
                check("actual View four-pointer chord reaches FPGA",(snapshot().keys&15)==15,snapshot().keys);
                for(int i=3;i>0;i--){touch(i+1,MotionEvent.ACTION_POINTER_UP|(i<<MotionEvent.ACTION_POINTER_INDEX_SHIFT),down);SystemClock.sleep(300);check("actual View selective pointer release"+i,(snapshot().keys&15)==((1<<i)-1),snapshot().keys);}
                touch(1,MotionEvent.ACTION_UP,down);SystemClock.sleep(300);check("actual View last pointer released",snapshot().keys==0,snapshot().keys);
                output.putBoolean("passed",true);return;
            }
            if(mode.equals("cached")){
                String text=activity.getSharedPreferences("reference_wifi",0).getString("score","");
                check("cached online score persists across network change",!text.isEmpty(),text);
                extension.score(text);check("cached online score acknowledged by real FPGA",true,"real A frame");
                output.putBoolean("passed",true);return;
            }
            if(mode.equals("display")){
                link.page(1);action(()->{activity.onTimbre(1);activity.onVolumeChanged(32,true);activity.onPadDown(4);});
                for(int screen=0;screen<5;screen++){
                    link.screen(screen);link.effects(screen==2?1:0);link.demo(screen<3);link.volume(screen<3?80:32);
                    if(screen==3){extension.score("0:100,12:100,-:100,31:100");link.extension("R01");}
                    if(screen==4){link.extension("R00");link.demo(true);link.volume(16);}
                    Bundle progress=new Bundle();progress.putString("stream","DISPLAY_PAGE_"+screen+"_OBSERVE_8_SECONDS\n");sendStatus(0,progress);
                    SystemClock.sleep(8000);check("display page transport"+screen,link.isRunning(),"physical observer confirmation required");
                }
                output.putBoolean("passed",true);return;
            }
            if(mode.equals("gesture")){gesture(link,output);output.putBoolean("passed",true);return;}
            if(mode.equals("bounds")){
                StringBuilder score=new StringBuilder();for(int i=0;i<64;i++){if(i>0)score.append(',');score.append("0:100");}
                extension.score(score.toString());check("maximum64 score events acknowledged",true,"64 events");
                boolean rejected=false;try{extension.score(score+",0:100");}catch(IllegalArgumentException expected){rejected=true;}
                check("65 score events rejected",rejected,rejected);
                for(int i=0;i<32;i++)extension.keymap(i,31-i);
                check("all32 remapped slots acknowledged",true,"each slot real A frame");
                for(int i=0;i<32;i++)extension.keymap(i,i);
                check("all32 identity slots restored acknowledged",true,"each slot real A frame");
                for(int[] a:new int[][]{{0,0,0,0},{15,15,255,15},{0,15,40,0},{15,0,180,15}})extension.envelope(a[0],a[1],a[2],a[3]);
                check("ADSR boundary configs acknowledged",true,"zero/max/mixed values");
                extension.envelope(9,12,160,13);
                String bad=ExtensionProtocol.envelope(0,0,1,0);bad=bad.substring(0,bad.length()-1)+(bad.endsWith("0")?"1":"0");
                link.extension(bad);link.extension(ExtensionProtocol.chunk(0));SystemClock.sleep(700);
                DirectExtension.Frame frame=(DirectExtension.Frame)field(extension,"latest");
                check("corrupt ADSR checksum ignored by real FPGA",frame.adsrEnabled&&frame.adsrConfig==0x9CDA0,Integer.toHexString(frame.adsrConfig));
                extension.resetEnvelope();extension.score("0:100,12:100,-:100,31:100");
                output.putBoolean("passed",true);return;
            }
            if(mode.equals("cancel")||mode.equals("background")){
                final Throwable[] failure=new Throwable[1];
                Thread recording=new Thread(()->{try{extension.record(text->{});}catch(Throwable e){failure[0]=e;}});
                recording.start();SystemClock.sleep(1200);
                if(mode.equals("background"))getTargetContext().startActivity(new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
                else action(()->activity.onConnectClick());
                recording.join(2500);
                check("record cancellation is bounded",!recording.isAlive(),failure[0]);
                if(mode.equals("background")){
                    check("background clears held mask",((Integer)activityField("mask"))==0,activityField("mask"));
                    Intent resume=new Intent(getTargetContext(),ReferenceActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_CLEAR_TASK);
                    activity=(ReferenceActivity)startActivitySync(resume);
                }
                connected();
                check("normal snapshots restored after aborted recording",Boolean.TRUE.equals(activityField("ready")),activityField("ready"));
                output.putBoolean("passed",true);return;
            }
            link.extension("R00");link.effects(0);link.vibrato(0);link.demo(false);
            action(()->{activity.onVolumeChanged(160,true);activity.onTimbre(1);activity.onEcho(false);});
            SystemClock.sleep(1000);
            int initialSequence=snapshot().sequence;
            for(int i=0;i<8;i++){
                final int key=i;action(()->activity.onPadDown(key));SystemClock.sleep(450);
                Protocol.Snapshot s=snapshot();check("phone key"+i+" down",(s.keys&(1<<i))!=0,s.keys);
                action(()->activity.onPadUp(key));SystemClock.sleep(400);
                check("phone key"+i+" up",(snapshot().keys&(1<<i))==0,snapshot().keys);
            }
            action(()->{for(int i=0;i<4;i++)activity.onPadDown(i);});SystemClock.sleep(600);
            check("four phone key callbacks held",(snapshot().keys&15)==15,snapshot().keys);
            for(int i=0;i<4;i++){
                final int key=i;action(()->activity.onPadUp(key));SystemClock.sleep(450);
                int expected=15&~((1<<(i+1))-1);
                check("selective phone release"+i,(snapshot().keys&15)==expected,snapshot().keys);
            }
            for(int i=0;i<4;i++){
                final int tone=i;action(()->activity.onTimbre(tone));SystemClock.sleep(400);
                check("timbre readback"+i,snapshot().timbre==i,snapshot().timbre);
                link.page(i);SystemClock.sleep(400);check("bank readback"+i,snapshot().page==i,snapshot().page);
            }
            link.page(0);action(()->activity.onTimbre(1));
            for(int v:new int[]{160,80,40,0,160}){
                final int volume=v;action(()->activity.onVolumeChanged(volume,true));SystemClock.sleep(400);
                check("volume readback"+v,snapshot().volume==v,snapshot().volume);
            }
            for(int fx=0;fx<8;fx++){
                link.effects(fx);SystemClock.sleep(350);
                check("effect enabled flag mask"+fx,snapshot().echo==(fx!=0),snapshot().echo);
            }
            link.effects(0);
            for(int screen=0;screen<5;screen++){link.screen(screen);SystemClock.sleep(250);check("screen command transport alive"+screen,link.isRunning(),"physical display pending");}
            link.screen(0);
            extension.keymap(0,12);check("keymap0 to12 acknowledged",true,"real FPGA A frame");
            extension.keymap(0,0);check("keymap restored acknowledged",true,"real FPGA A frame");
            extension.envelope(15,0,180,0);check("custom ADSR acknowledged",true,"real FPGA A frame");
            extension.resetEnvelope();check("factory ADSR restored acknowledged",true,"real FPGA A frame");
            boolean rejected=false;try{extension.keymap(32,0);}catch(IllegalArgumentException expected){rejected=true;}
            check("invalid map rejected",rejected,rejected);
            rejected=false;try{extension.envelope(16,0,180,0);}catch(IllegalArgumentException expected){rejected=true;}
            check("invalid ADSR rejected",rejected,rejected);
            extension.score("0:100,12:100,-:100,31:100");check("score4 including rest acknowledged",true,"real FPGA A frame");
            link.extension("R01");SystemClock.sleep(1500);link.extension("R00");
            action(()->activity.onPadDown(0));
            byte[] wav;
            try{wav=extension.record(text->{Bundle b=new Bundle();b.putString("stream",text+"\n");sendStatus(0,b);});}
            finally{action(()->activity.onPadUp(0));}
            check("record128 chunks and WAV",wav.length==4140,wav.length);
            File file=new File(getTargetContext().getExternalFilesDir(null),"device-suite-record.wav");
            try(FileOutputStream stream=new FileOutputStream(file)){stream.write(wav);}
            output.putString("record_path",file.getAbsolutePath());
            check("WAV actual phone file write",file.length()==wav.length,file.getAbsolutePath());
            link.vibrato(160);link.demo(true);SystemClock.sleep(500);
            action(()->activity.onConnectClick());SystemClock.sleep(5500);
            check("disconnect clears local phone held state",((Integer)activityField("mask"))==0,activityField("mask"));
            connected();link=(WifiSession)activityField("session");
            link.vibrato(0);link.demo(false);link.effects(0);link.page(0);link.extension("R00");
            action(()->{activity.onVolumeChanged(160,true);activity.onTimbre(1);});SystemClock.sleep(800);
            check("fresh telemetry after reconnect",snapshot().sequence!=initialSequence,snapshot().sequence);
            output.putBoolean("passed",true);
        }catch(Throwable error){output.putBoolean("passed",false);output.putString("error",error.toString()+"\n"+android.util.Log.getStackTraceString(error));}
        finally{
            if(activity!=null)try{action(()->{for(int i=0;i<8;i++)activity.onPadUp(i);});Object session=activityField("session");if(session instanceof WifiSession){WifiSession link=(WifiSession)session;link.extension("C00000000");link.keys(0);link.vibrato(0);link.demo(false);link.effects(0);link.extension("R00");link.volume(160);link.tone(1);link.page(0);SystemClock.sleep(800);}}catch(Exception ignored){}
            output.putString("results_json",results.toString());finish(0,output);
        }
    }
}
