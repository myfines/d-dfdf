package cn.myfines.instrument.reference;
import android.app.*;
import android.os.*;
import android.content.*;
import android.net.*;
import android.view.*;
import android.widget.*;
import cn.myfines.instrument.WifiProtocol;
import cn.myfines.instrument.WifiSession;
import cn.myfines.instrument.DirectExtension;
import cn.myfines.instrument.EffectsState;
public final class ReferenceActivity extends Activity implements InstrumentView.Actions {
 private InstrumentView view;private WifiSession session;private final Handler ui=new Handler(Looper.getMainLooper());
 private volatile DirectExtension extension;private boolean extensionBusy;private byte[] pendingWav;
 private AlertDialog settingsDialog,extensionDialog;
 private EffectsState effectState;
 private final java.util.concurrent.ExecutorService extensionWorker=java.util.concurrent.Executors.newSingleThreadExecutor();
 private SharedPreferences prefs;private String host;private int port,volume,tone,page,mask;private volatile int generation;private boolean echo;private boolean ready;private final boolean[] held=new boolean[8];
 private void held(int key,boolean value){held[key]=value;view.setHeld(held);}
 private void save(){prefs.edit().putString("host",host).putInt("port",port).putInt("volume",volume).putInt("tone",tone).putInt("page",page).putBoolean("echo",echo).putInt("effects",effectState.mask()).apply();}
 @Override public void onCreate(Bundle state){super.onCreate(state);prefs=getSharedPreferences("reference_wifi",0);host=prefs.getString("host","192.168.4.1");port=prefs.getInt("port",9000);volume=prefs.getInt("volume",160);tone=prefs.getInt("tone",0);page=prefs.getInt("page",0);echo=prefs.getBoolean("echo",false);
  effectState=new EffectsState(prefs.getInt("effects",-1),echo);echo=effectState.delay();
  getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);getWindow().setStatusBarColor(0xff080f18);getWindow().setNavigationBarColor(0xff080f18);
  view=new InstrumentView(this);view.setActions(this);view.setHost(host,port);view.setVolume(volume);view.setTimbre(tone);view.setEcho(echo);view.setStatus("未连接","手机连接 FPGA-Instrument 热点后点连接",0,false);view.setReady(false);setContentView(view);
 }
 private void disconnect(){generation++;ready=false;mask=0;if(extension!=null){extension.cancel();extension=null;}java.util.Arrays.fill(held,false);view.releaseTouchState();view.setReady(false);if(session!=null){session.close();session=null;}view.setStatus("未连接","已释放手机按键",0,false);}
 @Override public void onConnectClick(){if(session!=null&&session.isRunning()){disconnect();return;}disconnect();
  ConnectivityManager cm=(ConnectivityManager)getSystemService(CONNECTIVITY_SERVICE);Network found=null;for(Network n:cm.getAllNetworks()){NetworkCapabilities c=cm.getNetworkCapabilities(n);if(c!=null&&c.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)){found=n;break;}}
  if(found==null){view.setStatus("未连接","请先在系统设置连接 ESP 热点",3,false);return;}final Network wifi=found;final int id=++generation;
  session=new WifiSession(new WifiSession.Listener(){public void status(String s){ui.post(()->{if(id==generation){view.setStatus(s,"等待真实状态帧，不代表已同步",session!=null&&session.isRunning()?1:3,session!=null&&session.isRunning());if(session==null||!session.isRunning()){ready=false;java.util.Arrays.fill(held,false);mask=0;view.releaseTouchState();view.setReady(false);}}});}
   public void extension(DirectExtension.Frame f){DirectExtension e=extension;if(id==generation&&e!=null)e.accept(f);}
   public void snapshot(WifiProtocol.Snapshot s){ui.post(()->{if(id!=generation)return;ready=true;view.setMode(true);view.setSnapshot(new Protocol.Snapshot(s.sequence,s.keys,s.flags,s.x,s.y,s.volume,s.timbre,s.echo,s.page,s.wave,s.gestureAvailable,s.gestureActive,s.gestureSequence,s.pinch,s.gestureY,s.confidence));view.setStatus("已连接","参数与波形来自 FPGA；设置自动保存",2,false);});}});
  final WifiSession link=session;extension=new DirectExtension(new DirectExtension.Wire(){public void send(String packet){link.extension(packet);}public boolean connected(){return link.isRunning();}});
  session.volume(volume);session.tone(tone);session.effects(effectState.mask());session.page(page);view.setStatus("连接中","正在连接 ESP "+host+":"+port,1,true);session.connect(host,port,()->wifi.getSocketFactory().createSocket());
 }
 public void onPadDown(int i){if(!ready)return;mask|=1<<i;held(i,true);session.keys(mask);}
 public void onPadUp(int i){mask&=~(1<<i);held(i,false);if(session!=null)session.keys(mask);}
 public void onVolumeChanged(int value,boolean done){volume=value;if(session!=null)session.volume(value);if(done)save();}
 public void onTimbre(int value){tone=value;if(session!=null)session.tone(value);save();}
 public void onEcho(boolean value){effectState.delay(value);echo=effectState.delay();if(session!=null)session.effects(effectState.mask());save();}
 public void onMute(){volume=0;view.setVolume(0);if(session!=null)session.volume(0);save();}
 public void onHelp(){new AlertDialog.Builder(this).setTitle("Wi-Fi 直连演奏").setMessage("手机连接 FPGA-Instrument 热点（密码 fpga-demo-2026），返回本页点击连接。需要 FPGA 热点版固件。\n八键支持多指，按住发声松开停止；音量、音色、延时、音区与连接地址自动保存。\n手势控制音量与亮度，手势本身不触发音符。波形来自设备回传，不是音频录音。\nRCFG只重配FPGA，外设异常请按原流程完整冷启动。").setPositiveButton("知道了",null).show();}
 public void onSettings(){LinearLayout form=new LinearLayout(this);form.setOrientation(1);form.setPadding(24,12,24,12);EditText address=new EditText(this);address.setSingleLine(true);address.setHint("ESP IP 地址");address.setText(host);form.addView(address);EditText number=new EditText(this);number.setInputType(2);number.setHint("TCP端口");number.setText(""+port);form.addView(number);Spinner bank=new Spinner(this);bank.setAdapter(new ArrayAdapter<String>(this,android.R.layout.simple_spinner_dropdown_item,new String[]{"音区1 · C3–G3","音区2 · G#3–D#4","音区3 · E4–B4","音区4 · C5–G5"}));bank.setSelection(page);form.addView(bank);
  Button extra=new Button(this);extra.setText("直连扩展 · 颤音 / ADSR / 曲谱 / 键位 / 录音");form.addView(extra);extra.setOnClickListener(v->extensions());
  AlertDialog dialog=new AlertDialog.Builder(this).setTitle("连接与演奏设置 · 自动保存").setView(form).setNegativeButton("取消",null).setPositiveButton("保存",null).create();dialog.setOnShowListener(d->dialog.getButton(-1).setOnClickListener(v->{try{String h=address.getText().toString().trim();int p=Integer.parseInt(number.getText().toString());if(h.isEmpty()||p<1||p>65535)throw new IllegalArgumentException();boolean changed=!h.equals(host)||p!=port;host=h;port=p;page=bank.getSelectedItemPosition();if(changed)disconnect();else if(session!=null)session.page(page);view.setHost(host,port);save();dialog.dismiss();}catch(Exception e){number.setError("地址不能为空，端口范围1–65535");}}));dialog.show();
  settingsDialog=dialog;
 }
 private interface Work {String run(DirectExtension e)throws Exception;}
 private boolean operate(TextView status,Work work){
  if(extensionBusy||!ready||extension==null||session==null||!session.isRunning()){status.setText("请先连接设备，并等待上一操作结束");return false;}
  final DirectExtension e=extension;final int id=generation;extensionBusy=true;status.setText("正在等待 FPGA 回读…");
  extensionWorker.execute(()->{String result;try{result=work.run(e);}catch(Exception error){result="未完成："+error.getMessage();}final String text=result;ui.post(()->{extensionBusy=false;if(id==generation){status.setText(text);Toast.makeText(this,text,Toast.LENGTH_LONG).show();}});});
  return true;
 }
 private void extensions(){
  LinearLayout body=new LinearLayout(this);body.setOrientation(1);body.setPadding(24,12,24,12);ScrollView scroll=new ScrollView(this);scroll.addView(body);
  TextView status=new TextView(this);status.setText("已备好示例曲谱，可直接下发；在线下载需手机能上网。设备配置断电不保留，录音约0.7秒单声道。");body.addView(status);
  TextView expression=new TextView(this);expression.setText("颤音深度 0..255（0关闭）；断连后自动释放。ADSR作用于新触发音符，A/D/R是步进索引，越大越慢；S为保持电平0..255。应用后重新按键试听。");body.addView(expression);
  EditText vibrato=new EditText(this);vibrato.setHint("颤音深度0..255");vibrato.setInputType(2);vibrato.setText("0");body.addView(vibrato);
  Button applyVibrato=new Button(this);applyVibrato.setText("应用颤音 / 0关闭");body.addView(applyVibrato);
  applyVibrato.setOnClickListener(v->{try{if(!ready||session==null||!session.isRunning())throw new IllegalStateException("请先连接设备");session.vibrato(Integer.parseInt(vibrato.getText().toString()));status.setText("已发送颤音设置；当前状态帧不含颤音回读，请按键试听确认");}catch(Exception error){status.setText("未应用："+error.getMessage());}});
  final EditText[] adsr=new EditText[4];String[] labels={"A 起音索引0..15","D 衰减索引0..15","S 保持电平0..255","R 释放索引0..15"};String[] defaults={"9","12","160","13"};
  for(int i=0;i<4;i++){TextView label=new TextView(this);label.setText(labels[i]);body.addView(label);adsr[i]=new EditText(this);adsr[i].setHint(labels[i]);adsr[i].setInputType(2);adsr[i].setText(defaults[i]);body.addView(adsr[i]);}
  Button applyEnvelope=new Button(this);applyEnvelope.setText("应用自定义ADSR（重新按键生效）");body.addView(applyEnvelope);
  applyEnvelope.setOnClickListener(v->{try{final int a=Integer.parseInt(adsr[0].getText().toString()),d=Integer.parseInt(adsr[1].getText().toString()),sustain=Integer.parseInt(adsr[2].getText().toString()),r=Integer.parseInt(adsr[3].getText().toString());operate(status,e->{e.envelope(a,d,sustain,r);return "FPGA已回读自定义ADSR；重新按键试听";});}catch(Exception error){status.setText("未应用："+error.getMessage());}});
  Button resetEnvelope=new Button(this);resetEnvelope.setText("恢复四音色原厂包络");body.addView(resetEnvelope);
  resetEnvelope.setOnClickListener(v->operate(status,e->{e.resetEnvelope();return "FPGA已回读原厂包络模式；重新按键试听";}));
  CheckBox chorus=new CheckBox(this);chorus.setText("合唱");chorus.setChecked((effectState.mask()&1)!=0);body.addView(chorus);CheckBox delay=new CheckBox(this);delay.setText("延迟");delay.setChecked(effectState.delay());body.addView(delay);CheckBox reverb=new CheckBox(this);reverb.setText("混响");reverb.setChecked((effectState.mask()&4)!=0);body.addView(reverb);
  Button effects=new Button(this);effects.setText("应用FPGA效果器组合");body.addView(effects);
  Runnable updateEffects=()->{effectState.select(chorus.isChecked(),delay.isChecked(),reverb.isChecked());echo=effectState.delay();view.setEcho(echo);save();if(session!=null&&session.isRunning()){session.effects(effectState.mask());status.setText("效果组合已保存并发送；请试听确认");}else{status.setText("效果组合已保存在手机；连接FPGA热点并点击连接后自动发送");}};
  chorus.setOnCheckedChangeListener((button,checked)->updateEffects.run());
  delay.setOnCheckedChangeListener((button,checked)->updateEffects.run());
  reverb.setOnCheckedChangeListener((button,checked)->updateEffects.run());
  effects.setOnClickListener(v->updateEffects.run());
  Spinner screen=new Spinner(this);screen.setAdapter(new ArrayAdapter<String>(this,android.R.layout.simple_spinner_dropdown_item,new String[]{"波形","16带频谱","立体声李萨如","曲目指引","系统状态"}));body.addView(screen);
  Button display=new Button(this);display.setText("切换OLED页面");body.addView(display);display.setOnClickListener(v->{if(!ready||session==null||!session.isRunning()){status.setText("请先连接设备");return;}session.screen(screen.getSelectedItemPosition());status.setText("已发送OLED页面请求，请查看板上显示；手机波形不代表OLED验收");});
  Button demoOn=new Button(this);demoOn.setText("启动32声部测试（先降低音箱音量）");body.addView(demoOn);Button demoOff=new Button(this);demoOff.setText("停止32声部测试");body.addView(demoOff);
  demoOn.setOnClickListener(v->{if(!ready||session==null||!session.isRunning()){status.setText("请先连接设备");return;}session.demo(true);status.setText("已请求32声部测试；频谱及实际输出采样率仍需仪器验证");});
  demoOff.setOnClickListener(v->{if(session!=null)session.demo(false);status.setText("已请求停止32声部测试；效果器可能有尾音");});
  EditText score=new EditText(this);score.setHint("音符0..31:时长10ms，-为休止");score.setText(prefs.getString("score",cn.myfines.instrument.ScoreDownload.EXAMPLE_SCORE));body.addView(score);
  EditText scoreUrl=new EditText(this);scoreUrl.setSingleLine(true);scoreUrl.setHint("已填好示例地址；也可替换为其他曲谱文本网址");scoreUrl.setText(cn.myfines.instrument.ScoreDownload.addressOrExample(prefs.getString("score_url","")));body.addView(scoreUrl);
  Button download=new Button(this);download.setText("下载曲谱（默认示例）");body.addView(download);
  download.setOnClickListener(v->{if(extensionBusy){status.setText("请等待上一操作完成");return;}final String address=cn.myfines.instrument.ScoreDownload.addressOrExample(scoreUrl.getText().toString());scoreUrl.setText(address);extensionBusy=true;status.setText("下载中；请确保手机有互联网。热点无互联网时先断开热点下载，再重连设备下发。");extensionWorker.execute(()->{try{final String text=cn.myfines.instrument.ScoreDownload.fetch(address);prefs.edit().putString("score",text).putString("score_url",address).apply();ui.post(()->{extensionBusy=false;score.setText(text);status.setText("在线曲谱已校验并保存在手机；连接设备后点击下发并回读确认");});}catch(Exception error){ui.post(()->{extensionBusy=false;status.setText("下载未完成，当前曲谱仍保留，可直接下发："+error.getMessage());});}});});
  Button upload=new Button(this);upload.setText("下发曲谱到FPGA并回读确认");body.addView(upload);upload.setOnClickListener(v->{final String text=score.getText().toString();operate(status,e->{e.score(text);prefs.edit().putString("score",text).apply();return "FPGA已回读曲谱事件数；可断网后用板载S3启停，断电需重新下载";});});
  Button play=new Button(this);play.setText("播放 / 停止曲谱");body.addView(play);final boolean[] playing={false};play.setOnClickListener(v->{if(extensionBusy||session==null||!session.isRunning())return;playing[0]=!playing[0];session.extension(playing[0]?"R01":"R00");status.setText("已发送播放/停止请求；请核对实际演奏");});
  EditText slot=new EditText(this);slot.setHint("映射位置0..31");slot.setText("0");slot.setInputType(2);body.addView(slot);EditText note=new EditText(this);note.setHint("目标音符0..31，C4=12");note.setText("12");note.setInputType(2);body.addView(note);
  Button map=new Button(this);map.setText("设置键位并回读确认（先松开演奏键）");body.addView(map);map.setOnClickListener(v->{try{final int a=Integer.parseInt(slot.getText().toString()),b=Integer.parseInt(note.getText().toString());operate(status,e->{e.keymap(a,b);return "FPGA已回读该位置映射；实际音高仍需试听确认";});}catch(Exception error){status.setText("位置与音符须为0..31整数");}});
  Button record=new Button(this);record.setText("录制设备PCM并导出WAV（点击后演奏）");body.addView(record);
  extensionDialog=new AlertDialog.Builder(this).setTitle("直连扩展").setView(scroll).setNegativeButton("关闭",null).show();
  // Return to the original pads immediately, so the phone can play during capture.
  record.setOnClickListener(v->{boolean started=operate(status,e->{byte[] wav=e.record(t->ui.post(()->status.setText(t)));ui.post(()->{pendingWav=wav;Intent save=new Intent(Intent.ACTION_CREATE_DOCUMENT);save.addCategory(Intent.CATEGORY_OPENABLE);save.setType("audio/wav");save.putExtra(Intent.EXTRA_TITLE,"FPGA-"+System.currentTimeMillis()+".wav");startActivityForResult(save,701);});return "128块已校验接收，请选择WAV保存位置";});if(started){extensionDialog.dismiss();if(settingsDialog!=null)settingsDialog.dismiss();}});
 }
 @Override protected void onActivityResult(int request,int result,Intent data){super.onActivityResult(request,result,data);if(request==701&&result==RESULT_OK&&data!=null&&pendingWav!=null){final byte[] wav=pendingWav;final android.net.Uri uri=data.getData();pendingWav=null;extensionWorker.execute(()->{try(java.io.OutputStream out=getContentResolver().openOutputStream(uri)){if(out==null)throw new java.io.IOException("无法打开文件");out.write(wav);ui.post(()->Toast.makeText(this,"WAV已保存",Toast.LENGTH_LONG).show());}catch(Exception error){ui.post(()->Toast.makeText(this,"保存失败："+error.getMessage(),Toast.LENGTH_LONG).show());}});}}
 @Override protected void onDestroy(){disconnect();extensionWorker.shutdownNow();super.onDestroy();}
 @Override protected void onPause(){save();disconnect();super.onPause();}
}
