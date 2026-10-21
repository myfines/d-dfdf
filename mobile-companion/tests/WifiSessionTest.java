package cn.myfines.instrument;
import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.*;
public final class WifiSessionTest {
 public static void main(String[] args)throws Exception {
  ServerSocket server=new ServerSocket(0);StringBuilder commands=new StringBuilder();
  CountDownLatch received=new CountDownLatch(1);
  Thread peer=new Thread(()->{try(Socket socket=server.accept()){
   BufferedReader in=new BufferedReader(new InputStreamReader(socket.getInputStream(),StandardCharsets.US_ASCII));
   for(int i=0;i<6;i++)commands.append(in.readLine()).append('\n');
   StringBuilder line=new StringBuilder("S00010F8101234580210");
   line=new StringBuilder("S0001"+"0F"+"81"+"012"+"345"+"80"+"2"+"1"+"0");
   for(int i=0;i<32;i++)line.append("80");
   // Fragment a real status line across TCP writes.
   OutputStream out=socket.getOutputStream();byte[] bytes=(line+"\n").getBytes(StandardCharsets.US_ASCII);
   out.write(bytes,0,13);out.flush();Thread.sleep(10);out.write(bytes,13,bytes.length-13);out.flush();Thread.sleep(50);
  }catch(Exception e){throw new RuntimeException(e);}});peer.start();
  WifiSession session=new WifiSession(new WifiSession.Listener(){public void status(String s){}public void snapshot(WifiProtocol.Snapshot s){if(s.keys==15&&s.timbre==2)received.countDown();}});
  session.volume(128);session.tone(2);session.keys(3);session.connect("127.0.0.1",server.getLocalPort(),Socket::new);
  if(!received.await(3,TimeUnit.SECONDS))throw new AssertionError("snapshot not delivered");
  session.close();peer.join(2000);server.close();
  if(!commands.toString().contains("V80\nT02\n")||!commands.toString().contains("K03\nQ00\n"))throw new AssertionError("control wire protocol");
  System.out.println("PASS WiFi TCP worker: control bytes, fragmented FPGA status, disconnect");
 }
}
