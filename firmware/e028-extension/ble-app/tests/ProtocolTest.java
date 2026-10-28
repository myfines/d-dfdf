import com.fpga.instrument.ble.Protocol;

import java.nio.charset.StandardCharsets;
import java.util.Arrays;

/** Desktop-JVM tests for the ASCII command builder (no Android needed). */
public final class ProtocolTest {

    private static int checks;

    public static void main(String[] args) {
        expect("V00", Protocol.volume(0));
        expect("VFF", Protocol.volume(255));
        expect("V7F", Protocol.volume(127));
        expect("VFF", Protocol.volume(999));       // clamped
        expect("V00", Protocol.volume(-3));        // clamped

        expect("T00", Protocol.timbre(0));
        expect("T03", Protocol.timbre(3));
        expect("T03", Protocol.timbre(7));         // clamped

        expect("K00", Protocol.keys(0));
        expect("K01", Protocol.keys(1));
        expect("K81", Protocol.keys(0x81));
        expect("KFF", Protocol.keys(0x1FF));       // masked

        expect("P00", Protocol.page(0));
        expect("P03", Protocol.page(3));

        expect("F00", Protocol.fx(0));
        expect("F01", Protocol.fx(Protocol.FX_CHORUS));
        expect("F02", Protocol.fx(Protocol.FX_DELAY));
        expect("F04", Protocol.fx(Protocol.FX_REVERB));
        expect("F07", Protocol.fx(Protocol.fxBits(true, true, true)));
        expect("F07", Protocol.fx(0xFF));          // masked

        expect("M00000000", Protocol.mask(0));
        expect("MFFFFFFFF", Protocol.mask(Protocol.ALL_VOICES));
        expect("M80000001", Protocol.mask(0x80000001));

        expect("B0000", Protocol.bend(Protocol.BEND_MIN));
        expect("B2000", Protocol.bend(Protocol.BEND_CENTRE));
        expect("B3FFF", Protocol.bend(Protocol.BEND_MAX));
        expect("B3FFF", Protocol.bend(0x7FFF));    // clamped

        expect("X00", Protocol.vibrato(0));
        expect("XFF", Protocol.vibrato(255));
        expect("Y80", Protocol.brightness(128));
        expect("S00", Protocol.screen(0));
        expect("S04", Protocol.screen(4));
        expect("S04", Protocol.screen(9));         // clamped
        expect("R01", Protocol.song(true));
        expect("R00", Protocol.song(false));
        expect("H01", Protocol.latch(true));
        expect("H00", Protocol.latch(false));
        expect("D01", Protocol.demo(true));
        expect("D00", Protocol.demo(false));
        expect("Q00", Protocol.KEEPALIVE);
        expect("L00", Protocol.RELEASE);

        byte[] line = Protocol.line("VFF");
        check(line.length == 4 && line[3] == '\n', "line terminator LF");
        check(Arrays.equals("VFF\n".getBytes(StandardCharsets.US_ASCII), line),
                "ASCII bytes");

        check(Protocol.noteName(0).equals("C5"), "note 0");
        check(Protocol.noteName(7).equals("C6"), "note 7");
        check(Protocol.noteName(9).equals("?"), "note range");

        byte[] rx = new byte[]{0x48, 0x4D, 0x2D, 0x31, 0x30};
        check(Protocol.hex(rx, 16).equals("48 4D 2D 31 30"), "hex dump");
        check(Protocol.ascii(rx, 16).equals("HM-10"), "ascii preview");
        check(Protocol.describeRx(rx).contains("48 4D 2D 31 30"), "describe hex");
        check(Protocol.describeRx(rx).contains("HM-10"), "describe ascii");
        check(Protocol.hex(new byte[0], 16).equals("--"), "empty hex");
        check(Protocol.hex(new byte[]{1, 2, 3}, 2).equals("01 02 ..."), "hex cut");

        check(Protocol.isKnownUartName("HM-10"), "known HM-10");
        check(Protocol.isKnownUartName("JDY-31-SPP"), "known JDY");
        check(Protocol.isKnownUartName("My NUS bridge"), "known NUS");
        check(!Protocol.isKnownUartName("Mi Band 7"), "unknown band");
        check(!Protocol.isKnownUartName(null), "null name");

        System.out.println("ProtocolTest OK (" + checks + " checks)");
    }

    private static void expect(String expected, String actual) {
        check(expected.equals(actual), "expected " + expected + " got " + actual);
    }

    private static void check(boolean condition, String what) {
        checks++;
        if (!condition) {
            throw new AssertionError("FAILED: " + what);
        }
    }
}
