package cn.myfines.instrument;
public class ExtensionProtocolTest {
 public static void main(String[]args){
  if(!ExtensionProtocol.keymap(0,31).equals("U10001F0F"))throw new AssertionError("map");
  if(!ExtensionProtocol.chunk(127).equals("C10027F6D"))throw new AssertionError("chunk");
  String[]s=ExtensionProtocol.score("12:2,-:2");if(!s[1].equals("W000C020E")||!s[2].equals("W01FF02FC")||!s[3].equals("WFF0102FC"))throw new AssertionError("score");
  try{ExtensionProtocol.score("32:0");throw new AssertionError("bounds");}catch(IllegalArgumentException expected){}
  System.out.println("PASS Android extension packet encoding and bounds");
 }
}
