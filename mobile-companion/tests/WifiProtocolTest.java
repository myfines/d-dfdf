package cn.myfines.instrument;
public final class WifiProtocolTest {
 public static void main(String[] args) {
  StringBuilder line=new StringBuilder("S00010F8101234580021");
  // fields are fixed-width; construct explicitly to avoid locale formatting.
  line=new StringBuilder("S0001"+"0F"+"81"+"012"+"345"+"80"+"2"+"1"+"0");
  for(int i=0;i<32;i++)line.append(String.format(java.util.Locale.ROOT,"%02X",i));
  WifiProtocol.Snapshot s=WifiProtocol.parse(line.toString());
  if(s.sequence!=1||s.keys!=15||s.x!=18||s.y!=837||s.volume!=128||s.timbre!=2||!s.echo||s.wave[31]!=31)throw new AssertionError("decode");
  if(!WifiProtocol.command('K',15).equals("K0F\n"))throw new AssertionError("command");
  for(String bad:new String[]{"",line+"X",line.toString().replace("S0001","SZZZZ"),line.toString().substring(0,19)+"9"+line.substring(20)}) {
   try {WifiProtocol.parse(bad);throw new AssertionError("invalid accepted");}catch(IllegalArgumentException expected){}
  }
  try {WifiProtocol.command('T',4);throw new AssertionError("range");}catch(IllegalArgumentException expected){}
  System.out.println("PASS WiFi protocol: actual snapshot fields, waveform, invalid/range checks");
 }
}
