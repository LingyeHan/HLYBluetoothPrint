//
//  HLYBluetoothManager.m
//
//  Created by 韩灵叶 on 2018/1/12.
//  Copyright © 2018年 WelfareMall. All rights reserved.
//

#import "HLYBluetoothManager.h"
#import "HLYBluetoothDevice.h"

@interface HLYBluetoothManager () <CBCentralManagerDelegate, CBPeripheralManagerDelegate, CBPeripheralDelegate>

// 接收蓝牙信号的是中央设备(客户端、手机)
@property (nonatomic, strong) CBCentralManager      *centralManager;
// 外设
@property (nonatomic, strong) CBPeripheralManager   *peripheralManager;

@property (nonatomic, assign) CBCharacteristicProperties characteristicProperties;

@property (nonatomic, strong) NSMutableArray<HLYBluetoothDevice *> *discoveredDevices;
@property (nonatomic, copy) HLYScanPeripheralsCompletionHandler scanPeripheralsCompletionHandler;
@property (nonatomic, copy) HLYConnectedPeripheralCompletionHandler connectedPeripheralCompletionHandler;

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

#pragma mark - Public Mothod

- (BOOL)isConnected {
    
    if (!self.connectedPeripheral) {
        return NO;
    }
    
    return self.connectedPeripheral.state == CBPeripheralStateConnected;
}

- (void)scanPeripheralsWithCompletionHandler:(HLYScanPeripheralsCompletionHandler)completionHandler {
    [self.discoveredDevices removeAllObjects];
    self.scanPeripheralsCompletionHandler = completionHandler;
    [self centralManager];
}

- (void)connectPeripheral:(CBPeripheral *)peripheral
                serviceID:(NSString *)serviceID
         characteristicID:(NSString *)characteristicID
        completionHandler:(HLYConnectedPeripheralCompletionHandler)completionHandler {
    
    if (!peripheral) {
        return;
    }
    
    if (self.connectedPeripheral != peripheral) {
        [self cancelPeripheralConnection:peripheral];
    }
    
    self.serviceID = serviceID;
    self.characteristicID = characteristicID;
    self.connectedPeripheral = peripheral;
    self.connectedPeripheral.delegate = self;
    self.connectedPeripheralCompletionHandler = completionHandler;
    
    [self.centralManager connectPeripheral:self.connectedPeripheral options:nil];//@{CBConnectPeripheralOptionNotifyOnDisconnectionKey:@(YES)}
}

- (void)cancelPeripheralConnection:(CBPeripheral *)peripheral {
    
    if (!peripheral) {
        return;
    }
    //去除次自动连接
//    RemoveLastConnectionPeripheral_UUID();
    
    [self.centralManager cancelPeripheralConnection:peripheral];
    
    if (self.connectedPeripheral) {
        self.connectedPeripheral.delegate = nil;
        self.connectedPeripheral = nil;
    }
}

- (void)autoConnectionPeripheralWithCompletionHandler:(HLYConnectedPeripheralCompletionHandler)completionHandler {
    
    [self scanPeripheralsWithCompletionHandler:^(NSArray<HLYBluetoothDevice *> *devices, NSString *message) {
        
        if (devices.count == 0) {
            return;
        }
        
        [devices enumerateObjectsUsingBlock:^(HLYBluetoothDevice * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            
            if ([obj.peripheral.identifier.UUIDString isEqualToString:[HLYBluetoothManager getRecentConnectionPeripheraUUID]]) {
                
                [self connectPeripheral:obj.peripheral
                              serviceID:obj.serviceID
                       characteristicID:obj.characteristicID
                      completionHandler:^(CBService *service, NSError *error) {
                          if (error) {
                              NSLog(@"自动连接外设出错: %@", [error localizedDescription]);
                          } else {
                              NSLog(@"自动连接外设成功");
                          }
                          completionHandler(service, error);
                      }];
            }
        }];
    }];
}

- (void)stopScanPeripheral {
    [self.centralManager stopScan];
}

#pragma mark - CBCentralManagerDelegate

/**
 * 中央设备状态改变
 */
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    
    NSString *message = nil;
    switch (central.state) {
        case CBCentralManagerStatePoweredOn:
            [self.centralManager scanForPeripheralsWithServices:nil options:nil];
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
            message = @"正在重置";
            break;
        case CBCentralManagerStateUnknown:
            message = @"未知";
            break;
        default:
            break;
    }
    if (message) {
        if (self.scanPeripheralsCompletionHandler) {
            self.scanPeripheralsCompletionHandler(nil, message);
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    
    [self.connectedPeripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    self.connectedPeripheralCompletionHandler(nil, error);
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(nonnull CBPeripheral *)peripheral error:(nullable NSError *)error {
    NSLog(@"设备已断开连接: %@", peripheral);
    
    // 设备断开重连
    [self connectPeripheral:self.connectedPeripheral
                  serviceID:self.serviceID
           characteristicID:self.characteristicID
          completionHandler:self.connectedPeripheralCompletionHandler];
}

#pragma mark - CBPeripheralManagerDelegate

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    
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
                    }
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
        self.scanPeripheralsCompletionHandler([self.discoveredDevices copy], @"蓝牙已打开");
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
        NSLog(@"didWriteValueForCharacteristic error: %@",error.userInfo);
    }
}

#pragma mark - Private Method

- (CBCentralManager *)centralManager {
    if (!_centralManager) {
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
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
