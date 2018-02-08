//
//  HLYBluetoothDevice.m
//
//  Created by 韩灵叶 on 2018/1/15.
//  Copyright © 2018年 WelfareMall. All rights reserved.
//

#import "HLYBluetoothDevice.h"
#import <CoreBluetooth/CoreBluetooth.h>

@implementation HLYBluetoothDevice

- (instancetype)initWithPeripheral:(CBPeripheral *)peripheral RSSI:(NSNumber *)RSSI {
    self = [super init];
    if (self) {
        _peripheral = peripheral;
        _RSSI = RSSI;
    }
    return self;
}

- (BOOL)isConnected {
    return self.peripheral && self.peripheral.state == CBPeripheralStateConnected;
}

- (NSString *)stateStringValue {
    
    switch (self.peripheral.state) {
        case CBPeripheralStateDisconnected:
            return @"未连接";
        case CBPeripheralStateConnecting:
            return @"连接中";
        case CBPeripheralStateConnected:
            return @"已连接";
        case CBPeripheralStateDisconnecting:
            return @"断开中";
            
        default:
            break;
    }
    return @"未知";
}

//- (BOOL)isEqual:(id)object {
//    if (object == self) return YES;
//    if (!object || ![object isKindOfClass:[self class]]) return NO;
//    if (![(id)[_peripheral identifier] isEqual:[object identifier]]) return NO;
//    
//    return YES;
//}
//
//- (NSUInteger)hash {
//    return [_peripheral.identifier hash];
//}

- (NSString *)description {
    return [NSString stringWithFormat:@"identifier: %@, name: %@", _peripheral.identifier, _peripheral.name];
}

@end
