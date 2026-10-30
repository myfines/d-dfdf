package cn.myfines.instrument;
import java.net.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
public final class ScoreDownloadTest {
 public static void main(String[] args)throws Exception {
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
  System.out.println("PASS online score download, format validation, size and URL bounds");
 }
}
