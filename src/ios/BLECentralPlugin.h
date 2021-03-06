//
//  BLECentralPlugin.h
//  BLE Central Cordova Plugin
//
//  (c) 2104 Don Coleman
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

#ifndef BLECentralPlugin_h
#define BLECentralPlugin_h

#import <Cordova/CDV.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "Foo.h"
#import "CBPeripheral+Extensions.h"

@interface BLECentralPlugin : CDVPlugin <CBCentralManagerDelegate, CBPeripheralDelegate> {
    NSString * discoverPeripherialCallbackId;
    NSMutableDictionary * connectCallbacks;
    NSMutableDictionary * connectCallbackLatches;
    NSMutableDictionary * readCallbacks;
    NSMutableDictionary * writeCallbacks;
    NSMutableDictionary * notificationCallbacks;
    NSMutableDictionary * stopNotificationCallbacks;
}

@property (strong, nonatomic) NSMutableSet *peripherals;
@property (strong, nonatomic) CBCentralManager *manager;
@property (nonatomic) NSString * onEnabledChangeCallbackId;
@property (strong, nonatomic) NSMutableDictionary * discoveredDevices;

- (void)scan:(CDVInvokedUrlCommand *)command;
- (void)stop:(CDVInvokedUrlCommand *)command;

- (void)connect:(CDVInvokedUrlCommand *)command;
- (void)disconnect:(CDVInvokedUrlCommand *)command;

- (void)isEnabled:(CDVInvokedUrlCommand *)command;
- (void)isConnected:(CDVInvokedUrlCommand *)command;

- (void)onEnabledChange:(CDVInvokedUrlCommand *)command;
- (void)_onEnabledChange;

- (void)setScanFilter:(CDVInvokedUrlCommand *)command;

@end

#endif
