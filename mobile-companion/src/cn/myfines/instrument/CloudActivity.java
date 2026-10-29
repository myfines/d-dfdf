package cn.myfines.instrument;
import android.app.Activity;
import android.os.Bundle;
import android.os.Build;
import android.os.Environment;
import android.content.ContentValues;
import android.provider.MediaStore;
import android.net.Uri;
import android.widget.*;
import android.text.InputType;
import org.json.JSONObject;
import java.net.*;
import java.io.*;
import java.util.concurrent.*;

/** Public relay client; keeps the phone's normal network, no ESP hotspot switch. */
public class CloudActivity extends Activity {
 private EditText server,token,slot,note,score;private TextView status;
 private final ThreadPoolExecutor worker=new ThreadPoolExecutor(1,1,0,TimeUnit.SECONDS,new ArrayBlockingQueue<Runnable>(2));
 private volatile boolean abortTask;
 private volatile boolean cancelled;private volatile String base,secret;
 private interface Work {void run()throws Exception;}
 @Override public void onCreate(Bundle b){super.onCreate(b);
  LinearLayout root=new LinearLayout(this);root.setOrientation(1);root.setPadding(20,16,20,16);ScrollView scroll=new ScrollView(this);scroll.addView(root);setContentView(scroll);
  label(root,"FPGA 公网控制 · E037+（保持手机原网络）");
  server=edit(root,"网页服务器地址 https://…","");token=edit(root,"访问令牌（不保存）","");token.setInputType(InputType.TYPE_CLASS_TEXT|InputType.TYPE_TEXT_VARIATION_PASSWORD);
  status=label(root,"先填写已部署的中继地址和访问令牌。服务端源码更新不代表服务已启动。");
  button(root,"检查设备",()->run(()->message(state().toString(2))));
  slot=edit(root,"键位位置0..31","0");note=edit(root,"目标音符0..31，C4=12","12");
  button(root,"设置键位（先松开演奏键）",()->run(()->{command(ExtensionProtocol.keymap(Integer.parseInt(slot.getText().toString()),Integer.parseInt(note.getText().toString())));message("已提交键位；请用实际演奏确认，网络接收不等于设备已应用。");}));
  button(root,"恢复默认键位",()->run(()->{command("U00000000");message("已提交默认键位恢复。");}));
  label(root,"曲谱：音符:时长，用逗号分隔。-为休止；每单位约10ms。下载到FPGA后可断网，用板载S3短按启停。");
  score=edit(root,"12:20,16:20,-:10","12:20,16:20,19:20,-:10");
  button(root,"下载曲谱并校验提交状态",()->run(()->upload(ExtensionProtocol.score(score.getText().toString()))));
  button(root,"播放已下载曲谱",()->run(()->{if(state().optInt("queued_commands")!=0)throw new IOException("上传队列尚未清空");command("R01");message("已请求播放；本地S3也可独立启停。");}));
  button(root,"停止曲谱",()->run(()->{command("R00");message("已请求停止远程曲谱；本地S3开启的曲谱需本地关闭。");}));
  button(root,"恢复内置曲谱",()->run(()->{command("R00");command("WFF0000FF");message("已请求恢复内置曲谱。");}));
  label(root,"数字录音：实时PCM短录音约0.7秒，8位单声道，约5.86kHz。不是屏幕波形，也不是连续高保真录音。传回128块可能需要数分钟。");
  button(root,"录制并保存WAV（点击前保持演奏）",()->run(this::record));
  button(root,"紧急释放远程演奏",()->{abortTask=true;worker.getQueue().clear();new Thread(()->{try{command("L00");command("C00000000");message("远程演奏已请求释放；物理键仍独立工作。");}catch(Exception e){message("停止请求失败，远程演奏租约会自动过期。");}}).start();});
 }
 private TextView label(LinearLayout p,String s){TextView t=new TextView(this);t.setText(s);t.setTextSize(15);t.setPadding(0,8,0,8);p.addView(t);return t;}
 private EditText edit(LinearLayout p,String hint,String text){EditText e=new EditText(this);e.setHint(hint);e.setText(text);p.addView(e);return e;}
 private void button(LinearLayout p,String text,Runnable r){Button b=new Button(this);b.setText(text);b.setOnClickListener(v->r.run());p.addView(b);}
 private void message(String s){runOnUiThread(()->status.setText(s));}
 private void run(Work w){
  if(worker.isShutdown())return;
  final String b=server.getText().toString().trim().replaceAll("/+$","");final String key=token.getText().toString();
  if(!b.startsWith("https://")||key.isEmpty()){message("请填写HTTPS服务地址和访问令牌。");return;}
  try{worker.execute(()->{base=b;secret=key;abortTask=false;try{w.run();}catch(Exception e){message("未完成："+e.getMessage());}});}catch(RejectedExecutionException e){message("任务进行中，请等待或紧急释放。");}
 }
 private byte[] request(String path,boolean post)throws Exception{
  if(cancelled)throw new IOException("页面已关闭");HttpURLConnection c=(HttpURLConnection)new URL(base+path).openConnection();
  c.setConnectTimeout(5000);c.setReadTimeout(5000);c.setRequestProperty("Authorization","Bearer "+secret);c.setInstanceFollowRedirects(false);
  if(post){c.setRequestMethod("POST");c.setDoOutput(true);c.setFixedLengthStreamingMode(0);c.getOutputStream().close();}
  try{int code=c.getResponseCode();if(code!=200)throw new IOException("服务器HTTP "+code);
   ByteArrayOutputStream out=new ByteArrayOutputStream();try(InputStream in=c.getInputStream()){byte[]buf=new byte[4096];int n;while((n=in.read(buf))>=0){out.write(buf,0,n);if(out.size()>65536)throw new IOException("响应过大");}}return out.toByteArray();
  }finally{c.disconnect();}
 }
 private void command(String cmd)throws Exception{request("/api/c/"+cmd,true);}
 private JSONObject state()throws Exception{return new JSONObject(new String(request("/api/state",false),"UTF-8"));}
 private JSONObject waitRecord(int id,int chunk,boolean ready,long end)throws Exception{
  while(System.currentTimeMillis()<end&&!cancelled&&!abortTask){command("Q01");JSONObject r=state().getJSONObject("recording");
   if((id<0||r.optInt("id",-1)==id)&&(chunk<0||r.optInt("last_chunk",-1)==chunk)&&(!ready||r.optInt("flags")==2))return r;
   Thread.sleep(250);
  }throw new IOException("设备录音状态等待超时");
 }
 private void upload(String[]packets)throws Exception{
  command("R00");command(packets[0]);command("C10020012");long end=System.currentTimeMillis()+30000;
  boolean cleared=false;while(System.currentTimeMillis()<end&&!abortTask){command("Q01");JSONObject s=state();JSONObject a=s.getJSONObject("recording").optJSONObject("applied");if(s.optInt("queued_commands")==0&&a!=null&&!a.optBoolean("score_ready")){cleared=true;break;}Thread.sleep(250);}
  if(!cleared)throw new IOException("旧曲谱清空尚未得到设备回读");
  for(int i=1;i<packets.length;i++)command(packets[i]);
  boolean committed=false;end=System.currentTimeMillis()+45000;
  while(System.currentTimeMillis()<end&&!abortTask){command("Q01");JSONObject a=state().getJSONObject("recording").optJSONObject("applied");if(a!=null&&a.optBoolean("score_ready")&&a.optInt("score_length")==packets.length-2){committed=true;break;}Thread.sleep(250);}
  command("C00000000");if(!committed)throw new IOException("设备未确认完整曲谱提交");message("FPGA已回读完整曲谱，事件数"+(packets.length-2)+"。断网后用板载S3短按启停；重新上电需重新下载。");
 }
 private void record()throws Exception{
  int previous=state().getJSONObject("recording").optInt("id",-1);command("C10010011");long end=System.currentTimeMillis()+180000;JSONObject r;
  do{r=waitRecord(-1,-1,true,end);if(r.optInt("id",-1)==previous)Thread.sleep(250);}while(r.optInt("id",-1)==previous&&System.currentTimeMillis()<end);
  int id=r.getInt("id");if(id==previous)throw new IOException("设备未启动新录音");
  for(int i=0;i<128;i++){command(ExtensionProtocol.chunk(i));waitRecord(id,i,true,end);message("回传录音 "+(i+1)+" /128；请保持连接。");}
  byte[]wav=request("/api/recording.wav",false);String name="FPGA-"+System.currentTimeMillis()+".wav";
  if(Build.VERSION.SDK_INT>=29){ContentValues v=new ContentValues();v.put(MediaStore.MediaColumns.DISPLAY_NAME,name);v.put(MediaStore.MediaColumns.MIME_TYPE,"audio/wav");v.put(MediaStore.MediaColumns.RELATIVE_PATH,Environment.DIRECTORY_DOWNLOADS+"/FPGA");Uri uri=getContentResolver().insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI,v);if(uri==null)throw new IOException("无法创建下载文件");try(OutputStream out=getContentResolver().openOutputStream(uri)){out.write(wav);}}
  else{File f=new File(getExternalFilesDir(null),name);try(OutputStream out=new FileOutputStream(f)){out.write(wav);}}
  command("C00000000");message("数字录音已保存：下载/FPGA/"+name+"（Android8/9在应用文件目录）。");
 }
 @Override public void onDestroy(){cancelled=true;worker.shutdownNow();super.onDestroy();}
 @Override protected void onResume(){super.onResume();UiStyle.apply(this);}
}
