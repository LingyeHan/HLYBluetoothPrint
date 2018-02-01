//
//  HLYPrinterDataWrapper.h
//
//  Created by 韩灵叶 on 2018/1/16.
//  Copyright © 2018年 WelfareMall. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * 打印机文本对齐方式
 */
typedef NS_ENUM(NSInteger, HLYPrinterTextAlignment) {
    HLYPrinterTextAlignmentLeft    = 0x00,
    HLYPrinterTextAlignmentCenter  = 0x01,
    HLYPrinterTextAlignmentRight   = 0x02
};

/**
 * 打印机字号
 */
typedef NS_ENUM(NSInteger, HLYPrinterFontSize) {

    HLYPrinterFontSizeSmall    = 0x00,
    HLYPrinterFontSizeMedium   = 0x11,
    HLYPrinterFontSizeLarge    = 0x22,
    HLYPrinterFontSizeSystem = HLYPrinterFontSizeSmall
};

/**
 * 打印机字体样式
 */
typedef NS_ENUM(NSInteger, HLYPrinterFontStyle) {
    HLYPrinterFontStyleSystem   = 0x00,
    HLYPrinterFontStyleBold     = 0x01,
};

@interface HLYPrinterDataWrapper : NSObject

@property (nonatomic, strong, readonly) NSData *printerData;

/**
 * 设置行间距
 * 说明: 0x33: n点行(n=0-255, 默认值行间距是30点)
 *
 *  @param point 多少个点(取值范围0-255)
 */
- (void)setLineSpace:(NSInteger)point;

/**
 * 设置对齐方式
 *
 * @param alignment 对齐方式：居左、居中、居右
 */
- (void)setAlignment:(HLYPrinterTextAlignment)alignment;
/**
 * 设置字体大小
 *
 * @param fontSize 字号
 */
- (void)setFontSize:(HLYPrinterFontSize)fontSize;

/**
 * 换行
 */
- (void)appendNewLine;

/**
 * 回车
 */
- (void)appendReturn;

/**
 * 添加文本
 *
 * @param text 文本
 */
- (void)appendText:(NSString *)text;

/**
 * 添加文本
 *
 * @param text 文本
 * @param newLine 是否换行
 */
- (void)appendText:(NSString *)text newLine:(BOOL)newLine;

/**
 * 添加文本
 *
 * @param text 文本
 * @param newLine 是否换行
 * @param alignment 对齐方式
 * @param fontSize 字号
 */
//- (void)appendText:(NSString *)text newLine:(BOOL)newLine fontSize:(HLYPrinterFontSize)fontSize;

- (void)appendTitle:(NSString *)title value:(NSString *)value;

- (void)appendTitle:(NSString *)title value:(NSString *)value alignment:(HLYPrinterTextAlignment)alignment;

/**
 * 添加文本
 *
 * @param text 文本
 * @param newLine 是否换行
 * @param alignment 对齐方式
 * @param fontSize 字号
 */
- (void)appendText:(NSString *)text newLine:(BOOL)newLine alignment:(HLYPrinterTextAlignment)alignment fontSize:(HLYPrinterFontSize)fontSize;

- (void)appendLeftText:(NSString *)leftText middleText:(NSString *)middleText rightText:(NSString *)rightText;

- (void)appendLeftText:(NSString *)leftText middleText:(NSString *)middleText rightText:(NSString *)rightText isTitle:(BOOL)isTitle;

- (void)appendSeperatorLine;

/**
 添加二维码
 ✅推荐：这种方式使用的是打印机的指令生成二维码并打印机，所以比较推荐这种方式
 @param info 二维码中的信息
 @param size 二维码的大小 取值范围1 <= size <= 16
 */
- (void)appendQRCodeWithInfo:(NSString *)info size:(NSInteger)size;

/**
 添加二维码
 ✅推荐：这种方式使用的是打印机的指令生成二维码并打印机，所以比较推荐这种方式
 @param info 二维码中的信息
 @param size 二维码大小，取值范围 1 <= size <= 16
 @param alignment 设置图片对齐方式
 */
- (void)appendQRCodeWithInfo:(NSString *)info size:(NSInteger)size alignment:(HLYPrinterTextAlignment)alignment;

@end
