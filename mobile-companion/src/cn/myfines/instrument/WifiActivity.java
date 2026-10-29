package cn.myfines.instrument;

import android.app.*;
import android.content.*;
import android.net.*;
import android.os.*;
import android.graphics.*;
import android.view.*;
import android.widget.*;
import java.io.*;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.util.*;

/** Direct ESP TCP control; all musical audio remains on the FPGA. */
public final class WifiActivity extends Activity {
 private LinearLayout root;
 private Button connectButton;
 private TextView connection,actual,keysText,gestureText,recordText;
 private EditText host;
 private ProgressBar pinchBar,heightBar;
 private WaveView wave;
 private WifiSession session;
 private final boolean[] held=new boolean[4];
 private final int[] mapping={0,1,2,3};
 private final Button[] pads=new Button[4];
 private final ArrayList<String> events=new ArrayList<>();
 private boolean recording;
 private int desiredVolume=160,desiredTone=0,desiredPage=0,generation;private boolean desiredEcho;
 private long recordStart;
 private String lastEvent="";
 private final Handler ui=new Handler(Looper.getMainLooper());
 private TextView text(String value,int size){TextView v=new TextView(this);v.setText(value);v.setTextSize(size);v.setTextColor(Color.rgb(205,225,240));v.setPadding(8,8,8,8);root.addView(v);return v;}
 private Button button(String title,Runnable action){Button b=new Button(this);b.setText(title);b.setOnClickListener(v->action.run());root.addView(b);return b;}
 @Override public void onCreate(Bundle state){
  super.onCreate(state);getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
  ScrollView scroll=new ScrollView(this);root=new LinearLayout(this);root.setOrientation(1);root.setPadding(20,16,20,16);root.setBackgroundColor(Color.rgb(10,20,32));scroll.addView(root);setContentView(scroll);
  text("FPGA · Wi-Fi 演奏台",26);
  button("E037 公网：曲谱 / 32键映射 / 数字录音",()->{disconnect();startActivity(new Intent(this,CloudActivity.class));});
  text("下方是旧版热点直连界面；当前公网固件请用上方E037入口。",14);
  text("连接 FPGA-Instrument 热点，然后点“连接乐器”。声音从外接音箱输出。",14);
  connection=text("未连接",16);host=new EditText(this);host.setSingleLine(true);host.setText("192.168.4.1");host.setTextColor(Color.WHITE);root.addView(host);
  connectButton=button("连接乐器",()->{if(session!=null&&session.isRunning())disconnect();else connect();});
  button("第一次使用 / 操作说明",()->showGuide());
  actual=text("尚无FPGA实际状态",16);keysText=text("光键：—",18);
  wave=new WaveView(this);root.addView(wave,new LinearLayout.LayoutParams(-1,240));
  text("下方为目标参数；上方回传值才是实际状态。",13);
  text("音量（默认160/255）",16);SeekBar volume=new SeekBar(this);volume.setMax(255);volume.setProgress(160);root.addView(volume);
  volume.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener(){public void onStartTrackingTouch(SeekBar s){}public void onStopTrackingTouch(SeekBar s){}public void onProgressChanged(SeekBar s,int v,boolean user){if(user){desiredVolume=v;if(session!=null)session.volume(v);}}});
  Spinner tones=new Spinner(this);ArrayAdapter<String> adapter=new ArrayAdapter<>(this,android.R.layout.simple_spinner_dropdown_item,new String[]{"柔和三角","正弦","锯齿拨弦"});tones.setAdapter(adapter);root.addView(tones);
  tones.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener(){public void onNothingSelected(AdapterView<?> p){}public void onItemSelected(AdapterView<?> p,View v,int n,long id){desiredTone=n;if(session!=null)session.tone(n);}});
  Switch echo=new Switch(this);echo.setText("FPGA硬件延时");echo.setTextColor(Color.WHITE);root.addView(echo);echo.setOnCheckedChangeListener((b,on)->{desiredEcho=on;if(session!=null)session.echo(on);});
  Spinner pages=new Spinner(this);pages.setAdapter(new ArrayAdapter<>(this,android.R.layout.simple_spinner_dropdown_item,new String[]{"板载键音区1","板载键音区2","板载键音区3"}));root.addView(pages);
  pages.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener(){public void onNothingSelected(AdapterView<?> p){}public void onItemSelected(AdapterView<?> p,View v,int n,long id){desiredPage=n;if(session!=null)session.page(n);}});
  text("触屏四键：按住发声，支持多指；有按键时优先手机，松开恢复光键。键位配置可重排四个声部，不是任意音高映射。",14);
  LinearLayout keyboard=new LinearLayout(this);keyboard.setMotionEventSplittingEnabled(true);root.addView(keyboard);
  for(int i=0;i<4;i++){
   final int pad=i;mapping[i]=getPreferences(0).getInt("pad"+i,i);if(mapping[i]<0||mapping[i]>3)mapping[i]=i;
   pads[i]=new Button(this);pads[i].setText("键"+(i+1)+"\n声部"+(mapping[i]+1));keyboard.addView(pads[i],new LinearLayout.LayoutParams(0,180,1));
   pads[i].setOnTouchListener((v,event)->{int a=event.getActionMasked();if(a==MotionEvent.ACTION_DOWN){held[pad]=true;sendKeys();v.setAlpha(.5f);return true;}if(a==MotionEvent.ACTION_UP||a==MotionEvent.ACTION_CANCEL){held[pad]=false;sendKeys();v.setAlpha(1);return true;}return true;});
  }
  button("辅助工具：本地预览 / 输入监听",()->startActivity(new Intent(this,MainActivity.class)));
  button("自定义触屏键位",()->{release();new AlertDialog.Builder(this).setTitle("选择要修改的触屏键").setItems(new String[]{"键1","键2","键3","键4"},(d,n)->new AlertDialog.Builder(this).setTitle("映射到声部").setItems(new String[]{"声部1","声部2","声部3","声部4"},(d2,m)->{mapping[n]=m;getPreferences(0).edit().putInt("pad"+n,m).apply();pads[n].setText("键"+(n+1)+"\n声部"+(m+1));}).show()).show();});
  button("释放触屏键",()->release());
  gestureText=text("K230：等待FPGA手势状态（需E025及串口接线）",14);
  pinchBar=new ProgressBar(this,null,android.R.attr.progressBarStyleHorizontal);pinchBar.setMax(1000);root.addView(pinchBar);
  heightBar=new ProgressBar(this,null,android.R.attr.progressBarStyleHorizontal);heightBar.setMax(1000);root.addView(heightBar);
  button("K230与演奏操作说明",()->new AlertDialog.Builder(this).setTitle("E025 演奏台")
   .setMessage("手机连接 FPGA-Instrument 热点后连接本页。四触屏键按住发声，松开恢复光键。\nK230通过115200串口发送手势：捏合控制音量，高度控制明亮度；手势本身不触发音符。丢手、低置信度或250ms未收到新包恢复本地控制。\n状态和波形来自FPGA；事件CSV不是音频录音。手机扬声器监听仍需要正确外部音频输入，Wi-Fi不传声音。")
   .setPositiveButton("知道了",null).show());
  recordText=text("事件记录未开始（不是音频录音）",14);
  button("开始 / 停止演奏事件记录",()->{recording=!recording;if(recording){events.clear();recordStart=SystemClock.elapsedRealtime();lastEvent="";}recordText.setText(recording?"正在记录FPGA回传事件":"记录已停止："+events.size()+"条");});
  button("导出事件CSV",()->{recording=false;Intent intent=new Intent(Intent.ACTION_CREATE_DOCUMENT);intent.setType("text/csv");intent.addCategory(Intent.CATEGORY_OPENABLE);intent.putExtra(Intent.EXTRA_TITLE,"fpga-performance.csv");startActivityForResult(intent,73);});
 }
 private void showGuide(){
  new AlertDialog.Builder(this).setTitle("演奏指南").setMessage(
   "启用：按住 S1+S2，按下并松开摇杆，再松开两键。只做一次，等待约20秒。\n\n"+
   "光键选音；摇杆左右弯音、上下改变明亮度。触屏支持多指，松开恢复光键。\n\n"+
   "手势：按住演奏键，单手捏合调音量、上下移动调明亮度；移开手恢复本地控制。手势本身不触发音符。\n\n"+
   "音色、音量、延时和音区可直接在本页调整。释放触屏键只释放手机按下的键。\n\n"+
   "CSV是控制事件记录，不是录音。辅助工具提供手机本地预览和输入监听。")
   .setPositiveButton("开始演奏",null).show();
 }
 private void clearGesture(){
  gestureText.setText("K230：尚无当前连接的有效状态");pinchBar.setProgress(0);heightBar.setProgress(0);
 }
 private void connect(){
  clearGesture();
  final String address=host.getText().toString().trim();if(address.isEmpty()){connection.setText("请输入IP地址");return;}
  ConnectivityManager manager=(ConnectivityManager)getSystemService(CONNECTIVITY_SERVICE);Network wifi=null;
  for(Network n:manager.getAllNetworks()){NetworkCapabilities c=manager.getNetworkCapabilities(n);if(c!=null&&c.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)){wifi=n;break;}}
  if(wifi==null){connection.setText("未找到已连接的Wi-Fi，请先连接设备热点");return;}
  final Network network=wifi;final int current=++generation;
  session=new WifiSession(new WifiSession.Listener(){
   public void status(String s){ui.post(()->{if(current==generation){connection.setText(s);connectButton.setText("连接乐器");clearGesture();}});}
   public void snapshot(WifiProtocol.Snapshot s){ui.post(()->{if(current==generation)show(s);});}
  });
  session.volume(desiredVolume);session.tone(desiredTone);session.echo(desiredEcho);session.page(desiredPage);
  connectButton.setText("取消连接");connection.setText("连接中…");session.connect(address,9000,()->network.getSocketFactory().createSocket());
 }
 private void show(WifiProtocol.Snapshot s){
  connectButton.setText("断开乐器");connection.setText("乐器已连接");
  actual.setText("实际音量 "+s.volume+" / 音色 "+(s.timbre+1)+" / 延时 "+(s.echo?"开":"关")+"\n摇杆 "+s.x+", "+s.y+" / 音区 "+(s.page+1)+" / 状态 "+String.format(Locale.ROOT,"%02X",s.flags));
  keysText.setText("实际键位 "+String.format(Locale.ROOT,"%8s",Integer.toBinaryString(s.keys)).replace(' ','0'));wave.set(s.wave);
  gestureText.setText(!s.gestureAvailable?"K230：旧固件未提供状态":
   s.gestureActive?"K230 手势有效 · 序号 "+s.gestureSequence+" · 置信度 "+s.confidence+"%\n捏合 "+s.pinch+" / 高度 "+s.gestureY+"（0–1000）":
   "K230 无有效手势 · 本地控制（丢手、低置信度或串口未接）");
  pinchBar.setProgress(s.gestureActive?s.pinch:0);heightBar.setProgress(s.gestureActive?s.gestureY:0);
  String event=s.keys+","+s.timbre+","+(s.echo?1:0)+","+s.page+","+s.volume+","+s.x+","+s.y+","+s.flags+","+(s.gestureAvailable?1:0)+","+(s.gestureActive?1:0)+","+s.gestureSequence+","+s.pinch+","+s.gestureY+","+s.confidence;
  if(recording&&!event.equals(lastEvent)){
   if(events.size()==5000){recording=false;recordText.setText("已达5000条，停止记录，请导出");}
   else{events.add((SystemClock.elapsedRealtime()-recordStart)+","+s.sequence+","+event);lastEvent=event;recordText.setText("事件记录："+events.size()+"条（接收时间，不是音频时戳）");}
  }
 }
 private void sendKeys(){int mask=0;for(int i=0;i<4;i++)if(held[i])mask|=1<<mapping[i];if(session!=null)session.keys(mask);}
 private void release(){Arrays.fill(held,false);sendKeys();for(Button pad:pads)if(pad!=null)pad.setAlpha(1);}
 private void disconnect(){generation++;release();clearGesture();if(session!=null)session.close();connectButton.setText("连接乐器");connection.setText("已断开，恢复本地演奏");}
 @Override protected void onPause(){recording=false;disconnect();super.onPause();}
 @Override protected void onActivityResult(int request,int result,Intent data){super.onActivityResult(request,result,data);if(request==73&&result==RESULT_OK&&data!=null){try(OutputStream out=getContentResolver().openOutputStream(data.getData())){if(out==null)throw new IOException("无法打开文件");out.write("receive_ms,sequence,keys,timbre,echo,page,volume,x,y,flags,gesture_available,gesture_active,gesture_sequence,pinch,gesture_y,confidence\n".getBytes(StandardCharsets.UTF_8));for(String line:events)out.write((line+"\n").getBytes(StandardCharsets.UTF_8));recordText.setText("CSV已导出："+events.size()+"条");}catch(IOException e){recordText.setText("导出失败："+e.getMessage());}}}
 private static final class WaveView extends View {
  final Paint pen=new Paint(3);int[] values=new int[32];
  WaveView(Context context){super(context);Arrays.fill(values,128);}
  void set(int[] wave){values=wave.clone();invalidate();}
  @Override protected void onDraw(Canvas c){super.onDraw(c);float w=getWidth(),h=getHeight();c.drawColor(Color.rgb(4,13,21));pen.setStrokeWidth(1);pen.setColor(Color.rgb(30,55,70));for(int i=1;i<4;i++)c.drawLine(0,h*i/4,w,h*i/4,pen);pen.setStrokeWidth(3);pen.setColor(Color.rgb(100,235,255));for(int i=1;i<values.length;i++)c.drawLine(w*(i-1)/31,h*(255-values[i-1])/255,w*i/31,h*(255-values[i])/255,pen);}
 }
}
