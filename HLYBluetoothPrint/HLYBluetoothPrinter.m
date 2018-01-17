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
            NSLog(@"Characteristic Service:%@ UUID: %@", service, characteristic.UUID);
            CBCharacteristicProperties properties = characteristic.properties;
            if (properties & CBCharacteristicPropertyWrite) {
                NSLog(@"Characteristic Property Write Service:%@ UUID: %@", service, characteristic.UUID);
                [self.characteristics addObject:characteristic];
                if (self.peripheral != service.peripheral) {
                    self.peripheral = service.peripheral;
                    [self.bluetoothManager stopScanPeripheral];
                    if (completionHandler) {
                        completionHandler(error);
                    }
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

/*
- (NSData *)testData {
    // 打印机支持的文字编码
    NSLog(@"goodsArray:%@",goodsArray);
    // 用到的goodsArray跟github中的商品数组是一样的。
    NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    
    NSString *title = @"测试电商";
    NSString *str1 = @"测试电商服务中心(销售单)";
    NSString *line = @"- - - - - - - - - - - - - - - -";
    NSString *time = @"时间:2016-04-27 10:01:50";
    NSString *orderNum = @"订单编号:4000020160427100150";
    NSString *address = @"地址:深圳市南山区学府路东科技园店";
    
    //初始化打印机
    Byte initBytes[] = {0x1B,0x40};
    NSData *initData = [NSData dataWithBytes:initBytes length:sizeof(initBytes)];
    
    //换行
    Byte nextRowBytes[] = {0x0A};
    NSData *nextRowData = [NSData dataWithBytes:nextRowBytes length:sizeof(nextRowBytes)];
    
    //居中
    Byte centerBytes[] = {0x1B,0x61,1};
    NSData *centerData= [NSData dataWithBytes:centerBytes length:sizeof(centerBytes)];
    
    //居左
    Byte leftBytes[] = {0x1B,0x61,0};
    NSData *leftdata= [NSData dataWithBytes:leftBytes length:sizeof(leftBytes)];
    
    NSMutableData *mainData = [[NSMutableData alloc]init];
    
    //初始化打印机
    [mainData appendData:initData];
    //设置文字居中/居左
    [mainData appendData:centerData];
    [mainData appendData:[title dataUsingEncoding:enc]];
    [mainData appendData:nextRowData];
    [mainData appendData:[str1 dataUsingEncoding:enc]];
    [mainData appendData:nextRowData];
    
    //            UIImage *qrImage =[MMQRCode createBarImageWithOrderStr:@"RN3456789012"];
    //            UIImage *qrImage =[MMQRCode qrCodeWithString:@"http://www.sina.com" logoName:nil size:400];
    //            qrImage = [self scaleCurrentImage:qrImage];
    //
    //            NSData *data = [IGThermalSupport imageToThermalData:qrImage];
    //            [mainData appendData:centerData];
    //            [mainData appendData:data];
    //            [mainData appendData:nextRowData];
    
    [mainData appendData:leftdata];
    [mainData appendData:[line dataUsingEncoding:enc]];
    [mainData appendData:nextRowData];
    [mainData appendData:[time dataUsingEncoding:enc]];
    [mainData appendData:nextRowData];
    [mainData appendData:[orderNum dataUsingEncoding:enc]];
    [mainData appendData:nextRowData];
    [mainData appendData:[address dataUsingEncoding:enc]];
    [mainData appendData:nextRowData];
    
    [mainData appendData:[line dataUsingEncoding:enc]];
    [mainData appendData:nextRowData];
    NSString *name = @"商品";
    NSString *number = @"数量";
    NSString *price = @"单价";
    [mainData appendData:leftdata];
    [mainData appendData:[name dataUsingEncoding:enc]];
    
    Byte spaceBytes1[] = {0x1B, 0x24, 150 % 256, 0};
    NSData *spaceData1 = [NSData dataWithBytes:spaceBytes1 length:sizeof(spaceBytes1)];
    [mainData appendData:spaceData1];
    [mainData appendData:[number dataUsingEncoding:enc]];
    
    Byte spaceBytes2[] = {0x1B, 0x24, 300 % 256, 1};
    NSData *spaceData2 = [NSData dataWithBytes:spaceBytes2 length:sizeof(spaceBytes2)];
    [mainData appendData:spaceData2];
    [mainData appendData:[price dataUsingEncoding:enc]];
    [mainData appendData:nextRowData];
    
    CGFloat total = 0.0;
    for (NSDictionary *dict in goodsArray) {
        [mainData appendData:[dict[@"name"] dataUsingEncoding:enc]];
        
        Byte spaceBytes1[] = {0x1B, 0x24, 150 % 256, 0};
        NSData *spaceData1 = [NSData dataWithBytes:spaceBytes1 length:sizeof(spaceBytes1)];
        [mainData appendData:spaceData1];
        [mainData appendData:[dict[@"amount"] dataUsingEncoding:enc]];
        
        Byte spaceBytes2[] = {0x1B, 0x24, 300 % 256, 1};
        NSData *spaceData2 = [NSData dataWithBytes:spaceBytes2 length:sizeof(spaceBytes2)];
        [mainData appendData:spaceData2];
        [mainData appendData:[dict[@"price"] dataUsingEncoding:enc]];
        [mainData appendData:nextRowData];
        
        total += [dict[@"price"] floatValue] * [dict[@"amount"] intValue];
    }
    
    [mainData appendData:[line dataUsingEncoding:enc]];
    [mainData appendData:nextRowData];
    [mainData appendData:[@"总计:" dataUsingEncoding:enc]];
    Byte spaceBytes[] = {0x1B, 0x24, 300 % 256, 1};
    NSData *spaceData = [NSData dataWithBytes:spaceBytes length:sizeof(spaceBytes)];
    [mainData appendData:spaceData];
    NSString *totalStr = [NSString stringWithFormat:@"%.2f",total];
    [mainData appendData:[totalStr dataUsingEncoding:enc]];
    [mainData appendData:nextRowData];
    
    [mainData appendData:[line dataUsingEncoding:enc]];
    [mainData appendData:nextRowData];
    [mainData appendData:centerData];
    [mainData appendData:[@"谢谢惠顾，欢迎下次光临!" dataUsingEncoding:enc]];
    [mainData appendData:nextRowData];
    
    return mainData;
}
*/
@end
