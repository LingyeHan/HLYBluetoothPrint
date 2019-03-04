//
//  HLYBluetoothManager.h
//
//  Created by 韩灵叶 on 2018/1/12.
//  Copyright © 2018年 WelfareMall. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@class HLYBluetoothDevice;

typedef void (^HLYScanPeripheralsCompletionHandler)(NSArray<HLYBluetoothDevice *> *devices, NSError *error);

@interface HLYBluetoothManager : NSObject

// CBCentralManager 的创建是异步的，如果初始化完成之后没有被当前创建它的类所持有，就会在下一次 RunLoop 迭代的时候释放。
// 当然 CBCentralManager 实例如果不是在 ViewController 中创建的，那么持有 CBCentralManager 的这个类在初始化之后也必须被 ViewController 持有，否则控制台会有如下的错误输出：[CoreBluetooth] XPC connection invalid
//@property (nonatomic, strong) UIViewController *viewController;
@property (nonatomic, readonly) BOOL isConnected;
@property (nonatomic, readonly) BOOL hasConnectedPrinter;
@property (nonatomic, readonly) NSString *stateMessage;
@property (nonatomic, copy) void(^disconnectCompletionHandler)(NSError *error);

+ (instancetype)manager;

- (void)checkBluetoothWithCompletionHandler:(void(^)(BOOL isPoweredOn))completionHandler;

- (void)scanPeripheralsWithCompletionHandler:(HLYScanPeripheralsCompletionHandler)completionHandler;

- (void)stopScanPeripheral;

- (void)cancelCurrentConnection;

- (void)autoConnectPeripheralWithServiceID:(NSString *)serviceID
                          characteristicID:(NSString *)characteristicID
                         completionHandler:(void (^)(NSError *))completionHandler;

- (void)connectPeripheral:(CBPeripheral *)peripheral
                serviceID:(NSString *)serviceID
         characteristicID:(NSString *)characteristicID
        completionHandler:(void(^)(NSError *error))completionHandler;

- (void)disconnectPeripheralConnection:(CBPeripheral *)peripheral completionHandler:(void(^)(NSError *error))completionHandler;

- (void)writeValue:(NSData *)data completionHandler:(void(^)(NSError *error))completionHandler;

@end
