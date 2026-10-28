package com.fpga.instrument.ble;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothProfile;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanResult;
import android.bluetooth.le.ScanSettings;
import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import java.util.ArrayDeque;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

/**
 * Small, dependency-free BLE central for the E027/E028 BLE-UART link.
 *
 * <p>Scanning is unfiltered so that any HM-10 / JDY / NUS module can be found.
 * Services are resolved by UUID, the writable characteristic is selected, and
 * notifications are enabled when a CCCD exists. Commands are written one at a
 * time through a small queue so that a BLE stack that accepts only one
 * outstanding operation is not flooded.</p>
 */
public final class BleController {

    public static final int STATE_IDLE = 0;
    public static final int STATE_SCANNING = 1;
    public static final int STATE_CONNECTING = 2;
    public static final int STATE_CONNECTED = 3;
    public static final int STATE_READY = 4;
    public static final int STATE_ERROR = 5;

    public interface Listener {
        void onScanState(boolean scanning);

        void onDevice(BleDevice device);

        void onState(int state, String detail);

        void onReady(BleDevice device);

        void onNotice(String message, boolean error);

        void onRx(byte[] data);

        void onCommand(String command);
    }

    /** IMMUTABLE identity, mutable display fields updated by scan results. */
    public static final class BleDevice {
        public final BluetoothDevice device;
        public final String address;
        public String name;
        public int rssi;

        BleDevice(BluetoothDevice device, String name, int rssi) {
            this.device = device;
            this.address = device.getAddress();
            this.name = name;
            this.rssi = rssi;
        }

        public String displayName() {
            if (name == null || name.trim().isEmpty()) {
                return "Unnamed device";
            }
            return name.trim();
        }

        public boolean looksLikeUart() {
            return Protocol.isKnownUartName(name);
        }
    }

    private static final String TAG = "BleController";

    // HM-10 / JDY-31 / CC41 / AT-09 style transparent UART.
    public static final UUID UUID_HM_SERVICE =
            UUID.fromString("0000ffe0-0000-1000-8000-00805f9b34fb");
    public static final UUID UUID_HM_CHAR =
            UUID.fromString("0000ffe1-0000-1000-8000-00805f9b34fb");

    // Nordic UART Service (NUS).
    public static final UUID UUID_NUS_SERVICE =
            UUID.fromString("6e400001-b5a3-f393-e0a9-e50e24dcca9e");
    public static final UUID UUID_NUS_RX =
            UUID.fromString("6e400002-b5a3-f393-e0a9-e50e24dcca9e");
    public static final UUID UUID_NUS_TX =
            UUID.fromString("6e400003-b5a3-f393-e0a9-e50e24dcca9e");

    private static final UUID UUID_CCCD =
            UUID.fromString("00002902-0000-1000-8000-00805f9b34fb");

    private static final long SCAN_TIMEOUT_MS = 20000L;
    private static final long CONNECT_TIMEOUT_MS = 15000L;
    private static final long KEEPALIVE_INTERVAL_MS = 2000L;
    private static final long WRITE_TIMEOUT_MS = 1500L;
    private static final int MAX_QUEUE = 48;

    private final Context context;
    private final Listener listener;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private final Map<String, BleDevice> seen = new LinkedHashMap<>();
    private final ArrayDeque<Pending> queue = new ArrayDeque<>();

    private BluetoothAdapter adapter;
    private BluetoothLeScanner scanner;
    private BluetoothGatt gatt;
    private BluetoothGattCharacteristic writeChar;
    private BluetoothGattCharacteristic notifyChar;

    private BleDevice active;
    private boolean scanning;
    private boolean connecting;
    private boolean ready;
    private boolean userDisconnect;
    private boolean writing;
    private boolean overflowNotified;
    private int writeSeq;
    private int writeRetries;
    private int writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT;
    private String transportName = "";

    private final Runnable scanTimeout = new Runnable() {
        @Override
        public void run() {
            if (scanning) {
                stopScan();
                listener.onNotice("Scan stopped after 20 s", false);
            }
        }
    };

    private final Runnable connectTimeout = new Runnable() {
        @Override
        public void run() {
            if (!ready && gatt != null) {
                fail("Connection timed out. Move closer and retry.");
            }
        }
    };

    private final Runnable keepalive = new Runnable() {
        @Override
        public void run() {
            if (ready) {
                enqueue(new Pending(Protocol.KEEPALIVE, true));
                handler.postDelayed(this, KEEPALIVE_INTERVAL_MS);
            }
        }
    };

    private final Runnable closeAfterDisconnect = new Runnable() {
        @Override
        public void run() {
            closeGatt();
        }
    };

    private final ScanCallback scanCallback = new ScanCallback() {
        @Override
        public void onScanResult(int callbackType, final ScanResult result) {
            handler.post(new Runnable() {
                @Override
                public void run() {
                    handleScanResult(result);
                }
            });
        }

        @Override
        public void onBatchScanResults(List<ScanResult> results) {
            if (results == null) {
                return;
            }
            for (ScanResult result : results) {
                onScanResult(ScanSettings.CALLBACK_TYPE_ALL_MATCHES, result);
            }
        }

        @Override
        public void onScanFailed(final int errorCode) {
            handler.post(new Runnable() {
                @Override
                public void run() {
                    scanning = false;
                    handler.removeCallbacks(scanTimeout);
                    listener.onScanState(false);
                    listener.onState(STATE_ERROR, "Scan failed (code " + errorCode + ")");
                    listener.onNotice("BLE scan failed, code " + errorCode
                            + ". Check permissions and Bluetooth.", true);
                }
            });
        }
    };

    private void handleScanResult(ScanResult result) {
        if (result == null || result.getDevice() == null) {
            return;
        }
        BluetoothDevice device = result.getDevice();
        String address = device.getAddress();
        String name;
        try {
            name = device.getName();
        } catch (SecurityException e) {
            name = null;
        }
        BleDevice item = seen.get(address);
        if (item == null) {
            item = new BleDevice(device, name, result.getRssi());
            seen.put(address, item);
        } else {
            if (name != null && !name.trim().isEmpty()) {
                item.name = name;
            }
            item.rssi = result.getRssi();
        }
        listener.onDevice(item);
    }

    private final BluetoothGattCallback gattCallback = new BluetoothGattCallback() {
        @Override
        public void onConnectionStateChange(final BluetoothGatt g, final int status, final int newState) {
            handler.post(new Runnable() {
                @Override
                public void run() {
                    handleConnectionState(g, status, newState);
                }
            });
        }

        @Override
        public void onServicesDiscovered(final BluetoothGatt g, final int status) {
            handler.post(new Runnable() {
                @Override
                public void run() {
                    handleServices(g, status);
                }
            });
        }

        @Override
        public void onDescriptorWrite(final BluetoothGatt g, final BluetoothGattDescriptor descriptor, final int status) {
            handler.post(new Runnable() {
                @Override
                public void run() {
                    if (g != gatt) {
                        return;
                    }
                    if (userDisconnect) {
                        return;
                    }
                    if (status != BluetoothGatt.GATT_SUCCESS) {
                        listener.onNotice("Notification setup failed (status " + status
                                + "); writes still work.", true);
                    }
                    becomeReady();
                }
            });
        }

        @Override
        public void onCharacteristicWrite(final BluetoothGatt g, final BluetoothGattCharacteristic characteristic, final int status) {
            handler.post(new Runnable() {
                @Override
                public void run() {
                    if (g != gatt) {
                        return;
                    }
                    writing = false;
                    writeSeq++;
                    if (status != BluetoothGatt.GATT_SUCCESS) {
                        listener.onNotice("Write failed (status " + status + ")", true);
                    }
                    handler.postDelayed(new Runnable() {
                        @Override
                        public void run() {
                            drain();
                        }
                    }, 15L);
                }
            });
        }

        @Override
        public void onCharacteristicChanged(BluetoothGatt g, BluetoothGattCharacteristic characteristic) {
            byte[] value = characteristic == null ? null : characteristic.getValue();
            deliverRx(value);
        }

        @Override
        public void onCharacteristicChanged(BluetoothGatt g, BluetoothGattCharacteristic characteristic, byte[] value) {
            deliverRx(value);
        }
    };

    public BleController(Context context, Listener listener) {
        this.context = context.getApplicationContext();
        this.listener = listener;
        this.adapter = getAdapter();
    }

    private BluetoothAdapter getAdapter() {
        android.bluetooth.BluetoothManager manager =
                (android.bluetooth.BluetoothManager) context.getSystemService(Context.BLUETOOTH_SERVICE);
        return manager == null ? null : manager.getAdapter();
    }

    public boolean isSupported() {
        return adapter != null;
    }

    public boolean isScanning() {
        return scanning;
    }

    public boolean isReady() {
        return ready;
    }

    public boolean isConnecting() {
        return connecting;
    }

    /** True while any GATT link object exists, including service discovery. */
    public boolean isLinked() {
        return gatt != null;
    }

    public boolean isBluetoothEnabled() {
        try {
            return adapter != null && adapter.isEnabled();
        } catch (SecurityException e) {
            listener.onNotice("Bluetooth permission missing (BLUETOOTH_CONNECT)", true);
            return false;
        }
    }

    public BleDevice getActive() {
        return active;
    }

    public String getTransportName() {
        return transportName;
    }

    public void startScan() {
        if (scanning) {
            return;
        }
        if (adapter == null) {
            listener.onState(STATE_ERROR, "Bluetooth LE not supported");
            listener.onNotice("This phone does not report a Bluetooth adapter.", true);
            return;
        }
        if (!isBluetoothEnabled()) {
            listener.onState(STATE_ERROR, "Bluetooth is off");
            listener.onNotice("Turn Bluetooth on, then scan again.", true);
            return;
        }
        try {
            scanner = adapter.getBluetoothLeScanner();
        } catch (SecurityException e) {
            scanner = null;
        } catch (IllegalStateException e) {
            scanner = null;
        }
        if (scanner == null) {
            listener.onState(STATE_ERROR, "BLE scanner unavailable");
            listener.onNotice("BLE scanner unavailable. Check BLUETOOTH_SCAN permission.", true);
            return;
        }
        seen.clear();
        ScanSettings settings;
        try {
            settings = new ScanSettings.Builder()
                    .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                    .setReportDelay(0L)
                    .build();
        } catch (IllegalArgumentException e) {
            settings = new ScanSettings.Builder()
                    .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                    .build();
        }
        try {
            scanning = true;
            scanner.startScan(null, settings, scanCallback);
        } catch (SecurityException e) {
            scanning = false;
            listener.onState(STATE_ERROR, "Scan permission denied");
            listener.onNotice("Android denied BLE scan. Grant Nearby devices permission.", true);
            return;
        } catch (IllegalStateException e) {
            scanning = false;
            listener.onState(STATE_ERROR, "Bluetooth is off");
            listener.onNotice("Bluetooth is off. Turn it on and retry.", true);
            return;
        }
        listener.onScanState(true);
        listener.onState(STATE_SCANNING, "Scanning for BLE-UART modules...");
        handler.removeCallbacks(scanTimeout);
        handler.postDelayed(scanTimeout, SCAN_TIMEOUT_MS);
    }

    public void stopScan() {
        boolean wasScanning = scanning;
        scanning = false;
        handler.removeCallbacks(scanTimeout);
        if (scanner != null && wasScanning) {
            try {
                scanner.stopScan(scanCallback);
            } catch (SecurityException ignored) {
                // Permission can be revoked while scanning; state is already cleared.
            } catch (IllegalStateException ignored) {
                // Adapter turned off mid-scan.
            }
        }
        if (wasScanning) {
            listener.onScanState(false);
            listener.onState(STATE_IDLE, "Scan stopped. Select a device.");
        }
    }

    public void connect(BleDevice device) {
        if (device == null) {
            return;
        }
        stopScan();
        handler.removeCallbacks(closeAfterDisconnect);
        closeGatt();
        active = device;
        userDisconnect = false;
        connecting = true;
        ready = false;
        transportName = "";
        listener.onState(STATE_CONNECTING,
                "Connecting to " + device.displayName() + "...");
        try {
            gatt = device.device.connectGatt(context, false, gattCallback,
                    BluetoothDevice.TRANSPORT_LE);
        } catch (SecurityException e) {
            gatt = null;
            connecting = false;
            listener.onState(STATE_ERROR, "Connect permission denied");
            listener.onNotice("Grant BLUETOOTH_CONNECT to connect.", true);
            return;
        }
        if (gatt == null) {
            connecting = false;
            listener.onState(STATE_ERROR, "Connect failed");
            listener.onNotice("Could not create a GATT connection.", true);
            return;
        }
        handler.removeCallbacks(connectTimeout);
        handler.postDelayed(connectTimeout, CONNECT_TIMEOUT_MS);
    }

    private void handleConnectionState(BluetoothGatt g, int status, int newState) {
        if (g != gatt) {
            try {
                g.close();
            } catch (Exception ignored) {
                // Stale callback from an earlier connection.
            }
            return;
        }
        if (newState == BluetoothProfile.STATE_CONNECTED) {
            connecting = false;
            if (userDisconnect) {
                try {
                    g.disconnect();
                } catch (SecurityException ignored) {
                    // Closing below is enough.
                }
                return;
            }
            listener.onState(STATE_CONNECTED, "Connected. Discovering services...");
            try {
                boolean started = g.discoverServices();
                if (!started) {
                    fail("Could not start service discovery.");
                }
            } catch (SecurityException e) {
                fail("Service discovery permission denied.");
            }
            return;
        }
        if (newState == BluetoothProfile.STATE_DISCONNECTED) {
            handler.removeCallbacks(connectTimeout);
            boolean wasUser = userDisconnect;
            closeGatt();
            connecting = false;
            ready = false;
            if (wasUser) {
                listener.onState(STATE_IDLE, "Disconnected");
                listener.onNotice("Link released (L00 sent when possible).", false);
            } else if (status == BluetoothGatt.GATT_SUCCESS) {
                listener.onState(STATE_IDLE, "Disconnected by the module");
                listener.onNotice("The BLE module closed the link. Reconnect to continue.", false);
            } else {
                listener.onState(STATE_ERROR, "Connection lost (status " + status + ")");
                listener.onNotice("Disconnected with status " + status
                        + ". Toggle Bluetooth or reconnect.", true);
            }
        }
    }

    private void handleServices(BluetoothGatt g, int status) {
        if (g != gatt || userDisconnect) {
            return;
        }
        if (status != BluetoothGatt.GATT_SUCCESS) {
            fail("Service discovery failed (status " + status + ")");
            return;
        }
        BluetoothGattService svc = g.getService(UUID_HM_SERVICE);
        BluetoothGattCharacteristic hm = svc == null ? null : svc.getCharacteristic(UUID_HM_CHAR);
        if (hm != null) {
            writeChar = hm;
            transportName = "HM-10/JDY FFE0";
            notifyChar = (hasNotify(hm) || hm.getDescriptor(UUID_CCCD) != null) ? hm : null;
        } else {
            svc = g.getService(UUID_NUS_SERVICE);
            if (svc != null) {
                BluetoothGattCharacteristic rx = svc.getCharacteristic(UUID_NUS_RX);
                BluetoothGattCharacteristic tx = svc.getCharacteristic(UUID_NUS_TX);
                if (rx != null) {
                    writeChar = rx;
                    transportName = "Nordic UART";
                    notifyChar = (tx != null && (hasNotify(tx) || tx.getDescriptor(UUID_CCCD) != null))
                            ? tx : null;
                }
            }
        }
        if (writeChar == null) {
            fail("No supported UART service (FFE0 or NUS) found.");
            return;
        }
        int properties = writeChar.getProperties();
        writeType = (properties & BluetoothGattCharacteristic.PROPERTY_WRITE) != 0
                ? BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                : BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE;
        listener.onNotice("Found " + transportName + " service", false);

        if (notifyChar == null) {
            becomeReady();
            return;
        }
        boolean enabled;
        try {
            enabled = g.setCharacteristicNotification(notifyChar, true);
        } catch (SecurityException e) {
            enabled = false;
        }
        if (!enabled) {
            listener.onNotice("Could not enable notifications; writes still work.", false);
            becomeReady();
            return;
        }
        BluetoothGattDescriptor cccd = notifyChar.getDescriptor(UUID_CCCD);
        if (cccd == null) {
            becomeReady();
            return;
        }
        try {
            cccd.setValue(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);
            if (!g.writeDescriptor(cccd)) {
                listener.onNotice("CCCD write was rejected; writes still work.", false);
                becomeReady();
            } else {
                // Some clones never report onDescriptorWrite. Do not leave the
                // UI stuck in "connected" if that callback is missing.
                handler.postDelayed(new Runnable() {
                    @Override
                    public void run() {
                        if (g == gatt && !ready) {
                            listener.onNotice("Notification setup timed out; writes only.", true);
                            becomeReady();
                        }
                    }
                }, 1800L);
            }
        } catch (SecurityException e) {
            listener.onNotice("CCCD permission denied; writes still work.", false);
            becomeReady();
        }
    }

    private void becomeReady() {
        if (ready || gatt == null || userDisconnect) {
            return;
        }
        ready = true;
        connecting = false;
        handler.removeCallbacks(connectTimeout);
        listener.onState(STATE_READY, "Ready");
        if (active != null) {
            listener.onReady(active);
        }
        listener.onNotice("Ready via " + transportName + "; "
                + (writeType == BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
                ? "write without response" : "write with response"), false);
        handler.removeCallbacks(keepalive);
        handler.postDelayed(keepalive, KEEPALIVE_INTERVAL_MS);
        enqueue(new Pending(Protocol.KEEPALIVE, true));
    }

    private static boolean hasNotify(BluetoothGattCharacteristic c) {
        int p = c.getProperties();
        return (p & BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0
                || (p & BluetoothGattCharacteristic.PROPERTY_INDICATE) != 0;
    }

    /** Send a user command. Shows a visible error when the link is not ready. */
    public void send(String command) {
        if (command == null || command.isEmpty()) {
            return;
        }
        if (!ready) {
            listener.onNotice("Not connected - " + command + " not sent", true);
            return;
        }
        enqueue(new Pending(command, false));
    }

    private void enqueue(Pending pending) {
        if (!ready && !pending.keepalive) {
            return;
        }
        if (queue.size() >= MAX_QUEUE) {
            queue.pollFirst();
            if (!overflowNotified) {
                overflowNotified = true;
                listener.onNotice("BLE write queue full; oldest command dropped.", true);
            }
        }
        queue.addLast(pending);
        drain();
    }

    private void drain() {
        if (!ready || writing || gatt == null || writeChar == null) {
            return;
        }
        final Pending pending = queue.pollFirst();
        if (pending == null) {
            overflowNotified = false;
            return;
        }
        byte[] bytes = Protocol.line(pending.command);
        try {
            writeChar.setWriteType(writeType);
            writeChar.setValue(bytes);
            writing = true;
            final int seq = ++writeSeq;
            boolean accepted = gatt.writeCharacteristic(writeChar);
            if (!accepted) {
                writing = false;
                writeSeq++;
                writeRetries++;
                if (writeRetries <= 3) {
                    queue.addFirst(pending);
                    handler.postDelayed(new Runnable() {
                        @Override
                        public void run() {
                            drain();
                        }
                    }, 120L);
                } else if (writeType == BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT) {
                    writeType = BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE;
                    writeRetries = 0;
                    queue.addFirst(pending);
                    listener.onNotice("Write-with-response rejected; retrying without response.", false);
                    handler.postDelayed(new Runnable() {
                        @Override
                        public void run() {
                            drain();
                        }
                    }, 120L);
                } else {
                    writeRetries = 0;
                    listener.onNotice("BLE stack rejected " + pending.command, true);
                }
                return;
            }
            writeRetries = 0;
            if (!pending.keepalive) {
                listener.onCommand(pending.command);
            }
            if (writeType == BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE) {
                handler.postDelayed(new Runnable() {
                    @Override
                    public void run() {
                        if (writing && seq == writeSeq) {
                            writing = false;
                            writeSeq++;
                            drain();
                        }
                    }
                }, 40L);
            } else {
                handler.postDelayed(new Runnable() {
                    @Override
                    public void run() {
                        if (writing && seq == writeSeq) {
                            writing = false;
                            writeSeq++;
                            listener.onNotice("Write timeout for " + pending.command, true);
                            drain();
                        }
                    }
                }, WRITE_TIMEOUT_MS);
            }
        } catch (SecurityException e) {
            writing = false;
            listener.onNotice("Write permission denied", true);
        } catch (RuntimeException e) {
            writing = false;
            Log.w(TAG, "write failed", e);
            listener.onNotice("BLE write error: " + e.getClass().getSimpleName(), true);
        }
    }

    private void deliverRx(byte[] value) {
        if (value == null || value.length == 0) {
            return;
        }
        final byte[] copy = new byte[value.length];
        System.arraycopy(value, 0, copy, 0, value.length);
        handler.post(new Runnable() {
            @Override
            public void run() {
                listener.onRx(copy);
            }
        });
    }

    /** User-requested disconnect: release the FPGA lease, then close. */
    public void disconnect() {
        userDisconnect = true;
        handler.removeCallbacks(connectTimeout);
        handler.removeCallbacks(keepalive);
        boolean wasReady = ready;
        if (wasReady && gatt != null && writeChar != null) {
            try {
                writeChar.setWriteType(writeType);
                writeChar.setValue(Protocol.line(Protocol.RELEASE));
                gatt.writeCharacteristic(writeChar);
            } catch (SecurityException ignored) {
                // Best effort only; the firmware lease also expires.
            } catch (RuntimeException ignored) {
                // Best effort only.
            }
        }
        ready = false;
        connecting = false;
        queue.clear();
        writing = false;
        writeSeq++;
        if (gatt != null) {
            try {
                gatt.disconnect();
            } catch (SecurityException ignored) {
                // close() below is enough.
            }
        }
        listener.onState(STATE_IDLE, "Disconnected");
        handler.removeCallbacks(closeAfterDisconnect);
        handler.postDelayed(closeAfterDisconnect, 400L);
    }

    /** Called from Activity.onDestroy; releases the link and stops callbacks. */
    public void shutdown() {
        stopScan();
        if (ready) {
            disconnect();
        }
        handler.removeCallbacks(keepalive);
        handler.removeCallbacks(connectTimeout);
        handler.removeCallbacks(scanTimeout);
        handler.removeCallbacks(closeAfterDisconnect);
        closeGatt();
    }

    private void fail(String message) {
        handler.removeCallbacks(connectTimeout);
        listener.onState(STATE_ERROR, message);
        listener.onNotice(message, true);
        closeGatt();
        connecting = false;
        ready = false;
    }

    private void closeGatt() {
        handler.removeCallbacks(keepalive);
        handler.removeCallbacks(connectTimeout);
        handler.removeCallbacks(closeAfterDisconnect);
        if (gatt != null) {
            try {
                gatt.close();
            } catch (Exception ignored) {
                // Nothing else to do.
            }
        }
        gatt = null;
        writeChar = null;
        notifyChar = null;
        writing = false;
        ready = false;
        writeSeq++;
        queue.clear();
        overflowNotified = false;
    }

    /** Debug string for the UI; never contains command payloads. */
    public String debugSummary() {
        return String.format(Locale.US, "%s, %s, queue=%d",
                transportName.isEmpty() ? "no service" : transportName,
                writeType == BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
                        ? "no-response" : "with-response",
                queue.size());
    }

    private static final class Pending {
        final String command;
        final boolean keepalive;

        Pending(String command, boolean keepalive) {
            this.command = command;
            this.keepalive = keepalive;
        }
    }
}
