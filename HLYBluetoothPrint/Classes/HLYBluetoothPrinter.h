//
//  HLYBluetoothPrinter.h
//  HLYBluetoothPrintDemo
//
//  Created by 韩灵叶 on 2018/1/15.
//  Copyright © 2018年 WelfareMall. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <HLYBluetoothPrint/HLYBluetoothManager.h>

@interface HLYBluetoothPrinter : NSObject

@property (nonatomic, readonly) BOOL isConnected;
@property (nonatomic, copy) void(^autoConnectionCompletionHandler)(NSError *error);

+ (instancetype)printer;

- (void)scanWithCompletionHandler:(HLYScanPeripheralsCompletionHandler)completionHandler;

- (void)stopScan;

- (void)connectWithDevice:(HLYBluetoothDevice *)device completionHandler:(void(^)(NSError *error))completionHandler;

/**
 * 发送打印数据
 *
 * @param data 需要打印的数据
 * @param completionHandler 打印完成回调
 */
- (void)sendData:(NSData *)data completionHandler:(void(^)(NSError *error))completionHandler;

@end
