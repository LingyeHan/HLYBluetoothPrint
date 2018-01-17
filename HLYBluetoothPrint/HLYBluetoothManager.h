//
//  HLYBluetoothManager.h
//
//  Created by 韩灵叶 on 2018/1/12.
//  Copyright © 2018年 WelfareMall. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "HLYBluetoothDevice.h"

typedef void (^HLYScanPeripheralsCompletionHandler)(NSArray<HLYBluetoothDevice *> *devices, NSString *message);
typedef void (^HLYConnectedPeripheralCompletionHandler)(CBService *service, NSError *error);

@interface HLYBluetoothManager : NSObject

@property (nonatomic, readonly) BOOL isConnected;

+ (instancetype)manager;

- (void)scanPeripheralsWithCompletionHandler:(HLYScanPeripheralsCompletionHandler)completionHandler;

- (void)stopScanPeripheral;

- (void)connectPeripheral:(CBPeripheral *)peripheral
                serviceID:(NSString *)serviceID
         characteristicID:(NSString *)characteristicID
        completionHandler:(HLYConnectedPeripheralCompletionHandler)completionHandler;

- (void)autoConnectionPeripheralWithCompletionHandler:(HLYConnectedPeripheralCompletionHandler)completionHandler;

@end
