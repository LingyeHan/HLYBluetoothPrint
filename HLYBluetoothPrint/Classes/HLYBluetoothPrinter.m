//
//  HLYBluetoothPrinter.m
//
//  Created by 韩灵叶 on 2018/1/15.
//  Copyright © 2018年 WelfareMall. All rights reserved.
//

#import "HLYBluetoothPrinter.h"
#import "HLYBluetoothManager.h"

@interface HLYBluetoothPrinter ()

@property (nonatomic, strong) HLYBluetoothManager *bluetoothManager;
@property (nonatomic, strong) CBPeripheral *peripheral;
@property (nonatomic, strong) NSMutableArray<CBCharacteristic *> *writeCharacteristics;

@end

@implementation HLYBluetoothPrinter

+ (instancetype)printer {
    
    static HLYBluetoothPrinter *printer = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        printer = [[[self class] alloc] init];
    });
    return printer;
}

- (instancetype)init {
    
    self = [super init];
    if (self) {
        self.writeCharacteristics = [NSMutableArray array];
        _bluetoothManager = [HLYBluetoothManager manager];
    }
    return self;
}

- (void)scanWithCompletionHandler:(HLYScanPeripheralsCompletionHandler)completionHandler {
    
    // 设置自动打印机连接回调处理
    __weak typeof(self) wSelf = self;
    [self.bluetoothManager setAutoConnectionCompletionHandler:^(CBService *service, NSError *error) {
        __strong typeof(wSelf) self = wSelf;
        [self handleCharacteristicsForPeripheralWithService:service error:error completionHandler:^(NSError *error) {
            if (error) {
                NSLog(@"自动连接打印机出错: %@", error);
            } else {
                NSLog(@"自动连接打印机完成");
            }
            self.autoConnectionCompletionHandler ? self.autoConnectionCompletionHandler(error) : nil;
        }];
    }];
    
    __block BOOL isFound = NO;
    [self.bluetoothManager scanPeripheralsWithCompletionHandler:^(NSArray<HLYBluetoothDevice *> *devices, NSError *error) {
        
        // 过滤掉不是打印机类型的设备
        NSMutableArray<HLYBluetoothDevice *> *printers = [NSMutableArray array];
        [devices enumerateObjectsUsingBlock:^(HLYBluetoothDevice * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (obj.serviceID) {
                [printers addObject:obj];
            }
        }];

        if (completionHandler) {
            if (printers.count > 0) {
                isFound = YES;
                completionHandler([printers copy], error);
            } else {
                // 扫描超时为 5 秒
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    isFound ? nil : completionHandler([printers copy], error);
                });
            }
        }
    }];
}

- (void)connectWithDevice:(HLYBluetoothDevice *)device completionHandler:(void(^)(NSError *error))completionHandler {
    
    [self connectPeripheral:device.peripheral
                  serviceID:device.serviceID
           characteristicID:device.characteristicID
          completionHandler:completionHandler];
}

- (BOOL)isConnected {
    return [self.bluetoothManager isConnected];
}

/**
 发送打印数据
 @param data 需要打印的数据
 @param completionHandler 打印完成回调
 */
- (void)sendData:(NSData *)data completionHandler:(void(^)(NSError *error))completionHandler {
    
    if (self.isConnected) {
        if (self.writeCharacteristics.count > 0) {
            [self.bluetoothManager setPeripheralWriteCompletionHandler:^(NSError *error) {
                completionHandler ? completionHandler(error) : nil;
            }];
            [self.peripheral writeValue:data forCharacteristic:[self.writeCharacteristics lastObject] type:CBCharacteristicWriteWithResponse];
        } else {
             completionHandler ? completionHandler([NSError errorWithDomain:@"HLYBluetoothPrint" code:1 userInfo:@{NSLocalizedDescriptionKey : @"未找到蓝牙打印机特征码"}]) : nil;
        }
    } else {
        // 设置自动打印机连接回调处理
        __weak typeof(self) wSelf = self;
        [self.bluetoothManager setAutoConnectionCompletionHandler:^(CBService *service, NSError *error) {
            __strong typeof(wSelf) self = wSelf;
            [self handleCharacteristicsForPeripheralWithService:service error:error completionHandler:^(NSError *error) {
                if (error) {
                    NSLog(@"自动连接打印机出错: %@", error);
                    completionHandler ? completionHandler(error) : nil;
                } else {
                    NSLog(@"自动连接打印机完成");
                    __strong typeof(wSelf) self = wSelf;
                    [self sendData:data completionHandler:completionHandler];
                }
            }];
        }];
        // 扫描打印机且会自动连接
        [self scanWithCompletionHandler:^(NSArray<HLYBluetoothDevice *> *devices, NSError *error) {
            if (error) {
                NSLog(@"自动扫描打印机出错: %@", error);
                completionHandler ? completionHandler(error) : nil;
            } else {
                NSLog(@"自动扫描打印机完成: %@", devices);
            }
        }];
    }
}

#pragma mark - Private Method

- (void)connectPeripheral:(CBPeripheral *)peripheral
                serviceID:(NSString *)serviceID
         characteristicID:(NSString *)characteristicID
        completionHandler:(void(^)(NSError *error))completionHandler {
    
    [self.writeCharacteristics removeAllObjects];
    
    __weak typeof(self) wSelf = self;
    [self.bluetoothManager connectPeripheral:peripheral serviceID:serviceID characteristicID:characteristicID completionHandler:^(CBService *service, NSError *error) {
        
        __strong typeof(wSelf) self = wSelf;
        [self handleCharacteristicsForPeripheralWithService:service error:error completionHandler:completionHandler];
    }];
}

- (void)handleCharacteristicsForPeripheralWithService:(CBService *)service error:(NSError *)error completionHandler:(void(^)(NSError *error))completionHandler {
    
    if (!error) {
        for (CBCharacteristic *characteristic in service.characteristics) {
//            NSLog(@"Characteristic Service:%@ UUID: %@", service, characteristic.UUID);
            CBCharacteristicProperties properties = characteristic.properties;
            if (properties & CBCharacteristicPropertyWrite) {
                NSLog(@"Characteristic Property Write Peripheral: %@, Service: %@, Characteristic: %@", service.peripheral, service, characteristic);
                [self.writeCharacteristics addObject:characteristic];
                if (self.peripheral != service.peripheral) {
                    self.peripheral = service.peripheral;
                    // 只到找到打印机特征码才停止扫描
                    [self.bluetoothManager stopScanPeripheral];
                }
                break;
            }
        }
    }
    if (completionHandler) {
        completionHandler(error);
    }
}

@end
