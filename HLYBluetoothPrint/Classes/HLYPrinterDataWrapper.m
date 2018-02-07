//
//  HLYPrinterDataWrapper.m
//
//  Created by 韩灵叶 on 2018/1/16.
//  Copyright © 2018年 WelfareMall. All rights reserved.
//

#import "HLYPrinterDataWrapper.h"
#import "UIImage+HLYBitmap.h"

#define kMargin 20
#define kPadding 2
#define kWidth 320

@interface HLYPrinterDataWrapper ()

@property (nonatomic, strong) NSMutableData *data;

@end

@implementation HLYPrinterDataWrapper

- (instancetype)init {
    self = [super init];
    if (self) {
        _data = [[NSMutableData alloc] init];
        [self initPrinterSetting];
    }
    return self;
}

- (void)initPrinterSetting {
    
    // 复位打印机
    Byte resetBytes[] = {0x1B, 0x40};
    [self.data appendBytes:resetBytes length:sizeof(resetBytes)];
    
    // 设置行间距为 0x32: 1/6英寸=203/6=34点
    Byte lineSpace[] = {0x1B, 0x32};
    [self.data appendBytes:lineSpace length:sizeof(lineSpace)];
    
    // 设置字号，打印机默认为字号
    Byte fontSizeBytes[] = {0x1B, 0x4D, 0x00};// 标准ASCII字体 0x01: 压缩ASCII字体
    [self.data appendBytes:fontSizeBytes length:sizeof(fontSizeBytes)];
}

#pragma mark - Public Method

/**
 * 设置行间距
 * 说明: 0x33: n点行(n=0-255, 默认值行间距是30点)
 *
 *  @param point 多少个点(取值范围0-255)
 */
- (void)setLineSpace:(NSInteger)point {
    Byte lineSpace[] = {0x1B, 0x33, MAX(0, MIN(point, 255))};
    [self.data appendBytes:lineSpace length:sizeof(lineSpace)];
}

/**
 * 设置对齐方式
 *
 * @param alignment 对齐方式：居左、居中、居右
 */
- (void)setAlignment:(HLYPrinterTextAlignment)alignment {
    Byte alignmentBytes[] = {0x1B, 0x61, alignment};
    [self.data appendBytes:alignmentBytes length:sizeof(alignmentBytes)];
}

/**
 * 设置字体大小
 *
 * @param fontSize 字号
 */
- (void)setFontSize:(HLYPrinterFontSize)fontSize {
    Byte fontSizeBytes[] = {0x1D, 0x21, fontSize};
    [self.data appendBytes:fontSizeBytes length:sizeof(fontSizeBytes)];
}

/**
 *  换行
 */
- (void)appendNewLine {
    Byte newLineBytes[] = {0x0A};
    [self.data appendBytes:newLineBytes length:sizeof(newLineBytes)];
}

/**
 *  回车
 */
- (void)appendReturn {
    Byte returnBytes[] = {0x0D};
    [self.data appendBytes:returnBytes length:sizeof(returnBytes)];
}

/**
 *  添加文本 (默认居左、系统字号、换行)
 *
 *  @param text 文本
 */
- (void)appendText:(NSString *)text {
    [self appendText:text newLine:YES];
}

- (void)appendText:(NSString *)text newLine:(BOOL)newLine {
    [self appendText:text newLine:newLine alignment:HLYPrinterTextAlignmentLeft fontSize:HLYPrinterFontSizeSystem];
}

- (void)appendText:(NSString *)text newLine:(BOOL)newLine alignment:(HLYPrinterTextAlignment)alignment {
    [self appendText:text newLine:newLine alignment:alignment fontSize:HLYPrinterFontSizeSystem];
}

- (void)appendText:(NSString *)text newLine:(BOOL)newLine alignment:(HLYPrinterTextAlignment)alignment fontSize:(HLYPrinterFontSize)fontSize {
    
    [self setAlignment:alignment];
    [self setFontSize:fontSize];
    [self.data appendData:[text dataUsingEncoding:HLYPrinterStringEncodingGB_18030_2000()]];
    if (newLine) {
        [self appendNewLine];
    }
}

// ==== Title

- (void)appendTitle:(NSString *)title value:(NSString *)value {
    [self appendTitle:title value:value fontSize:HLYPrinterFontSizeSystem];
}

- (void)appendTitle:(NSString *)title value:(NSString *)value alignment:(HLYPrinterTextAlignment)alignment {
    [self appendTitle:title value:value offset:0 fontSize:HLYPrinterFontSizeSystem alignment:alignment];
}

- (void)appendTitle:(NSString *)title value:(NSString *)value fontSize:(HLYPrinterFontSize)fontSize {
    [self appendTitle:title value:value offset:0 fontSize:fontSize];
}

- (void)appendTitle:(NSString *)title value:(NSString *)value offset:(NSInteger)offset {
    [self appendTitle:title value:value offset:offset fontSize:HLYPrinterFontSizeSystem];
}

- (void)appendTitle:(NSString *)title value:(NSString *)value offset:(NSInteger)offset fontSize:(HLYPrinterFontSize)fontSize {
    [self appendTitle:title value:value offset:offset fontSize:fontSize alignment:HLYPrinterTextAlignmentLeft];
}

- (void)appendTitle:(NSString *)title value:(NSString *)value offset:(NSInteger)offset fontSize:(HLYPrinterFontSize)fontSize alignment:(HLYPrinterTextAlignment)alignment {
    
    [self setAlignment:alignment];
    [self setFontSize:fontSize];
    [self appendText:title newLine:NO];
    if (offset > 0) {
        [self setOffset:offset];
    }
    [self appendText:value];
}

// ===== Left

- (void)appendLeftText:(NSString *)leftText middleText:(NSString *)middleText rightText:(NSString *)rightText {
    [self appendLeftText:leftText middleText:middleText rightText:rightText isTitle:NO];
}

- (void)appendLeftText:(NSString *)leftText middleText:(NSString *)middleText rightText:(NSString *)rightText isTitle:(BOOL)isTitle {
    
    [self setAlignment:HLYPrinterTextAlignmentLeft];
    [self setFontSize:HLYPrinterFontSizeSystem];
    
    NSInteger offset = isTitle ? 0 : 10;
    if (leftText) {
        [self appendText:leftText maxChar:8];
    }
    
    if (middleText) {
        [self setOffset:245 + offset];
        [self appendText:middleText newLine:NO];
    }
    
    if (rightText) {
//        [self setOffset:350 + offset];
        [self setOffsetText:rightText];
        [self appendText:rightText newLine:NO];
    }
    
    [self appendNewLine];
}

/**
 *  添加文字，不换行
 *
 *  @param text    文字内容
 *  @param maxCount 最多可以允许多少个字符, 超过后面加"..."
 */
- (void)appendText:(NSString *)text maxChar:(NSInteger)maxCount {
    
    if (text.length >= maxCount) {
        text = [text stringByReplacingCharactersInRange:NSMakeRange(maxCount, text.length-maxCount) withString:@"..."];
    }
    [self appendText:text newLine:NO];
}

/**
 *  设置偏移文字
 *
 *  @param text 文字
 */
- (void)setOffsetText:(NSString *)text
{
    // 1.计算偏移量,因字体和字号不同，所以计算出来的宽度与实际宽度有误差(小字体与22字体计算值接近)
    NSDictionary *dict = @{NSFontAttributeName:[UIFont systemFontOfSize:22.0]};
    NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:text attributes:dict];
    NSInteger textWidth = attrString.size.width;

    // 2.设置偏移量
    [self setOffset:378 - textWidth];

    // 3.设置文字
//    [self appendText:text];
}

/**
 *  设置偏移量
 *
 *  @param offset 偏移量 用点数计算=(nH*256+nL)*0.125mm
 */
- (void)setOffset:(NSInteger)offset {
    NSInteger nL = offset % 256;//低位
    NSInteger nH = offset / 256;//高位
    Byte spaceBytes[] = {0x1B, 0x24, nL, nH};
    [self.data appendBytes:spaceBytes length:sizeof(spaceBytes)];
}

/**
 *  设置二维码模块大小
 *
 *  @param size  1<= size <= 16,二维码的宽高相等
 */
- (void)setQRCodeSize:(NSInteger)size
{
    Byte QRSize [] = {0x1D,0x28,0x6B,0x03,0x00,0x31,0x43,size};
    //    Byte QRSize [] = {29,40,107,3,0,49,67,size};
    [self.data appendBytes:QRSize length:sizeof(QRSize)];
}

/**
 *  设置二维码的纠错等级
 *
 *  @param level 48 <= level <= 51
 */
- (void)setQRCodeErrorCorrection:(NSInteger)level
{
    Byte levelBytes [] = {0x1D,0x28,0x6B,0x03,0x00,0x31,0x45,level};
    //    Byte levelBytes [] = {29,40,107,3,0,49,69,level};
    [self.data appendBytes:levelBytes length:sizeof(levelBytes)];
}

/**
 *  将二维码数据存储到符号存储区
 * [范围]:  4≤(pL+pH×256)≤7092 (0≤pL≤255,0≤pH≤27)
 * cn=49
 * fn=80
 * m=48
 * k=(pL+pH×256)-3, k就是数据的长度
 *
 *  @param info 二维码数据
 */
- (void)setQRCodeInfo:(NSString *)info
{
    NSInteger kLength = info.length + 3;
    NSInteger pL = kLength % 256;
    NSInteger pH = kLength / 256;
    
    Byte dataBytes [] = {0x1D,0x28,0x6B,pL,pH,0x31,0x50,48};
    //    Byte dataBytes [] = {29,40,107,pL,pH,49,80,48};
    [self.data appendBytes:dataBytes length:sizeof(dataBytes)];
    NSData *infoData = [info dataUsingEncoding:NSUTF8StringEncoding];
    [self.data appendData:infoData];
    //    [self setText:info];
}

/**
 *  打印之前存储的二维码信息
 */
- (void)printStoredQRData
{
    Byte printBytes [] = {0x1D,0x28,0x6B,0x03,0x00,0x31,0x51,48};
    //    Byte printBytes [] = {29,40,107,3,0,49,81,48};
    [self.data appendBytes:printBytes length:sizeof(printBytes)];
}

- (void)appendImage:(UIImage *)image alignment:(HLYPrinterTextAlignment)alignment maxWidth:(CGFloat)maxWidth
{
    if (!image) {
        return;
    }
    
    // 1.设置图片对齐方式
    [self setAlignment:alignment];
    
    // 2.设置图片
    UIImage *newImage = [image imageWithscaleMaxWidth:maxWidth];
    
    NSData *imageData = [newImage bitmapData];
    [self.data appendData:imageData];
    
    // 3.换行
    [self appendNewLine];
    
    // 4.打印图片后，恢复文字的行间距
    Byte lineSpace[] = {0x1B,0x32};
    [self.data appendBytes:lineSpace length:sizeof(lineSpace)];
}

- (void)appendBarCodeWithInfo:(NSString *)info
{
    [self appendBarCodeWithInfo:info alignment:HLYPrinterTextAlignmentCenter maxWidth:300];
}

- (void)appendBarCodeWithInfo:(NSString *)info alignment:(HLYPrinterTextAlignment)alignment maxWidth:(CGFloat)maxWidth
{
    UIImage *barImage = [UIImage barCodeImageWithInfo:info];
    [self appendImage:barImage alignment:alignment maxWidth:maxWidth];
}

- (void)appendQRCodeWithInfo:(NSString *)info size:(NSInteger)size
{
    [self appendQRCodeWithInfo:info size:size alignment:HLYPrinterTextAlignmentCenter];
}

- (void)appendQRCodeWithInfo:(NSString *)info size:(NSInteger)size alignment:(HLYPrinterTextAlignment)alignment
{
    [self setAlignment:alignment];
    [self setQRCodeSize:size];
    [self setQRCodeErrorCorrection:48];
    [self setQRCodeInfo:info];
    [self printStoredQRData];
    [self appendNewLine];
}

- (void)appendQRCodeWithInfo:(NSString *)info
{
    [self appendQRCodeWithInfo:info centerImage:nil alignment:HLYPrinterTextAlignmentCenter maxWidth:250];
}

- (void)appendQRCodeWithInfo:(NSString *)info centerImage:(UIImage *)centerImage alignment:(HLYPrinterTextAlignment)alignment maxWidth:(CGFloat )maxWidth
{
    UIImage *QRImage = [UIImage qrCodeImageWithInfo:info centerImage:centerImage width:maxWidth];
    [self appendImage:QRImage alignment:alignment maxWidth:maxWidth];
}

- (void)appendSeperatorLine {
    
    [self setAlignment:HLYPrinterTextAlignmentCenter];
    [self setFontSize:HLYPrinterFontSizeSmall];
    [self appendText:@"--------------------------------"];
}

- (NSData *)dataValue {
    return self.data;
}

#pragma mark - Private Method

- (NSData *)printerData {
    return [self.data copy];
}

NSStringEncoding HLYPrinterStringEncodingGB_18030_2000() {
    return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
}

@end
