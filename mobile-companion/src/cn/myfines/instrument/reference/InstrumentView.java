package cn.myfines.instrument.reference;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RadialGradient;
import android.graphics.RectF;
import android.graphics.Shader;
import android.graphics.Typeface;
import android.os.SystemClock;
import android.util.SparseIntArray;
import android.view.MotionEvent;
import android.view.View;
import java.util.Locale;

/* JADX INFO: loaded from: classes.dex */
public final class InstrumentView extends View {
    private static final int AMBER = -14249;
    private static final int BG_BOTTOM = -16117220;
    private static final int BG_TOP = -16447475;
    private static final int BTN_CONNECT = 1;
    private static final int BTN_ECHO = 9;
    private static final int BTN_HELP = 3;
    private static final int BTN_MUTE = 4;
    private static final int BTN_NONE = 0;
    private static final int BTN_SETTINGS = 2;
    private static final int BTN_TIMBRE_0 = 5;
    private static final int BTN_TIMBRE_1 = 6;
    private static final int BTN_TIMBRE_2 = 7;
    private static final int CARD = -15919067;
    private static final int CARD_EDGE = -14930624;
    private static final int CYAN = -13246256;
    private static final int DIM = -11705993;
    private static final int GREEN = -11803766;
    private static final int INK = -16050396;
    private static final int MUTED = -8218965;
    private static final int RED = -41862;
    private static final int TEXT = -1379329;
    private static final int VIOLET = -6001665;
    private Actions actions;
    private int activeBank;
    private int actualVolume;
    private Shader backgroundShader;
    private Shader blackKeyShader;
    private final RectF[] blackKeys;
    private final Typeface bold;
    private int buttonPointer;
    private RectF connectRect;
    private boolean connecting;
    private Shader cyanGlowShader;
    private final float density;
    private String detailText;
    private boolean echo;
    private RectF echoRect;
    private boolean eightKey;
    private RectF footerBar;
    private RectF gearRect;
    private RectF gestureCard;
    private final boolean[] held;
    private RectF helpRect;
    private String host;
    private RectF keyboard;
    private int lastNonZeroVolume;
    private long lastPressedAt;
    private long lastVolumeSent;
    private final Typeface mono;
    private RectF muteRect;
    private String noticeText;
    private final SparseIntArray padPointers;
    private final Shader[] padShader;
    private final Shader[] padShaderDown;
    private final RectF[] pads;
    private final Paint paint;
    private final Path path;
    private int port;
    private int pressedButton;
    private RectF rail;
    private boolean ready;
    private final Typeface regular;
    private final float scaledDensity;
    private RectF scopeRect;
    private int sliderPointer;
    private RectF sliderTouch;
    private RectF sliderTrack;
    private Protocol.Snapshot snapshot;
    private int statusKind;
    private RectF statusPill;
    private String statusText;
    private final Paint textPaint;
    private int timbre;
    private RectF timbreCard;
    private final RectF[] timbreChips;
    private final RectF tmp;
    private Shader violetGlowShader;
    private int volume;
    private RectF volumeCard;
    private int volumePointer;
    private Shader volumeShader;
    private static final int[] PAD_COLORS = {-15091799, -13983776, -11764235, -8756238, -15554410, -14448439, -12490530, -9678885};
    private static final String[] NOTES_EIGHT = {"C5", "D5", "E5", "F5", "G5", "A5", "B5", "C6"};
    private static final String[] NOTES_LEGACY_LOW = {"C5", "D5", "E5", "G5"};
    private static final String[] NOTES_LEGACY_HIGH = {"C#5", "D#5", "F5", "F#5"};
    private static final String[] TIMBRES = {"电钢琴", "风琴", "弦乐", "Bass"};
    private static final int[] BLACK_AFTER = {0, 1, 3, 4, 5};

    public interface Actions {
        void onConnectClick();

        void onEcho(boolean z);

        void onHelp();

        void onMute();

        void onPadDown(int i);

        void onPadUp(int i);

        void onSettings();

        void onTimbre(int i);

        void onVolumeChanged(int i, boolean z);
    }

    public InstrumentView(Context context) {
        super(context);
        this.paint = new Paint(1);
        this.textPaint = new Paint(1);
        this.path = new Path();
        this.padShader = new Shader[8];
        this.padShaderDown = new Shader[8];
        this.tmp = new RectF();
        this.pads = new RectF[8];
        this.blackKeys = new RectF[5];
        this.timbreChips = new RectF[4];
        this.padPointers = new SparseIntArray();
        this.statusText = "未连接";
        this.detailText = "连接 FPGA-Instrument 热点后开始";
        this.noticeText = "";
        this.host = "192.168.4.1";
        this.port = 9000;
        this.eightKey = true;
        this.volume = 160;
        this.actualVolume = 160;
        this.timbre = 0;
        this.held = new boolean[8];
        this.lastNonZeroVolume = 160;
        this.keyboard = new RectF();
        this.rail = new RectF();
        this.footerBar = new RectF();
        this.statusPill = new RectF();
        this.helpRect = new RectF();
        this.gearRect = new RectF();
        this.volumeCard = new RectF();
        this.sliderTrack = new RectF();
        this.sliderTouch = new RectF();
        this.muteRect = new RectF();
        this.timbreCard = new RectF();
        this.echoRect = new RectF();
        this.gestureCard = new RectF();
        this.connectRect = new RectF();
        this.scopeRect = new RectF();
        this.sliderPointer = -1;
        this.buttonPointer = -1;
        this.pressedButton = 0;
        this.volumePointer = -1;
        this.density = getResources().getDisplayMetrics().density;
        this.scaledDensity = getResources().getDisplayMetrics().scaledDensity;
        this.regular = Typeface.create("sans-serif", 0);
        this.bold = Typeface.create("sans-serif", 1);
        this.mono = Typeface.create("monospace", 0);
        for (int i = 0; i < 8; i++) {
            this.pads[i] = new RectF();
        }
        int i2 = 0;
        while (true) {
            RectF[] rectFArr = this.blackKeys;
            if (i2 >= rectFArr.length) {
                break;
            }
            rectFArr[i2] = new RectF();
            i2++;
        }
        for (int i3 = 0; i3 < 4; i3++) {
            this.timbreChips[i3] = new RectF();
        }
        setFocusable(true);
        setKeepScreenOn(true);
    }

    public void setActions(Actions actions) {
        this.actions = actions;
    }

    public void setHost(String str, int i) {
        this.host = str;
        this.port = i;
        invalidate();
    }

    public String getHost() {
        return this.host;
    }

    public int getPort() {
        return this.port;
    }

    public void setStatus(String str, String str2, int i, boolean z) {
        this.statusText = str;
        this.detailText = str2;
        this.statusKind = i;
        this.connecting = z;
        invalidate();
    }

    public void setMode(boolean z) {
        this.eightKey = z;
        this.ready = true;
        invalidate();
    }

    public void setReady(boolean z) {
        this.ready = z;
        invalidate();
    }

    public void setVolume(int i) {
        int iClamp = clamp(i, 0, 255);
        this.volume = iClamp;
        if (iClamp > 0) {
            this.lastNonZeroVolume = iClamp;
        }
        invalidate();
    }

    public int getVolume() {
        return this.volume;
    }

    public void setTimbre(int i) {
        this.timbre = clamp(i, 0, 3);
        invalidate();
    }

    public void setEcho(boolean z) {
        this.echo = z;
        invalidate();
    }

    public void setNotice(String str) {
        if (str == null) {
            str = "";
        }
        this.noticeText = str;
        invalidate();
    }

    public void setSnapshot(Protocol.Snapshot snapshot) {
        this.snapshot = snapshot;
        if (snapshot != null) {
            this.actualVolume = snapshot.volume;
        }
        invalidate();
    }

    public void setHeld(boolean[] zArr) {
        if (zArr == null || zArr.length != 8) {
            return;
        }
        for (int i = 0; i < 8; i++) {
            this.held[i] = zArr[i];
        }
        for (int size = this.padPointers.size() - 1; size >= 0; size--) {
            int iValueAt = this.padPointers.valueAt(size);
            if (iValueAt < 0 || iValueAt >= 8 || !this.held[iValueAt]) {
                this.padPointers.removeAt(size);
            }
        }
        invalidate();
    }

    public void releaseTouchState() {
        this.padPointers.clear();
        this.sliderPointer = -1;
        this.buttonPointer = -1;
        this.pressedButton = 0;
        this.volumePointer = -1;
        for (int i = 0; i < 8; i++) {
            this.held[i] = false;
        }
        invalidate();
    }

    @Override // android.view.View
    protected void onSizeChanged(int i, int i2, int i3, int i4) {
        super.onSizeChanged(i, i2, i3, i4);
        layout(i, i2);
    }

    private void layout(int i, int i2) {
        float f = i;
        float fMax = Math.max(dp(10.0f), 0.014f * f);
        float f2 = i2;
        float fMin = Math.min(dp(68.0f), 0.19f * f2);
        float fMin2 = Math.min(dp(48.0f), 0.135f * f2);
        float fMax2 = Math.max(dp(7.0f), 0.008f * f);
        float f3 = fMax + fMin;
        float f4 = f2 - fMax;
        float f5 = f4 - fMin2;
        float fMin3 = Math.min(dp(286.0f), 0.28f * f);
        if (f < dp(620.0f)) {
            fMin3 = 0.31f * f;
        }
        float f6 = f - fMax;
        float f7 = (f6 - fMin3) - fMax2;
        this.keyboard.set(fMax, f3, f7, f5);
        this.rail.set(f7 + fMax2, f3, f6, f5);
        this.footerBar.set(fMax, f5 + (fMax2 * 0.35f), f6, f4);
        float fMax3 = Math.max(dp(3.0f), this.keyboard.width() * 0.004f);
        float fMin4 = Math.min(dp(52.0f), this.keyboard.height() * 0.17f);
        float fHeight = (this.keyboard.height() - fMin4) - fMax3;
        float fWidth = (this.keyboard.width() - (7.0f * fMax3)) / 8.0f;
        for (int i3 = 0; i3 < 8; i3++) {
            float f8 = this.keyboard.left + (i3 * (fWidth + fMax3));
            this.pads[i3].set(f8, this.keyboard.top, f8 + fWidth, this.keyboard.top + fHeight);
        }
        for (int i4 = 0; i4 < this.blackKeys.length; i4++) {
            float f9 = this.pads[BLACK_AFTER[i4]].right + (fMax3 / 2.0f);
            float f10 = 0.29f * fWidth;
            this.blackKeys[i4].set(f9 - f10, this.keyboard.top, f9 + f10, this.keyboard.top + (0.62f * fHeight));
        }
        this.scopeRect.set(this.keyboard.left, this.keyboard.bottom - fMin4, this.keyboard.right, this.keyboard.bottom);
        float f11 = fMax + (fMin * 0.52f);
        this.gearRect.set(f6 - dp(30.0f), f11 - dp(14.0f), f6, dp(16.0f) + f11);
        this.helpRect.set(this.gearRect.left - dp(36.0f), this.gearRect.top, this.gearRect.left - dp(6.0f), this.gearRect.bottom);
        this.statusPill.set((this.helpRect.left - dp(8.0f)) - dp(92.0f), f11 - dp(14.0f), this.helpRect.left - dp(8.0f), f11 + dp(16.0f));
        float f12 = this.rail.top;
        float fMax4 = Math.max(dp(5.0f), this.rail.height() * 0.018f);
        float fHeight2 = this.rail.height() * 0.32f;
        float fHeight3 = this.rail.height() * 0.29f;
        this.volumeCard.set(this.rail.left, f12, this.rail.right, fHeight2 + f12);
        float f13 = this.volumeCard.bottom + fMax4;
        this.timbreCard.set(this.rail.left, f13, this.rail.right, fHeight3 + f13);
        this.gestureCard.set(this.rail.left, this.timbreCard.bottom + fMax4, this.rail.right, this.rail.bottom);
        float fDp = dp(12.0f);
        this.sliderTrack.set(this.volumeCard.left + fDp, this.volumeCard.bottom - dp(30.0f), (this.volumeCard.right - fDp) - dp(52.0f), (this.volumeCard.bottom - dp(30.0f)) + dp(8.0f));
        this.sliderTouch.set(this.sliderTrack.left - dp(10.0f), this.sliderTrack.top - dp(18.0f), this.sliderTrack.right + dp(10.0f), this.sliderTrack.bottom + dp(18.0f));
        this.muteRect.set((this.volumeCard.right - fDp) - dp(46.0f), this.volumeCard.bottom - dp(40.0f), this.volumeCard.right - fDp, this.volumeCard.bottom - dp(20.0f));
        float fDp2 = dp(5.0f);
        float fWidth2 = ((this.timbreCard.width() - (fDp * 2.0f)) - (3.0f * fDp2)) / 4.0f;
        float fDp3 = this.timbreCard.top + dp(19.0f);
        for (int i5 = 0; i5 < 4; i5++) {
            float f14 = this.timbreCard.left + fDp + (i5 * (fWidth2 + fDp2));
            this.timbreChips[i5].set(f14, fDp3, f14 + fWidth2, dp(19.0f) + fDp3);
        }
        this.echoRect.set(this.timbreCard.left + fDp, this.timbreCard.bottom - dp(21.0f), this.timbreCard.right - fDp, this.timbreCard.bottom - dp(3.0f));
        this.connectRect.set(f6 - dp(86.0f), this.footerBar.top + dp(8.0f), f6, this.footerBar.bottom - dp(8.0f));
        this.backgroundShader = new LinearGradient(0.0f, 0.0f, 0.0f, f2, -16447475, -16117220, Shader.TileMode.CLAMP);
        this.cyanGlowShader = new RadialGradient(dp(20.0f), dp(10.0f), f * 0.55f, new int[]{573956304, 0}, (float[]) null, Shader.TileMode.CLAMP);
        this.violetGlowShader = new RadialGradient(f * 0.92f, f2 * 0.9f, f * 0.48f, new int[]{581200895, 0}, (float[]) null, Shader.TileMode.CLAMP);
        this.volumeShader = new LinearGradient(this.sliderTrack.left, 0.0f, this.sliderTrack.right, 0.0f, -13246256, -6001665, Shader.TileMode.CLAMP);
        for (int i6 = 0; i6 < 8; i6++) {
            RectF rectF = this.pads[i6];
            this.padShader[i6] = new LinearGradient(rectF.left, rectF.top, rectF.left, rectF.bottom, -656641, -3811608, Shader.TileMode.CLAMP);
            this.padShaderDown[i6] = new LinearGradient(rectF.left, rectF.top, rectF.left, rectF.bottom, -1, -1770753, Shader.TileMode.CLAMP);
        }
        this.blackKeyShader = new LinearGradient(0.0f, this.keyboard.top, 0.0f, this.keyboard.top + (fHeight * 0.62f), -15458002, -16578805, Shader.TileMode.CLAMP);
    }

    @Override // android.view.View
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        drawBackground(canvas);
        drawHeader(canvas);
        drawKeyboard(canvas);
        drawScope(canvas);
        drawRail(canvas);
        drawFooterBar(canvas);
        if (heldAny() || this.connecting) {
            postInvalidateOnAnimation();
        }
    }

    private void drawBackground(Canvas canvas) {
        this.paint.setShader(this.backgroundShader);
        this.paint.setStyle(Paint.Style.FILL);
        canvas.drawRect(0.0f, 0.0f, getWidth(), getHeight(), this.paint);
        this.paint.setShader(null);
        this.paint.setShader(this.cyanGlowShader);
        canvas.drawRect(0.0f, 0.0f, getWidth(), getHeight(), this.paint);
        this.paint.setShader(this.violetGlowShader);
        canvas.drawRect(0.0f, 0.0f, getWidth(), getHeight(), this.paint);
        this.paint.setShader(null);
        this.paint.setColor(234881023);
        this.paint.setStrokeWidth(dp(1.0f));
        float fDp = 0.0f;
        float fDp2 = 0.0f;
        while (fDp2 < getWidth()) {
            canvas.drawLine(fDp2, 0.0f, fDp2, getHeight(), this.paint);
            fDp2 += dp(48.0f);
        }
        while (fDp < getHeight()) {
            canvas.drawLine(0.0f, fDp, getWidth(), fDp, this.paint);
            fDp += dp(48.0f);
        }
    }

    private void drawHeader(Canvas canvas) {
        float fMax = Math.max(dp(12.0f), getWidth() * 0.014f);
        float fMax2 = Math.max(dp(10.0f), getHeight() * 0.02f);
        drawText(canvas, "FPGA乐器", fMax, fMax2 + sp(30.0f), sp(26.0f), -1379329, true, Paint.Align.LEFT);
        drawText(canvas, "TANG PRIMER 20K   ·   8 KEY WIFI PIANO", fMax + dp(2.0f), fMax2 + sp(52.0f), sp(9.5f), -8218965, false, Paint.Align.LEFT);
        drawPill(canvas, this.statusPill, this.statusText, statusColor(), this.statusKind != 0);
        drawIconButton(canvas, this.helpRect, "?");
        drawGear(canvas, this.gearRect);
    }

    private void drawKeyboard(Canvas canvas) {
        for (int i = 0; i < 8; i++) {
            drawWhiteKey(canvas, i);
        }
        for (int i2 = 0; i2 < this.blackKeys.length; i2++) {
            drawBlackKey(canvas, i2);
        }
        if (!this.ready) {
            this.paint.setColor(-1291515376);
            canvas.drawRoundRect(this.keyboard, dp(10.0f), dp(10.0f), this.paint);
            drawText(canvas, this.connecting ? "正在同步 FPGA…" : "未连接 FPGA", this.keyboard.centerX(), this.keyboard.centerY() - dp(4.0f), sp(20.0f), -1379329, true, Paint.Align.CENTER);
            drawText(canvas, this.connecting ? "保持热点连接，等待状态帧" : "点击底部「连接」或齿轮设置地址", this.keyboard.centerX(), this.keyboard.centerY() + dp(22.0f), sp(11.0f), -8218965, false, Paint.Align.CENTER);
        }
    }

    private void drawWhiteKey(Canvas canvas, int i) {
        RectF rectF = this.pads[i];
        boolean z = this.held[i];
        long jUptimeMillis = SystemClock.uptimeMillis();
        float fMin = Math.min(dp(8.0f), rectF.width() * 0.09f);
        if (z) {
            this.paint.setColor(withAlpha(PAD_COLORS[i], (int) ((((float) ((Math.sin((jUptimeMillis - this.lastPressedAt) / 110.0d) * 0.5d) + 0.5d)) * 45.0f) + 55.0f)));
            this.tmp.set(rectF);
            this.tmp.inset(-dp(3.0f), -dp(4.0f));
            canvas.drawRoundRect(this.tmp, dp(3.0f) + fMin, dp(3.0f) + fMin, this.paint);
        }
        this.paint.setShader(z ? this.padShaderDown[i] : this.padShader[i]);
        this.paint.setAlpha(this.ready ? 255 : 150);
        canvas.drawRoundRect(rectF, fMin, fMin, this.paint);
        this.paint.setShader(null);
        this.paint.setColor(855638016);
        canvas.drawRect(rectF.left, rectF.top, rectF.right, dp(2.0f) + rectF.top, this.paint);
        this.paint.setColor(-1426063361);
        canvas.drawRect(dp(3.0f) + rectF.left, dp(3.0f) + rectF.top, rectF.right - dp(3.0f), dp(5.0f) + rectF.top, this.paint);
        this.paint.setStyle(Paint.Style.STROKE);
        this.paint.setStrokeWidth(dp(1.0f));
        this.paint.setColor(z ? -868884272 : 1428173636);
        this.tmp.set(rectF);
        this.tmp.inset(dp(0.5f), dp(0.5f));
        canvas.drawRoundRect(this.tmp, fMin, fMin, this.paint);
        this.paint.setStyle(Paint.Style.FILL);
        RectF rectF2 = new RectF(rectF.left + dp(4.0f), rectF.bottom - dp(7.0f), rectF.right - dp(4.0f), rectF.bottom - dp(2.0f));
        Paint paint = this.paint;
        int[] iArr = PAD_COLORS;
        paint.setColor(z ? lighten(iArr[i], 0.22f) : iArr[i]);
        canvas.drawRoundRect(rectF2, dp(3.0f), dp(3.0f), this.paint);
        drawText(canvas, noteName(i), rectF.centerX(), rectF.bottom - dp(35.0f), Math.min(sp(21.0f), rectF.width() * 0.34f), z ? -16375767 : -16050396, true, Paint.Align.CENTER);
        drawText(canvas, "KEY " + (i + 1), rectF.centerX(), rectF.bottom - dp(17.0f), sp(8.5f), z ? -16098728 : -11639429, false, Paint.Align.CENTER);
        Protocol.Snapshot snapshot = this.snapshot;
        if (snapshot != null && (snapshot.keys & (1 << i)) != 0) {
            this.paint.setColor(PAD_COLORS[i]);
            canvas.drawCircle(rectF.left + dp(9.0f), rectF.top + dp(12.0f), dp(3.2f), this.paint);
            this.paint.setColor(-855638017);
            canvas.drawCircle(rectF.left + dp(9.0f), rectF.top + dp(12.0f), dp(1.2f), this.paint);
        }
    }

    private void drawBlackKey(Canvas canvas, int i) {
        RectF rectF = this.blackKeys[i];
        float fMin = Math.min(dp(5.0f), rectF.width() * 0.12f);
        this.paint.setColor(1711276032);
        this.tmp.set(rectF);
        this.tmp.inset(-dp(2.0f), dp(0.0f));
        this.tmp.offset(dp(1.0f), dp(2.0f));
        canvas.drawRoundRect(this.tmp, dp(2.0f) + fMin, dp(2.0f) + fMin, this.paint);
        this.paint.setShader(this.blackKeyShader);
        this.paint.setAlpha(255);
        canvas.drawRoundRect(rectF, fMin, fMin, this.paint);
        this.paint.setShader(null);
        this.paint.setStyle(Paint.Style.STROKE);
        this.paint.setStrokeWidth(dp(1.0f));
        this.paint.setColor(-1439611044);
        this.tmp.set(rectF);
        this.tmp.inset(dp(0.5f), dp(0.5f));
        canvas.drawRoundRect(this.tmp, fMin, fMin, this.paint);
        this.paint.setStyle(Paint.Style.FILL);
        this.paint.setColor(1157627903);
        canvas.drawRect(rectF.left + dp(3.0f), rectF.top + dp(2.0f), rectF.right - dp(3.0f), rectF.top + dp(3.0f), this.paint);
        this.paint.setColor(-1439309616);
        canvas.drawRect(rectF.left + dp(3.0f), rectF.bottom - dp(2.0f), rectF.right - dp(3.0f), rectF.bottom, this.paint);
    }

    private void drawScope(Canvas canvas) {
        this.paint.setColor(-871754464);
        canvas.drawRoundRect(this.scopeRect, dp(10.0f), dp(10.0f), this.paint);
        this.paint.setStyle(Paint.Style.STROKE);
        this.paint.setStrokeWidth(dp(1.0f));
        this.paint.setColor(-14930624);
        canvas.drawRoundRect(this.scopeRect, dp(10.0f), dp(10.0f), this.paint);
        this.paint.setStyle(Paint.Style.FILL);
        float fDp = this.scopeRect.left + dp(12.0f);
        float fDp2 = this.scopeRect.right - dp(12.0f);
        float fDp3 = this.scopeRect.bottom - dp(13.0f);
        float fDp4 = this.scopeRect.top + dp(17.0f);
        this.paint.setColor(536870911);
        canvas.drawLine(fDp, fDp3, fDp2, fDp3, this.paint);
        Protocol.Snapshot snapshot = this.snapshot;
        int[] iArr = snapshot == null ? null : snapshot.wave;
        this.path.reset();
        for (int i = 0; i < 42; i++) {
            float f = (((fDp2 - fDp) * i) / 31.0f) + fDp;
            float f2 = fDp3 - ((fDp3 - fDp4) * ((iArr == null ? 128 : iArr[i]) / 255.0f));
            if (i == 0) {
                this.path.moveTo(f, f2);
            } else {
                this.path.lineTo(f, f2);
            }
        }
        this.paint.setStyle(Paint.Style.STROKE);
        this.paint.setStrokeWidth(dp(2.2f));
        this.paint.setColor(859168976);
        canvas.drawPath(this.path, this.paint);
        this.paint.setStrokeWidth(dp(1.2f));
        this.paint.setColor(-13246256);
        canvas.drawPath(this.path, this.paint);
        this.paint.setStyle(Paint.Style.FILL);
        drawText(canvas, "FPGA 输出波形 · 32 点", this.scopeRect.left + dp(12.0f), this.scopeRect.top + dp(12.0f), sp(9.0f), -8218965, false, Paint.Align.LEFT);
        if (this.snapshot != null) {
            Locale locale = Locale.ROOT;
            Object[] objArr = new Object[2];
            objArr[0] = Integer.valueOf(this.snapshot.sequence);
            objArr[1] = this.snapshot.gestureAvailable ? "G" : "S";
            drawText(canvas, String.format(locale, "#%04X  %s", objArr), this.scopeRect.right - dp(12.0f), this.scopeRect.top + dp(12.0f), sp(9.0f), -11705993, false, Paint.Align.RIGHT);
        }
    }

    private void drawRail(Canvas canvas) {
        drawCard(canvas, this.volumeCard);
        drawCard(canvas, this.timbreCard);
        drawCard(canvas, this.gestureCard);
        drawVolumeCard(canvas);
        drawTimbreCard(canvas);
        drawGestureCard(canvas);
    }

    private void drawVolumeCard(Canvas canvas) {
        float fDp = dp(12.0f);
        drawText(canvas, "主音量", this.volumeCard.left + fDp, this.volumeCard.top + dp(20.0f), sp(12.0f), -8218965, false, Paint.Align.LEFT);
        drawText(canvas, String.valueOf(this.volume), this.volumeCard.right - fDp, this.volumeCard.top + dp(28.0f), sp(25.0f), -1379329, true, Paint.Align.RIGHT);
        drawText(canvas, "/255", this.volumeCard.right - fDp, this.volumeCard.top + dp(42.0f), sp(9.0f), -11705993, false, Paint.Align.RIGHT);
        drawText(canvas, "FPGA " + this.actualVolume, this.volumeCard.left + fDp, this.volumeCard.top + dp(38.0f), sp(9.5f), this.actualVolume == this.volume ? -11705993 : -14249, false, Paint.Align.LEFT);
        this.paint.setColor(-16314344);
        RectF rectF = this.sliderTrack;
        canvas.drawRoundRect(rectF, rectF.height() / 2.0f, this.sliderTrack.height() / 2.0f, this.paint);
        float f = this.volume / 255.0f;
        this.tmp.set(this.sliderTrack.left, this.sliderTrack.top, this.sliderTrack.left + (this.sliderTrack.width() * f), this.sliderTrack.bottom);
        if (this.tmp.width() > dp(2.0f)) {
            this.paint.setShader(this.volumeShader);
            canvas.drawRoundRect(this.tmp, this.sliderTrack.height() / 2.0f, this.sliderTrack.height() / 2.0f, this.paint);
            this.paint.setShader(null);
        }
        this.paint.setColor(-1048577);
        canvas.drawCircle(this.sliderTrack.left + (this.sliderTrack.width() * f), this.sliderTrack.centerY(), dp(7.0f), this.paint);
        this.paint.setColor(1429594320);
        canvas.drawCircle(this.sliderTrack.left + (this.sliderTrack.width() * f), this.sliderTrack.centerY(), dp(12.0f), this.paint);
        boolean z = this.volume == 0;
        drawSmallButton(canvas, this.muteRect, z ? "恢复" : "静音", z, 4);
    }

    private void drawTimbreCard(Canvas canvas) {
        drawText(canvas, "音色", this.timbreCard.left + dp(12.0f), this.timbreCard.top + dp(18.0f), sp(12.0f), -8218965, false, Paint.Align.LEFT);
        int i = 0;
        while (i < 4) {
            drawChip(canvas, this.timbreChips[i], TIMBRES[i], this.timbre == i);
            i++;
        }
        boolean z = this.echo;
        drawText(canvas, "硬件延时", this.echoRect.left, this.echoRect.centerY() + dp(3.5f), sp(11.0f), -8218965, false, Paint.Align.LEFT);
        RectF rectF = new RectF(this.echoRect.right - dp(42.0f), this.echoRect.centerY() - dp(10.0f), this.echoRect.right, this.echoRect.centerY() + dp(10.0f));
        this.paint.setColor(z ? withAlpha(-13246256, 50) : -16116706);
        canvas.drawRoundRect(rectF, dp(10.0f), dp(10.0f), this.paint);
        this.paint.setColor(z ? -13246256 : -11705993);
        canvas.drawCircle(z ? rectF.right - dp(12.0f) : rectF.left + dp(12.0f), rectF.centerY(), dp(7.0f), this.paint);
        drawText(canvas, z ? "开" : "关", rectF.centerX() - dp(9.0f), rectF.centerY() + dp(4.0f), sp(9.0f), z ? -1379329 : -11705993, false, Paint.Align.CENTER);
    }

    private void drawGestureCard(Canvas canvas) {
        String str;
        int i;
        String str2;
        float fDp = dp(12.0f);
        drawText(canvas, "K230 手势", this.gestureCard.left + fDp, dp(18.0f) + this.gestureCard.top, sp(12.0f), -8218965, false, Paint.Align.LEFT);
        Protocol.Snapshot snapshot = this.snapshot;
        boolean z = snapshot != null && snapshot.gestureAvailable;
        boolean z2 = z && snapshot.gestureActive;
        if (z) {
            str = z2 ? "有效" : "无手势";
        } else {
            str = "等待手势帧";
        }
        String str3 = str;
        float f = this.gestureCard.right - fDp;
        float fDp2 = this.gestureCard.top + dp(18.0f);
        float fSp = sp(10.0f);
        if (z2) {
            i = -11803766;
        } else {
            i = z ? -11705993 : -14249;
        }
        drawText(canvas, str3, f, fDp2, fSp, i, false, Paint.Align.RIGHT);
        float fDp3 = this.gestureCard.left + fDp + dp(34.0f);
        float f2 = this.gestureCard.right - fDp;
        float fDp4 = this.gestureCard.top + dp(33.0f);
        float fDp5 = this.gestureCard.top + dp(51.0f);
        boolean z3 = z;
        drawText(canvas, "捏合", this.gestureCard.left + fDp, fDp4 + dp(4.0f), sp(9.0f), -8218965, false, Paint.Align.LEFT);
        drawText(canvas, "高度", this.gestureCard.left + fDp, fDp5 + dp(4.0f), sp(9.0f), -8218965, false, Paint.Align.LEFT);
        drawBar(canvas, fDp3, fDp4, f2, z2 ? snapshot.pinch / 1000.0f : 0.0f, -13246256);
        drawBar(canvas, fDp3, fDp5, f2, z2 ? snapshot.gestureY / 1000.0f : 0.0f, -6001665);
        if (z3) {
            str2 = z2 ? String.format(Locale.ROOT, "置信度 %d%% · 序号 %d", Integer.valueOf(snapshot.confidence), Integer.valueOf(snapshot.gestureSequence)) : "丢手/低置信度时恢复本地控制";
        } else {
            str2 = "E025 以下固件不提供手势状态";
        }
        drawText(canvas, str2, this.gestureCard.left + fDp, this.gestureCard.bottom - dp(8.0f), sp(8.5f), -11705993, false, Paint.Align.LEFT);
    }

    /* JADX WARN: Code duplicated, block: B:27:0x00cc  */
    /* JADX WARN: Code duplicated, block: B:29:0x00cf  */
    /* JADX WARN: Code duplicated, block: B:30:0x00d2  */
    /* JADX WARN: Code duplicated, block: B:32:0x00d6  */
    /* JADX WARN: Code duplicated, block: B:35:0x0112  */
    /* JADX WARN: Code duplicated, block: B:36:0x0114  */
    /* JADX WARN: Code duplicated, block: B:42:0x012b  */
    /* JADX WARN: Code duplicated, block: B:45:0x0130  */
    /* JADX WARN: Code duplicated, block: B:46:0x0133  */
    private void drawFooterBar(Canvas canvas) {
        drawCard(canvas, footerBar);
        paint.setColor(statusColor());
        canvas.drawCircle(footerBar.left+dp(14),footerBar.centerY()-dp(5),dp(4),paint);
        String mode=ready?(eightKey?"8 键演奏":"4 键兼容"):(connecting?"连接中":"未同步");
        drawText(canvas,statusText+" · "+mode+" · "+host+":"+port,footerBar.left+dp(25),footerBar.top+dp(17),sp(10),statusColor(),true,Paint.Align.LEFT);
        boolean notice=noticeText!=null&&!noticeText.isEmpty();
        String detail=notice?noticeText:(detailText==null?"":detailText);
        drawText(canvas,ellipsize(detail,Math.max(dp(40),connectRect.left-footerBar.left-dp(32))),footerBar.left+dp(25),footerBar.top+dp(33),sp(8.5f),notice?AMBER:DIM,false,Paint.Align.LEFT);
        boolean connected=statusKind==2||statusKind==1;
        drawWideButton(canvas,connectRect,connected?"断开":"连接",connected,1);
    }

    private void drawCard(Canvas canvas, RectF rectF) {
        this.paint.setColor(-15919067);
        canvas.drawRoundRect(rectF, dp(14.0f), dp(14.0f), this.paint);
        this.paint.setStyle(Paint.Style.STROKE);
        this.paint.setStrokeWidth(dp(1.0f));
        this.paint.setColor(-14930624);
        canvas.drawRoundRect(rectF, dp(14.0f), dp(14.0f), this.paint);
        this.paint.setStyle(Paint.Style.FILL);
    }

    private void drawPill(Canvas canvas, RectF rectF, String str, int i, boolean z) {
        this.paint.setColor(z ? withAlpha(i, 34) : -15721690);
        canvas.drawRoundRect(rectF, rectF.height() / 2.0f, rectF.height() / 2.0f, this.paint);
        this.paint.setColor(i);
        canvas.drawCircle(rectF.left + dp(12.0f), rectF.centerY(), dp(4.0f), this.paint);
        drawText(canvas, str, rectF.left + dp(22.0f), dp(4.0f) + rectF.centerY(), sp(10.0f), z ? i : -8218965, true, Paint.Align.LEFT);
    }

    private void drawIconButton(Canvas canvas, RectF rectF, String str) {
        this.paint.setColor(-15721690);
        canvas.drawRoundRect(rectF, dp(10.0f), dp(10.0f), this.paint);
        this.paint.setStyle(Paint.Style.STROKE);
        this.paint.setStrokeWidth(dp(1.0f));
        this.paint.setColor(-14930624);
        canvas.drawRoundRect(rectF, dp(10.0f), dp(10.0f), this.paint);
        this.paint.setStyle(Paint.Style.FILL);
        drawText(canvas, str, rectF.centerX(), rectF.centerY() + dp(5.0f), sp(14.0f), -8218965, true, Paint.Align.CENTER);
    }

    private void drawGear(Canvas canvas, RectF rectF) {
        this.paint.setColor(-15721690);
        canvas.drawRoundRect(rectF, dp(10.0f), dp(10.0f), this.paint);
        float fCenterX = rectF.centerX();
        float fCenterY = rectF.centerY();
        float fMin = Math.min(rectF.width(), rectF.height()) * 0.27f;
        this.paint.setStyle(Paint.Style.STROKE);
        this.paint.setStrokeWidth(dp(1.6f));
        this.paint.setColor(-8218965);
        canvas.drawCircle(fCenterX, fCenterY, fMin, this.paint);
        for (int i = 0; i < 8; i++) {
            double d = (((double) i) * 3.141592653589793d) / 4.0d;
            canvas.drawLine(fCenterX + (((float) Math.cos(d)) * (dp(2.0f) + fMin)), fCenterY + (((float) Math.sin(d)) * (dp(2.0f) + fMin)), fCenterX + (((float) Math.cos(d)) * (dp(5.0f) + fMin)), fCenterY + (((float) Math.sin(d)) * (dp(5.0f) + fMin)), this.paint);
        }
        this.paint.setStyle(Paint.Style.FILL);
    }

    private void drawChip(Canvas canvas, RectF rectF, String str, boolean z) {
        this.paint.setColor(z ? withAlpha(-13246256, 45) : -16116706);
        canvas.drawRoundRect(rectF, dp(9.0f), dp(9.0f), this.paint);
        this.paint.setStyle(Paint.Style.STROKE);
        this.paint.setStrokeWidth(dp(1.0f));
        this.paint.setColor(z ? -13246256 : -14930624);
        canvas.drawRoundRect(rectF, dp(9.0f), dp(9.0f), this.paint);
        this.paint.setStyle(Paint.Style.FILL);
        drawText(canvas, str, rectF.centerX(), rectF.centerY() + dp(4.0f), sp(10.0f), z ? -13246256 : -8218965, z, Paint.Align.CENTER);
    }

    private void drawSmallButton(Canvas canvas, RectF rectF, String str, boolean z, int i) {
        this.paint.setColor(z ? withAlpha(-14249, 40) : -16116706);
        canvas.drawRoundRect(rectF, dp(8.0f), dp(8.0f), this.paint);
        drawText(canvas, str, rectF.centerX(), rectF.centerY() + dp(4.0f), sp(9.0f), z ? -14249 : -8218965, true, Paint.Align.CENTER);
    }

    private void drawWideButton(Canvas canvas, RectF rectF, String str, boolean z, int i) {
        this.paint.setColor(z ? withAlpha(-13246256, 30) : withAlpha(-6001665, 22));
        canvas.drawRoundRect(rectF, dp(9.0f), dp(9.0f), this.paint);
        this.paint.setStyle(Paint.Style.STROKE);
        this.paint.setStrokeWidth(dp(1.0f));
        this.paint.setColor(z ? withAlpha(-13246256, 130) : withAlpha(-6001665, 110));
        canvas.drawRoundRect(rectF, dp(9.0f), dp(9.0f), this.paint);
        this.paint.setStyle(Paint.Style.FILL);
        drawText(canvas, str, rectF.centerX(), rectF.centerY() + dp(4.0f), sp(10.0f), z ? -13246256 : -6001665, true, Paint.Align.CENTER);
    }

    private void drawBar(Canvas canvas, float f, float f2, float f3, float f4, int i) {
        float fDp = dp(6.0f);
        this.paint.setColor(-16314344);
        float f5 = f2 + fDp;
        float f6 = fDp / 2.0f;
        canvas.drawRoundRect(new RectF(f, f2, f3, f5), f6, f6, this.paint);
        float fClamp = ((f3 - f) * clamp(f4, 0.0f, 1.0f)) + f;
        if (fClamp > dp(2.0f) + f) {
            this.paint.setColor(i);
            canvas.drawRoundRect(new RectF(f, f2, fClamp, f5), f6, f6, this.paint);
        }
    }

    private void drawText(Canvas canvas, String str, float f, float f2, float f3, int i, boolean z, Paint.Align align) {
        this.textPaint.setTextSize(f3);
        this.textPaint.setTypeface(z ? this.bold : this.regular);
        this.textPaint.setColor(i);
        this.textPaint.setTextAlign(align);
        canvas.drawText(str, f, f2, this.textPaint);
    }

    private String noteName(int i) {
        int note=(snapshot==null?0:snapshot.page)*8+i;
        String[] names={"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"};
        return names[note%12]+(3+note/12);
    }

    private int statusColor() {
        switch (this.statusKind) {
            case 1:
                return -14249;
            case 2:
                return -11803766;
            case 3:
                return -41862;
            default:
                return -11705993;
        }
    }

    private String ellipsize(String str, float f) {
        this.textPaint.setTextSize(sp(8.5f));
        this.textPaint.setTypeface(this.regular);
        if (this.textPaint.measureText(str) <= f) {
            return str;
        }
        int length = str.length();
        while (length > 0 && this.textPaint.measureText(str.substring(0, length) + "…") > f) {
            length--;
        }
        return str.substring(0, length) + "…";
    }

    private boolean heldAny() {
        for (boolean z : this.held) {
            if (z) {
                return true;
            }
        }
        return false;
    }

    @Override // android.view.View
    public boolean onTouchEvent(MotionEvent motionEvent) {
        switch (motionEvent.getActionMasked()) {
            case 0:
                int pointerId = motionEvent.getPointerId(0);
                float x = motionEvent.getX();
                float y = motionEvent.getY();
                int iButtonAt = buttonAt(x, y);
                if (iButtonAt != 0) {
                    this.pressedButton = iButtonAt;
                    this.buttonPointer = pointerId;
                    invalidate();
                } else if (this.sliderTouch.contains(x, y)) {
                    this.sliderPointer = pointerId;
                    this.volumePointer = pointerId;
                    updateVolumeFromX(x, false);
                    this.lastPressedAt = SystemClock.uptimeMillis();
                } else {
                    int iPadAt = padAt(x, y);
                    if (iPadAt >= 0) {
                        this.padPointers.put(pointerId, iPadAt);
                        this.lastPressedAt = SystemClock.uptimeMillis();
                        Actions actions = this.actions;
                        if (actions != null) {
                            actions.onPadDown(iPadAt);
                        }
                        invalidate();
                    }
                }
                break;
            case 1:
                int pointerId2 = motionEvent.getPointerId(0);
                releasePadPointer(pointerId2);
                if (pointerId2 == this.sliderPointer) {
                    commitVolume();
                }
                if (pointerId2 == this.buttonPointer) {
                    int i = this.pressedButton;
                    this.pressedButton = 0;
                    this.buttonPointer = -1;
                    if (i != 0 && i == buttonAt(motionEvent.getX(), motionEvent.getY())) {
                        performClick();
                        performButton(i);
                    }
                }
                invalidate();
                break;
            case 2:
                for (int i2 = 0; i2 < motionEvent.getPointerCount(); i2++) {
                    int pointerId3 = motionEvent.getPointerId(i2);
                    float x2 = motionEvent.getX(i2);
                    float y2 = motionEvent.getY(i2);
                    if (pointerId3 == this.sliderPointer) {
                        updateVolumeFromX(x2, false);
                    }
                    int iIndexOfKey = this.padPointers.indexOfKey(pointerId3);
                    if (iIndexOfKey >= 0) {
                        int iValueAt = this.padPointers.valueAt(iIndexOfKey);
                        int iPadAt2 = padAt(x2, y2);
                        if (iPadAt2 >= 0 && iPadAt2 != iValueAt) {
                            Actions actions2 = this.actions;
                            if (actions2 != null) {
                                actions2.onPadUp(iValueAt);
                                this.actions.onPadDown(iPadAt2);
                            }
                            this.padPointers.put(pointerId3, iPadAt2);
                        }
                    }
                }
                break;
            case 3:
                for (int i3 = 0; i3 < this.padPointers.size(); i3++) {
                    int iValueAt2 = this.padPointers.valueAt(i3);
                    Actions actions3 = this.actions;
                    if (actions3 != null) {
                        actions3.onPadUp(iValueAt2);
                    }
                }
                this.padPointers.clear();
                this.sliderPointer = -1;
                this.buttonPointer = -1;
                this.pressedButton = 0;
                invalidate();
                break;
            case 5:
                int actionIndex = motionEvent.getActionIndex();
                int pointerId4 = motionEvent.getPointerId(actionIndex);
                int iPadAt3 = padAt(motionEvent.getX(actionIndex), motionEvent.getY(actionIndex));
                if (iPadAt3 >= 0) {
                    this.padPointers.put(pointerId4, iPadAt3);
                    this.lastPressedAt = SystemClock.uptimeMillis();
                    Actions actions4 = this.actions;
                    if (actions4 != null) {
                        actions4.onPadDown(iPadAt3);
                    }
                    invalidate();
                }
                break;
            case 6:
                int pointerId5 = motionEvent.getPointerId(motionEvent.getActionIndex());
                releasePadPointer(pointerId5);
                if (pointerId5 == this.sliderPointer) {
                    commitVolume();
                }
                if (pointerId5 == this.buttonPointer) {
                    this.buttonPointer = -1;
                    this.pressedButton = 0;
                }
                invalidate();
                break;
        }
        return true;
    }

    private void releasePadPointer(int i) {
        int iIndexOfKey = this.padPointers.indexOfKey(i);
        if (iIndexOfKey >= 0) {
            int iValueAt = this.padPointers.valueAt(iIndexOfKey);
            this.padPointers.removeAt(iIndexOfKey);
            Actions actions = this.actions;
            if (actions != null && this.padPointers.indexOfValue(iValueAt)<0) {
                actions.onPadUp(iValueAt);
            }
        }
    }

    private void updateVolumeFromX(float f, boolean z) {
        int iRound = Math.round(clamp((f - this.sliderTrack.left) / Math.max(1.0f, this.sliderTrack.width()), 0.0f, 1.0f) * 255.0f);
        if (iRound != this.volume) {
            this.volume = iRound;
            if (iRound > 0) {
                this.lastNonZeroVolume = iRound;
            }
            long jUptimeMillis = SystemClock.uptimeMillis();
            if (z || jUptimeMillis - this.lastVolumeSent >= 40) {
                this.lastVolumeSent = jUptimeMillis;
                Actions actions = this.actions;
                if (actions != null) {
                    actions.onVolumeChanged(iRound, z);
                }
            }
            invalidate();
        }
    }

    private void commitVolume() {
        this.sliderPointer = -1;
        this.volumePointer = -1;
        Actions actions = this.actions;
        if (actions != null) {
            actions.onVolumeChanged(this.volume, true);
        }
    }

    private int buttonAt(float f, float f2) {
        if (this.helpRect.contains(f, f2)) {
            return 3;
        }
        if (this.gearRect.contains(f, f2)) {
            return 2;
        }
        if (this.muteRect.contains(f, f2)) {
            return 4;
        }
        for (int i = 0; i < 4; i++) {
            if (this.timbreChips[i].contains(f, f2)) {
                return i + 5;
            }
        }
        if (this.echoRect.contains(f, f2)) {
            return 9;
        }
        if (!this.connectRect.contains(f, f2)) {
            return 0;
        }
        return 1;
    }

    private int padAt(float f, float f2) {
        for (int i = 0; i < 8; i++) {
            if (this.pads[i].contains(f, f2)) {
                return i;
            }
        }
        if (this.pads[0].top <= f2 && f2 <= this.pads[0].bottom && this.pads[0].left <= f && f <= this.pads[7].right) {
            float f3 = Float.MAX_VALUE;
            int i2 = 0;
            for (int i3 = 0; i3 < 8; i3++) {
                float fAbs = Math.abs(f - this.pads[i3].centerX());
                if (fAbs < f3) {
                    i2 = i3;
                    f3 = fAbs;
                }
            }
            return i2;
        }
        return -1;
    }

    private void performButton(int i) {
        Actions actions = this.actions;
        if (actions == null) { return; }
        switch (i) {
            case 1:
                actions.onConnectClick();
                break;
            case 2:
                actions.onSettings();
                break;
            case 3:
                actions.onHelp();
                break;
            case 4:
                int i2 = this.volume;
                if (i2 == 0) {
                    int i3 = this.lastNonZeroVolume;
                    this.volume = i3;
                    actions.onVolumeChanged(i3, true);
                } else {
                    this.lastNonZeroVolume = i2;
                    this.volume = 0;
                    actions.onMute();
                }
                invalidate();
                break;
            case 5:
            case 6:
            case 7:
            case 8:
                int i4 = i - 5;
                this.timbre = i4;
                actions.onTimbre(i4);
                invalidate();
                break;
            case 9:
                boolean z = !this.echo;
                this.echo = z;
                actions.onEcho(z);
                invalidate();
                break;
        }
    }

    private float dp(float f) {
        return f * this.density;
    }

    private float sp(float f) {
        return f * this.scaledDensity;
    }

    private static int clamp(int i, int i2, int i3) {
        return i < i2 ? i2 : Math.min(i, i3);
    }

    private static float clamp(float f, float f2, float f3) {
        return f < f2 ? f2 : Math.min(f, f3);
    }

    private static int withAlpha(int i, int i2) {
        return (i & 16777215) | ((i2 & 255) << 24);
    }

    private static int lighten(int i, float f) {
        return Color.rgb(clamp((int) (Color.red(i) + ((255 - Color.red(i)) * f)), 0, 255), clamp((int) (Color.green(i) + ((255 - Color.green(i)) * f)), 0, 255), clamp((int) (Color.blue(i) + ((255 - Color.blue(i)) * f)), 0, 255));
    }

    private static int darken(int i, float f) {
        float f2 = 1.0f - f;
        return Color.rgb(clamp((int) (Color.red(i) * f2), 0, 255), clamp((int) (Color.green(i) * f2), 0, 255), clamp((int) (Color.blue(i) * f2), 0, 255));
    }
}
