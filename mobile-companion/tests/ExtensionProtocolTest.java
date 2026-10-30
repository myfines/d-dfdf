package cn.myfines.instrument;
public class ExtensionProtocolTest {
 public static void main(String[]args){
  if(!ExtensionProtocol.keymap(0,31).equals("U10001F0F"))throw new AssertionError("map");
  if(!ExtensionProtocol.chunk(127).equals("C10027F6D"))throw new AssertionError("chunk");
  String[]s=ExtensionProtocol.score("12:2,-:2");if(!s[1].equals("W000C020E")||!s[2].equals("W01FF02FC")||!s[3].equals("WFF0102FC"))throw new AssertionError("score");
  try{ExtensionProtocol.score("32:0");throw new AssertionError("bounds");}catch(IllegalArgumentException expected){}
  if(!ExtensionProtocol.envelope(9,12,160,13).equals("G19CDA074"))throw new AssertionError("ADSR nibble order/checksum");
  if(!ExtensionProtocol.envelope(0,0,0,0).equals("G10000010"))throw new AssertionError("enabled zero envelope differs from reset");
  try{ExtensionProtocol.envelope(16,0,0,0);throw new AssertionError("attack bounds");}catch(IllegalArgumentException expected){}
  try{ExtensionProtocol.envelope(0,0,256,0);throw new AssertionError("sustain bounds");}catch(IllegalArgumentException expected){}
  if(!WifiProtocol.command('X',255).equals("XFF\n"))throw new AssertionError("vibrato");
  try{WifiProtocol.command('X',256);throw new AssertionError("vibrato bounds");}catch(IllegalArgumentException expected){}
  if(!WifiProtocol.command('F',7).equals("F07\n")||!WifiProtocol.command('S',4).equals("S04\n")||!WifiProtocol.command('D',1).equals("D01\n"))throw new AssertionError("FX/display/test mode");
  try{WifiProtocol.command('F',8);throw new AssertionError("FX bounds");}catch(IllegalArgumentException expected){}
  System.out.println("PASS Android extension packet encoding and bounds");
 }
}
