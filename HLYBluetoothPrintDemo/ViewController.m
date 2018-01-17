//
//  ViewController.m
//  HLYBluetoothPrintDemo
//
//  Created by 韩灵叶 on 2018/1/12.
//  Copyright © 2018年 WelfareMall. All rights reserved.
//

#import "ViewController.h"
#import "HLYBluetoothManager.h"
#import "HLYBluetoothPrinter.h"

@interface ViewController () <UITableViewDataSource, UITableViewDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (nonatomic, strong) NSArray<HLYBluetoothDevice *> *bluetoothDevices;
@property (nonatomic, strong) HLYBluetoothPrinter *bluetoothPrinter;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.bluetoothPrinter = [HLYBluetoothPrinter printer];
    [self scanPeripherals];
}

- (IBAction)printButtonClicked:(UIButton *)sender {

    __weak typeof(self) wSelf = self;
    [self.bluetoothPrinter sendData:[@"打印机测试内容太少会打印多遍 <CBPeripheral: 0x1c411c9e0, identifier = 4EDC6F3D-8FDE-4944-DFB4-7712FB801ACB, name = Printer_C96B, state = connected>\n\r" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000)] completionHandler:^(NSError *error) {
        
        __strong typeof(wSelf) self = wSelf;
        [self showAlertWithTitle:sender.titleLabel.text message:error ? [NSString stringWithFormat:@"打印失败: %@", error] : @"打印完成"];
    }];
}

- (void)scanPeripherals {
    
    __weak typeof(self) wSelf = self;
    [self.bluetoothPrinter scanWithCompletionHandler:^(NSArray<HLYBluetoothDevice *> *devices, NSString *message) {
        
        __strong typeof(wSelf) self = wSelf;
        if (devices.count > 0) {
            self.bluetoothDevices = devices;
            [self.tableView reloadData];
        } else {
//            [self showAlertWithTitle:@"打描打印机" message:message];
        }
    }];
}

#pragma mark - UITableViewDataSource

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @"蓝牙设备";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *identifier = @"HLYTableViewCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    }
    HLYBluetoothDevice *device = self.bluetoothDevices[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"名称:%@   信号强度:%@", device.peripheral.name, [device.RSSI stringValue]];
    cell.detailTextLabel.text = device.stateStringValue;
    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.bluetoothDevices.count;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    HLYBluetoothDevice *device = self.bluetoothDevices[indexPath.row];

    __weak typeof(self) wSelf = self;
    [self.bluetoothPrinter connectPrinterDevice:device completionHandler:^(NSError *error) {
        __strong typeof(wSelf) self = wSelf;
        
        [self.tableView  reloadData];
        [self showAlertWithTitle:@"连接打印机" message:error ? [NSString stringWithFormat:@"连接失败: %@", [error localizedDescription]] : @"连接成功"];
    }];

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Private Mothod

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    
    UIAlertAction *alertAction = [UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:NULL];
    UIAlertController* alertController = [UIAlertController alertControllerWithTitle:title
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:alertAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

@end
