package cn.myfines.instrument;
import java.net.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
public final class ScoreDownloadTest {
 private static void rejectedResponse(String headers,byte[] body)throws Exception {
  try(ServerSocket server=new ServerSocket(0)){
   java.util.concurrent.CompletableFuture<Void> served=new java.util.concurrent.CompletableFuture<>();
   Thread peer=new Thread(()->{try(Socket socket=server.accept()){
    socket.setSoTimeout(2000);BufferedReader input=new BufferedReader(new InputStreamReader(socket.getInputStream(),StandardCharsets.US_ASCII));
    String line;while((line=input.readLine())!=null&&!line.isEmpty()){}
    socket.getOutputStream().write(headers.getBytes(StandardCharsets.US_ASCII));socket.getOutputStream().write(body);socket.getOutputStream().flush();served.complete(null);
   }catch(Exception error){served.completeExceptionally(error);}});peer.setDaemon(true);peer.start();
   boolean rejected=false;try{ScoreDownload.fetch("http://127.0.0.1:"+server.getLocalPort()+"/song");}catch(IOException|IllegalArgumentException expected){rejected=true;}
   if(!rejected)throw new AssertionError("invalid HTTP score accepted");
   served.get(3,java.util.concurrent.TimeUnit.SECONDS);peer.join(2000);
  }
 }
 public static void main(String[] args)throws Exception {
  if(!ScoreDownload.addressOrExample("  ").equals(ScoreDownload.EXAMPLE_URL))throw new AssertionError("blank URL should use ready-to-download example");
  if(!ScoreDownload.addressOrExample(null).equals(ScoreDownload.EXAMPLE_URL))throw new AssertionError("missing saved URL should use example");
  if(!ScoreDownload.addressOrExample(" http://127.0.0.1/song ").equals("http://127.0.0.1/song"))throw new AssertionError("custom URL preserved");
  if(!ScoreDownload.validate(ScoreDownload.EXAMPLE_SCORE).equals(ScoreDownload.EXAMPLE_SCORE))throw new AssertionError("bundled offline example must be valid");
  try(ServerSocket server=new ServerSocket(0)){
   Thread peer=new Thread(()->{try(Socket socket=server.accept()){
    BufferedReader in=new BufferedReader(new InputStreamReader(socket.getInputStream(),StandardCharsets.US_ASCII));
    while(!in.readLine().isEmpty()){}
    byte[] body="12:20,16:20,-:10".getBytes(StandardCharsets.UTF_8);
    socket.getOutputStream().write(("HTTP/1.1 200 OK\r\nContent-Length: "+body.length+"\r\nConnection: close\r\n\r\n").getBytes(StandardCharsets.US_ASCII));socket.getOutputStream().write(body);
   }catch(Exception e){throw new RuntimeException(e);}});peer.start();
   if(!ScoreDownload.fetch("http://127.0.0.1:"+server.getLocalPort()+"/song").equals("12:20,16:20,-:10"))throw new AssertionError("download validated score");peer.join(2000);
  }
  for(String address:new String[]{"file:///song","ftp://example.com/song","https://user:password@example.com/song"}){
   try{ScoreDownload.fetch(address);throw new AssertionError("unsupported URL accepted");}catch(IllegalArgumentException expected){}
  }
  try{ScoreDownload.validate("32:20");throw new AssertionError("bad downloaded note");}catch(IllegalArgumentException expected){}
  try{ScoreDownload.validate(new String(new char[8193]).replace('\0','1'));throw new AssertionError("oversize");}catch(IllegalArgumentException expected){}
  rejectedResponse("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n",new byte[0]);
  rejectedResponse("HTTP/1.1 302 Found\r\nLocation: /elsewhere\r\nContent-Length: 0\r\nConnection: close\r\n\r\n",new byte[0]);
  byte[] html="<html>not a score</html>".getBytes(StandardCharsets.UTF_8);
  rejectedResponse("HTTP/1.1 200 OK\r\nContent-Length: "+html.length+"\r\nConnection: close\r\n\r\n",html);
  byte[] huge=new byte[8193];java.util.Arrays.fill(huge,(byte)'1');
  rejectedResponse("HTTP/1.1 200 OK\r\nConnection: close\r\n\r\n",huge);
  System.out.println("PASS online score download, default example, offline score, custom URL and HTTP/format/size rejection");
 }
}
