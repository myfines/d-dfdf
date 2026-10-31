package cn.myfines.instrument;

public final class EffectsStateTest {
 public static void main(String[] args) {
  EffectsState legacy=new EffectsState(-1,true);
  if(legacy.mask()!=2)throw new AssertionError("legacy delay migration");
  for(int mask=0;mask<8;mask++){
   EffectsState state=new EffectsState(mask,false);
   if(state.mask()!=mask)throw new AssertionError("restore all three effects");
   state.select((mask&1)!=0,(mask&2)!=0,(mask&4)!=0);
   EffectsState reopened=new EffectsState(state.mask(),state.delay());
   if(reopened.mask()!=mask)throw new AssertionError("dialog reopen/relaunch loses effects");
   reopened.delay(false);
   if(reopened.mask()!=(mask&5))throw new AssertionError("delay off clears other effects");
   reopened.delay(true);
   if(reopened.mask()!=((mask&5)|2))throw new AssertionError("delay on clears other effects");
  }
  EffectsState applied=new EffectsState(0,false);
  applied.select(true,false,true);
  if(applied.mask()!=5||applied.delay())throw new AssertionError("chorus/reverb without delay");
  System.out.println("PASS effects state: all8 masks, saved restore, legacy migration and delay isolation");
 }
}
