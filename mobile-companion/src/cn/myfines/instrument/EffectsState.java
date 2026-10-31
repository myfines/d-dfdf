package cn.myfines.instrument;

/** Desired effect combination; independent of the aggregate FPGA echo flag. */
public final class EffectsState {
 private int mask;
 public EffectsState(int savedMask,boolean legacyDelay){mask=savedMask>=0&&savedMask<=7?savedMask:legacyDelay?2:0;}
 public int mask(){return mask;}
 public boolean delay(){return (mask&2)!=0;}
 public void select(boolean chorus,boolean delay,boolean reverb){mask=(chorus?1:0)|(delay?2:0)|(reverb?4:0);}
 public void delay(boolean enabled){mask=(mask&5)|(enabled?2:0);}
}
