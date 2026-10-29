package cn.myfines.instrument.reference;
import android.content.Context;import android.graphics.Canvas;import java.lang.reflect.Method;
public class ReferenceViewTest {
 public static void main(String[] args)throws Exception {InstrumentView view=new InstrumentView(new Context());view.onSizeChanged(1000,600,0,0);view.onDraw(new Canvas());
  StringBuilder packet=new StringBuilder("G0001FF8101234580313");for(int i=0;i<32;i++)packet.append(String.format("%02X",i*8));packet.append("1FE2EE0FA5F");
  view.setSnapshot(Protocol.parse(packet.toString()));view.setMode(true);view.setStatus("已连接","",2,false);
  for(int tone=0;tone<4;tone++){view.setTimbre(tone);view.onDraw(new Canvas());}
  System.out.println("PASS actual reference View constructor/layout/offline draw/32-point connected draw/four timbres");
 }
}
