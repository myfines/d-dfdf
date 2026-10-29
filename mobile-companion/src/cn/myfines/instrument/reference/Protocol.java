package cn.myfines.instrument.reference;

import java.util.Locale;

/* JADX INFO: loaded from: classes.dex */
public final class Protocol {
    public static final String DEFAULT_HOST = "192.168.4.1";
    public static final int DEFAULT_PORT = 9000;

    private Protocol() {
    }

    public static final class Snapshot {
        public final int confidence;
        public final boolean echo;
        public final int flags;
        public final boolean gestureActive;
        public final boolean gestureAvailable;
        public final int gestureSequence;
        public final int gestureY;
        public final int keys;
        public final int page;
        public final int pinch;
        public final int sequence;
        public final int timbre;
        public final int volume;
        public final int[] wave;
        public final int x;
        public final int y;

        Snapshot(int i, int i2, int i3, int i4, int i5, int i6, int i7, boolean z, int i8, int[] iArr, boolean z2, boolean z3, int i9, int i10, int i11, int i12) {
            this.sequence = i;
            this.keys = i2;
            this.flags = i3;
            this.x = i4;
            this.y = i5;
            this.volume = i6;
            this.timbre = i7;
            this.echo = z;
            this.page = i8;
            this.wave = iArr;
            this.gestureAvailable = z2;
            this.gestureActive = z3;
            this.gestureSequence = i9;
            this.pinch = i10;
            this.gestureY = i11;
            this.confidence = i12;
        }

        public boolean armed() {
            return (this.flags & 128) != 0;
        }

        public boolean opticalValid() {
            return (this.flags & 64) != 0;
        }

        public boolean controlsValid() {
            return (this.flags & 32) != 0;
        }

        public boolean testMode() {
            return (this.flags & 16) != 0;
        }

        public boolean editMode() {
            return (this.flags & 8) != 0;
        }

        public boolean selectedEcho() {
            return (this.flags & 4) != 0;
        }

        public boolean noteActive() {
            return (this.flags & 2) != 0;
        }

        public boolean remoteActive() {
            return (this.flags & 1) != 0;
        }
    }

    public static Snapshot parse(String str) {
        boolean z;
        int i;
        int i2;
        int i3;
        int i4;
        if (str == null) {
            throw new IllegalArgumentException("状态帧为空");
        }
        String strTrim = str.trim();
        int length = strTrim.length();
        int i5 = 0;
        boolean z2 = length == 95 && strTrim.charAt(0) == 'G';
        if (!z2 && (length != 84 || strTrim.charAt(0) != 'S')) {
            throw new IllegalArgumentException("状态帧长度错误: " + length);
        }
        int iHex = hex(strTrim, 1, 5);
        int iHex2 = hex(strTrim, 5, 7);
        int iHex3 = hex(strTrim, 7, 9);
        int iHex4 = hex(strTrim, 9, 12);
        int iHex5 = hex(strTrim, 12, 15);
        int iHex6 = hex(strTrim, 15, 17);
        int iHex7 = hex(strTrim, 17, 18);
        int iHex8 = hex(strTrim, 18, 19);
        int iHex9 = hex(strTrim, 19, 20);
        if (iHex7 > 3 || iHex8 > 1 || iHex9 > 3) {
            throw new IllegalArgumentException("状态参数越界");
        }
        int[] iArr = new int[32];
        for (int i6 = 32; i5 < i6; i6 = 32) {
            int i7 = i5 * 2;
            iArr[i5] = hex(strTrim, i7 + 20, i7 + 22);
            i5++;
        }
        if (z2) {
            int iHex10 = hex(strTrim, 84, 85);
            if (iHex10 > 1) {
                throw new IllegalArgumentException("手势有效位越界");
            }
            boolean z3 = iHex10 == 1;
            int iHex11 = hex(strTrim, 85, 87);
            int iHex12 = hex(strTrim, 87, 90);
            int iHex13 = hex(strTrim, 90, 93);
            int iHex14 = hex(strTrim, 93, 95);
            if (iHex12 <= 1000 && iHex13 <= 1000 && iHex14 <= 100) {
                i4 = iHex14;
                z = z3;
                i2 = iHex12;
                i3 = iHex13;
                i = iHex11;
            } else {
                throw new IllegalArgumentException("手势数值越界");
            }
        } else {
            z = false;
            i = 0;
            i2 = 0;
            i3 = 0;
            i4 = 0;
        }
        return new Snapshot(iHex, iHex2, iHex3, iHex4, iHex5, iHex6, iHex7, iHex8 == 1, iHex9, iArr, z2, z, i, i2, i3, i4);
    }

    private static int hex(String str, int i, int i2) {
        if (i < 0 || i2 > str.length() || i >= i2) {
            throw new IllegalArgumentException("状态帧截断");
        }
        int i3 = 0;
        while (i < i2) {
            int iDigit = Character.digit(str.charAt(i), 16);
            if (iDigit < 0) {
                throw new IllegalArgumentException("状态帧非十六进制");
            }
            i3 = (i3 << 4) | iDigit;
            i++;
        }
        return i3;
    }

    public static String command(char c, int i) {
        boolean z = true;
        if ((c != 'V' || i < 0 || i > 255) && ((c != 'T' || i < 0 || i > 2) && ((c != 'E' || i < 0 || i > 1) && ((c != 'K' || i < 0 || i > 255) && ((c != 'P' || i < 0 || i > 2) && ((c != 'Q' && c != 'L') || i != 0)))))) {
            z = false;
        }
        if (!z) {
            throw new IllegalArgumentException("命令范围错误: " + c + i);
        }
        return String.format(Locale.ROOT, "%c%02X\n", Character.valueOf(c), Integer.valueOf(i));
    }
}
