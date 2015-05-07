//
//  BLECentralPlugin.m
//  BLE Central Cordova Plugin
//
//  (c) 2104-2015 Don Coleman
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

#import "BLECentralPlugin.h"
#import <Cordova/CDV.h>

@interface BLECentralPlugin()
- (CBPeripheral *)findPeripheralByUUID:(NSString *)uuid;
@end

@implementation BLECentralPlugin

@synthesize manager;
@synthesize peripherals;

- (void)pluginInitialize
{
    NSLog(@"Cordova BLE Central Plugin");

    [super pluginInitialize];

    peripherals = [NSMutableSet set];
    manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];

    connectCallbacks = [NSMutableDictionary new];
    connectCallbackLatches = [NSMutableDictionary new];
    readCallbacks = [NSMutableDictionary new];
    writeCallbacks = [NSMutableDictionary new];
    notificationCallbacks = [NSMutableDictionary new];
    stopNotificationCallbacks = [NSMutableDictionary new];
    
    self.onEnabledChangeCallbackId = nil;
}

#pragma mark - Cordova Plugin Methods

- (void)connect:(CDVInvokedUrlCommand *)command
{
    NSLog(@"connect");
    NSString * uuid = [command.arguments objectAtIndex:0];
    CBPeripheral * peripheral = [self findPeripheralByUUID:uuid];
    NSString * existingConnectCallbackId = [connectCallbacks valueForKey:uuid];
    
    int bluetoothState = [manager state];
    BOOL enabled = bluetoothState == CBCentralManagerStatePoweredOn;
    
    if (!enabled) {
        NSString * error = [NSString stringWithFormat:@"Cannot connect to this peripheral %@ because Bluetooth is turned off.", uuid];
        NSLog(@"%@", error);
        
        if (peripheral) {
            [manager cancelPeripheralConnection:peripheral];
        }
        
        CDVPluginResult * pluginResult = nil;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
    else if (existingConnectCallbackId)
    {
        NSString * error = [NSString stringWithFormat:@"Connect already called for this peripheral %@.", uuid];
        NSLog(@"%@", error);
        CDVPluginResult * pluginResult = nil;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
    else if (peripheral)
    {
        NSLog(@"Connecting to peripheral with UUID : %@", uuid);
        [connectCallbacks setObject:[command.callbackId copy] forKey:[peripheral uuidAsString]];
        [manager connectPeripheral:peripheral options:nil];
    }
    else
    {
        NSString * error = [NSString stringWithFormat:@"Could not find peripheral %@.", uuid];
        NSLog(@"%@", error);
        CDVPluginResult * pluginResult = nil;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

- (void)disconnect:(CDVInvokedUrlCommand*)command
{
    NSLog(@"disconnect");

    NSString * uuid = [command.arguments objectAtIndex:0];
    CBPeripheral * peripheral = [self findPeripheralByUUID:uuid];
    [connectCallbacks removeObjectForKey:uuid];

    // if (peripheral && peripheral.isConnected)
    if (peripheral)
    {
        [manager cancelPeripheralConnection:peripheral];
    }

    // always return OK
    CDVPluginResult * pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)isEnabled:(CDVInvokedUrlCommand*)command
{
    NSLog(@"isEnabled");
    CDVPluginResult *pluginResult = nil;
    int bluetoothState = [manager state];
    BOOL enabled = bluetoothState == CBCentralManagerStatePoweredOn;

    if (enabled)
    {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    }
    else
    {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt:bluetoothState];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)onEnabledChange:(CDVInvokedUrlCommand*)command
{
    NSLog(@"onEnabledChange");
    NSString * callbackId = [command callbackId];
    self.onEnabledChangeCallbackId = [command.callbackId copy];
}

- (void)_onEnabledChange
{
    if (self.onEnabledChangeCallbackId == nil)
    {
        return;
    }
    
    int bluetoothState = [manager state];
    BOOL enabled = bluetoothState == CBCentralManagerStatePoweredOn;
    
    CDVPluginResult * result = [CDVPluginResult
                               resultWithStatus:CDVCommandStatus_OK
                               messageAsBool:enabled];
    
    [result setKeepCallbackAsBool:TRUE];
    [self.commandDelegate sendPluginResult:result callbackId:self.onEnabledChangeCallbackId];
}

- (void)scan:(CDVInvokedUrlCommand*)command
{
    NSLog(@"scan");
    discoverPeripherialCallbackId = [command.callbackId copy];

    NSArray * serviceUUIDStrings = [command.arguments objectAtIndex:0];
    NSNumber * timeoutSeconds = [command.arguments objectAtIndex:1];
    NSMutableArray * serviceUUIDs = [NSMutableArray new];

    for (int i = 0; i < [serviceUUIDStrings count]; i++)
    {
        CBUUID * serviceUUID = [CBUUID UUIDWithString:[serviceUUIDStrings objectAtIndex: i]];
        [serviceUUIDs addObject:serviceUUID];
    }

    // [manager scanForPeripheralsWithServices:serviceUUIDs options:nil];
    NSDictionary * scanOptions = [NSDictionary
                                    dictionaryWithObject:[NSNumber numberWithBool:YES] 
                                    forKey:CBCentralManagerScanOptionAllowDuplicatesKey];

    [manager scanForPeripheralsWithServices:serviceUUIDs options:scanOptions];
}

- (void)isConnected:(CDVInvokedUrlCommand*)command
{
    NSLog(@"isConnected");
    CDVPluginResult * pluginResult = nil;
    CBPeripheral * peripheral = [self findPeripheralByUUID:[command.arguments objectAtIndex:0]];

    if (peripheral && [peripheral isConnected])
    {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    }
    else
    {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not connected"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)stop:(CDVInvokedUrlCommand*)command
{
    NSLog(@"stop");    
    NSString * callbackId = [command callbackId];
    NSString * msg = @"true";
    
    [manager stopScan];

    if (discoverPeripherialCallbackId)
    {
        discoverPeripherialCallbackId = nil;
    }
    
    CDVPluginResult* result = [CDVPluginResult
                               resultWithStatus:CDVCommandStatus_OK
                               messageAsString:msg];
    
    [self.commandDelegate sendPluginResult:result callbackId:callbackId];
}

- (void)setScanFilter:(CDVInvokedUrlCommand*)command
{
    NSLog(@"setScanFilter");
    NSString * callbackId = [command callbackId];
    NSString * msg = @"true";
    
    CDVPluginResult* result = [CDVPluginResult
                               resultWithStatus:CDVCommandStatus_OK
                               messageAsString:msg];
    
    [self.commandDelegate sendPluginResult:result callbackId:callbackId];
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    
    if (!discoverPeripherialCallbackId)
    {
        NSLog(@"discoverPeripherialCallbackId = %@", discoverPeripherialCallbackId);
        return;
    }
    
    [peripherals addObject:peripheral];
    [peripheral setAdvertisementData:advertisementData RSSI:RSSI];
    
    NSMutableDictionary * msg = [[peripheral asDictionary] mutableCopy];
    NSLog(@"Discovered %@", msg);

    CDVPluginResult * pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:msg];
    [pluginResult setKeepCallbackAsBool:TRUE];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:discoverPeripherialCallbackId];
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    NSLog(@"Status of CoreBluetooth central manager changed %ld %@", central.state, [self centralManagerStateToString: central.state]);

    if (central.state != CBCentralManagerStatePoweredOn)
    {
        NSLog(@"Bluetooth turned OFF");
        
        // connectCallbacks
        NSLog(@"Bluetooth turned OFF - cleaning connect callbacks");
        for (NSString * uuid in connectCallbacks)
        {
            CBPeripheral * peripheral = connectCallbacks[uuid];
            [manager cancelPeripheralConnection:peripheral];
        }
        
        [connectCallbacks removeAllObjects];
        connectCallbacks = [NSMutableDictionary new];
        
        // peripherals
//        NSLog(@"Bluetooth turned OFF - clearing peripherals");
//        [peripherals removeAllObjects];
//        peripherals = [NSMutableSet new];
    }
    
    [self _onEnabledChange];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"didConnectPeripheral");
    peripheral.delegate = self;

    // NOTE: it's inefficient to discover all services
    // [peripheral discoverServices:nil];

    // Call success callback for connect
    NSString * peripheralUUIDString = [peripheral uuidAsString];
    NSString * connectCallbackId = [connectCallbacks valueForKey:peripheralUUIDString];

    if (connectCallbackId)
    {
        CDVPluginResult * pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:[peripheral asDictionary]];
        [pluginResult setKeepCallbackAsBool:TRUE];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:connectCallbackId];
    }

    // [connectCallbackLatches removeObjectForKey:peripheralUUIDString];
    [connectCallbacks removeObjectForKey:peripheralUUIDString];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"didDisconnectPeripheral");

    // TODO send PhoneGap more info from NSError

    NSString * connectCallbackId = [connectCallbacks valueForKey:[peripheral uuidAsString]];
    [connectCallbacks removeObjectForKey:[peripheral uuidAsString]];

    if (connectCallbackId)
    {
        CDVPluginResult *pluginResult = nil;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Disconnected"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:connectCallbackId];
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"didFailToConnectPeripheral");

    // TODO send PhoneGap more info from NSError

    NSString *connectCallbackId = [connectCallbacks valueForKey:[peripheral uuidAsString]];
    [connectCallbacks removeObjectForKey:[peripheral uuidAsString]];

    CDVPluginResult *pluginResult = nil;
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Failed to Connect"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:connectCallbackId];
}

#pragma mark CBPeripheralDelegate

#pragma mark - internal implemetation

- (CBPeripheral*)findPeripheralByUUID:(NSString*)uuid
{
    CBPeripheral * peripheral = nil;

    for (CBPeripheral * p in peripherals)
    {
        NSString * other = CFBridgingRelease(CFUUIDCreateString(nil, p.UUID));

        if ([uuid isEqualToString:other])
        {
            peripheral = p;
            break;
        }
    }

    return peripheral;
}

// RedBearLab
-(CBService *) findServiceFromUUID:(CBUUID *)UUID p:(CBPeripheral *)p
{
    for(int i = 0; i < p.services.count; i++)
    {
        CBService * s = [p.services objectAtIndex:i];
        
        if ([self compareCBUUID:s.UUID UUID2:UUID])
            return s;
    }

    return nil; //Service not found on this peripheral
}

// RedBearLab
-(CBCharacteristic *) findCharacteristicFromUUID:(CBUUID *)UUID service:(CBService*)service
{
    NSLog(@"Looking for %@", UUID);
    
    for(int i=0; i < service.characteristics.count; i++)
    {
        CBCharacteristic *c = [service.characteristics objectAtIndex:i];
        NSLog(@"Characteristic %@", c);
        
        if ([self compareCBUUID:c.UUID UUID2:UUID])
            return c;
    }

    return nil; //Characteristic not found on this service
}

// RedBearLab
-(int) compareCBUUID:(CBUUID *) UUID1 UUID2:(CBUUID *)UUID2
{
    char b1[16];
    char b2[16];
    [UUID1.data getBytes:b1];
    [UUID2.data getBytes:b2];

    if (memcmp(b1, b2, UUID1.data.length) == 0)
        return 1;
    else
        return 0;
}

// expecting deviceUUID, serviceUUID, characteristicUUID in command.arguments
-(Foo*) getData:(CDVInvokedUrlCommand*)command
{
    NSLog(@"getData");

    CDVPluginResult *pluginResult = nil;

    NSString *deviceUUIDString = [command.arguments objectAtIndex:0];
    NSString *serviceUUIDString = [command.arguments objectAtIndex:1];
    NSString *characteristicUUIDString = [command.arguments objectAtIndex:2];

    CBUUID *serviceUUID = [CBUUID UUIDWithString:serviceUUIDString];
    CBUUID *characteristicUUID = [CBUUID UUIDWithString:characteristicUUIDString];

    CBPeripheral *peripheral = [self findPeripheralByUUID:deviceUUIDString];

    if (!peripheral) {

        NSLog(@"Could not find peripherial with UUID %@", deviceUUIDString);

        NSString *errorMessage = [NSString stringWithFormat:@"Could not find peripherial with UUID %@", deviceUUIDString];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

        return nil;
    }

    CBService *service = [self findServiceFromUUID:serviceUUID p:peripheral];

    if (!service)
    {
        NSLog(@"Could not find service with UUID %@ on peripheral with UUID %@",
              serviceUUIDString,
              peripheral.identifier.UUIDString);


        NSString *errorMessage = [NSString stringWithFormat:@"Could not find service with UUID %@ on peripheral with UUID %@",
                                  serviceUUIDString,
                                  peripheral.identifier.UUIDString];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

        return nil;
    }

    CBCharacteristic *characteristic = [self findCharacteristicFromUUID:characteristicUUID service:service];

    if (!characteristic)
    {
        NSLog(@"Could not find characteristic with UUID %@ on service with UUID %@ on peripheral with UUID %@",
              characteristicUUIDString,
              serviceUUIDString,
              peripheral.identifier.UUIDString);

        NSString *errorMessage = [NSString stringWithFormat:
                                  @"Could not find characteristic with UUID %@ on service with UUID %@ on peripheral with UUID %@",
                                  characteristicUUIDString,
                                  serviceUUIDString,
                                  peripheral.identifier.UUIDString];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

        return nil;
    }

    Foo *foo = [[Foo alloc] init];
    [foo setPeripheral:peripheral];
    [foo setService:service];
    [foo setCharacteristic:characteristic];
    return foo;

}

-(NSString *) keyForPeripheral: (CBPeripheral *)peripheral andCharacteristic:(CBCharacteristic *)characteristic
{
    return [NSString stringWithFormat:@"%@|%@", [peripheral uuidAsString], [characteristic UUID]];
}

#pragma mark - util

- (NSString*) centralManagerStateToString: (int)state
{
    switch(state)
    {
        case CBCentralManagerStateUnknown:
            return @"State unknown (CBCentralManagerStateUnknown)";
        case CBCentralManagerStateResetting:
            return @"State resetting (CBCentralManagerStateUnknown)";
        case CBCentralManagerStateUnsupported:
            return @"State BLE unsupported (CBCentralManagerStateResetting)";
        case CBCentralManagerStateUnauthorized:
            return @"State unauthorized (CBCentralManagerStateUnauthorized)";
        case CBCentralManagerStatePoweredOff:
            return @"State BLE powered off (CBCentralManagerStatePoweredOff)";
        case CBCentralManagerStatePoweredOn:
            return @"State powered up and ready (CBCentralManagerStatePoweredOn)";
        default:
            return @"State unknown";
    }

    return @"Unknown state";
}

@end
