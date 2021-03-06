// (c) 2104 Don Coleman
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package com.megster.cordova.ble.central;

import android.app.Activity;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothManager;
import android.content.Context;
import android.os.Handler;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaArgs;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.LOG;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;

import android.content.Intent;
import android.content.IntentFilter;
import android.content.BroadcastReceiver;

import java.util.*;

public class BLECentralPlugin extends CordovaPlugin implements BluetoothAdapter.LeScanCallback {
    // actions
    private static final String SCAN = "scan";
    private static final String STOP = "stop";
    private static final String LIST = "list";

    private static final String CONNECT = "connect";
    private static final String DISCONNECT = "disconnect";

    private static final String READ = "read";
    private static final String WRITE = "write";
    private static final String WRITE_WITHOUT_RESPONSE = "writeWithoutResponse";

    private static final String NOTIFY = "startNotification"; // register for characteristic notification
    // TODO future private static final String INDICATE = "indicate"; // register indication

    private static final String IS_ENABLED = "isEnabled";
    private static final String IS_CONNECTED  = "isConnected";
    private static final String ON_ENABLED_CHANGE  = "onEnabledChange";
    private static final String SET_SCAN_FILTER  = "setScanFilter";

    // scan filter
    private List<String> macAddressFilter = new ArrayList<String>();

    // callbacks
    CallbackContext discoverCallback;
    CallbackContext onEnabledChangeCallback;

    private static final String TAG = "BLEPlugin";

    private Activity mActivity;
    private Context mContext;

    BluetoothAdapter bluetoothAdapter;
    private BroadcastReceiver bluetoothAdapterReceiver;

    // key is the MAC Address
    Map<String, Peripheral> peripherals = new LinkedHashMap<String, Peripheral>();

    @Override
    public boolean execute(String action, CordovaArgs args, CallbackContext callbackContext) throws JSONException {

        LOG.d(TAG, "action = " + action);

        if (bluetoothAdapter == null) {
            Activity activity = cordova.getActivity();
            BluetoothManager bluetoothManager = (BluetoothManager) activity.getSystemService(Context.BLUETOOTH_SERVICE);
            bluetoothAdapter = bluetoothManager.getAdapter();

            // listens BluetoothAdapter state changes
            // http://stackoverflow.com/questions/9693755/detecting-state-changes-made-to-the-bluetoothadapter
            mActivity = this.cordova.getActivity();
            mContext = mActivity.getApplicationContext();

            bluetoothAdapterReceiver = new BroadcastReceiver() {
                @Override
                public void onReceive(Context context, Intent intent) {
                    final String action = intent.getAction();
                    LOG.d(TAG, "action = " + action);

                    if (action.equals(BluetoothAdapter.ACTION_STATE_CHANGED)) {
                        final int state = intent.getIntExtra(
                            BluetoothAdapter.EXTRA_STATE,
                            BluetoothAdapter.ERROR
                        );
                        
                        switch (state) {
                            case BluetoothAdapter.STATE_OFF:
                                LOG.d(TAG, "Bluetooth off");

                                if (onEnabledChangeCallback != null) {
                                    PluginResult result = new PluginResult(PluginResult.Status.OK, false);
                                    result.setKeepCallback(true);
                                    onEnabledChangeCallback.sendPluginResult(result);
                                }
                                
                                break;
                            case BluetoothAdapter.STATE_TURNING_OFF:
                                LOG.d(TAG, "Turning Bluetooth off...");
                                break;
                            case BluetoothAdapter.STATE_ON:
                                LOG.d(TAG, "Bluetooth on");

                                if (onEnabledChangeCallback != null) {
                                    PluginResult result = new PluginResult(PluginResult.Status.OK, true);
                                    result.setKeepCallback(true);
                                    onEnabledChangeCallback.sendPluginResult(result);
                                }

                                break;
                            case BluetoothAdapter.STATE_TURNING_ON:
                                LOG.d(TAG, "Turning Bluetooth on...");
                                break;
                        }
                    }
                }
            };

            IntentFilter filter = new IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED);
            mContext.registerReceiver(bluetoothAdapterReceiver, filter);
        }

        boolean validAction = true;

        if (action.equals(SCAN)) {

            UUID[] serviceUUIDs = parseServiceUUIDList(args.getJSONArray(0));
            int scanSeconds = args.getInt(1);
            findLowEnergyDevices(callbackContext, serviceUUIDs, scanSeconds);
        
        } else if (action.equals(STOP)) {
        
            stop(callbackContext);
        
        } else if (action.equals(LIST)) {

            listKnownDevices(callbackContext);

        } else if (action.equals(CONNECT)) {

            String macAddress = args.getString(0);
            connect(callbackContext, macAddress);

        } else if (action.equals(DISCONNECT)) {

            String macAddress = args.getString(0);
            disconnect(callbackContext, macAddress);

        } else if (action.equals(READ)) {

            String macAddress = args.getString(0);
            UUID serviceUUID = uuidFromString(args.getString(1));
            UUID characteristicUUID = uuidFromString(args.getString(2));
            read(callbackContext, macAddress, serviceUUID, characteristicUUID);

        } else if (action.equals(WRITE)) {

            String macAddress = args.getString(0);
            UUID serviceUUID = uuidFromString(args.getString(1));
            UUID characteristicUUID = uuidFromString(args.getString(2));
            byte[] data = args.getArrayBuffer(3);
            int type = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT;
            write(callbackContext, macAddress, serviceUUID, characteristicUUID, data, type);

        } else if (action.equals(WRITE_WITHOUT_RESPONSE)) {

            String macAddress = args.getString(0);
            UUID serviceUUID = uuidFromString(args.getString(1));
            UUID characteristicUUID = uuidFromString(args.getString(2));
            byte[] data = args.getArrayBuffer(3);
            int type = BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE;
            write(callbackContext, macAddress, serviceUUID, characteristicUUID, data, type);

        } else if (action.equals(NOTIFY)) {

            String macAddress = args.getString(0);
            UUID serviceUUID = uuidFromString(args.getString(1));
            UUID characteristicUUID = uuidFromString(args.getString(2));
            registerNotifyCallback(callbackContext, macAddress, serviceUUID, characteristicUUID);

        } else if (action.equals(IS_ENABLED)) {

            if (bluetoothAdapter.isEnabled()) {
                callbackContext.success();
            } else {
                callbackContext.error("Bluetooth is disabled.");
            }

        } else if (action.equals(IS_CONNECTED)) {

            String macAddress = args.getString(0);

            if (peripherals.containsKey(macAddress) && peripherals.get(macAddress).isConnected()) {
                callbackContext.success();
            } else {
                callbackContext.error("Not connected.");
            }

        } else if (action.equals(ON_ENABLED_CHANGE)) {
        
            onEnabledChangeCallback = callbackContext;

            PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
            result.setKeepCallback(true);
            callbackContext.sendPluginResult(result);

        } else if (action.equals(SET_SCAN_FILTER)) {

            JSONArray macAddresses = args.getJSONArray(0);
            macAddressFilter.clear();

            for (int i = 0; i < macAddresses.length(); i++) {
                String macAddess = macAddresses.getString(i).toLowerCase();
                macAddressFilter.add(macAddess);
            }

            PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
            callbackContext.sendPluginResult(result);

        } else {

            validAction = false;

        }

        return validAction;
    }

    private UUID[] parseServiceUUIDList(JSONArray jsonArray) throws JSONException {
        List<UUID> serviceUUIDs = new ArrayList<UUID>();

        for(int i = 0; i < jsonArray.length(); i++){
            String uuidString = jsonArray.getString(i);
            serviceUUIDs.add(uuidFromString(uuidString));
        }

        return serviceUUIDs.toArray(new UUID[jsonArray.length()]);
    }

    private void connect(CallbackContext callbackContext, String macAddress) {
        Peripheral peripheral = peripherals.get(macAddress);

        if (peripheral != null) {
            peripheral.connect(callbackContext, cordova.getActivity());
        } else {
            callbackContext.error("Peripheral " + macAddress + " not found.");
        }
    }

    private void disconnect(CallbackContext callbackContext, String macAddress) {
        Peripheral peripheral = peripherals.get(macAddress);

        if (peripheral != null) {
            peripheral.disconnect();
        }

        callbackContext.success();
    }

    private void read(CallbackContext callbackContext, String macAddress, UUID serviceUUID, UUID characteristicUUID) {
        Peripheral peripheral = peripherals.get(macAddress);

        if (peripheral == null) {
            callbackContext.error("Peripheral " + macAddress + " not found.");
            return;
        }

        if (!peripheral.isConnected()) {
            callbackContext.error("Peripheral " + macAddress + " is not connected.");
            return;
        }

        //peripheral.readCharacteristic(callbackContext, serviceUUID, characteristicUUID);
        peripheral.queueRead(callbackContext, serviceUUID, characteristicUUID);
    }

    private void write(CallbackContext callbackContext, String macAddress, UUID serviceUUID, UUID characteristicUUID,
                       byte[] data, int writeType) {

        Peripheral peripheral = peripherals.get(macAddress);

        if (peripheral == null) {
            callbackContext.error("Peripheral " + macAddress + " not found.");
            return;
        }

        if (!peripheral.isConnected()) {
            callbackContext.error("Peripheral " + macAddress + " is not connected.");
            return;
        }

        //peripheral.writeCharacteristic(callbackContext, serviceUUID, characteristicUUID, data, writeType);
        peripheral.queueWrite(callbackContext, serviceUUID, characteristicUUID, data, writeType);
    }

    private void registerNotifyCallback(CallbackContext callbackContext, String macAddress, UUID serviceUUID, UUID characteristicUUID) {
        Peripheral peripheral = peripherals.get(macAddress);

        if (peripheral != null) {
            // peripheral.setOnDataCallback(serviceUUID, characteristicUUID, callbackContext);
            peripheral.queueRegisterNotifyCallback(callbackContext, serviceUUID, characteristicUUID);
        } else {
            callbackContext.error("Peripheral " + macAddress + " not found");

        }
    }

    private void findLowEnergyDevices(CallbackContext callbackContext, UUID[] serviceUUIDs, int scanSeconds) {
        // TODO skip if currently scanning

        discoverCallback = callbackContext;

        // FIXME:
        // This method was deprecated in API level 21.
        // use startScan(List, ScanSettings, ScanCallback) instead.

        if (serviceUUIDs.length > 0) {
            bluetoothAdapter.startLeScan(serviceUUIDs, this);
        } else {
            bluetoothAdapter.startLeScan(this);
        }
        
        PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
        result.setKeepCallback(true);
        callbackContext.sendPluginResult(result);
    }
    
    private void stop(CallbackContext callbackContext) {
        // FIXME:
        // This method was deprecated in API level 21.
        // Use stopScan(ScanCallback) instead.

        // LOG.d(TAG, "Stopping Scan");
        // BLECentralPlugin.this.bluetoothAdapter.stopLeScan(BLECentralPlugin.this);
        this.bluetoothAdapter.stopLeScan(this);
        callbackContext.success();
    }
    
    private void listKnownDevices(CallbackContext callbackContext) {
        JSONArray json = new JSONArray();

        // do we care about consistent order? will peripherals.values() be in order?
        for (Map.Entry<String, Peripheral> entry : peripherals.entrySet()) {
            Peripheral peripheral = entry.getValue();
            json.put(peripheral.asJSONObject());
        }

        PluginResult result = new PluginResult(PluginResult.Status.OK, json);
        callbackContext.sendPluginResult(result);
    }

    @Override
    public void onLeScan(BluetoothDevice device, int rssi, byte[] scanRecord) {
        String address = device.getAddress();
        
        /*
        if (!peripherals.containsKey(address)) {

            Peripheral peripheral = new Peripheral(device, rssi, scanRecord);
            peripherals.put(device.getAddress(), peripheral);

            if (discoverCallback != null) {
                PluginResult result = new PluginResult(PluginResult.Status.OK, peripheral.asJSONObject());
                result.setKeepCallback(true);
                discoverCallback.sendPluginResult(result);
            }

        } else {
            // this isn't necessary
            Peripheral peripheral = peripherals.get(address);
            peripheral.updateRssi(rssi);
        }
        */
        
        // filter by MAC
        if (macAddressFilter.size() > 0) {
            String macAddress = device.getAddress().toLowerCase();

            if (!macAddressFilter.contains(macAddress)) {
                return;
            }
        }

        Peripheral peripheral = new Peripheral(device, rssi, scanRecord);
        peripherals.put(device.getAddress(), peripheral);

        if (discoverCallback != null) {
            PluginResult result = new PluginResult(PluginResult.Status.OK, peripheral.asJSONObject());
            result.setKeepCallback(true);
            discoverCallback.sendPluginResult(result);
        }

        // TODO offer option to return duplicates
    }

    private UUID uuidFromString(String uuid) {
        return UUIDHelper.uuidFromString(uuid);
    }
}
