package cn.myfines.instrument;
import java.nio.file.*;
import java.util.*;
/** Replay actual USB diagnostic A packets through the production Android parser. */
public final class DirectBoardReplayTest {
 public static void main(String[] args)throws Exception {
  if(args.length!=2)throw new IllegalArgumentException("frames.txt output.wav");
  int packets=0,id=-1;byte[][] chunks=new byte[128][];
  for(String line:Files.readAllLines(Paths.get(args[0]))){
   if(!line.startsWith("A"))continue;
   DirectExtension.Frame f=DirectExtension.parse(line.trim());packets++;
   if(f.flags!=2)continue;
   if(f.id!=id){id=f.id;chunks=new byte[128][];}
   chunks[f.chunk]=f.pcm;
  }
  if(packets==0)throw new AssertionError("no real packets");
  byte[] pcm=new byte[4096];
  for(int i=0;i<128;i++){
   if(chunks[i]==null)throw new AssertionError("missing chunk "+i);
   System.arraycopy(chunks[i],0,pcm,i*32,32);
  }
  byte[] wav=DirectExtension.wav(pcm,8);Files.write(Paths.get(args[1]),wav);
  System.out.println("PASS Android production parser replay: "+packets+" real A packets, same recording ID="+id+", complete128 chunks, WAV bytes="+wav.length);
 }
}
