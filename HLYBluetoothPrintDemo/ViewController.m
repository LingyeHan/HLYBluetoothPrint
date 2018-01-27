//
//  ViewController.m
//  HLYBluetoothPrintDemo
//
//  Created by 韩灵叶 on 2018/1/12.
//  Copyright © 2018年 WelfareMall. All rights reserved.
//

#import "ViewController.h"
#import <HLYBluetoothPrint/HLYBluetoothPrint.h>

@interface ViewController () <UITableViewDataSource, UITableViewDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (nonatomic, strong) NSArray<HLYBluetoothDevice *> *bluetoothDevices;
@property (nonatomic, strong) HLYBluetoothPrinter *bluetoothPrinter;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.bluetoothPrinter = [HLYBluetoothPrinter printer];
    [self scanPrinters];
}

- (IBAction)printButtonClicked:(UIButton *)sender {

    __weak typeof(self) wSelf = self;
    [self.bluetoothPrinter sendData:[self createPrinterTestData] completionHandler:^(NSError *error) {
        
        __strong typeof(wSelf) self = wSelf;
        [self showAlertWithTitle:sender.titleLabel.text message:error ? [NSString stringWithFormat:@"打印失败: %@", error] : @"打印完成"];
    }];
}

- (NSData *)createPrinterTestData {
    
    HLYPrinterDataWrapper *dataWrapper = [[HLYPrinterDataWrapper alloc] init];
    
    // 店铺名称
    [dataWrapper appendText:@"小辉哥火锅" newLine:YES alignment:HLYPrinterTextAlignmentCenter fontSize:HLYPrinterFontSizeMedium];
    [dataWrapper appendNewLine];
    [dataWrapper appendText:@"地址: 在火星上插上中国国旗188号" newLine:YES alignment:HLYPrinterTextAlignmentCenter fontSize:HLYPrinterFontSizeSystem];
    [dataWrapper appendNewLine];
    
    [dataWrapper appendText:@"订单信息"];
    [dataWrapper appendSeperatorLine];
    [dataWrapper appendTitle:@"店铺编号: " value:@"1231234225556"];
    [dataWrapper appendTitle:@"联系人: " value:@"韩先生 13867865432"];
    [dataWrapper appendTitle:@"送餐地址: " value:@"中国地球村美国啊地球村美国啊地球村149号"];
    [dataWrapper appendTitle:@"下单时间: " value:@"2017.10.23 16:34"];
    [dataWrapper appendNewLine];
    
    [dataWrapper appendText:@"订单详情"];
    [dataWrapper appendSeperatorLine];
    [dataWrapper appendLeftText:@"蚂蚁上树" middleText:@"X1" rightText:@"42.00"];
    [dataWrapper appendLeftText:@"毛血旺" middleText:@"X2" rightText:@"182.00"];
    [dataWrapper appendLeftText:@"韭菜炒鸡蛋" middleText:@"X1" rightText:@"42.00"];
    [dataWrapper appendNewLine];
    [dataWrapper appendText:@"总价: 152.50" newLine:YES alignment:HLYPrinterTextAlignmentRight fontSize:HLYPrinterFontSizeMedium];
    [dataWrapper appendNewLine];
    [dataWrapper appendNewLine];
    [dataWrapper appendText:@"备注：不要辣!不要辣!不要辣!"];
    [dataWrapper appendNewLine];
    [dataWrapper appendNewLine];
    [dataWrapper appendQRCodeWithInfo:@"https://m.zuifuli.com/app/download" size:8];
    [dataWrapper appendText:@"扫描二维码 下载最福利" newLine:YES alignment:HLYPrinterTextAlignmentCenter fontSize:HLYPrinterFontSizeSystem];
    [dataWrapper appendNewLine];
    [dataWrapper appendNewLine];
    
    return dataWrapper.printerData;
}

- (void)scanPrinters {
    
    __weak typeof(self) wSelf = self;
    [self.bluetoothPrinter setAutoConnectionCompletionHandler:^(NSError *error) {
        __strong typeof(wSelf) self = wSelf;
        [self.tableView reloadData];
    }];
    [self.bluetoothPrinter scanWithCompletionHandler:^(NSArray<HLYBluetoothDevice *> *devices, NSError *error) {
        
        __strong typeof(wSelf) self = wSelf;
        if (error) {
            [self showAlertWithTitle:@"蓝牙打印机" message:[NSString stringWithFormat:@"扫描失败: %@", [error localizedDescription]]];
        } else {
            self.bluetoothDevices = devices;
            [self.tableView reloadData];
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
    [self.bluetoothPrinter connectWithDevice:device completionHandler:^(NSError *error) {
        __strong typeof(wSelf) self = wSelf;
        
        [self.tableView  reloadData];
        [self showAlertWithTitle:@"蓝牙打印机" message:error ? [NSString stringWithFormat:@"连接失败: %@", [error localizedDescription]] : @"连接成功"];
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
