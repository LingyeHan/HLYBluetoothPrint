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
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
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
    self.scanPeripheralsCompletionHandler = completionHandler;
}

- (void)connectPeripheral:(CBPeripheral *)peripheral completionHandler:(HLYConnectedPeripheralCompletionHandler)completionHandler {
    
    if (!peripheral) {
        return;
    }
    
    if (self.connectedPeripheral != peripheral) {
        [self cancelPeripheralConnection:peripheral];
    }
    
    _connectedPeripheral = peripheral;
    self.connectedPeripheral.delegate = self;
    self.connectedPeripheralCompletionHandler = completionHandler;
    
    [self.centralManager connectPeripheral:peripheral options:nil];//@{CBConnectPeripheralOptionNotifyOnDisconnectionKey:@(YES)}
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
        _connectedPeripheral = nil;
    }
    //取消连接 清楚可打印输入
//    [_printeChatactersArray removeAllObjects];
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
    
//    [self.arrayServices removeAllObjects];
    [self.connectedPeripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    self.connectedPeripheralCompletionHandler(nil, error);
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(nonnull CBPeripheral *)peripheral error:(nullable NSError *)error {
    NSLog(@"断开连接 %@", peripheral);
    [self connectPeripheral:peripheral completionHandler:self.connectedPeripheralCompletionHandler];
}

#pragma mark - CBPeripheralManagerDelegate

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI {
    
    if (peripheral.name.length == 0) {
        return;
    }
    
    NSLog(@"Discovered Peripheral [Peripheral=%@, AdvertisementData=%@, RSSI=%@]", peripheral, advertisementData, RSSI);
    
    HLYBluetoothDevice *bluetoothDevice = [[HLYBluetoothDevice alloc] initWithPeripheral:peripheral RSSI:RSSI];
    if (self.discoveredDevices.count > 0) {
        // 更新蓝牙外设数据
        BOOL isExist = NO;
        for (int i = 0; i < self.discoveredDevices.count; i++) {
            CBPeripheral *origPeripheral = self.discoveredDevices[i].peripheral;
            if ([origPeripheral.identifier.UUIDString isEqualToString:peripheral.identifier.UUIDString]) {
                isExist = YES;
                [self.discoveredDevices replaceObjectAtIndex:i withObject:bluetoothDevice];
                break;
            }
        }
        
        if (!isExist) {
            [self.discoveredDevices addObject:bluetoothDevice];
        }
    } else {
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
            [service.peripheral discoverCharacteristics:nil forService:service];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(nullable NSError *)error {
    
//    if (error) {
//        self.connectedPeripheralCompletionHandler(nil, nil, error);
//        return;
//    }
    self.connectedPeripheralCompletionHandler(service, error);
//    for (CBCharacteristic *characteristic in service.characteristics) {
//        CBCharacteristicProperties properties = characteristic.properties;
//        if (properties & self.characteristicProperties) {
//            NSLog(@"Characteristic found with Service:%@ UUID: %@", service, characteristic.UUID);
//            self.connectedPeripheralCompletionHandler(peripheral, characteristic, nil);
//            break;
//        }
//    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error {
    NSLog(@"写入成功 %@", characteristic);
}

#pragma mark - Class Method

+ (void)removeLastConnectionPeripheral_UUID {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults removeObjectForKey:@"BluetoothPeripheral_uuid"];
    [userDefaults synchronize];
}

@end
