package cn.myfines.instrument;

import java.util.Locale;

/** E023/E025 protocol; status is FPGA-originated, not phone synthesis or audio recording. */
public final class WifiProtocol {
 private WifiProtocol() {}
 public static final class Snapshot {
  public final int sequence,keys,flags,x,y,volume,timbre,page;
  public final boolean echo;
  public boolean gestureAvailable,gestureActive;
  public int gestureSequence,pinch,gestureY,confidence;
  public final int[] wave;
  Snapshot(int sequence,int keys,int flags,int x,int y,int volume,int timbre,boolean echo,int page,int[] wave) {
   this.sequence=sequence;this.keys=keys;this.flags=flags;this.x=x;this.y=y;
   this.volume=volume;this.timbre=timbre;this.echo=echo;this.page=page;this.wave=wave;
  }
 }
 private static int hex(String line,int from,int to) {
  for(int i=from;i<to;i++)if(Character.digit(line.charAt(i),16)<0)throw new IllegalArgumentException("Invalid hex");
  return Integer.parseInt(line.substring(from,to),16);
 }
 public static Snapshot parse(String line) {
  boolean extended=line.length()==95 && line.charAt(0)=='G';
  if(!extended && (line.length()!=84 || line.charAt(0)!='S'))throw new IllegalArgumentException("Expected E023/E025 snapshot");
  int tone=hex(line,17,18),echo=hex(line,18,19),page=hex(line,19,20);
  if(tone>2 || echo>1 || page>2)throw new IllegalArgumentException("Status range");
  int[] wave=new int[32];for(int i=0;i<32;i++)wave[i]=hex(line,20+2*i,22+2*i);
  Snapshot result=new Snapshot(hex(line,1,5),hex(line,5,7),hex(line,7,9),hex(line,9,12),hex(line,12,15),hex(line,15,17),tone,echo==1,page,wave);
  if(extended){
   int active=hex(line,84,85),pinch=hex(line,87,90),y=hex(line,90,93),confidence=hex(line,93,95);
   if(active>1||pinch>1000||y>1000||confidence>100)throw new IllegalArgumentException("Gesture range");
   result.gestureAvailable=true;result.gestureActive=active==1;result.gestureSequence=hex(line,85,87);
   result.pinch=pinch;result.gestureY=y;result.confidence=confidence;
  }
  return result;
 }
 public static String command(char kind,int value) {
  boolean valid=(kind=='V'&&value>=0&&value<=255)||(kind=='T'&&value>=0&&value<=2)
   ||(kind=='E'&&value>=0&&value<=1)||(kind=='K'&&value>=0&&value<=15)
   ||(kind=='P'&&value>=0&&value<=2)||((kind=='Q'||kind=='L')&&value==0);
  if(!valid)throw new IllegalArgumentException("Command range");
  return String.format(Locale.ROOT,"%c%02X\n",kind,value);
 }
}
