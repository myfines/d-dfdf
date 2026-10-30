package cn.myfines.instrument;
import java.io.*;
import java.util.function.Predicate;
/** Direct TCP extensions. Call operations off the UI/network reader threads. */
public final class DirectExtension {
 public interface Wire {void send(String packet);boolean connected();}
 public interface Progress {void update(String text);}
 public static final class Frame {
  public int id,chunk,flags,length,decimate,scoreLength,mapNote,adsrConfig;public boolean scoreReady,adsrEnabled;public byte[] pcm;
 }
 private final Wire wire;private Frame latest;private long serial;private boolean cancelled;
 public DirectExtension(Wire wire){this.wire=wire;}
 private static int hex(String s,int a,int b){for(int i=a;i<b;i++)if(Character.digit(s.charAt(i),16)<0)throw new IllegalArgumentException("A帧十六进制错误");return Integer.parseInt(s.substring(a,b),16);}
 public static Frame parse(String s){
  if(s.length()!=95||s.charAt(0)!='A'||s.charAt(94)!='1')throw new IllegalArgumentException("A帧长度/版本错误");
  Frame f=new Frame();f.id=hex(s,1,5);f.chunk=hex(s,5,7);f.flags=hex(s,7,9);f.length=hex(s,9,13);f.decimate=hex(s,13,15);f.scoreLength=hex(s,15,17);f.scoreReady=hex(s,17,18)==1;f.mapNote=hex(s,18,20);f.pcm=new byte[32];
  f.adsrEnabled=hex(s,88,89)==1;f.adsrConfig=hex(s,89,94);
  int sum=0;for(int i=0;i<32;i++){int n=hex(s,20+i*2,22+i*2);sum+=n;f.pcm[i]=(byte)n;}
  // Chunks0..31 carry a keymap note; later PCM chunks use HDL sentinel FF.
  if((f.chunk<32?f.mapNote>31:f.mapNote!=255)||f.chunk>127||f.flags>2||f.length!=4096||f.decimate!=8||f.scoreLength>64||hex(s,17,18)>1||hex(s,88,89)>1||sum!=hex(s,84,88))throw new IllegalArgumentException("A帧范围/校验错误");hex(s,89,94);return f;
 }
 public synchronized void accept(Frame f){latest=f;serial++;notifyAll();}
 public synchronized void cancel(){cancelled=true;notifyAll();}
 private synchronized Frame exchange(String packet,Predicate<Frame> match)throws Exception{
  long before=serial,end=System.nanoTime()+15000000000L;wire.send(packet);
  while(true){
   if(cancelled||!wire.connected())throw new IOException("直连操作已取消/断开");
   if(serial>before&&latest!=null&&match.test(latest))return latest;
   if(System.nanoTime()>=end)throw new IOException("设备回读超时；未确认应用");wait(150);
  }
 }
 private void begin()throws IOException{ synchronized(this){if(cancelled||!wire.connected())throw new IOException("请先连接设备");} }
 public void keymap(int slot,int note)throws Exception{
  begin();try{wire.send(ExtensionProtocol.keymap(slot,note));exchange(ExtensionProtocol.chunk(slot),f->f.chunk==slot&&f.mapNote==note);}finally{wire.send("C00000000");}
 }
 public void envelope(int attack,int decay,int sustain,int release)throws Exception{
  String packet=ExtensionProtocol.envelope(attack,decay,sustain,release);int config=(attack<<16)|(decay<<12)|(release<<8)|sustain;begin();
  try{wire.send(packet);exchange(ExtensionProtocol.chunk(0),f->f.adsrEnabled&&f.adsrConfig==config);}finally{wire.send("C00000000");}
 }
 public void resetEnvelope()throws Exception{
  begin();try{wire.send("G00000000");exchange(ExtensionProtocol.chunk(0),f->!f.adsrEnabled);}finally{wire.send("C00000000");}
 }
 public void score(String text)throws Exception{
  String[] packets=ExtensionProtocol.score(text);begin();
  try{
   wire.send("R00");wire.send(packets[0]);exchange(ExtensionProtocol.chunk(0),f->!f.scoreReady);
   for(int i=1;i<packets.length;i++)wire.send(packets[i]);
   exchange(ExtensionProtocol.chunk(0),f->f.scoreReady&&f.scoreLength==packets.length-2);
  }finally{wire.send("C00000000");}
 }
 public byte[] record(Progress progress)throws Exception{
  begin();try{
   Frame old=exchange(ExtensionProtocol.chunk(0),f->true);
   Frame first=exchange("C10010011",f->f.id!=old.id&&f.flags==2);
   byte[] pcm=new byte[first.length];final int id=first.id;
   for(int i=0;i<128;i++){final int chunk=i;Frame f=exchange(ExtensionProtocol.chunk(i),a->a.id==id&&a.flags==2&&a.chunk==chunk);System.arraycopy(f.pcm,0,pcm,i*32,32);progress.update("录音回传 "+(i+1)+" / 128");}
   return wav(pcm,first.decimate);
  }finally{wire.send("C00000000");}
 }
 public static byte[] wav(byte[] pcm,int decimate)throws IOException{
  if(decimate!=8||pcm.length!=4096)throw new IllegalArgumentException("PCM尺寸/抽取率错误");
  ByteArrayOutputStream out=new ByteArrayOutputStream();out.write("RIFF".getBytes("US-ASCII"));le(out,36+pcm.length,4);out.write("WAVEfmt ".getBytes("US-ASCII"));le(out,16,4);le(out,1,2);le(out,1,2);
  // RIFF integer rate rounded from actual HDL rate46875/8, not phone capture rate.
  int rate=(46875+decimate/2)/decimate;le(out,rate,4);le(out,rate,4);le(out,1,2);le(out,8,2);out.write("data".getBytes("US-ASCII"));le(out,pcm.length,4);for(byte b:pcm)out.write((b&255)^128);return out.toByteArray();
 }
 private static void le(OutputStream out,int n,int count)throws IOException{for(int i=0;i<count;i++)out.write((n>>>(8*i))&255);}
}
