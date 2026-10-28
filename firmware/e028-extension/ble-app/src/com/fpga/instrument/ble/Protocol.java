package com.fpga.instrument.ble;

import java.nio.charset.StandardCharsets;
import java.util.Locale;

/**
 * E027/E028 FPGA instrument ASCII command builder.
 *
 * <p>The FPGA command parser accepts upper- or lower-case hex digits, but this
 * class always emits upper case. Every command must be terminated with a
 * single LF (0x0A); carriage returns are ignored by the parser but are not
 * sent by this app.</p>
 *
 * <p>This class deliberately has no Android dependencies so it can be tested
 * on a desktop JVM.</p>
 */
public final class Protocol {

    public static final int VOLUME_MIN = 0;
    public static final int VOLUME_MAX = 255;
    public static final int TIMBRE_MIN = 0;
    public static final int TIMBRE_MAX = 3;
    public static final int PAGE_MIN = 0;
    public static final int PAGE_MAX = 3;
    public static final int BEND_MIN = 0x0000;
    public static final int BEND_CENTRE = 0x2000;   // 8192 decimal
    public static final int BEND_MAX = 0x3FFF;
    public static final int SCREEN_MIN = 0;
    public static final int SCREEN_MAX = 4;

    /** FX bitmap bits used by fx_engine.v: {reverb, delay, chorus}. */
    public static final int FX_CHORUS = 0x01;
    public static final int FX_DELAY = 0x02;
    public static final int FX_REVERB = 0x04;

    public static final String KEEPALIVE = "Q00";
    public static final String RELEASE = "L00";

    public static final int KEY_COUNT = 8;
    public static final int ALL_KEYS = 0xFF;
    public static final int ALL_VOICES = 0xFFFFFFFF;

    private static final char[] HEX = "0123456789ABCDEF".toCharArray();
    private static final String[] NOTE_NAMES = {
            "C5", "D5", "E5", "F5", "G5", "A5", "B5", "C6"
    };

    private Protocol() {
    }

    public static String volume(int value) {
        return "V" + hex(clamp(value, VOLUME_MIN, VOLUME_MAX), 2);
    }

    public static String timbre(int value) {
        return "T" + hex(clamp(value, TIMBRE_MIN, TIMBRE_MAX), 2);
    }

    /** 8-bit key mask; bit j selects key j on the current page. */
    public static String keys(int mask) {
        return "K" + hex(mask & 0xFF, 2);
    }

    public static String page(int value) {
        return "P" + hex(clamp(value, PAGE_MIN, PAGE_MAX), 2);
    }

    /** @param bits combination of FX_CHORUS, FX_DELAY and FX_REVERB. */
    public static String fx(int bits) {
        return "F" + hex(bits & 0x07, 2);
    }

    /** Direct 32-note mask, 8 hex digits. */
    public static String mask(int mask) {
        return "M" + hex(mask, 8);
    }

    /** Pitch bend; 0x2000 (B2000) is the centre position. */
    public static String bend(int value) {
        return "B" + hex(clamp(value, BEND_MIN, BEND_MAX), 4);
    }

    public static String vibrato(int value) {
        return "X" + hex(clamp(value, 0, 255), 2);
    }

    public static String brightness(int value) {
        return "Y" + hex(clamp(value, 0, 255), 2);
    }

    public static String screen(int value) {
        return "S" + hex(clamp(value, SCREEN_MIN, SCREEN_MAX), 2);
    }

    public static String song(boolean on) {
        return "R" + hex(on ? 1 : 0, 2);
    }

    public static String latch(boolean on) {
        return "H" + hex(on ? 1 : 0, 2);
    }

    public static String demo(boolean on) {
        return "D" + hex(on ? 1 : 0, 2);
    }

    /** Legacy E027 FX alias (reverb only); kept for older firmware. */
    public static String legacyEcho(boolean on) {
        return "E" + hex(on ? 1 : 0, 2);
    }

    /** Raw ASCII bytes for one command, including the terminating LF. */
    public static byte[] line(String command) {
        return (command + "\n").getBytes(StandardCharsets.US_ASCII);
    }

    public static String noteName(int keyIndex) {
        if (keyIndex < 0 || keyIndex >= NOTE_NAMES.length) {
            return "?";
        }
        return NOTE_NAMES[keyIndex];
    }

    public static int noteCount() {
        return NOTE_NAMES.length;
    }

    /** Combined FX bitmap from individual toggle states. */
    public static int fxBits(boolean chorus, boolean delay, boolean reverb) {
        int bits = 0;
        if (chorus) {
            bits |= FX_CHORUS;
        }
        if (delay) {
            bits |= FX_DELAY;
        }
        if (reverb) {
            bits |= FX_REVERB;
        }
        return bits;
    }

    /**
     * Names commonly used by transparent BLE-UART modules. Used only to sort
     * and tag scan results; any BLE device can still be selected.
     */
    public static boolean isKnownUartName(String name) {
        if (name == null) {
            return false;
        }
        String n = name.toUpperCase(Locale.US);
        String[] needles = {
                "HM-10", "HM10", "JDY", "BT05", "CC41", "AT-09", "MLT-",
                "UART", "NUS", "BLE-UART", "BLE UART", "E027", "E028",
                "FPGA", "INSTRUMENT"
        };
        for (String needle : needles) {
            if (n.contains(needle)) {
                return true;
            }
        }
        return false;
    }

    /** "48 4D 2D 31 30" style dump, limited to maxBytes. */
    public static String hex(byte[] data, int maxBytes) {
        if (data == null || data.length == 0) {
            return "--";
        }
        int count = Math.min(data.length, maxBytes);
        StringBuilder out = new StringBuilder(count * 3);
        for (int i = 0; i < count; i++) {
            if (i != 0) {
                out.append(' ');
            }
            out.append(HEX[(data[i] >> 4) & 0x0F]);
            out.append(HEX[data[i] & 0x0F]);
        }
        if (data.length > count) {
            out.append(" ...");
        }
        return out.toString();
    }

    /** Printable ASCII preview; non-printable bytes become '.'. */
    public static String ascii(byte[] data, int maxBytes) {
        if (data == null || data.length == 0) {
            return "";
        }
        int count = Math.min(data.length, maxBytes);
        StringBuilder out = new StringBuilder(count);
        for (int i = 0; i < count; i++) {
            int b = data[i] & 0xFF;
            out.append(b >= 32 && b <= 126 ? (char) b : '.');
        }
        return out.toString();
    }

    /** Hex plus a short printable preview for the RX status line. */
    public static String describeRx(byte[] data) {
        if (data == null || data.length == 0) {
            return "--";
        }
        String preview = ascii(data, 12);
        return hex(data, 12) + (preview.isEmpty() ? "" : "  | " + preview);
    }

    private static int clamp(int value, int min, int max) {
        return Math.max(min, Math.min(max, value));
    }

    private static String hex(int value, int digits) {
        char[] out = new char[digits];
        int v = value;
        for (int i = digits - 1; i >= 0; i--) {
            out[i] = HEX[v & 0x0F];
            v >>>= 4;
        }
        return new String(out);
    }
}
