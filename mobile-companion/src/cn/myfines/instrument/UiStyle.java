package cn.myfines.instrument;
import android.app.Activity;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.view.*;
import android.widget.*;
final class UiStyle {
 static final int BG=0xff080f18, CARD=0xff101b26, TEXT=0xffeaf3ff, MUTED=0xff8296ab, ACCENT=0xff4be38a;
 static GradientDrawable panel(int color,int radius){GradientDrawable d=new GradientDrawable();d.setColor(color);d.setCornerRadius(radius);d.setStroke(1,0xff1c2d40);return d;}
 static void apply(Activity a){a.getWindow().setStatusBarColor(BG);a.getWindow().setNavigationBarColor(BG);ViewGroup content=a.findViewById(android.R.id.content);content.setBackgroundColor(BG);walk(content);}
 static void walk(View v){
  if(v instanceof EditText){EditText e=(EditText)v;e.setTextColor(TEXT);e.setHintTextColor(MUTED);e.setPadding(22,18,22,18);e.setBackground(panel(CARD,18));}
  else if(v instanceof Button){TextView t=(TextView)v;t.setTextColor(TEXT);t.setAllCaps(false);t.setTypeface(Typeface.DEFAULT,Typeface.BOLD);t.setPadding(20,14,20,14);v.setBackground(panel(0xff1c2d40,20));}
  else if(v instanceof TextView){((TextView)v).setTextColor(TEXT);}
  if(v instanceof LinearLayout){v.setBackgroundColor(BG);}
  if(v instanceof ViewGroup){ViewGroup g=(ViewGroup)v;for(int i=0;i<g.getChildCount();i++)walk(g.getChildAt(i));}
 }
}
