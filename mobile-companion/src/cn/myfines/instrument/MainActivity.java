package cn.myfines.instrument;

import android.Manifest;
import android.app.Activity;
import android.os.*;
import android.content.pm.PackageManager;
import android.media.*;
import android.view.*;
import android.widget.*;
import android.graphics.Color;
import org.json.JSONObject;
import java.io.*;
import java.net.*;
import java.util.concurrent.*;

public class MainActivity extends Activity {
 private final SynthCore synth=new SynthCore(48000);
 private final ThreadPoolExecutor commands=new ThreadPoolExecutor(1,1,0,TimeUnit.SECONDS,new ArrayBlockingQueue<Runnable>(32));
 private volatile boolean running;
 private volatile float monitorGain=.15f;
 private AudioTrack track;
 private AudioRecord recorder;
 private Thread worker;
 private TextView status,eventText,meter;
 private EditText endpoint;
 private boolean remote=false;
 private int preset=0;
 private double bend=0,color=.2;
 private AudioManager audio;
 private AudioDeviceCallback devices;
 private LinearLayout root,body;
 @Override public void onCreate(Bundle b){
  super.onCreate(b);audio=(AudioManager)getSystemService(AUDIO_SERVICE);
  getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
  root=new LinearLayout(this);root.setOrientation(1);root.setPadding(24,24,24,24);root.setBackgroundColor(Color.rgb(244,246,250));
  setContentView(root);label(root,"FPGA 乐器伴侣",25);label(root,"手机预览 · 外接输入监听",14);
  status=label(root,"未连接 FPGA；手机发声不计作 FPGA 合成",14);
  LinearLayout tabs=new LinearLayout(this);root.addView(tabs);button(root,"连接 FPGA Wi-Fi",()->startActivity(new android.content.Intent(this,WifiActivity.class)));
  button(tabs,"触屏演奏",()->showPlay());button(tabs,"手机扬声器",()->showMonitor());
  ScrollView scroll=new ScrollView(this);root.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));body=new LinearLayout(this);body.setOrientation(1);scroll.addView(body);
  button(root,"紧急静音 / 停止",()->{stopAudio();emit("all_off",-1,0);});
  devices=new AudioDeviceCallback(){@Override public void onAudioDevicesRemoved(AudioDeviceInfo[] list){stopAudio();status.setText("设备变化，已停止；请重新选择输入");}};
  audio.registerAudioDeviceCallback(devices,new Handler(Looper.getMainLooper()));showPlay();
 }
 private TextView label(LinearLayout parent,String text,int size){TextView v=new TextView(this);v.setText(text);v.setTextSize(size);v.setPadding(0,10,0,10);v.setTextColor(Color.rgb(25,35,50));parent.addView(v);return v;}
 private Button button(LinearLayout parent,String text,Runnable action){Button b=new Button(this);b.setText(text);parent.addView(b);b.setOnClickListener(v->action.run());return b;}
 private void showPlay(){
  stopAudio();emit("all_off",-1,0);body.removeAllViews();label(body,"触屏演奏 · 本地预览",22);label(body,"8键、最多4复音。按住发声，松开释放。当前不是 FPGA 演奏。",14);
  String[] names={"C5","D5","E5","F5","G5","A5","B5","C6"};
  for(int row=0;row<2;row++){
   LinearLayout line=new LinearLayout(this);body.addView(line);
   for(int col=0;col<4;col++){final int k=row*4+col;Button key=new Button(this);key.setText(names[k]);line.addView(key,new LinearLayout.LayoutParams(0,150,1));
    key.setOnTouchListener((v,e)->{int a=e.getActionMasked();if(a==MotionEvent.ACTION_DOWN){if(!running)startSynth();synth.note(k,true);emit("note_on",k,1);v.setAlpha(.5f);return true;}if(a==MotionEvent.ACTION_UP||a==MotionEvent.ACTION_CANCEL){synth.note(k,false);emit("note_off",k,0);v.setAlpha(1);return true;}return true;});
   }
  }
  Spinner timbre=new Spinner(this);timbre.setAdapter(new ArrayAdapter<String>(this,android.R.layout.simple_spinner_dropdown_item,new String[]{"柔和三角","正弦","锯齿拨弦"}));body.addView(timbre);timbre.setSelection(preset);
  timbre.setOnItemSelectedListener(new android.widget.AdapterView.OnItemSelectedListener(){public void onNothingSelected(android.widget.AdapterView<?> p){}public void onItemSelected(android.widget.AdapterView<?> p,View v,int i,long id){preset=i;synth.preset(i);emit("preset",-1,i);}});
  slider("弯音（中间归零）",(int)Math.round(bend*25+50),v->{bend=(v-50)/25.;synth.expression(bend,color);emit("bend",-1,bend);});
  slider("明亮度",(int)Math.round(color*100),v->{color=v/100.;synth.expression(bend,color);emit("brightness",-1,color);});
  CheckBox send=new CheckBox(this);send.setText("发送控制命令到开发桥接器（不是已连接FPGA）");send.setChecked(remote);body.addView(send);send.setOnCheckedChangeListener((b,on)->remote=on);
  endpoint=new EditText(this);endpoint.setSingleLine(true);endpoint.setText("http://127.0.0.1:8765/event");body.addView(endpoint);
  label(body,"电脑USB开发桥通过 adb reverse 接收命令；真实 FPGA 接收端尚未接入。",13);
  eventText=label(body,"等待触控",13);
 }
 interface Changed{void change(int value);}
 private void slider(String title,int initial,Changed change){label(body,title,15);SeekBar bar=new SeekBar(this);bar.setMax(100);bar.setProgress(initial);body.addView(bar);bar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener(){public void onStartTrackingTouch(SeekBar s){}public void onStopTrackingTouch(SeekBar s){}public void onProgressChanged(SeekBar s,int p,boolean user){if(user)change.change(p);}});}
 private void emit(String kind,int key,double value){
  try{JSONObject j=new JSONObject();j.put("version",1);j.put("type",kind);j.put("key",key);j.put("value",value);j.put("phone_time_ms",SystemClock.elapsedRealtime());String payload=j.toString();if(eventText!=null)eventText.setText(payload);
   if(!remote||endpoint==null)return;String url=endpoint.getText().toString();
   if(commands.getQueue().size()>8 && (kind.equals("bend")||kind.equals("brightness")))return;
   commands.execute(()->{HttpURLConnection c=null;try{c=(HttpURLConnection)new URL(url).openConnection();c.setConnectTimeout(800);c.setReadTimeout(800);c.setRequestMethod("POST");c.setDoOutput(true);c.setRequestProperty("Content-Type","application/json");try(OutputStream o=c.getOutputStream()){o.write(payload.getBytes("UTF-8"));}int code=c.getResponseCode();runOnUiThread(()->status.setText(code==200?"开发桥已收命令；FPGA 未连接":"开发桥错误 "+code));}catch(Exception e){runOnUiThread(()->status.setText("控制桥未连接；本地预览可用"));}finally{if(c!=null)c.disconnect();}});
  }catch(Exception e){status.setText("命令错误："+e.getMessage());}
 }
 private AudioDeviceInfo find(int type,boolean input){for(AudioDeviceInfo d:audio.getDevices(input?AudioManager.GET_DEVICES_INPUTS:AudioManager.GET_DEVICES_OUTPUTS))if(d.getType()==type)return d;return null;}
 private AudioTrack makeTrack(){return new AudioTrack.Builder().setAudioAttributes(new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build()).setAudioFormat(new AudioFormat.Builder().setSampleRate(48000).setEncoding(AudioFormat.ENCODING_PCM_16BIT).setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build()).setBufferSizeInBytes(Math.max(4096,AudioTrack.getMinBufferSize(48000,AudioFormat.CHANNEL_OUT_MONO,AudioFormat.ENCODING_PCM_16BIT))).setTransferMode(AudioTrack.MODE_STREAM).setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY).build();}
 private void startSynth(){
  stopAudio();try{track=makeTrack();AudioDeviceInfo speaker=find(AudioDeviceInfo.TYPE_BUILTIN_SPEAKER,false);if(speaker!=null)track.setPreferredDevice(speaker);track.play();running=true;worker=new Thread(()->{short[] b=new short[256];try{while(running){synth.render(b);if(track.write(b,0,b.length)<0)break;}}catch(Exception e){runOnUiThread(()->status.setText("音频停止："+e.getMessage()));}},"phone-preview");worker.start();status.setText("手机本地合成预览 · FPGA 未连接");}catch(Exception e){stopAudio();status.setText("无法播放："+e.getMessage());}
 }
 private void showMonitor(){
  stopAudio();emit("all_off",-1,0);body.removeAllViews();eventText=null;label(body,"外接音频 → 手机扬声器",22);label(body,"普通AUX双公线不能直接送入手机耳麦输入。需正确CTIA转接及线电平衰减，或USB音频输入。当前未接FPGA，暂不验证接线和延迟。",14);
  label(body,"安全默认：拒绝内置麦克风，停止/切页/离开应用立即静音。",14);
  slider("监听增益（默认15%，上限60%）",(int)Math.round(monitorGain/.006),v->monitorGain=v*.006f);
  meter=label(body,"等待外部音频输入",14);
  button(body,"刷新输入设备",()->listInputs());button(body,"开始外部输入监听",()->startMonitor());listInputs();
 }
 private void listInputs(){StringBuilder s=new StringBuilder();for(AudioDeviceInfo d:audio.getDevices(AudioManager.GET_DEVICES_INPUTS))s.append("类型 ").append(d.getType()).append("：").append(d.getProductName()).append("\n");meter.setText(s.length()==0?"没有输入设备":s.toString());}
 private static boolean external(AudioDeviceInfo d){if(d==null)return false;int t=d.getType();return t==AudioDeviceInfo.TYPE_WIRED_HEADSET||t==AudioDeviceInfo.TYPE_USB_DEVICE||t==AudioDeviceInfo.TYPE_USB_HEADSET||t==AudioDeviceInfo.TYPE_USB_ACCESSORY;}
 private void startMonitor(){
  stopAudio();if(checkSelfPermission(Manifest.permission.RECORD_AUDIO)!=PackageManager.PERMISSION_GRANTED){requestPermissions(new String[]{Manifest.permission.RECORD_AUDIO},1);status.setText("授权后再次点开始；不会自动录音");return;}
  AudioDeviceInfo input=null;for(AudioDeviceInfo d:audio.getDevices(AudioManager.GET_DEVICES_INPUTS))if(external(d)){input=d;break;}
  if(input==null){status.setText("没有外部输入：拒绝启用内置麦克风，防止啸叫");return;}
  try{
   int min=AudioRecord.getMinBufferSize(48000,AudioFormat.CHANNEL_IN_MONO,AudioFormat.ENCODING_PCM_16BIT);
   recorder=new AudioRecord.Builder().setAudioSource(MediaRecorder.AudioSource.UNPROCESSED).setAudioFormat(new AudioFormat.Builder().setSampleRate(48000).setChannelMask(AudioFormat.CHANNEL_IN_MONO).setEncoding(AudioFormat.ENCODING_PCM_16BIT).build()).setBufferSizeInBytes(Math.max(4096,min)).build();
   if(!recorder.setPreferredDevice(input))throw new IllegalStateException("系统不接受外部输入路由");
   track=makeTrack();AudioDeviceInfo speaker=find(AudioDeviceInfo.TYPE_BUILTIN_SPEAKER,false);if(speaker==null||!track.setPreferredDevice(speaker))throw new IllegalStateException("无法选择手机扬声器");
   recorder.startRecording();track.play();running=true;worker=new Thread(()->{short[] b=new short[256];int count=0;try{while(running){int n=recorder.read(b,0,b.length);if(n<=0)throw new IllegalStateException("输入读取失败");if(!external(recorder.getRoutedDevice()))throw new IllegalStateException("输入未路由到外部设备，已停止");AudioDeviceInfo out=track.getRoutedDevice();if(out!=null&&out.getType()!=AudioDeviceInfo.TYPE_BUILTIN_SPEAKER)throw new IllegalStateException("扬声器路由改变，已停止");int peak=0;for(int k=0;k<n;k++){peak=Math.max(peak,Math.abs((int)b[k]));b[k]=(short)(b[k]*monitorGain);}if(track.write(b,0,n)<0)throw new IllegalStateException("输出失败");if(++count%40==0){final int p=peak;runOnUiThread(()->meter.setText("输入峰值 "+Math.round(p*100./32768)+"% · "+(p>32000?"输入可能过载，先减小源电平":"监听中")));}}}catch(Exception e){runOnUiThread(()->{stopAudio();status.setText(e.getMessage());});}},"external-monitor");worker.start();status.setText("外部输入监听中；延迟未标定");
  }catch(Exception e){stopAudio();status.setText("无法监听："+e.getMessage());}
 }
 private void stopAudio(){running=false;synth.panic();if(recorder!=null){try{recorder.stop();}catch(Exception ignored){}}if(track!=null){try{track.pause();track.flush();}catch(Exception ignored){}}if(worker!=null){try{worker.join(800);}catch(InterruptedException e){Thread.currentThread().interrupt();}worker=null;}if(recorder!=null){recorder.release();recorder=null;}if(track!=null){track.release();track=null;}}
 @Override protected void onPause(){stopAudio();emit("all_off",-1,0);super.onPause();}
 @Override protected void onDestroy(){stopAudio();audio.unregisterAudioDeviceCallback(devices);commands.shutdownNow();super.onDestroy();}
}

