//
//  HLYBluetoothDevice.h
//
//  Created by 韩灵叶 on 2018/1/15.
//  Copyright © 2018年 WelfareMall. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CBPeripheral;

@interface HLYBluetoothDevice : NSObject

@property (nonatomic, readonly) NSNumber *RSSI;
@property (nonatomic, readonly) CBPeripheral *peripheral;

- (instancetype)initWithPeripheral:(CBPeripheral *)peripheral RSSI:(NSNumber *)RSSI;

- (NSString *)stateStringValue;

@end
