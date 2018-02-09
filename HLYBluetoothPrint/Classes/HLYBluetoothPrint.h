//
//  HLYBluetoothPrint.h
//
//  Created by 韩灵叶 on 2018/1/22.
//  Copyright © 2018年 WelfareMall. All rights reserved.
//

#ifdef DEBUG
    #define NSLog(...)  NSLog(__VA_ARGS__)
#else
    #define NSLog(...)
#endif

#import <HLYBluetoothPrint/HLYBluetoothDevice.h>
#import <HLYBluetoothPrint/HLYPrinterDataWrapper.h>
#import <HLYBluetoothPrint/HLYBluetoothManager.h>
#import <HLYBluetoothPrint/HLYBluetoothPrinter.h>
