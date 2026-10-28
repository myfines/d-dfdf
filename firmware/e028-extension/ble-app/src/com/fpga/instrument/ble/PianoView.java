package com.fpga.instrument.ble;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Shader;
import android.util.AttributeSet;
import android.util.SparseIntArray;
import android.view.MotionEvent;
import android.view.View;

/**
 * Eight large multi-touch keys, C5..C6.
 *
 * <p>Each pointer owns at most one key. Sliding a finger onto another key
 * moves that pointer's contribution; lifting it clears that bit. The bitmask
 * is reported only when it actually changes.</p>
 */
public final class PianoView extends View {

    public interface Listener {
        void onMaskChanged(int mask);
    }

    private static final int KEY_COUNT = 8;

    private final Paint fill = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint stroke = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint label = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final RectF rect = new RectF();
    private final SparseIntArray pointerKeys = new SparseIntArray();
    private final float density;
    private final float gap;
    private final float radius;

    private Listener listener;
    private int mask;

    public PianoView(Context context) {
        this(context, null);
    }

    public PianoView(Context context, AttributeSet attrs) {
        super(context, attrs);
        density = getResources().getDisplayMetrics().density;
        gap = 3.0f * density;
        radius = 7.0f * density;
        stroke.setStyle(Paint.Style.STROKE);
        stroke.setStrokeWidth(Math.max(1.0f, density));
        label.setTypeface(android.graphics.Typeface.create("sans-serif", android.graphics.Typeface.NORMAL));
        setContentDescription("Piano keys C5 to C6, eight multi-touch keys");
        setFocusable(true);
        setClickable(true);
    }

    public void setListener(Listener listener) {
        this.listener = listener;
    }

    public int getMask() {
        return mask;
    }

    /** Clear all pressed keys and notify the listener if needed. */
    public void clearKeys() {
        if (pointerKeys.size() == 0 && mask == 0) {
            return;
        }
        pointerKeys.clear();
        updateMask();
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        if (!isEnabled()) {
            return false;
        }
        switch (event.getActionMasked()) {
            case MotionEvent.ACTION_DOWN:
            case MotionEvent.ACTION_POINTER_DOWN: {
                int index = event.getActionIndex();
                int id = event.getPointerId(index);
                int key = keyAt(event.getX(index), event.getY(index));
                if (key >= 0) {
                    pointerKeys.put(id, key);
                    performHapticFeedback(android.view.HapticFeedbackConstants.KEYBOARD_TAP);
                    updateMask();
                }
                break;
            }
            case MotionEvent.ACTION_MOVE: {
                for (int i = 0; i < event.getPointerCount(); i++) {
                    int id = event.getPointerId(i);
                    int key = keyAt(event.getX(i), event.getY(i));
                    int old = pointerKeys.get(id, -1);
                    if (key >= 0 && key != old) {
                        pointerKeys.put(id, key);
                    } else if (key < 0 && old >= 0) {
                        pointerKeys.delete(id);
                    }
                }
                updateMask();
                break;
            }
            case MotionEvent.ACTION_UP:
            case MotionEvent.ACTION_POINTER_UP:
            case MotionEvent.ACTION_CANCEL: {
                if (event.getActionMasked() == MotionEvent.ACTION_CANCEL) {
                    pointerKeys.clear();
                } else {
                    int index = event.getActionIndex();
                    pointerKeys.delete(event.getPointerId(index));
                }
                updateMask();
                break;
            }
            default:
                break;
        }
        return true;
    }

    @Override
    public boolean performClick() {
        super.performClick();
        return true;
    }

    private void updateMask() {
        int next = 0;
        for (int i = 0; i < pointerKeys.size(); i++) {
            int key = pointerKeys.valueAt(i);
            if (key >= 0 && key < KEY_COUNT) {
                next |= 1 << key;
            }
        }
        if (next != mask) {
            mask = next;
            invalidate();
            if (listener != null) {
                listener.onMaskChanged(mask);
            }
        }
    }

    private int keyAt(float x, float y) {
        if (getWidth() <= 0 || getHeight() <= 0) {
            return -1;
        }
        if (y < 0 || y > getHeight() || x < 0 || x >= getWidth()) {
            return -1;
        }
        int key = (int) (x / (getWidth() / (float) KEY_COUNT));
        return Math.max(0, Math.min(KEY_COUNT - 1, key));
    }

    @Override
    protected void onDetachedFromWindow() {
        pointerKeys.clear();
        mask = 0;
        super.onDetachedFromWindow();
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        float width = getWidth();
        float height = getHeight();
        if (width <= 0 || height <= 0) {
            return;
        }
        float keyWidth = width / (float) KEY_COUNT;
        int topOn = Color.rgb(70, 232, 166);
        int bottomOn = Color.rgb(32, 178, 122);
        int topOff = Color.rgb(232, 238, 245);
        int bottomOff = Color.rgb(188, 199, 211);

        for (int i = 0; i < KEY_COUNT; i++) {
            boolean on = (mask & (1 << i)) != 0;
            rect.set(i * keyWidth + gap * 0.5f, 0f,
                    (i + 1) * keyWidth - gap * 0.5f, height);
            fill.setShader(new LinearGradient(0f, 0f, 0f, height,
                    on ? topOn : topOff, on ? bottomOn : bottomOff, Shader.TileMode.CLAMP));
            canvas.drawRoundRect(rect, radius, radius, fill);
            fill.setShader(null);

            stroke.setColor(on ? Color.rgb(155, 255, 214) : Color.rgb(115, 129, 143));
            canvas.drawRoundRect(rect, radius, radius, stroke);

            float cx = rect.centerX();
            label.setTextAlign(Paint.Align.CENTER);
            label.setFakeBoldText(true);
            label.setColor(on ? Color.rgb(6, 40, 28) : Color.rgb(24, 34, 44));
            label.setTextSize(18.0f * density);
            canvas.drawText(Protocol.noteName(i), cx, height * 0.46f, label);

            label.setFakeBoldText(false);
            label.setColor(on ? Color.rgb(12, 66, 47) : Color.rgb(92, 105, 119));
            label.setTextSize(9.0f * density);
            canvas.drawText("K" + i, cx, height * 0.60f, label);
        }
    }
}
