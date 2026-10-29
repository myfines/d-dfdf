package cn.myfines.instrument;
import android.app.*;
import android.os.Bundle;
import android.content.Intent;
import android.graphics.Typeface;
import android.widget.*;
public final class DashboardActivity extends Activity {
 private LinearLayout root;
 private int dp(int n){return Math.round(n*getResources().getDisplayMetrics().density);}
 private TextView label(String text,int size){TextView t=new TextView(this);t.setText(text);t.setTextSize(size);t.setPadding(0,dp(8),0,dp(8));root.addView(t);return t;}
 private void entry(String title,String detail,Class<?> target){
  Button b=new Button(this);b.setText(title+"\n"+detail);b.setGravity(3|16);b.setTextSize(17);LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-1,dp(96));lp.topMargin=dp(12);root.addView(b,lp);b.setOnClickListener(v->startActivity(new Intent(this,target)));
 }
 @Override public void onCreate(Bundle b){super.onCreate(b);ScrollView scroll=new ScrollView(this);root=new LinearLayout(this);root.setOrientation(1);root.setPadding(dp(22),dp(24),dp(22),dp(24));scroll.addView(root);setContentView(scroll);
  label("TANG PRIMER 20K  /  PERFORMANCE",12);
  TextView title=label("FPGA 乐器",34);title.setTypeface(Typeface.DEFAULT,Typeface.BOLD);
  label("演奏 · 手势 · 波形 · 曲谱",16);
  TextView mode=label("当前固件：ESP 联网模式\nESP 连接手机热点，手机保留正常网络。\n此模式不会广播 FPGA-Instrument 热点。",16);
  entry("公网控制","键位 / 曲谱 / 数字录音回传",CloudActivity.class);
  entry("旧版热点直连","仅适用于广播 FPGA-Instrument 的旧固件",WifiActivity.class);
  entry("本地音频工具","声音预览 / 输入监听",MainActivity.class);
  label("连接检查",20);
  label("① 启动给 ESP 使用的 2.4 GHz 热点。\n② FPGA 冷启动后只启用一次外设。\n③ 公网控制中填写可用的服务器地址和令牌。\n④ 收到实际状态再确认连接成功。",15);
  label("RCFG 只重配 FPGA，不会让 ESP 同步断电重启；异常时按既有方式完整冷启动。",14);
  label("界面与联网模式说明  ·  0.6",12);
  UiStyle.apply(this);mode.setTextColor(UiStyle.ACCENT);
 }
}
