//
//  HLYBluetoothManager.m
//
//  Created by 韩灵叶 on 2018/1/12.
//  Copyright © 2018年 WelfareMall. All rights reserved.
//

#import "HLYBluetoothManager.h"
#import "HLYBluetoothPrint.h"

@interface HLYBluetoothManager () <CBCentralManagerDelegate, CBPeripheralManagerDelegate, CBPeripheralDelegate>

// 接收蓝牙信号的是中央设备(客户端、手机)
@property (nonatomic, strong) CBCentralManager      *centralManager;
// 外设
@property (nonatomic, strong) CBPeripheralManager   *peripheralManager;

@property (nonatomic, assign) CBCharacteristicProperties characteristicProperties;

@property (nonatomic, copy) HLYScanPeripheralsCompletionHandler scanPeripheralsCompletionHandler;
@property (nonatomic, copy) HLYConnectedPeripheralCompletionHandler connectedPeripheralCompletionHandler;
@property (nonatomic, copy) void(^disconnectCompletionHandler)(NSError *error);
@property (nonatomic, strong) NSMutableArray<HLYBluetoothDevice *> *discoveredDevices;

@property (nonatomic, strong) CBPeripheral *connectedPeripheral;
@property (nonatomic, strong) NSString *serviceID;
@property (nonatomic, strong) NSString *characteristicID;

@end

#pragma mark - CBCentralManagerDelegate

@implementation HLYBluetoothManager

+ (instancetype)manager {
    
    static HLYBluetoothManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[[self class] alloc] init];
    });
    return manager;
}

- (instancetype)init {
    
    self = [super init];
    if (self) {
        _discoveredDevices = [NSMutableArray array];
    }
    return self;
}

#pragma mark - Public Method

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
    
    [self.discoveredDevices removeAllObjects];
    self.scanPeripheralsCompletionHandler = completionHandler;
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:@{CBCentralManagerOptionShowPowerAlertKey : [NSNumber numberWithBool:YES]}];
}

- (void)connectPeripheral:(CBPeripheral *)peripheral
                serviceID:(NSString *)serviceID
         characteristicID:(NSString *)characteristicID
        completionHandler:(HLYConnectedPeripheralCompletionHandler)completionHandler {
    
    self.connectedPeripheralCompletionHandler = completionHandler;
    if (!peripheral) {
        return;
    }
    if (peripheral.state == CBPeripheralStateConnecting || peripheral.state == CBPeripheralStateConnected) {
        return;
    }
    
    if (self.connectedPeripheral) {
        [self cancelPeripheralConnection:self.connectedPeripheral];
    }
    
    self.serviceID = serviceID;
    self.characteristicID = characteristicID;
    self.connectedPeripheral = peripheral;
    self.connectedPeripheral.delegate = self;
    
    [self.centralManager connectPeripheral:self.connectedPeripheral options:nil];//@{CBConnectPeripheralOptionNotifyOnDisconnectionKey:@(YES)}
    
    // 连接超时默认 5 秒
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self connectTimeout];
    });
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

#pragma mark - CBCentralManagerDelegate

/**
 * 中央设备状态改变
 */
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {

    [self bluetoothAvailable:central.state == CBCentralManagerStatePoweredOn];
    if (central.state == CBCentralManagerStatePoweredOn) {
        [self.centralManager scanForPeripheralsWithServices:nil options:nil];
    }
//    self.bluetoothStateUpdateBlock ? self.bluetoothStateUpdateBlock(peripheral.state) : nil;
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    
    [self.connectedPeripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    self.connectedPeripheralCompletionHandler(nil, error);
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(nonnull CBPeripheral *)peripheral error:(nullable NSError *)error {
    NSLog(@"蓝牙设备已断开连接: %@", peripheral);
    
    self.disconnectCompletionHandler ? self.disconnectCompletionHandler(error) : nil;
    
    // 设备断开重连
//    [self connectPeripheral:self.connectedPeripheral
//                  serviceID:self.serviceID
//           characteristicID:self.characteristicID
//          completionHandler:self.connectedPeripheralCompletionHandler];
}

#pragma mark - CBPeripheralManagerDelegate

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    NSLog(@"蓝牙设备状态改变: %@", self.stateMessage);
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI {
    
    if (peripheral.name.length == 0) {
        return;
    }
    NSLog(@"Discovered Peripheral [Peripheral=%@, AdvertisementData=%@, RSSI=%@]", peripheral, advertisementData, RSSI);
          
    __block BOOL isExist = NO;
    if (self.discoveredDevices.count > 0) {
        // 更新蓝牙外设信号强度
        [self.discoveredDevices enumerateObjectsUsingBlock:^(HLYBluetoothDevice * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj.peripheral.identifier.UUIDString isEqualToString:peripheral.identifier.UUIDString]) {
                obj.RSSI = RSSI;
                isExist = YES;
                if (!obj.serviceID) {
                    // 第一个值为 ServiceID, 第二个值为 CharacteristicID
                    NSArray *serviceUUIDs = [advertisementData objectForKey:@"kCBAdvDataServiceUUIDs"];
                    if (serviceUUIDs) {
                        obj.serviceID = ((NSUUID *)[serviceUUIDs lastObject]).UUIDString;
                        //obj.characteristicID = serviceUUIDs.count > 1 ? ((NSUUID *)serviceUUIDs[1]).UUIDString : nil;
//                    } else {
                        // 没找到 ServiceUUID 重扫描，直到找到 ServiceUUID 为止
//                        [self scanPeripheralsWithCompletionHandler:self.scanPeripheralsCompletionHandler];
                    }
                }
                // 自动连接
                if (obj.serviceID && (obj.peripheral.state != CBPeripheralStateConnected && obj.peripheral.state != CBPeripheralStateConnecting)) {
                    [self autoConnectionPeripheral:obj.peripheral serviceID:obj.serviceID];
                }
                *stop = YES;
            }
        }];
    }
    if (!isExist) {
        HLYBluetoothDevice *bluetoothDevice = [[HLYBluetoothDevice alloc] initWithPeripheral:peripheral RSSI:RSSI];
        [self.discoveredDevices addObject:bluetoothDevice];
    }

    if (self.scanPeripheralsCompletionHandler) {
        self.scanPeripheralsCompletionHandler([self.discoveredDevices copy], nil);
    }
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    
    if (error) {
        self.connectedPeripheralCompletionHandler(nil, error);
    } else {
        for (CBService *service in peripheral.services) {
            if (self.serviceID) {
                if([service.UUID isEqual:[CBUUID UUIDWithString:self.serviceID]]) {
                    [service.peripheral discoverCharacteristics:(self.characteristicID ? @[[CBUUID UUIDWithString:self.characteristicID]] : nil)
                                                     forService:service];
                    break;
                }
            } else {
                [service.peripheral discoverCharacteristics:nil forService:service];
            }
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(nullable NSError *)error {
    
    [HLYBluetoothManager setRecentConnectionPeripheralUUID:peripheral.identifier.UUIDString];
    self.connectedPeripheralCompletionHandler(service, error);
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error {
    if (error) {
        NSLog(@"设备写入失败: %@", error);
    } else {
        NSLog(@"设备写入完成");
    }
    if (self.peripheralWriteCompletionHandler) {
        self.peripheralWriteCompletionHandler(error);
    }
}

#pragma mark - Private Method

- (void)autoConnectionPeripheral:(CBPeripheral *)peripheral serviceID:(NSString *)serviceID {
    
    if (self.isConnected) {
        return;
    }
    
    if (([peripheral.identifier.UUIDString isEqualToString:[HLYBluetoothManager getRecentConnectionPeripheraUUID]])) {
        __weak typeof(self) wSelf = self;
        [self connectPeripheral:peripheral
                      serviceID:serviceID
               characteristicID:nil
              completionHandler:^(CBService *service, NSError *error) {
                  __strong typeof(wSelf) self = wSelf;
//                  if (error) {
//                      NSLog(@"自动连接设备失败: %@", error);
//                  } else {
//                      NSLog(@"自动连接设备成功: %@", service);
//                  }
                  if (self.autoConnectionCompletionHandler) {
                      self.autoConnectionCompletionHandler(service, error);
                  }
              }];
    }
}

- (void)bluetoothAvailable:(BOOL)available {
    if (self.bluetoothAvailableCompletionHandler) {
        self.bluetoothAvailableCompletionHandler(available);
//        self.bluetoothAvailableCompletionHandler = NULL;
    }
}

- (void)connectTimeout {
    
    if (self.isConnected) {
        return;
    }
    
    [self cancelPeripheralConnection:self.connectedPeripheral];
    if (self.connectedPeripheralCompletionHandler) {
        self.connectedPeripheralCompletionHandler(nil, [NSError errorWithDomain:@"HLYBluetoothPeripheral" code:1 userInfo:@{NSLocalizedDescriptionKey : @"蓝牙设备连接超时"}]);
    }
}

#pragma mark - Getter Method

//- (CBCentralManager *)centralManager {
//    if (!_centralManager) {
//        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
//    }
//    return _centralManager;
//}

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
