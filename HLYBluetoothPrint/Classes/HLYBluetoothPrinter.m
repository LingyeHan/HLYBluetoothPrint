//
//  HLYBluetoothPrinter.m
//
//  Created by 韩灵叶 on 2018/1/15.
//  Copyright © 2018年 WelfareMall. All rights reserved.
//

#import "HLYBluetoothPrinter.h"
#import "HLYBluetoothPrint.h"

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

- (void)setBluetoothAvailableCompletionHandler:(HLYBluetoothAvailableCompletionHandler)bluetoothAvailableCompletionHandler {
    self.bluetoothManager.bluetoothAvailableCompletionHandler = bluetoothAvailableCompletionHandler;
}

- (void)scanWithCompletionHandler:(HLYScanPeripheralsCompletionHandler)completionHandler {
    
    // 设置设备自动连接回调处理
    __weak typeof(self) wSelf = self;
    [self.bluetoothManager setAutoConnectionCompletionHandler:^(CBService *service, NSError *error) {
        __strong typeof(wSelf) self = wSelf;
        [self handleCharacteristicsForPeripheralWithService:service error:error completionHandler:^(NSError *error) {
            self.autoConnectionCompletionHandler ? self.autoConnectionCompletionHandler(error) : nil;
        }];
    }];
    
    __block BOOL isCallbackCompleted = NO;
    [self.bluetoothManager scanPeripheralsWithCompletionHandler:^(NSArray<HLYBluetoothDevice *> *devices, NSError *error) {
        
        if (error) {
            completionHandler ? completionHandler(nil, error) : nil;
            return;
        }
        
        // 过滤掉不是打印机类型的设备
        NSMutableArray<HLYBluetoothDevice *> *printers = [NSMutableArray array];
        [devices enumerateObjectsUsingBlock:^(HLYBluetoothDevice * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (obj.serviceID) {
                [printers addObject:obj];
            }
        }];

        if (completionHandler) {
            if (printers.count > 0) {
                isCallbackCompleted = YES;
                completionHandler([printers copy], error);
            } else {
                // 扫描超时为 5 秒回调
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if (!isCallbackCompleted) {
                        completionHandler([printers copy], error);
                    }
                });
            }
        }
    }];
}

- (void)stopScan {
    [self.bluetoothManager stopScanPeripheral];
}

- (void)connectWithDevice:(HLYBluetoothDevice *)device completionHandler:(void(^)(NSError *error))completionHandler {
    
    [self connectPeripheral:device.peripheral
                  serviceID:device.serviceID
           characteristicID:device.characteristicID
          completionHandler:completionHandler];
}

- (void)disconnectWithDevice:(HLYBluetoothDevice *)device completionHandler:(void(^)(NSError *error))completionHandler {
    
    [self.bluetoothManager disconnectPeripheralConnection:device.peripheral completionHandler:completionHandler];
}

- (BOOL)isConnected {
    return [self.bluetoothManager isConnected];
}

/**
 * 发送打印数据
 *
 * @param data 需要打印的数据
 * @param completionHandler 打印完成回调
 */
- (void)sendData:(NSData *)data completionHandler:(void(^)(NSError *error))completionHandler {
    
    // 检查打印机是否已连接
    if (self.isConnected) {
        if (self.writeCharacteristics.count > 0) {
            // 设置写入打印机数据回调
            [self.bluetoothManager setPeripheralWriteCompletionHandler:^(NSError *error) {
                completionHandler ? completionHandler(error) : nil;
            }];
            NSLog(@"开始写入打印机数据...");
//            completionHandler(nil);
            [self.peripheral writeValue:data forCharacteristic:[self.writeCharacteristics lastObject] type:CBCharacteristicWriteWithResponse];
        } else {
             completionHandler ? completionHandler([NSError errorWithDomain:@"HLYBluetoothPrint" code:1 userInfo:@{NSLocalizedDescriptionKey : @"未找到蓝牙打印机特征码"}]) : nil;
        }
    } else { // 自动连接打印机
        // 设置打印机自动连接回调处理
        __weak typeof(self) wSelf = self;
        [self setAutoConnectionCompletionHandler:^(NSError *error) {
            __strong typeof(wSelf) self = wSelf;
            if (error) {
                NSLog(@"自动连接打印机出错: %@", error);
                completionHandler ? completionHandler(error) : nil;
            } else {
                NSLog(@"自动连接打印机完成");
                __strong typeof(wSelf) self = wSelf;
                [self sendData:data completionHandler:completionHandler];
            }
        }];
        
        // 开始扫描打印机，找到匹配的打印机会自动连接 (注意: 因为在扫描中，会存在无限回调)
        __block BOOL isCallbackCompleted = NO;
        [self scanWithCompletionHandler:^(NSArray<HLYBluetoothDevice *> *devices, NSError *error) {
            if (error) {
                NSLog(@"自动扫描打印机出错: %@", error);
                [self stopScan];
                if (!isCallbackCompleted) {//剔除多次回调
                    isCallbackCompleted = YES;
                    completionHandler ? completionHandler(error) : nil;
                }
            } else {
                NSLog(@"自动扫描打印机完成: %@", devices);
                // 未找到或未连接上打印机，等待 5 秒后回调
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if (!self.isConnected) {
                        [self stopScan];
                        if (!isCallbackCompleted) {//剔除多次回调
                            isCallbackCompleted = YES;
                            completionHandler ? completionHandler([NSError errorWithDomain:@"HLYBluetoothPrint" code:1 userInfo:@{NSLocalizedDescriptionKey : devices.count > 0 ? @"未连接打印机" : @"未扫描到打印机"}]) : nil;
                        }
                    }
                });
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
                    [self stopScan];
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
