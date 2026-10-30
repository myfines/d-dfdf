package cn.myfines.instrument;
import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
/** Bounded text-score download; no audio is downloaded or used to synthesize. */
public final class ScoreDownload {
 private static final int LIMIT=8192;
 public static String validate(String text){
  if(text.length()>LIMIT)throw new IllegalArgumentException("曲谱文本不能超过8192字符");
  String score=text.trim();if(score.startsWith("\uFEFF"))score=score.substring(1).trim();
  ExtensionProtocol.score(score);return score;
 }
 public static String fetch(String address)throws IOException {
  URL url=new URL(address.trim());
  if(!(url.getProtocol().equals("https")||url.getProtocol().equals("http"))||url.getUserInfo()!=null)throw new IllegalArgumentException("请使用不含账号密码的HTTP/HTTPS曲谱文本网址");
  HttpURLConnection connection=(HttpURLConnection)url.openConnection();
  connection.setConnectTimeout(5000);connection.setReadTimeout(5000);connection.setInstanceFollowRedirects(false);
  try{
   if(connection.getResponseCode()!=200)throw new IOException("曲谱服务器HTTP "+connection.getResponseCode()+"；请使用最终文本网址");
   if(connection.getContentLength()>LIMIT)throw new IOException("曲谱文件超过8192字节");
   long deadline=System.nanoTime()+10000000000L;
   try(InputStream in=connection.getInputStream();ByteArrayOutputStream out=new ByteArrayOutputStream()){
    byte[] block=new byte[1024];int count;
    while((count=in.read(block))!=-1){if(out.size()+count>LIMIT)throw new IOException("曲谱文件超过8192字节");if(System.nanoTime()>deadline)throw new IOException("曲谱下载超时");out.write(block,0,count);}
    return validate(new String(out.toByteArray(),StandardCharsets.UTF_8));
   }
  }finally{connection.disconnect();}
 }
}
