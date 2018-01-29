//
//  HLYBluetoothDevice.h
//
//  Created by 韩灵叶 on 2018/1/15.
//  Copyright © 2018年 WelfareMall. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CBPeripheral;

@interface HLYBluetoothDevice : NSObject

@property (nonatomic, copy) NSNumber *RSSI;
@property (nonatomic, copy) CBPeripheral *peripheral;
@property (nonatomic, copy) NSString *serviceID;
@property (nonatomic, copy) NSString *characteristicID;
@property (nonatomic, readonly, getter=isConnected) BOOL connected;

- (instancetype)initWithPeripheral:(CBPeripheral *)peripheral RSSI:(NSNumber *)RSSI;

- (NSString *)stateStringValue;

@end
