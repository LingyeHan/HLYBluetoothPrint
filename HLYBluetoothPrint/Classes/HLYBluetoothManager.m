//
//  HLYBluetoothManager.m
//
//  Created by 韩灵叶 on 2018/1/12.
//  Copyright © 2018年 WelfareMall. All rights reserved.
//

#import "HLYBluetoothManager.h"
#import "HLYBluetoothPrint.h"
#import <HLYBluetoothPrint/HLYBluetoothDevice.h>

typedef NS_ENUM(NSInteger, HLYBluetoothTimeoutType) {
    HLYBluetoothTimeoutTypeScan = 0,
    HLYBluetoothTimeoutTypeConnect,
    HLYBluetoothTimeoutTypeAutoConnect,
};

@interface HLYBluetoothManager () <CBCentralManagerDelegate, CBPeripheralManagerDelegate, CBPeripheralDelegate>

@property (nonatomic, strong) CBCentralManager      *centralManager;
@property (nonatomic, strong) CBPeripheralManager   *peripheralManager;

@property (nonatomic, copy) void(^checkBluetoothWithCompletionHandler)(BOOL isPoweredOn);
@property (nonatomic, copy) HLYScanPeripheralsCompletionHandler scanPeripheralsCompletionHandler;
@property (nonatomic, copy) void(^peripheralWriteCompletionHandler)(NSError *error);
@property (nonatomic, copy) void(^autoConnectedPeripheralCompletionHandler)(NSError *error);
@property (nonatomic, copy) void(^connectedPeripheralCompletionHandler)(NSError *error);
@property (nonatomic, copy) void(^disconnectCompletionHandler)(NSError *error);

@property (nonatomic, strong) NSString *serviceID;
@property (nonatomic, strong) NSString *characteristicID;

@property (nonatomic, strong) NSMutableArray<HLYBluetoothDevice *> *discoveredDevices;
@property (nonatomic, strong) NSMutableArray<CBCharacteristic *> *writeCharacteristics;

@property (nonatomic, strong) CBPeripheral *connectedPeripheral;

@property (nonatomic) NSTimeInterval timeoutInterval;

@end

#pragma mark - CBCentralManagerDelegate

@implementation HLYBluetoothManager
{
    dispatch_semaphore_t _syncLock;
}

+ (instancetype)manager {

    static HLYBluetoothManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[HLYBluetoothManager alloc] init];
    });
    return manager;
}

- (instancetype)init {
    
    self = [super init];
    if (self) {
        // 打印机服务、特征码
//        self.serviceID = @"E7810A71-73AE-499D-8C15-FAA9AEF0C3F2";
//        self.characteristicID = @"BEF8D6C9-9C21-4C9E-B632-BD58C1009F9F";
        self.discoveredDevices = [NSMutableArray array];
        self.writeCharacteristics = [NSMutableArray array];
    }
    return self;
}

#pragma mark - Public Method

- (void)checkBluetoothWithCompletionHandler:(void (^)(BOOL))completionHandler {
    
    self.checkBluetoothWithCompletionHandler = completionHandler;
    if (_centralManager) {
        completionHandler ? completionHandler(_centralManager.state == CBCentralManagerStatePoweredOn) : nil;
    } else {
        [self centralManager];
    }
}

- (BOOL)isConnected {
    
    if (!self.connectedPeripheral) {
        return NO;
    }
    
    return self.connectedPeripheral.state == CBPeripheralStateConnected;
}

- (NSString *)stateMessage {
    
    NSString *message = nil;
    switch (self.centralManager.state) {
        case CBCentralManagerStatePoweredOn:
            message = @"蓝牙已打开";
            break;
        case CBCentralManagerStatePoweredOff:
            message = @"蓝牙已关闭";
            break;
        case CBCentralManagerStateUnsupported:
            message = @"该设备不支持蓝牙";
            break;
        case CBCentralManagerStateUnauthorized:
            message = @"蓝牙未被授权";
            break;
        case CBCentralManagerStateResetting:
            message = @"蓝牙正在重置";
            break;
        case CBCentralManagerStateUnknown:
            message = @"未知蓝牙";
            break;
        default:
            break;
    }
    return message;
}

- (void)scanPeripheralsWithCompletionHandler:(HLYScanPeripheralsCompletionHandler)completionHandler {
    
    self.scanPeripheralsCompletionHandler = completionHandler;
    
    [self.discoveredDevices removeAllObjects];
    
    // 设置扫描、自动连接超时
    if (self.autoConnectedPeripheralCompletionHandler) {
        [self setTimeoutInterval:8 type:HLYBluetoothTimeoutTypeAutoConnect];
    } else {
        [self setTimeoutInterval:6 type:HLYBluetoothTimeoutTypeScan];
    }

    if (_centralManager) {
        [_centralManager scanForPeripheralsWithServices:nil options:nil];//@[[CBUUID UUIDWithString:self.serviceID]]
    } else {
        [self centralManager];
    }
}

// 自动连接
- (void)autoConnectPeripheralWithServiceID:(NSString *)serviceID
                          characteristicID:(NSString *)characteristicID
                         completionHandler:(void (^)(NSError *))completionHandler {
    
    self.connectedPeripheralCompletionHandler = NULL;
    // 没有连接过打印机直接报错
    if (![HLYBluetoothManager getRecentConnectionPeripheraUUID]) {
        self.autoConnectedPeripheralCompletionHandler = NULL;
        completionHandler ? completionHandler([NSError errorWithDomain:@"HLYBluetoothPeripheral" code:1 userInfo:@{NSLocalizedDescriptionKey : @"打印机还未设置，请设置打印机"}]) : nil;
        return;
    }
    
    self.serviceID = serviceID;
    self.characteristicID = characteristicID;
    self.autoConnectedPeripheralCompletionHandler = completionHandler;
    
    __weak typeof(self) wSelf = self;
    [self scanPeripheralsWithCompletionHandler:^(NSArray<HLYBluetoothDevice *> *devices, NSError *error) {
        __strong typeof(wSelf) self = wSelf;
        
        if (error || devices.count == 0) {
            completionHandler ? completionHandler([NSError errorWithDomain:@"HLYBluetoothPeripheral" code:1 userInfo:@{NSLocalizedDescriptionKey : @"未发现打印机"}]) : nil;
            self.autoConnectedPeripheralCompletionHandler = NULL;
        }
    }];
}

- (void)connectPeripheral:(CBPeripheral *)peripheral
                serviceID:(NSString *)serviceID
         characteristicID:(NSString *)characteristicID
        completionHandler:(void(^)(NSError *error))completionHandler {
    
    self.autoConnectedPeripheralCompletionHandler = NULL;
    [self _connectPeripheral:peripheral serviceID:serviceID characteristicID:characteristicID completionHandler:completionHandler];
}

- (void)_connectPeripheral:(CBPeripheral *)peripheral
                serviceID:(NSString *)serviceID
         characteristicID:(NSString *)characteristicID
        completionHandler:(void(^)(NSError *error))completionHandler {
    
    NSLog(@"调用连接方法 %@", peripheral);
    
    if (!peripheral) {
        return;
    }
    if (peripheral.state == CBPeripheralStateConnecting || peripheral.state == CBPeripheralStateConnected) {
        return;
    }
    self.serviceID = serviceID;
    self.characteristicID = characteristicID;
    [self.writeCharacteristics removeAllObjects];
    [self cancelCurrentConnection];
    
    self.connectedPeripheralCompletionHandler = completionHandler;
    // 设置连接超时(默认 5 秒)
    if (!self.autoConnectedPeripheralCompletionHandler) {
        [self setTimeoutInterval:5 type:HLYBluetoothTimeoutTypeConnect];
    }

    [self.centralManager connectPeripheral:peripheral options:nil];//@{CBConnectPeripheralOptionNotifyOnDisconnectionKey:@(YES)}
    //    [self.centralManager retrievePeripheralsWithIdentifiers:<#(nonnull NSArray<NSUUID *> *)#>];//
}

- (void)disconnectPeripheralConnection:(CBPeripheral *)peripheral completionHandler:(void(^)(NSError *error))completionHandler {
    
    if (!peripheral) {
        return;
    }
    
    self.disconnectCompletionHandler = completionHandler;
    [self cancelPeripheralConnection:peripheral];
    [HLYBluetoothManager removeRecentConnectionPeripheral];
}

- (void)cancelPeripheralConnection:(CBPeripheral *)peripheral {
    
    if (!peripheral) {
        return;
    }
    
    [self.centralManager cancelPeripheralConnection:peripheral];
    
    if (self.connectedPeripheral) {
        self.connectedPeripheral.delegate = nil;
        self.connectedPeripheral = nil;
    }
}

- (void)stopScanPeripheral {
    [self.centralManager stopScan];
}

- (void)cancelCurrentConnection {
    [self cancelPeripheralConnection:self.connectedPeripheral];
}

- (void)writeValue:(NSData *)data completionHandler:(void(^)(NSError *error))completionHandler {
    
    self.peripheralWriteCompletionHandler = completionHandler;
    // 自动连接打印时，会出现特征码还没取到就开始打印失败问题
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.writeCharacteristics.count > 0) {
            NSLog(@"可写特征码: %@", self.writeCharacteristics);
            
            [self.connectedPeripheral writeValue:data
                               forCharacteristic:self.characteristicID ?: [self.writeCharacteristics lastObject]
                                            type:CBCharacteristicWriteWithResponse];
        } else {
            NSLog(@"无法写入, 未发现设备可写特征码");
            if (self.peripheralWriteCompletionHandler) {
                self.peripheralWriteCompletionHandler([NSError errorWithDomain:@"HLYBluetoothManager" code:1 userInfo:@{NSLocalizedDescriptionKey : @"无法写入, 未发现设备可写特征码"}]);
            }
        }
//    });
}

#pragma mark - 外围设备 CBPeripheralManagerDelegate

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI {
    
    if (peripheral.name.length == 0) {
        return;
    }
    NSLog(@"发现蓝牙设备 [Peripheral=%@, AdvertisementData=%@, RSSI=%@]", peripheral, advertisementData, RSSI);
    
    __block BOOL isExist = NO;
    if (self.discoveredDevices.count > 0) {
        [self.discoveredDevices enumerateObjectsUsingBlock:^(HLYBluetoothDevice * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj.peripheral.identifier.UUIDString isEqualToString:peripheral.identifier.UUIDString]) {
                obj.RSSI = RSSI;
                isExist = YES;
                *stop = YES;
            }
        }];
    }
    if (!isExist) {
        HLYBluetoothDevice *bluetoothDevice = [[HLYBluetoothDevice alloc] initWithPeripheral:peripheral RSSI:RSSI];
        [self.discoveredDevices addObject:bluetoothDevice];
    }
    
    // 解析获取自动连接过外设的广播服务、特征码
    if (advertisementData && [peripheral.identifier.UUIDString isEqualToString:[HLYBluetoothManager getRecentConnectionPeripheraUUID]]) {
        NSArray *advDataServiceUUIDs = [advertisementData[@"kCBAdvDataServiceUUIDs"] copy];
        if (advDataServiceUUIDs.count >= 2 && ((CBUUID *)[advDataServiceUUIDs lastObject]).UUIDString.length == 36) {//E7810A71-73AE-499D-8C15-FAA9AEF0C3F2
            NSString *serviceID = ((CBUUID *)[advDataServiceUUIDs lastObject]).UUIDString;
            // 自动连接
            __weak typeof(self) wSelf = self;
            [self _connectPeripheral:peripheral
                           serviceID:serviceID
                    characteristicID:nil
                   completionHandler:^(NSError *error) {
                      __strong typeof(wSelf) self = wSelf;
                      
                      if (error) {
                          NSLog(@"自动连接设备失败: %@", error);
                      } else {
                          [self stopScanPeripheral];
                          NSLog(@"自动连接设备完成");
                      }
                  }];
        }
    }
    
    if (self.scanPeripheralsCompletionHandler) {
        self.scanPeripheralsCompletionHandler(self.discoveredDevices, nil);
    }
}

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    NSLog(@"蓝牙设备状态改变: %@", self.stateMessage);
}

#pragma mark - 外围设备 CBPeripheralDelegate

// 发现服务
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    NSLog(@"查找服务: %@", peripheral);
    
    if (error) {
        NSLog(@"未发现服务: %@", [error localizedDescription]);
    } else {
        for (CBService *service in peripheral.services) {
//            if (self.serviceID) {有问题，某些打印机会不打印
//                if([service.UUID isEqual:[CBUUID UUIDWithString:self.serviceID]]) {
//                    [service.peripheral discoverCharacteristics:self.characteristicID ? @[[CBUUID UUIDWithString:self.characteristicID]] : nil
//                                                     forService:service];
//                    break;
//                }
//            } else {
                [service.peripheral discoverCharacteristics:nil forService:service];
//            }
        }
    }
}

// 发现可写特征码
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(nullable NSError *)error {
    NSLog(@"查找特征码: %@", service);
    if (error) {
        NSLog(@"查找可写特征码出错: %@", [error localizedDescription]);
    } else {
        for (CBCharacteristic *characteristic in service.characteristics) {
            if (characteristic.properties & CBCharacteristicPropertyWrite) {
                [self.writeCharacteristics addObject:characteristic];
            }
        }
        // 执行自动连接回调块
        if (self.autoConnectedPeripheralCompletionHandler && self.writeCharacteristics.count > 0 && [peripheral.identifier.UUIDString isEqualToString:[HLYBluetoothManager getRecentConnectionPeripheraUUID]] && [service.UUID.UUIDString isEqualToString:self.serviceID]) {
            [self stopScanPeripheral];
            self.autoConnectedPeripheralCompletionHandler(error);
            self.autoConnectedPeripheralCompletionHandler = NULL;
            self.connectedPeripheralCompletionHandler = NULL;
        }
    }
}

// 写入值
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error {
    if (error) {
        NSLog(@"写入设备失败: %@", error);
    } else {
        NSLog(@"写入设备完成");
    }
//    [self cancelPeripheralConnection:peripheral];
    
    if (self.peripheralWriteCompletionHandler) {
        self.peripheralWriteCompletionHandler(error);
    }
}

#pragma mark - 中央设备 CBCentralManagerDelegate

/**
 * 中央设备状态更新
 */
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    
        if (central.state == CBCentralManagerStatePoweredOn) {
            [self.centralManager scanForPeripheralsWithServices:nil options:nil];//@{CBCentralManagerScanOptionAllowDuplicatesKey : @YES}
        } else {
            if (self.checkBluetoothWithCompletionHandler) {
                self.checkBluetoothWithCompletionHandler(central.state == CBCentralManagerStatePoweredOn);
                //        self.checkBluetoothWithCompletionHandler = NULL;
            }
        }
}

/**
 * 连接
 */
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"连接成功: %@", peripheral);

    self.connectedPeripheral = peripheral;
    self.connectedPeripheral.delegate = self;
    
//    [self.connectedPeripheral discoverServices:self.serviceID ? @[[CBUUID UUIDWithString:self.serviceID]] : nil];有问题，某些打印机会不打印
    [self.connectedPeripheral discoverServices:nil];
    
    [HLYBluetoothManager setRecentConnectionPeripheralUUID:peripheral.identifier.UUIDString];
    
    if (self.connectedPeripheralCompletionHandler) {
        self.connectedPeripheralCompletionHandler(nil);
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"连接失败: %@, %@", error, peripheral);

    if (self.connectedPeripheralCompletionHandler) {
        self.connectedPeripheralCompletionHandler(error);
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(nonnull CBPeripheral *)peripheral error:(nullable NSError *)error {
    NSLog(@"已断开连接: %@, %@", error, peripheral);
    
    self.disconnectCompletionHandler ? self.disconnectCompletionHandler(error) : nil;
    
    // 设备断开重连
    [self.centralManager connectPeripheral:peripheral options:nil];
}

//- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary<NSString *,id> *)dict {
//
//    NSArray *peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey];
//
//    _centralManager = central;
//    _centralManager.delegate = self;
//
//    for(CBPeripheral* peripheral in peripherals) {
//        if([peripheral.name isEqualToString:@"HLYBLEManagerIdentifier"]) {
//            NSLog(@"Restoring Connection");
//            self.connectedPeripheral = peripheral;
//            self.connectedPeripheral.delegate = self;
//
//            [_centralManager connectPeripheral:self.connectedPeripheral options:nil];
//            return;
//        }
//    }
//
//    [_centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:@"FFF0"]] options:nil];
//}

#pragma mark - Private Method

- (void)setTimeoutInterval:(NSTimeInterval)timeoutInterval type:(HLYBluetoothTimeoutType)type {
    
    NSAssert(timeoutInterval > 0, @"超时时间必须大于0");
    
//    NSLog(@"启动执行超时处理: %lf, %d", timeoutInterval, type);
    
    _timeoutInterval = timeoutInterval;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeoutInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        [self stopScanPeripheral];
        
        if (type == HLYBluetoothTimeoutTypeScan) {
            if (self.discoveredDevices.count > 0) {
                return;
            }
           
            if (self.scanPeripheralsCompletionHandler) {
                 NSLog(@"扫描超时");
                self.scanPeripheralsCompletionHandler(nil, [NSError errorWithDomain:@"HLYBluetoothPeripheral" code:1 userInfo:@{NSLocalizedDescriptionKey : @"扫描超时"}]);
                self.scanPeripheralsCompletionHandler = NULL;
            }
        } else {
            if (self.isConnected) {
                return;
            }
            
            if (type == HLYBluetoothTimeoutTypeConnect) {
                if (self.connectedPeripheralCompletionHandler) {
                    NSLog(@"连接超时");
                    self.connectedPeripheralCompletionHandler([NSError errorWithDomain:@"HLYBluetoothPeripheral" code:1 userInfo:@{NSLocalizedDescriptionKey : @"连接超时"}]);
                    self.connectedPeripheralCompletionHandler = NULL;
                }
            } else if (type == HLYBluetoothTimeoutTypeAutoConnect) {
                if (self.autoConnectedPeripheralCompletionHandler) {
                    NSLog(@"自动连接超时");
                    self.autoConnectedPeripheralCompletionHandler([NSError errorWithDomain:@"HLYBluetoothPeripheral" code:1 userInfo:@{NSLocalizedDescriptionKey : @"连接超时"}]);
                    self.autoConnectedPeripheralCompletionHandler = NULL;
                }
            }
        }
    });
}

#pragma mark - Getter Method

- (CBCentralManager *)centralManager {
    if (!_centralManager) {
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil
                                                             options:@{CBCentralManagerOptionShowPowerAlertKey : [NSNumber numberWithBool:NO]//,
                                                                      // CBCentralManagerOptionRestoreIdentifierKey : @"HLYBLEManagerIdentifier"
                                                                       }];
    }
    return _centralManager;
}

#pragma mark - Class Method

+ (NSString *)getRecentConnectionPeripheraUUID {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    return [userDefaults objectForKey:@"HLYBluetoothPeripheralUUID"];
}

+ (void)setRecentConnectionPeripheralUUID:(NSString *)UUID {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:UUID forKey:@"HLYBluetoothPeripheralUUID"];
    [userDefaults synchronize];
}

+ (void)removeRecentConnectionPeripheral {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults removeObjectForKey:@"HLYBluetoothPeripheralUUID"];
    [userDefaults synchronize];
}

@end
