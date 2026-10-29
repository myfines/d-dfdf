package cn.myfines.instrument.reference;
import android.app.*;
import android.os.*;
import android.content.*;
import android.net.*;
import android.view.*;
import android.widget.*;
import cn.myfines.instrument.WifiProtocol;
import cn.myfines.instrument.WifiSession;
public final class ReferenceActivity extends Activity implements InstrumentView.Actions {
 private InstrumentView view;private WifiSession session;private final Handler ui=new Handler(Looper.getMainLooper());
 private SharedPreferences prefs;private String host;private int port,volume,tone,page,mask,generation;private boolean echo;private boolean ready;private final boolean[] held=new boolean[8];
 private void held(int key,boolean value){held[key]=value;view.setHeld(held);}
 private void save(){prefs.edit().putString("host",host).putInt("port",port).putInt("volume",volume).putInt("tone",tone).putInt("page",page).putBoolean("echo",echo).apply();}
 @Override public void onCreate(Bundle state){super.onCreate(state);prefs=getSharedPreferences("reference_wifi",0);host=prefs.getString("host","192.168.4.1");port=prefs.getInt("port",9000);volume=prefs.getInt("volume",160);tone=prefs.getInt("tone",0);page=prefs.getInt("page",0);echo=prefs.getBoolean("echo",false);
  getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);getWindow().setStatusBarColor(0xff080f18);getWindow().setNavigationBarColor(0xff080f18);
  view=new InstrumentView(this);view.setActions(this);view.setHost(host,port);view.setVolume(volume);view.setTimbre(tone);view.setEcho(echo);view.setStatus("未连接","手机连接 FPGA-Instrument 热点后点连接",0,false);view.setReady(false);setContentView(view);
 }
 private void disconnect(){generation++;ready=false;mask=0;java.util.Arrays.fill(held,false);view.releaseTouchState();view.setReady(false);if(session!=null){session.close();session=null;}view.setStatus("未连接","已释放手机按键",0,false);}
 @Override public void onConnectClick(){if(session!=null&&session.isRunning()){disconnect();return;}disconnect();
  ConnectivityManager cm=(ConnectivityManager)getSystemService(CONNECTIVITY_SERVICE);Network found=null;for(Network n:cm.getAllNetworks()){NetworkCapabilities c=cm.getNetworkCapabilities(n);if(c!=null&&c.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)){found=n;break;}}
  if(found==null){view.setStatus("未连接","请先在系统设置连接 ESP 热点",3,false);return;}final Network wifi=found;final int id=++generation;
  session=new WifiSession(new WifiSession.Listener(){public void status(String s){ui.post(()->{if(id==generation){view.setStatus(s,"等待真实状态帧，不代表已同步",session!=null&&session.isRunning()?1:3,session!=null&&session.isRunning());if(session==null||!session.isRunning()){ready=false;java.util.Arrays.fill(held,false);mask=0;view.releaseTouchState();view.setReady(false);}}});}
   public void snapshot(WifiProtocol.Snapshot s){ui.post(()->{if(id!=generation)return;ready=true;view.setMode(true);view.setSnapshot(new Protocol.Snapshot(s.sequence,s.keys,s.flags,s.x,s.y,s.volume,s.timbre,s.echo,s.page,s.wave,s.gestureAvailable,s.gestureActive,s.gestureSequence,s.pinch,s.gestureY,s.confidence));view.setStatus("已连接","参数与波形来自 FPGA；设置自动保存",2,false);});}});
  session.volume(volume);session.tone(tone);session.echo(echo);session.page(page);view.setStatus("连接中","正在连接 ESP "+host+":"+port,1,true);session.connect(host,port,()->wifi.getSocketFactory().createSocket());
 }
 public void onPadDown(int i){if(!ready)return;mask|=1<<i;held(i,true);session.keys(mask);}
 public void onPadUp(int i){mask&=~(1<<i);held(i,false);if(session!=null)session.keys(mask);}
 public void onVolumeChanged(int value,boolean done){volume=value;if(session!=null)session.volume(value);if(done)save();}
 public void onTimbre(int value){tone=value;if(session!=null)session.tone(value);save();}
 public void onEcho(boolean value){echo=value;if(session!=null)session.echo(value);save();}
 public void onMute(){volume=0;view.setVolume(0);if(session!=null)session.volume(0);save();}
 public void onHelp(){new AlertDialog.Builder(this).setTitle("Wi-Fi 直连演奏").setMessage("手机连接 FPGA-Instrument 热点（密码 fpga-demo-2026），返回本页点击连接。需要 FPGA 热点版固件。\n八键支持多指，按住发声松开停止；音量、音色、延时、音区与连接地址自动保存。\n手势控制音量与亮度，手势本身不触发音符。波形来自设备回传，不是音频录音。\nRCFG只重配FPGA，外设异常请按原流程完整冷启动。").setPositiveButton("知道了",null).show();}
 public void onSettings(){LinearLayout form=new LinearLayout(this);form.setOrientation(1);form.setPadding(24,12,24,12);EditText address=new EditText(this);address.setSingleLine(true);address.setHint("ESP IP 地址");address.setText(host);form.addView(address);EditText number=new EditText(this);number.setInputType(2);number.setHint("TCP端口");number.setText(""+port);form.addView(number);Spinner bank=new Spinner(this);bank.setAdapter(new ArrayAdapter<String>(this,android.R.layout.simple_spinner_dropdown_item,new String[]{"音区1 · C3–G3","音区2 · G#3–D#4","音区3 · E4–B4","音区4 · C5–G5"}));bank.setSelection(page);form.addView(bank);
  AlertDialog dialog=new AlertDialog.Builder(this).setTitle("连接与演奏设置 · 自动保存").setView(form).setNegativeButton("取消",null).setPositiveButton("保存",null).create();dialog.setOnShowListener(d->dialog.getButton(-1).setOnClickListener(v->{try{String h=address.getText().toString().trim();int p=Integer.parseInt(number.getText().toString());if(h.isEmpty()||p<1||p>65535)throw new IllegalArgumentException();boolean changed=!h.equals(host)||p!=port;host=h;port=p;page=bank.getSelectedItemPosition();if(changed)disconnect();else if(session!=null)session.page(page);view.setHost(host,port);save();dialog.dismiss();}catch(Exception e){number.setError("地址不能为空，端口范围1–65535");}}));dialog.show();
 }
 @Override protected void onPause(){save();disconnect();super.onPause();}
}
