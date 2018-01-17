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

- (NSString *)stateStringValue {
    
    switch (self.peripheral.state) {
        case CBPeripheralStateDisconnected:
            return @"未连接";
        case  CBPeripheralStateConnecting:
            return @"连接中";
        case  CBPeripheralStateConnected:
            return @"已连接";
        case  CBPeripheralStateDisconnecting:
            return @"断开中";
            
        default:
            break;
    }
    return @"未知";
}

@end
