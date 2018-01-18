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
@property (nonatomic, strong) NSMutableArray<CBCharacteristic *> *characteristics;

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
        self.characteristics = [NSMutableArray array];
        _bluetoothManager = [HLYBluetoothManager manager];
    }
    return self;
}

- (void)scanWithCompletionHandler:(HLYScanPeripheralsCompletionHandler)completionHandler {
    
    [self.bluetoothManager scanPeripheralsWithCompletionHandler:^(NSArray<HLYBluetoothDevice *> *devices, NSString *message) {
        
        // 过滤掉不是打印机类型的设备
        NSMutableArray<HLYBluetoothDevice *> *printers = [NSMutableArray array];
        [devices enumerateObjectsUsingBlock:^(HLYBluetoothDevice * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (obj.serviceID) {
                [printers addObject:obj];
            }
        }];

        if (completionHandler) {
            completionHandler([printers copy], message);
        }
    }];
}

- (void)connectPrinterDevice:(HLYBluetoothDevice *)device completionHandler:(void(^)(NSError *error))completionHandler {
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
        [self.peripheral writeValue:data forCharacteristic:[self.characteristics lastObject] type:CBCharacteristicWriteWithoutResponse];
        if (completionHandler) {
            completionHandler(nil);
        }
    } else {
        // 自动连接打印机
        __weak typeof(self) wSelf = self;
        [self.bluetoothManager autoConnectionPeripheralWithCompletionHandler:^(CBService *service, NSError *error) {
            
            __strong typeof(wSelf) self = wSelf;
            [self connectPeripheral:service.peripheral
                          serviceID:nil
                   characteristicID:nil
                  completionHandler:^(NSError *error) {
                      if (error) {
                          NSLog(@"自动连接打印机出错: %@", [error localizedDescription]);
                          NSError *error = [NSError errorWithDomain:@"HLYBluetoothPrint" code:0 userInfo:@{NSLocalizedDescriptionKey : @"打印机连接出错"}];
                          if (completionHandler) {
                              completionHandler(error);
                          }
                      } else {
                          __strong typeof(wSelf) self = wSelf;
                          [self.peripheral writeValue:data forCharacteristic:[self.characteristics lastObject] type:CBCharacteristicWriteWithoutResponse];
                      }
                  }];
        }];
    }
}

#pragma mark - Private Method

- (void)connectPeripheral:(CBPeripheral *)peripheral
                serviceID:(NSString *)serviceID
         characteristicID:(NSString *)characteristicID
        completionHandler:(void(^)(NSError *error))completionHandler {
    
    [self.characteristics removeAllObjects];
    
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
                NSLog(@"Characteristic Property Write Service:%@ , characteristic: %@", service, characteristic);
                [self.characteristics addObject:characteristic];
                if (self.peripheral != service.peripheral) {
                    self.peripheral = service.peripheral;
                    [self.bluetoothManager stopScanPeripheral];
                }
                if (completionHandler) {
                    completionHandler(nil);
                }
                break;
            }
        }
    } else {
        if (completionHandler) {
            completionHandler(error);
        }
    }
}

@end
