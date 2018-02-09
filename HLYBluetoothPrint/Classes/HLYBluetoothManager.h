//
//  HLYBluetoothManager.h
//
//  Created by 韩灵叶 on 2018/1/12.
//  Copyright © 2018年 WelfareMall. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@class HLYBluetoothDevice;

typedef void (^HLYBluetoothAvailableCompletionHandler)(BOOL available);
typedef void (^HLYScanPeripheralsCompletionHandler)(NSArray<HLYBluetoothDevice *> *devices, NSError *error);
typedef void (^HLYConnectedPeripheralCompletionHandler)(CBService *service, NSError *error);
typedef void (^HLYPeripheralWriteCompletionHandler)(NSError *error);

@interface HLYBluetoothManager : NSObject

@property (nonatomic, readonly) BOOL isConnected;
@property (nonatomic, readonly) NSString *stateMessage;
@property (nonatomic, copy) HLYBluetoothAvailableCompletionHandler bluetoothAvailableCompletionHandler;
//@property (nonatomic, copy) HLYBluetoothStateUpdateBlock bluetoothStateUpdateBlock;
@property (nonatomic, copy) HLYConnectedPeripheralCompletionHandler autoConnectionCompletionHandler;
@property (nonatomic, copy) HLYPeripheralWriteCompletionHandler peripheralWriteCompletionHandler;

+ (instancetype)manager;

- (void)scanPeripheralsWithCompletionHandler:(HLYScanPeripheralsCompletionHandler)completionHandler;

- (void)stopScanPeripheral;

- (void)connectPeripheral:(CBPeripheral *)peripheral
                serviceID:(NSString *)serviceID
         characteristicID:(NSString *)characteristicID
        completionHandler:(HLYConnectedPeripheralCompletionHandler)completionHandler;

- (void)disconnectPeripheralConnection:(CBPeripheral *)peripheral completionHandler:(void(^)(NSError *error))completionHandler;

@end
