package cn.myfines.instrument;

/** Phone-only preview; never represented as FPGA generated audio. */
public final class SynthCore {
 private final int rate;
 private final int[] keys={-1,-1,-1,-1};
 private final double[] phases=new double[4],levels=new double[4];
 private final boolean[] held=new boolean[4];
 private int preset;
 private double bend=1,brightness=.2;
 private static final int[] SEMITONES={0,2,4,5,7,9,11,12};
 public SynthCore(int rate){this.rate=rate;}
 public static double frequency(int key){return 523.2511306*Math.pow(2,SEMITONES[key]/12.0);}
 public synchronized void note(int key,boolean down){
  if(key<0||key>=8)return;
  for(int i=0;i<4;i++)if(keys[i]==key){held[i]=down;return;}
  if(!down)return;
  for(int i=0;i<4;i++)if(keys[i]<0){keys[i]=key;held[i]=true;levels[i]=0;return;}
 }
 public synchronized void preset(int p){preset=Math.max(0,Math.min(2,p));}
 public synchronized void expression(double semitones,double color){bend=Math.pow(2,Math.max(-2,Math.min(2,semitones))/12);brightness=Math.max(0,Math.min(1,color));}
 public synchronized void panic(){for(int i=0;i<4;i++){keys[i]=-1;held[i]=false;levels[i]=0;}}
 public synchronized int activeVoices(){int n=0;for(int k:keys)if(k>=0)n++;return n;}
 public synchronized void render(short[] buffer){
  for(int j=0;j<buffer.length;j++){
   double sum=0;
   for(int i=0;i<4;i++)if(keys[i]>=0){
    if(held[i]){if(preset==2){levels[i]=levels[i]==0?.8:levels[i]*.99985;}else levels[i]+=(.65-levels[i])*.004;}
    else levels[i]*=.998;
    if(!held[i]&&levels[i]<.0001){keys[i]=-1;levels[i]=0;continue;}
    phases[i]+=frequency(keys[i])*bend/rate;phases[i]-=Math.floor(phases[i]);
    double p=phases[i],sine=Math.sin(2*Math.PI*p),tri=1-4*Math.abs(p-.5);
    double wave=preset==1?sine:preset==2?2*p-1:tri*(1-brightness)+sine*brightness;
    sum+=wave*levels[i]*.14;
   }
   buffer[j]=(short)Math.round(Math.max(-.9,Math.min(.9,sum))*32767);
  }
 }
}
