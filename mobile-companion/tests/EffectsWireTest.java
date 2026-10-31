package cn.myfines.instrument;

import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.*;

public final class EffectsWireTest {
 public static void main(String[] args)throws Exception {
  for(int saved=0;saved<8;saved++){
   EffectsState restored=new EffectsState(saved,false);
   try(ServerSocket server=new ServerSocket(0)){
    CompletableFuture<String> captured=new CompletableFuture<>();
    Thread peer=new Thread(()->{
     try(Socket socket=server.accept()){
      socket.setSoTimeout(2000);
      BufferedReader input=new BufferedReader(new InputStreamReader(socket.getInputStream(),StandardCharsets.US_ASCII));
      StringBuilder wire=new StringBuilder();String line;
      while((line=input.readLine())!=null){wire.append(line).append('\n');if(line.equals("Q00"))break;}
      captured.complete(wire.toString());
     }catch(Exception e){captured.completeExceptionally(e);}
    });peer.setDaemon(true);peer.start();
    WifiSession session=new WifiSession(new WifiSession.Listener(){public void status(String text){}public void snapshot(WifiProtocol.Snapshot snapshot){}});
    try{
     session.effects(restored.mask());session.connect("127.0.0.1",server.getLocalPort(),Socket::new);
     String wire=captured.get(3,TimeUnit.SECONDS);
     String expected=String.format("E%02X\nF%02X\n",restored.delay()?1:0,saved);
     if(!wire.startsWith("C00000000\n")||!wire.contains(expected))throw new AssertionError("saved effects replay "+saved+": "+wire);
    }finally{session.close();peer.join(2500);}
   }
  }
  System.out.println("PASS actual TCP effect replay: exact E/F bytes for all8 restored combinations");
 }
}
