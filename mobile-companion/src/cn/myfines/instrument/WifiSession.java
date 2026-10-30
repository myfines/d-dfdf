package cn.myfines.instrument;

import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;

/** One bounded socket worker; no Android dependency so a mock server can test it. */
public final class WifiSession implements AutoCloseable {
 public interface Listener {void status(String message);void snapshot(WifiProtocol.Snapshot snapshot);default void extension(DirectExtension.Frame frame){} }
 public interface SocketSource {Socket create() throws IOException;}
 private final Listener listener;
 private volatile boolean running;
 private volatile Socket socket;
 private Thread worker;
 private final Object stateLock=new Object();
 private int volume=160,tone=0,echo=0,page=0,keys=0,vibrato=0,fx=0,screen=0,demo=0;
 private boolean dirty=true;
 private final java.util.concurrent.ArrayBlockingQueue<String> extensions=new java.util.concurrent.ArrayBlockingQueue<>(96);
 public void extension(String packet){if(!packet.matches("(?:[WUCG][0-9A-F]{8}|R0[01])"))throw new IllegalArgumentException("扩展命令错误");if(!running||!extensions.offer(packet+"\n"))throw new IllegalStateException("直连未运行或发送队列已满");}
 public WifiSession(Listener listener){this.listener=listener;}
 public void volume(int value){set('V',value);}
 public void vibrato(int value){set('X',value);}
 public void envelope(int attack,int decay,int sustain,int release){extension(ExtensionProtocol.envelope(attack,decay,sustain,release));}
 public void resetEnvelope(){extension("G00000000");}
 public void tone(int value){set('T',value);}
 public void echo(boolean value){set('E',value?1:0);}
 public void effects(int value){set('F',value);}
 public void screen(int value){set('S',value);}
 public void demo(boolean value){set('D',value?1:0);}
 public void page(int value){set('P',value);}
 public void keys(int value){set('K',value);}
 private void set(char kind,int value){
  WifiProtocol.command(kind,value);
  synchronized(stateLock){switch(kind){case 'V':volume=value;break;case 'X':vibrato=value;break;case 'T':tone=value;break;case 'E':echo=value;fx=(fx&5)|(value<<1);break;case 'F':fx=value;echo=(value>>1)&1;break;case 'S':screen=value;break;case 'D':demo=value;break;case 'P':page=value;break;default:keys=value;}dirty=true;}
 }
 public synchronized void connect(final String host,final int port,final SocketSource source) {
  if(running)throw new IllegalStateException("Already connecting");
  running=true;dirty=true;
  worker=new Thread(()->run(host,port,source),"FPGA-WiFi");worker.start();
 }
 private void run(String host,int port,SocketSource source) {
  String failure="";
  try(Socket s=source.create()){
   socket=s;if(!running)return;
   s.connect(new InetSocketAddress(host,port),3000);s.setSoTimeout(100);s.setTcpNoDelay(true);
   InputStream input=s.getInputStream();OutputStream output=s.getOutputStream();
   // A broken previous socket may leave FPGA telemetry selecting an A/PCM
   // chunk. Restore normal snapshots before replaying queued controls.
   output.write("C00000000\n".getBytes(StandardCharsets.US_ASCII));output.flush();
   listener.status("TCP已连接，等待FPGA真实状态");
   StringBuilder line=new StringBuilder(96);long sent=0,received=System.nanoTime();boolean first=true;
   while(running){
    for(int count=0;count<8;count++){String packet=extensions.poll();if(packet==null)break;output.write(packet.getBytes(StandardCharsets.US_ASCII));output.flush();}
    long now=System.nanoTime();
    synchronized(stateLock){
     if(dirty || first || now-sent>=500000000L){
      String message=WifiProtocol.command('V',volume)+WifiProtocol.command('T',tone)
       +WifiProtocol.command('X',vibrato)+WifiProtocol.command('E',echo)+WifiProtocol.command('F',fx)+WifiProtocol.command('S',screen)+WifiProtocol.command('D',demo)+WifiProtocol.command('P',page)+WifiProtocol.command('K',keys)+WifiProtocol.command('Q',0);
      output.write(message.getBytes(StandardCharsets.US_ASCII));output.flush();sent=now;dirty=false;first=false;
     }
    }
    try{
     int b=input.read();if(b<0)throw new EOFException("设备断开");
     if(b==10){
      String frame=line.toString();line.setLength(0);received=System.nanoTime();
      if(frame.startsWith("A"))listener.extension(DirectExtension.parse(frame));else listener.snapshot(WifiProtocol.parse(frame));
     }else{
      if(b<32 || b>126 || line.length()>=95)throw new IOException("状态帧格式错误");
      line.append((char)b);
     }
    }catch(SocketTimeoutException timeout){/* bounded wait; send lease on next loop */}
    if(System.nanoTime()-received>3000000000L)throw new IOException("3秒未收到FPGA状态；停止远控");
   }
   output.write(WifiProtocol.command('L',0).getBytes(StandardCharsets.US_ASCII));output.flush();
  }catch(Exception error){if(running)failure="连接停止："+error.getMessage()+"；";}
  finally{running=false;socket=null; synchronized(stateLock){keys=0;vibrato=0;demo=0;} extensions.clear(); listener.status(failure+"已断开；FPGA最迟5秒释放远控");}
 }
 public boolean isRunning(){return running;}
 @Override public void close(){
  running=false;
  // Do not block the UI thread on network writes; socket close interrupts read/connect.
  Socket s=socket;if(s!=null)try{s.close();}catch(IOException ignored){}
 }
}
