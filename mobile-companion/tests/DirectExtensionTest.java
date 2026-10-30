package cn.myfines.instrument;
public final class DirectExtensionTest {
 public static void main(String[] args)throws Exception{
  // Header is exactly20 characters: id/chunk/flags/length/decimation/score/map.
  StringBuilder s=new StringBuilder("A0001"+"03"+"02"+"1000"+"08"+"04"+"1"+"0C");
  for(int i=0;i<32;i++)s.append("80");s.append("1000"+"0"+"00000"+"1");
  DirectExtension.Frame f=DirectExtension.parse(s.toString());
  DirectExtension.Frame envelope=DirectExtension.parse(s.substring(0,88)+"19CDA0"+"1");
  if(!envelope.adsrEnabled||envelope.adsrConfig!=0x9CDA0)throw new AssertionError("ADSR readback fields");
  if(f.id!=1||f.chunk!=3||f.flags!=2||f.length!=4096||f.decimate!=8||f.scoreLength!=4||!f.scoreReady||f.mapNote!=12)throw new AssertionError("metadata");
  try{DirectExtension.parse(s.substring(0,84)+"0000"+s.substring(88));throw new AssertionError("checksum accepted");}catch(IllegalArgumentException expected){}
  try{DirectExtension.parse(s.substring(0,18)+"20"+s.substring(20));throw new AssertionError("out-of-range mapped note32 accepted");}catch(IllegalArgumentException expected){}
  String later=s.substring(0,5)+"20"+s.substring(7,18)+"FF"+s.substring(20);
  if(DirectExtension.parse(later).mapNote!=255)throw new AssertionError("PCM-only chunk sentinel rejected");
  try{DirectExtension.parse(later.substring(0,18)+"00"+later.substring(20));throw new AssertionError("PCM-only chunk missing FF accepted");}catch(IllegalArgumentException expected){}
  byte[] pcm=new byte[4096];pcm[0]=(byte)0x80;pcm[1]=0;pcm[2]=127;
  byte[] wav=DirectExtension.wav(pcm,8);
  if(wav.length!=4140||wav[0]!='R'||wav[8]!='W'||(wav[44]&255)!=0||(wav[45]&255)!=128||(wav[46]&255)!=255)throw new AssertionError("WAV signed conversion");
  if((wav[24]&255)+((wav[25]&255)<<8)!=5859)throw new AssertionError("DAC derived sample rate");
  final DirectExtension[] engine=new DirectExtension[1];final int[] id={0},length={0},map={0},chunks={0};final boolean[] committed={false};final int[] envelopeConfig={0};final boolean[] envelopeEnabled={false};
  engine[0]=new DirectExtension(new DirectExtension.Wire(){public boolean connected(){return true;}public void send(String p){
   if(p.startsWith("G")){envelopeEnabled[0]=!p.equals("G00000000");envelopeConfig[0]=Integer.parseInt(p.substring(2,7),16);}
   if(p.startsWith("WFF0000")){committed[0]=false;length[0]=0;}
   else if(p.startsWith("WFF01")){committed[0]=true;length[0]=Integer.parseInt(p.substring(5,7),16);}
   else if(p.startsWith("U10"))map[0]=Integer.parseInt(p.substring(5,7),16);
   if(p.equals("C10010011"))id[0]++;
   if(p.startsWith("C1002")||p.equals("C10010011")){
    DirectExtension.Frame state=new DirectExtension.Frame();state.id=id[0];state.chunk=p.equals("C10010011")?0:Integer.parseInt(p.substring(5,7),16);state.flags=2;state.length=4096;state.decimate=8;state.scoreLength=length[0];state.scoreReady=committed[0];state.mapNote=map[0];state.adsrEnabled=envelopeEnabled[0];state.adsrConfig=envelopeConfig[0];state.pcm=new byte[32];engine[0].accept(state);chunks[0]++;
   }
  }});
  engine[0].score("12:20,16:20,-:10");if(!committed[0]||length[0]!=3)throw new AssertionError("score transaction");
  engine[0].keymap(3,12);if(map[0]!=12)throw new AssertionError("map transaction");
  byte[] recording=engine[0].record(t->{});if(recording.length!=4140||chunks[0]!=133)throw new AssertionError("complete 128 chunk recording");
  engine[0].envelope(9,12,160,13);if(!envelopeEnabled[0]||envelopeConfig[0]!=0x9CDA0)throw new AssertionError("ADSR transaction");
  engine[0].resetEnvelope();if(envelopeEnabled[0])throw new AssertionError("ADSR reset transaction");
  engine[0].cancel();try{engine[0].score("12:1");throw new AssertionError("cancel ignored");}catch(java.io.IOException expected){}
  System.out.println("PASS direct A metadata/checksum and signed PCM WAV export");
 }
}
