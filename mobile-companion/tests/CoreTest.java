package cn.myfines.instrument;
public class CoreTest {
 public static void main(String[] args) {
  SynthCore s=new SynthCore(48000);
  short[] b=new short[4800];s.render(b);for(short v:b)if(v!=0)throw new AssertionError("idle");
  for(int i=0;i<8;i++)s.note(i,true);
  if(s.activeVoices()!=4)throw new AssertionError("four voice limit");
  s.render(b);boolean heard=false;for(short v:b){heard|=v!=0;if(Math.abs((int)v)>16000)throw new AssertionError("headroom");}
  if(!heard)throw new AssertionError("silent note");
  s.panic();s.render(b);for(short v:b)if(v!=0)throw new AssertionError("panic");
  s.note(7,true);s.note(7,false);for(int n=0;n<50;n++)s.render(b);
  if(s.activeVoices()!=0)throw new AssertionError("release");
  if(Math.abs(SynthCore.frequency(0)-523.251)>0.1)throw new AssertionError("C5");
  System.out.println("PASS idle, four voices, headroom, panic, release, pitch");
 }
}
