"""Execute production effect callback wiring with offline widget/session doubles.
Not Android instrumentation: verifies handler behavior, not physical touch/rendering.
"""
import pathlib, subprocess, sys
root=pathlib.Path(__file__).resolve().parents[1]
source=subprocess.check_output(['git','show',sys.argv[1]+':mobile-companion/src/cn/myfines/instrument/reference/ReferenceActivity.java'],text=True,encoding='utf-8') if len(sys.argv)>1 else (root/'src/cn/myfines/instrument/reference/ReferenceActivity.java').read_text(encoding='utf-8')
start=source.find('  Runnable updateEffects=')
if start<0:start=source.index('  effects.setOnClickListener(')
code=source[start:source.index('  Spinner screen=',start)]
head=r"""
import cn.myfines.instrument.EffectsState;
public class OfflineCallbacks {
 interface Click {void run(Object v);} interface Change {void run(Object b,boolean c);}
 static class Box {boolean checked;Change change;boolean isChecked(){return checked;}void setOnCheckedChangeListener(Change c){change=c;}void click(){checked=!checked;if(change!=null)change.run(this,checked);}}
 static class Button {Click click;void setOnClickListener(Click c){click=c;}void press(){click.run(this);}}
 static class Text {String text;void setText(String s){text=s;}}
 static class Screen {boolean echo;void setEcho(boolean e){echo=e;}}
 static class Session {int mask;boolean isRunning(){return true;}void effects(int m){mask=m;}}
 EffectsState effectState=new EffectsState(0,false);boolean echo,ready;Session session;
 int saved;Box chorus=new Box(),delay=new Box(),reverb=new Box();Button effects=new Button();Text status=new Text();Screen view=new Screen();
 void save(){saved=effectState.mask();} void bind(){
"""
tail=r"""
 }
 static void check(boolean b,String s){if(!b)throw new AssertionError(s);}
 public static void main(String[] args){
  for(int mask:new int[]{2,0,1,3,4,5,6,7}){
   OfflineCallbacks a=new OfflineCallbacks();a.bind();
   if((mask&1)!=0)a.chorus.click();if((mask&2)!=0)a.delay.click();if((mask&4)!=0)a.reverb.click();
   check(a.saved==mask,"offline checkbox selection not saved: "+mask);
   check(a.view.echo==((mask&2)!=0),"main delay display not synced: "+mask);
   a.effects.press();check(a.saved==mask,"offline apply loses selection");
   EffectsState reopened=new EffectsState(a.saved,a.echo);check(reopened.mask()==mask,"reopen loses effects");
   a.session=new Session();a.effects.press();check(a.session.mask==mask,"connected resend wrong");
   a.delay.click();check(a.saved==(mask^2),"delay toggle clears chorus/reverb");
  }
  System.out.println("PASS production callbacks: all8 masks offline select/apply/save/main display/restore and connected resend");
 }
}
"""
out=root/'build/offline-callbacks';out.mkdir(parents=True,exist_ok=True)
java=out/'OfflineCallbacks.java';java.write_text(head+code+tail,encoding='utf-8')
jdk=next(pathlib.Path('E:/gaoyun/tools/mobile-jdk').glob('*/bin/javac.exe')).parent
subprocess.run([str(jdk/'javac.exe'),'-encoding','UTF-8','-d',str(out),str(root/'src/cn/myfines/instrument/EffectsState.java'),str(java)],check=True)
subprocess.run([str(jdk/'java.exe'),'-cp',str(out),'OfflineCallbacks'],check=True)
