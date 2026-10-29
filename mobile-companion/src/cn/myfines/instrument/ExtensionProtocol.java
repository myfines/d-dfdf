package cn.myfines.instrument;
public final class ExtensionProtocol {
 private static String packet(char kind,int a,int b,int c){return String.format(java.util.Locale.ROOT,"%c%02X%02X%02X%02X",kind,a,b,c,a^b^c);}
 public static String keymap(int slot,int note){if(slot<0||slot>31||note<0||note>31)throw new IllegalArgumentException("位置/音符应为0..31");return packet('U',16,slot,note);}
 public static String chunk(int index){if(index<0||index>127)throw new IllegalArgumentException("分块应为0..127");return packet('C',16,2,index);}
 public static String[] score(String text){
  String[] events=text.trim().split("[,，\\s]+");if(events.length<1||events.length>64)throw new IllegalArgumentException("曲谱须有1..64个事件");
  String[] result=new String[events.length+2];result[0]=packet('W',255,0,0);
  for(int i=0;i<events.length;i++){
   String[] pair=events[i].split(":");if(pair.length!=2)throw new IllegalArgumentException("格式：12:20,16:20,-:10");
   int note=pair[0].equals("-")?255:Integer.parseInt(pair[0]),duration=Integer.parseInt(pair[1]);
   if((note!=255&&(note<0||note>31))||duration<1||duration>255)throw new IllegalArgumentException("音符0..31；时长1..255；-为休止");
   result[i+1]=packet('W',i,note,duration);
  }
  result[result.length-1]=packet('W',255,1,events.length);return result;
 }
}
