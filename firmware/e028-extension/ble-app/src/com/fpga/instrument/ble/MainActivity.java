package com.fpga.instrument.ble;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothManager;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.location.LocationManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.text.TextUtils;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.SeekBar;
import android.widget.TextView;

import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;

/**
 * Single-screen BLE companion for the E027/E028 FPGA instrument.
 *
 * <p>Everything is plain Android framework code: no AndroidX, no Gradle, no
 * external libraries. The screen has a device list page and a performance
 * page with eight multi-touch keys, volume, timbre, FX, page, song, latch and
 * the 32-note stress mask.</p>
 */
public final class MainActivity extends Activity implements BleController.Listener {

    private static final int REQ_PERMISSIONS = 10;
    private static final int REQ_ENABLE_BT = 11;
    private static final int ACTION_NONE = 0;
    private static final int ACTION_SCAN = 1;
    private static final int ACTION_CONNECT = 2;

    private static final int BG = Color.rgb(10, 12, 15);
    private static final int PANEL = Color.rgb(20, 25, 32);
    private static final int PANEL_HI = Color.rgb(32, 40, 50);
    private static final int TEXT = Color.rgb(232, 239, 246);
    private static final int MUTED = Color.rgb(139, 152, 165);
    private static final int ACCENT = Color.rgb(61, 220, 151);
    private static final int ACCENT_DARK = Color.rgb(6, 40, 28);
    private static final int AMBER = Color.rgb(242, 184, 75);
    private static final int DANGER = Color.rgb(255, 92, 92);
    private static final int BLUE = Color.rgb(99, 169, 255);

    private final Handler ui = new Handler(Looper.getMainLooper());
    private final Map<String, DeviceRow> deviceRows = new LinkedHashMap<>();

    private BleController ble;
    private BluetoothAdapter adapter;

    private TextView stateChip;
    private TextView detailText;
    private TextView noticeText;
    private TextView scanInfo;
    private TextView lastText;
    private TextView rxText;
    private TextView volumeValue;
    private TextView keepaliveText;
    private Button scanButton;
    private Button connectButton;
    private LinearLayout performPanel;
    private LinearLayout devicesPanel;
    private LinearLayout deviceList;
    private LinearLayout controlsBox;
    private PianoView piano;
    private SeekBar volumeBar;

    private final Button[] timbreButtons = new Button[4];
    private final Button[] fxButtons = new Button[3];
    private final Button[] pageButtons = new Button[4];
    private Button songButton;
    private Button latchButton;
    private Button stressButton;
    private Button moreButton;

    private BleController.BleDevice selected;
    private BleController.BleDevice pendingConnect;

    private int pendingAction = ACTION_NONE;
    private boolean controlsReady;
    private boolean performVisible = true;

    private int volume = 160;
    private int timbre = 0;
    private int page = 0;
    private boolean chorus;
    private boolean delayFx;
    private boolean reverb;
    private boolean song;
    private boolean latch;
    private boolean stress;
    private boolean demo;
    private int stressToken;
    private int bend = Protocol.BEND_CENTRE;
    private int vibrato = 0;
    private int brightness = 128;
    private int screen = 0;

    private final Runnable volumeSend = new Runnable() {
        @Override
        public void run() {
            if (ble != null) {
                ble.send(Protocol.volume(volume));
            }
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Window window = getWindow();
        window.setStatusBarColor(BG);
        window.setNavigationBarColor(BG);
        window.setBackgroundDrawable(new GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM, new int[]{BG, BG}));

        BluetoothManager manager = (BluetoothManager) getSystemService(Context.BLUETOOTH_SERVICE);
        adapter = manager == null ? null : manager.getAdapter();
        ble = new BleController(this, this);

        setContentView(buildRoot());
        updateState(adapter == null ? BleController.STATE_ERROR : BleController.STATE_IDLE,
                adapter == null ? "Bluetooth LE not supported on this device"
                        : "Idle - tap SCAN to find a BLE-UART module");
        noticeText.setText(adapter == null
                ? "This phone does not expose a Bluetooth adapter."
                : "HM-10 / JDY-31 (FFE0) and Nordic UART (NUS) are supported.");
        if (adapter == null) {
            noticeText.setTextColor(DANGER);
        }
        if (adapter != null && !hasBlePermissions()) {
            requestBlePermissions(ACTION_NONE);
        }
    }

    @Override
    protected void onDestroy() {
        if (ble != null) {
            ble.shutdown();
        }
        ui.removeCallbacksAndMessages(null);
        super.onDestroy();
    }

    @Override
    public void onBackPressed() {
        if (!performVisible) {
            showPerform();
            return;
        }
        super.onBackPressed();
    }

    // ------------------------------------------------------------------
    // UI construction
    // ------------------------------------------------------------------

    private View buildRoot() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(BG);
        root.setPadding(dp(10), dp(6), dp(10), dp(4));

        root.addView(buildHeader(), new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        FrameLayout content = new FrameLayout(this);
        root.addView(content, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));

        performPanel = buildPerformPanel();
        content.addView(performPanel, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        devicesPanel = buildDevicesPanel();
        content.addView(devicesPanel, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        devicesPanel.setVisibility(View.GONE);

        LinearLayout footer = new LinearLayout(this);
        footer.setOrientation(LinearLayout.HORIZONTAL);
        footer.setGravity(Gravity.CENTER_VERTICAL);
        footer.setPadding(0, dp(2), 0, 0);
        lastText = monoText("LAST  --", 9, MUTED);
        lastText.setSingleLine(true);
        lastText.setEllipsize(TextUtils.TruncateAt.END);
        rxText = monoText("RX  --", 9, MUTED);
        rxText.setSingleLine(true);
        rxText.setEllipsize(TextUtils.TruncateAt.END);
        rxText.setGravity(Gravity.END);
        footer.addView(lastText, new LinearLayout.LayoutParams(0,
                ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        footer.addView(rxText, new LinearLayout.LayoutParams(0,
                ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        root.addView(footer, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        return root;
    }

    private View buildHeader() {
        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.VERTICAL);

        LinearLayout titleRow = new LinearLayout(this);
        titleRow.setOrientation(LinearLayout.HORIZONTAL);
        titleRow.setGravity(Gravity.CENTER_VERTICAL);
        TextView title = text("FPGA BLE", 18, TEXT, true);
        title.setLetterSpacing(0.08f);
        titleRow.addView(title, new LinearLayout.LayoutParams(0,
                ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        stateChip = text("IDLE", 9, ACCENT_DARK, true);
        stateChip.setGravity(Gravity.CENTER);
        stateChip.setPadding(dp(8), dp(4), dp(8), dp(4));
        stateChip.setBackground(roundRect(MUTED, 4));
        titleRow.addView(stateChip, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        header.addView(titleRow, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        LinearLayout actionRow = new LinearLayout(this);
        actionRow.setOrientation(LinearLayout.HORIZONTAL);
        actionRow.setGravity(Gravity.CENTER_VERTICAL);
        actionRow.setPadding(0, dp(2), 0, 0);
        detailText = text("Idle", 9.5f, MUTED, false);
        detailText.setSingleLine(true);
        detailText.setEllipsize(TextUtils.TruncateAt.END);
        actionRow.addView(detailText, new LinearLayout.LayoutParams(0, dp(32), 1f));

        scanButton = headerButton("SCAN");
        LinearLayout.LayoutParams scanLp = new LinearLayout.LayoutParams(dp(62), dp(32));
        scanLp.setMargins(dp(4), 0, dp(4), 0);
        actionRow.addView(scanButton, scanLp);
        scanButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                onScanPressed();
            }
        });

        connectButton = headerButton("CONNECT");
        actionRow.addView(connectButton, new LinearLayout.LayoutParams(dp(86), dp(32)));
        connectButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                onConnectPressed();
            }
        });
        header.addView(actionRow, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        noticeText = text("", 9, MUTED, false);
        noticeText.setSingleLine(true);
        noticeText.setEllipsize(TextUtils.TruncateAt.END);
        LinearLayout.LayoutParams noticeLp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(16));
        noticeLp.setMargins(0, dp(2), 0, 0);
        header.addView(noticeText, noticeLp);
        return header;
    }

    private LinearLayout buildPerformPanel() {
        LinearLayout panel = new LinearLayout(this);
        panel.setOrientation(LinearLayout.VERTICAL);

        piano = new PianoView(this);
        piano.setMinimumHeight(dp(120));
        piano.setListener(new PianoView.Listener() {
            @Override
            public void onMaskChanged(int mask) {
                if (controlsReady && ble != null) {
                    ble.send(Protocol.keys(mask));
                }
            }
        });
        LinearLayout.LayoutParams pianoLp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f);
        pianoLp.setMargins(0, dp(4), 0, dp(4));
        panel.addView(piano, pianoLp);

        controlsBox = new LinearLayout(this);
        controlsBox.setOrientation(LinearLayout.VERTICAL);
        controlsBox.addView(buildVolumeRow());
        controlsBox.addView(buildTimbreRow());
        controlsBox.addView(buildFxRow());
        controlsBox.addView(buildPageRow());
        controlsBox.addView(buildActionRow());
        controlsBox.addView(buildPanicRow());
        panel.addView(controlsBox, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        return panel;
    }

    private View buildVolumeRow() {
        LinearLayout row = newRow();
        row.addView(sectionLabel("VOL"));
        volumeBar = new SeekBar(this);
        volumeBar.setMax(Protocol.VOLUME_MAX);
        volumeBar.setProgress(volume);
        volumeBar.setProgressTintList(ColorStateList.valueOf(ACCENT));
        volumeBar.setProgressBackgroundTintList(ColorStateList.valueOf(PANEL_HI));
        volumeBar.setThumbTintList(ColorStateList.valueOf(ACCENT));
        volumeBar.setPadding(0, 0, 0, 0);
        row.addView(volumeBar, new LinearLayout.LayoutParams(0, dp(34), 1f));
        volumeValue = monoText(String.valueOf(volume), 10, ACCENT);
        volumeValue.setGravity(Gravity.END);
        row.addView(volumeValue, new LinearLayout.LayoutParams(dp(32), dp(34)));
        volumeBar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                volume = progress;
                volumeValue.setText(String.valueOf(progress));
                if (fromUser) {
                    ui.removeCallbacks(volumeSend);
                    ui.postDelayed(volumeSend, 130L);
                }
            }

            @Override
            public void onStartTrackingTouch(SeekBar seekBar) {
                ui.removeCallbacks(volumeSend);
            }

            @Override
            public void onStopTrackingTouch(SeekBar seekBar) {
                ui.removeCallbacks(volumeSend);
                if (controlsReady && ble != null) {
                    ble.send(Protocol.volume(volume));
                }
            }
        });
        return row;
    }

    private View buildTimbreRow() {
        LinearLayout row = newRow();
        row.addView(sectionLabel("TIMBRE"));
        String[] names = {"EPiano", "Organ", "Strings", "Bass"};
        for (int i = 0; i < names.length; i++) {
            final int value = i;
            Button button = rowButton(names[i]);
            button.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    selectTimbre(value);
                }
            });
            timbreButtons[i] = button;
            row.addView(button, weightLp());
        }
        refreshTimbre();
        return row;
    }

    private View buildFxRow() {
        LinearLayout row = newRow();
        row.addView(sectionLabel("FX"));
        String[] names = {"Chorus", "Delay", "Reverb"};
        for (int i = 0; i < names.length; i++) {
            final int value = i;
            Button button = rowButton(names[i]);
            button.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    toggleFx(value);
                }
            });
            fxButtons[i] = button;
            row.addView(button, weightLp());
        }
        refreshFx();
        return row;
    }

    private View buildPageRow() {
        LinearLayout row = newRow();
        row.addView(sectionLabel("PAGE"));
        for (int i = 0; i < 4; i++) {
            final int value = i;
            Button button = rowButton("P" + i);
            button.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    selectPage(value);
                }
            });
            pageButtons[i] = button;
            row.addView(button, weightLp());
        }
        refreshPage();
        return row;
    }

    private View buildActionRow() {
        LinearLayout row = newRow();
        row.addView(sectionLabel("PLAY"));
        songButton = rowButton("SONG");
        songButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                toggleSong();
            }
        });
        row.addView(songButton, weightLp());

        latchButton = rowButton("LATCH");
        latchButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                toggleLatch();
            }
        });
        row.addView(latchButton, weightLp());

        stressButton = rowButton("STRESS");
        stressButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                toggleStress();
            }
        });
        row.addView(stressButton, weightLp());

        moreButton = rowButton("MORE");
        moreButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                showMoreDialog();
            }
        });
        row.addView(moreButton, weightLp());
        refreshSongLatchStress();
        return row;
    }

    private View buildPanicRow() {
        LinearLayout row = newRow();
        Button allOff = rowButton("ALL NOTES OFF");
        allOff.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9);
        allOff.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                panic();
            }
        });
        row.addView(allOff, new LinearLayout.LayoutParams(0, dp(32), 1f));
        keepaliveText = text("Q00 keepalive every 2 s", 8, MUTED, false);
        keepaliveText.setGravity(Gravity.END);
        LinearLayout.LayoutParams kp = new LinearLayout.LayoutParams(dp(132), dp(32));
        kp.setMargins(dp(6), 0, 0, 0);
        row.addView(keepaliveText, kp);
        return row;
    }

    private LinearLayout buildDevicesPanel() {
        LinearLayout panel = new LinearLayout(this);
        panel.setOrientation(LinearLayout.VERTICAL);
        panel.setPadding(0, dp(6), 0, 0);

        LinearLayout top = new LinearLayout(this);
        top.setOrientation(LinearLayout.HORIZONTAL);
        top.setGravity(Gravity.CENTER_VERTICAL);
        TextView title = text("BLE DEVICES", 12, TEXT, true);
        title.setLetterSpacing(0.06f);
        top.addView(title, new LinearLayout.LayoutParams(0,
                ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        scanInfo = text("No devices yet", 9, MUTED, false);
        top.addView(scanInfo);
        panel.addView(top, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        TextView hint = text("Tap a device to connect. BLE-UART modules usually need no OS pairing.",
                8.5f, MUTED, false);
        hint.setSingleLine(true);
        hint.setEllipsize(TextUtils.TruncateAt.END);
        panel.addView(hint, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        deviceList = new LinearLayout(this);
        deviceList.setOrientation(LinearLayout.VERTICAL);
        scroll.addView(deviceList, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        LinearLayout.LayoutParams scrollLp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f);
        scrollLp.setMargins(0, dp(4), 0, 0);
        panel.addView(scroll, scrollLp);
        return panel;
    }

    private LinearLayout newRow() {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(0, dp(2), 0, dp(2));
        return row;
    }

    private TextView sectionLabel(String value) {
        TextView label = text(value, 7.5f, MUTED, true);
        label.setLetterSpacing(0.08f);
        label.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(dp(46), dp(36));
        label.setLayoutParams(lp);
        return label;
    }

    private Button rowButton(String label) {
        Button button = new Button(this);
        button.setText(label);
        button.setAllCaps(false);
        button.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9);
        button.setTextColor(TEXT);
        button.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL));
        button.setBackground(roundRect(PANEL_HI, 6));
        button.setPadding(dp(2), 0, dp(2), 0);
        button.setMinHeight(0);
        button.setMinimumHeight(0);
        button.setMinWidth(0);
        button.setMinimumWidth(0);
        button.setElevation(0);
        button.setStateListAnimator(null);
        button.setGravity(Gravity.CENTER);
        return button;
    }

    private Button headerButton(String label) {
        Button button = rowButton(label);
        button.setTextSize(TypedValue.COMPLEX_UNIT_SP, 8.5f);
        button.setBackground(roundRect(PANEL, 6));
        return button;
    }

    private LinearLayout.LayoutParams weightLp() {
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, dp(36), 1f);
        lp.setMargins(dp(2), 0, dp(2), 0);
        return lp;
    }

    private TextView text(String value, float sizeSp, int color, boolean bold) {
        TextView view = new TextView(this);
        view.setText(value);
        view.setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp);
        view.setTextColor(color);
        view.setTypeface(Typeface.create("sans-serif", bold ? Typeface.BOLD : Typeface.NORMAL));
        view.setIncludeFontPadding(false);
        return view;
    }

    private TextView monoText(String value, float sizeSp, int color) {
        TextView view = text(value, sizeSp, color, false);
        view.setTypeface(Typeface.MONOSPACE);
        return view;
    }

    private GradientDrawable roundRect(int color, int radiusDp) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(color);
        drawable.setCornerRadius(dp(radiusDp));
        return drawable;
    }

    private int dp(float value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    // ------------------------------------------------------------------
    // User actions
    // ------------------------------------------------------------------

    private void onScanPressed() {
        if (ble == null) {
            return;
        }
        if (ble.isScanning()) {
            ble.stopScan();
            return;
        }
        if (ble.isReady() || ble.isConnecting() || ble.isLinked()) {
            showError("Disconnect first, then scan for another module");
            return;
        }
        if (!hasBlePermissions()) {
            requestBlePermissions(ACTION_SCAN);
            return;
        }
        if (adapter == null) {
            showError("Bluetooth LE is not supported");
            return;
        }
        if (!ble.isBluetoothEnabled()) {
            pendingAction = ACTION_SCAN;
            promptEnableBluetooth();
            return;
        }
        if (!locationServicesOn()) {
            showLocationDialog();
            return;
        }
        if (ble.isConnecting()) {
            showError("A connection attempt is in progress");
            return;
        }
        showDevices();
        startScanNow();
    }

    private void startScanNow() {
        deviceRows.clear();
        deviceList.removeAllViews();
        scanInfo.setText("Scanning...");
        scanInfo.setTextColor(AMBER);
        ble.startScan();
    }

    private void onConnectPressed() {
        if (ble == null) {
            return;
        }
        if (ble.isReady() || ble.isConnecting() || ble.isLinked()) {
            ble.disconnect();
            showPerform();
            return;
        }
        if (!hasBlePermissions()) {
            requestBlePermissions(ACTION_CONNECT);
            return;
        }
        if (adapter == null) {
            showError("Bluetooth LE is not supported");
            return;
        }
        if (!ble.isBluetoothEnabled()) {
            pendingAction = ACTION_CONNECT;
            promptEnableBluetooth();
            return;
        }
        if (selected == null) {
            showDevices();
            if (!deviceRows.isEmpty()) {
                showError("Select a device from the list");
            } else {
                showError("No device selected - tap SCAN");
            }
            return;
        }
        connectTo(selected);
    }

    private void connectTo(BleController.BleDevice device) {
        if (device == null) {
            return;
        }
        if (!hasBlePermissions()) {
            pendingConnect = device;
            requestBlePermissions(ACTION_CONNECT);
            return;
        }
        if (adapter == null || !ble.isBluetoothEnabled()) {
            pendingConnect = device;
            pendingAction = ACTION_CONNECT;
            promptEnableBluetooth();
            return;
        }
        selected = device;
        highlightSelection(device);
        showPerform();
        ble.connect(device);
    }

    private void selectTimbre(int value) {
        timbre = value;
        refreshTimbre();
        if (controlsReady && ble != null) {
            ble.send(Protocol.timbre(value));
        }
    }

    private void toggleFx(int which) {
        if (which == 0) {
            chorus = !chorus;
        } else if (which == 1) {
            delayFx = !delayFx;
        } else {
            reverb = !reverb;
        }
        refreshFx();
        if (controlsReady && ble != null) {
            ble.send(Protocol.fx(Protocol.fxBits(chorus, delayFx, reverb)));
        }
    }

    private void selectPage(int value) {
        if (value == page) {
            return;
        }
        page = value;
        refreshPage();
        if (!controlsReady || ble == null) {
            return;
        }
        piano.clearKeys();
        ble.send(Protocol.keys(0));
        ble.send(Protocol.page(value));
        noticeText.setText("Page " + value + " selected");
        noticeText.setTextColor(MUTED);
    }

    private void toggleSong() {
        song = !song;
        refreshSongLatchStress();
        if (controlsReady && ble != null) {
            ble.send(Protocol.song(song));
            noticeText.setText(song ? "Offline song started (R01)" : "Offline song stopped (R00)");
            noticeText.setTextColor(MUTED);
        }
    }

    private void toggleLatch() {
        latch = !latch;
        refreshSongLatchStress();
        if (controlsReady && ble != null) {
            ble.send(Protocol.latch(latch));
            noticeText.setText(latch ? "Latch on (H01)" : "Latch off (H00)");
            noticeText.setTextColor(MUTED);
        }
    }

    private void toggleStress() {
        if (!controlsReady || ble == null) {
            return;
        }
        if (stress) {
            stopStress("32-note stress mask cleared");
            return;
        }
        stress = true;
        refreshSongLatchStress();
        ble.send(Protocol.mask(Protocol.ALL_VOICES));
        noticeText.setText("MFFFFFFFF sent; auto-clear in 2 s");
        noticeText.setTextColor(AMBER);
        final int token = ++stressToken;
        ui.postDelayed(new Runnable() {
            @Override
            public void run() {
                if (stress && token == stressToken) {
                    stress = false;
                    refreshSongLatchStress();
                    if (ble.isReady()) {
                        ble.send(Protocol.mask(0));
                        noticeText.setText("32-note stress mask cleared (M00000000)");
                        noticeText.setTextColor(MUTED);
                    }
                }
            }
        }, 2000L);
    }

    private void stopStress(String message) {
        stressToken++;
        stress = false;
        refreshSongLatchStress();
        if (ble != null && ble.isReady()) {
            ble.send(Protocol.mask(0));
        }
        noticeText.setText(message);
        noticeText.setTextColor(MUTED);
    }

    private void panic() {
        if (!controlsReady || ble == null) {
            return;
        }
        stressToken++;
        stress = false;
        refreshSongLatchStress();
        piano.clearKeys();
        ble.send(Protocol.keys(0));
        ble.send(Protocol.mask(0));
        noticeText.setText("All notes off (K00, M00000000)");
        noticeText.setTextColor(MUTED);
    }

    // ------------------------------------------------------------------
    // More controls dialog
    // ------------------------------------------------------------------

    private void showMoreDialog() {
        if (!controlsReady || ble == null) {
            return;
        }
        ScrollView scroll = new ScrollView(this);
        scroll.setBackgroundColor(PANEL);
        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setPadding(dp(16), dp(8), dp(16), dp(8));
        box.setBackgroundColor(PANEL);
        scroll.addView(box);

        addDialogHeading(box, "PITCH BEND  B0000..B3FFF");
        final TextView bendValue = monoText(Protocol.bend(bend)
                + (bend == Protocol.BEND_CENTRE ? "  centre" : ""), 10, ACCENT);
        final SeekBar bendBar = addSlider(box, 0, Protocol.BEND_MAX, bend);
        LinearLayout bendRow = new LinearLayout(this);
        bendRow.setOrientation(LinearLayout.HORIZONTAL);
        bendRow.setGravity(Gravity.CENTER_VERTICAL);
        bendRow.addView(bendValue, new LinearLayout.LayoutParams(0,
                ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        Button centre = rowButton("CENTRE");
        centre.setBackground(roundRect(PANEL_HI, 6));
        centre.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                bend = Protocol.BEND_CENTRE;
                bendBar.setProgress(bend);
                bendValue.setText("B2000  centre");
                ble.send(Protocol.bend(bend));
            }
        });
        bendRow.addView(centre, new LinearLayout.LayoutParams(dp(80), dp(28)));
        box.addView(bendRow);
        bendBar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                bend = progress;
                bendValue.setText(Protocol.bend(progress)
                        + (progress == Protocol.BEND_CENTRE ? "  centre" : ""));
            }

            @Override
            public void onStartTrackingTouch(SeekBar seekBar) {
            }

            @Override
            public void onStopTrackingTouch(SeekBar seekBar) {
                ble.send(Protocol.bend(bend));
            }
        });

        addDialogHeading(box, "VIBRATO  X00..XFF");
        final TextView vibratoValue = monoText(Protocol.vibrato(vibrato), 10, ACCENT);
        box.addView(vibratoValue);
        final SeekBar vibratoBar = addSlider(box, 0, 255, vibrato);
        vibratoBar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                vibrato = progress;
                vibratoValue.setText(Protocol.vibrato(progress));
            }

            @Override
            public void onStartTrackingTouch(SeekBar seekBar) {
            }

            @Override
            public void onStopTrackingTouch(SeekBar seekBar) {
                ble.send(Protocol.vibrato(vibrato));
            }
        });

        addDialogHeading(box, "BRIGHTNESS  Y00..YFF");
        final TextView brightnessValue = monoText(Protocol.brightness(brightness), 10, ACCENT);
        box.addView(brightnessValue);
        final SeekBar brightnessBar = addSlider(box, 0, 255, brightness);
        brightnessBar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                brightness = progress;
                brightnessValue.setText(Protocol.brightness(progress));
            }

            @Override
            public void onStartTrackingTouch(SeekBar seekBar) {
            }

            @Override
            public void onStopTrackingTouch(SeekBar seekBar) {
                ble.send(Protocol.brightness(brightness));
            }
        });

        addDialogHeading(box, "OLED SCREEN  S00..S04");
        LinearLayout screenRow = new LinearLayout(this);
        screenRow.setOrientation(LinearLayout.HORIZONTAL);
        final Button[] screenButtons = new Button[5];
        for (int i = 0; i < 5; i++) {
            final int value = i;
            Button button = rowButton(String.valueOf(i));
            screenButtons[i] = button;
            button.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    screen = value;
                    for (int j = 0; j < screenButtons.length; j++) {
                        styleButton(screenButtons[j], j == screen);
                    }
                    ble.send(Protocol.screen(value));
                }
            });
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, dp(34), 1f);
            lp.setMargins(dp(2), dp(2), dp(2), dp(2));
            screenRow.addView(button, lp);
        }
        for (int i = 0; i < screenButtons.length; i++) {
            styleButton(screenButtons[i], i == screen);
        }
        box.addView(screenRow);

        addDialogHeading(box, "32-VOICE DEMO  D00/D01");
        final Button demoButton = rowButton(demo ? "D01 DEMO ON" : "D00 DEMO OFF");
        demoButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                demo = !demo;
                demoButton.setText(demo ? "D01 DEMO ON" : "D00 DEMO OFF");
                styleButton(demoButton, demo);
                ble.send(Protocol.demo(demo));
            }
        });
        styleButton(demoButton, demo);
        box.addView(demoButton, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(38)));

        TextView hint = text("Pitch-bend is sent when you release the slider. "
                + "Vibrato/brightness are sent on release.", 8, MUTED, false);
        LinearLayout.LayoutParams hintLp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        hintLp.setMargins(0, dp(8), 0, 0);
        box.addView(hint, hintLp);

        AlertDialog dialog = new AlertDialog.Builder(this)
                .setTitle("MORE CONTROLS")
                .setView(scroll)
                .setPositiveButton("CLOSE", null)
                .create();
        dialog.show();
    }

    private void addDialogHeading(LinearLayout parent, String label) {
        TextView heading = text(label, 8, MUTED, true);
        heading.setLetterSpacing(0.05f);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        lp.setMargins(0, dp(10), 0, dp(2));
        parent.addView(heading, lp);
    }

    private SeekBar addSlider(LinearLayout parent, int min, int max, int value) {
        SeekBar bar = new SeekBar(this);
        bar.setMax(max - min);
        bar.setProgress(value - min);
        bar.setProgressTintList(ColorStateList.valueOf(ACCENT));
        bar.setProgressBackgroundTintList(ColorStateList.valueOf(PANEL_HI));
        bar.setThumbTintList(ColorStateList.valueOf(ACCENT));
        bar.setPadding(0, 0, 0, 0);
        parent.addView(bar, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(36)));
        return bar;
    }

    private void styleButton(Button button, boolean active) {
        button.setBackground(roundRect(active ? ACCENT : PANEL_HI, 6));
        button.setTextColor(active ? ACCENT_DARK : TEXT);
    }

    // ------------------------------------------------------------------
    // UI state
    // ------------------------------------------------------------------

    private void refreshTimbre() {
        for (int i = 0; i < timbreButtons.length; i++) {
            if (timbreButtons[i] != null) {
                styleButton(timbreButtons[i], i == timbre);
            }
        }
    }

    private void refreshFx() {
        if (fxButtons[0] != null) {
            styleButton(fxButtons[0], chorus);
        }
        if (fxButtons[1] != null) {
            styleButton(fxButtons[1], delayFx);
        }
        if (fxButtons[2] != null) {
            styleButton(fxButtons[2], reverb);
        }
    }

    private void refreshPage() {
        for (int i = 0; i < pageButtons.length; i++) {
            if (pageButtons[i] != null) {
                styleButton(pageButtons[i], i == page);
            }
        }
    }

    private void refreshSongLatchStress() {
        if (songButton != null) {
            songButton.setText(song ? "SONG ON" : "SONG");
            styleButton(songButton, song);
        }
        if (latchButton != null) {
            latchButton.setText(latch ? "LATCH ON" : "LATCH");
            styleButton(latchButton, latch);
        }
        if (stressButton != null) {
            stressButton.setText(stress ? "STRESS ON" : "STRESS");
            styleButton(stressButton, stress);
        }
    }

    private void updateState(int state, String detail) {
        String label;
        int color;
        int textColor;
        switch (state) {
            case BleController.STATE_SCANNING:
                label = "SCAN";
                color = AMBER;
                textColor = Color.rgb(35, 24, 4);
                break;
            case BleController.STATE_CONNECTING:
                label = "LINK";
                color = AMBER;
                textColor = Color.rgb(35, 24, 4);
                break;
            case BleController.STATE_CONNECTED:
                label = "LINK";
                color = BLUE;
                textColor = Color.rgb(6, 20, 38);
                break;
            case BleController.STATE_READY:
                label = "READY";
                color = ACCENT;
                textColor = ACCENT_DARK;
                break;
            case BleController.STATE_ERROR:
                label = "ERROR";
                color = DANGER;
                textColor = Color.WHITE;
                break;
            case BleController.STATE_IDLE:
            default:
                label = "IDLE";
                color = MUTED;
                textColor = ACCENT_DARK;
                break;
        }
        stateChip.setText(label);
        stateChip.setTextColor(textColor);
        stateChip.setBackground(roundRect(color, 4));
        if (detail != null) {
            detailText.setText(detail);
        }
        boolean linkUp = state == BleController.STATE_READY
                || state == BleController.STATE_CONNECTED
                || state == BleController.STATE_CONNECTING;
        connectButton.setText(linkUp ? "DISCONNECT" : "CONNECT");
        scanButton.setText(ble != null && ble.isScanning() ? "STOP" : "SCAN");
        setControlsEnabled(state == BleController.STATE_READY);
    }

    private void setControlsEnabled(boolean enabled) {
        controlsReady = enabled;
        if (piano != null) {
            piano.setEnabled(enabled);
            piano.setAlpha(enabled ? 1f : 0.42f);
            if (!enabled) {
                piano.clearKeys();
            }
        }
        if (controlsBox != null) {
            setEnabledRecursive(controlsBox, enabled);
            controlsBox.setAlpha(enabled ? 1f : 0.42f);
        }
    }

    private void setEnabledRecursive(View view, boolean enabled) {
        view.setEnabled(enabled);
        if (view instanceof ViewGroup) {
            ViewGroup group = (ViewGroup) view;
            for (int i = 0; i < group.getChildCount(); i++) {
                setEnabledRecursive(group.getChildAt(i), enabled);
            }
        }
    }

    private void showDevices() {
        performVisible = false;
        performPanel.setVisibility(View.GONE);
        devicesPanel.setVisibility(View.VISIBLE);
        scanInfo.setText(deviceRows.isEmpty()
                ? "No devices yet - tap SCAN" : deviceRows.size() + " device(s) found");
        scanInfo.setTextColor(deviceRows.isEmpty() ? MUTED : ACCENT);
    }

    private void showPerform() {
        performVisible = true;
        devicesPanel.setVisibility(View.GONE);
        performPanel.setVisibility(View.VISIBLE);
    }

    private void showError(String message) {
        noticeText.setText(message);
        noticeText.setTextColor(DANGER);
    }

    private void addOrUpdateDevice(BleController.BleDevice device) {
        DeviceRow row = deviceRows.get(device.address);
        if (row == null) {
            row = createDeviceRow(device);
            deviceRows.put(device.address, row);
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            lp.setMargins(0, dp(2), 0, dp(4));
            deviceList.addView(row.root, lp);
        }
        row.name.setText(device.displayName());
        row.sub.setText(String.format(Locale.US, "%s   RSSI %d dBm",
                device.address, device.rssi));
        row.tag.setVisibility(device.looksLikeUart() ? View.VISIBLE : View.GONE);
        scanInfo.setText(deviceRows.size() + " device(s) - tap to connect");
        scanInfo.setTextColor(ACCENT);
        if (selected != null && selected.address.equals(device.address)) {
            highlightSelection(selected);
        }
    }

    private DeviceRow createDeviceRow(final BleController.BleDevice device) {
        DeviceRow holder = new DeviceRow();
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.HORIZONTAL);
        root.setGravity(Gravity.CENTER_VERTICAL);
        root.setPadding(dp(10), dp(7), dp(10), dp(7));
        root.setBackground(roundRect(PANEL, 8));
        root.setClickable(true);
        root.setFocusable(true);

        LinearLayout column = new LinearLayout(this);
        column.setOrientation(LinearLayout.VERTICAL);
        holder.name = text(device.displayName(), 12, TEXT, true);
        holder.name.setSingleLine(true);
        holder.name.setEllipsize(TextUtils.TruncateAt.END);
        holder.sub = monoText("", 8, MUTED);
        holder.sub.setSingleLine(true);
        column.addView(holder.name);
        column.addView(holder.sub);
        root.addView(column, new LinearLayout.LayoutParams(0,
                ViewGroup.LayoutParams.WRAP_CONTENT, 1f));

        holder.tag = text("UART", 8, ACCENT, true);
        holder.tag.setPadding(dp(6), dp(3), dp(6), dp(3));
        holder.tag.setBackground(roundRect(PANEL_HI, 4));
        holder.tag.setVisibility(device.looksLikeUart() ? View.VISIBLE : View.GONE);
        root.addView(holder.tag);

        root.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                selected = device;
                highlightSelection(device);
                connectTo(device);
            }
        });
        holder.root = root;
        return holder;
    }

    private void highlightSelection(BleController.BleDevice device) {
        for (Map.Entry<String, DeviceRow> entry : deviceRows.entrySet()) {
            boolean active = device != null && entry.getKey().equals(device.address);
            entry.getValue().root.setBackground(roundRect(active ? ACCENT_DARK : PANEL, 8));
            entry.getValue().name.setTextColor(active ? ACCENT : TEXT);
        }
    }

    // ------------------------------------------------------------------
    // Permissions, Bluetooth and location
    // ------------------------------------------------------------------

    private String[] neededPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return new String[]{
                    Manifest.permission.BLUETOOTH_SCAN,
                    Manifest.permission.BLUETOOTH_CONNECT
            };
        }
        return new String[]{Manifest.permission.ACCESS_FINE_LOCATION};
    }

    private boolean hasBlePermissions() {
        for (String permission : neededPermissions()) {
            if (checkSelfPermission(permission) != PackageManager.PERMISSION_GRANTED) {
                return false;
            }
        }
        return true;
    }

    private void requestBlePermissions(int action) {
        pendingAction = action;
        requestPermissions(neededPermissions(), REQ_PERMISSIONS);
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode != REQ_PERMISSIONS) {
            return;
        }
        boolean granted = grantResults.length > 0;
        for (int result : grantResults) {
            if (result != PackageManager.PERMISSION_GRANTED) {
                granted = false;
            }
        }
        if (granted) {
            int action = pendingAction;
            pendingAction = ACTION_NONE;
            if (action == ACTION_SCAN) {
                onScanPressed();
            } else if (action == ACTION_CONNECT) {
                BleController.BleDevice device = pendingConnect != null ? pendingConnect : selected;
                pendingConnect = null;
                if (device != null) {
                    connectTo(device);
                } else {
                    onConnectPressed();
                }
            }
            return;
        }

        pendingAction = ACTION_NONE;
        pendingConnect = null;
        String message = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
                ? "Nearby devices permission is required for BLE scan/connect."
                : "Location permission is required for BLE scanning on Android 11 and below.";
        showError(message);
        boolean permanentlyDenied = false;
        for (int i = 0; i < permissions.length && i < grantResults.length; i++) {
            if (grantResults[i] != PackageManager.PERMISSION_GRANTED
                    && !shouldShowRequestPermissionRationale(permissions[i])) {
                permanentlyDenied = true;
            }
        }
        if (permanentlyDenied) {
            showSettingsDialog(message);
        }
    }

    private void promptEnableBluetooth() {
        try {
            startActivityForResult(new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE), REQ_ENABLE_BT);
        } catch (SecurityException e) {
            showError("BLUETOOTH_CONNECT permission is required to enable Bluetooth");
        } catch (RuntimeException e) {
            showError("Could not open the Bluetooth enable dialog");
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != REQ_ENABLE_BT) {
            return;
        }
        int action = pendingAction;
        pendingAction = ACTION_NONE;
        if (resultCode != RESULT_OK) {
            showError("Bluetooth was not enabled");
            return;
        }
        if (action == ACTION_SCAN) {
            onScanPressed();
        } else if (action == ACTION_CONNECT) {
            BleController.BleDevice device = pendingConnect != null ? pendingConnect : selected;
            pendingConnect = null;
            if (device != null) {
                connectTo(device);
            } else {
                onConnectPressed();
            }
        }
    }

    private boolean locationServicesOn() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // BLUETOOTH_SCAN is declared with neverForLocation on Android 12+.
            return true;
        }
        LocationManager manager = (LocationManager) getSystemService(Context.LOCATION_SERVICE);
        if (manager == null) {
            return false;
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                return manager.isLocationEnabled();
            }
            return manager.isProviderEnabled(LocationManager.GPS_PROVIDER)
                    || manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER);
        } catch (RuntimeException e) {
            return false;
        }
    }

    private void showLocationDialog() {
        new AlertDialog.Builder(this)
                .setTitle("Location services are off")
                .setMessage("Android 11 and below require system location to be enabled "
                        + "for BLE scan results. This app does not use your location.")
                .setPositiveButton("SETTINGS", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {
                        try {
                            startActivity(new Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS));
                        } catch (RuntimeException ignored) {
                            // Some ROMs do not export the settings activity.
                        }
                    }
                })
                .setNegativeButton("CANCEL", null)
                .show();
    }

    private void showSettingsDialog(String message) {
        new AlertDialog.Builder(this)
                .setTitle("Permission required")
                .setMessage(message + "\n\nOpen app settings and allow the permission, "
                        + "then return and tap SCAN.")
                .setPositiveButton("OPEN SETTINGS", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {
                        Intent intent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:" + getPackageName()));
                        try {
                            startActivity(intent);
                        } catch (RuntimeException ignored) {
                            // Nothing else to open.
                        }
                    }
                })
                .setNegativeButton("CANCEL", null)
                .show();
    }

    // ------------------------------------------------------------------
    // BleController.Listener
    // ------------------------------------------------------------------

    @Override
    public void onScanState(boolean scanning) {
        scanButton.setText(scanning ? "STOP" : "SCAN");
        if (scanning) {
            showDevices();
            scanInfo.setText("Scanning... move closer to the module");
            scanInfo.setTextColor(AMBER);
        } else {
            scanInfo.setText(deviceRows.isEmpty()
                    ? "Scan stopped - no devices" : deviceRows.size() + " device(s) found");
            scanInfo.setTextColor(deviceRows.isEmpty() ? MUTED : ACCENT);
        }
    }

    @Override
    public void onDevice(BleController.BleDevice device) {
        addOrUpdateDevice(device);
    }

    @Override
    public void onState(int state, String detail) {
        updateState(state, detail);
    }

    @Override
    public void onReady(BleController.BleDevice device) {
        selected = device;
        detailText.setText("Connected: " + device.displayName() + "  " + device.address);
        noticeText.setText("Ready. Service: " + (ble == null ? "?" : ble.getTransportName()));
        noticeText.setTextColor(MUTED);
        highlightSelection(device);
        showPerform();
    }

    @Override
    public void onNotice(String message, boolean error) {
        noticeText.setText(message);
        noticeText.setTextColor(error ? DANGER : MUTED);
    }

    @Override
    public void onRx(byte[] data) {
        rxText.setText("RX  " + Protocol.describeRx(data));
        rxText.setTextColor(TEXT);
    }

    @Override
    public void onCommand(String command) {
        lastText.setText("LAST  " + command);
        lastText.setTextColor(ACCENT);
    }

    private static final class DeviceRow {
        LinearLayout root;
        TextView name;
        TextView sub;
        TextView tag;
    }
}
